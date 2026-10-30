---
name: audit-slop
description: >-
  Read-only audit for the anti-patterns AI coding agents repeatedly introduce (hallucinated APIs, missing ownership checks, swallowed errors, silent fallbacks, fake tests, drift, prose slop in comments and UI strings), then sweep the rest of the codebase for the same mistakes. Run on a diff before merging, or with `all` for a full sweep. Not for fixing band-aids with the user — use /find-bandaids; not for Dart-only rulebook checks — use /dart-audit-code; not for comment accuracy alone — use /find-bad-comments.
---

# audit-slop

Read `../../commands/audit-slop.md` (from the project root: `.agents/commands/audit-slop.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
