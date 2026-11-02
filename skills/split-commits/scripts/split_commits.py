#!/usr/bin/env python3
"""Split a pile of uncommitted changes into one commit per piece of work.

Several agent sessions (and you) often edit one working tree at once, so the
changes end up in one huge commit. This matches every changed hunk to the
session transcript whose edit wrote it, groups the hunks by session, and
commits one group at a time. Only this script's short output reaches the
agent, never the diffs, so it stays cheap at hundreds of changed files.

Transcripts read (read-only; a missing one means that agent is not installed):
  claude    ~/.claude/projects/<dir>/*.jsonl, plus <session>/subagents/*.jsonl
  codex     ~/.codex/sessions/**/rollout-*.jsonl
  gemini    ~/.gemini/tmp/<project>/chats/session-*.json[l]
  opencode  ~/.local/share/opencode/opencode.db  (SQLite)
  kilo      ~/.local/share/kilo/kilo.db          (SQLite, same schema)

Usage (from anywhere inside the repository):
  split_commits.py scan [--since 2d|12h|<ISO date>]   build the plan, print it
  split_commits.py list                                print the plan again
  split_commits.py show <G> [--tasks | --diff [--max-chars N]]
  split_commits.py split <G> --by-task | --by-dir
  split_commits.py merge <G-from> <G-into>
  split_commits.py move <path-prefix | path#hunk> <G | new>
  split_commits.py commit <G> -m <subject> [-m <paragraph> ...] [--include-live]
  split_commits.py done                                delete the plan

How a commit is made: a private index is built from HEAD plus only that
group's changes (a whole file, or only its hunks when other groups share the
file), then commit-tree and a compare-and-swap update-ref. The working tree
is never touched, and the shared index only has the committed paths reset to
the new HEAD, so other sessions can keep editing while this runs. Hooks do
not run (commit-tree skips them). The plan lives in .git/split-commits/.

A hunk is a block of changed lines in `git diff -U0`. Its id is a hash of the
path and the lines, so it survives other commits moving it up or down.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone

HOME = os.path.expanduser("~")

# A session whose transcript changed this recently may still be editing: its
# group is skipped unless `commit --include-live` is given.
LIVE_SECONDS = 10 * 60

# Paths that must never be committed by a sweep; they land in the HOLD group.
SECRET_PATH = re.compile(
    r"(^|/)(\.env(\..*)?|.*\.(pem|key|p12|pfx|keystore|jks|mobileprovision)|.*credentials.*\.json|.*service[-_]?account.*\.json|id_(rsa|ed25519)(\.pub)?)$",
    re.IGNORECASE,
)
HOLD_BYTES = 5 * 1024 * 1024

# A shell command that probably writes files (so a path it names may be its output).
SHELL_TOOLS = re.compile(r"^(bash|shell|exec|exec_command|local_shell|run_shell_command|shell_command)$", re.IGNORECASE)
SHELL_WRITES = re.compile(
    r"(sed -i|perl -[a-z]*i|\btee\b|(?<![0-9&>])>{1,2}\s*(?!/dev/null|&)[^\s]|\bmv\s|\bcp\s|\brm\s|\btouch\s|git (mv|rm)\s|(?<!-)\bformat\s|(?<!-)\bfix\s|--fix\b|--write\b|\bgenerate|\bbuild_runner\b)"
)
EDIT_TOOL = re.compile(r"(edit|write|patch|replace|create|notebook)", re.IGNORECASE)

# Prompts this short ("yes", "go on") continue the task before them.
MIN_TASK_PROMPT = 25

DIFF_MAX_CHARS = 6000


def die(message):
    print(f"split_commits: {message}", file=sys.stderr)
    sys.exit(1)


def git(*args, input_bytes=None, env=None, check=True):
    result = subprocess.run(
        ["git", "-c", "core.quotePath=false", *args],
        input=input_bytes,
        capture_output=True,
        env=env,
    )
    if check and result.returncode != 0:
        die(f"git {' '.join(args[:3])} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def git_text(*args, **kwargs):
    return git(*args, **kwargs).decode("utf-8", errors="surrogateescape")


ROOT = os.path.realpath(git_text("rev-parse", "--show-toplevel").strip())
STATE_DIR = os.path.join(ROOT, git_text("rev-parse", "--git-dir").strip(), "split-commits")
PLAN_PATH = os.path.join(STATE_DIR, "plan.json")


# ---------- the working tree ----------


def split_lines(text):
    """Lines with their newline kept; unlike splitlines(), splits on \\n only."""
    return re.findall(r"[^\n]*\n|[^\n]+$", text)


def dirty_paths():
    """{path: kind} for every change against HEAD; kind is M, A, D, T or ? (untracked)."""
    paths = {}
    out = git_text("diff", "HEAD", "--name-status", "--no-renames", "-z")
    fields = out.split("\0")
    for status, path in zip(fields[0::2], fields[1::2]):
        if path:
            paths[path] = status[0]
    for path in git_text("ls-files", "--others", "--exclude-standard", "-z").split("\0"):
        if path:
            paths[path] = "?"
    return paths


def file_hunks(path):
    """The -U0 hunks of a modified text file, or None when it must move as a whole file."""
    raw = git_text("diff", "-U0", "--no-color", "--no-ext-diff", "--no-textconv", "HEAD", "--", path)
    if "\nBinary files " in raw or raw.startswith("Binary files ") or "\nSubproject commit " in raw:
        return None
    if re.search(r"^(old|new) mode ", raw, re.MULTILINE):
        return None
    hunks = []
    current = None
    last = None  # the list the previous -/+ line went to, for "\ No newline"
    for line in split_lines(raw):
        header = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", line)
        if header:
            current = {
                "old_start": int(header.group(1)),
                "old_count": int(header.group(2) or 1),
                "removed": [],
                "added": [],
            }
            hunks.append(current)
            continue
        if current is None:
            continue
        if line.startswith("-"):
            current["removed"].append(line[1:])
            last = current["removed"]
        elif line.startswith("+"):
            current["added"].append(line[1:])
            last = current["added"]
        elif line.startswith("\\") and last:
            last[-1] = last[-1].rstrip("\n")
    seen = {}
    for hunk in hunks:
        digest = hashlib.sha1(
            ("\0".join([path, *hunk["removed"], "\1", *hunk["added"]])).encode("utf-8", "surrogateescape")
        ).hexdigest()[:7]
        seen[digest] = seen.get(digest, 0) + 1
        hunk["id"] = digest if seen[digest] == 1 else f"{digest}{seen[digest]}"
    return hunks


def worktree_units():
    """Every change as a unit: one per hunk of a modified text file, else one per file."""
    units = {}
    for path, kind in sorted(dirty_paths().items()):
        hunks = file_hunks(path) if kind == "M" else None
        if hunks:
            for hunk in hunks:
                units[f"{path}#{hunk['id']}"] = {
                    "path": path,
                    "hunk": hunk["id"],
                    "kind": "M",
                    "added": hunk["added"],
                    "removed": hunk["removed"],
                }
            continue
        added = []
        full = os.path.join(ROOT, path)
        if kind in ("?", "A") and os.path.isfile(full) and os.path.getsize(full) < HOLD_BYTES:
            with open(full, encoding="utf-8", errors="surrogateescape") as fh:
                added = split_lines(fh.read(200_000))
        units[path] = {"path": path, "hunk": None, "kind": kind, "added": added, "removed": []}
    return units


# ---------- the transcripts ----------


class Session:
    def __init__(self, tool, sid, source, updated):
        self.tool = tool
        self.id = sid
        self.source = source
        self.updated = updated  # seconds since the epoch
        self.title = ""
        self.prompts = []  # the task prompts, in order
        self.events = []  # (seconds, task index, write-like, text, mentioned paths)
        self.runs_this_tool = False

    @property
    def ref(self):
        return f"{self.tool}:{self.id[:8]}"


def parse_when(value):
    if isinstance(value, (int, float)):
        return value / 1000 if value > 1e11 else value
    if isinstance(value, str) and value:
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError:
            return None
    return None


def read_jsonl(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line:
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue  # a line cut by a crash mid-write


def strings_in(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from strings_in(item)
    elif isinstance(value, list):
        for item in value:
            yield from strings_in(item)


def is_injected(text):
    stripped = text.lstrip()
    return stripped.startswith("<") or stripped.startswith("# AGENTS.md") or stripped.startswith("Base directory for this skill")


class Recorder:
    """Turns one session's prompts and tool calls into tasks and events."""

    def __init__(self, session, cwd, since, dirty):
        self.session = session
        self.cwd = os.path.realpath(cwd) if cwd else ROOT
        self.since = since
        self.dirty = dirty
        self.stopped = False

    def prompt(self, text):
        text = text.strip()
        if not text or is_injected(text):
            return
        flat = " ".join(text.split())
        if not self.session.title:
            self.session.title = flat[:90]
        if not self.session.prompts or len(flat) >= MIN_TASK_PROMPT:
            self.session.prompts.append(flat[:140])

    def tool_call(self, name, arguments, when):
        if self.stopped:
            return
        text = "\n".join(strings_in(arguments)) if not isinstance(arguments, str) else arguments
        if "split_commits.py" in text:
            # This session is the one splitting commits: ignore it from here on.
            self.session.runs_this_tool = True
            self.stopped = True
            return
        if when is not None and when < self.since:
            return
        if "\\n" in text:
            text = text + "\n" + text.replace("\\n", "\n").replace('\\"', '"').replace("\\t", "\t")
        mentioned = self.paths_in(arguments, text)
        if not mentioned:
            return
        write_like = bool(EDIT_TOOL.search(name)) or "*** Begin Patch" in text
        if not write_like and SHELL_TOOLS.match(name) and SHELL_WRITES.search(text):
            write_like = "shell"
        if not write_like:
            return
        task = max(0, len(self.session.prompts) - 1)
        self.session.events.append((when or self.session.updated, task, write_like, text, mentioned))

    def paths_in(self, arguments, text):
        found = set()
        candidates = []
        if isinstance(arguments, dict):
            for key, value in arguments.items():
                if isinstance(value, str) and re.search(r"path|file", key, re.IGNORECASE):
                    candidates.append(value)
        for line in text[:200_000].splitlines():
            if line.startswith("*** ") and ":" in line:
                candidates.append(line.split(":", 1)[1])
        candidates += re.split(r"[\s'\"`()<>,;=|&]+", text[:20_000])
        for token in candidates:
            token = token.strip().rstrip(".:")
            if not token:
                continue
            for base in (ROOT, self.cwd):
                full = os.path.normpath(token if os.path.isabs(token) else os.path.join(base, token))
                if full.startswith(ROOT + os.sep):
                    rel = full[len(ROOT) + 1:]
                    if rel in self.dirty:
                        found.add(rel)
                        break
        return found


