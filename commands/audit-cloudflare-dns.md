---
description: Audit every Cloudflare DNS zone the project owns through the signed-in Chrome browser — records missing, stale or dangling against what the project expects, wrong proxy status, mail authentication (SPF, DKIM, DMARC, MX), CAA and DNSSEC — cross-checked with public lookups, then make only the dashboard changes the owner confirms one by one. Run before launch, after moving a domain or host, after adding a mail or hosting provider, or as a periodic sweep. Not for Cloudflare cache, WAF or bot settings.
argument-hint: "[zone, e.g. example.com] (default: every zone the project facts name)"
---

# /audit-cloudflare-dns

Reads each Cloudflare DNS zone in the owner's signed-in Chrome, compares it with what the project expects and with what public DNS actually answers, and reports what is missing, stale, dangling (pointing at something that no longer exists, which lets an outsider claim the name) or weakly configured.

Two phases: **investigate and ask** (Steps 1–9), then **fix** (Step 10). DNS is live: one wrong change takes the site, the app or the mail down. Change nothing in Cloudflare before the owner says yes to that exact change.

## Step 1: Load the project's DNS facts

`$ARGUMENTS` may name one zone (`<zone>`). Empty means every zone the facts name.

```sh
rg -n '^- \*\*(DNS|Records)\*\*' .agents/project-facts.md | head -n 5
```

The DNS bullet names a doc and a heading. Read that section only (find its line with `rg -n '<heading>' <doc> | head -n 3`, then read about 60 lines from there) and write down:

- `<zones>`: every zone the project owns, and whether each sends mail;
- `<expected>`: per hostname, what it should point at and whether it should be proxied (orange cloud) or DNS-only (grey cloud);
- `<retired>`: hostnames that must not exist any more;
- `<record>`: the audit record path for this sweep;
- `<records>`: where owner-only tasks, open bugs and changelog lines go.

Done when: you can state `<zones>`, `<expected>` and `<record>`. If the command prints nothing or the section names no zones, stop and ask: "Which Cloudflare zones should I audit, and what should each hostname point at?"

## Step 2: Re-check the audit record

`<record>` is created on first run (shape in Step 8); if it does not exist, skip this step.

```sh
rg -n '^[0-9]+\. \*\*' <record> | grep -v '~~' | head -n 40
```

Those are the open entries. Step 6 judges each one again: still open, fixed (strike it through with the date) or wrong (delete it). Write nothing to the record yet.

Done when: you have a list of the open entry numbers.

## Step 3: Open a new Chrome tab on the dashboard

This step uses the browser tools, not the shell. Load the browser tools in one batch (tab context, new tab, navigate, page text, JavaScript), read the current tab context, then open a **new** tab at `https://dash.cloudflare.com/`.

| What the page shows | Action |
|---|---|
| The account home with a list of domains | Go on. |
| A login or two-factor screen | Stop and ask: "Please sign in to Cloudflare in Chrome, then tell me to carry on." Never type a password or code, even if the browser autofills it. |
| Several accounts to choose from | Stop and ask: "Which Cloudflare account holds `<zones>`?" |
| Browser tools fail twice | Stop and report the error. |

Done when: the tab shows the account home.

## Step 4: Export each zone's records

From the dashboard tab, call the dashboard's own API with the session cookie (read-only `GET`s only). Run it once per zone, keeping the result in `window.__dns`:

```js
const z = (await (await fetch('/api/v4/zones?name=<zone>')).json()).result[0];
const r = await (await fetch(`/api/v4/zones/${z.id}/dns_records?per_page=500`)).json();
const s = await (await fetch(`/api/v4/zones/${z.id}/dnssec`)).json();
window.__dns = {...(window.__dns || {}), ['<zone>']: {zone: z, records: r.result, dnssec: s.result}};
`${z.status} ns=${z.name_servers} records=${r.result.length} dnssec=${s.result?.status}`;
```

Then print the records about 15 at a time as `type | name | content (cut to 70 chars) | proxied | ttl`. Output is capped at about 1,000 characters per call, so print slices, never the raw JSON.

| Result | Action |
|---|---|
| A status line per zone | Go on. |
| `result` is empty for a zone | The zone is not on this account: report it as a finding (`ZONE MISSING`), go on. |
| 401, 403 or HTML instead of JSON | Fall back: open the zone's **DNS → Records** page and read it with the page-text tool, then **DNS → Settings** for DNSSEC. |
| Fallback also fails | Stop and report what the page shows. |

Also list every zone on the account (`/api/v4/zones?per_page=50`, names only). A zone not in `<zones>` is reported as `UNLISTED ZONE`, not audited.

Done when: every zone in scope has its records and DNSSEC status written in your notes.

## Step 5: Check public DNS from the terminal

Run these for each zone, and the `A`/`CNAME`/`curl` lines for each hostname found in Step 4:

```sh
dig +short NS <zone>
dig +short DS <zone>
dig +short CAA <zone>
dig +short MX <zone>
dig +short TXT <zone>
dig +short TXT _dmarc.<zone>
dig +short A <host>; dig +short CNAME <host>
curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' --max-time 10 https://<host>/
```

