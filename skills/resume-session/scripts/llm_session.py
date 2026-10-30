#!/usr/bin/env python3
"""List coding-agent sessions from every local cache, and hand one over to any agent.

When one agent (Claude Code, Codex, Gemini CLI, OpenCode, Kilo, Antigravity)
runs out of tokens mid-task, this finds its cached conversation so the same
agent can resume it natively, or a different agent can read the transcript
and carry on.

Caches read (read-only; a missing one just means that agent is not installed):
  claude       ~/.claude/projects/<dir>/<session>.jsonl  (top level only; subagents skipped)
  codex        ~/.codex/sessions/**/rollout-*.jsonl  + titles from ~/.codex/session_index.jsonl
  gemini       ~/.gemini/tmp/<project>/chats/session-*.json[l]
  opencode     ~/.local/share/opencode/opencode.db  (SQLite)
  kilo         ~/.local/share/kilo/kilo.db          (SQLite, same schema as opencode)
  antigravity  ~/.gemini/antigravity-cli/history.jsonl  (your prompts only: replies are
               stored as protobuf blobs this script does not decode)

Usage:
  llm_session.py                          # on a terminal: list, pick one, resume it
  llm_session.py list [--tool T] [--here] [--limit N]
  llm_session.py show <ref> [--tools] [--tail N]
  llm_session.py handoff <ref> --to <agent> [--tools] [--tail N]

<ref> is "<tool>:<id>" or a unique prefix of a session id, as `list` prints it.
`show` prints the transcript as Markdown. `handoff` writes it to a file and
prints the command that opens <agent> with a prompt to read it and continue.
"""

import argparse
import glob
import json
import os
import shlex
import sqlite3
import sys
import tempfile
import time
from dataclasses import dataclass
from datetime import datetime

HOME = os.path.expanduser("~")
TOOLS = ("claude", "codex", "gemini", "opencode", "kilo", "antigravity")

# The CLI each tool is launched with, and how it takes an opening prompt.
LAUNCH = {
    "claude": ["claude"],
    "codex": ["codex"],
    "gemini": ["gemini", "-i"],
    "opencode": ["opencode", "--prompt"],
    "kilo": ["kilo", "--prompt"],
    "antigravity": ["agy", "-i"],
}

# One message is cut to this many characters in a transcript. A pasted log or a
# file dump can run to megabytes, and the next agent only needs the gist.
MESSAGE_CHAR_LIMIT = 4000

# How much of the end of a Claude transcript is read to find its latest title.
CLAUDE_TAIL_BYTES = 512 * 1024


@dataclass
class Session:
    tool: str
    id: str
    title: str
    cwd: str
    updated_ms: int
    source: str  # the file (or DB) the session was read from

    @property
    def ref(self):
        return f"{self.tool}:{self.id}"


@dataclass
class Turn:
    role: str  # "user", "assistant", or "tool" (a tool call, shown only with --tools)
    text: str


def warn(message):
    print(f"llm_session: {message}", file=sys.stderr)


def iso_to_ms(value):
    return int(datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000)


def mtime_ms(path):
    return int(os.path.getmtime(path) * 1000)


def read_jsonl(path):
    """Yields each JSON line of `path`; reports (never hides) lines that don't parse."""
    bad = 0
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                bad += 1
    if bad:
        warn(f"{bad} unreadable line(s) in {path}")


def is_injected_context(text):
    """True for text an agent harness adds to the user's turn (reminders, env blocks, AGENTS.md)."""
    stripped = text.lstrip()
    return stripped.startswith("<") or stripped.startswith("# AGENTS.md")


def one_line(text, limit=90):
    flat = " ".join(text.split())
    return flat if len(flat) <= limit else flat[: limit - 1] + "…"


def clip(text):
    if len(text) <= MESSAGE_CHAR_LIMIT:
        return text
    return text[:MESSAGE_CHAR_LIMIT] + f"\n[… {len(text) - MESSAGE_CHAR_LIMIT} more characters cut]"


def describe_tool_call(name, arguments):
    if isinstance(arguments, str):
        detail = arguments
    else:
        detail = json.dumps(arguments, ensure_ascii=False)
    return f"{name}: {one_line(detail, 200)}"