def claude_sessions(since, dirty):
    prefix = re.sub(r"[^A-Za-z0-9]", "-", ROOT)
    sessions = []
    for project in glob.glob(os.path.join(HOME, ".claude", "projects", "*")):
        name = os.path.basename(project)
        if name != prefix and not name.startswith(prefix + "-"):
            continue
        for path in glob.glob(os.path.join(project, "*.jsonl")):
            sid = os.path.basename(path)[: -len(".jsonl")]
            files = [path] + sorted(glob.glob(os.path.join(project, sid, "subagents", "*.jsonl")))
            updated = max(os.path.getmtime(f) for f in files)
            if updated < since:
                continue
            session = Session("claude", sid, path, updated)
            for index, source in enumerate(files):
                recorder = None
                for event in read_jsonl(source):
                    if recorder is None and event.get("cwd"):
                        recorder = Recorder(session, event["cwd"], since, dirty)
                    if recorder is None:
                        continue
                    content = (event.get("message") or {}).get("content")
                    if event.get("type") == "user" and index == 0 and not event.get("isMeta"):
                        if isinstance(content, str):
                            recorder.prompt(content)
                        elif isinstance(content, list):
                            for block in content:
                                if block.get("type") == "text":
                                    recorder.prompt(block["text"])
                    elif event.get("type") == "assistant" and isinstance(content, list):
                        for block in content:
                            if block.get("type") == "tool_use":
                                recorder.tool_call(block["name"], block.get("input", {}), parse_when(event.get("timestamp")))
            sessions.append(session)
    return sessions