Done when: each hostname has a resolution line and an HTTP status (or "no web service" for mail-only names). If `dig` is missing, stop and ask: "May I install dig, or skip public checks?"

## Step 6: Classify every finding

This step is judgement; no command. Judge each record and zone, and each open entry from Step 2, against this table. Each finding gets one code, its evidence (`<zone> <type> <name> -> <content>`) and a confidence: confirmed (seen in the dashboard and public DNS), likely, or suspected.

| Code | Situation | Severity |
|---|---|---|
| DANGLING | A record points at a host or provider that answers "not found", fails to resolve, or is an IP nobody owns any more. Someone else could claim it. | high |
| RETIRED | A hostname in `<retired>` still exists. | high |
| MISSING | A hostname in `<expected>` has no record, or public DNS disagrees with the dashboard. | high |
| NS | The zone's public `NS` answer is not the Cloudflare name servers from Step 4. | high |
| ORIGIN EXPOSED | A DNS-only record reveals the same origin IP a proxied record hides. | medium |
| PROXY | Proxy status differs from `<expected>`. | medium |
| MAIL | Mail-sending zone: no SPF, two SPF records, SPF ending `+all`/`?all`, no DMARC, DMARC `p=none` with no reporting address, a provider's DKIM record missing. Non-mail zone: no `v=spf1 -all`, no DMARC `p=reject`. | medium |
| DNSSEC | DNSSEC off, or on in Cloudflare with no `DS` in public DNS. | medium |
| CAA | No CAA record limiting which authorities may issue certificates. | low |
| UNEXPECTED | A record not in `<expected>` and not explained by a known provider's verification. | ask |
| UNLISTED ZONE / ZONE MISSING | From Step 4. | ask |

Anything that fits no row → suspected, code UNEXPECTED. Never mark a verification `TXT` (site verification, ACME challenge) DANGLING just because nothing serves it.

Done when: every record has either a finding or "ok".

## Step 7: Check the expectations themselves

A finding may mean the project's DNS facts are stale, not the zone. For each MISSING, UNEXPECTED and PROXY finding, search the repo for the hostname:

```sh
rg -l '<host>' --glob '!CHANGELOG.md' . | head -n 10
```

If the code agrees with the zone and only the DNS facts disagree, the fix is to the facts section (a repo edit), not the dashboard. Say so on the finding.

Done when: each of those findings says "fix zone" or "fix facts".

## Step 8: Update the audit record

Write findings into `<record>` in this shape (keep its existing entries and numbering; add new entries after them):

```markdown
# Cloudflare audit

**Audited:** <date>. **Zones:** <zone>, <zone>. **Method:** dashboard API export + public dig/curl.
**Confidence:** confirmed = seen in dashboard and public DNS; likely; suspected.

1. **[DANGLING, high, confirmed]** `<zone> CNAME old -> <target>`: target answers 404 "site not found". Fix zone: delete the record.
- Re-checked <date>: 1 open, 2 fixed.
```

Add one dated `Re-checked` line covering the Step 2 entries. A finding that is a real outage goes to the open-bug list in `<records>` instead, with a pointer here.

Done when: the record has this run's date line.

## Step 9: Present and ask

In your reply, list findings worst first, at most 10 per round, numbered as in the record:

```text
3. DANGLING high confirmed | <zone> CNAME old -> <target> | 404 site not found | fix zone: delete record
```

Then ask: "Which should I fix (numbers), which leave, which defer?" Wait for the answer. Write nothing in Cloudflare yet.

Done when: the owner has answered for every listed number.

## Step 10: Fix the confirmed ones

Dashboard changes use the browser tools; the check after each is its Step 5 `dig` line. For each confirmed number, in order:

| Fix kind | Action |
|---|---|
| fix facts | Edit the project's DNS facts section in the repo. |
| Add, edit or delete a record | First copy the record's full current value into its finding in `<record>` (so it can be restored). Make the change in the zone's **DNS → Records** page through the browser. Re-run the matching Step 5 `dig` line; a new value can take up to the TTL to show. |
| Name servers, DNSSEC at the registrar, registrar settings, anything billed | Do not touch. Write it as an owner task in `<records>`. |
| Owner said leave | Mark the finding `left (<reason>, <date>)` in `<record>`. |
| Owner said defer | Leave it open. |

Never delete or edit a record the owner did not name by number. If a change fails twice, stop and report what the page shows.

Then mark each fixed finding struck through with the date in `<record>`, and add one changelog line for the run (the `<records>` changelog command) if any zone or facts changed.

Done when: every confirmed number is fixed, left or recorded as an owner task, and its `dig` line shows the new value (or the TTL is noted).

## Done means

- `<record>` has this run's dated line, and every finding has a code, evidence and confidence.
- No Cloudflare change was made without the owner naming its number.
- Every changed record's `dig +short <type> <host>` matches the new value, or the finding notes the TTL still pending.
