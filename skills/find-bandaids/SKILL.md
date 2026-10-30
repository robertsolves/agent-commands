---
name: find-bandaids
description: >-
  Find band-aid fixes left behind by AI sessions — swallowed errors, suppressions, magic delays, special-case patches — trace each to the root cause it papers over, ask the user which to fix properly, then implement the real fix. Run after a stretch of fast agent-driven changes or when a subsystem feels patched-over rather than solved. Not for a read-only report of AI-agent anti-patterns — use /audit-slop.
---

# find-bandaids

Read `../../commands/find-bandaids.md` (from the project root: `.agents/commands/find-bandaids.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
