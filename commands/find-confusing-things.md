---
description: Find what contradicts itself or doesn't add up across the project — docs that disagree with each other or with the code, one word meaning two things, plans the code quietly abandoned, product behaviour that would confuse a user, scenarios nobody thought through — and turn each into a forced-choice question for the owner, then apply the answers to code and docs. Run before a release, after a burst of design changes, or when the project feels inconsistent. Not for one doc or one source file — use /interview-docs or /interview-code.
argument-hint: "[area, doc or feature to focus on] (default: the whole project)"
---

# /find-confusing-things

Bugs are code doing the wrong thing. This command hunts the step before: places where nobody could say what the right thing *is*, because two sources disagree, a word means two things, or a case was never decided. Each finding ends as a question only the owner can answer.

Two phases: **find and ask** (Steps 1–6), then **apply** (Step 7). Never change code or docs before the owner answers. Findings go in the audit record, not in new files.

## Step 1: Load the project facts

Your project facts come from one file. Run:

```sh
rg -n '^- \*\*(Audit records|Product brief|Records|Search helpers|Checks and tests)\*\*' .agents/project-facts.md | head -n 8
```

Those five bullets give: this sweep's audit record `<audit-record>`, the product brief, the glossary and scope docs, `<symbol-finder>` and `<drift-tool>` search helpers, and the checks to run after a change.

Done when: the output shows five bullets. If it shows fewer, stop and ask: "The project-facts file lacks `<bullet name>` — where is it recorded?"

If the **Search helpers** bullet names no script of its own, use the ones in the `search-helpers` skill: `bash .agents/skills/search-helpers/scripts/find_symbol.sh` is the symbol finder, `bash .agents/skills/search-helpers/scripts/capped_grep.sh` the grep helper and `bash .agents/skills/search-helpers/scripts/doc_drift.sh` the drift tool.

## Step 2: Set the scope

This step is judgement; it has no command. If `$ARGUMENTS` names an area, doc or feature, stay there. If it is empty, cover the whole project, product docs first.

Done when: you can say the scope in one line.

## Step 3: Re-check the audit record

```sh
ls <audit-record> && head -n 80 <audit-record>
```

This prints the record's first 80 lines; read further in ranges. If it does not exist, create it in the format of another record named in the Audit records bullet (created on first run). Re-check each open entry against the current docs and code: an entry already applied is struck with today's date.

Done when: every open entry is either still open or struck with a date, and you can name the count of each.

## Step 4: Read the sources of truth

This step is reading; it has no command. Read the product brief, the glossary, the scope doc and the architecture overview (paths from the Product brief bullet). Note every rule they state about behaviour: limits, permissions, flows, retention.

Done when: you hold a list of stated rules to compare against.

## Step 5: Hunt each class

Search with `<symbol-finder>` and `<drift-tool>` (Search helpers bullet), always with a path and a cap. For each class, check the second source before claiming a clash:

| Class | Check |
|---|---|
| Docs that disagree | Search the second doc for each rule the first states |
| Docs versus code | Read the code path itself; never trust a third doc |
| One word, two meanings (or two words, one meaning) across docs, UI text, code and wire | Compare against the glossary; a term it lacks is a candidate |
| Plans the code abandoned | A plan or design doc describing an approach the code went another way on, still read as current |
| Confusing to a user | Two screens naming one thing differently, an action whose result contradicts its label, a setting that silently overrides another, an error that blames the wrong cause |
| Not thought through | What happens offline, on a second device, for a second member, when empty, after account deletion, at a limit, across a time zone or day boundary |

Done when: each class has been checked and you hold a list of candidates, each with two `file:line` sources. A candidate with only one source is dropped.

## Step 6: Write the questions and ask

Write each finding into `<audit-record>` in its existing format, then ask the owner. A finding has this shape:

```text
N. <title>
   Sources: <path>:<line> says A; <path>:<line> says B.
   Why it matters: <one sentence for a user>.
   Question: A or B?
     A) <option> (recommended: <why>)
     B) <option>
```

Two to four options, one marked and explained. "What should happen?" is not a question. Ask in batches of three, most user-visible first, and wait for each batch's answers before sending the next. Do not edit code or docs in this step.

Done when: every finding is in the record and has an answer, or the owner has said to skip it.

## Step 7: Apply the answers

For each answer, edit with your file-edit tool:

1. Make code, UI text and every doc that disagreed say the same thing. Record the decision once, in the doc that owns the subsystem; make the others agree with it.
2. If behaviour changed, add or update a test that pins it.
3. Strike the entry in `<audit-record>` with today's date and the decision.

Then run the checks from the Checks and tests bullet and the `<drift-tool>` doc-drift checks. If a check fails twice with the same error, stop and report the output.

Done when: every answered entry is struck in `<audit-record>` and the checks pass.

## Done means

- `<audit-record>` has no open entry that the owner has answered.
- The checks from the Checks and tests bullet pass.
