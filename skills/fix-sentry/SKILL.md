---
name: fix-sentry
description: >-
  Pull every unresolved Sentry issue across the project's Sentry projects, check each against the current code, list the ones still live, then fix them. Run after a release, when Sentry mails about a new issue, or as a periodic sweep. Not for a bug list that is not in Sentry — use /refine-findings.
---

# fix-sentry

Read `../../commands/fix-sentry.md` (from the project root: `.agents/commands/fix-sentry.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
