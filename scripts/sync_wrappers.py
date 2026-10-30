#!/usr/bin/env python3
"""Keep a thin skill wrapper next to every command, so agents that only read skills can run them.

    python3 scripts/sync_wrappers.py          # write or refresh skills/<name>/SKILL.md + agents/openai.yaml
    python3 scripts/sync_wrappers.py --check  # exit 1 if a wrapper is missing or stale; changes nothing

`commands/<name>.md` is the only source of truth. A wrapper copies its one-line `description` and tells
the agent to read and follow the command file. Never put workflow steps in a wrapper: they would drift.
Codex, Antigravity, Cursor, Gemini CLI and Freebuff all find skills in `.agents/skills/`. Run this after
adding, renaming or re-describing a command. Files a command owns (references/, scripts/) stay untouched.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMANDS, SKILLS = ROOT / "commands", ROOT / "skills"

BODY = """# {name}

Read `../../commands/{name}.md` (from the project root: `.agents/commands/{name}.md`) in full before doing anything, then follow it step by step.

Text the user gave with the skill is the command's `$ARGUMENTS`. If the skill was picked without any, use the command's default only where it defines one; otherwise ask.

The command file is the only source of truth. Skip frontmatter keys your tool does not understand, but keep their intent: read-only limits and "ask first" steps still apply. Where it says to run another `/command`, run the skill of the same name.
"""


def description(command: Path) -> str:
    match = re.search(r"^description: (.+)$", command.read_text(), re.M)
    if match is None:
        sys.exit(f"{command} needs a one-line `description:` in its frontmatter")
    value = match.group(1).strip()
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1].replace('\\"', '"')
    return value


def wrapper(command: Path) -> dict[Path, str]:
    name = command.stem
    text = command.read_text()
    yaml = (
        "interface:\n"
        f'  display_name: "{name}"\n'
        f'  short_description: "Run the {name} command"\n'
        f'  default_prompt: "Use ${name} to run the {name} command."\n'
    )
    if re.search(r"^disable-model-invocation: true$", text, re.M):
        yaml += "policy:\n  allow_implicit_invocation: false\n"
    skill = SKILLS / name
    return {
        skill / "SKILL.md": f"---\nname: {name}\ndescription: >-\n  {description(command)}\n---\n\n" + BODY.format(name=name),
        skill / "agents" / "openai.yaml": yaml,
    }


def main() -> None:
    check = "--check" in sys.argv
    stale = []
    for command in sorted(COMMANDS.glob("*.md")):
        for path, content in wrapper(command).items():
            if path.is_file() and path.read_text() == content:
                continue
            if check:
                stale.append(str(path.relative_to(ROOT)))
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
                print(f"wrote {path.relative_to(ROOT)}")
    if stale:
        print("stale or missing wrappers (run python3 scripts/sync_wrappers.py):\n  " + "\n  ".join(stale))
        sys.exit(1)


main()
