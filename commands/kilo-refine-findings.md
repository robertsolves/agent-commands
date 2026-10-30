---
description: "Refine a findings document (a bug list, an audit of API bugs, a TODO file, a list of stale comments) with the free Kilo CLI: each round Kilo re-checks every entry against the code, deletes the fixed or false ones, corrects the drifted ones, then adds new entries of the same kind, until two rounds in a row leave the document unchanged; then you spot-check the changes once. Run when a findings document needs a deep refresh while spending as few Claude tokens as possible. Not for one careful pass by you — use /refine-findings; not for doing a task — use /kilo-loop."
argument-hint: "<doc-path> [focus words] [--model <id>]"
---

# /kilo-refine-findings

The document decides what Kilo looks for: a document of API bugs gets checked and grown with API bugs, a TODO file with TODOs, a list of stale comments with stale comments. One script runs every round, so none of Kilo's round reports pass through your context: that is where the token saving comes from. Spend tokens only on your spot-check (Step 5).

Writes: the findings document (Kilo edits it; nothing else), a new run folder `.kilo_runs/refine_<timestamp>/` that the script creates (git-ignored, inside the repo so Kilo can read it and `AGENTS.md`; `.kilo_runs/refine_latest` always points at the newest), then the records of Step 6.

## Models

Free models only, best at coding first (checked 2026-10-29; most scores are the makers' own claims, so the order is a judgement). `<models>` is every id in the table, top to bottom, joined with commas and no spaces. If `$ARGUMENTS` holds `--model <id>`, take it out of the task text; `<models>` is then that one id. Keep this table identical in /kilo, /kilo-loop and /kilo-refine-findings.

| # | Model id | Why it is here |
|---|---|---|
| 1 | `kilo/dots-studio/dots-3-note-preview:free` | highest published coding scores (78.4 SWE-bench Verified, 75.1 Terminal-Bench 2.1); a preview |
| 2 | `kilo/poolside/laguna-s-2.1:free` | built for coding agents (70.2 Terminal-Bench 2.1, 59.4 SWE-bench Pro) |
| 3 | `kilo/nvidia/nemotron-3-ultra-550b-a55b:free` | 71.9 SWE-bench Verified, about 69 in independent runs: the most checked |
| 4 | `kilo/reflection/beam-free` | claims 81.6 SWE-bench Verified, but ranks low in independent runs |
| 5 | `kilo/nvidia/nemotron-3.5-super-vl:free` | 71.1 SWE-bench Verified |
| 6 | `kilo/xingchen-agi/xing4.0-29b-a4b:free` | 75.0 SWE-bench Verified from a small model |
| 7 | `kilo/recursive/flint-v1.0:free` | claims 74.2 SWE-bench Verified; small, uneven in agent tests |
| 8 | `kilo/cohere/north-mini-code:free` | 67.6 SWE-bench Verified |
| 9 | `kilo/kilo-auto/free` | Kilo's router over its free models; the model changes per session |
| 10 | `kilo/openrouter/free` | OpenRouter's free router |
| 11 | `litellm/coder` | the local LiteLLM proxy, with its own fallback chain; last resort |

## Step 1: Resolve the document

`$ARGUMENTS` (without any `--model <id>`, see Models) is the doc path, then optional focus words (e.g. `todo/exploits.md auth`).

| `$ARGUMENTS` | Action |
|---|---|
| empty | stop and ask: "Which findings document should Kilo refine?" |
| a path | `ls <doc-path>` |
| a name without a path | `rg --files -g '*<name>*' | head -n 5` |
| the name matches more than one file | stop and ask: "Which of these files?" |
| the file is outside this repo | stop and say Kilo can only edit files inside the repo |

Done when: `ls <doc-path>` prints the path, and `<doc-path>` and `<focus>` (may be empty) are fixed.

## Step 2: Load the project facts

```sh
rg -n '^- \*\*(Records|Agent prompts)\*\*' .agents/project-facts.md | head -n 5
```

Done when: you can name `<bug-list>` (the open-bugs file) and `<changelog-command>` (the "Changelog:" command in the Agent prompts bullet). If nothing prints, take both from the agent guide `AGENTS.md`, or write `<changelog-command>` as none.

## Step 3: Run the refine loop

```sh
bash .agents/skills/kilo-refine-findings/scripts/run_refine.sh <doc-path> [--focus "<focus>"] --models "<models>"
```

Leave out `--focus` when `<focus>` is empty. `<models>` is the chain from Models: when a model is rate-limited, the script moves to the next one for the rest of the run. A run takes 10 to 90 minutes: run it in the background if your CLI can, with no timeout shorter than 2 hours, and wait for it to exit. Do not edit `<doc-path>` or read the run folder while it runs.

Done when: the script has exited and you have its exit code.

## Step 4: Read the refine log

Read only the log, never the round reports:

```sh
cat .kilo_runs/refine_latest/refine.log
```

| Exit code | Last log line | Action |
|---|---|---|
| 0 | `REFINE: STABLE after <n> rounds` | Go to Step 5 |
| 1 | `REFINE: CAP REACHED` | Go to Step 5; say in Step 7 that the document was still changing |
| 2 | `no model is left to switch to`, then `STOP: ... failed twice` | Stop and ask: "Every model in Kilo's chain is rate-limited. Retry in an hour, or refine with /refine-findings?" |
| 2 | `STOP: ... failed twice` | Run `tail -n 30` on the file the log line names, then stop and ask: "Kilo's refine failed: <reason>. Retry, or refine with /refine-findings?" |
| 3 | `STOP: ... changed files other than` or `committed` | Stop and tell the user exactly what the log lines say, file names included. Do not undo anything yourself |
| 4 | a `STOP:` usage line | Fix the arguments and re-run Step 3 once |
| anything else | | Stop and ask: "The Kilo refine ended unexpectedly: <last log line>. Retry or refine with /refine-findings?" |

Done when: you have taken the action in the matching row.

## Step 5: Spot-check the changes

This is the one place to spend tokens. Read what Kilo changed, never the whole document:

```sh
wc -l .kilo_runs/refine_latest/doc.diff
cat .kilo_runs/refine_latest/changes.txt
```

Read `doc.diff` whole when it is under 400 lines, otherwise in 300-line ranges with `sed -n '<a>,<b>p'`. Then check against the code, opening only the cited line with ten lines around it (`sed -n '<line-10>,<line+10>p' <file>`):

1. Every deletion of a high-severity entry (P0 or P1, or the document's own top level): is it really fixed or false?
2. Every new high-severity entry, plus two other new entries picked at random: does the code fail as it says?
3. Two corrected entries picked at random: is the correction right?

| Code says | Action |
|---|---|
| Kilo's change is right | keep it |
| a deleted entry is still real | put it back from `.kilo_runs/refine_latest/doc_before.md`, corrected if it drifted |
| a new or corrected entry is wrong | delete or fix it in `<doc-path>` with your file-edit tool |
| needs a live environment, a credential or the owner | keep it; say what is needed in Step 7 |

If a third or more of the changes you checked are wrong, check every remaining change the same way before going on.

Done when: every change in the three lists above has a verdict and the wrong ones are undone in `<doc-path>`.

## Step 6: Record deleted bug fixes

Only for deletions that `changes.txt` marks `fixed` and that you did not put back, and only when the entry was a bug (not a TODO, a comment, or another kind of finding):

| Situation | Action |
|---|---|
| the fix has no changelog line | run `<changelog-command> "<one line>"` |
| it already has one, or the entry was not a bug | do nothing |
| `<changelog-command>` is none | stop and ask: "Fixed bug <heading> has no changelog line and I have no command to add one — add it by hand?" |

If `<doc-path>` is not `<bug-list>` and the entry also sits in `<bug-list>`, delete it there too (search first: `rg -n '<symbol>' <bug-list> | head -n 5`).

Done when: each deleted fixed bug has a changelog line, or there are none.

## Step 7: Report

Reply in chat, not in a file:

```text
<doc-path>: Kilo <n> rounds, ended <STABLE | CAP REACHED>; deleted X, added A, corrected C (from doc.diff and changes.txt)
checked by me: <k> changes, <w> wrong and undone
undone: <heading> - <why>
owner: <heading> - needs <what>
```

One `undone:` line per change you reverted and one `owner:` line per entry only the owner can settle.

Done when: the reply holds the counts lines and one line per undone change.

## Done means

- `tail -n 1 .kilo_runs/refine_latest/refine.log` was read and acted on.
- Every high-severity deletion and addition has a verdict from you, and the wrong ones are undone.
- `git status --short` shows no file edited in this run other than `<doc-path>`, `<bug-list>` and the changelog.
