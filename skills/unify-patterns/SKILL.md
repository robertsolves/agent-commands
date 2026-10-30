---
name: unify-patterns
description: >-
  Make the codebase skimmable by giving every recurring job one pattern and every kind of file one skeleton (same names, parameters, outputs, flow and part order), plus one predictable file tree and one name per concept across layers. Discover across every package (coverage ledger, skeleton comparison, cross-cutting sweep, adversarial gap check), have the owner pick the canonical pattern per family, migrate one family per run without changing behaviour, split oversized files, add a guard against drift, and fix every confirmed bug as its own change. Run when asked to unify patterns, make files consistent, or find drift between files of the same kind; no argument discovers, a family id migrates it, `split <path>` splits a file. Not for style lint — use /dart-clean-packages; not for a readability ranking — use /find-readability-improvements.
---

# unify-patterns

Read `../../commands/unify-patterns.md` (from the project root: `.agents/commands/unify-patterns.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
