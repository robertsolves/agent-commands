---
name: find-compliance-issues
description: >-
  Find where the app breaks its own privacy and legal promises — policy retention periods the purge doesn't honour, personal data missing from the export or the deletion, children's-data rules not enforced, consent not recorded on every sign-up path, store privacy labels that don't match what the code collects, and any gap against the privacy-compliance baseline — with evidence from the code, ask which to fix, then fix them, sending anything that needs a lawyer to the owner. Run before launch, after a schema change that adds personal data, and after any edit to the privacy policy or terms.
---

# find-compliance-issues

Read `../../commands/find-compliance-issues.md` (from the project root: `.agents/commands/find-compliance-issues.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
