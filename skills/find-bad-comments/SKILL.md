---
name: find-bad-comments
description: >-
  Find comments that mislead or waste the reader — claims the code no longer backs (numbers, dates, history, invariants), descriptions of old behaviour, comments that restate the code, undefined jargon, backstory essays — and the places a why-comment is missing, verify each against the code and git history, ask which to fix, then rewrite or delete them. Run after a big refactor, before handing code to a new reader, or as periodic hygiene.
---

# find-bad-comments

Read `../../commands/find-bad-comments.md` (from the project root: `.agents/commands/find-bad-comments.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
