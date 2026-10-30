---
description: Find band-aid fixes left behind by AI sessions — swallowed errors, suppressions, magic delays, special-case patches — trace each to the root cause it papers over, ask the user which to fix properly, then implement the real fix. Run after a stretch of fast agent-driven changes or when a subsystem feels patched-over rather than solved. Not for a read-only report of AI-agent anti-patterns — use /audit-slop.
argument-hint: "[path or area to focus on] (default: whole repo, recent code first)"
---

# /find-bandaids

A **band-aid** is a change that made a symptom go away without fixing the cause: a swallowed exception, a null guard, a delay, a suppression. This command finds them, names the cause each one hides, asks the user, then fixes only what the user confirms.

Order: find (Steps 2–3), trace the root cause (Step 4), ask (Step 5), then fix (Step 6). Never edit code before the user answers in Step 5: a site that looks like a band-aid may be a sanctioned workaround. Until Step 6, write findings in your reply and edit no file.

## Step 1: Load project facts and resolve scope

```sh
rg -n '^- \*\*(Records|Deliberate workarounds|Search helpers|Checks and tests)' .agents/project-facts.md | head -n 5
```

Done when: you have read those four bullets in full and noted `<bug-file>` (open bugs) and `<todo-file>` (deferred work). They name the records (where kept and deferred findings are parked), the `NOTE(band-aid-audit)` marker, the sanctioned workarounds, the search helpers and the checks to run after a change. If the command prints fewer than 4 lines, stop and ask: "project-facts.md lacks a bullet this command needs — where are the project facts?"

Scope: if `$ARGUMENTS` names a path or area, use it. If it is empty, use the whole repo.
Done when: you can state the scope in one line.

If the **Search helpers** bullet names no script of its own, use the ones in the `search-helpers` skill: `bash .agents/skills/search-helpers/scripts/find_symbol.sh` is the symbol finder, `bash .agents/skills/search-helpers/scripts/capped_grep.sh` the grep helper and `bash .agents/skills/search-helpers/scripts/doc_drift.sh` the drift tool.

## Step 2: Sweep for signatures

Run each command with the scope as `<scope>` (`.` when whole repo).

```sh
git log --since='30 days ago' --name-only --pretty=format: -- <scope> | sort -u | head -n 60
rg -n -i --max-count 3 'HACK|WORKAROUND|FIXME|XXX|for now|temporar|quick fix|band-?aid|stopgap|to unblock|revisit|papering' <scope> | head -n 80
rg -n --max-count 3 'ignore:|eslint-disable|noqa|SuppressWarnings|skip:|xit\(|@Skip' <scope> | head -n 80
```

The first command lists recently changed files: read those first, since band-aids concentrate where agents worked last. The other two print `file:line:text` markers and suppressions, or nothing.

Then read the recently changed files for these smells (this part is judgement against the code; it has no command):

| Smell | What to look for |
|---|---|
| Swallowed error | a `catch` that returns a default, empty or null with no rethrow, where the error signals an upstream bug |
| Arbitrary timing | sleeps, delays, retry loops or widened timeouts added to dodge a race |
| Silencing guard | `if (x == null) return;`, force-unwrap, cast, dynamic type, or a field made nullable to stop a crash |
| Special case | a branch keyed to one id, env, name or caller |
| Duplication | logic pasted at a call site because fixing the shared helper looked risky |
| Weakened test | loosened expectation, widened tolerance, deleted assert |

Session transcripts are the best source: agents announce a band-aid as they apply it. The path pattern is in the project facts (**Session transcripts** bullet, if present):

```sh
rg -l -i 'workaround|for now|band-aid|temporary|to unblock' <transcript-dir> | head -n 10
```

For each hit, `rg -n -i --max-count 3 'workaround|for now|band-aid|to unblock' <file> | head -c 3000`, map the admission to a code site, and check the site still exists.

Done when: you hold a candidate list of `file:line` sites (write "no candidates" if empty).

## Step 3: Drop sanctioned and already-recorded sites

For each candidate, in this order:

| The site… | Action |
|---|---|
| is in the **Deliberate workarounds** bullet or documented in a doc | drop it: it is a decision |
| carries a `NOTE(band-aid-audit)` comment | drop it: the user accepted it in an earlier run |
| is already in `<todo-file>`'s `# Bandaids` section or in `<bug-file>` | drop it, or propose promoting it to a fix in Step 5 |
| none of the above | keep it |

```sh
rg -n 'NOTE\(band-aid-audit\)' <scope> | head -n 40
sed -n '/^# Bandaids/,/^# /p' <todo-file> | head -n 80
rg -n --max-count 3 '<file or symbol>' <bug-file> <todo-file> | head -n 10
```

Done when: each candidate is kept or dropped, with the reason. This step reads and filters; it edits nothing.

## Step 4: Root-cause each kept finding

Run per site:

```sh
git log -n 5 --format='%h %ad %s' --date=short -L <line>,<line>:<file> | head -n 40
```

Read the surrounding code. Answer in one line each: what failure was hidden, what is the actual cause, what is the proper fix. If you cannot answer, mark the finding LOW confidence and say what is unknown. This step is judgement against the code; it has no other command.

Trace to the producer before choosing a fix: a dressing often sits in the file that noticed the problem, not the file that causes it (a reader filtering out interference instead of the writer stopping it; a caller guarding a value the producer should never emit). A guard whose signal a fail-soft `catch` downstream can swallow is not a guard: record the fact and assert on the record.

Done when: every kept finding has dressing, disease and fix, or is marked LOW.

## Step 5: Present and ask

This step asks the user and waits; it has no command. Write at most 10 findings per round, worst first, in your reply only:

```text
1. src/orders/save_order.ts:42  [HIGH]
   Dressing: catch returns an empty list.
   Disease: the loader throws when the cache is cold.
   Fix: await the cache before reading; about 30 minutes; behaviour changes (an error is shown).
```

Ask for each finding: **fix** / **keep** (it is intentional) / **defer**. Stop and wait for the answers. If the user gives no answer for a finding, leave it untouched and unrecorded.

Done when: every finding has an answer.

## Step 6: Fix, keep or defer

Handle each finding by its answer:

| Answer | Action |
|---|---|
| fix | 1. Fix the root cause and remove the band-aid in the same change. 2. If it masked a reproducible failure, add a regression test that fails on the old symptom. 3. Say in your reply any user-visible change. |
| keep | Leave the code alone. Add a `NOTE(band-aid-audit): <why it stays>` comment at the site, and a one-line why in the doc that owns the subsystem if the workaround is undocumented. |
| defer | Add an entry under `# Bandaids` in the record the project facts name for no-failure-mode findings; use the bug list when the failure is concrete. A chat mention is not a record. |

Edit only the files of confirmed findings, the records above and the docs for "keep". Use your file-edit tool. Then list what you changed:

```sh
git diff --stat | head -n 40
```

Then run the checks from the **Checks and tests** bullet for every package you touched, and add the changelog line the project requires for a behaviour change. If a check fails twice with the same error, stop and report the output.

Done when: every finding is fixed, kept or recorded, and the checks pass.

## Done means

- Each kept finding has an answer from the user, and no code changed before it.
- No fixed band-aid remains at its site:

```sh
rg -n '<the dressing text>' <file> | head -n 5
```

  Expected: no output for every fixed site.
- The project checks from Step 1 print their success line for the touched packages.
