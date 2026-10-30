---
name: audit-devex
description: >-
  Audit the project's dev pipeline (file structure, scripts, IDE config, automation, debug setup, repeated pain patterns in the code), ask the developer 5-10 pointed questions about what slows them down, then implement only the fixes they confirm. Run when asked why the dev loop is slow, about developer experience, onboarding friction, or tooling and script cleanup. Language-agnostic. Not for end-user UX — use /audit-product; not for code style or dead code — use /dart-audit-code.
---

# audit-devex

Read `../../commands/audit-devex.md` (from the project root: `.agents/commands/audit-devex.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