def codex_sessions(since, dirty):
    sessions = []
    for path in glob.glob(os.path.join(HOME, ".codex", "sessions", "**", "rollout-*.jsonl"), recursive=True):
        updated = os.path.getmtime(path)
        if updated < since:
            continue
        session = None
        recorder = None
        for event in read_jsonl(path):
            payload = event.get("payload") or {}
            if event.get("type") == "session_meta" and session is None:
                cwd = os.path.realpath(payload.get("cwd") or "/")
                if cwd != ROOT and not cwd.startswith(ROOT + os.sep):
                    break
                session = Session("codex", payload.get("id", os.path.basename(path)), path, updated)
                recorder = Recorder(session, cwd, since, dirty)
                continue
            if recorder is None:
                continue
            kind = payload.get("type")
            if kind == "message" and payload.get("role") == "user":
                recorder.prompt("\n".join(item.get("text", "") for item in payload.get("content", [])))
            elif kind in ("function_call", "custom_tool_call"):
                arguments = payload.get("arguments") or payload.get("input") or ""
                if isinstance(arguments, str) and arguments.startswith("{"):
                    try:
                        arguments = json.loads(arguments)
                    except json.JSONDecodeError:
                        pass
                recorder.tool_call(payload.get("name", ""), arguments, parse_when(event.get("timestamp")))
        if session:
            sessions.append(session)
    return sessions


