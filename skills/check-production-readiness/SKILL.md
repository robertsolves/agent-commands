---
name: check-production-readiness
description: >-
  Give a GO / NO-GO verdict on whether the project is ready for real users — every open item on the readiness checklist is queued somewhere, the riskiest items marked done really are done, the dev-only switch and its markers are ready to flip, every release gate passes, every P0 item of the production-readiness standard has evidence, and what ships matches the agreed scope — reporting blockers first and changing nothing. Run before opening to real users, and periodically during the run-up to launch.
---

# check-production-readiness

Read `../../commands/check-production-readiness.md` (from the project root: `.agents/commands/check-production-readiness.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
