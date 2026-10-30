---
description: Pull every unresolved Sentry issue across the project's Sentry projects, check each against the current code, list the ones still live, then fix them. Run after a release, when Sentry mails about a new issue, or as a periodic sweep. Not for a bug list that is not in Sentry — use /refine-findings.
argument-hint: "[issue short-id, Sentry project slug, or stats period like 14d] (default: every project, 90d)"
---

# /fix-sentry

Three phases: pull every unresolved issue (Step 2), triage each against the current tree (Step 3), fix the live ones (Steps 4-6). The user asked for "list, then fix" in one go: do not stop for confirmation between the list and the fixes. Stop only at the ask points below.

## Ask points

Each of these needs a yes from the user. If the user gives no answer, leave the item untouched.

| Situation | Action |
|---|---|
| You want to mark issues resolved in Sentry (this changes shared external state) | Offer to resolve the FIXED and newly fixed ones ("resolve in next release" for undeployed fixes). Do it only on a yes. |
| An error would go away by raising a cost-bearing limit (token budget, retry count, quota) | Read the comment beside the constant, then ask: "Raise `<limit>` from X to Y?" Do not raise it without a yes. |
| `<triage rules>` list the item as needing the owner | Ask the user. |

## Step 1: Load the project's Sentry facts

`$ARGUMENTS` may be one issue short-id, one Sentry project slug, or a stats period (`14d`). Empty means every project, over `90d`.

```sh
rg -n '^- \*\*Sentry\*\*' .agents/project-facts.md | head -n 5
```

That bullet names the doc that holds the Sentry notes. Open that doc at the heading the bullet names (read that section only, not the whole file) and write down:

- `<org>`: the Sentry organisation slug;
- `<projects>`: every project slug, with the short-id prefix its issues carry;
- `<access>`: how to reach Sentry from this machine (token environment variable `<VAR>`, a CLI, an MCP server, or the signed-in browser);
- `<release format>`: the release tag format of each surface, so an event can be dated against `git log`;
- `<entry points>`: where each surface's errors enter Sentry (the log-to-Sentry bridge, the uncaught-error boundaries, the request-error middleware);
- `<triage rules>`: which log level means "a person should look at this", how expected outcomes are logged, how debug/local builds are kept out, where source maps come from and why frames may still be minified, and where owner-only follow-ups are recorded;
- `<records>`: where owner-only follow-ups and changelog lines go;
- `<checks>`: the analyze, format and test commands for an edited package, and which suites need a local stack or must run in chunks.

```sh
rg -n '^- \*\*(Records|Checks and tests)\*\*' .agents/project-facts.md | head -n 5
```

Use that output for `<records>` and `<checks>` if the Sentry doc does not name them.

Done when: you can state `<org>`, `<projects>` and `<access>`. If the Step 1 command prints nothing, or the notes name no org or projects, stop and ask: "Which Sentry org and project slugs should I use?"

## Step 2: Pull the issues

Pick the first route that `<access>` allows and that works:

| Route | How |
|---|---|
| Token | Check it is set without printing it (command below; prints `1`). Then call the REST API with `curl -H "Authorization: Bearer $<VAR>" https://sentry.io/api/0/organizations/<org>/...`. It needs only `event:read` and `project:read`. |
| An MCP server or CLI that `<access>` names | Use it. |
| The user's browser | Load the browser tools, open `https://<org>.sentry.io/issues/`, and call the same API paths from the page with `fetch('/api/0/organizations/<org>/...')`. The session cookie authenticates them. If the page shows the login screen, ask the user to sign in. Never enter their password, even if the browser autofills it. |
| None works | Stop and ask: "How can I reach Sentry from here?" |

```sh
env | grep -c <VAR> | head -n 1
```

A wrong `<org>` returns 404, not an empty list. If every call 404s, recheck `<org>` first. If a call fails twice with the same error, stop and report the output.

Calls (all read-only):

- Issue list: `/api/0/organizations/<org>/issues/?query=is%3Aunresolved&statsPeriod=90d&limit=100&project=-1&sort=freq`. If 100 come back, page with the `Link` header's cursor.
- Latest event per issue: `/api/0/organizations/<org>/issues/<numeric id>/events/latest/`. The numeric `id` is not the short-id.
- All events of one issue (bursts, per-user spread): `/issues/<id>/events/?limit=100&full=true`.
- Whether source maps were ever uploaded for a project: `/api/0/projects/<org>/<project>/files/artifact-bundles/`.

Browser-route gotchas:

- The rate limit is about 15 requests a second. `Promise.all` over dozens of issues gets most of them a `{"detail":"…too frequently…"}` body. Fetch sequentially with a ~120 ms gap, then check every result has `entries`.
- A browser JavaScript tool's output is usually capped (around 1,000 characters). Keep the raw data in `window.__issues` / `window.__events` and print slices of about 9 rows: short-id | count | users | last seen | title cut to 85 characters.
- Output that looks like a query string or cookie may be blocked. Print summaries, not raw JSON.

