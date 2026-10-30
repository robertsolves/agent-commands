---
name: setup-project-facts
description: >-
  Fill in .agents/project-facts.md, the one file the other agent commands read for anything about this project (where bugs are recorded, how to run the tests, what is a deliberate workaround). Reads the repo first and asks only what it cannot find. Run once after installing the commands, and again when a command stops because a bullet is unfilled.
---

# setup-project-facts

Read `../../commands/setup-project-facts.md` (from the project root: `.agents/commands/setup-project-facts.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