# ---------- Claude Code ----------

CLAUDE_PROJECTS = os.path.join(HOME, ".claude", "projects")


def claude_text_parts(content, include_tools):
    """The readable text of a Claude message's content, plus its tool calls when asked."""
    if isinstance(content, str):
        return [("text", content)]
    parts = []
    for block in content:
        kind = block.get("type")
        if kind == "text":
            parts.append(("text", block["text"]))
        elif kind == "tool_use" and include_tools:
            parts.append(("tool", describe_tool_call(block["name"], block.get("input", {}))))
    return parts


def claude_sessions():
    sessions = []
    for path in glob.glob(os.path.join(CLAUDE_PROJECTS, "*", "*.jsonl")):
        sid = os.path.basename(path)[: -len(".jsonl")]
        cwd = ""
        first_prompt = ""
        for event in read_jsonl(path):
            cwd = cwd or event.get("cwd", "")
            if not first_prompt and event.get("type") == "user" and not event.get("isMeta"):
                for kind, text in claude_text_parts(event["message"]["content"], False):
                    if kind == "text" and not is_injected_context(text):
                        first_prompt = text
                        break
            if cwd and first_prompt:
                break
        title = claude_latest_title(path) or first_prompt
        if not title:
            continue  # opened and closed without a prompt: nothing to resume
        sessions.append(Session("claude", sid, one_line(title), cwd, mtime_ms(path), path))
    return sessions


def claude_latest_title(path):
    """The newest title the session was given (renamed > AI-generated > compaction summary)."""
    size = os.path.getsize(path)
    with open(path, "rb") as fh:
        fh.seek(max(0, size - CLAUDE_TAIL_BYTES))
        tail = fh.read().decode("utf-8", errors="replace").splitlines()
    found = {}
    for line in tail:
        if '"type":"custom-title"' in line or '"type":"ai-title"' in line or '"type":"summary"' in line:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue  # the first line of the tail window is usually cut mid-way
            found[event["type"]] = event.get("customTitle") or event.get("aiTitle") or event.get("summary")
    return found.get("custom-title") or found.get("ai-title") or found.get("summary") or ""


def claude_turns(session, include_tools):
    turns = []
    for event in read_jsonl(session.source):
        kind = event.get("type")
        if kind not in ("user", "assistant") or event.get("isMeta") or event.get("isSidechain"):
            continue
        for part_kind, text in claude_text_parts(event["message"]["content"], include_tools):
            if part_kind == "tool":
                turns.append(Turn("tool", text))
            elif kind == "assistant" or not is_injected_context(text) or event.get("isCompactSummary"):
                turns.append(Turn(kind, text))
    return turns


# ---------- Codex ----------

CODEX_DIR = os.path.join(HOME, ".codex")


def codex_titles():
    """Thread names from Codex's index; the last line for an id is its current name."""
    index = os.path.join(CODEX_DIR, "session_index.jsonl")
    if not os.path.isfile(index):
        return {}
    return {entry["id"]: entry["thread_name"] for entry in read_jsonl(index)}


def codex_message_text(payload):
    return "\n".join(item["text"] for item in payload["content"] if "text" in item)


def codex_sessions():
    titles = codex_titles()
    sessions = []
    for path in glob.glob(os.path.join(CODEX_DIR, "sessions", "**", "rollout-*.jsonl"), recursive=True):
        meta = None
        first_prompt = ""
        for event in read_jsonl(path):
            payload = event.get("payload", {})
            if event.get("type") == "session_meta" and meta is None:
                meta = payload
            elif payload.get("type") == "message" and payload.get("role") == "user":
                text = codex_message_text(payload)
                if not is_injected_context(text):
                    first_prompt = text
                    break
        if meta is None:
            warn(f"no session_meta line in {path}")
            continue
        if meta.get("thread_source") == "subagent":
            continue  # a worker spawned by another session, not something to resume
        title = titles.get(meta["id"]) or first_prompt
        if not title:
            continue
        sessions.append(Session("codex", meta["id"], one_line(title), meta.get("cwd", ""), mtime_ms(path), path))
    return sessions


