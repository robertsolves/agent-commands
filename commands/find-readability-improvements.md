---
description: Find the code a tired human would struggle to read — mode flags threaded through layers, components or functions doing several jobs, logic buried in UI code, parameter lists that travel together unnamed, states the types allow but the product forbids, two names for one concept — rank the worst, ask which to fix, then fix them without changing behaviour. Run when a file feels hard to skim, after a fast feature push, or as periodic hygiene. Not for lint-level checks (names, nullability, `late`) — use /dart-audit-code; not for comments — use /find-bad-comments.
argument-hint: "[path or area to focus on] (default: the most-edited files of the last 30 days)"
---

# /find-readability-improvements

A cold read of the code as its owner would meet it at 11pm: can someone open a file and know what it does without decoding, holding five things in their head, or tracing a value through four layers? This command finds structure a linter cannot see.

Order: find and verify (Steps 1–4), ask (Step 5), then fix only what is confirmed (Step 6). Never fix before the user answers Step 5. Edit only the files a confirmed finding names, plus the audit record.

## Step 1: Load the project facts

```sh
rg -n 'Audit records|Readability and comments|UI and business code|Checks and tests' .agents/project-facts.md | head -n 8
```

Read those four bullets of `.agents/project-facts.md`. Write down: the audit record for `/find-readability-improvements`, the readability bar and its doc, the screen/file shape pattern, and the checks to run after a change.

Done when: your notes hold those four items. If the command prints nothing, stop and ask: "Where are this project's readability bar, audit record and post-change checks?"

## Step 2: Pick the files

| `$ARGUMENTS` | Files to read |
|---|---|
| empty | the 20 files printed by the command below |
| a path to a file or folder | the source files under it, at most 20 (most recently changed first) |
| anything else | stop and ask: "Which path is `<argument>`?" |

```sh
git log --since=30.days --name-only --format= | grep -E '\.(dart|ts|tsx|js|jsx|vue|svelte|py|go|rs|rb|java|kt|swift|cs|php|ex|sql|sh)$' | grep -vE '\.(g|freezed|mocks|gen|generated|pb)\.|(^|/)(test|tests|__tests__|spec)/|[._](test|spec)\.' | sort | uniq -c | sort -rn | head -n 20
```

Each line is `<edit count> <path>`. Churn is where readability decays. Skip generated files, data files and tests.

Done when: your notes hold the list of at most 20 paths.

## Step 3: Re-verify the audit record

Open the audit record from Step 1 (if it does not exist, it is created on first run). Check each open entry against the code:

| The entry is | Action |
|---|---|
| still true | keep it |
| fixed | strike it through and add the date |
| wrong | delete it |

Add one dated verification line at the end of the record. Edit only that file.

This step is judgement against the code; it has no command.

Done when: every open entry is kept, struck or deleted, and the dated line exists.

## Step 4: Read each file cold, flag, and record

Read each Step 2 file top to bottom once, as a stranger, before searching for anything. Note where you had to stop and work something out: that pause is the finding. Name it with one of these flags:

| # | Flag | The fix wants |
|---|---|---|
| 1 | A mode as a flag: a bool or nullable callback passed down several levels, or a mode inferred from an unrelated null | a named enum |
| 2 | One unit, several jobs: a widget, component or function whose body forks into different results by flag | a split, with the shared part put somewhere deliberate, not copy-pasted |
| 3 | Logic in the view: permissions, date bucketing or state derivations computed inside rendering code | a named, testable place |
| 4 | Parameters that travel together: the same arguments declared at several levels | one named group |
| 5 | Illegal states representable: two nullable fields "mutually exclusive", or a status plus a flag that can contradict it | a sealed or union type, or an assert |
| 6 | Two names for one concept across layers (column, wire key, model field, parameter, UI), or one name for two concepts | one name everywhere |
| 7 | The file is not the shape the project's pattern (Step 1) expects for its kind | the project's shape |
| 8 | Cleverness: a parametric helper replacing three similar lines, an abstraction with one call site, a transform chain where a flat `if` reads in one pass | the plain version |
| 9 | Distance: a value whose meaning you learn three files away, a constant far from its only use | moving it next to its use |

For each finding write `file:line`, the flag number, one sentence on what made you stop, and the fix shape. Order by reading time cost to the owner, not by ease of fix. Write the findings into the audit record from Step 1, in its existing format. A finding that is also a real bug (the confusing code is wrong) goes to the project's bug list from the **Records** bullet of `.agents/project-facts.md` instead.

This step is judgement against the code; it has no command.

Done when: every finding is in the record or the bug list, or you wrote "no findings" in your reply.

## Step 5: Present and ask

Print a numbered list in your reply, worst first, at most 10 per round. Each item has the `file:line`, the flag, and a before/after sketch of the shape (not the full diff). Ask per finding: **fix** / **leave** (record why in the audit record) / **defer**. Wait for the answers.

This step is a question to the user; it has no command.

Done when: every listed finding has an answer from the user.

## Step 6: Fix the confirmed findings

For each finding answered **fix**:

1. Make the change behaviour-preserving. If no existing test pins the behaviour you are restructuring, add one first.
2. Do the whole change: when a concept is renamed, rename it everywhere it travels, including docs and tests. Leave nothing half-renamed.
3. Re-read the file cold. If it is not easier to skim, the change is not done.
4. Mark the entry fixed in the audit record with the date.

Then run every check listed in the **Checks and tests** bullet (Step 1). If a check fails twice with the same error, stop and report the output.

Done when: every confirmed finding is marked fixed and every check passes.

## Done means

- Every open record entry is kept, struck with a date, or deleted, and has a dated verification line.
- No file was edited before the user answered Step 5.
- Every **fix** finding is marked fixed with a date, and every check from Step 1 passes.
