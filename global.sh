#!/usr/bin/env bash
# Links this repo's commands, skills and subagents into your user folders, so
# they work in every project. Clone the repo somewhere permanent first.
#
#   ./global.sh install     link everything
#   ./global.sh uninstall   remove only the links that point into this clone
#   ./global.sh list        show the links that exist now
#
# Claude Code gets commands/ and agents/, plus any skill with no command of the
# same name (a command and a skill of one name would show twice). Codex and
# other skill readers get every skill in ~/.agents/skills. Update with git pull.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cmd="${1:-}"

# Prints "<link target> <link path>" for every link this repo owns.
links() {
  local f d name
  for f in "$here"/commands/*.md; do
    [ -e "$f" ] && echo "$f $HOME/.claude/commands/$(basename "$f")"
  done
  for f in "$here"/agents/*.md; do
    [ -e "$f" ] && echo "$f $HOME/.claude/agents/$(basename "$f")"
  done
  for d in "$here"/skills/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"; name="$(basename "$d")"
    echo "$d $HOME/.agents/skills/$name"
    [ -e "$here/commands/$name.md" ] || echo "$d $HOME/.claude/skills/$name"
  done
}

case "$cmd" in
  install)
    links | while read -r target link; do
      if [ -L "$link" ] || [ ! -e "$link" ]; then
        mkdir -p "$(dirname "$link")"
        ln -sfn "$target" "$link"
        echo "linked $link"
      else
        echo "skipped $link (a file of that name is already there)" >&2
      fi
    done
    ;;
  uninstall)
    links | while read -r target link; do
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        rm "$link"
        echo "removed $link"
      fi
    done
    ;;
  list)
    links | while read -r target link; do
      [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ] && echo "$link"
    done
    ;;
  *) echo "Usage: global.sh install | uninstall | list" >&2; exit 2 ;;
esac
