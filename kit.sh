#!/usr/bin/env bash
# Installs any mix of the robertsolves agent kits into a project in one go.
#
#   curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- add commands dart
#   curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- setup
#
# Kits (short name or repo name):
#   template  agent-project-template  AGENTS.md, folder guides, BUGS/TODO/CHANGELOG, scripts
#   commands  agent-commands          cleanup, audit and review commands for any language
#   dart      dart-agent-kit          Dart and Flutter commands, reviewer subagent, Effective Dart
#   all       every kit above
#
# Commands:
#   add <kits...> [installer options]   install into the project (template always goes first)
#   add <kits...> --submodule           same, but each kit becomes a git submodule in .agents/kits/
#                                       and the project links to it, so `update` moves it forward
#   update                              bring every installed kit up to date (both modes)
#   autoupdate                          write a weekly GitHub Action that runs `update` and opens a PR
#   remove <kits...>                    uninstall (the template has no uninstall: its files are yours)
#   list                                show the kits
#   setup                               add the agent-kits skill to your user folders, so in any
#                                       project you can just ask "add the dart kit" or type /agent-kits
#
# Installer options (--tools, --only, --copy, --force, --no-agents-md, --dry-run, --project)
# are passed to every kit. KITS_DIR=<folder with local clones> uses those instead of GitHub.

set -euo pipefail

OWNER=robertsolves
BRANCH=main
RAW="https://raw.githubusercontent.com/$OWNER"

die() { printf 'kit.sh: %s\n' "$*" >&2; exit 1; }

repo_of() {
  case "$1" in
    template|agent-project-template) echo agent-project-template ;;
    commands|agent-commands) echo agent-commands ;;
    dart|dart-agent-kit) echo dart-agent-kit ;;
    *) return 1 ;;
  esac
}

kit_list() {
  cat <<'EOF'
  template  agent-project-template  AGENTS.md, folder guides, BUGS/TODO/CHANGELOG, scripts
  commands  agent-commands          cleanup, audit and review commands for any language
  dart      dart-agent-kit          Dart and Flutter commands, reviewer subagent, Effective Dart
  all       every kit above
EOF
}

usage() {
  cat <<'EOF'
Usage: kit.sh add <kits...> [--submodule] [options] | update | autoupdate | remove <kits...> | list | setup

Kits:
EOF
  kit_list
  cat <<'EOF'

  add      install the kits into this project (the template goes first)
           --submodule keeps each kit as a git submodule in .agents/kits/
  update   bring every installed kit up to date
  autoupdate  write a weekly GitHub Action that runs update and opens a PR
  remove   uninstall kits (the template has no uninstall: its files are yours)
  setup    add the agent-kits skill to your user folders, so in any project
           you can ask "add the dart kit" or type /agent-kits
  Options for add: --project DIR --tools LIST --only NAMES --copy --force
                   --no-agents-md --dry-run
EOF
}

# Runs a kit's installer from a local clone when there is one, else from GitHub.
run_installer() {
  local repo="$1" script="$2"; shift 2
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
  for dir in "$project/.agents/kits" "${KITS_DIR:-}" "$here/.."; do
    if [ -n "$dir" ] && [ -f "$dir/$repo/$script" ]; then
      bash "$dir/$repo/$script" "$@"
      return
    fi
  done
  command -v curl >/dev/null || die "curl is needed to fetch $OWNER/$repo"
  curl -fsSL "$RAW/$repo/$BRANCH/$script" | bash -s -- "$@"
}

cmd="${1:-}"
[ $# -gt 0 ] && shift

kits="" opts=() submodule=0 project=""
while [ $# -gt 0 ]; do
  case "$1" in
    --submodule) submodule=1 ;;
    --project) project="${2:?--project needs a directory}"; opts+=("$1" "$2"); shift ;;
    --tools|--only) opts+=("$1" "${2:?$1 needs a value}"); shift ;;
    -*) opts+=("$1") ;;
    all) kits="agent-project-template agent-commands dart-agent-kit" ;;
    *) r="$(repo_of "$1")" || die "unknown kit: $1 (try: kit.sh list)"
       case " $kits " in *" $r "*) ;; *) kits="$kits $r" ;; esac ;;
  esac
  shift
done

[ -n "$project" ] || project="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
project="$(cd "$project" && pwd)"
GIT_BASE="${KITS_GIT_BASE:-https://github.com/$OWNER}"

add_submodule() { # put a kit in .agents/kits/<repo> as a git submodule, once
  local repo="$1" path=".agents/kits/$1"
  [ -e "$project/$path" ] && return 0
  git -C "$project" rev-parse --git-dir >/dev/null 2>&1 || die "--submodule needs the project to be a git repo"
  git -C "$project" -c protocol.file.allow=always submodule add -q -b "$BRANCH" "$GIT_BASE/$repo.git" "$path"
  echo "Added $path as a submodule."
}