def gemini_sessions(since, dirty):
    sessions = []
    for project in glob.glob(os.path.join(HOME, ".gemini", "tmp", "*")):
        root_file = os.path.join(project, ".project_root")
        if not os.path.isfile(root_file):
            continue
        with open(root_file) as fh:
            cwd = os.path.realpath(fh.read().strip())
        if cwd != ROOT and not cwd.startswith(ROOT + os.sep):
            continue
        for path in glob.glob(os.path.join(project, "chats", "session-*.json*")):
            updated = os.path.getmtime(path)
            if updated < since:
                continue
            if path.endswith(".json"):
                with open(path, encoding="utf-8") as fh:
                    messages = json.load(fh).get("messages", [])
            else:
                messages = [event for event in read_jsonl(path) if "type" in event]
            session = Session("gemini", os.path.basename(path), path, updated)
            recorder = Recorder(session, cwd, since, dirty)
            for message in messages:
                content = message.get("content")
                text = content if isinstance(content, str) else "\n".join(p.get("text", "") for p in content or [] if isinstance(p, dict))
                if message.get("type") == "user":
                    recorder.prompt(text)
                for call in message.get("toolCalls", []) or []:
                    recorder.tool_call(call.get("name", ""), call.get("args", {}), parse_when(message.get("timestamp")))
            sessions.append(session)
    return sessions


def sqlite_sessions(tool, db_path, since, dirty):
    if not os.path.isfile(db_path):
        return []
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    rows = db.execute("SELECT id, parent_id, directory, time_updated FROM session").fetchall()
    parent_of = {sid: parent for sid, parent, _, _ in rows}
    by_root = {}
    for sid, parent, directory, updated in rows:
        cwd = os.path.realpath(directory or "/")
        if cwd != ROOT and not cwd.startswith(ROOT + os.sep):
            continue
        if (updated or 0) / 1000 < since:
            continue
        root = sid
        while parent_of.get(root):
            root = parent_of[root]  # a subagent's edits belong to the session that spawned it
        by_root.setdefault(root, []).append((sid, cwd, (updated or 0) / 1000))
    sessions = []
    for root, members in by_root.items():
        session = Session(tool, root, db_path, max(m[2] for m in members))
        for sid, cwd, _ in sorted(members, key=lambda m: m[0] != root):
            recorder = Recorder(session, cwd, since, dirty)
            parts = db.execute(
                "SELECT m.data, p.data FROM message m JOIN part p ON p.message_id = m.id "
                "WHERE m.session_id = ? ORDER BY m.time_created, m.id, p.id",
                (sid,),
            ).fetchall()
            for message_data, part_data in parts:
                role = json.loads(message_data).get("role")
                part = json.loads(part_data)
                if part.get("type") == "text" and role == "user" and sid == root and not part.get("synthetic"):
                    recorder.prompt(part.get("text", ""))
                elif part.get("type") == "tool":
                    state = part.get("state") or {}
                    recorder.tool_call(part.get("tool", ""), state.get("input", {}), parse_when((state.get("time") or {}).get("start")))
        sessions.append(session)
    db.close()
    return sessions


def all_sessions(since, dirty):
    sessions = claude_sessions(since, dirty) + codex_sessions(since, dirty) + gemini_sessions(since, dirty)
    for tool in ("opencode", "kilo"):
        sessions += sqlite_sessions(tool, os.path.join(HOME, ".local", "share", tool, f"{tool}.db"), since, dirty)
    return [s for s in sessions if s.events]


# ---------- matching hunks to sessions ----------


def significant(lines):
    kept = []
    for line in lines:
        stripped = line.strip()
        if len(stripped) >= 3 and re.search(r"[A-Za-z0-9]", stripped):
            kept.append(stripped)
    if len(kept) > 40:
        kept = kept[:20] + kept[-20:]
    return kept