def codex_turns(session, include_tools):
    turns = []
    for event in read_jsonl(session.source):
        if event.get("type") != "response_item":
            continue
        payload = event["payload"]
        kind = payload.get("type")
        if kind == "message" and payload["role"] in ("user", "assistant"):
            text = codex_message_text(payload)
            if payload["role"] == "assistant" or not is_injected_context(text):
                turns.append(Turn(payload["role"], text))
        elif kind in ("function_call", "custom_tool_call") and include_tools:
            turns.append(Turn("tool", describe_tool_call(payload["name"], payload.get("arguments") or payload.get("input", ""))))
    return turns


# ---------- Gemini CLI ----------

GEMINI_TMP = os.path.join(HOME, ".gemini", "tmp")


def gemini_read(path):
    """Returns (session header, messages) for both the .json and the newer .jsonl layout."""
    if path.endswith(".json"):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        return data, data["messages"]
    header = None
    messages = []
    for event in read_jsonl(path):
        if header is None:
            header = event
        elif "type" in event:
            messages.append(event)
        elif "$set" in event:
            header.update(event["$set"])
    if header is None:
        raise ValueError("empty session file")
    return header, messages


def gemini_text(content):
    if isinstance(content, str):
        return content
    return "\n".join(part["text"] for part in content if "text" in part)


def gemini_sessions():
    sessions = []
    for project_dir in glob.glob(os.path.join(GEMINI_TMP, "*")):
        root_file = os.path.join(project_dir, ".project_root")
        # Older Gemini versions name the folder by a hash of the path and keep no
        # .project_root, so the working directory of those sessions is unknown.
        cwd = open(root_file).read().strip() if os.path.isfile(root_file) else ""
        for path in glob.glob(os.path.join(project_dir, "chats", "session-*.json*")):
            try:
                header, messages = gemini_read(path)
            except (ValueError, KeyError) as error:
                warn(f"cannot read {path}: {error}")
                continue
            prompts = [gemini_text(m["content"]) for m in messages if m["type"] == "user"]
            if not prompts:
                continue
            updated = iso_to_ms(header["lastUpdated"]) if "lastUpdated" in header else mtime_ms(path)
            sessions.append(Session("gemini", header["sessionId"], one_line(prompts[0]), cwd, updated, path))
    return sessions


def gemini_turns(session, include_tools):
    _, messages = gemini_read(session.source)
    turns = []
    for message in messages:
        if message["type"] == "user":
            turns.append(Turn("user", gemini_text(message["content"])))
        elif message["type"] == "gemini":
            text = gemini_text(message["content"])
            if text:
                turns.append(Turn("assistant", text))
            if include_tools:
                for call in message.get("toolCalls", []):
                    turns.append(Turn("tool", describe_tool_call(call["name"], call.get("args", {}))))
    return turns


# ---------- OpenCode and Kilo (same SQLite schema) ----------

SQLITE_STORES = {
    "opencode": os.path.join(HOME, ".local", "share", "opencode", "opencode.db"),
    "kilo": os.path.join(HOME, ".local", "share", "kilo", "kilo.db"),
}


def open_readonly(db_path):
    return sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)


def sqlite_sessions(tool):
    db_path = SQLITE_STORES[tool]
    if not os.path.isfile(db_path):
        return []
    with open_readonly(db_path) as db:
        rows = db.execute(
            "SELECT id, title, directory, time_updated FROM session "
            "WHERE parent_id IS NULL AND time_archived IS NULL"
        ).fetchall()
    return [Session(tool, sid, one_line(title), directory, updated, db_path) for sid, title, directory, updated in rows]


def sqlite_turns(session, include_tools):
    with open_readonly(session.source) as db:
        rows = db.execute(
            "SELECT m.data, p.data FROM message m JOIN part p ON p.message_id = m.id "
            "WHERE m.session_id = ? ORDER BY m.time_created, m.id, p.id",
            (session.id,),
        ).fetchall()
    turns = []
    for message_data, part_data in rows:
        role = json.loads(message_data)["role"]
        part = json.loads(part_data)
        if part["type"] == "text" and not part.get("synthetic"):
            turns.append(Turn(role, part["text"]))
        elif part["type"] == "tool" and include_tools:
            turns.append(Turn("tool", describe_tool_call(part["tool"], part["state"].get("input", {}))))
    return turns


