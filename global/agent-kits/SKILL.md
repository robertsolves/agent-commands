---
name: agent-kits
description: "Adds Robert Solves agent kits to the current project: the agent-project-template (AGENTS.md, folder guides, BUGS.md, TODO.md, write-only CHANGELOG.md, helper scripts), agent-commands (cleanup, audit and review slash commands for any language), dart-agent-kit (Dart and Flutter commands, reviewer subagent, Effective Dart rules) and prompt-trials (test commands on a free model). Any mix works together. Use when the user asks to add, install, set up, update or remove any of these, or says something like \"add the agent commands\", \"set this project up for agents\" or \"add the dart kit\"."
---

# Add agent kits to this project

| Kit | Short name | Gives the project |
|---|---|---|
| agent-project-template | `template` | `AGENTS.md` with `CLAUDE.md`/`GEMINI.md` imports, folder guides, `BUGS.md`, `TODO.md`, `MANUAL_TODO.md`, a changelog agents can only append to, git hooks, search scripts |
| agent-commands | `commands` | `/find-bandaids`, `/find-dead-code`, `/find-exploits`, `/audit-slop`, `/update-docs` and about 25 more, for any language |
| dart-agent-kit | `dart` | `/dart-audit-code`, `/dart-improve-code`, `/dart-clean-packages`, the `dart-reviewer` subagent, Effective Dart as a skill |
| prompt-trials | `trials` | `/improve-prompts`, `/improve-agent-prompts` and a harness that tests a command on a free model |

## Step 1: Decide which kits

Use the kits the user named. If they only said "set this project up" or similar, recommend:

- `template commands` for any project that has no `AGENTS.md` yet, else `commands`
- add `dart` when the project has a `pubspec.yaml`
- add `trials` only when the user writes their own agent commands

Say which kits you'll add in one line, and go ahead unless the user said to ask first.

## Step 2: Run the installer

From the project root:

```sh
curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- add <kits>
```

For example `... | bash -s -- add template commands dart`. Useful options after the kit names: `--dry-run` to preview, `--tools claude,codex` to pick the agents (the default detects them), `--only find-bandaids,audit-slop` for just some commands. To remove a kit: `... | bash -s -- remove <kits>`. Re-running `add` updates a kit in place.

If a step fails, show the user the last lines of output and stop. Don't edit installed files to work around it.

## Step 3: Finish

1. Tell the user what was added. The installer prints the counts and anything it skipped because a file of the same name already existed.
2. If `.agents/project-facts.md` still has `<placeholders>` and the commands kit was added, offer to run `/setup-project-facts`.
3. If the template was added, offer to fill in "About the project" and "After making changes" in `AGENTS.md` from the README and manifests.
4. Remind them to commit `.agents/` and the tool folders so their team gets the same setup. Don't commit for them.
