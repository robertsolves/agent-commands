---
description: Make the codebase skimmable by giving every recurring job one pattern and every kind of file one skeleton (same names, parameters, outputs, flow and part order), plus one predictable file tree and one name per concept across layers. Discover across every package (coverage ledger, skeleton comparison, cross-cutting sweep, adversarial gap check), have the owner pick the canonical pattern per family, migrate one family per run without changing behaviour, split oversized files, add a guard against drift, and fix every confirmed bug as its own change. Run when asked to unify patterns, make files consistent, or find drift between files of the same kind; no argument discovers, a family id migrates it, `split <path>` splits a file. Not for style lint — use /dart-clean-packages; not for a readability ranking — use /find-readability-improvements.
argument-hint: "[discover | <family-id> | split <path>] (default: discover)"
---

# /unify-patterns

The goal is one pattern per recurring job and one skeleton per kind of file, so the owner can read one instance and skim the rest. Three levels are in scope: inside a job (errors, logging, permissions handled the same way), across one kind of file (same layout, names, parameter order, outputs, flow, and the same order of repeated units), and across the tree and layers (predictable paths, one name per concept from table to screen). Consistency beats the locally best pattern. Every sanctioned exception is marked in code and says why.

## Step 1: Load context (every mode)

```sh
rg -n '^- \*\*(Patterns|Checks and tests|Records)\*\*' .agents/project-facts.md | head -n 5
git fetch
git status --short | head -n 40
```

Read the project's agent guide (`AGENTS.md`, `CLAUDE.md` or equivalent) and the rule files it points at. From the printed bullets and the guide, write down these placeholders:

- `<catalogue>`: the pattern catalogue with its coverage ledger, and the section saying how this command uses them. Read that section. A decided family is never re-litigated.
- `<exception-marker>`: how a sanctioned exception is marked in code.
- `<rule-check>`: the command that checks one catalogue rule alone.
- `<check-cmds>`: the analyze, format and test commands, and the pre-deploy checks for the area you touch.
- `<bug-record>`, `<todo-record>`, `<owner-record>`, `<changelog>`: where open bugs, deferred work, the owner's own tasks and fixes are recorded.
- The doc that owns the area you touch, the glossary, and the generated or read-only files.

If the project has no catalogue, this run creates one in its docs folder and proposes a one-line pointer to it in the agent guide.

Peer sessions may edit this tree. If a file you will touch is already dirty or changed upstream, say so and leave it alone.

Done when: every placeholder above has a value in your notes, or you stopped and asked: "I cannot find <placeholder>. Where is it?"

Arguments: `$ARGUMENTS`

| `$ARGUMENTS` | Action |
|---|---|
| empty or `discover` | Mode A |
| a family id from `<catalogue>` | Mode B |
| `split <path>` | Mode C |
| anything else | stop and ask: "Run discovery, migrate a family (which id?), or split a file (which path?)" |

The catalogue's known families are where discovery starts, not where it ends. Earlier surveys sampled, so assume there is more drift than recorded. "I checked the known families" is not a finished discovery.

## Mode A: discover (no code edits)

Read `.agents/skills/unify-patterns/references/discovery_checklists.md` before A2.

### A1. Build the coverage ledger

```sh
git ls-files | xargs -n1 dirname | sort | uniq -c | sort -rn | head -n 150
```

List every directory holding hand-written source, excluding generated files, build outputs, dependency caches and the read-only packages the guide names. It must span every package and artefact kind: library code, entry points, tools, tests, schema and migrations, infrastructure, web and native shells, scripts, CI workflows. Start from the packages and out-of-scope parts `<catalogue>` lists. One row per directory: path, file count, kinds of file, surveyed (y/n), verdict. The verdict is `consistent — exemplar <file>` or the open family ids; never blank.

Done when: every directory in the output has a row with a verdict or `surveyed: n`.

### A2. Compare skeletons per file kind

Group files that do the same kind of job (list in the checklist). For each kind, compare 3 to 5 instances on every axis in the checklist § Skeleton axes, count each variant with a capped grep (`| head -n 40`), and draft the canonical skeleton from the majority. This step is judgement plus greps.

