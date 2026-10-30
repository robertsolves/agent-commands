---
name: kilo
description: >-
  Investigate a prompt with the free Kilo CLI (read-only), have Kilo audit its own report, then take over and do the work. Run when a task needs heavy repo exploration and you want to save Claude tokens. Not for handing Kilo the edits as well — use /kilo-loop; not for small tasks where writing the brief costs as much as doing the work — just do those.
---

# kilo

Read `../../commands/kilo.md` (from the project root: `.agents/commands/kilo.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
