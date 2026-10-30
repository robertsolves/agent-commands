---
description: Give a GO / NO-GO verdict on whether the project is ready for real users — every open item on the readiness checklist is queued somewhere, the riskiest items marked done really are done, the dev-only switch and its markers are ready to flip, every release gate passes, every P0 item of the production-readiness standard has evidence, and what ships matches the agreed scope — reporting blockers first and changing nothing. Run before opening to real users, and periodically during the run-up to launch.
argument-hint: "[checklist section or item number to focus on] (default: everything)"
---

# /check-production-readiness

A read-only launch gate. It asks whether the whole project is fit for real users, not whether one release is ready. It creates and edits no file: write everything in your reply. Its output is a verdict and the list of what blocks it.

## Step 1: Load the project facts and set the scope

```sh
rg -n 'Production readiness' .agents/project-facts.md | head -n 3
```

The matching bullet names the readiness checklist, the release scope doc, the launch runbook, the production-safety doc, the dev-only switch and its marker, and the release gates. Write them in your notes as `<checklist>`, `<scope doc>`, `<switch>`, `<marker>` and `<gates>`. Also find where deferred work and the owner's tasks are queued: the same file's **Records** bullet.

| `$ARGUMENTS` | Scope |
|---|---|
| empty | everything |
| a checklist section name or item number | only that part, for Steps 2 and 3 |

Done when: your notes hold all five names and the scope. If the command prints nothing, stop and ask: "Where are this project's readiness checklist and release gates?"

## Step 2: List the open items and check each is queued

```sh
grep -n -E '^#+ .*[0-9]+\.' <checklist> | grep -v 'DONE' | head -n 60
```

Each line is a checklist item that is not done. For each one, search both queues for its number or title: `rg -n -m 3 '<number or title>' <deferred-work file> <owner-task file> | head -c 2000`. An open item queued nowhere is a finding: nobody will do it.

Done when: you have `open items queued: <n>/<n>` and a list of the unqueued ones.

## Step 3: Spot-check items marked done

Pick up to eight of the riskiest done items: security, payments, data deletion, consent, backups, monitoring, in that order. For each, read the code or config the item cites (`rg -n -m 3 '<symbol>' <path> | head -c 1500`) and decide whether the claim is still true today.

| Result | Action |
|---|---|
| the claim still holds | note the item as checked |
| the claim no longer holds | record a blocker |
| the item cites nothing to check | record a warning: "no evidence cited" |

Done when: you can list which items you checked and the result of each.

## Step 4: Check the dev-only switch

```sh
rg -n '<marker>' . | head -n 60
```

Confirm three things: each marker is listed on the checklist, the switch is the only thing gating each dev-only surface, and flipping it closes all of them. A dev-only surface gated by something else, or by nothing, is a blocker.

Done when: every marker line is classed as listed or unlisted, gated by the switch or not.

## Step 5: Run the release gates

```sh
<gate command> 2>&1 | tail -n 40
```

Run every command in `<gates>` from the repo root, one at a time, in that form. After each, record `PASS` or `FAIL` and, for a `FAIL`, the first failing line of its output.

| A gate… | Action |
|---|---|
| needs a service that is not running (for example the local stack) | record `FAIL (not run: <what is missing>)`; do not start it |
| fails twice with the same error | stop retrying and record the output |

Done when: every gate has a `PASS` or `FAIL` line.

## Step 6: Walk the readiness standard

```sh
sed -n '/^## P0/,/^## Changing/p;/^## Release decision/,/^## Done means/p' .agents/skills/production-readiness/SKILL.md
```

This prints the P0 items and the release-decision questions. For each P0 item, cite evidence (a `file:line`, a test, a config value or a checklist entry) or an N/A reason.

| An item has… | Result |
|---|---|
| evidence | counts toward `P0 items with evidence` |
| an N/A reason | counts as N/A |
| neither | blocker |

A release-decision question with no answer is a warning.

Done when: every P0 item and every release-decision question has a line in your notes.

## Step 7: Compare the scope with what ships

Read `<scope doc>`. For each in-scope feature, search for its route or screen: `rg -l '<feature name>' <code dirs> | head -n 5`. For each out-of-scope feature, check whether a user can reach it.

| Finding | Class |
|---|---|
| an in-scope feature is missing | finding |
| an out-of-scope feature is reachable by users | finding |

Done when: each scope-doc feature is marked present, absent or reachable.

## Step 8: Print the verdict

Print **GO** only when there are no blockers; otherwise **NO-GO**. Then fill in this block. Blockers go first.

```text
Verdict: NO-GO
Blockers (each blocks GO)
  1. <item> — <evidence> — <what would close it> — <queued in …>
Warnings (should close before launch, do not block)
  1. <item> — <evidence>
Gates
  <gate>: PASS | FAIL (<first failure>)
Checked
  open items queued: <n>/<n>; done items spot-checked: <list>; standard P0 items with evidence: <n>/<n>
```

Offer to queue each unqueued item, and queue one only after the user says yes. Change nothing else.

Done when: your reply holds the block above, filled in.

## Done means

- Your reply starts with `Verdict: GO` or `Verdict: NO-GO`.
- The `Gates` section has one `PASS` or `FAIL` line for every gate in `<gates>`.
- `git status --short` shows no file changed by this run.
