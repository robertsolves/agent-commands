---
name: kilo-loop
description: >-
  Hand a whole task to the free Kilo CLI: Kilo does the work, then audits and fixes its own changes in a loop until two audits in a row find nothing, and only then do you audit the final diff. Run when a task is well defined and you want a cheap model to do the edits while spending as few Claude tokens as possible. Not for investigation where you make the edits — use /kilo; not for small tasks where writing the brief costs as much as doing the work — just do those.
---

# kilo-loop

Read `../../commands/kilo-loop.md` (from the project root: `.agents/commands/kilo-loop.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
