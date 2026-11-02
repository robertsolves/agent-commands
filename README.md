# agent-commands

Slash commands for coding agents that clean up after coding agents.

I build most of my apps with Claude Code, Codex and a couple of free models doing the grunt work. They're fast, but they leave a mess behind. A `catch` that returns an empty list so a test goes green. A helper nobody calls any more. A doc that describes how things worked two refactors ago. A half-finished change from a session that ran out of tokens.

These are the commands I wrote to find that mess and fix it properly. They started inside one of my own projects. I pulled out the ones that don't depend on it, and they now run in any repo and in most agents.

Most of them follow the same pattern. Search the code, check each finding against the code again, show you a short list, ask what you want done, then fix only what you said yes to. Nothing gets changed before you answer.

## Install

From the root of your project:

```sh
curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/install.sh | bash
```

Or clone it and point it at a project:

```sh
git clone https://github.com/robertsolves/agent-commands.git
./agent-commands/install.sh --project ~/code/my-app
```

The script puts everything in `.agents/` and links it into the folders each agent reads. It works out which agents you use from the folders in your project and the CLIs on your PATH. To choose yourself, pass `--tools`:

```sh
./install.sh --tools claude,codex,cursor      # or --tools all
./install.sh --only find-bandaids,audit-slop  # just these
./install.sh --list                           # see what's in here
./install.sh --dry-run                        # show what would change
```

With curl, put the flags after `bash -s --`, for example `curl ... | bash -s -- --tools all`.

