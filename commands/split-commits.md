---
description: Split a large pile of uncommitted changes (from several agent sessions or agents working in one tree at once) into small commits, one per discrete piece of work, by matching each changed hunk to the Claude Code, Codex, Gemini CLI, OpenCode or Kilo session that wrote it, and keep committing until nothing is left. Run when the working tree holds many unrelated changes, or the last unpushed commit is one huge mixed commit, and you want separate described commits. Not for carrying on one session's work — use /resume-session.
argument-hint: "[auto] [last] [--since 2d]"
---

# /split-commits

Turns hundreds of mixed changes into a short series of commits, each describing one piece of work. A script does the heavy lifting: it reads the agent transcripts, matches every changed hunk (a block of changed lines) to the session whose edit wrote it, and commits one group at a time through a private index. You read only its short plan, never the full diff, so the run stays cheap at 600 changed files.

Read the project's agent guide first (`AGENTS.md`, `CLAUDE.md` or equivalent) for its commit-message style, the attribution lines its commits need, and any rule about committing in a shared tree.

Set the script path in every shell you run:

```sh
S=.agents/skills/split-commits/scripts/split_commits.py; [ -f "$S" ] || S=~/.agents/skills/split-commits/scripts/split_commits.py
```

Writes: commits on the current branch, and the plan in `.git/split-commits/` (created on first run). Never push, amend, `git stash`, `git checkout -- <path>`, `git restore`, `git reset --hard`, or `git add -A` on the shared index: other sessions may be editing this tree right now.

## Step 1: Read the arguments

`$ARGUMENTS` may hold any of these words:

| Word | Means |
|---|---|
| `auto` | commit without asking in Step 5 |
| `last` | the work is already in one big commit: undo it first (Step 2) |
| `--since 2d` (or `12h`, or an ISO date) | read transcripts from that time instead of the default (6 hours before the last commit or the oldest change, whichever is earlier) |
| empty | uncommitted changes, ask once in Step 5 |
| anything else | stop and ask: "What should /split-commits do with `<word>`?" |

Done when: you know whether `auto`, `last` and `--since` apply.

## Step 2: Undo the big commit (only with `last`)

Skip this step without `last`. Check the commit is not pushed:

```sh
git branch -r --contains HEAD | head -n 3
```

| Output | Do |
|---|---|
| empty | `git reset --soft HEAD~1` (keeps every change in the tree and index) |
| any branch | stop and ask: "HEAD is already on <branch>; splitting it means rewriting pushed history. Go ahead?" |

Done when: `git log --oneline -1` shows the commit before the big one.

## Step 3: Scan

```sh
python3 $S scan | head -c 12000
```

Pass `--since <value>` here when Step 1 found one. The output is the plan, one block per group:

```text
G1     claude:aaaa1111     14 files   22 changes +230/-80  [3 loose, 2 tasks]
       Fix the bug where clearing an item's day loses it
       in: app/lib/screens (9), shared/lib/src (4), app/test (1)
U1                          6 files    6 changes +40/-12
       no transcript names these: backend/lib/
HOLD                        1 files    1 changes +1/-0
```

`G` groups come from one session each, oldest work first. `U` groups are changes no transcript names, grouped by folder. `HOLD` holds secret-looking or huge files and is never committed. `LIVE` marks a session that edited in the last 10 minutes. `loose` counts changes matched by file or folder only, not by content. `N tasks` means the session worked on several prompts.

If it prints `nothing left to commit`, go to Step 8.

Done when: the plan printed, or `nothing left to commit`.

## Step 4: Shape the groups

Work through every group with this table, worst-shaped first. Each command prints the changed group.

| Group looks like | Run |
|---|---|
| `N tasks` and the label covers only one of them | `python3 $S show G1 --tasks`; if the tasks are unrelated, `python3 $S split G1 --by-task`, then `python3 $S merge G1.3 G1.2` for any two parts that are one piece of work |
| one session's work spans clearly separate areas (say backend and docs, unrelated) | `python3 $S split G1 --by-dir` |
| two groups are the same piece of work (two sessions on one task) | `python3 $S merge G2 G1` |
| `U` group | `python3 $S show U1 --diff --max-chars 3000`; if it belongs to a `G` group's work, `python3 $S move <path-or-folder> G1`; otherwise keep it as its own commit |
| `loose` changes in a group you are unsure of | `python3 $S show G1` lists each file with `(weak)` or `(folder)`; move a file that plainly belongs elsewhere with `python3 $S move <path> <group>` |
| `LIVE` | leave it; it is committed on a later pass once its session stops |
| `HOLD` | leave it; list it in the final reply |
| anything else | leave the group as it is |

Read a diff only through `show … --diff --max-chars 3000`, never with a raw `git diff`. Stop after three shaping commands on one group: a rough group is better than a wasted context.

Done when: `python3 $S list | head -c 12000` shows groups you can each describe in one subject line.

## Step 5: Write the messages

Match the repository's style:

```sh
git log --format=%s -15
```

For each group, write a subject in that style saying what changed for a user or developer, from the group's label, its `tasks`, and its folders. Add a short body paragraph only when the subject cannot carry it. Add the attribution lines the agent guide or your harness requires to every message.

Unless Step 1 found `auto`, show the list and ask once:

```text
G1   v1: items that lost their day get it back          (14 files)
G2   Agent tooling: new /split-commits command           (3 files)
U1   Tidy backend logging                                 (6 files)
skipped: G4 (LIVE), HOLD (.env.local)
Commit these 3? (yes / changes)
```

Apply any changes the user names with Step 4's commands, then ask again. If the user gives no answer, stop without committing.

Done when: every group except `LIVE` and `HOLD` has a message, and the user said yes (or `auto` applies).

## Step 6: Commit each group

One command per group, in plan order (`G` groups, then `N`, then `U`):

```sh
python3 $S commit G1 -m "<subject>" -m "<body paragraph>" -m "<attribution lines>"
```

Leave out the `-m` flags you do not need. Each run prints `committed <sha> G1: …` and what is left.

| Output | Do |
|---|---|
| `committed …` | next group |
| `changed since the scan, left uncommitted` | carry on; Step 7 picks them up |
| `HEAD moved while committing` | another session committed: go back to Step 3 |
| `… belongs to a session that edited in the last 10 minutes` | skip that group |
| any other error, twice for one group | stop and report the output |

Done when: every group with a message is committed or skipped.

## Step 7: Scan again until nothing is left

Changes made while you worked, and hunks that moved, show up as new groups:

```sh
python3 $S scan | head -c 12000
```

Shape, message and commit them as in Steps 4–6. Stop when the scan prints `nothing left to commit`, or prints only `LIVE` and `HOLD` groups, or after the third pass.

Done when: one of those three holds.

## Step 8: Report

Clear the plan, then show the result:

```sh
python3 $S done
git log --oneline <first-sha>~1..HEAD
git status --short | head -n 20
```

Reply with the commit list, what was left uncommitted and why (`LIVE`, `HOLD`, or stopped), and one line: "Commits were made without hooks and each was not built on its own; run the project's checks on HEAD before pushing."

Done when: `ls .git/split-commits 2>/dev/null` prints nothing and the reply lists every new commit.

## Done means

- `python3 $S scan` prints `nothing left to commit`, or only `LIVE` / `HOLD` groups, each named in the reply.
- `git log --oneline -20` shows the new commits, each with one subject per piece of work.
- Nothing was pushed, and `git stash list` is unchanged.
