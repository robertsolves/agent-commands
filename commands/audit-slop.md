---
description: Read-only audit for the anti-patterns AI coding agents repeatedly introduce (hallucinated APIs, missing ownership checks, swallowed errors, silent fallbacks, fake tests, drift, prose slop in comments and UI strings), then sweep the rest of the codebase for the same mistakes. Run on a diff before merging, or with `all` for a full sweep. Not for fixing band-aids with the user — use /find-bandaids; not for Dart-only rulebook checks — use /dart-audit-code; not for comment accuracy alone — use /find-bad-comments.
argument-hint: "[all | path ...] (default: git diff HEAD)"
allowed-tools: Read, Grep, Glob, Bash, Edit
---

# /audit-slop

You are a code auditor looking for the failures AI coding agents repeatedly introduce. This audit is read-only: it writes no fix, and its only edit is Step 8's one-line additions to its own dimensions file. Print findings in your reply, not to a file. Do not write corrected code; if you start to, rewrite the reply as findings only.

## Step 1: Resolve scope and project facts

`$ARGUMENTS` decides the scope:

| `$ARGUMENTS` | Scope |
|---|---|
| empty | the diff: `git diff HEAD` |
| `all` | the entire codebase, one package at a time |
| file or folder paths | only those paths |

Load the project facts:

```sh
rg -n '^- \*\*(Records|Checks and tests|Search helpers)\*\*' .agents/project-facts.md | head -n 5
```

Read the project's agent guide (`AGENTS.md` or `CLAUDE.md`): it may set a stricter bar (for example that a silent default is always a defect) and names the product voice.

Done when: you have written down the scope and two placeholders, `<finder>` (the symbol-finder or capped-grep helper from the Search helpers bullet) and `<offenders>` (the "Repeat offenders" checks in the record the Records bullet names for this audit; write `none` if it names none).
If the `rg` prints nothing, stop and ask: "No project-facts file found — which file holds the search helpers and records?"

## Step 2: List the changed files

```sh
git diff HEAD --stat | tail -n 40
```

For `all` or path scope, run `rg -l '.' <path> | head -n 200` instead. Done when: you hold a file list for the scope. This step only lists; no judgement.

## Step 3: Audit code against dimensions 1–9

Read `.agents/skills/audit-slop/references/slop_dimensions.md` § 1 through § 9. Read each file in the list (line ranges for large files) and check it against those dimensions, in order. This step is judgement: no command finds a missing ownership check.

Done when: every file in the list has been read against all nine dimensions, and each finding has a path, a line and a category.

## Step 4: Find prose slop

Read `.agents/skills/audit-slop/references/slop_dimensions.md` § 10. Then find candidates:

```sh
git diff HEAD -U0 | grep -E '^\+[^+]' \
  | grep -inE '\b(delve|tapestry|testament|pivotal|crucial|seamless(ly)?|robust|leverag(e|es|ing)|showcas(e|es|ing)|underscor(e|es)|empower|streamline|comprehensive|meticulous(ly)?|vibrant|cutting-edge|game-changer|effortless(ly)?|holistic|intricate|elevate)\b|it.s worth noting|at its core|serves as an? |in today.s |let.s dive|i hope this helps' | head -n 40
```

For `all` or path scope, run the same pattern with `rg -n -i '<pattern>' <package> --max-count 3 | head -n 60`, after `rg -l` on that package. Read each hit and apply § 10.

Done when: each hit is classed as a Minor finding or dropped as literal use. Zero hits is a valid result.

## Step 5: Run the repeat-offender checks

Run each check listed in `<offenders>`, with its output capped:

```sh
<check-command-from-offenders> | head -n 40
```

Read every hit before calling it a finding. If `<offenders>` is `none`, skip this step.

Done when: each check has a recorded result (hits read, or none).

## Step 6: Sweep for the same mistakes

A bad pattern found once usually exists elsewhere. For each distinct pattern from Steps 3–5 (not each instance):

1. Pick one or two representative instances: the symbol, function or call shape.
2. Turn it into a search for the call shape it always uses (for example a repo `findById(` with no `ownerId` argument, or `?? ''` on a field), one package at a time:

```sh
rg -l '<pattern>' <package> | head -n 30
rg -n --max-count 3 '<pattern>' <files-from-above> | head -c 4000
```

For a plain symbol, use `<finder>` instead.
3. Read only the files returned, on the matching line ranges.
4. Record each confirmed hit under the same category, tagged `(sweep)`. A lookalike you did not confirm is tagged `(suspected)`; never report it as confirmed.

Done when: every distinct pattern has been searched once and its hits are tagged. Sweep hits are findings only.

## Step 7: Report

Print the report in your reply, in this shape:

```md
# Unslop Audit

**Scope:** [files or "git diff"]

## Critical (Security / Runtime)

- `path/to/file.ts:42` — [Category] Short description
  - **Why dangerous:** ...
  - **Root cause:** ...

## Important (Bugs / Edge Cases / Doom Loops)

- `path/to/file.ts:108` — [Category] Short description
  - **Why it breaks:** ...
  - **Root cause:** ...

## Minor (Architecture / Redundancy / Noise)

- `path/to/file.ts:15` — [Category] Short description

## Summary
- Critical: X
- Important: Y
- Minor: Z
- Sweep: N patterns swept, M extra hits
```

Done when: the reply holds every heading above and the four counts match the findings listed.

## Step 8: Learn new patterns

This step is judgement; its only edit is to `.agents/skills/audit-slop/references/slop_dimensions.md`, made with your file-edit tool. List the current bullets first:

```sh
rg -n '^- ' .agents/skills/audit-slop/references/slop_dimensions.md | head -n 120
```

| A finding from Steps 3–6 is… | Action |
|---|---|
| a bad pattern no bullet describes | add one short bullet to the best-fitting dimension (or a new numbered dimension if none fits), named in general terms a future audit in any project can recognise, never this repo's file or line |
| a variant a bullet covers loosely | sharpen that bullet instead of adding one |
| only meaningful in this project | add nothing here; it belongs in `<offenders>` |

Never add repo inventories, finding lists or code snippets: one line per pattern.

Done when: you print the patterns added, one per line, or `patterns: none added`.

## Done means

- No file was edited except `slop_dimensions.md` in Step 8: `git status --short | head -n 5` shows nothing else you changed.
- The reply ends with the `## Summary` block, including the `Sweep` line.
- Every finding names a path and line, and every sweep hit is tagged `(sweep)` or `(suspected)`.