def attribute(unit, events):
    """(session, task, confidence) for one unit, from the events that name its path.

    confidence: "strong" when the event's text holds most of the hunk's lines,
    "weak" when a session only touched the file (or ran a writing shell command
    naming it), None when no session did.
    """
    lines = significant(unit["added"]) or significant(unit["removed"])
    best = None
    if lines:
        for session, (when, task, write_like, text, _) in events:
            hits = sum(1 for line in lines if line in text)
            score = hits / len(lines)
            if score >= 0.3 and (best is None or (score, when) > (best[0], best[1])):
                best = (score, when, session, task)
    if best:
        return best[2], best[3], "strong"
    editors = [(when, session, task) for session, (when, task, write_like, _, _) in events if write_like is True]
    shells = [(when, session, task) for session, (when, task, write_like, _, _) in events if write_like == "shell"]
    for pool in (editors, shells):
        if pool:
            when, session, task = max(pool, key=lambda item: item[0])
            return session, task, "weak"
    return None, None, None


def top_dir(path, depth=2):
    parts = path.split("/")[:-1]
    return "/".join(parts[:depth]) or "."


def build_plan(since):
    units = worktree_units()
    if not units:
        return None
    dirty = {unit["path"] for unit in units.values()}
    sessions = all_sessions(since, dirty)
    events_by_path = {}
    for session in sessions:
        for event in session.events:
            for path in event[4]:
                events_by_path.setdefault(path, []).append((session, event))

    now = time.time()
    groups = {}
    session_group = {}
    first_seen = {}
    unattributed = []
    for uid, unit in units.items():
        full = os.path.join(ROOT, unit["path"])
        too_big = os.path.isfile(full) and os.path.getsize(full) >= HOLD_BYTES and unit["kind"] in ("?", "A")
        if SECRET_PATH.search(unit["path"]) or too_big:
            groups.setdefault("HOLD", {"label": "never committed by a sweep: secret-looking or over 5 MB", "units": {}})
            groups["HOLD"]["units"][uid] = {"task": 0, "conf": "hold"}
            continue
        session, task, confidence = attribute(unit, events_by_path.get(unit["path"], []))
        if session is None:
            unattributed.append(uid)
            continue
        if session.ref not in session_group:
            name = f"G{len(session_group) + 1}"
            session_group[session.ref] = name
            groups[name] = {
                "session": session.ref,
                "label": session.title,
                "tasks": session.prompts,
                "live": (now - session.updated) < LIVE_SECONDS and not session.runs_this_tool,
                "units": {},
            }
        name = session_group[session.ref]
        groups[name]["units"][uid] = {"task": task, "conf": confidence}
        first_seen[name] = min(first_seen.get(name, now), min(e[0] for e in session.events))

    # A file no transcript names (a generated barrel, a lock file) joins the one
    # group that owns every other change in its folder; otherwise it is grouped
    # by folder as unattributed.
    owner_by_dir = {}
    for name, group in groups.items():
        if name == "HOLD":
            continue
        for uid in group["units"]:
            owner_by_dir.setdefault(os.path.dirname(units[uid]["path"]), set()).add(name)
    leftover = {}
    for uid in unattributed:
        owners = owner_by_dir.get(os.path.dirname(units[uid]["path"]), set())
        if len(owners) == 1:
            groups[next(iter(owners))]["units"][uid] = {"task": 0, "conf": "folder"}
        else:
            leftover.setdefault(top_dir(units[uid]["path"]), []).append(uid)
    for index, (folder, uids) in enumerate(sorted(leftover.items()), start=1):
        groups[f"U{index}"] = {
            "label": f"no transcript names these: {folder if folder != '.' else '(repo root)'}/",
            "units": {uid: {"task": 0, "conf": "none"} for uid in uids},
        }

    # Number the session groups in the order their work started.
    ordered = sorted((n for n in groups if n.startswith("G")), key=lambda n: first_seen[n])
    renamed = {old: f"G{i}" for i, old in enumerate(ordered, start=1)}
    groups = {renamed.get(n, n): g for n, g in groups.items()}
    stats = {uid: [unit["path"], unit["hunk"], unit["kind"], len(unit["added"]), len(unit["removed"])] for uid, unit in units.items()}
    return {"since": since, "units": stats, "groups": groups}


# ---------- the plan file ----------


def load_plan():
    if not os.path.isfile(PLAN_PATH):
        die("no plan yet: run `scan` first")
    with open(PLAN_PATH) as fh:
        return json.load(fh)


def save_plan(plan):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(PLAN_PATH, "w") as fh:
        json.dump(plan, fh)


def group_of(plan, name):
    if name not in plan["groups"]:
        die(f"no group {name}; groups are {', '.join(plan['groups']) or 'none'}")
    return plan["groups"][name]