Done when: each kind has a variant count and a drafted skeleton.

### A2b. Check the file tree and the names across layers

Run the checks in the checklist § Tree and naming checks. If `<catalogue>` names a guard for folder shape, run it and record its output.

Done when: every package has a folder rule, and each traced concept has a name per layer or a recorded conflict.

### A3. Sweep the cross-cutting concerns

Sweep every concern in the checklist § Cross-cutting concerns, and every concern `<catalogue>` records, across all packages. A concern on neither list becomes a new cross-cutting family. This step is judgement plus greps.

Done when: each concern has a variant count, or `one pattern` with an exemplar.

### A4. Find duplication

Look for near-identical functions, UI components, helpers, SQL fragments and script blocks, within and across packages. This step is judgement plus greps.

Done when: each duplicate group lists its files, or you wrote `none found` for each package.

### A5. Find modularity problems

Follow the checklist § Modularity.

```sh
git ls-files | rg -v '\.(g|freezed|mocks|gen|generated|pb)\.[a-z]+$|_pb2\.py$|(^|/)generated/' | xargs wc -l | sort -rn | head -n 60
```

Done when: every file over the proposed budget lists its seams, and wrong-layer logic is listed with file and line.

### A6. Delegate, then attack your own findings

Hand A2 to A5 to read-only search subagents, one bounded slice of the ledger each, on a cheap model. Never read code wholesale in the main context. If your CLI cannot run subagents, do the slices yourself with capped reads.

Then run one adversarial pass: a fresh subagent gets the ledger and family list and this brief: "What recurring job, concern or directory is missing? Which 'consistent' verdicts are wrong? Check by opening files, not by reasoning." Re-check any verdict it disputes.

Done when: the adversarial pass returned and each of its claims is folded in or refuted.

### A7. Write the decision sheet

Give each family an id in `<catalogue>`'s scheme and a block in the shape of checklist § Decision-sheet blocks. A file-kind block carries the drafted skeleton. Recommend the majority variant. List semantic traps (variants that look like style but mean different things): never merge those without the owner.

Done when: every family has a block with variants, a recommendation, a migration estimate and a semantic-traps line.

### A8. Decide with the owner and record the decisions

1. Ask the owner a multiple-choice question per family, up to 4 per call. Options in order: the recommended variant, the alternatives, "leave as is for now". Ask once for the file-size budget. If the owner gives no answer, leave the item untouched.
2. Record each decision in `<catalogue>` in the shape of checklist § Catalogue entry shape, plus a row in its index. A file-kind entry holds the approved skeleton.
3. Write the coverage ledger where `<catalogue>` keeps it, one line per row, and the evidence where `<catalogue>` says evidence goes.
4. Put each family's one-line rule into the matching rule file the agent guide lists.
5. If a decision contradicts the doc that owns the area, fix that doc in the same pass.
6. End with a migration order: most reading leverage and least risk first, behaviour decisions after pure refactors, file splits last.

Done when: `<rule-check>` runs without error and every decided family has a catalogue entry.

## Mode B: migrate one family

1. Check the family is decided in `<catalogue>`. If not, run A2 to A8 for that family alone first.
   Done when: its catalogue status reads `decided`, `migrating` or `done`.
2. List the live sites with the family's probes, capped (`| head -n 200`). Over about 40 sites, work in batches of one directory or one feature.
   Done when: the site list and batch plan are in your notes.
3. Get a baseline: run the `<check-cmds>` analyze command for each touched package and the narrow tests covering the touched files.
   Done when: both are green. If the baseline is red, stop and report; a refactor on red cannot prove it preserved behaviour.
