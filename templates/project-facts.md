# Project facts for the agent commands

The commands in `.agents/commands/` work in any project because they never name a path of their own. When one needs to know where your bug list is, how to run your tests or what counts as a deliberate workaround, it reads the matching bullet below.

Keep each bullet on one line, and keep the bold name at the start exactly as it is: commands find a bullet by searching for its name. Replace everything in `<angle brackets>`. A bullet that still has angle brackets has not been filled in. When a command meets one, it stops and asks you. Delete a bullet only if you never run the commands that read it. `/setup-project-facts` fills this file in by reading the repo and asking you about anything it can't find.

- **Checks and tests**: after a change, run `<lint or analyze command>` and `<test command>`. A schema or generated-code check, if there is one: `<command>`. A command that changes behaviour adds a changelog line with `<how, or "none">`.
- **Records**: open bugs go in `<BUGS.md or issue tracker>`, deferred work in `<TODO.md>`, tasks only a human can do in `<file>`, fixes in `<CHANGELOG.md>`. `/find-bandaids` parks the findings it keeps or defers under a `# Bandaids` heading in the deferred-work file.
- **Audit records**: each audit command keeps its findings in its own file, for example `/find-exploits` → `<todo/exploits.md>`, `/find-dead-code` → `<todo/dead_code.md>`, `/find-stale-references` → `<todo/stale_references.md>`. A re-run checks the open entries again first. Missing files are created on the first run.
- **Readability and comments**: the style guide or lint rules that define readable code here: `<path, or "none beyond the linter">`. Comment rules: `<path or one line>`.
- **UI and business code**: where UI lives `<path>`, where shared state lives `<path>`, where pure business rules live `<path>`, shared widgets or components `<path>`, analyze command `<command>`.
- **Security**: how auth works `<doc or file>`, where request guards are written `<path>`, and the switch every dev-only bypass hangs off `<flag name, or "none">`.
- **Compliance**: privacy policy and terms `<paths>`, where personal-data fields are declared `<schema path>`, data export `<doc or code path>`, account deletion or purge `<doc or code path>`. Questions that need a lawyer go to `<file>`.
- **Marketing site and SEO**: site source `<path>`, routes `<file>`, page head or meta tags `<file>`, sitemap and robots `<how they are made>`, brand voice `<doc, or "none">`.
- **Production readiness**: the pre-launch checklist `<path>`, release scope `<path>`, deploy runbook `<path>`, and the gates that must pass before release `<scripts or commands>`.
- **Search helpers**: symbol finder `bash .agents/skills/search-helpers/scripts/find_symbol.sh SYMBOL`, capped search `bash .agents/skills/search-helpers/scripts/capped_grep.sh PATTERN PATH`, doc drift `bash .agents/skills/search-helpers/scripts/doc_drift.sh`. Swap in the project's own scripts if it has better ones.
- **Product brief**: what the product is and who it is for, `<doc path, or one sentence>`. Words with a special meaning here are defined in `<glossary path, or "none">`.
- **Deliberate workarounds, never flagged as band-aids**: `<file:line or description, one per item, separated by semicolons>`, or "none".
- **Deliberately unused, never flagged as dead code**: `<paths or symbols kept on purpose, and why>`, or "none".
- **Who uses shared code**: `<shared package or folder>` is used by `<the apps or packages>`. A symbol there is dead only when none of them reference it.
- **Endpoints**: one endpoint lives in `<path pattern>` and is registered in `<router file>`, or "no API".
- **Patterns**: the pattern catalogue `/unify-patterns` reads and writes is `<doc path>`, and a sanctioned exception is marked `<comment marker>`.
- **Agent prompts**: commands live in `.agents/commands/`, skills in `.agents/skills/`, rules in `.agents/rules/`. After editing a command, run `<checks, or "none">`.
- **Prompts**: AI prompts the product itself sends are in `<path, or "none">`, and are tested with `<tool or doc>`.
- **DNS**: the domains and the hostnames each one should serve are listed in `<doc path>`.
- **Sentry**: org `<slug>`, projects `<slugs>`, and the triage rules in `<doc path>`, or "not used".
- **Core docs**: the docs `/update-docs` keeps true, and what each one must match: `<list or doc path>`.
- **Dart packages**: the packages are `<paths>`, the style rules are in `<path>`, generated files are `<glob, e.g. *.g.dart>`, and anything out of scope is `<paths>`, or "not a Dart project".
- **Session transcripts**: Claude Code keeps them in `~/.claude/projects/<this repo's path with / replaced by ->/*.jsonl`. Codex keeps them in `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. Add others you use.
