#!/usr/bin/env bash
# @admin.description Have Kilo refine a findings document (bugs, TODOs, stale comments...) round after round until two rounds in a row leave it unchanged (/kilo-refine-findings).
# The whole Kilo loop behind /kilo-refine-findings, run without the calling
# agent in the middle so none of Kilo's round reports pass through its context.
# The document itself is the brief: whatever it lists (API bugs, TODOs, stale
# comments...) is the kind of entry Kilo checks and adds. Each round is one
# fresh Kilo session that edits ONLY the document:
#   1. AUDIT every entry against the code: delete fixed or false ones, correct
#      drifted ones, deepen thin ones
#   2. EXPAND with new entries of the document's own kind, in its own shape
# A round is quiet when the document comes out byte-for-byte unchanged. The
# loop stops after two quiet rounds IN A ROW, or at the cap. After every round
# it checks Kilo changed no other file and made no commit. Kilo runs from the
# repo root, so it reads AGENTS.md.
#
# Writes the document, plus a new run folder .kilo_runs/refine_<timestamp>/
# (git-ignored, also reachable as .kilo_runs/refine_latest): refine.log (one
# line per round, the ONLY file the caller reads besides the two below),
# doc.diff (the whole change to the document), changes.txt (every DELETED /
# ADDED line Kilo reported, by round), doc_before.md, round_<n>.md.
#
# Exit codes: 0 two quiet rounds in a row · 1 round cap reached · 2 a Kilo
# call failed twice · 3 Kilo changed another file or committed · 4 bad usage.
#
# Usage:
#   bash .agents/skills/kilo-refine-findings/scripts/run_refine.sh <doc-path> [--focus "<words>"] [--models <provider/model>[,...]]
# A model chain is tried best first: a rate-limited model hands over to the next.
# Env: KILO_REFINE_MAX_ROUNDS (default 8), KILO_REFINE_NEW_PER_ROUND (default
# 8), KILO_REFINE_CALL_TIMEOUT seconds per Kilo call (default 1800),
# KILO_RETRY_WAIT seconds before a retry (default 300).
# Runs from any directory: the repo root comes from git.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

usage() {
  echo "usage: run_refine.sh <doc-path> [--focus \"<words>\"] [--models <provider/model>[,...]]" >&2
  exit 4
}

[ $# -lt 1 ] && usage
DOC_ARG="$1"; shift
FOCUS=""
MODELS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --focus) [ $# -lt 2 ] && usage; FOCUS="$2"; shift 2 ;;
    --models) [ $# -lt 2 ] && usage; MODELS="$2"; shift 2 ;;
    *) usage ;;
  esac
done
MAX_ROUNDS="${KILO_REFINE_MAX_ROUNDS:-8}"
NEW_PER_ROUND="${KILO_REFINE_NEW_PER_ROUND:-8}"
CALL_TIMEOUT="${KILO_REFINE_CALL_TIMEOUT:-1800}"

[ -s "$DOC_ARG" ] || { echo "STOP: $DOC_ARG is missing or empty" >&2; exit 4; }
DOC_ABS="$(cd "$(dirname "$DOC_ARG")" && pwd)/$(basename "$DOC_ARG")"

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"
source "$(dirname "${BASH_SOURCE[0]}")/kilo_lib.sh"

case "$DOC_ABS" in
  "$REPO_ROOT"/*) DOC="${DOC_ABS#"$REPO_ROOT"/}" ;;
  *) echo "STOP: $DOC_ARG is outside the repo; Kilo can only edit files inside it" >&2; exit 4 ;;
esac

# The document is the brief; kilo_make_run_dir keeps a copy as brief.md.
kilo_make_run_dir refine "$DOC"
LOG="$OUT/refine.log"
: > "$LOG"
kilo_snapshot "$OUT"
RULES="$OUT/rules.md"
write_kilo_rules "$RULES"
cp "$DOC" "$OUT/doc_before.md"
: > "$OUT/changes.txt"

doc_hash() { shasum "$DOC" | cut -d' ' -f1; }

# Exit 3 when any file other than the document changed since the snapshot.
check_only_doc_changed() {
  local others
  others="$( { git diff --name-only "$SNAPSHOT"
               git ls-files --others --exclude-standard | sort | comm -13 "$UNTRACKED_BEFORE" -
             } | grep -vxF "$DOC" | head -n 10)"
  if [ -n "$others" ]; then
    log "STOP: round $1 changed files other than $DOC:"
    printf '  %s\n' $others | tee -a "$LOG"
    exit 3
  fi
}

focus_line=""
[ -n "$FOCUS" ] && focus_line="
Focus: only entries about \"$FOCUS\". Leave every other entry exactly as it is, and add only entries about it."

quiet=0
round=0
while [ "$round" -lt "$MAX_ROUNDS" ]; do
  round=$((round + 1))
  ask="Round $round of refining the findings document $DOC. Edit only $DOC; change no other file.
First read the document's header and its first two entries to learn what an entry in it is (a bug, a TODO, a stale comment, a risk...), the exact shape of an entry, and how entries point at code. If the header defines a format, follow it. Every edit and every new entry copies that shape.$focus_line
Part 1, audit: check every entry against the code as it is now. Open the cited file and line; do not trust the entry's wording or tags. Look for what makes it a non-issue: a guard one layer up, a test that pins the behaviour, a sibling that already handles it.
- accurate: leave it; if it is thin, add only facts you saw in the code
- drifted (wrong line, name or wording): correct it
- fixed or false: delete the whole entry (no strikethrough, no resolved section)
- needs a live environment, a credential or the owner to check: leave it
Part 2, expand: add at most $NEW_PER_ROUND new entries of the document's own kind and no other, not already in it: the same pattern in sibling files, the twin of an accurate entry (the other endpoint, the other platform), anything you tripped over. Open the code for every one; do not guess. Add nothing when you find nothing real.
Do not reorder, restyle or renumber entries you did not change.
End your reply with one line per deleted entry 'DELETED: <entry heading> - fixed|false - <why>', one line per added entry 'ADDED: <entry heading>', and finally exactly one line: 'ROUND: DONE'."
  [ "$quiet" -gt 0 ] && ask="$ask
The previous round changed nothing. Assume it missed something and look harder."

  before="$(doc_hash)"
  call_with_retry "round $round" code "$OUT/round_$round.md" ROUND "$ask" "$RULES" "$DOC"
  check_git_untouched "round $round"
  check_only_doc_changed "$round"

  grep -E '^[*_ ]*(DELETED|ADDED):' "$OUT/round_$round.md" | sed "s/^/round $round: /" >> "$OUT/changes.txt"
  deleted="$(grep -cE '^[*_ ]*DELETED:' "$OUT/round_$round.md")"
  added="$(grep -cE '^[*_ ]*ADDED:' "$OUT/round_$round.md")"

  if [ "$(doc_hash)" = "$before" ]; then
    quiet=$((quiet + 1))
    log "round $round: document unchanged (quiet $quiet/2)"
    if [ "$quiet" -ge 2 ]; then
      diff -u "$OUT/doc_before.md" "$DOC" > "$OUT/doc.diff"
      log "REFINE: STABLE after $round rounds; $(grep -c '^round' "$OUT/changes.txt") deletions and additions reported; see doc.diff"
      exit 0
    fi
  else
    quiet=0
    log "round $round: document changed (Kilo reports $deleted deleted, $added added)"
  fi
done

diff -u "$OUT/doc_before.md" "$DOC" > "$OUT/doc.diff"
log "REFINE: CAP REACHED after $MAX_ROUNDS rounds without two unchanged in a row; see doc.diff"
exit 1
