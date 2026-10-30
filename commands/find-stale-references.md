---
description: Find references that point at nothing — doc links and paths to moved files, backticked symbols that were renamed, slash commands that no longer exist, env vars and script names a script still uses, code comments citing dead functions — fix or delete each, and propose a check that would catch the class automatically. Run after renames, moves and deletions, or when docs feel out of date. Not for re-syncing whole core docs with the code — use /update-docs.
argument-hint: "[path or area to focus on] (default: every doc, command, script and code comment)"
---

# /find-stale-references

A stale reference is a dead end for every reader. This command checks only that the thing named exists and is the thing meant. Order: find and verify, ask, then fix only what the user confirmed. Write nothing to a file until Step 4.

## Step 1: Load the project facts and set scope

```sh
rg -n '^- \*\*(Audit records|Search helpers|Checks and tests)\*\*' .agents/project-facts.md | cut -c1-400 | head -n 5
```

Done when: you have this sweep's audit record path (the `/find-stale-references` entry), the checks to run after a change, and two scripts from the **Search helpers** bullet: `<symbol-finder>` (the symbol script) and `<drift-tool>` (the one that finds dead doc and comment citations). A script the bullet gives by bare name lives in the same folder as the first full script path in that bullet; paths are relative to the repo root. Check both with `ls <symbol-finder> <drift-tool>`. The commands below use those placeholders.

| `$ARGUMENTS` | Scope | `<scope>` |
|---|---|---|
| empty | every markdown doc, command and skill file, script and code comment | `:` (matches every line) |
| a path or area | only findings in files under it; leave everything else alone, even when the tool reports it | the path, for example `docs/guides/setup.md` |

If the **Search helpers** bullet names no script of its own, use the ones in the `search-helpers` skill: `bash .agents/skills/search-helpers/scripts/find_symbol.sh` is the symbol finder, `bash .agents/skills/search-helpers/scripts/capped_grep.sh` the grep helper and `bash .agents/skills/search-helpers/scripts/doc_drift.sh` the drift tool.

## Step 2: Re-check the open entries

Open the audit record. If it does not exist, it is created in Step 4 in the format of another record under the same folder. For each open entry, resolve its reference again (Step 4 table). If it now resolves, strike the entry with today's date.

This step is judgement against the code; it has no command.

Done when: every open entry is struck or still marked open.

## Step 3: Run the existing drift tool

Replace `<drift-tool>` and `<scope>` with the values from Step 1, then run exactly this loop. Do not run the tool with `all` or without the `rg` filter: unfiltered output lists files outside the scope, and none of those is a finding.

```sh
for m in links paths comments workflows indexes; do echo "== $m"; DRIFT_CAP=1000 bash <drift-tool> "$m" 2>&1 | rg -F -- '<scope>' | head -n 40; done
```

Each mode prints dead references as `file:line  -> target` (the output may end `... and N more`). Take every printed line as a finding. A section that prints nothing under its `== <mode>` line has no finding in scope. Do not re-derive by hand what the tool checks.

Done when: all five `== <mode>` lines printed. Write `drift tool: <N> in scope` in your notes, even when `<N>` is 0. If a mode errors, stop and report its output.

## Step 4: Resolve the classes the tool cannot see

The drift tool sees only links, backticked paths and comment cites. A script, command or file named anywhere else (inside a code block, a shell line, a table cell) is yours to check, even when Step 3 printed nothing. When `<scope>` is a path, list every such name in it:

```sh
rg -n -o -- '[A-Za-z0-9_./-]+\.(sh|py|js|mjs|ts|tsx|dart|go|rs|rb|java|kt|swift|cs|php|md|ya?ml|json|toml|sql)\b|(^|[ `(])[/$][a-z][a-z0-9-]+' <scope> | head -n 200
```

Each line is `line:name` for one file, `file:line:name` for a folder. When `<scope>` is `:`, check the files that changed in the last 30 commits instead: `git diff --name-only --diff-filter=d HEAD~30 -- '*.md' '*.sh' | head -n 50`, then run the command above on each.

Resolve every name with the table below. Report a finding only after it was resolved and failed.

| Class | How to resolve it | Fix |
|---|---|---|
| Backticked symbol | `bash <symbol-finder> <Symbol>` prints a declaration or nothing | `git log -S '<name>' --oneline \| head -n 5` shows what it became |
| `/name` or `$name` command | `ls .agents/commands/<name>.md` | new name, or delete the mention |
| Script path, flag, env var, table name used by a script | `ls <script>`; `rg -l --max-count 1 '<name>' <expected folder>` | new path or name |
| CI step, editor task, setting naming a script or path | `ls <path>` | new path |
| Comment citing code ("see `foo()`", "mirrors `Bar`") | info_find.sh as above, then read the cited code: does it still play that role? | new name, or delete the comment |

A moved file's fix is its new home. A deleted thing's fix is deleting the reference and its sentence if the sentence is now meaningless. A reference that may name something outside the repo is `suspected`, with the question stated.

Write each finding into the audit record, grouped by class:

```text
- [confirmed] docs/example.md:12 — `OldName` — renamed to `NewName` (or: delete)
```

Done when: every reference in scope is resolved and the record lists the failures with `file:line`.

## Step 5: Present and ask

Present the list in your reply, grouped by class. For each class the tool missed, propose one automatic check (an extra drift-tool mode, a test or a guard script). Then ask once per class and wait:

"Class `<name>` (`<N>` findings): fix all / review each / skip?"

Anything else the user says → ask again with those three options. Do not edit anything before the answers.

This step is a question to the user; it has no command.

Done when: every class has an answer of fix all, review each or skip.

## Step 6: Fix what was confirmed

1. For each confirmed class, edit the files with your file-edit tool. Never `sed -i` or `perl -i`.
2. Build only the check the user approved, and run it.
3. Mark the fixed entries in the audit record with today's date.
4. Run the checks from Step 1.

This step is file edits; its commands are the project checks from Step 1.

Done when: the drift tool's `links` and `paths` sections show none of the fixed lines. If a check fails twice with the same error, stop and report the output.

## Done means

```sh
bash <drift-tool> links 2>&1 | head -n 20
```

Every fixed reference is gone from the output, and the audit record has a dated line for this run.
