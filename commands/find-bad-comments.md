---
description: Find comments that mislead or waste the reader — claims the code no longer backs (numbers, dates, history, invariants), descriptions of old behaviour, comments that restate the code, undefined jargon, backstory essays — and the places a why-comment is missing, verify each against the code and git history, ask which to fix, then rewrite or delete them. Run after a big refactor, before handing code to a new reader, or as periodic hygiene.
argument-hint: "[path or area to focus on] (default: the most-edited files of the last 30 days)"
---

# /find-bad-comments

A wrong comment is worse than no comment: the reader trusts it over the code. Treat every comment as a claim and check it. Order: find and verify (Steps 1–4), ask (Step 5), then fix only what the user confirmed (Step 6). Never edit a source file before Step 6.

## Step 1: Load the project facts

```sh
rg -n '^- \*\*(Audit records|Readability and comments|Records|Search helpers|Checks and tests)\*\*' .agents/project-facts.md | head -n 5
```

Read only those bullets. Note three things: the audit record path for `/find-bad-comments`, the file holding the comment rules, and the checks to run after a change.

Done when: you can write down those three items. If a bullet is missing, stop and ask: "Where do this project's comment rules, audit record and post-change checks live?"

## Step 2: Pick the files

`$ARGUMENTS` empty → use the default list. Otherwise use the path or area it names.

```sh
git log --since='30 days ago' --name-only --pretty=format: | grep -v '^$' | grep -v -E '\.(g|freezed|mocks|gen|generated|pb)\.[a-z]+$|(^|/)generated/|^CHANGELOG' | sort | uniq -c | sort -rn | head -n 20
```

Each line is `<edit count> <path>`. Skip generated files. Add the agent rule files (every agent reads them, so a wrong claim there spreads). Then open the audit record from Step 1 (`<audit record>`) and re-check each open entry; strike fixed ones with today's date.

Done when: you have a list of at most 20 files plus the open entries re-checked. Write the list in your reply, not to a file.

## Step 3: Verify every claim

For each file, read it in line ranges (about 200 lines at a time). List what each comment asserts and check it:

| Comment claims | Check by |
|---|---|
| A number (limit, count, timeout, size) | find the value in the code: `rg -n --max-count 5 '<constant>' <path> \| head -n 20`. 30 days next to a constant of 7 is a finding |
| Behaviour ("retries three times", "never null here", "runs before X") | read the code path. An invariant the code does not enforce is a finding even if it holds today |
| History or origin ("added because of the iOS bug") | `git log -S'<phrase>' --oneline -- <path> \| head -n 5`, then `git blame -L <line>,<line> <path>`. A comment may say what a line governs; it must not assert an unverifiable origin. Unknown origin becomes a `TODO` asking, or nothing |
| A date or version | compare with today's date and the pinned version file |
| Anything else | read the code beside it; if you cannot tell, mark it "unverified" and do not flag it |

Done when: every comment in the listed files has been checked or marked unverified.

## Step 4: Classify and record

Flag each failed comment with one class:

| Class | Meaning |
|---|---|
| 1 False or unverifiable | the claim fails Step 3 |
| 2 Old behaviour | true once, not since a change |
| 3 Restates the code | says what the next line says; delete it |
| 4 Undefined jargon | an internal term, acronym or ticket id the reader must already know; define it in plain words, or drop it |
| 5 Backstory essay | a paragraph of history where one line of why would do |
| 6 Missing why | a line that looks wrong or deletable and is not (workaround, ordering requirement, deliberate exception) |
| 7 Comment is right, code is wrong | the comment states the intent and the code fails it |
| anything else | skip it |

Write each finding into the audit record, in its existing format, as:

```text
12. src/<path>:42 — class 1 — says "retries 3 times"; the code retries 5 (<path>:40) — replace with "retries 5 times"
```

Class 7 goes to the bug list the **Records** bullet names, not into a comment rewrite. This sweep does not chase references that point at nothing or restructure code.

Done when: every finding has `file:line`, class, claim, evidence and replacement text (or "delete"), and is in the record.

## Step 5: Ask

Show a numbered list in your reply: classes 1, 2, 6 first, then 3, 4, 5; at most 15 per round. Ask: "For each number: fix, leave or defer?" Stop and wait for the answers. No answer means no edits.

Done when: every listed number has an answer.

## Step 6: Fix what was confirmed

Edit only the comments marked fix, with your file-edit tool (never `sed -i`).

1. Rewrite or delete each one. Keep the replacement short, plain and checkable from the code beside it.
2. If a deleted backstory held a reason a future reader needs, move it, in one or two sentences, to the doc that owns the subsystem (use the **Search helpers** bullet to find it).
3. Mark the entries fixed in the audit record with today's date.
4. Run the checks from Step 1 (comment-only edits still need the formatter). If a check fails twice with the same error, stop and report the output.

Done when: the checks pass and the record shows each fixed entry with a date.

## Done means

- No source file was edited before the user answered Step 5.
- The audit record holds every finding with a date.
- The post-change checks from Step 1 pass.
