#!/usr/bin/env bash
# Where is a symbol declared, and which files mention it? Usage: bash .agents/skills/search-helpers/scripts/find_symbol.sh <Symbol> [-t]
#
# Prints `file:line  declaration` for every class, function, type, enum,
# interface, struct, trait, constant or variable named <Symbol>, in most
# languages (TS/JS, Python, Go, Rust, Dart, Java, Kotlin, Swift, C#, Ruby,
# PHP, Elixir, shell). Then lists the files that mention it, capped at 15.
# Skips tests, generated code, build output and vendored code unless -t.
# Extra globs to skip: SEARCH_EXCLUDE='**/fixtures/**,**/*.min.js'
# Exit 0 = found, 1 = not found, 2 = bad usage.
set -eo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

sym="${1:-}"
[ -n "$sym" ] || { echo "usage: find_symbol.sh <Symbol> [-t]" >&2; exit 2; }
shift
with_tests=0
for arg in "$@"; do
  case "$arg" in
    -t) with_tests=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

globs=(-g '!**/node_modules/**' -g '!**/vendor/**' -g '!**/build/**' -g '!**/dist/**' -g '!**/target/**'
  -g '!**/.dart_tool/**' -g '!**/.venv/**' -g '!**/__pycache__/**' -g '!**/generated/**'
  -g '!**/*.g.*' -g '!**/*.freezed.*' -g '!**/*.mocks.*' -g '!**/*.gen.*' -g '!**/*.generated.*'
  -g '!**/*.pb.*' -g '!**/*_pb2.py' -g '!**/*.min.js' -g '!**/*.lock' -g '!CHANGELOG.md' -g '!**/*.md')
if [ "$with_tests" -eq 0 ]; then
  globs+=(-g '!**/test/**' -g '!**/tests/**' -g '!**/__tests__/**' -g '!**/spec/**'
    -g '!**/*_test.*' -g '!**/*.test.*' -g '!**/*.spec.*' -g '!**/test_*.py')
fi
IFS=',' read -r -a extra <<< "${SEARCH_EXCLUDE:-}"
for g in ${extra[@]+"${extra[@]}"}; do [ -n "$g" ] && globs+=(-g "!$g"); done

# A keyword that declares something, any modifiers, then the name.
keywords='class|interface|struct|enum|trait|type|typedef|protocol|record|object|mixin|extension|module|impl|def|defp|defmodule|fn|func|function|fun|const|let|var|val|static|macro_rules!'
decl="$(rg -n --no-heading "${globs[@]}" \
  "^\s*((export|default|public|private|protected|internal|abstract|final|sealed|static|async|pub(\([a-z]+\))?|open|data|inline|base|readonly|declare|unsafe|extern)\s+)*(${keywords})\s+\**${sym}\b|^\s*${sym}\s*\(\)\s*\{|^\s*(func\s+\([^)]*\)\s+)${sym}\b" . \
  2>/dev/null || true)"

if [ -z "$decl" ]; then
  echo "not found: $sym (declarations only; for any mention try capped_grep.sh '\\b$sym\\b')"
  exit 1
fi

echo "declared:"
printf '%s\n' "$decl" | head -n 20 | cut -c1-200 | sed 's/^/  /'
refs="$(rg -l -w "${globs[@]}" -- "$sym" . 2>/dev/null || true)"
n="$(printf '%s' "$refs" | grep -c . || true)"
echo "mentioned in ${n} files (first 15):"
printf '%s\n' "$refs" | head -n 15 | sed 's/^/  /'
