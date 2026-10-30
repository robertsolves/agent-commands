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
#   trials    prompt-trials           test your own commands on a free model
#   all       every kit above
#
# Commands:
#   add <kits...> [installer options]   install into the project (template always goes first)
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
    trials|prompt-trials) echo prompt-trials ;;
    *) return 1 ;;
  esac
}

kit_list() {
  cat <<'EOF'
  template  agent-project-template  AGENTS.md, folder guides, BUGS/TODO/CHANGELOG, scripts
  commands  agent-commands          cleanup, audit and review commands for any language
  dart      dart-agent-kit          Dart and Flutter commands, reviewer subagent, Effective Dart
  trials    prompt-trials           test your own commands on a free model
  all       every kit above
EOF
}

usage() {
  cat <<'EOF'
Usage: kit.sh add <kits...> [options] | remove <kits...> | list | setup

Kits:
EOF
  kit_list
  cat <<'EOF'

  add      install the kits into this project (the template goes first)
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
  for dir in "${KITS_DIR:-}" "$here/.."; do
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

kits="" opts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --project|--tools|--only) opts+=("$1" "${2:?$1 needs a value}"); shift ;;
    -*) opts+=("$1") ;;
    all) kits="agent-project-template agent-commands dart-agent-kit prompt-trials" ;;
    *) r="$(repo_of "$1")" || die "unknown kit: $1 (try: kit.sh list)"
       case " $kits " in *" $r "*) ;; *) kits="$kits $r" ;; esac ;;
  esac
  shift
done

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
      run_installer "$repo" install.sh ${opts[@]+"${opts[@]}"}
    done
    ;;
  remove)
    [ -n "$kits" ] || die "name at least one kit to remove"
    for repo in $kits; do
      if [ "$repo" = agent-project-template ]; then echo "Skipping the template: its files are yours now. Delete what you don't want."; continue; fi
      echo "== $repo"
      run_installer "$repo" install.sh --uninstall ${opts[@]+"${opts[@]}"}
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
