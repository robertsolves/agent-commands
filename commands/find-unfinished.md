---
description: Find work left half-done by interrupted agent sessions — reconstruct intent from recent session transcripts and git state, verify what actually landed in the code, ask the user which threads to finish, then finish them. Run after a crashed or closed-mid-task session, or whenever the repo feels mid-flight. Not for carrying on one known session — use /resume-session.
argument-hint: "[days of history to scan] (default: 14)"
---

# /find-unfinished

An agent session can die mid-task, leaving a thread of work with no record except its transcript and whatever half of the diff landed. This command reconstructs those threads, checks which genuinely remain unfinished, asks, and finishes only the ones the user confirms.

Order: reconstruct intent (Steps 2–3), verify what landed (Step 4), ask (Step 5), then finish only what is confirmed (Step 6). Never revert or overwrite another session's uncommitted work.

## Step 1: Resolve scope and load the project facts

`$ARGUMENTS` is the number of days of history to scan; empty means 14. Then load the project facts (a step with no command beyond this):

```sh
rg -n '^- \*\*(Session transcripts|Records|Checks and tests)\*\*' .agents/project-facts.md | head -n 5
```

Write down `<transcript-dir>` (Claude Code and Codex transcript locations), `<todo-file>` and `<changelog>` (from Records), and `<checks>` (from Checks and tests).

Done when: you have the window in days and a value for each of those four names; if the command prints fewer than 3 lines, stop and ask: "Where are the session transcripts, records and checks for this project?"

## Step 2: Read the record

This step has two parts. First separate live sessions from dead ones: a running peer's transcript ends mid-sentence just like an interrupted one, and finishing a live session's work edits files it is still writing.

```sh
python3 .agents/skills/resume-session/scripts/llm_session.py list --here | head -n 40
ps aux | grep -iE 'claude|codex' | grep -v grep | wc -l
date -u +%FT%TZ
```

The "ago" column is the file mtime, so it does not settle live-or-dead. For each session in the window, read the last entry that carries a `timestamp` (UTC), capped:

```sh
tail -n 5 <transcript-dir>/<session>.jsonl | head -c 4000
```

| Last content timestamp | Action |
|---|---|
| within ~20 minutes of now | live: exclude it from the report and say so |
| older, tail shows a pending todo, an unexecuted plan, an interrupted tool call or an abrupt end | dead: keep it as a candidate |
| older, tail shows the work finished | not a thread: skip it |
| anything else | stop and ask: "Is session `<id>` still running?" |

If most candidates are live, report that and stop; "no dead threads" is a real result.

For each dead session, read its tail (never the whole file):

```sh
python3 .agents/skills/resume-session/scripts/llm_session.py show <ref> --tail 40 | head -c 4000
```

Without that script, `tail -n 40 <transcript-dir>/<session>.jsonl | head -c 4000` reads the same. Note what the session set out to do and where it stopped.

Then the git state. The working tree may hold the user's own or a live peer's edits: dirty does not mean interrupted. Note it and ask; change nothing.

```sh
git status --short | head -n 60
git stash list | head -n 20
git log --oneline -n 60 | rg -i 'wip|incomplete' | head -n 20
git branch -vv | rg ahead | head -n 20
rg -n --max-count 20 '<keyword from the thread>' <todo-file> | head -c 2000
```

The last command cross-references deliberate deferrals so you do not re-report one as an interruption; do surface a deferral that blocks a thread.

Done when: you have a list of dead sessions with a one-line "set out to / stopped at" each, a list of live sessions excluded, and the git findings noted.

## Step 3: Sweep for interrupt scars in the code

Judgement plus the project's own checks. Run the analyzer for each recently touched package (the commands are in `<checks>`), then look for these orphaned halves:

| Scar | How to look |
|---|---|
| route or endpoint file never registered with the router | the project's layout test, or `rg -n '<endpoint name>' <router file> \| head -n 5` |
| schema or model spec edited, generated code not regenerated | the project's schema-sync command in `<checks>` |
| migration edited, checksum or lock file beside it not updated | compare `git diff --stat` on the two paths; do not run the generator (some rewrite their output on any invocation, `--help` included) |
| barrel or index file missing newly added siblings | `git diff --name-status HEAD~20 \| head -n 40`, then `rg -n '<new file>' <barrel> \| head -n 5` |
| unwritten bodies | `rg -n --max-count 3 'UnimplementedError\|NotImplementedError\|TODO' <touched files> \| head -n 40` |
| tests or docs naming a symbol that does not exist | `rg -n --max-count 3 '<symbol>' <dir> \| head -n 10` |
| client calls an endpoint the backend lacks, or vice versa | grep both sides for the path |
| behaviour-changing commit with no `<changelog>` line | weak signal; corroborate with a transcript. Never read `<changelog>` whole: if the project facts say it must not be read, skip this row |

Done when: each row has been checked or marked not applicable, and every hit is attached to a candidate thread or noted as a new one.

## Step 4: Verify against reality

A later session may already have finished the thread. For each candidate, check the current code for the promised artifacts (judgement plus these two commands):

```sh
rg -n --max-count 3 '<promised symbol>' <touched dir> | head -n 10
git log --oneline -n 10 -- <touched file>
```

| Result | Action |
|---|---|
| every promised artifact exists and the checks pass | drop the thread |
| some artifacts missing | keep it, listing landed vs missing |
| none exist and nothing in git touches them | keep it as not started |
| anything else | stop and ask: "Did `<thread>` land? I can't tell from the code." |

Done when: every candidate is kept with evidence (file and line) or dropped.

## Step 5: Report and ask

This step is a report and a question to the user; it runs no command. Write the threads in your reply, newest first, in this shape:

```text
1. 2026-10-27, session ended mid-edit
   Set out to: add the export button to the settings screen
   Landed: src/settings/export.py (complete)
   Missing: the route in src/routes.py; no test
   Proposed completion: register the route, add one test (~20 min)
```

Ask per thread: **finish** / **abandon and clean up** (remove the dangling half) / **abandon and log** (record it in `<todo-file>`). Stop and wait for the answers before touching anything. A thread the user does not answer is left untouched.

Done when: the user has answered for each thread, or has said to stop.

## Step 6: Finish

Edit files with your file-edit tool, and only for threads answered **finish**. Never `git checkout` or `git restore` a file, and never revert or overwrite another session's uncommitted work.

1. Re-read the thread's transcript tail (`show <ref> --tail 40 | head -c 4000`) to recover the intent, the approach and any decision the user already made. Continue that work; do not re-derive it. If the original approach was wrong, say so and propose a correction instead of silently diverging.
2. Do the missing work from Step 5's list.
3. Do the closing duties the interruption dropped: analyze and format, tests, the `<changelog>` line, any doc note, regenerated code, all as `<checks>` lists them.
4. **Abandon and clean up**: remove the dangling half only on the user's confirmation, and first log anything still worth doing in `<todo-file>`.
5. **Abandon and log**: add the entry to `<todo-file>` and change nothing else.

If a command fails twice with the same error, stop and report the output.

Done when: every confirmed thread has its missing artifacts present and the `<checks>` pass.

## Done means

- Live sessions were excluded and named; no live session's work was edited.
- Every confirmed thread: `rg -n '<promised symbol>' <touched dir> | head -n 5` finds it, and the `<checks>` print no errors.
- Unanswered threads: `git status --short` shows no change for them.
