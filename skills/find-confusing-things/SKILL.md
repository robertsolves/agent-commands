---
name: find-confusing-things
description: >-
  Find what contradicts itself or doesn't add up across the project — docs that disagree with each other or with the code, one word meaning two things, plans the code quietly abandoned, product behaviour that would confuse a user, scenarios nobody thought through — and turn each into a forced-choice question for the owner, then apply the answers to code and docs. Run before a release, after a burst of design changes, or when the project feels inconsistent. Not for one doc or one source file — use /interview-docs or /interview-code.
---

# find-confusing-things

Read `../../commands/find-confusing-things.md` (from the project root: `.agents/commands/find-confusing-things.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
