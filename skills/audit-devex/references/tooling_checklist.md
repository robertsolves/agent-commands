# Developer-experience surface checklist

Read by Step 3 of `.agents/commands/audit-devex.md`. For each area, look for friction and cite specific paths as evidence (`<script path>:<line>`, `<config path>` missing).

## Contents

- File and folder structure
- Scripts
- IDE config
- Lint, format, typecheck
- Pre-commit and pre-push hooks
- CI and CD
- Environment and secrets
- Debugging
- Documentation and onboarding
- Git hygiene
- Test ergonomics

## File and folder structure

- Similar things in similar places, or scattered? (One script in `scripts/`, another at the repo root, a third in `tools/`.)
- Graveyard folders: `old/`, `_archive/`, `backup-<year>/`, `tmp/`.
- Files that should be ignored but are not: `.DS_Store`, `*.log`, `coverage/`, IDE caches.
- Large generated artefacts checked in (`dist/`, `build/`). Lock files are usually fine. Checked-in generated source is intentional in some ecosystems: do not assume.

## Scripts

- A single obvious entry point to run the project, or tribal knowledge?
- Scripts that almost duplicate each other (`run.sh`, `run-dev.sh`, `start.sh`).
- `set -euo pipefail` (bash) or the equivalent; do they print what they are doing?
- Common flows (test, lint, format, typecheck, build, deploy, regen) discoverable via `make`, `just`, `npm run`, `dart run`, or only by reading the README?
- Env vars and flags documented at the top of the script, or only inferable from the body?

## IDE config (`.vscode/`, `.idea/`)

- `launch.json`: one-click run and debug configs for the main entry points. Missing breakpoint-attach configs for server, app or tests is a big time sink.
- `tasks.json`: common shell tasks runnable from the IDE.
- `settings.json`: formatter on save, correct interpreter or SDK path, overrides that contradict the user's global settings.
- `extensions.json`: lists the extensions a new contributor needs.
- Project-wide config is checked in; personal state (`.vscode/*.local.json`) is not.

## Lint, format, typecheck

- One canonical config per tool (`.eslintrc`, `.prettierrc`, `analysis_options.yaml`, `ruff.toml`, `rustfmt.toml`, `mypy.ini`).
- Does the IDE apply it, or must the developer remember before pushing?
- An `.editorconfig` for non-IDE editors.
- Contradictions: Prettier against ESLint, `dart format` against `analysis_options`.

## Pre-commit and pre-push hooks

- A hook runner (`husky`, `lefthook`, `pre-commit`, `lint-staged`): does it run lint, format and typecheck on staged files?
- No hook runner: deliberate choice or missing safety net? (Some teams reject hooks because they slow commits; that is fine if intentional.)

## CI and CD

- A CI config (`.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`, `azure-pipelines.yml`): does it run the same checks the developer runs locally? Drift between local and CI is a common time sink.
- Manual release chores that could be automated: release notes, version bumps, changelog, tag-and-push.

## Environment and secrets

- An `.env.example` listing every env var the project reads, with safe placeholders.
- Runtime version pinning: `direnv`, `mise`, `asdf`, `.tool-versions`, `.nvmrc`.
- Secrets loaded from a documented source (1Password CLI, Doppler, AWS SSM), or cobbled together per developer.

## Debugging

- Can the developer set a breakpoint and hit it in one click? If not, what is missing?
- Structured logging or a log viewer, or `print` everywhere.
- Mobile and desktop: a flavor or config switcher (dev / staging / prod) with one-shot run commands.
- Backend: a debugger can attach to a running container or process.

## Documentation and onboarding

- README "Getting Started" works top to bottom on a fresh machine, with no steps long-timers do unconsciously.
- A `CONTRIBUTING.md` or `docs/dev/` describing the dev loop, conventions and gotchas.
- Undocumented prerequisites: Xcode version, Android SDK, specific Node, native libs, system fonts.
- `CLAUDE.md` / `AGENTS.md` / `.cursor/rules/` present and accurate.

## Git hygiene

- `.gitignore` covers IDE caches, OS files, build outputs, env files, coverage reports.
- `.gitattributes`: line endings, binary markers, language overrides.
- Branch protection and merge style are out of scope unless checked-in config is obviously wrong.

## Test ergonomics

- A one-liner to run all tests and a one-liner to run one test.
- Watch mode and IDE test-explorer integration.
- Flaky tests quarantined, or rerun by luck.
