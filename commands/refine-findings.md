---
description: Take a findings document (a bug list, audit report, TODO file), verify every finding against the actual code, delete the wrong or already-fixed ones, correct and deepen the rest, add a few closely related new findings in the doc's own style, then verify those too. Run when a findings doc is stale, unverified, or thin. Not for writing a new audit from scratch — use the matching /find-* command, or /kilo-refine-findings to have the free Kilo CLI refine it round after round.
argument-hint: "<doc-path> [focus words]"
---

# /refine-findings

Edits the findings document only, never the code it describes. Every token read is re-billed on every later turn, so: read line ranges, never whole large files; give every search a cap; use a subagent only for a large read.

## Step 1: Resolve the document

`$ARGUMENTS` is the doc path, then optional focus words (e.g. `docs/audit/api_bugs.md auth`).

| `$ARGUMENTS` | Action |
|---|---|
| empty | stop and ask: "Which findings document should I refine?" |
| a path | `ls <doc-path>` |
| a name without a path | `rg --files -g '*<name>*' | head -n 5` |
| the name matches more than one file | stop and ask: "Which of these files?" |

Done when: `ls <doc-path>` prints the path, and `<doc-path>` and `<focus>` (may be empty) are fixed.

If the **Search helpers** bullet names no script of its own, use the ones in the `search-helpers` skill: `bash .agents/skills/search-helpers/scripts/find_symbol.sh` is the symbol finder, `bash .agents/skills/search-helpers/scripts/capped_grep.sh` the grep helper and `bash .agents/skills/search-helpers/scripts/doc_drift.sh` the drift tool.

## Step 2: Load the project facts

```sh
rg -n '^- \*\*(Records|Audit records|Search helpers|Agent prompts)\*\*' .agents/project-facts.md | head -n 5
```

Done when: you can name `<bug-list>` (open bugs file), `<symbol-finder>` and `<grep-helper>` (the search helpers), `<audit-records>` (the other findings docs) and `<changelog-command>` (the "Changelog:" command in the Agent prompts bullet). If the bullets are missing, use plain `rg` and write `<changelog-command>` as none.

## Step 3: Learn the doc

```sh
head -n 40 <doc-path>
rg -n '^#' <doc-path> | head -n 80
```

Read the first two entries in full, then only headings. Never read a large history file whole. Write down:

- **Purpose**: what a finding in this doc is (a bug, a smell, a missing test, a risk).
- **Entry shape**: heading, fields, severity tags and ordering. Every edit and new entry copies it exactly.
- **Evidence form**: how entries point at code (`file:line`, symbol, route).

This step is judgement; it has no further command. If the doc is not a list of code-grounded claims, stop and say so.

Done when: you have written Purpose, Entry shape and Evidence form in your notes.

## Step 4: Give each finding a verdict

Judge every finding against the code in the working tree. Per file, run one capped search, then read a line range only where doubt remains:

```sh
rg -n --max-count 3 <symbol> <file> | head -c 4000
```

Re-derive the claim from the code; do not trust the doc's wording, line numbers or "confirmed" tags. Look for the usual false alarms: a guard one layer up, a keyed list or pinning test that makes the path unreachable, a sibling that already handles it. Only when a finding looks fixed and the code does not say so, run `git log -S<symbol> --oneline -3 -- <file> | head -n 3`.

| Code says | Verdict | Action in Step 5 |
|---|---|---|
| does what the finding says | accurate | expand if thin |
| real, but citation, name or wording is stale | drifted | fix the wording |
| the problem is gone | fixed | delete the entry |
| the problem never existed | false | delete the entry |
| needs a live environment, a credential or the owner | unverifiable | keep; state what is needed |
| anything else | | stop and ask: "Finding <heading>: I cannot tell which verdict fits — what should I do?" |

Above about 25 findings, hand slices by file area to a cheap-model subagent with the exact entries, the evidence form and a one-line-per-finding verdict format. Re-check any `false` or `fixed` verdict yourself before applying it.

Done when: every finding has one verdict in your notes.

## Step 5: Fix the doc

Edit the doc with your file-edit tool, in one pass. Write only in `<doc-path>`; if a bug is already fixed with no changelog line, Step 6 adds it.

- Delete `fixed` and `false` entries completely: no strikethrough, no "resolved" section. Then `rg -n '<removed heading>' <doc-path> | head -n 5` must print nothing.
- Correct `drifted` citations and wording.
- Expand each thin `accurate` entry with facts you saw in Step 4 only: the failure scenario (input or state, then wrong output), the root cause location, what a fix touches. Leave complete entries alone.
- Keep the doc's order, severity tags and house style. If the doc's header defines a format, follow it.

Done when: the doc holds no `fixed` or `false` entry and the `rg` check prints nothing.

## Step 6: Record deleted bug fixes

For each deleted entry that was a bug fixed in code, check whether the fix already has a changelog line. Find the fixing commit date with `git log -S<symbol> --format=%cs -1 -- <file> | head -n 1`.

| Situation | Action |
|---|---|
| the fix has no changelog line | run `<changelog-command> "<one line>"` |
| it already has one | do nothing |
| `<changelog-command>` is none | stop and ask: "Fixed bug <heading> has no changelog line and I have no command to add one — add it by hand?" |

If the entry also sits in `<bug-list>`, delete it there too (search first: `rg -n '<symbol>' <bug-list> | head -n 5`). No fixed bugs deleted → nothing to do.

Done when: each deleted fixed bug has a changelog line, or the list is empty.

## Step 7: Expand, within bounds

Look for new findings of the doc's own kind and no other. Do not go out of your way. Search only where Step 4 pointed:

- The same pattern in sibling files: take each accurate finding's signature and run `rg -l <signature> <package-dir> | head -n 20` once.
- The twin of each confirmed finding (the SQL mirror, the anonymous variant, the other platform, the other endpoint in the same family).
- Anything you tripped over while verifying.

Limits: at most 10 new findings; no content greps over a whole package; no category the doc lacks; with a `<focus>`, ignore everything outside it. Dedupe against the doc, `<bug-list>` and `<audit-records>` using `<grep-helper>`. Stop early when the trail goes cold. Write each in the doc's entry shape and evidence form, marked `suspected` only if the doc distinguishes confidence levels.

Done when: you have added 0 to 10 entries and listed each in your notes.

## Step 8: Audit the new findings

Repeat Step 4 on only the new entries, as if someone else wrote them: re-open each cited line, look for the guard that makes it a non-issue, delete any that fail, fix any that drifted. One round only; do not expand again. This step is judgement against the code; it has no command beyond the Step 4 search.

Done when: every new entry has a verdict and the failing ones are deleted.

## Step 9: Report

Reply in chat, not in a file:

```text
<doc-path>: existing N -> kept A, reworded D, deleted X (fixed F, false B), unverifiable U; new: proposed P, survived S
deleted: <heading> - <reason>
owner: <unverifiable heading> - needs <what>
```

One `deleted:` line per deleted finding and one `owner:` line per unverifiable one.

Done when: the reply holds the counts line and one line per deleted finding.

## Done means

- `rg -n '<removed heading>' <doc-path> | head -n 5` prints nothing for each deleted heading.
- Every entry in the doc has a verdict of accurate, drifted or unverifiable, and every new entry survived Step 8.
- No file other than `<doc-path>`, `<bug-list>` and the changelog was edited.