4. For each site: read it, rewrite it to the canonical pattern, re-read it. The diff must be behaviour-preserving and verifiable by reading (same status codes, JSON, client state, error messages, offline behaviour).

   | Situation | Action |
   |---|---|
   | The site cannot move without a behaviour change | mark it with `<exception-marker>` and list it in `<catalogue>`, or report it to the owner |
   | The site is wrong, not just different | migrate its shape only, then fix the bug as its own change (Read `.agents/skills/unify-patterns/references/bugs_and_comments.md` § Fix every bug you find) |
   | Units must be reordered to the canonical order | move them verbatim and change nothing else in that change |
   | A rename or move changes a path or public symbol | update every reference in the same change: imports, barrels, docs, the guide, command files, scripts, CI |
   | The rename reaches the wire (JSON keys, URL paths, DB columns, env names, a script name CI or a doc tells people to run) | stop and ask: "<rename> changes the wire. Approve it?" |
   | A pinning test disagrees with the canonical pattern | the test wins until the owner says otherwise |
   | A critical why is missing in a file you touch | add it (Read the same reference § Add missing why-comments) |

   Done when: every site in the batch is migrated, marked as an exception, or reported.
5. After each batch run the `<check-cmds>` analyze and format commands, the narrow tests, and every check the guide or `<catalogue>` names for what you touched. If tests need a local stack, start it the way the guide says and restart it after server edits; with a peer session testing, use your own port or database.
   Done when: analyze is clean and the narrow tests pass.
6. If grep can detect the deviation, add a guard in the form `<catalogue>` describes: a named rule with a header explaining the rule and decision date, skipping comment lines, allowing `<exception-marker>` lines. File-kind and naming families can often be guarded (suffix and location, handler names, script headers, mirrored test paths). If grep cannot catch it, write in the catalogue entry that the rule file and the code-audit command are its only guard.
   Done when: `<rule-check>` for the family passes, or the entry says `guard: none`.
7. Set the family's catalogue status to `done` and name the guard.
   Done when: the catalogue entry reads `Status: done`.

## Mode C: split an oversized file

1. Read the file and list its seams.
   Done when: each seam is named in a few words.
2. Ask the owner: "Split <path> into <new files>, moving <what> where?" If the project's rules forbid moving declarations between files, this command is the explicit request that overrides them. If the owner gives no answer, leave the file untouched.
   Done when: the owner confirmed the split.
3. Move the code verbatim, as a pure move with nothing else changed. Any use of the new seams (lifting a rule out of a UI build method into a view-model with its own test) is a second, separate change.
   Done when: `git diff` shows only moved lines.
4. Regenerate barrels or index files for any directory that gained or lost files, the way the guide says.
   Done when: the generator exits 0.
5. Verify as in Mode B steps 3 and 5.
   Done when: analyze is clean and the narrow tests pass.

## Discovery never ends at Mode A

When migration reveals a new variant or recurring job, add it to `<catalogue>` as "found during migration"; never fix it quietly inside another family's diff. After every family, re-check the ledger rows for the directories you touched. The job is finished only when every ledger row reads "consistent" or names an open family.

## Hard rules

- No behaviour change disguised as consistency. Wire and JSON shapes, status codes, permission semantics, transaction and audit boundaries, delete semantics, and online-only vs queued writes are each the owner's decision: report them, never change them silently.
- One family per run; a mixed diff cannot be reviewed.
- Unify on an existing pattern; invent no new abstraction.
- Never edit generated files, read-only packages or applied migrations. A change to a package the project does not own goes to the owner as a suggestion.
- Fix confirmed bugs in their own change, never inside a refactor diff. Log in `<bug-record>` only what cannot be fixed now, `<todo-record>` for work with no failure mode, `<owner-record>` for what only the owner can do. Details are in the bugs reference.
- Stage and commit only your own files, and only if the owner asked for commits in this run.

## Closing

Add no `<changelog>` line for a pure refactor; add one only for an approved behaviour change or a bug fix. Report in your reply, not in a new file:

```
families touched: …
sites migrated: N
exceptions recorded: …
guards added: …
skipped (and why): …
bugs fixed (each with its test): …
open-bug and deferred entries added: …
why-comments added / "reason unknown" entries: …
ledger rows still open: …
next family in the migration order: …
```

## Done means

```sh
<rule-check> <family-id>
git status --short | grep '^ T'
```

Run `<rule-check>` for each family you touched, if the project has one: it must pass. The `grep '^ T'` must print nothing (a `T` means a symlink was replaced by a plain file). The `<check-cmds>` analyze command is clean for every touched package.