# ---------- Antigravity ----------

ANTIGRAVITY_HISTORY = os.path.join(HOME, ".gemini", "antigravity-cli", "history.jsonl")


def antigravity_prompts():
    """Your prompts grouped by conversation; lines with no conversation id are not resumable."""
    if not os.path.isfile(ANTIGRAVITY_HISTORY):
        return {}
    conversations = {}
    for entry in read_jsonl(ANTIGRAVITY_HISTORY):
        if "conversationId" in entry and entry.get("type") != "slash_command":
            conversations.setdefault(entry["conversationId"], []).append(entry)
    return conversations


def antigravity_sessions():
    return [
        Session(
            "antigravity", cid, one_line(entries[0]["display"]), entries[0].get("workspace", ""),
            max(e["timestamp"] for e in entries), ANTIGRAVITY_HISTORY,
        )
        for cid, entries in antigravity_prompts().items()
    ]


def antigravity_turns(session, include_tools):
    return [Turn("user", e["display"]) for e in antigravity_prompts()[session.id]]


# ---------- shared ----------

SCANNERS = {
    "claude": claude_sessions,
    "codex": codex_sessions,
    "gemini": gemini_sessions,
    "opencode": lambda: sqlite_sessions("opencode"),
    "kilo": lambda: sqlite_sessions("kilo"),
    "antigravity": antigravity_sessions,
}

TRANSCRIBERS = {
    "claude": claude_turns,
    "codex": codex_turns,
    "gemini": gemini_turns,
    "opencode": sqlite_turns,
    "kilo": sqlite_turns,
    "antigravity": antigravity_turns,
}


def native_resume_command(session):
    """The command that reopens the session in the agent that made it."""
    if session.tool == "claude":
        command = f"claude --resume {session.id}"
    elif session.tool == "codex":
        command = f"codex resume {session.id}"
    elif session.tool == "gemini":
        command = "gemini --list-sessions   # then: gemini --resume <index>"
    elif session.tool in ("opencode", "kilo"):
        command = f"{session.tool} --session {session.id}"
    elif session.tool == "antigravity":
        command = f"agy --conversation {session.id}"
    else:
        raise ValueError(f"no resume command for tool {session.tool!r}")
    return f"cd {shlex.quote(session.cwd)} && {command}" if session.cwd else command


def scan(tools):
    sessions = []
    for tool in tools:
        sessions.extend(SCANNERS[tool]())
    sessions.sort(key=lambda s: s.updated_ms, reverse=True)
    return sessions


def resolve(ref):
    tool, _, prefix = ref.rpartition(":")
    if tool and tool not in TOOLS:
        sys.exit(f"llm_session: unknown tool {tool!r} (expected one of {', '.join(TOOLS)})")
    matches = [s for s in scan([tool] if tool else TOOLS) if s.id.startswith(prefix)]
    if not matches:
        sys.exit(f"llm_session: no session matches {ref!r}")
    if len(matches) > 1:
        listing = "\n".join(f"  {s.ref}  {s.title}" for s in matches[:10])
        sys.exit(f"llm_session: {ref!r} matches {len(matches)} sessions; use a longer id:\n{listing}")
    return matches[0]


def ago(ms):
    seconds = max(0, int(time.time() - ms / 1000))
    for unit, size in (("d", 86400), ("h", 3600), ("m", 60)):
        if seconds >= size:
            return f"{seconds // size}{unit} ago"
    return f"{seconds}s ago"


def print_list(sessions):
    for number, s in enumerate(sessions, 1):
        print(f"{number:3}) {s.ref:<50} {ago(s.updated_ms):>8}  {s.title}")
        print(f"     {s.cwd or '(working directory unknown)'}")