def sort_key(name):
    order = {"G": 0, "U": 1, "H": 2}
    digits = re.findall(r"\d+", name)
    return (order.get(name[0], 3), [int(d) for d in digits])


def summary_line(plan, name, group):
    uids = group["units"]
    files = sorted({plan["units"][uid][0] for uid in uids})
    added = sum(plan["units"][uid][3] for uid in uids)
    removed = sum(plan["units"][uid][4] for uid in uids)
    loose = sum(1 for meta in uids.values() if meta["conf"] in ("weak", "folder"))
    flags = []
    if group.get("live"):
        flags.append("LIVE")
    if loose:
        flags.append(f"{loose} loose")
    tasks = {meta["task"] for meta in uids.values()}
    if len(tasks) > 1:
        flags.append(f"{len(tasks)} tasks")
    head = f"{name:<6} {group.get('session', ''):<17} {len(files):>4} files {len(uids):>4} changes +{added}/-{removed}"
    if flags:
        head += f"  [{', '.join(flags)}]"
    dirs = {}
    for path in files:
        dirs[top_dir(path, 3)] = dirs.get(top_dir(path, 3), 0) + 1
    top = sorted(dirs.items(), key=lambda kv: -kv[1])[:3]
    where = ", ".join(f"{d} ({n})" for d, n in top) + (f", +{len(dirs) - 3} more" if len(dirs) > 3 else "")
    return f"{head}\n       {group['label']}\n       in: {where}"


def print_plan(plan):
    groups = plan["groups"]
    total_units = sum(len(g["units"]) for g in groups.values())
    files = {plan["units"][uid][0] for g in groups.values() for uid in g["units"]}
    print(f"split-commits: {total_units} changes in {len(files)} files, {len(groups)} groups (HEAD {git_text('rev-parse', '--short', 'HEAD').strip()})")
    for name in sorted(groups, key=sort_key):
        print(summary_line(plan, name, groups[name]))
    print("legend: LIVE = its session edited in the last 10 min; loose = matched by file or folder only, not by content")


# ---------- commands ----------


def parse_since(value):
    if not value:
        return None
    match = re.fullmatch(r"(\d+)([dh])", value)
    if match:
        return time.time() - int(match.group(1)) * (86400 if match.group(2) == "d" else 3600)
    when = parse_when(value)
    if when is None:
        die(f"--since takes 2d, 12h or an ISO date, not {value!r}")
    return when


def cmd_scan(args):
    since = parse_since(args.since)
    if since is None:
        base = os.path.join(STATE_DIR, "base")
        if os.path.isfile(base):
            with open(base) as fh:
                head = fh.read().strip()
        else:
            head = git_text("rev-parse", "HEAD").strip()
            os.makedirs(STATE_DIR, exist_ok=True)
            with open(base, "w") as fh:
                fh.write(head)
        since = float(git_text("show", "-s", "--format=%ct", head).strip())
        mtimes = [os.path.getmtime(os.path.join(ROOT, p)) for p in dirty_paths() if os.path.exists(os.path.join(ROOT, p))]
        if mtimes:
            since = min(since, min(mtimes))
        since -= 6 * 3600
    plan = build_plan(since)
    if plan is None:
        cmd_done(None)
        print("split-commits: nothing left to commit")
        return
    save_plan(plan)
    print_plan(plan)


def cmd_list(_):
    print_plan(load_plan())


def cmd_show(args):
    plan = load_plan()
    group = group_of(plan, args.group)
    uids = group["units"]
    if args.tasks:
        tasks = group.get("tasks") or []
        counts = {}
        for meta in uids.values():
            counts[meta["task"]] = counts.get(meta["task"], 0) + 1
        for task, count in sorted(counts.items()):
            prompt = tasks[task] if task < len(tasks) else "(no prompt)"
            print(f"task {task}: {count} changes — {prompt}")
        return
    if args.diff:
        budget = args.max_chars
        printed = set()
        for uid in sorted(uids):
            path = plan["units"][uid][0]
            if path in printed:
                continue
            printed.add(path)
            if plan["units"][uid][2] == "?":
                text = f"new file {path} ({plan['units'][uid][3]} lines)\n"
            else:
                text = git_text("diff", "-U1", "--no-color", "--no-ext-diff", "HEAD", "--", path)
            if len(text) > budget:
                print(text[:budget] + f"\n[… cut at {args.max_chars} characters; {len({plan['units'][u][0] for u in uids}) - len(printed)} more files]")
                return
            budget -= len(text)
            print(text, end="")
        return
    by_path = {}
    for uid, meta in uids.items():
        by_path.setdefault(plan["units"][uid][0], []).append((uid, meta))
    print(summary_line(plan, args.group, group))
    for index, (path, entries) in enumerate(sorted(by_path.items())):
        if index == 80:
            print(f"… {len(by_path) - 80} more files")
            break
        kind = plan["units"][entries[0][0]][2]
        confs = sorted({meta["conf"] for _, meta in entries})
        hunks = [plan["units"][uid][1] for uid, _ in entries if plan["units"][uid][1]]
        shape = f"{len(hunks)} hunks" if hunks else {"?": "new", "A": "new", "D": "deleted", "T": "type change"}.get(kind, "whole file")
        print(f"  {path}  {shape}  ({'/'.join(confs)})")


