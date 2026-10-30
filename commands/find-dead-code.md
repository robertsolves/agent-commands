---
description: Find dead code across the project's packages, figure out why each piece is dead (orphaned by a refactor, never wired up, deliberate dark-launch, superseded), then — with the user's confirmation — remove it or wire it back in. Run after large refactors or as periodic hygiene.
argument-hint: "[package or path to focus on] (default: every package)"
---

# /find-dead-code

Dead code is code nothing reaches: a symbol with no live references, a branch that can't be taken, a route never mounted, a method with no caller. The reason it is dead is the finding: an orphaned helper is noise, a guard that was written but never called is a live bug. Scope is code only (source, migrations, infrastructure config, helper scripts), not assets. Order: find, explain why each is dead, ask, then remove or wire back only what the user confirms. Write findings in your reply, not to a file.

## Step 1: Load the project facts and resolve scope

```sh
rg -n '^- \*\*(Deliberately unused|Who uses|Checks and tests|Records|Search helpers)' .agents/project-facts.md | head -n 5
```

It prints five bullets. Name what they give: `<never-flag-list>` (Deliberately unused), `<shared-package>` with its consumers and barrel command (Who uses), `<check-commands>` (Checks and tests), `<bug-file>` and `<changelog-command>` (Records), `<symbol-finder>` and `<grep-helper>` (Search helpers).

| `$ARGUMENTS` | Scope |
|---|---|
| empty | every package |
| a package or path that exists | that package or path |
| anything else | stop and ask: "Which package or path is `<argument>`?" |

Done when: your notes hold the five bullets and the scope. If the command prints fewer than 5 lines, stop and ask: "Where are this project's facts for dead-code sweeps?"

If the **Search helpers** bullet names no script of its own, use the ones in the `search-helpers` skill: `bash .agents/skills/search-helpers/scripts/find_symbol.sh` is the symbol finder, `bash .agents/skills/search-helpers/scripts/capped_grep.sh` the grep helper and `bash .agents/skills/search-helpers/scripts/doc_drift.sh` the drift tool.

## Step 2: List candidates

```sh
<symbol-finder> <Symbol>
<grep-helper> '\b<Symbol>\b' <scope>
```

This step is judgement plus those two commands. Only its own file, a barrel export and tests reference it, or nothing does → candidate. Discount its declaration, barrel exports and generated mirrors. File-local dead code is the analyzer's job; hunt for exported-but-unused symbols across files and packages. High-yield: service methods nothing calls; request/response models no route or client uses; enum values never produced or matched; widgets never instantiated; repository methods without a route; scripts nothing references; branches behind a constant flag.

| Candidate is… | Action |
|---|---|
| on `<never-flag-list>` | drop it |
| in `<shared-package>` | keep only if every consumer, its tests and scripts have zero references |
| a request/response field or enum value | also check stored JSON, queued entries and old clients; any chance one arrives → drop it |
| a DB column or table | list it as "flag only"; never drop it |
| anything else with zero real references | candidate |

Done when: you have a numbered list of `file:line Symbol` candidates. Zero candidates → reply "no dead code found" and stop.

## Step 3: Find out why each is dead

```sh
git log --oneline -S "<Symbol>" -- <file> | head -n 5
```

Also check the session transcripts and plan docs for stated intent. This step is judgement against the history; it has no other command.

| Verdict | Meaning | Proposed action |
|---|---|---|
| ORPHANED | a refactor removed the last caller | remove |
| SUPERSEDED | a newer implementation replaced it and both survive | remove the loser, after checking nothing subtle needs it |
| NEVER-WIRED | written to be called, never hooked up (a guard that can't fire) | wire it in; this changes behaviour |
| DELIBERATELY DARK | staged for later, or one side of a platform conditional import, or a path-discovered script | keep; if the why is undocumented, propose a one-line note in the doc that owns it |

A NEVER-WIRED gap that is a concrete failure outside this run goes in `<bug-file>`. Anything not clearly one verdict → stop and ask: "`<Symbol>`: dead or intended?"

Done when: every candidate has a verdict, the commit or transcript that shows it, and a proposed action.

## Step 4: Present and ask

This step is a question to the user; it has no command. Present the numbered list grouped by verdict. Each finding states: symbol and `file:line`, which consumers were checked, when and why it died, the proposed action. Then ask: "Which of these should I apply? Answer by number."

Removal is destructive and wiring changes behaviour: nothing happens before the answer. A finding with no answer stays untouched. Never invent a default action.

Done when: the user has answered; the confirmed numbers are in your notes.

## Step 5: Apply the confirmed ones

This step is file edits plus the checks below; the edits have no command. Edit with your file-edit tool, never `sed -i` / `perl -i`. Never edit generated files; fix the spec and regenerate.

| Confirmed | Do |
|---|---|
| remove (ORPHANED / SUPERSEDED) | delete the code and the helpers, tests and exports that die with it; regenerate the barrel with the `<shared-package>` command if one changed |
| wire in (NEVER-WIRED) | wire it as the original intent says, add a test proving it now fires, call out the behaviour change |
| keep (DELIBERATELY DARK) | add the one-line why to the owning doc |

Then run `<check-commands>` for each touched package. If a check fails twice with the same error, stop and report the output. If an API or UI surface changed, run `<changelog-command> "<one line>"`.

Done when: every check passes and the working tree holds only the confirmed changes.

## Done means

- Every confirmed finding is applied; every unanswered one is untouched.
- `<check-commands>` pass for each touched package.
- No DB column or table was dropped.
