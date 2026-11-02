---
name: split-commits
description: >-
  Split a large pile of uncommitted changes (from several agent sessions or agents working in one tree at once) into small commits, one per discrete piece of work, by matching each changed hunk to the Claude Code, Codex, Gemini CLI, OpenCode or Kilo session that wrote it, and keep committing until nothing is left. Run when the working tree holds many unrelated changes, or the last unpushed commit is one huge mixed commit, and you want separate described commits. Not for carrying on one session's work — use /resume-session.
---

# split-commits

Read `../../commands/split-commits.md` (from the project root: `.agents/commands/split-commits.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