drop_submodule() {
  local path=".agents/kits/$1"
  [ -e "$project/$path" ] || return 0
  git -C "$project" submodule deinit -q -f "$path"
  git -C "$project" rm -q -f "$path"
  rm -rf "$(git -C "$project" rev-parse --git-dir)/modules/$path"
  echo "Removed the $path submodule."
}

case "$cmd" in
  add)
    [ -n "$kits" ] || die "name at least one kit, e.g. kit.sh add commands dart"
    # The template first, so its filled-in project-facts.md is what the others extend.
    case " $kits " in *" agent-project-template "*)
      template_opts=()
      for o in ${opts[@]+"${opts[@]}"}; do case "$o" in --dry-run) template_opts+=("$o") ;; esac; done
      for ((i = 0; i < ${#opts[@]}; i++)); do [ "${opts[$i]}" = --project ] && template_opts+=(--project "${opts[$((i + 1))]}"); done
      echo "== agent-project-template"
      run_installer agent-project-template init.sh ${template_opts[@]+"${template_opts[@]}"}
    ;; esac
    for repo in $kits; do
      [ "$repo" = agent-project-template ] && continue
      echo; echo "== $repo"
      [ "$submodule" = 1 ] && add_submodule "$repo"
      run_installer "$repo" install.sh ${opts[@]+"${opts[@]}"}
    done
    [ "$submodule" = 1 ] && echo && echo "Commit .gitmodules and .agents/. Teammates clone with --recurse-submodules (or run git submodule update --init)."
    ;;
  update)
    found=0
    for manifest in "$project"/.agents/.installed/*.txt; do
      [ -f "$manifest" ] || continue
      repo="$(basename "$manifest" .txt)"
      found=1
      echo "== $repo"
      if [ -e "$project/.agents/kits/$repo" ]; then
        git -C "$project" -c protocol.file.allow=always submodule update -q --init --remote ".agents/kits/$repo"
        echo "Moved .agents/kits/$repo to the latest $BRANCH."
      fi
      run_installer "$repo" install.sh --project "$project" ${opts[@]+"${opts[@]}"}
    done
    [ "$found" = 1 ] || die "no kits installed here (nothing in .agents/.installed/)"
    echo; echo "The template kit is never updated: its files are yours. Review the changes with git diff and commit."
    ;;
  autoupdate)
    wf="$project/.github/workflows/agent-kits-update.yml"
    [ -e "$wf" ] && die "$wf already exists"
    mkdir -p "$(dirname "$wf")"
    cat > "$wf" <<'YAML'
# Weekly: bring the robertsolves agent kits up to date and open a PR with the changes.
# Needs Settings > Actions > General > "Allow GitHub Actions to create and approve pull requests".
name: Update agent kits
on:
  schedule:
    - cron: "0 3 * * 1"
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
      - run: sudo apt-get install -y ripgrep
      - run: curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/kit.sh | bash -s -- update
      - uses: peter-evans/create-pull-request@v7
        with:
          branch: agent-kits-update
          title: Update agent kits
          commit-message: Update agent kits
          body: Ran `kit.sh update`. Check the diff before merging.
YAML
    echo "Wrote ${wf#"$project"/}. Commit it, and allow Actions to open PRs in the repo settings."
    ;;
  remove)
    [ -n "$kits" ] || die "name at least one kit to remove"
    for repo in $kits; do
      if [ "$repo" = agent-project-template ]; then echo "Skipping the template: its files are yours now. Delete what you don't want."; continue; fi
      echo "== $repo"
      run_installer "$repo" install.sh --uninstall ${opts[@]+"${opts[@]}"}
      drop_submodule "$repo"
    done
    ;;
  list)
    kit_list
    ;;
  setup)
    # One user-level skill, in every folder the agents read skills from.
    skill="$(mktemp)"
    trap 'rm -f "$skill"' EXIT
    here="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || true)"
    if [ -f "$here/global/agent-kits/SKILL.md" ]; then cp "$here/global/agent-kits/SKILL.md" "$skill"
    else curl -fsSL "$RAW/agent-commands/$BRANCH/global/agent-kits/SKILL.md" -o "$skill" || die "could not fetch the agent-kits skill"; fi
    for dir in "$HOME/.claude/skills" "$HOME/.agents/skills" "$HOME/.gemini/antigravity/skills"; do
      case "$dir" in */antigravity/*) [ -d "$HOME/.gemini/antigravity" ] || continue ;; esac
      mkdir -p "$dir/agent-kits"
      cp "$skill" "$dir/agent-kits/SKILL.md"
      echo "Added $dir/agent-kits"
    done
    echo
    echo "Done. In any project, ask your agent to \"add the agent commands and the dart kit\","
    echo "or type /agent-kits in Claude Code (\$agent-kits in Codex)."
    ;;
  ''|-h|--help|help) usage ;;
  *) die "unknown command: $cmd (try: add, remove, list, setup)" ;;
esac
