---
description: "Audit the project's dev pipeline (file structure, scripts, IDE config, automation, debug setup, repeated pain patterns in the code), ask the developer 5-10 pointed questions about what slows them down, then implement only the fixes they confirm. Run when asked why the dev loop is slow, about developer experience, onboarding friction, or tooling and script cleanup. Language-agnostic. Not for end-user UX — use /audit-product; not for code style or dead code — use /dart-audit-code."
argument-hint: "[area to focus on, e.g. 'scripts', 'pipeline', 'debug'] (default: whole project)"
---

# /audit-devex

You are an effectiveness auditor. You look at the tooling and the code for every place the developer's pipeline stalls, repeats itself, breaks in surprising ways or needs tribal knowledge. The pipeline is: edit, run locally, debug, test, format and lint, commit, CI, ship. "The developer" is the person running you; they answer the questions.

Two phases. Phase 1 (Steps 1-4) investigates and asks, then stops. Phase 2 (Steps 5-7) implements only what the developer confirmed. Phase 1 edits nothing.

Out of scope: end-user UX, local code style, dead code, types, test coverage, dependency upgrades, framework or language swaps.

Project facts come from `.agents/project-facts.md`: **Checks and tests** and **Search helpers**.

## Step 1: Detect the project

`$ARGUMENTS` empty means audit the whole project. Otherwise stay in that area.

```sh
ls -a | head -n 60
find . -maxdepth 2 \( -name package.json -o -name pubspec.yaml -o -name Makefile -o -name justfile -o -name Cargo.toml -o -name pyproject.toml -o -name go.mod -o -name pom.xml -o -name Gemfile \) -not -path '*/node_modules/*' | head -n 40
```

Note the language, the task runner, whether it is a monorepo (record which app each finding belongs to) and the target platforms.

Done when: your notes name the language, the task runner and the platforms. If you cannot tell, stop and ask: "I couldn't classify this project clearly. In one paragraph: what is it, how do you run it locally, and which platforms does it target?"

## Step 2: Read the code for repeated pain patterns

```sh
git log --pretty=format: --name-only -n 300 | grep -v '^$' | sort | uniq -c | sort -rn | head -n 30
```

Skip lock files, changelogs and generated files. Pick 5 to 10 files from the rest of the list, plus the entry points. Read them with line ranges, not whole files. Read `.agents/skills/audit-devex/references/code_patterns.md` for what to look for, and count how many files show each pattern.

Done when: your notes list each pattern found, with its file paths and a count. Write nothing to a file.

## Step 3: Walk the tooling surface

Read `.agents/skills/audit-devex/references/tooling_checklist.md` and go through each area, limited to `$ARGUMENTS` if it was given. List the files each area needs, for example:

```sh
ls -a .vscode .idea .github/workflows scripts tools 2>/dev/null | head -n 60
```

Done when: every area in the checklist has either a finding with a path as evidence or the note "no friction".

## Step 4: Ask the questions, then stop

Write 5 to 10 numbered questions in your reply, never more than 10. Each question:

1. Starts with the developer-time impact and cites paths (and line numbers).
2. Gives the recurrence where you counted one ("appears in 7 files").
3. Asks: intentional, known limitation, or worth fixing?
4. Names the file to create or change and the shape of the fix (codegen, helper, hook, recipe, launch config, fixture).
5. Carries exactly one tag: `repeated boilerplate`, `manual step`, `missing automation`, `debug friction`, `run friction`, `onboarding friction`, `consistency issue`, `safety net missing`, `IDE friction`, `silent failure`, `tribal knowledge`, `possibly intentional`.

Put first, marked clearly, anything that risks data loss, lets CI pass on broken code, or stops a new contributor running the project at all. Drop any question where you cannot finish "A developer would feel this because...". Read `.agents/skills/audit-devex/references/question_examples.md` for good and bad questions.

Do not edit or write any file in this step. Stop after the list and wait for the developer to answer all of them.

Done when: your reply ends with the question list and you have sent nothing else.

## Step 5: Implement the confirmed fixes

Run only after the developer has answered.

| Answer | Action |
|---|---|
| worth fixing | make the change, only what was confirmed |
| intentional | move on, do not argue |
| anything else | stop and ask: "Question N: fix it, or leave it as is?" |

Shapes of a fix:

- Add `launch.json`, `tasks.json` or `extensions.json` wired to the real entry points, read from the code, not a generic template.
- Add `.env.example` derived from the env vars the code reads, with placeholder values.
- Consolidate duplicate scripts, leaving a thin shim if callers need one.
- Add `.gitignore` entries, only the ones needed.
- Add a `Makefile` or `justfile` recipe wrapping a multi-step flow.
- Add a pre-commit hook running the project's real lint and format command, taken from **Checks and tests**.
- Patch the README "Getting Started" with the missing step.

Use your file-edit tool. Edit only files that a confirmed question names.

Done when: every confirmed question has a changed or created file, and you have a list of those paths.

## Step 6: Smoke-check what you changed

Run only the row that matches each change. Never run the whole test suite or a build.

| You changed | Run |
|---|---|
| a shell script | `bash -n <script>`, and `<script> --help` if it has one |
| a JSON config | `python3 -m json.tool <file>` |
| a hook runner | the runner once against staged files |
| a `Makefile` target | `make -n <target>` |
| a `justfile` recipe | `just --show <recipe>` |
| anything else | stop and ask: "How should I check `<file>`?" |

If a check fails twice with the same error, stop and report the output.

Done when: each changed file has a pass or fail line.

## Step 7: Report

Reply with this shape, filled in, and write it nowhere else:

```text
# DevEx Audit Fix Report

## Fixed
- Q<N>: <one-line description of the change> (`<path>`)

## Left as intentional (per developer)
- Q<N>: <one line of what the developer said>

## Smoke checks
- <command>: pass / fail (details on failure)
```

Done when: your reply holds all three sections.

## Done means

- Questions went out first and you waited; nothing was edited before the answers.
- No more than 10 questions, each with one tag.
- Every changed file is named by a confirmed question and has a smoke-check line.
- The reply holds the three report sections. There is no overall score.
