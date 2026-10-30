---
name: refine-findings
description: >-
  Take a findings document (a bug list, audit report, TODO file), verify every finding against the actual code, delete the wrong or already-fixed ones, correct and deepen the rest, add a few closely related new findings in the doc's own style, then verify those too. Run when a findings doc is stale, unverified, or thin. Not for writing a new audit from scratch — use the matching /find-* command, or /kilo-refine-findings to have the free Kilo CLI refine it round after round.
---

# refine-findings

Read `../../commands/refine-findings.md` (from the project root: `.agents/commands/refine-findings.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
