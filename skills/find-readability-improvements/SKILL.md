---
name: find-readability-improvements
description: >-
  Find the code a tired human would struggle to read — mode flags threaded through layers, components or functions doing several jobs, logic buried in UI code, parameter lists that travel together unnamed, states the types allow but the product forbids, two names for one concept — rank the worst, ask which to fix, then fix them without changing behaviour. Run when a file feels hard to skim, after a fast feature push, or as periodic hygiene. Not for lint-level checks (names, nullability, `late`) — use /dart-audit-code; not for comments — use /find-bad-comments.
---

# find-readability-improvements

Read `../../commands/find-readability-improvements.md` (from the project root: `.agents/commands/find-readability-improvements.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
