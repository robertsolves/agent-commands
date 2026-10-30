---
description: Find what keeps the marketing site from being found and quoted — routes missing from the sitemap or hreflang, titles and descriptions missing per locale, wrong canonical or social tags, structured data that is missing or out of date, pages search engines and AI answer engines can't lift a clear answer from, an llms.txt that no longer matches the site — ask which to fix, then fix them with a test where the gap is mechanical. Run before a site release, after adding pages or locales, or as a periodic sweep.
argument-hint: "[page, locale or area: seo | aeo] (default: the whole site, both)"
---

# /find-seo-aeo-improvements

Two audiences read the site besides people. Search engines (SEO) need every page discoverable, uniquely titled and correctly linked across languages. AI answer engines (AEO: assistants that quote the web) need pages that state plain, quotable answers to the questions people ask. This command checks both from the site's source and its generated files.

Two phases: investigate and ask (Steps 1-6), then fix (Step 7). Never fix before the owner answers in Step 6.

Never use the SEO tool's paid features (keyword, ranking or AI-visibility checks) without asking first (Step 6).

## Step 1: Read the project facts and resolve scope

```sh
rg -n '^- \*\*(Marketing site and SEO|Audit records|Records|Product brief|Checks and tests)\*\*' .agents/project-facts.md | head -n 5
```

Read those bullets in `.agents/project-facts.md`. Write down these names in your notes (they are the `<placeholders>` below):

- `<site-dir>`: the site's folder; `<router-file>` and `<head-component>`: where its routes and its page head (title, meta, canonical, JSON-LD) are defined;
- `<generators>`: how the sitemap, `robots.txt` and `llms.txt` are made. For each one note the command that regenerates it (`<generator-command>`), or "hand-written". Note which of the files they write are committed;
- `<site-checks>`: the site's lint and test commands, from the **Checks and tests** bullet;
- `<record>`: the audit record for this sweep (`/find-seo-aeo-improvements`);
- `<brief>`: the product brief.

| `$ARGUMENTS` | Scope |
|---|---|
| a page or locale | that page or locale, both `seo` and `aeo` |
| `seo` or `aeo` | the whole site, only that half (skip Step 5 for `seo`, Steps 3-4 for `aeo`) |
| empty | the whole site, both halves |

Done when: every placeholder above has a real path from the bullets.
If the bullets are missing, stop and ask: "Where is the marketing site and where does this project keep its SEO audit record?"

## Step 2: Re-verify the open entries in the record

```sh
ls <record>
rg -n '^(##|###) |Status|OPEN|open' <record> | head -n 60
```

For each open entry, check it against the current code. Still open: keep. Fixed: strike it with today's date. Wrong: delete it. Add a dated verification line at the bottom. If `<record>` does not exist, it is created in Step 6 (created on first run).

Done when: every open entry has a verdict and the record has today's verification line.

## Step 3: Regenerate and diff the committed generated files

Skip this step for a file that is hand-written. A generator overwrites the committed file, so keep a copy and put it back after the diff. Run from the repo root, once per committed generated file (`<generated-file>` is its path from Step 1, `<scratch>` any empty temp folder):

```sh
mkdir -p <scratch> && cp <generated-file> <scratch>/
<generator-command>
diff <scratch>/<generated-file-name> <generated-file> | head -n 40
cp <scratch>/<generated-file-name> <generated-file>
```

A difference means the committed file is stale: that is the first finding. Do not keep the regenerated file; Step 7 regenerates.

Done when: you have a verdict (same or stale) for each committed generated file and each file is back to its committed content.
If a generator fails twice with the same error, stop and report the output.

## Step 4: Check routes and languages

```sh
rg -n -i "path|route" <router-file> | head -n 80
rg -n -i "path|loc" <sitemap-source> | head -n 80
```

`<sitemap-source>` is the sitemap generator, or the committed sitemap file when it is hand-written. Compare the two lists (the first is the truth, the second is the sitemap's). For each route, note whether it:

- is in the sitemap, or is deliberately excluded with a reason written beside it;
- has every locale version, each linking to the others with `hreflang`, including `x-default`;
- has one canonical URL, and the canonical and the social `og:url` agree;
- is not blocked by the robots rules.

Done when: you have a table of route, in sitemap (yes / excluded / missing), locales complete (yes / no), canonical agrees (yes / no).
This step reads source only; the verdicts are judgement.

## Step 5: Check page heads

```sh
rg -n -i "hreflang|canonical|og:|twitter:|ld\+json|jsonld" <head-component> | head -n 40
rg -n -i "price|rating|<price-gate>" <site-config> | head -n 20
```

For each route and locale, check:

- a unique title and description of sensible length, in that locale's language (not English on a translated page);
- social preview tags and an image;
- structured data (JSON-LD) that is valid and true. It must not state anything the page hides: no prices while prices are gated, no ratings that don't exist.

Done when: each route has a verdict on title, description, social tags and structured data.
This step is judgement over the source the commands list.

## Step 6: Check answers, record, present and ask

Skip the answer-engine part when `$ARGUMENTS` is `seo`.

```sh
rg -n -i "faq|howto|FAQPage|acceptedAnswer" <site-dir>/lib | head -n 30
rg -n -i "^#|^-" <site-dir>/web/llms.txt | head -n 60
```

Take the questions a prospective user asks from `<brief>` and the site's own FAQ. For each, note:

- is there a page that answers it in one or two plain sentences near the top, quotable on its own?
- do FAQ or how-to sections use the matching structured data?
- does the llms file describe the product and link the pages that answer it, accurately and without claims the product cannot back?

Live search data from an SEO tool is optional and spends credits. If you want it, ask: "Use the SEO tool for <what> at about <N> credits?" and wait. No answer means do not use it.

Write each finding into `<record>` in its existing format:

```text
### 4. /de/partners missing from the sitemap
Page: /de/partners · Locale: de · Confidence: confirmed
Evidence: <router-file> lists the route; the sitemap generator does not.
Fix: add the route to the generator list.
```

Present a numbered list: discoverability first (missing routes, broken hreflang, blocked pages), then page heads, then answer-engine content; at most 15 per round. Ask per finding: **fix** / **leave** / **defer**. Content rewrites need the owner's wording approval. Wait for the answers.

Done when: every finding is in `<record>` and the owner has answered for each one shown.

## Step 7: Fix

Fix only the findings marked **fix**. Edit these and nothing else: the generators, `<head-component>`, page content the owner approved, tests, `<record>`.

1. Fix mechanical gaps in the generator or head component, not page by page, so the next page gets it for free.
2. Add a test or build check for each mechanical class you fixed (every route in the sitemap, every page has a title per locale), so it cannot regress.
3. For content changes, follow the copy and brand rules the bullet from Step 1 names.
4. Regenerate the generated files with the Step 3 generators, mark entries fixed in `<record>` with the date, and add a changelog line with the command `AGENTS.md` lists under "After making changes".
5. Run the checks `AGENTS.md` lists under "After making changes" for the site, plus the tests you added:

```sh
<site-checks>
```

Done when: the new tests pass, the site's analyze command from `AGENTS.md` prints no issues, and `<record>` marks each fixed entry with today's date.
If a command fails twice with the same error, stop and report the output.

## Done means

- Every open entry in `<record>` has a verdict and a dated verification line.
- The Step 3 diff for each committed generated file was read, and each file is back to its committed content (or regenerated in Step 7).
- The owner answered **fix** / **leave** / **defer** for every finding shown, before any edit.
- After fixes, the site's tests and analyze command pass, and the changelog command exited 0.
