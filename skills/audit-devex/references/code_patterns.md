# Repeated pain patterns to look for in code

Read by Step 2 of `.agents/commands/audit-devex.md`. You are not reviewing correctness; you are spotting patterns that cost time every week.

- **Repeated boilerplate.** The same try/catch wrapper, JSON-parse-and-validate dance, or log-entry / log-exit / measure-duration preamble. Repeated 3 or more times means codegen, middleware, mixin, decorator or helper.
- **Manual steps that happen every time.** Hand-rolled DTO-to-domain mapping, manual route registration, hand-edited barrel exports, hand-curated dependency-injection lists. If adding something in one place means remembering a second place, that is a future bug.
- **Magic strings duplicated.** The same env-var name, route, query param, table column or feature flag spelled in several files. The second occurrence is the smoking gun.
- **Copy-pasted setup in tests.** The same 15 lines of fixture wiring in every test means a fixture, `beforeEach` or test factory is hiding there.
- **Comments that document a workaround.** `// don't change this, breaks on Android`, `// see incident #1234`, `// must run before X`. Each is a tribal-knowledge fact. Ask whether an assert, a type or a build step should enforce it instead.
- **Error handling that swallows.** `catch { /* ignore */ }`, `catch (_) {}`, a bare `.catch(() => null)`. Each is a future debugging session that starts in the dark.
- **Logging without structure.** `print` / `console.log` / `fmt.Println` scattered across the code, so the developer cannot grep for what they need when CI or staging breaks.
- **Hand-rolled scripts that wrap a CLI the project already uses.** A `scripts/build.sh` that only adds one env var to `cargo build` could be a `Makefile` or `justfile` recipe, which is easier to discover.
- **Drift between similar files.** Two route files, service classes or test setups that almost agree. The next developer picks the wrong one to copy.
