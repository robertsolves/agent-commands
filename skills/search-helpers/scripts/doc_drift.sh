#!/usr/bin/env bash
# Finds doc links and backticked paths that point at nothing. Usage: bash .agents/skills/search-helpers/scripts/doc_drift.sh [links|paths]
#
#   links  a relative markdown link ](path) whose target is missing
#   paths  a backticked path such as `src/auth/login.ts` that is missing,
#          counted only when it starts with a folder that exists at the repo root
#
# Scans tracked markdown, but skips the history files (CHANGELOG.md, BUGS.md,
# TODO.md, MANUAL_TODO.md, todo/, docs/plans/), installed agent commands and
# skills (.agents/), audit folders, and any line saying the file was deleted,
# renamed or moved. In a monorepo, a path that exists inside some package
# (`scripts/build.sh` written from inside `apps/web/`) passes.
# Each check prints at most DRIFT_CAP findings (default 20).
# comments, workflows and indexes print a "not checked" line and pass.
# Exit 0 clean, 1 on any finding, 2 on bad usage.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

what="${1:-all}"
cap="${DRIFT_CAP:-20}"
found=0
history_words='deleted|retired|removed|renamed|moved|no longer|previously|used to'

current_docs() {
  git ls-files --cached --others --exclude-standard '*.md' \
    | grep -vE '^(CHANGELOG|BUGS|TODO|MANUAL_TODO)\.md$' \
    | grep -vE '^(todo|docs/plans|doc/plans|\.agents)/|(^|/)audits?/' \
    | grep -vE '(^|/)(node_modules|build|dist|vendor)/' || true
}

summarise() { # $1 = findings for this check
  if [ "$1" -eq 0 ]; then echo "  OK"; else
    [ "$1" -gt "$cap" ] && echo "  ... and $(($1 - cap)) more"
    found=$((found + $1))
  fi
  echo
}

about_history() { sed -n "${2}p" "$1" | grep -qiE "$history_words"; }

check_links() {
  echo "LINKS: relative markdown links whose target is missing"
  local n=0 hit file lineno target
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; hit="${hit#*:}"
    lineno="${hit%%:*}"; target="${hit#*:](}"
    target="${target%)}"; target="${target%%#*}"; target="${target%% *}"
    case "$target" in ''|http:*|https:*|mailto:*|/*|'<'*|*:*|*'|'*) continue ;; esac
    case "$target" in */*|*.*) ;; *) continue ;; esac
    [ -e "$(dirname "$file")/$target" ] || [ -e "$target" ] && continue
    about_history "$file" "$lineno" && continue
    n=$((n + 1))
    [ "$n" -le "$cap" ] && echo "  $file:$lineno  -> $target"
  done <<EOF2
$(current_docs | while IFS= read -r f; do grep -noE '\]\([^)]+\)' "$f" 2>/dev/null | sed "s#^#$f:#"; done)
EOF2
  summarise "$n"
}

check_paths() {
  echo "PATHS: backticked repo paths that are missing"
  local n=0 hit file lineno path roots tracked
  tracked="$(git ls-files)"
  roots="$(git ls-files | awk -F/ 'NF > 1 { print $1 }' | sort -u | grep -v '^\.git$' | sed 's/\./\\./g' | paste -sd'|' -)"
  if [ -z "$roots" ]; then summarise 0; return; fi
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    file="${hit%%:*}"; hit="${hit#*:}"
    lineno="${hit%%:*}"; path="${hit#*:}"
    path="${path#\`}"; path="${path%\`}"
    path="${path%%:[0-9]*}"; path="${path%/}"
    case "$path" in *'<'*|*'*'*|*'...'*|*'{'*) continue ;; esac
    [ -e "$path" ] || [ -e "$(dirname "$file")/$path" ] && continue
    grep -qF -- "/$path" <<<"$tracked" && continue
    about_history "$file" "$lineno" && continue
    n=$((n + 1))
    [ "$n" -le "$cap" ] && echo "  $file:$lineno  \`$path\`"
  done <<EOF2
$(current_docs | while IFS= read -r f; do grep -noE "\`($roots)/[A-Za-z0-9_./*<>{}-]*(:[0-9]+)?\`" "$f" 2>/dev/null | sed "s#^#$f:#"; done)
EOF2
  summarise "$n"
}

case "$what" in
  links) check_links ;;
  paths) check_paths ;;
  all) check_links; check_paths ;;
  comments|workflows|indexes)
    # Modes a project's own drift tool may have. This one doesn't, so say so
    # and pass, letting a command that loops over every mode carry on.
    echo "${what}: not checked by this tool, check by hand" ;;
  *) echo "usage: doc_drift.sh [links|paths]" >&2; exit 2 ;;
esac
[ "$found" -eq 0 ]
