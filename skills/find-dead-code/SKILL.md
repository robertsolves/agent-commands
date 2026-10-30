---
name: find-dead-code
description: >-
  Find dead code across the project's packages, figure out why each piece is dead (orphaned by a refactor, never wired up, deliberate dark-launch, superseded), then — with the user's confirmation — remove it or wire it back in. Run after large refactors or as periodic hygiene.
---

# find-dead-code

Read `../../commands/find-dead-code.md` (from the project root: `.agents/commands/find-dead-code.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
