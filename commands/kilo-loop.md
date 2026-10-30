---
description: "Hand a whole task to the free Kilo CLI: Kilo does the work, then audits and fixes its own changes in a loop until two audits in a row find nothing, and only then do you audit the final diff. Run when a task is well defined and you want a cheap model to do the edits while spending as few Claude tokens as possible. Not for investigation where you make the edits — use /kilo; not for small tasks where writing the brief costs as much as doing the work — just do those."
argument-hint: "<the task> [--model <id>]"
---

# /kilo-loop

Kilo does the work and the audits; you write one brief and audit the result once. One script runs the whole loop, so none of Kilo's reports pass through your context: that is where the token saving comes from. Spend tokens only on the brief (Step 3) and the final audit (Step 6).

Writes: `$SCRATCH/kilo_loop_brief.md` (the session scratchpad), a new run folder `.kilo_runs/loop_<timestamp>/` that the script creates (git-ignored, inside the repo so Kilo can read it and `AGENTS.md`; `.kilo_runs/loop_latest` always points at the newest), Kilo's edits to the repo, then your fixes in Step 7.

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

## Step 1: Read the task

`$ARGUMENTS` is the task. If it is empty, ask "What is the task for Kilo?" and stop.

Done when: you have the task text. (Judgement and a question; no command.)

## Step 2: Load the project's checks

```sh
rg -n -m 3 "Checks and tests" .agents/project-facts.md | head -n 5
```

`<checks>` = the commands that bullet names as the checks to run after a change. If the search prints nothing, `<checks>` = the checks the agent guide `AGENTS.md` lists after a change.

Done when: you can write `<checks>` as one or more concrete commands.

## Step 3: Write the brief

Write `$SCRATCH/kilo_loop_brief.md` from what you already know. Do not open repo files to write it: research is Kilo's job, and every file you read here is a token the command exists to save. Keep it under 40 lines, in this shape:

```markdown
# Task
<the task, in the user's words plus anything they said in this conversation>

# Known starting points
- <file or symbol you already know is involved, or "none">

# Done when
- <observable result 1, e.g. "the endpoint returns 404 for a deleted group">
- <checks> pass
```

The script adds the safety rules (no commits, no deploys, edits inside the repo only) itself; do not repeat them.

Done when: `test -s "$SCRATCH/kilo_loop_brief.md" && echo OK` prints `OK`.

## Step 4: Run the loop

```sh
bash .agents/skills/kilo-loop/scripts/run_loop.sh "$SCRATCH/kilo_loop_brief.md" "<models>"
```

`<models>` is the chain from Models: when a model is rate-limited, the script moves to the next one for the rest of the run. A run takes 10 to 90 minutes: run it in the background if your CLI can, with no timeout shorter than 2 hours, and wait for it to exit. Do not read its output files while it runs.

Done when: the script has exited and you have its exit code.

## Step 5: Read the loop log

Read only the log, never the reports behind it:

```sh
cat .kilo_runs/loop_latest/loop.log
```

| Exit code | Last log line | Action |
|---|---|---|
| 0 | `LOOP: CLEAN after <n> audits` | Go to Step 6 |
| 1 | `LOOP: CAP REACHED` | Read only the problem lines of the last audit: `grep -E '^- .+:[0-9]+' .kilo_runs/loop_latest/audit_<n>.md \| head -n 20`. Then Step 6, treating those as open findings |
| 2 | `no model is left to switch to`, then `STOP: ... failed twice` | Stop and ask: "Every model in Kilo's chain is rate-limited. Retry in an hour, or should I do the task directly?" |
| 2 | `STOP: ... failed twice` or `did not finish` | Run `tail -n 30` on the file the log line names, then stop and ask: "Kilo could not finish: <reason>. Retry, or should I do the task directly?" |
| 3 | `STOP: Kilo committed ...` or `audit ... changed files` | Stop and tell the user exactly what the log line says. Do not undo anything yourself |
| anything else | | Stop and ask: "The Kilo loop ended unexpectedly: <last log line>. Retry or do it directly?" |

Done when: you have taken the action in the matching row.

## Step 6: Audit the final diff yourself

This is the one place to spend tokens. Read the change, not the reports:

```sh
cat .kilo_runs/loop_latest/final_files.txt
wc -l < .kilo_runs/loop_latest/final.patch
```

1. Check every path in `final_files.txt` belongs to the task. A path the task cannot explain (a parallel session's edit, a stray file) → stop and ask: "<path> changed during the run but is not part of the task. Was that you or another session?"
2. Read `final.patch`. Over 1500 lines → read it one file at a time: `git diff -- <file>`.
3. Open a source file only where the patch alone cannot answer whether the change is right (a caller, a test it should have touched).
4. Run `<checks>`.
5. Judge the change against the brief's "Done when" list and the rules in `AGENTS.md`. Where the two audits passed something that breaks a rule, the rule wins.

Do not read `work.md`, `audit_*.md` or `fix_*.md` in this step. The diff is the truth; the reports are Kilo's opinion of it.

Done when: you have a list of findings (it may be empty) with `file:line` evidence, and `<checks>` have run.

## Step 7: Close the findings

| Findings | Action |
|---|---|
| None, and `<checks>` pass | Go to Step 8 |
| A few small ones (each under ~20 lines to fix) | Fix them yourself, re-run `<checks>` |
| Larger ones, the first time | Write them into a new brief `$SCRATCH/kilo_loop_brief_2.md` (same shape as Step 3, the findings as the task), re-run Step 4 with that brief (it makes a new run folder and moves `loop_latest` to it), then Steps 5 and 6 |
| Larger ones after a second run | Stop and ask: "Kilo's second pass still leaves: <findings>. Fix them myself, or stop here?" |

Done when: `<checks>` pass and you have no open findings, or the user has answered the question.

## Step 8: Report

Report in this shape:

```text
Kilo loop: <n> audits, <m> fix rounds, ended <CLEAN | CAP REACHED>
Changed: <paths from final_files.txt>
My audit: <what I found and fixed, or "nothing found">
Checks: <command> → <result>
Open: <anything left, or "none">
```

Done when: the report is sent and `git status --short` shows only intended changes.

## Done means

- `tail -n 1 .kilo_runs/loop_latest/loop.log` was read and acted on.
- `final.patch` was read by you, and `<checks>` were run after your last edit.
- `git status --short` shows only intended changes.