def new_group_name(plan, prefix):
    index = 1
    while f"{prefix}{index}" in plan["groups"]:
        index += 1
    return f"{prefix}{index}"


def cmd_split(args):
    plan = load_plan()
    group = group_of(plan, args.group)
    buckets = {}
    for uid, meta in group["units"].items():
        key = meta["task"] if args.by_task else top_dir(plan["units"][uid][0], 3)
        buckets.setdefault(key, {})[uid] = meta
    if len(buckets) < 2:
        die(f"{args.group} has only one {'task' if args.by_task else 'folder'}; nothing to split")
    del plan["groups"][args.group]
    for index, (key, units) in enumerate(sorted(buckets.items(), key=lambda kv: str(kv[0])), start=1):
        part = dict(group, units=units)
        if args.by_task and isinstance(key, int) and key < len(group.get("tasks") or []):
            part["label"] = group["tasks"][key]
        elif not args.by_task:
            part["label"] = f"{group['label']} — {key}/"
        plan["groups"][f"{args.group}.{index}"] = part
    save_plan(plan)
    print_plan(plan)


def cmd_merge(args):
    plan = load_plan()
    source = group_of(plan, args.source)
    target = group_of(plan, args.target)
    target["units"].update(source["units"])
    target["live"] = bool(target.get("live") or source.get("live"))
    del plan["groups"][args.source]
    save_plan(plan)
    print(summary_line(plan, args.target, target))


def cmd_move(args):
    plan = load_plan()
    if args.target == "new":
        args.target = new_group_name(plan, "N")
        plan["groups"][args.target] = {"label": "moved by hand", "units": {}}
    target = group_of(plan, args.target)
    moved = 0
    for name, group in list(plan["groups"].items()):
        if name == args.target:
            continue
        for uid in list(group["units"]):
            path = plan["units"][uid][0]
            if uid == args.what or path == args.what or path.startswith(args.what.rstrip("/") + "/"):
                target["units"][uid] = dict(group["units"].pop(uid), conf="moved")
                moved += 1
        if not group["units"]:
            del plan["groups"][name]
    if not moved:
        die(f"nothing matches {args.what!r}")
    save_plan(plan)
    print(f"moved {moved} changes to {args.target}")
    print(summary_line(plan, args.target, target))


def patched_blob(path, wanted):
    """HEAD's copy of `path` with only the hunks in `wanted` applied; returns (mode, sha, missing ids)."""
    hunks = file_hunks(path) or []
    present = {h["id"]: h for h in hunks}
    missing = [h for h in wanted if h not in present]
    chosen = sorted((present[h] for h in wanted if h in present), key=lambda h: h["old_start"], reverse=True)
    mode = git_text("ls-tree", "HEAD", "--", path).split(" ")[0]
    lines = split_lines(git(*["cat-file", "blob", f"HEAD:{path}"]).decode("utf-8", errors="surrogateescape"))
    for hunk in chosen:
        start = hunk["old_start"]
        if hunk["removed"]:
            index = start - 1
            if lines[index : index + len(hunk["removed"])] != hunk["removed"]:
                die(f"{path}: hunk {hunk['id']} no longer matches HEAD; run `scan` again")
            lines[index : index + len(hunk["removed"])] = hunk["added"]
        else:
            lines[start:start] = hunk["added"]  # -U0 insertions come after line `start`
    blob = "".join(lines).encode("utf-8", errors="surrogateescape")
    sha = git_text("hash-object", "-w", "--stdin", input_bytes=blob).strip()
    return mode, sha, missing


