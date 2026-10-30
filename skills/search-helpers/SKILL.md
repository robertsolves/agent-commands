---
name: search-helpers
description: "Three small read-only scripts for searching a repo without flooding the context: find_symbol.sh (where a class, function or type is declared, in most languages, plus the files that mention it), capped_grep.sh (matching files first, then a few lines from each) and doc_drift.sh (doc links and backticked paths that point at nothing). Use them instead of a raw grep over a big folder, or when a command asks for the symbol finder, grep helper or drift tool and the project has none of its own."
---

# Search helpers

Run from anywhere in the repo. Each script caps its output and exits 0 on a hit or clean result, 1 on no match or a finding, 2 on bad usage.

```sh
bash .agents/skills/search-helpers/scripts/find_symbol.sh <Symbol> [-t]        # -t includes tests
bash .agents/skills/search-helpers/scripts/capped_grep.sh '<pattern>' [path] [-a]  # -a includes generated and vendored code
bash .agents/skills/search-helpers/scripts/doc_drift.sh [links|paths]          # no argument runs both
```

`find_symbol.sh` matches declarations by keyword (`class`, `def`, `function`, `fn`, `func`, `type`, `const` and the like), so a symbol made some other way, such as an object key or a generated name, shows as "not found". Follow up with `capped_grep.sh '\b<Symbol>\b'` before deciding nothing uses it.

If the project lists its own search scripts in the **Search helpers** bullet of `.agents/project-facts.md`, prefer those. They know the project's generated files and data folders.
