#!/usr/bin/env bash
# Two-phase search: matching files first, then a few matches from each. Usage: bash .agents/skills/search-helpers/scripts/capped_grep.sh <pattern> [path] [-a]
#
# Use it instead of a raw grep over a whole folder, which can put tens of
# thousands of tokens into an agent's context. Skips build output, vendored
# and generated code and CHANGELOG.md. -a searches those too.
# Exit 0 on a match, 1 on none, 2 on bad usage.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

pat="${1:-}"
[ -n "$pat" ] || { echo "usage: capped_grep.sh <pattern> [path] [-a]" >&2; exit 2; }
shift
dir="." all=0
for arg in "$@"; do
  case "$arg" in
    -a) all=1 ;;
    *) dir="$arg" ;;
  esac
done

set -- -g '!CHANGELOG.md'
if [ "$all" = 0 ]; then
  for g in build dist out target node_modules vendor .dart_tool .next coverage __pycache__ .venv; do
    set -- "$@" -g "!**/$g/**"
  done
  set -- "$@" -g '!*.min.js' -g '!*.lock' -g '!*-lock.json' -g '!*.g.dart' -g '!*.generated.*' -g '!*.pb.go'
fi

files="$(rg -l --no-messages "$@" -e "$pat" "$dir" | sort || true)"
n="$(printf '%s' "$files" | grep -c . || true)"
if [ "${n:-0}" -eq 0 ]; then
  echo "no matches for /$pat/ in $dir"
  exit 1
fi

echo "files: $n (first 20)"
printf '%s\n' "$files" | head -n 20 | sed 's/^/  /'
echo "--- matches (3 per file, first 8 files, 4000 characters max)"
printf '%s\n' "$files" | head -n 8 | while IFS= read -r f; do
  rg -nH --max-count 3 --max-columns 200 --max-columns-preview -e "$pat" "$f" || true
done | head -c 4000
echo
