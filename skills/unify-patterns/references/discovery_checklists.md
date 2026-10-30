# Discovery checklists for Mode A

## Contents

1. Skeleton axes (A2)
2. Tree and naming checks (A2b)
3. Cross-cutting concerns (A3)
4. Modularity (A5)
5. Decision-sheet blocks (A7)
6. Catalogue entry shape (A8)

## 1. Skeleton axes (A2)

Compare 3 to 5 instances of one file kind (the smallest, the largest, the oldest and the newest by `git log`) on every axis:

- **Location and file name:** folder, name suffix, singular vs plural, one kind per file or several.
- **Layout order:** imports and their grouping, constants, the public class or entry point, then private helpers.
- **Order of repeated units:** the order of handlers, repository methods, service methods, state holders, test cases or script functions. The registration block (router mounts, a dependency registry, group order) must match it. Draft the canonical order, for example list, get, create, update, delete, then other verbs, then private helpers.
- **Names:** the scheme for classes, functions, handlers, fields, state holders, script functions and variables.
- **Inputs:** parameter order, named vs positional, required vs optional, how a request body or script argument is read.
- **Outputs:** return type and shape (response model, domain model, option type, `bool`, record, raw map, exit code with a summary line).
- **Flow:** the order of steps inside a unit. A route handler: authenticate, parse, validate, check permission, call the repository, audit, respond. A client write: guard, optimistic state update, queued or sent write, reconcile. A script: header, shell flags, args, preflight, work, summary, exit code.
- **Errors, logging and comments:** where they sit in the flow, and their style.
- **Tests:** where the test file lives relative to its source, how groups and cases are named, how setup is done.

Every difference is a candidate variant. Count each variant with a capped grep over the whole group.

Kinds to list (units inside a file count too): API endpoint file, repository, service, screen, sheet or dialog flow, primitive widget, view-model, shared data model, request or response model, test file, migration, infrastructure module, workflow, shell script, site component, admin screen, agent tool; route handler, repository method, service method, UI build method, test case, script function.

## 2. Tree and naming checks (A2b)

- **Folder rules.** Per package, state the rule that decides where a file goes (by feature, by layer, or a mix) and list the directories that break it: several screens in one folder, folders whose name does not match their entry file, stray files at a package root, helpers with no clear home. If the catalogue names a guard that lists drifting folders, record that guard's output instead of re-deriving the rule.
- **Test tree.** Does `test/` mirror the source tree in every package? List source files whose test lives under a different path or name.
- **One concept, one name.** Trace each main domain concept (from the catalogue, the glossary or the data model) through: schema table, data model, wire request or response, endpoint folder and URL path, repository, client service, client state, screen folder. Record every place one concept has two names or two concepts share one. Singular vs plural drift counts. Terms the glossary documents as overloaded are known, not new findings.
- **Script names.** Check the verb and noun scheme, the prefix for internal helpers, and where each kind of script lives across every scripts folder.
- **Renames.** Before recommending a rename, grep (capped) for every reference: imports, barrels, docs, the agent guide, command files, CI workflows, scripts. Count them in the migration estimate.

## 3. Cross-cutting concerns (A3)

Sweep each across all packages; each should have one pattern:

- error creation, propagation and display
- logging (tags, levels, what reaches error reporting)
- absence handling (`null` vs an option type vs empty)
- dates, times and time zones
- IDs
- config and env reading
- feature-flag checks
- permission checks
- (de)serialisation and wire-key constants
- user-facing strings and localisation
- caching, retries and timeouts
- async orchestration (awaited, deliberately unawaited, fire-and-forget)
- dependency access
- constants and magic numbers
- file and folder naming, barrels and imports
- comment and doc-comment style
- test structure (setup, fixtures, shared support helpers, naming)
- shell-script structure (header, shell flags, arg parsing, output, exit codes)
- SQL style in repositories and migrations
- infrastructure module and variable layout
- CI job layout

Also sweep every concern the catalogue already records. A concern on neither list becomes a new cross-cutting family.

## 4. Modularity (A5)

- Rank every package's files by `wc -l`, excluding generated files. For each file over budget, list its seams: the separate jobs it does, each nameable in a few words.
- Suggested starting budget for the owner to confirm: a screen or widget file under about 400 lines, everything else under about 800.
- Logic in the wrong layer: rules computed inside a UI build method (home: the view-model or logic layer the agent guide names), business logic in route handlers, SQL outside repositories, domain data held in widget or component state.

## 5. Decision-sheet blocks (A7)

Family block:

```
### <ID> — Failing a request
Variants: return notFound(...) (N sites, M files) · throw NotFoundException (N sites, M files)
Exemplar of each: …
Recommend: <variant>, because <reason>. Migration: ~N sites in M files, risk <low/med/high>.
Semantic traps: <none | what must NOT be merged, and why>
```

File-kind block (illustrative shape, not a decision):

```
### <ID> — API route file
Variants: handler names _getX/_listX (N files) · _handleX (N) · mixed (N); flow parse-then-auth (N) · auth-then-parse (N)
Canonical skeleton:
  imports (language, package, relative)
  class XRoutes { Router get router => Router()..get('/', _list)..get('/<id>', _get)..post('/', _create)…; }  // mounts in handler order
  Future<Response> _list(Request req)   // auth → parse → validate → permission → repo → respond
  Future<Response> _get(Request req)    // canonical order: list → get → create → update → delete → other verbs
  Future<Response> _create(Request req) // same flow, + audit before respond
  private helpers last
Exemplar: …   Migration: ~N files, risk <low/med/high>
```

- Recommend the majority variant, unless a minority one is clearly simpler or safer and cheap to adopt.
- Where code and a doc disagree, recommend whichever fits the readability bar better and name the side that gets rewritten.
- Semantic traps are variants that look like style but mean different things: `isMember` vs `isActiveMember`, `softDelete` vs `purge`, an online-only write that deliberately skips the offline queue. Never merge them without the owner.

## 6. Catalogue entry shape (A8)

```
### <ID> — Failing a request  (decided YYYY-MM-DD)
Pattern: throw <the exception>(message); one error mapper turns it into the error response.
Exemplar: <path/to/exemplar>
Recognise it by: …
Sanctioned exceptions: <list, each with why> — marked in code with `<exception-marker with ID>`
Status: decided · migrating · done (guard: <guard> | none)
```

A file-kind entry also holds the approved skeleton. A file-tree or naming entry holds the folder rule or the concept-name table. If the project has no id scheme yet, use one letter per area (file-kind skeletons, backend, client state, client UI, shared code, tests, scripts/CI/infra, file tree and naming, cross-cutting and modularity) then a number.
