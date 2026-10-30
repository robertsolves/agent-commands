---
name: find-unfinished
description: >-
  Find work left half-done by interrupted agent sessions — reconstruct intent from recent session transcripts and git state, verify what actually landed in the code, ask the user which threads to finish, then finish them. Run after a crashed or closed-mid-task session, or whenever the repo feels mid-flight. Not for carrying on one known session — use /resume-session.
---

# find-unfinished

Read `../../commands/find-unfinished.md` (from the project root: `.agents/commands/find-unfinished.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
