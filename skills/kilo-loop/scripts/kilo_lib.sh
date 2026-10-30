#!/usr/bin/env bash
# Kept identical in kilo-loop/scripts/ and kilo-refine-findings/scripts/, so either command works when installed alone.
# @admin.description Shared helpers for the Kilo loop scripts (/kilo-loop, /kilo-refine-findings); sourced, never run.
# @admin.hidden
# Sourced by the loop scripts that drive the free Kilo CLI, so the calling
# agent never reads Kilo's reports. Before sourcing this file, the loop
# script sets:
#   LOG           file every log() line is appended to
#   MODELS        comma-separated provider/model chain, best first, or empty
#                 for Kilo's configured default; a rate-limited model hands
#                 over to the next one for the rest of the run
#   CALL_TIMEOUT  seconds one Kilo call may run before it is killed
# and then runs kilo_snapshot once, from the repo root.
#
# Usage (from a loop script):
#   source "$REPO_ROOT/scripts/kilo_lib.sh"
# ──────────────────────────────────────────────────────────────────────────────

log() { echo "$*" | tee -a "$LOG"; }

IFS=',' read -r -a MODEL_CHAIN <<< "${MODELS:-}"
MODEL_INDEX=0
# The model the next Kilo call uses, or empty for Kilo's configured default.
current_model() { echo "${MODEL_CHAIN[$MODEL_INDEX]:-}"; }

# kilo_make_run_dir <kind> <brief.md>: creates .kilo_runs/<kind>_<timestamp>/
# under the repo root, copies the brief in as brief.md, points
# .kilo_runs/<kind>_latest at it, and sets OUT and BRIEF. The run folder must
# be inside the repo: Kilo refuses to read files outside it in a run nobody
# can approve. .kilo_runs/ is git-ignored, so nothing in it shows in a diff.
kilo_make_run_dir() {
  local kind="$1" brief_src="$2" parent
  parent="$(git rev-parse --show-toplevel)/.kilo_runs"
  OUT="$parent/${kind}_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$OUT"
  if ! git check-ignore -q "$OUT"; then
    echo "STOP: $parent is not git-ignored; add .kilo_runs/ to .gitignore" >&2
    exit 4
  fi
  cp "$brief_src" "$OUT/brief.md"
  BRIEF="$OUT/brief.md"
  ln -sfn "$(basename "$OUT")" "$parent/${kind}_latest"
  echo "RUN_DIR: $OUT"
}

# Records HEAD, the branch and a snapshot commit of the working tree, without
# changing anything (`git stash create` writes no ref and touches no file).
# Sets START_HEAD, START_BRANCH, SNAPSHOT; writes <out_dir>/untracked_before.txt.
kilo_snapshot() {
  local out_dir="$1"
  START_HEAD="$(git rev-parse HEAD)"
  START_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  SNAPSHOT="$(git stash create)"
  [ -z "$SNAPSHOT" ] && SNAPSHOT="$START_HEAD"
  UNTRACKED_BEFORE="$out_dir/untracked_before.txt"
  git ls-files --others --exclude-standard | sort > "$UNTRACKED_BEFORE"
}

# Fingerprint of the working tree since the snapshot, to prove a read-only
# call changed nothing.
tree_fingerprint() {
  { git diff "$SNAPSHOT"; git ls-files --others --exclude-standard; } | shasum | cut -d' ' -f1
}

# Exit 3 when Kilo committed or switched branch during the step named in $1.
check_git_untouched() {
  if [ "$(git rev-parse HEAD)" != "$START_HEAD" ] \
    || [ "$(git rev-parse --abbrev-ref HEAD)" != "$START_BRANCH" ]; then
    log "STOP: Kilo committed or switched branch during $1 (HEAD was $START_HEAD on $START_BRANCH)"
    exit 3
  fi
}

# kilo_call <agent> <report> <message> <files...>: one fresh Kilo session with
# a watchdog. The `code` agent runs with --auto (it may edit); `plan` is
# read-only. Returns 0 when the report is non-empty. It does not fail on
# `Error:` lines: Kilo prints one for every tool call its permissions refuse
# (the plan agent may not pipe), then carries on; whether the call worked is
# decided by its marker line in call_with_retry.
kilo_call() {
  local agent="$1" report="$2" message="$3"; shift 3
  # The message goes first: `-f` takes a list and would swallow it as a file.
  # --dir pins Kilo to the repo root, so it loads AGENTS.md and the project's
  # commands, skills and agents (through the .kilo symlink).
  local args=(run "$message" --agent "$agent" --dir "$(git rev-parse --show-toplevel)")
  [ "$agent" = "code" ] && args+=(--auto)
  local model
  model="$(current_model)"
  [ -n "$model" ] && args+=(-m "$model")
  local f
  for f in "$@"; do args+=(-f "$f"); done
  kilo "${args[@]}" > "$report" 2>&1 < /dev/null &
  local pid=$!
  ( sleep "$CALL_TIMEOUT"; kill "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid"
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  # Strip colour codes so the marker-line grep sees plain text.
  sed -i '' -e $'s/\x1b\\[[0-9;]*[A-Za-z]//g' "$report" 2>/dev/null \
    || sed -i -e $'s/\x1b\\[[0-9;]*[A-Za-z]//g' "$report"
  [ -s "$report" ]
}

# Last `<KEY>: ...` line of a report (markdown bold stripped), or empty.
last_line_for() { grep -E "^[*_ ]*$1:" "$2" | tail -n 1 | sed -E 's/^[*_ ]+//; s/[*_ ]+$//'; }

# call_with_retry <label> <agent> <report> <key> <message> <files...>: runs
# the call until the report has its `<key>:` line. A rate-limited model hands
# over to the next one in MODELS at once, for the rest of the run. Any other
# failure gets one retry after KILO_RETRY_WAIT seconds (default 300); exit 2
# after the second.
call_with_retry() {
  local label="$1" agent="$2" report="$3" key="$4"; shift 4
  local failures=0
  while true; do
    if kilo_call "$agent" "$report" "$@" && [ -n "$(last_line_for "$key" "$report")" ]; then
      return 0
    fi
    if grep -qiE 'rate.?limit|quota exceeded|limit exceeded|cooldown|too many requests|RESOURCE_EXHAUSTED|\b429\b' "$report"; then
      if [ $((MODEL_INDEX + 1)) -lt "${#MODEL_CHAIN[@]}" ]; then
        log "$label: $(current_model) is rate-limited; switching to ${MODEL_CHAIN[$((MODEL_INDEX + 1))]}"
        MODEL_INDEX=$((MODEL_INDEX + 1))
        continue
      fi
      log "$label: the model looks rate-limited and no model is left to switch to"
    fi
    failures=$((failures + 1))
    log "$label: attempt $failures failed or gave no $key line"
    [ "$failures" -ge 2 ] && break
    sleep "${KILO_RETRY_WAIT:-300}"
  done
  log "STOP: $label failed twice; see $report"
  exit 2
}

# Writes the shared rules every Kilo call gets to $1.
write_kilo_rules() {
  cat > "$1" <<'EOF'
# Rules for this run (they override anything else you read)

- Read AGENTS.md at the repo root first and follow it.
- Edit only the files this message allows, and only what the task needs.
- Never run git commit, push, checkout, switch, reset, restore, stash, rebase or merge.
- Never run anything that deploys, resets a database, applies terraform, or calls gcloud or firebase.
- Never delete a file you did not create for this task.
EOF
}
