#!/usr/bin/env bash
# Adds this repo's commands, skills and subagents to a project, wired up for
# every coding agent you use there.
#
#   curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/robertsolves/agent-commands/main/install.sh | bash -s -- --tools all
#   ./install.sh --project ~/code/my-app --only find-bandaids,audit-slop
#
# ./install.sh --help lists every option. Needs bash 3.2+, plus curl and tar
# when it is piped from curl. Works the same in both repos
# (agent-commands, dart-agent-kit); only REPO differs.

set -euo pipefail

REPO=agent-commands
OWNER=robertsolves
BRANCH=main

usage() {
  cat <<EOF
Usage: install.sh [options]

  --project DIR    project to install into (default: the git root of the
                   current directory, else the current directory)
  --tools LIST     comma list of: claude, codex, gemini, opencode, kilo,
                   antigravity, cursor, copilot, windsurf, freebuff, or "all".
                   Default "auto": whatever the project or your PATH shows.
  --only NAMES     comma list of commands, skills or agents to install
                   (default: everything). See --list.
  --copy           copy files into tool folders instead of symlinking them
  --force          overwrite files of the same name this script did not create
  --no-agents-md   leave AGENTS.md alone
  --dry-run        print what would change, change nothing
  --uninstall      remove everything a previous run installed
  --list           print what this repo contains and exit
  -h, --help       this text
EOF
}

project="" tools="auto" only="" mode="link" force=0 agents_md=1 dry=0 uninstall=0 list=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project) project="${2:?--project needs a directory}"; shift ;;
    --tools) tools="${2:?--tools needs a list}"; shift ;;
    --only) only="${2:?--only needs a list}"; shift ;;
    --copy) mode="copy" ;;
    --force) force=1 ;;
    --no-agents-md) agents_md=0 ;;
    --dry-run) dry=1 ;;
    --uninstall) uninstall=1 ;;
    --list) list=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

# --- Find the repo's files: next to this script, or download them. ---------

src=""
script="${BASH_SOURCE[0]:-}"
if [ -n "$script" ] && [ -f "$script" ]; then
  src="$(cd "$(dirname "$script")" && pwd)"
fi
if [ -z "$src" ] || { [ ! -d "$src/commands" ] && [ ! -d "$src/skills" ]; }; then
  command -v curl >/dev/null || die "curl is needed to download $OWNER/$REPO"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://codeload.github.com/$OWNER/$REPO/tar.gz/refs/heads/$BRANCH" | tar -xz -C "$tmp" \
    || die "could not download $OWNER/$REPO"
  src="$tmp/$REPO-$BRANCH"
fi

