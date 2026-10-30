"""Append the Gemini CLI's own session logs to the (b) transcript.

    uv run python scripts/summarize_cli_sessions.py itsdangerous 2026-10-30T04:45

The parallel CLI analysts run inside an AgentTool, whose inner events are not surfaced
to the parent runner. The CLI keeps its own JSONL session log per invocation in
~/.gemini/tmp/<repo>/chats/, so this lists each invocation: the task ADK sent, the
model, the tools the CLI itself used to read the repo, and the start of its answer.
"""

import json
import sys
from pathlib import Path

repo, since = sys.argv[1], sys.argv[2]
chats = Path.home() / ".gemini" / "tmp" / repo / "chats"
out = ["", "## Gemini CLI invocations (from the CLI's session logs)", ""]
for path in sorted(chats.glob("session-*.jsonl")):
    records = [json.loads(line) for line in path.open() if line.strip()]
    start = records[0].get("startTime", "")
    if start < since:
        continue
    task, model, tools, answer = "", "", [], ""
    for rec in records:
        if rec.get("type") == "user":
            text = " ".join(p.get("text", "") for p in rec.get("content", []) if isinstance(p, dict))
            if text and not text.lstrip().startswith("<session_context>") and not task:
                task = text.strip()
        elif rec.get("type") == "gemini":
            model = rec.get("model") or model
            for call in rec.get("toolCalls") or []:
                arg = json.dumps(call.get("args", {}))[:90].replace(str(Path.home()), "~")
                tools.append(f"`{call.get('name')}`({arg})")
            content = rec.get("content")
            text = content if isinstance(content, str) else " ".join(
                p.get("text", "") for p in (content or []) if isinstance(p, dict)
            )
            if text.strip():
                answer = text.strip()
    out += [
        f"### {start[11:19]} UTC, model `{model}`",
        f"**Task from ADK:** {task[:300]}",
        "",
        f"**CLI tool calls ({len(tools)}):** " + (", ".join(tools[:12]) + (" ..." if len(tools) > 12 else "") or "none"),
        "",
        "**Answer (start):** " + answer[:500].replace("\n", " ") + ("..." if len(answer) > 500 else ""),
        "",
    ]
transcript = Path(__file__).resolve().parents[1] / "docs" / "runs" / "gemini_cli_agent.md"
transcript.write_text(transcript.read_text() + "\n".join(out) + "\n")
print("\n".join(out)[:3000])
