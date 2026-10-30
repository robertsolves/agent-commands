---
description: Find a session from any coding agent (Claude Code, Codex, Gemini CLI, OpenCode, Kilo, Antigravity) in the local caches, read its transcript, and carry on its work here. Run when an agent ran out of tokens or crashed mid-task and you want to continue that one session in this agent. Not for finding every half-done thread — use /find-unfinished.
argument-hint: "[<tool>:<session-id> | search words]"
---

# /resume-session

**Argument:** `$ARGUMENTS` is a session reference as the script's `list` prints it (`kilo:ses_e806…`, or a unique id prefix), or a few words from the session's title. If it is empty, Step 1 lists the recent sessions for this directory and asks which one.

The script is `.agents/skills/resume-session/scripts/llm_session.py` (Python 3, standard library only, read-only on every cache; its docstring lists where each agent keeps its sessions). Call it `S` below. Set it in every shell you run:

```sh
S=.agents/skills/resume-session/scripts/llm_session.py
```

Writes: this command writes nothing itself, except the handoff file in Step 4 and any fix to the script in Step 5. Never revert, reset or overwrite files you did not change in this run: another session may be editing them.

## Step 1: Pick the session

| `$ARGUMENTS` is… | Do |
|---|---|
| a `<tool>:<id>` or id prefix | use it as `<ref>` in Step 2; if the script says the prefix matches several sessions, show its list and ask which one |
| search words | run `python3 $S list --limit 200 \| head -n 400`, match the words against the titles; one clear match → use it; several → show them (ref, age, title) and ask |
| empty | run `python3 $S list --here --limit 15 \| head -n 40` and ask which one to resume; the newest `claude:` entry is usually this session itself, so leave it out of the question |
| anything else | stop and ask: "Which session (ref or title words)?" |

If the user gives no answer, stop without changing anything.

Done when: you hold one `<ref>` (`<tool>:<id>`) that `list` printed.

## Step 2: Read the transcript

```sh
python3 $S show <ref> --tools --tail 120 | head -c 20000
```

`--tools` adds one line per tool call, which shows which files the session touched. `--tail 120` keeps the read short. If the tail has no first user message that states the goal, read again with a larger `--tail`, or without it. Messages longer than 4,000 characters come back cut, with a note.

Antigravity transcripts hold only the user's prompts: say so, and expect to reconstruct what was done from the files and `git` alone.

Done when: you can state in one sentence the goal the session was given. Otherwise read more (or stop and ask: "The transcript has no clear goal; what should I carry on?").

## Step 3: Check what actually landed

A transcript says what the agent *meant* to do, not what is on disk.

1. Compare the working directory the transcript header names with this one. If it differs, `cd` there; if it is a different repository than the user expects, stop and ask: "The session ran in <dir>; carry on there?"
2. Run:

```sh
git status --short | head -n 60
git log --oneline -10
```

3. Check each file the transcript edited or claimed to fix.

Done when: you have written a few lines saying which steps landed, which are half done, and which never started.

## Step 4: Continue

Judgement step, no command. Take up the last unfinished task the user asked for in that session, following the repository's agent guide (`AGENTS.md`, `CLAUDE.md` or equivalent) as usual.

| The transcript ends on… | Do |
|---|---|
| a question the other agent put to the user | stop and confirm with the user before going further |
| a destructive step (a deploy, a reset, a push) | stop and confirm with the user before going further |
| anything else | carry on with the last unfinished task |

To hand the session to a *different* agent instead of continuing it here, the script writes a handoff file and prints the launch command:

```sh
python3 $S handoff <ref> --to <claude|codex|gemini|opencode|kilo|antigravity>
```

On a terminal, `python3 $S` with no arguments lists the sessions, asks which one and which agent, and launches it.

Done when: the task is finished, or you have stopped at one of the rows above and asked, or the handoff command printed its launch command.

## Step 5: Check the script still reads every store

After the work, run:

```sh
python3 $S list --limit 5 2>&1 >/dev/null | head -n 10
which claude codex gemini opencode kilo agy
python3 $S list --tool <tool> --limit 1 | head -n 3
```

Run the last command once for each tool `which` printed.

If a store moved or its format changed, fix the matching section of `llm_session.py` (each tool has its own `# ---------- <tool> ----------` block) and its docstring, and fix any stale path in this file.

Done when: the first command prints nothing (no warnings on stderr) and each installed tool returned one row.

## Done means

- `python3 $S list --limit 5 2>&1 >/dev/null | head -n 10` prints nothing.
- `python3 $S list --tool <tool> --limit 1 | head -n 3` prints one row for each tool `which` found.
- The reply says which steps of the session landed, which are half done, and which never started.