Done when: you hold one record per unresolved issue in scope, and each has `entries` from its latest event.

## Step 3: Read each event

This step is judgement; no command. For each issue read off:

- Tags `environment`, `release`, `browser`, `url`, `transaction`. Read the release against `<release format>` and compare it with `git log` to see how old the build is.
- Message or exception. A `message` entry is usually an error-level log line promoted by the log bridge. An `exception` entry is a thrown error; one with no handler mechanism is often an unawaited, fire-and-forget future.
- Stack frames, filtered to the project's own packages. Minified frames (a web build without uploaded source maps) cannot be traced by line: find the code by the log message text instead.
- Breadcrumbs, the log lines before the event. Count each breadcrumb's call site to see what fired repeatedly. `[Filtered]` is Sentry's own scrubber hiding a line, not missing data.

Done when: every issue has a release age, a cause hypothesis and a code location (or "unlocatable: minified").

## Step 4: Triage against the current tree

Hand each package area to a read-only subagent if your CLI has them, with each issue's message, release and breadcrumbs pasted in. Otherwise do them yourself. Give each issue exactly one status:

| Status | Meaning and action |
|---|---|
| LIVE | The code that produced it is still there and still wrong. To be fixed. |
| FIXED | The code changed after the event's release, or the data it hit has since been reset. Cite the commit or line. |
| NOISE | An expected outcome logged as an error (an expected 4xx, a transport failure the cache covered, a refused request). Fix by lowering the log level at the call site. If the log line lives in a third-party package the project cannot edit, filter it at the project's Sentry bridge instead. |
| LOCAL | The event came from a developer machine (`url` on `localhost`, an unstamped release). Confirm the gate that keeps debug builds from reporting still holds. Do not chase framework errors from it. |
| CONFIG | Needs a dashboard, key or account action only the owner can take. Record it in `<records>` (owner-only follow-ups); grep for an existing entry first, with `| head -n 5`. |

Rules:

- Verify against the current tree before calling anything LIVE. Sentry's line numbers are from the event's build. When another session has uncommitted edits, compare with `git show HEAD:<file> | head -n 200` as well as the working tree.
- A burst (dozens of events from one user in seconds) is a loop. Group its events by user and by session or boot before deciding what repeats.

Print the list in your reply before fixing anything, grouped LIVE (most events first), NOISE, LOCAL, CONFIG, FIXED. One line per issue:

```text
<short-id> | <events>/<users> | LIVE | <root cause> | <file>:<line>
```

Done when: every issue has one status and one printed line.

## Step 5: Fix

Fix every LIVE and NOISE issue, plus the gate for LOCAL ones, in this repo.

- If other agent sessions share this tree, claim files first the way the project's notes say. Build on any edits already on disk. Never run `git checkout -- <file>`.
- Pinning tests win. Before changing an error contract, run the tests that cover it (narrowest first, per `<checks>`). If a test pins the current behaviour, fix the callers, not the contract.
- Fix root causes, not dressings. An uncaught fire-and-forget future gets a handler that tells the user; do not silence it. A noisy-but-expected log gets the right level; a real error stays an error.
- A bug in a third-party package: fix it on the project's side where the package's public interface allows. Otherwise record the needed package change in `<records>`, naming the symptom the project sees.

Done when: each LIVE and NOISE issue has an edit, or a CONFIG entry, or a stop question to the user.

## Step 6: Verify

The commands come from `<checks>` (this step has no fixed command). Run the analyze and format commands in every edited package. Then run the narrowest tests that cover the change, the way `<checks>` says. Run the full gates only when the user is about to deploy.

Done when: analyze, format and the covering tests all pass. If a command fails twice with the same error, stop and report the output.

## Step 7: Close

This step is judgement and writing; the record command comes from `<records>`.

- Record each behaviour change in `<records>` (a changelog line, usually) using the project's own add-line command if the notes name one.
- Write the reasoning into the doc that owns the subsystem, and add any new triage rule to the Sentry notes so the next run finds it.
- Then raise the resolve-in-Sentry offer from the Ask points. Do nothing in Sentry without a yes.

Done when: each fix has its record line and every new triage rule is written down.

## Step 8: Summary

Write the summary in your reply only, in this shape:

```text
pulled: <project>: <n>, <project>: <n>
triage: LIVE <n> / NOISE <n> / LOCAL <n> / CONFIG <n> / FIXED <n>
fixed: <short-id> <what changed> <file>:<line>
left: <short-id> <why: CONFIG recorded in <where>, cost decision, unlocatable minified crash>
tests: <command> -> <result>
```

Done when: every issue pulled appears in exactly one of `fixed`, `left` or FIXED.

## Done means

- Every issue has one status and was printed in Step 4.
- The Step 6 analyze, format and test commands passed (exit 0).
- No issue was resolved, ignored or changed in Sentry without a yes from the user.
