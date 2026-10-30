---
name: kilo-refine-findings
description: >-
  Refine a findings document (a bug list, an audit of API bugs, a TODO file, a list of stale comments) with the free Kilo CLI: each round Kilo re-checks every entry against the code, deletes the fixed or false ones, corrects the drifted ones, then adds new entries of the same kind, until two rounds in a row leave the document unchanged; then you spot-check the changes once. Run when a findings document needs a deep refresh while spending as few Claude tokens as possible. Not for one careful pass by you — use /refine-findings; not for doing a task — use /kilo-loop.
---

# kilo-refine-findings

Read `../../commands/kilo-refine-findings.md` (from the project root: `.agents/commands/kilo-refine-findings.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