def cmd_commit(args):
    plan = load_plan()
    group = group_of(plan, args.group)
    if args.group == "HOLD":
        die("HOLD is never committed by this script; commit those files by hand if they really belong in git")
    if group.get("live") and not args.include_live:
        die(f"{args.group} belongs to a session that edited in the last 10 minutes; wait, or pass --include-live")
    wanted = {}
    whole = set()
    for uid in group["units"]:
        path, hunk = plan["units"][uid][0], plan["units"][uid][1]
        if hunk:
            wanted.setdefault(path, set()).add(hunk)
        else:
            whole.add(path)
    for path, ids in list(wanted.items()):
        current = file_hunks(path) or []
        if current and all(h["id"] in ids for h in current):
            whole.add(path)  # the group owns every change left in the file
            del wanted[path]

    old_head = git_text("rev-parse", "HEAD").strip()
    index_file = os.path.join(STATE_DIR, "index")
    env = dict(os.environ, GIT_INDEX_FILE=index_file)
    git("read-tree", "HEAD", env=env)
    stale = []
    if whole:
        listing = "\0".join(sorted(whole)).encode("utf-8", "surrogateescape")
        git("add", "-A", "--pathspec-from-file=-", "--pathspec-file-nul", input_bytes=listing, env=env)
    for path, ids in sorted(wanted.items()):
        mode, sha, missing = patched_blob(path, ids)
        stale += [f"{path}#{h}" for h in missing]
        git("update-index", "--cacheinfo", f"{mode},{sha},{path}", env=env)
    tree = git_text("write-tree", env=env).strip()
    os.remove(index_file)
    if tree == git_text("rev-parse", "HEAD^{tree}").strip():
        del plan["groups"][args.group]
        save_plan(plan)
        print(f"{args.group}: nothing left to commit (already committed elsewhere); removed from the plan")
        return
    message = "\n\n".join(m.strip() for m in args.message) + "\n"
    commit = git_text("commit-tree", tree, "-p", old_head, input_bytes=message.encode()).strip()
    result = subprocess.run(["git", "update-ref", "-m", f"split-commits: {args.group}", "HEAD", commit, old_head], capture_output=True)
    if result.returncode != 0:
        die("HEAD moved while committing (another session committed); nothing was changed. Run `scan` again")
    paths = sorted(whole | set(wanted))
    listing = "\0".join(paths).encode("utf-8", "surrogateescape")
    reset = subprocess.run(
        ["git", "reset", "-q", "--pathspec-from-file=-", "--pathspec-file-nul"], input=listing, capture_output=True
    )
    if reset.returncode not in (0, 1):
        print(f"warning: commit made, but resetting the index for its paths failed: {reset.stderr.decode().strip()}")
    del plan["groups"][args.group]
    save_plan(plan)
    left = sum(len(g["units"]) for g in plan["groups"].values())
    print(f"committed {commit[:9]} {args.group}: {len(paths)} files · {len(plan['groups'])} groups ({left} changes) left in the plan")
    if stale:
        print(f"changed since the scan, left uncommitted ({len(stale)}): {', '.join(stale[:5])}{' …' if len(stale) > 5 else ''}")


def cmd_done(_):
    for name in ("plan.json", "base", "index"):
        path = os.path.join(STATE_DIR, name)
        if os.path.exists(path):
            os.remove(path)
    if os.path.isdir(STATE_DIR) and not os.listdir(STATE_DIR):
        os.rmdir(STATE_DIR)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    scan = sub.add_parser("scan")
    scan.add_argument("--since")
    scan.set_defaults(run=cmd_scan)
    sub.add_parser("list").set_defaults(run=cmd_list)
    show = sub.add_parser("show")
    show.add_argument("group")
    show.add_argument("--tasks", action="store_true")
    show.add_argument("--diff", action="store_true")
    show.add_argument("--max-chars", type=int, default=DIFF_MAX_CHARS)
    show.set_defaults(run=cmd_show)
    split = sub.add_parser("split")
    split.add_argument("group")
    how = split.add_mutually_exclusive_group(required=True)
    how.add_argument("--by-task", action="store_true")
    how.add_argument("--by-dir", action="store_true")
    split.set_defaults(run=cmd_split)
    merge = sub.add_parser("merge")
    merge.add_argument("source")
    merge.add_argument("target")
    merge.set_defaults(run=cmd_merge)
    move = sub.add_parser("move")
    move.add_argument("what")
    move.add_argument("target")
    move.set_defaults(run=cmd_move)
    commit = sub.add_parser("commit")
    commit.add_argument("group")
    commit.add_argument("-m", dest="message", action="append", required=True)
    commit.add_argument("--include-live", action="store_true")
    commit.set_defaults(run=cmd_commit)
    sub.add_parser("done").set_defaults(run=cmd_done)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
