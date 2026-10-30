---
description: Find where the app breaks its own privacy and legal promises — policy retention periods the purge doesn't honour, personal data missing from the export or the deletion, children's-data rules not enforced, consent not recorded on every sign-up path, store privacy labels that don't match what the code collects, and any gap against the privacy-compliance baseline — with evidence from the code, ask which to fix, then fix them, sending anything that needs a lawyer to the owner. Run before launch, after a schema change that adds personal data, and after any edit to the privacy policy or terms.
argument-hint: "[area to focus on: retention | export | deletion | children | consent | stores] (default: all)"
---

# /find-compliance-issues

The privacy policy and terms are promises; this command checks the code keeps them. It is not legal advice: where the right answer is a legal judgement, the finding says so and goes to the owner for counsel. Never state what a law or store policy says from memory: read its text, or mark the finding `suspected`.

Two phases: **investigate and ask** (Steps 1–8), then **fix** (Step 9). Never fix before the user confirms. Phase 1 writes only the audit record from Step 2; it edits no code and no document.

## Step 1: Load the project facts

```sh
rg -n -A2 '^- \*\*(Compliance|Audit records|Records|Checks and tests)\*\*' .agents/project-facts.md | head -n 40
```

Keep these in your notes from the **Compliance** bullet: the compliance doc and its launch checklist, the published legal documents, the schema source, the export, deletion and consent docs, the legal-chain check command, where the owner's tasks go. From **Audit records**: the audit record for this sweep. From **Checks and tests**: the checks to run after a change.

Done when: your notes hold the compliance doc path, the audit record path and the legal-chain check command. If the command prints nothing, stop and ask: "Where are this project's compliance doc, audit record and post-change checks?"

## Step 2: Set the scope and open the audit record

| `$ARGUMENTS` | Scope |
|---|---|
| empty | all areas |
| `retention`, `export`, `deletion`, `children`, `consent` or `stores` | that area only |
| anything else | stop and ask: "Which area: retention, export, deletion, children, consent or stores?" |

Read the audit record (Step 1). Re-check each open entry against the current code and strike the fixed ones with today's date. Note any counsel decision recorded since the last run.

Done when: every open entry is marked still-open or struck with a date.

## Step 3: Run the existing checks

Run the legal-chain or version check from Step 1 (the published documents, their version constants, the acceptance flow).

Done when: the check has run and you have its pass or fail result. A failure is the first finding. If the project has no such check, write `no legal-chain check` in your notes and go on.

## Step 4: Compare promises with code

Read the privacy policy and terms and list every concrete promise: retention periods, what is collected, who sees it, what is shared with which processor, how long backups live, how deletion and export work. For each, find the code that keeps it:

| Promise | Code to find |
|---|---|
| a retention period | the purge job's interval and what it deletes |
| "you can export your data" | an export that covers every table holding the user's data, account and profile rows included |
| "we delete your data" | a deletion that reaches every table and every external processor (auth provider, storage, email, analytics, payments) |
| a processor list | every third-party SDK and API the code actually calls |

Search with a cap, for example `rg -n --max-count 3 '<purge or export term>' <code folder> | head -n 40`.

Done when: every promise has a verdict (kept, broken, or can't tell) with a `file:line`.

## Step 5: Trace personal data

List every column that holds personal data in the schema source (names, emails, birth dates, free text, device ids, locations, IP addresses). For each, confirm it appears in the export, the deletion and the policy's list of what is collected. A column missing from any of the three is a finding.

Done when: every personal-data column has a row of export yes/no, deletion yes/no, policy yes/no.

## Step 6: Walk the launch checklist and the baseline

Walk the compliance doc's launch checklist item by item. Mark each implemented (with the `file:line`), missing, or needs-counsel. Look hardest at:

- Children: age gate or birth date at profile creation, parental consent, child profiles in export and deletion.
- Consent: a consent record written on **every** sign-up path, including any agent, single-sign-on or invite path, and re-consent when the documents' version changes.
- User rights: access, correction, deletion, portability, objection. Each has a way to exercise it.

Then walk "The baseline" in `.agents/skills/privacy-compliance/SKILL.md` the same way. It covers what a project's own checklist tends to miss (no personal data in logs, processors, AI input, payments, user content, the breach runbook). A baseline line the compliance doc does not mention is a finding against the doc, not proof of a gap in the code.

Done when: every checklist item and every baseline line is marked.

## Step 7: Check store requirements

If the app does not ship to an app store, write `no stores` and go to Step 8. Otherwise compare what the code collects with the store privacy labels or data-safety form, and check the store's account-deletion requirement. Read the store's current policy text; never answer from memory.

Done when: each label field and the deletion requirement has a verdict, or you wrote `no stores`.

## Step 8: Record, present and ask

Write each finding into the audit record (Step 1), in its existing format: the promise or rule (quoted, with its source), the code evidence, confidence (confirmed / likely / suspected), severity (a broken promise to users first), and the fix. Edit only that file. Then show the findings in your reply, worst first, at most 10 per round:

```text
1. [high, confirmed] Policy says "deleted after 30 days"; purge runs at 90 days
   Evidence: <path>:<line>
   Fix: change the purge interval to 30 days
   Choose: fix / accept / counsel
```

| The user answers | Action |
|---|---|
| fix | do it in Step 9 |
| accept | record why in the audit record |
| counsel | add it to the owner's queue named in Step 1, with the exact question for a lawyer |
| nothing, or unclear | stop and ask: "fix, accept or counsel for finding N?" |

Wait for the answers before Step 9.

Done when: every presented finding has an answer.

## Step 9: Fix

1. Fix the code where the code is wrong. Fix the document only when the code is right and the promise was wrong, and then follow the project's process for publishing a new document version.
2. Add a test that pins each promise you fixed (a purge test for a retention period, an export test that a table is included).
3. Mark the entry fixed in the audit record with the date, and add a changelog line with the project's changelog command (the **Records** bullet from Step 1).
4. Run the checks from the **Checks and tests** bullet, and the legal-chain check again if a document changed. If a check fails twice with the same error, stop and report the output.

Done when: every check passes and every fixed entry is marked in the audit record.

## Done means

- The audit record has a dated line for this run and no open entry that is actually fixed.
- Every finding is fixed, accepted with a reason, or in the owner's queue.
- The legal-chain check (Step 3) passes if a document changed.
- The checks from Step 1 pass.
