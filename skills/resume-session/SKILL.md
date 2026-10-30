---
name: resume-session
description: >-
  Find a session from any coding agent (Claude Code, Codex, Gemini CLI, OpenCode, Kilo, Antigravity) in the local caches, read its transcript, and carry on its work here. Run when an agent ran out of tokens or crashed mid-task and you want to continue that one session in this agent. Not for finding every half-done thread — use /find-unfinished.
---

# resume-session

Read `../../commands/resume-session.md` (from the project root: `.agents/commands/resume-session.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
