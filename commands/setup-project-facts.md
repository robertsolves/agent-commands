---
description: Fill in .agents/project-facts.md, the one file the other agent commands read for anything about this project (where bugs are recorded, how to run the tests, what is a deliberate workaround). Reads the repo first and asks only what it cannot find. Run once after installing the commands, and again when a command stops because a bullet is unfilled.
argument-hint: "[bullet name to fill, e.g. Records] (default: every unfilled bullet)"
---

# /setup-project-facts

The other commands never name a path of their own. They read `.agents/project-facts.md` instead. This command fills that file in from what the repo already says, and asks the user only for what the repo cannot answer.

Never invent a path or a command. A fact goes in the file only when you have seen it in the repo or the user has said it.

## Step 1: Find the unfilled bullets

```sh
test -f .agents/project-facts.md && rg -n '^- \*\*' .agents/project-facts.md | rg '<' | head -n 40
```

Each printed line is a bullet that still holds `<placeholders>`. If the file is missing, stop and tell the user to re-run the installer, which creates it.

If `$ARGUMENTS` names a bullet, work on that one only.

Done when: you have the list of bullets to fill (write "all filled" and stop if there are none).

## Step 2: Read what the repo already says

Read these when they exist: `AGENTS.md`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, the package manifests (`package.json`, `pubspec.yaml`, `pyproject.toml`, `Cargo.toml`, `go.mod`), `Makefile`, the CI workflows in `.github/workflows/`, and the top of `docs/` or `doc/`.

```sh
ls -a | head -n 60
ls .github/workflows docs doc 2>/dev/null | head -n 40
rg -l -i 'changelog|bugs|todo' --max-depth 2 -g '*.md' | head -n 20
```

For each unfilled bullet, note what you found and the file you found it in. Test and lint commands usually sit in CI workflows or the manifest's scripts. Records are usually top-level markdown files.

Done when: every unfilled bullet has either a sourced answer or "not found".

## Step 3: Ask about the rest

Ask the user about the "not found" bullets, at most four per question, each as multiple choice with your best guess first and "skip, I don't use the commands that need this" last. Wait for the answers.

Done when: every bullet has a sourced answer, a user answer or "skip".

## Step 4: Write the file

Edit `.agents/project-facts.md` with your file-edit tool. Replace the placeholder text in each bullet, keep the bold name at the start of the line exactly as it is, and keep each bullet on one line. For a skipped bullet write "not used here" after the name.

Done when: this prints nothing.

```sh
rg -n '^- \*\*.*<' .agents/project-facts.md | head -n 20
```

## Done means

- No bullet still holds a `<placeholder>` (the check in Step 4 prints nothing).
- Every path you wrote exists in the repo. Check each one with `ls`.
- You told the user which bullets came from the repo and which from their answers.
