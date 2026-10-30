"""Drive one agent through a scripted conversation and record a transcript.

    uv run python scripts/run_agent.py lead_generation_agent "Find fintech leads in Thailand" "3" "yes" "3"

Every agent hop, tool call, tool result and model reply is printed live and written
to docs/runs/<agent>.md, which is the execution evidence linked from the README.
"""

import argparse
import asyncio
import importlib
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "agents"))

from google.adk.runners import InMemoryRunner  # noqa: E402
from google.genai import types  # noqa: E402


def short(value, limit=600) -> str:
    text = value if isinstance(value, str) else json.dumps(value, default=str)
    return text if len(text) <= limit else text[:limit] + f" ... [{len(text) - limit} more chars]"


async def run(agent_pkg: str, turns: list[str], out: Path, user_id: str) -> None:
    module = importlib.import_module(agent_pkg)
    root = module.agent.root_agent
    runner = InMemoryRunner(agent=root, app_name=agent_pkg)
    session = await runner.session_service.create_session(app_name=agent_pkg, user_id=user_id)

    log = [f"# Execution transcript: `{agent_pkg}`\n", f"Root agent: `{root.name}`. Recorded {time.strftime('%Y-%m-%d %H:%M')}.\n"]

    def emit(line: str = "") -> None:
        print(line, flush=True)
        log.append(line)

    for turn_no, text in enumerate(turns, 1):
        emit(f"\n## Turn {turn_no}\n\n**User:** {text}\n")
        started = time.time()
        message = types.Content(role="user", parts=[types.Part(text=text)])
        async for event in runner.run_async(user_id=user_id, session_id=session.id, new_message=message):
            for part in (event.content.parts if event.content else []) or []:
                if part.function_call:
                    emit(f"- `{event.author}` calls **{part.function_call.name}**(`{short(dict(part.function_call.args or {}), 300)}`)")
                elif part.function_response:
                    emit(f"- `{event.author}` ← {part.function_response.name}: `{short(part.function_response.response, 400)}`")
                elif part.executable_code:
                    emit(f"- `{event.author}` executes code:\n\n```python\n{part.executable_code.code}\n```")
                elif part.code_execution_result:
                    emit(f"- `{event.author}` code result: `{short(part.code_execution_result.output, 400)}`")
                elif part.text and not part.thought:
                    if event.is_final_response() and event.author == root.name:
                        emit(f"\n**{event.author}:**\n\n{part.text}\n")
                    else:
                        emit(f"- `{event.author}` says: {short(part.text, 500)}")
            if event.actions and event.actions.state_delta:
                keys = ", ".join(sorted(event.actions.state_delta))
                emit(f"  - state updated: `{keys}`")
        emit(f"\n_Turn took {time.time() - started:.1f}s._")

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(log) + "\n")
    print(f"\nTranscript written to {out.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("agent")
    parser.add_argument("turns", nargs="+")
    parser.add_argument("--out")
    parser.add_argument("--user", default="demo-user")
    args = parser.parse_args()
    out = Path(args.out) if args.out else ROOT / "docs" / "runs" / f"{args.agent}.md"
    asyncio.run(run(args.agent, args.turns, out, args.user))


if __name__ == "__main__":
    main()