description_of() { # one-line description from a markdown file's frontmatter
  local d
  d="$(sed -n '2,/^---$/s/^description: *//p' "$1" | head -n 1)"
  case "$d" in \"*\") d="${d#\"}"; d="${d%\"}"; d="${d//\\\"/\"}" ;; esac
  printf '%s' "$d"
}

names_in() { # names of *.md files or of folders in a repo directory
  local dir="$src/$1" kind="$2" f
  [ -d "$dir" ] || return 0
  for f in "$dir"/*; do
    [ -e "$f" ] || continue
    if [ "$kind" = file ]; then
      case "$f" in *.md) basename "$f" .md ;; esac
    elif [ -d "$f" ]; then
      basename "$f"
    fi
  done
}

commands="$(names_in commands file)"
skills="$(names_in skills dir)"
agents="$(names_in agents file)"
rules="$(names_in rules file)"

if [ "$list" = 1 ]; then
  for n in $commands; do printf '/%-30s %s\n' "$n" "$(description_of "$src/commands/$n.md" | cut -c1-90)"; done
  for n in $skills; do
    [ -f "$src/commands/$n.md" ] && continue
    printf 'skill %-25s %s\n' "$n" "$(description_of "$src/skills/$n/SKILL.md" | cut -c1-90)"
  done
  for n in $agents; do printf 'agent %-25s %s\n' "$n" "$(description_of "$src/agents/$n.md" | cut -c1-90)"; done
  exit 0
fi

# --- Where to install, and for which tools. ---------------------------------

if [ -z "$project" ]; then
  project="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
[ -d "$project" ] || die "no such directory: $project"
project="$(cd "$project" && pwd)"
[ "$project" = "$src" ] && die "run this from (or point --project at) the project you want the commands in, not this repo"
cd "$project"

# When this repo sits inside the project (a git submodule at .agents/kits/<repo>),
# link to its files instead of copying them, so updating the submodule updates
# the commands. --copy turns this off.
linked=0
case "$src/" in "$project/"*) [ "$mode" = link ] && linked=1 ;; esac

# Re-runs (kit.sh update) reuse the choices of the first install.
options_file=".agents/.installed/$REPO.options"
if [ -f "$options_file" ] && [ "$uninstall" = 0 ]; then
  if [ "$tools" = auto ]; then
    saved="$(sed -n 's/^tools=//p' "$options_file")"
    [ -n "$saved" ] && tools="$saved"
  fi
  [ -z "$only" ] && only="$(sed -n 's/^only=//p' "$options_file")"
fi

has() { command -v "$1" >/dev/null 2>&1; }
want() { case ",$tools," in *",$1,"*|*",all,"*) return 0 ;; *) return 1 ;; esac; }

if [ "$tools" = auto ]; then
  tools=""
  { [ -e .claude ] || [ -e CLAUDE.md ] || has claude; } && tools="$tools,claude"
  { [ -e .opencode ] || [ -e opencode.json ] || [ -e opencode.jsonc ] || has opencode; } && tools="$tools,opencode"
  { [ -e .kilo ] || [ -e .kilocode ] || has kilo || has kilocode; } && tools="$tools,kilo"
  { [ -e .gemini ] || [ -e GEMINI.md ] || has gemini; } && tools="$tools,gemini"
  { [ -e .github/copilot-instructions.md ] || [ -d .github/prompts ]; } && tools="$tools,copilot"
  { [ -e .windsurf ] || [ -e .windsurfrules ]; } && tools="$tools,windsurf"
  [ -z "$tools" ] && tools=",claude"
  tools="${tools#,}"
fi
for t in ${tools//,/ }; do
  case "$t" in
    all|claude|codex|gemini|opencode|kilo|antigravity|cursor|copilot|windsurf|freebuff) ;;
    *) die "unknown tool: $t (see --help)" ;;
  esac
done

selected() { # is this command, skill or agent part of the install?
  [ -z "$only" ] && return 0
  case ",$only," in *",$1,"*|*",/$1,"*) return 0 ;; *) return 1 ;; esac
}
if [ -n "$only" ]; then
  for n in ${only//,/ }; do
    n="${n#/}"
    case " $(echo $commands $skills $agents) " in *" $n "*) ;; *) die "$REPO has no command, skill or agent called $n (see --list)" ;; esac
  done
fi

# Pull in the skills a chosen command uses (its scripts and references live
# there), so --only never installs a command without what it runs.
if [ -n "$only" ]; then
  changed=1
  while [ "$changed" = 1 ]; do
    changed=0
    for n in ${only//,/ }; do
      n="${n#/}"
      for f in "$src/commands/$n.md" "$src/agents/$n.md" "$src/skills/$n"; do
        [ -e "$f" ] || continue
        for dep in $(grep -rhoE '\.agents/skills/[a-z0-9-]+/' "$f" 2>/dev/null | sed 's#^\.agents/skills/##; s#/$##' | sort -u); do
          [ -d "$src/skills/$dep" ] || continue
          case ",$only," in
            *",$dep,"*) ;;
            *) only="$only,$dep"; changed=1; say "Also installing $dep, which $n uses." ;;
          esac
        done
      done
    done
  done
fi

manifest_dir=".agents/.installed"
manifest="$manifest_dir/$REPO.txt"
begin_mark="<!-- BEGIN $OWNER/$REPO -->"
end_mark="<!-- END $OWNER/$REPO -->"

act() { # run a change, or print it in --dry-run
  if [ "$dry" = 1 ]; then say "  would: $*"; else "$@"; fi
}

# --- Remove what an earlier run installed (also the first half of an update).

remove_previous() {
  [ -f "$manifest" ] || return 0
  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ -L "$path" ] || [ -e "$path" ]; then act rm -rf "$path"; fi
  done < "$manifest"
  act rm -f "$manifest"
}

strip_agents_md_block() {
  [ -f AGENTS.md ] && grep -qF "$begin_mark" AGENTS.md || return 0
  if [ "$dry" = 1 ]; then say "  would: remove the $REPO block from AGENTS.md"; return 0; fi
  awk -v b="$begin_mark" -v e="$end_mark" '$0==b{skip=1} !skip{print} $0==e{skip=0}' AGENTS.md > AGENTS.md.tmp
  mv AGENTS.md.tmp AGENTS.md
  # Drop the file again if the block was all it held.
  grep -q '[^[:space:]]' AGENTS.md || rm -f AGENTS.md
}

if [ "$uninstall" = 1 ]; then
  [ -f "$manifest" ] || die "nothing to uninstall: $project/$manifest is missing"
  say "Removing $OWNER/$REPO from $project"
  remove_previous
  rm -f "$options_file"
  strip_agents_md_block
  for d in .agents/commands .agents/skills .agents/agents .agents/rules "$manifest_dir" \
           .claude/commands .claude/skills .claude/agents .claude/rules .opencode/commands .opencode/agents \
           .kilo/commands .kilo/agents .gemini/commands .github/prompts .windsurf/workflows \
           .claude .opencode .kilo .gemini .windsurf .github .agents; do
    [ -L "$d" ] || rmdir "$d" 2>/dev/null || true
  done
  say "Done. .agents/project-facts.md was left in place, since you may have filled it in."
  exit 0
fi

# --- Install. ----------------------------------------------------------------

installed=""   # newline list of paths, written to the manifest at the end
skipped=""

owned_before=""
[ -f "$manifest" ] && owned_before="$(cat "$manifest")"
is_ours() { printf '%s\n' "$owned_before" | grep -qxF "$1"; }

same_dir() { # true when two directories are the same folder on disk
  [ -d "$1" ] && [ -d "$2" ] && [ "$(cd "$1" && pwd -P)" = "$(cd "$2" && pwd -P)" ]
}

free_to_write() { # refuse to clobber a user's own file of the same name
  local dst="$1"
  if { [ -e "$dst" ] || [ -L "$dst" ]; } && ! is_ours "$dst" && [ "$force" = 0 ]; then
    skipped="$skipped
$dst"
    return 1
  fi
  return 0
}

record() { installed="$installed
$1"; }

relpath() { # relative path from directory $1 to path $2 (both absolute)
  local from="$1" to="$2" up=""
  while [ "${to#"$from"/}" = "$to" ]; do from="$(dirname "$from")"; up="../$up"; done
  printf '%s%s' "$up" "${to#"$from"/}"
}

copy_in() { # copy (or, from a submodule, link) a file or folder from the repo into .agents/
  local from="$1" dst="$2"
  free_to_write "$dst" || return 0
  act mkdir -p "$(dirname "$dst")"
  act rm -rf "$dst"
  if [ "$linked" = 1 ]; then
    act ln -s "$(relpath "$project/$(dirname "$dst")" "$from")" "$dst"
  else
    act cp -R "$from" "$dst"
  fi
  record "$dst"
}

link_in() { # point a tool folder entry at its .agents/ original
  local target="$1" dst="$2" parent depth up=""
  parent="$(dirname "$dst")"
  # Some projects symlink a whole tool folder to .agents (.opencode -> .agents).
  # The file is already there; linking it would replace it with a loop.
  same_dir "$parent" "$(dirname "$target")" && return 0
  free_to_write "$dst" || return 0
  act mkdir -p "$parent"
  act rm -rf "$dst"
  if [ "$mode" = link ]; then
    depth="$(printf '%s' "$parent" | tr -cd '/' | wc -c | tr -d ' ')"
    depth=$((depth + 1))
    while [ "$depth" -gt 0 ]; do up="../$up"; depth=$((depth - 1)); done
    act ln -s "$up$target" "$dst" 2>/dev/null || act cp -R "$target" "$dst"
  else
    act cp -R "$target" "$dst"
  fi
  record "$dst"
}

write_file() { # write generated text ($2) to a path
  local dst="$1"
  free_to_write "$dst" || return 0
  if [ "$dry" = 1 ]; then say "  would: write $dst"; else
    mkdir -p "$(dirname "$dst")"
    printf '%s\n' "$2" > "$dst"
  fi
  record "$dst"
}

yaml_quote() { local s="${1//\\/\\\\}"; printf '"%s"' "${s//\"/\\\"}"; }

pointer() { # body of a thin wrapper that sends the agent to the real command
  printf 'Read `.agents/commands/%s.md` in full, then follow it step by step. %s' "$1" "$2"
}
typed_after='Anything the user typed after the command name is its $ARGUMENTS.'


say "Installing $OWNER/$REPO into $project"
[ "$linked" = 1 ] && say "Linking to ${src#"$project"/} (submodule), so updating it updates the commands."
say "Tools: $tools"
remove_previous

for n in $commands; do
  selected "$n" || continue
  copy_in "$src/commands/$n.md" ".agents/commands/$n.md"
done
for n in $skills; do
  selected "$n" || continue
  copy_in "$src/skills/$n" ".agents/skills/$n"
done
for n in $agents; do
  selected "$n" || continue
  copy_in "$src/agents/$n.md" ".agents/agents/$n.md"
done
for n in $rules; do
  copy_in "$src/rules/$n.md" ".agents/rules/$n.md"
done

for n in $commands; do
  selected "$n" || continue
  desc="$(description_of "$src/commands/$n.md")"
  want claude && link_in ".agents/commands/$n.md" ".claude/commands/$n.md"
  want opencode && link_in ".agents/commands/$n.md" ".opencode/commands/$n.md"
  want kilo && link_in ".agents/commands/$n.md" ".kilo/commands/$n.md"
  if want gemini; then
    write_file ".gemini/commands/$n.toml" "description = $(yaml_quote "$desc")

prompt = \"\"\"
$(pointer "$n" 'Its $ARGUMENTS are: {{args}}')
\"\"\""
  fi
  if want copilot; then
    write_file ".github/prompts/$n.prompt.md" "---
description: $(yaml_quote "$desc")
---

$(pointer "$n" "$typed_after")"
  fi
  if want windsurf; then
    write_file ".windsurf/workflows/$n.md" "---
description: $(yaml_quote "$desc")
---

$(pointer "$n" "$typed_after")"
  fi
done

# Claude Code lists commands/*.md and skills/*/SKILL.md in the same / menu, so
# it only gets the skills that have no command twin. The twins are the thin
# wrappers that let Codex, Antigravity, Cursor and Freebuff run the commands.
for n in $skills; do
  selected "$n" || continue
  [ -f "$src/commands/$n.md" ] && continue
  want claude && link_in ".agents/skills/$n" ".claude/skills/$n"
done

for n in $rules; do
  want claude && link_in ".agents/rules/$n.md" ".claude/rules/$n.md"
done

for n in $agents; do
  selected "$n" || continue
  want claude && link_in ".agents/agents/$n.md" ".claude/agents/$n.md"
  want opencode && link_in ".agents/agents/$n.md" ".opencode/agents/$n.md"
  want kilo && link_in ".agents/agents/$n.md" ".kilo/agents/$n.md"
done

# Project facts: the one file the commands read for anything project-specific.
# Never overwritten. Missing bullets are appended so new commands find them.
facts_template="$src/templates/project-facts.md"
if [ -f "$facts_template" ]; then
  facts=".agents/project-facts.md"
  if [ ! -f "$facts" ]; then
    act mkdir -p .agents
    act cp "$facts_template" "$facts"
    say "Created $facts. Fill it in, or run /setup-project-facts if you installed agent-commands."
  else
    added=0
    while IFS= read -r line; do
      case "$line" in
        "- **"*)
          head="$(printf '%s' "$line" | sed -E 's/^(- \*\*[^*]+\*\*).*/\1/')"
          if ! grep -qF -- "$head" "$facts"; then
            if [ "$dry" = 1 ]; then say "  would: add $head to $facts"; else printf '%s\n' "$line" >> "$facts"; fi
            added=$((added + 1))
          fi ;;
      esac
    done < "$facts_template"
    [ "$added" -gt 0 ] && say "Added $added new bullet(s) to $facts. Fill them in."
  fi
fi

if [ "$agents_md" = 1 ]; then
  strip_agents_md_block
  list_line=""
  for n in $commands; do selected "$n" && list_line="$list_line \`/$n\`"; done
  block="$begin_mark
## Agent commands from $OWNER/$REPO

Each workflow lives in \`.agents/commands/<name>.md\`. They came from \`install.sh\`, and re-running it overwrites them, so put anything about this project in \`.agents/project-facts.md\` instead. The commands read it.

Run one as \`/name\` in Claude Code, OpenCode, Kilo, Gemini CLI, Antigravity, Cursor, Copilot and Windsurf, as \`\$name\` in Codex, or as \`/skill:name\` in Freebuff. In any other agent, ask it to open \`.agents/commands/<name>.md\` and follow it.

Commands:$list_line
$end_mark"
  if [ "$dry" = 1 ]; then say "  would: add the $REPO block to AGENTS.md"; else
    [ -f AGENTS.md ] && [ -s AGENTS.md ] && printf '\n' >> AGENTS.md
    printf '%s\n' "$block" >> AGENTS.md
  fi
fi

if [ "$dry" = 0 ]; then
  mkdir -p "$manifest_dir"
  printf '%s\n' "$installed" | sed '/^$/d' > "$manifest"
  printf 'tools=%s\nonly=%s\n' "$tools" "$only" > "$options_file"
fi

count="$(printf '%s\n' "$installed" | sed '/^$/d' | wc -l | tr -d ' ')"
say "Done: $count files and links. The list is in $manifest."
if [ -n "$skipped" ]; then
  say "Skipped because a file of the same name is already there (use --force to replace):"
  printf '%s\n' "$skipped" | sed '/^$/d; s/^/  /'
fi
say "Commit .agents/ and the tool folders so your team gets them too."