def transcript_markdown(session, include_tools, tail):
    turns = TRANSCRIBERS[session.tool](session, include_tools)
    total = len(turns)
    if tail:
        turns = turns[-tail:]
    lines = [
        f"# Session handoff: {session.title}",
        "",
        f"- Agent: {session.tool}",
        f"- Session id: {session.id}",
        f"- Working directory: {session.cwd or 'unknown'}",
        f"- Last active: {datetime.fromtimestamp(session.updated_ms / 1000):%Y-%m-%d %H:%M} ({ago(session.updated_ms)})",
        f"- Resume natively: `{native_resume_command(session)}`",
        f"- Read from: {session.source}",
    ]
    if session.tool == "antigravity":
        lines.append("- Note: only the user's prompts are recoverable; the agent's replies are not.")
    if len(turns) < total:
        lines.append(f"- Showing the last {len(turns)} of {total} messages.")
    lines += ["", "## Transcript", ""]
    for turn in turns:
        if turn.role == "tool":
            lines.append(f"> tool call: {turn.text}")
        else:
            lines += [f"### {turn.role}", "", clip(turn.text.strip())]
        lines.append("")
    return "\n".join(lines)


def write_handoff(session, include_tools, tail):
    folder = os.path.join(tempfile.gettempdir(), "llm-session")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, f"{session.tool}-{session.id}.md")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(transcript_markdown(session, include_tools, tail))
    return path


def handoff_command(session, target, path):
    prompt = (
        f"Continue the work from an earlier {session.tool} session. Its transcript is at {path}. "
        "Read it, check the current state of the files it touched, say in a few lines where it left off, "
        "then carry on with the last unfinished task."
    )
    argv = LAUNCH[target] + [prompt]
    return session.cwd, argv


def run_interactive():
    sessions = scan(TOOLS)[:30]
    if not sessions:
        print("No sessions found in any cache.")
        return
    print_list(sessions)
    pick = input(f"\nSession to resume (1-{len(sessions)}, q to quit): ").strip()
    if pick == "q":
        return
    if not pick.isdigit() or not 1 <= int(pick) <= len(sessions):
        sys.exit(f"llm_session: {pick!r} is not a number from the list")
    session = sessions[int(pick) - 1]
    target = input(f"Resume in which agent? [{session.tool}] / {' / '.join(TOOLS)}: ").strip() or session.tool
    if target not in TOOLS:
        sys.exit(f"llm_session: unknown agent {target!r}")
    if session.cwd:
        os.chdir(session.cwd)
    if target == session.tool and session.tool != "gemini":
        argv = shlex.split(native_resume_command(session).split(" && ")[-1])
    else:
        _, argv = handoff_command(session, target, write_handoff(session, False, None))
    os.execvp(argv[0], argv)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command")

    list_parser = commands.add_parser("list", help="list sessions, newest first")
    list_parser.add_argument("--tool", choices=TOOLS)
    list_parser.add_argument("--here", action="store_true", help="only sessions started in this directory or below")
    list_parser.add_argument("--limit", type=int, default=30)

    for name, help_text in (("show", "print a session as Markdown"), ("handoff", "write a handoff file for another agent")):
        sub = commands.add_parser(name, help=help_text)
        sub.add_argument("ref")
        sub.add_argument("--tools", action="store_true", help="include one line per tool call")
        sub.add_argument("--tail", type=int, help="only the last N messages")
        if name == "handoff":
            sub.add_argument("--to", choices=TOOLS, required=True)

    args = parser.parse_args()

    if args.command is None:
        if not sys.stdin.isatty():
            parser.error("choose a subcommand (list, show, handoff) when not on a terminal")
        run_interactive()
    elif args.command == "list":
        sessions = scan([args.tool] if args.tool else TOOLS)
        if args.here:
            here = os.getcwd()
            sessions = [s for s in sessions if s.cwd == here or s.cwd.startswith(here + os.sep)]
        print_list(sessions[: args.limit])
    elif args.command == "show":
        print(transcript_markdown(resolve(args.ref), args.tools, args.tail))
    elif args.command == "handoff":
        session = resolve(args.ref)
        path = write_handoff(session, args.tools, args.tail)
        cwd, argv = handoff_command(session, args.to, path)
        command = shlex.join(argv)
        print(f"Wrote {path}")
        print(f"cd {shlex.quote(cwd)} && {command}" if cwd else command)


if __name__ == "__main__":
    main()
