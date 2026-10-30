# Example questions

Read by Step 4 of `.agents/commands/audit-devex.md`. Paths and names below are made up; use the real ones you found.

> 1. **(debug friction)** There is no `<ide config>/launch.json`. To run the backend with breakpoints the developer has to start it in a terminal and attach an inspector by hand. Intentional, or should I add a launch config for `<server entry file>` with breakpoints out of the box?
>
> 2. **(repeated boilerplate)** Every handler in `<routes folder>/*` starts with the same 8 lines: parse body, validate, wrap in try/catch, log on error. 14 handlers, about 110 duplicated lines, and every new route must remember them. A `defineRoute(schema, handler)` helper could make it 1 line per route. Worth doing, or is the explicit code intentional?
>
> 3. **(manual step)** `<release script>:1` bumps the version, but the changelog and git tag are done by hand (`README.md:104`). Every release repeats the same 4 steps in the same order. A recipe could chain bump, changelog, tag, push. Intentional review gate, or worth automating?
>
> 4. **(consistency issue)** Three entry points run the dev server: `<script one>`, `<script two>`, `<package manifest>#dev`. Each sets `NODE_ENV` differently, and new contributors run the wrong one. Consolidate to one and delete the others?
>
> 5. **(silent failure)** `<service a>:54`, `<service b>:88` and `<service c>:31` all have `catch (_) {}`. When the auth flow breaks in staging the developer has no signal. Log and rethrow, or deliberately suppressed?
>
> 6. **(tribal knowledge)** Three files carry the same workaround comment (`// must call before super.initState: Android crashes otherwise`). Only convention enforces the order. Wrap it in a helper that makes the wrong order impossible, or leave the comment?
>
> 7. **(onboarding friction)** `README.md` says "copy `.env` from the password manager" but there is no `.env.example`. I count 11 distinct env var reads in the code. Generate `.env.example` from them?
>
> 8. **(safety net missing)** No pre-commit hook runs the analyzer or formatter; CI catches it 5 minutes later. Add a hook runner wired to staged files only?

## Not a good question

- "Should we adopt framework X?" is an architecture decision.
- "This function is long, split it?" is code style.
- "Add more tests." is process advice.
- "Upgrade dependency Y." is dependency hygiene.
- "Switch from npm to pnpm?" is a runtime swap, unless there is a specific concrete friction.
- "The README could use more emoji." is taste.
