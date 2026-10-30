#!/usr/bin/env bash
# @admin.description Have Kilo do a task, then audit and fix its own changes until two audits in a row find nothing (/kilo-loop).
# The whole Kilo loop behind /kilo-loop, run without the calling agent in the
# middle so none of Kilo's reports pass through the caller's context:
#   1. snapshot the working tree (nothing is changed: `git stash create`)
#   2. WORK  - Kilo's `code` agent does the task in the brief
#   3. AUDIT - a fresh read-only Kilo session audits the diff since the snapshot
#   4. FIX   - if the audit lists problems, Kilo's `code` agent fixes them,
#              and the clean streak resets to 0
#   5. repeat 3-4 until two audits IN A ROW say VERDICT: CLEAN, or the cap
# Kilo runs from the repo root, so it reads AGENTS.md and the project rules.
# After every Kilo call it checks Kilo made no commit and switched no branch,
# and after every audit that the audit changed nothing.
#
# Writes only into a new run folder .kilo_runs/loop_<timestamp>/ (git-ignored,
# also reachable as .kilo_runs/loop_latest): loop.log (one line per step, the
# ONLY file the caller reads), brief.md, work.md, audit_<n>.md, fix_<n>.md,
# diff_<n>.patch, final.patch, final_files.txt.
#
# Exit codes: 0 two clean audits in a row · 1 round cap reached · 2 a Kilo
# call failed twice or gave no verdict · 3 Kilo committed, switched branch or
# an audit edited files · 4 bad usage.
#
# Usage:
#   bash .agents/skills/kilo-loop/scripts/run_loop.sh <brief.md> [<provider/model>[,<provider/model>...]]
# A model chain is tried best first: a rate-limited model hands over to the next.
# Env: KILO_LOOP_MAX_ROUNDS (default 8), KILO_LOOP_CALL_TIMEOUT seconds per
# Kilo call (default 1800), KILO_RETRY_WAIT seconds before a retry (default 300).
# Runs from any directory: the repo root comes from git.
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

if [ $# -lt 1 ] || [ ! -s "$1" ]; then
  echo "usage: run_loop.sh <brief.md> [<provider/model>[,...]]" >&2
  exit 4
fi

BRIEF_SRC="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
MODELS="${2:-}"
MAX_ROUNDS="${KILO_LOOP_MAX_ROUNDS:-8}"
CALL_TIMEOUT="${KILO_LOOP_CALL_TIMEOUT:-1800}"

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"
source "$(dirname "${BASH_SOURCE[0]}")/kilo_lib.sh"

kilo_make_run_dir loop "$BRIEF_SRC"
LOG="$OUT/loop.log"
: > "$LOG"
kilo_snapshot "$OUT"
RULES="$OUT/rules.md"
write_kilo_rules "$RULES"

# Writes the change since the snapshot (tracked diff plus new untracked files)
# to $1 and the changed paths to $2.
write_diff() {
  local patch="$1" files="$2" f
  git diff "$SNAPSHOT" > "$patch"
  git diff --name-only "$SNAPSHOT" > "$files"
  git ls-files --others --exclude-standard | sort \
    | comm -13 "$UNTRACKED_BEFORE" - | while IFS= read -r f; do
      git diff --no-index -- /dev/null "$f" >> "$patch"
      echo "$f" >> "$files"
    done
}

# ── Work ──────────────────────────────────────────────────────────────────────
call_with_retry "work" code "$OUT/work.md" RESULT \
  "Do the task in the attached brief, obeying the attached rules. You may edit any repository file the task needs. When finished, end your reply with exactly one line: 'RESULT: DONE' or 'RESULT: BLOCKED <why>'." \
  "$RULES" "$BRIEF"
check_git_untouched "work"
WORK_RESULT="$(last_line_for RESULT "$OUT/work.md")"
log "work: $WORK_RESULT"
case "$WORK_RESULT" in
  "RESULT: DONE"*) ;;
  *) log "STOP: Kilo did not finish the task; see $OUT/work.md"; exit 2 ;;
esac

# ── Audit / fix loop ──────────────────────────────────────────────────────────
AUDIT_ASK="Audit the attached diff: it is every change made for the task in the attached brief. Read-only: change no file. Open each changed file and check the change against the brief, AGENTS.md and the rules it points to: bugs, missing pieces of the task, broken callers, missing tests, leftovers, silent fallbacks, anything that will fail the checks AGENTS.md lists. Write each problem as one line '- <file>:<line> - <problem>'. Then list every changed file under 'Reviewed:' with one line on what you checked. End with exactly one line: 'VERDICT: CLEAN' if there is no problem, or 'VERDICT: ISSUES <count>'."
SKEPTIC=" A previous auditor found nothing. Assume they missed something and look harder."

streak=0
round=0
while [ "$round" -lt "$MAX_ROUNDS" ]; do
  round=$((round + 1))
  write_diff "$OUT/diff_$round.patch" "$OUT/files_$round.txt"
  if [ ! -s "$OUT/diff_$round.patch" ]; then
    log "STOP: round $round: no change since the snapshot; Kilo made no edits"
    exit 2
  fi

  ask="$AUDIT_ASK"
  [ "$streak" -gt 0 ] && ask="$ask$SKEPTIC"
  before="$(tree_fingerprint)"
  call_with_retry "audit $round" plan "$OUT/audit_$round.md" VERDICT "$ask" \
    "$RULES" "$BRIEF" "$OUT/diff_$round.patch"
  check_git_untouched "audit $round"
  if [ "$(tree_fingerprint)" != "$before" ]; then
    log "STOP: audit $round changed files; it must be read-only"
    exit 3
  fi

  verdict="$(last_line_for VERDICT "$OUT/audit_$round.md")"
  case "$verdict" in
    "VERDICT: CLEAN"*)
      # A clean verdict that lists nothing reviewed did not look: not counted.
      if ! grep -q 'Reviewed:' "$OUT/audit_$round.md"; then
        log "audit $round: CLEAN but no Reviewed: list; not counted"
        streak=0
        continue
      fi
      streak=$((streak + 1))
      log "audit $round: CLEAN (streak $streak/2)"
      if [ "$streak" -ge 2 ]; then
        write_diff "$OUT/final.patch" "$OUT/final_files.txt"
        log "LOOP: CLEAN after $round audits; $(wc -l < "$OUT/final_files.txt" | tr -d ' ') files changed; see final.patch"
        exit 0
      fi
      ;;
    "VERDICT: ISSUES"*)
      streak=0
      log "audit $round: ${verdict#VERDICT: }"
      call_with_retry "fix $round" code "$OUT/fix_$round.md" RESULT \
        "Fix every problem in the attached audit. Change only what each problem needs, obeying the attached rules. If you believe a listed problem is wrong, leave the code and say why. End with exactly one line: 'RESULT: DONE' or 'RESULT: BLOCKED <why>'." \
        "$RULES" "$BRIEF" "$OUT/audit_$round.md"
      check_git_untouched "fix $round"
      log "fix $round: $(last_line_for RESULT "$OUT/fix_$round.md")"
      ;;
    *)
      log "STOP: audit $round verdict unreadable: $verdict"
      exit 2
      ;;
  esac
done

write_diff "$OUT/final.patch" "$OUT/final_files.txt"
log "LOOP: CAP REACHED after $MAX_ROUNDS audits without two clean in a row; see the last audit_<n>.md"
exit 1