You need bash and [ripgrep](https://github.com/BurntSushi/ripgrep). Most commands call `rg`. On Windows, use Git Bash or WSL.

## Install several kits at once

This repo is one of three kits that work together:

| Kit | What it adds |
|---|---|
| `template` | [agent-project-template](https://github.com/robertsolves/agent-project-template): `AGENTS.md`, folder guides, `BUGS.md`, `TODO.md`, a changelog agents can only append to |
| `commands` | [agent-commands](https://github.com/robertsolves/agent-commands): cleanup, audit and review commands for any language |
| `dart` | [dart-agent-kit](https://github.com/robertsolves/dart-agent-kit): Dart and Flutter commands and a reviewer subagent |

Pick any mix, in one line:

```sh
curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- add template commands dart
```

`all` installs all three. `remove dart` takes one out again. They share `.agents/` and `.agents/project-facts.md`, and each keeps its own list of the files it wrote, so adding or removing one never touches the others.

### Keep them up to date

Each kit remembers the agents and commands you picked, so updating is one line:

```sh
curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- update
```

If you'd rather have updates come in as a reviewable git change, add the kits as submodules instead:

```sh
curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- add commands dart --submodule
```

Each kit then lives in `.agents/kits/<repo>`, and the project links to its files instead of copying them. `update` moves the submodules to the latest commit and adds links for any new commands. Once agent-commands is a submodule, the update runs from inside the project, with no download:

```sh
bash .agents/kits/agent-commands/kit.sh update
```

You see the whole change in `git diff`, and nothing changes until you commit it. Teammates clone with `--recurse-submodules`. On Windows, turn on `git config core.symlinks true` first.

To have it happen by itself, `kit.sh autoupdate` writes a GitHub Action that runs `update` every Monday and opens a pull request. You need to allow Actions to create pull requests in the repo settings.

The template is never updated, because its files are yours to edit.

### Or just ask your agent

Run this once on your machine:

```sh
curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- setup
```

It adds a small `agent-kits` skill to your user folders (`~/.claude/skills`, `~/.agents/skills`, and Antigravity's if you have it). After that, in any project, tell Claude Code, Codex, Cursor, Gemini CLI or OpenCode "add the agent commands and the dart kit", or type `/agent-kits`. The agent picks the kits and runs the line above for you.

### Install globally

To have the commands in every project without installing them one by one, clone the repo once and link it into your user folders:

```sh
git clone https://github.com/robertsolves/agent-commands.git ~/agent-commands
mkdir -p ~/.claude/commands ~/.agents/skills
for f in ~/agent-commands/commands/*.md; do ln -sf "$f" ~/.claude/commands/; done    # Claude Code, /name
for d in ~/agent-commands/skills/*/; do ln -sfn "${d%/}" ~/.agents/skills/; done      # Codex and other skill readers
```

Update with `git -C ~/agent-commands pull`. The links follow it, so there is nothing to reinstall. Remove one with `rm ~/.claude/commands/<name>.md`.

The commands still read their facts from the project you run them in, so run `/setup-project-facts` once per project. If you want a project to carry its own copy (so teammates get it too), use the per-project install above instead. For just the `agent-kits` skill on your machine, run the `setup` line above.

## Then fill in your project facts

The commands never assume your paths. Where is your bug list? How do you run the tests? Which odd-looking workaround is on purpose? They read the answers from one file, `.agents/project-facts.md`. The installer creates it from a template.

Run `/setup-project-facts` once. It reads your README, CI config and manifests, fills in what it can, and asks you about the rest. If a command needs a fact that's still blank, it stops and asks you rather than guessing.

## Running a command

| Agent | How |
|---|---|
| Claude Code, OpenCode, Kilo, Gemini CLI | `/find-bandaids` |
| Antigravity, Cursor, GitHub Copilot, Windsurf | `/find-bandaids` |
| Codex | `$find-bandaids` |
| Freebuff | `/skill:find-bandaids` |
| Anything else | "Open `.agents/commands/find-bandaids.md` and follow it" |

Text after the name is passed to the command. Most take a folder or area to focus on, for example `/find-dead-code lib/auth`.

## What's in it

Cleaning up after agents:

| Command | What it does |
|---|---|
| `/find-bandaids` | Finds patches that hid a bug instead of fixing it, traces each to the real cause, then fixes the ones you pick. |
| `/audit-slop` | Read-only report on the mistakes agents keep making: made-up APIs, swallowed errors, tests that test nothing. |
| `/find-unfinished` | Reads recent session transcripts and git state to find work an interrupted session never finished. |
| `/resume-session` | Picks up a session from Claude Code, Codex, Gemini CLI, OpenCode, Kilo or Antigravity and carries on in whatever agent you're using now. |
| `/split-commits` | Splits a big pile of uncommitted changes from several sessions into one commit per piece of work, by matching each changed hunk to the transcript that wrote it. |
| `/refine-findings` | Checks every entry in a bug list or audit against the code. Deletes the wrong ones and fixes the rest. |

Finding problems:

| Command | What it does |
|---|---|
| `/find-dead-code` | Dead code, why it died, and what to do with each piece. |
| `/find-stale-references` | Links, paths, symbols, commands and env vars that point at nothing. |
| `/find-bad-comments` | Comments that lie, describe old behaviour or just repeat the code. |
| `/find-confusing-things` | Docs that disagree with each other or with the code, and one word used for two things. |
| `/find-readability-improvements` | Code a tired person would struggle to read, with a fix for each. |
| `/find-exploits` | Missing ownership checks, auth bypasses, injectable queries, weak tokens, unsigned webhooks. |
| `/find-compliance-issues` | Places the code breaks the privacy policy, for example data the export or account deletion misses. |
| `/find-seo-aeo-improvements` | Why the marketing site isn't being found or quoted by search engines and AI answers. |
| `/fix-sentry` | Pulls open Sentry issues, checks which still happen in the current code, and fixes them. |

Reviews and audits:

| Command | What it does |
|---|---|
| `/audit-product` | Uses the app as a real user would, asks you hard questions about what it finds, then fixes what you confirm. |
| `/audit-devex` | Looks at scripts, tooling and repeated pain in the code, and asks how your dev setup could be faster. |
| `/check-production-readiness` | GO or NO-GO on whether the project is ready for real users. Lists blockers first and changes nothing. |
| `/audit-cloudflare-dns` | Compares each Cloudflare zone with what the project expects and what DNS actually answers. Uses your signed-in Chrome. |
| `/interview-code` | Goes through the source and asks you the product questions only you can answer, then writes the answers into the code and docs. |
| `/interview-docs` | Same idea for your docs: gaps, contradictions and vague claims, three questions at a time. |
| `/interview-risky-spot` | Picks one risky file and asks whether the code really does what you meant. Read-only. |

Keeping things tidy:

| Command | What it does |
|---|---|
| `/unify-patterns` | Gives every recurring job one pattern and every kind of file one layout, so you can read one and skim the rest. |
| `/update-docs` | Updates the core docs to match the code. Shows you the diff list first. |
| `/improve-markdowns` | Rewrites markdown files to be clearer and shorter, and keeps `CLAUDE.md` and `README.md` lean. |
| `/improve-prompts` | Improves a prompt as a controlled experiment: baseline, one hypothesis, one change, rerun, decide by a rule fixed in advance. |
| `/improve-agent-prompts` | Rewrites every agent prompt so a weak free coding agent can follow it. Changes how a prompt is written, never what it does. |
| `/setup-project-facts` | Fills in `.agents/project-facts.md`. |

Handing work to a free model:

| Command | What it does |
|---|---|
| `/kilo` | The free Kilo CLI explores the repo and writes a report. It checks its own report, then your main agent does the work. |
| `/kilo-loop` | Kilo does the whole task and audits its own changes until two audits in a row are clean. Then your agent reviews the diff. |
| `/kilo-refine-findings` | `/refine-findings`, but with Kilo doing the rounds. |

These three need the [Kilo CLI](https://kilo.ai) and use its free models only. They're how I keep big exploration jobs from eating my Claude budget.

There are also three skills the agent loads by itself when they're relevant: `production-readiness` (is this one change safe to ship), `privacy-compliance` (the privacy baseline a change has to keep) and `ui-logic-separation` (keeping business rules out of UI code).

## How it's laid out in your project

```
.agents/commands/      the commands, one markdown file each
.agents/skills/        the skills, plus a small wrapper per command for agents that only read skills
.agents/project-facts.md
.claude/commands/      links back to .agents (also .opencode/, .kilo/)
.gemini/commands/      small TOML files that point at the markdown
```

There's one copy of each command, in `.agents/commands/`. Every other folder links or points back to it. Claude Code only gets links to the real skills, not the command wrappers, so each command shows up once in its `/` menu.

The installer also adds a short section to `AGENTS.md` listing the commands, so agents that read nothing else still know they exist. `--no-agents-md` skips it.

Commit `.agents/` and the tool folders, and everyone on the team gets the same commands.

## Updating and removing

Run the installer again to update. It keeps a list of every file it wrote in `.agents/.installed/agent-commands.txt`, replaces those, and leaves your own files alone. If you already have a file with the same name, it skips it and tells you. `--force` replaces it anyway.

```sh
./install.sh --uninstall
```

This removes everything on that list and the `AGENTS.md` section. It leaves `project-facts.md` alone, since you probably wrote some of it.

Don't edit the installed commands directly, because the next update overwrites them. Put anything project-specific in `project-facts.md`. To change how a command works, fork this repo.

## Writing your own

A command is a markdown file in `commands/` with a one-line `description` in the frontmatter. After adding or renaming one, run `python3 scripts/sync_wrappers.py` to regenerate the skill wrappers. `--check` tells you if any are out of date.

The commands are written so that a cheap model can follow them: numbered steps, an exact shell command where there is one, a "Done when" line on every step and a check at the end.

## Related

- [dart-agent-kit](https://github.com/robertsolves/dart-agent-kit): Dart and Flutter commands, a reviewer subagent and the Effective Dart rules as a skill.

## Licence

MIT
