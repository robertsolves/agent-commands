---
name: find-stale-references
description: >-
  Find references that point at nothing — doc links and paths to moved files, backticked symbols that were renamed, slash commands that no longer exist, env vars and script names a script still uses, code comments citing dead functions — fix or delete each, and propose a check that would catch the class automatically. Run after renames, moves and deletions, or when docs feel out of date. Not for re-syncing whole core docs with the code — use /update-docs.
---

# find-stale-references

Read `../../commands/find-stale-references.md` (from the project root: `.agents/commands/find-stale-references.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
