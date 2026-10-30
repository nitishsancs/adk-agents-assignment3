"""Tools that let ADK agents drive the Gemini CLI against a cloned GitHub repository.

Compared with shelling out a formatted string, these tools:
- pass argv lists (no shell), so a task containing quotes or `$()` cannot inject commands
- accept only https://github.com/<owner>/<repo> URLs and clone shallowly into one workspace
- run the CLI read-only (`--approval-mode plan`) unless the caller explicitly asks to edit
- parse the CLI's JSON output so the agent gets the answer plus token stats, not raw stdout
"""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from google.adk.tools.tool_context import ToolContext

WORKSPACE = Path(os.getenv("GEMINI_CLI_WORKSPACE", Path(__file__).resolve().parents[2] / "workspace"))
CLI_MODEL = os.getenv("GEMINI_CLI_MODEL", "gemini-flash-latest")
CLI_TIMEOUT = int(os.getenv("GEMINI_CLI_TIMEOUT", "600"))
GITHUB_URL = re.compile(r"^https://github\.com/(?P<owner>[\w.-]+)/(?P<repo>[\w.-]+?)(?:\.git)?/?$")
MAX_OUTPUT_CHARS = 20_000


def _repo_dir(repo_name: str) -> Path:
    path = (WORKSPACE / repo_name).resolve()
    if path.parent != WORKSPACE.resolve():
        raise ValueError(f"invalid repository name: {repo_name}")
    return path


def _cli_env() -> dict:
    env = os.environ.copy()
    # The CLI reads GEMINI_API_KEY; ADK reads GOOGLE_API_KEY. Share one key.
    if env.get("GOOGLE_API_KEY") and not env.get("GEMINI_API_KEY"):
        env["GEMINI_API_KEY"] = env["GOOGLE_API_KEY"]
    return env


def clone_repository(github_url: str, tool_context: ToolContext) -> dict:
    """Shallow-clones a public GitHub repository into the agent workspace.

    Args:
        github_url: A URL of the form https://github.com/<owner>/<repo>.

    Returns:
        The local repo name to pass to run_gemini_cli, plus a short inventory.
    """
    match = GITHUB_URL.match(github_url.strip())
    if not match:
        return {"status": "error", "message": "Only https://github.com/<owner>/<repo> URLs are supported."}
    repo_name = match["repo"]
    target = _repo_dir(repo_name)
    WORKSPACE.mkdir(parents=True, exist_ok=True)
    if not (target / ".git").exists():
        shutil.rmtree(target, ignore_errors=True)
        result = subprocess.run(
            ["git", "clone", "--depth", "1", f"https://github.com/{match['owner']}/{repo_name}.git", str(target)],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            return {"status": "error", "message": result.stderr.strip()[-2000:]}

    files = [p for p in target.rglob("*") if p.is_file() and ".git" not in p.parts]
    by_ext: dict[str, int] = {}
    for p in files:
        by_ext[p.suffix or p.name] = by_ext.get(p.suffix or p.name, 0) + 1
    top = sorted(by_ext.items(), key=lambda kv: -kv[1])[:8]
    tool_context.state["repo_name"] = repo_name
    tool_context.state["github_url"] = github_url
    return {
        "status": "ok",
        "repo_name": repo_name,
        "file_count": len(files),
        "top_file_types": dict(top),
        "top_level": sorted(p.name for p in target.iterdir() if p.name != ".git"),
    }


def run_gemini_cli(task: str, repo_name: str, allow_edits: bool = False) -> dict:
    """Runs the Gemini CLI headlessly inside a cloned repository.

    The CLI reads the codebase itself (file discovery, grep, reading files), so the
    task can be high level, e.g. "explain the architecture" or "write a test plan".

    Args:
        task: The instruction for Gemini CLI.
        repo_name: The repo_name returned by clone_repository.
        allow_edits: If true the CLI may create or edit files in the repo (auto_edit mode).
            Leave false for analysis; the CLI then runs in read-only plan mode.

    Returns:
        The CLI's answer, the model used, and token stats.
    """
    try:
        cwd = _repo_dir(repo_name)
    except ValueError as exc:
        return {"status": "error", "message": str(exc)}
    if not cwd.exists():
        return {"status": "error", "message": f"{repo_name} is not cloned yet; call clone_repository first."}

    argv = [
        shutil.which("gemini") or "gemini",
        "-p", task,
        "-m", CLI_MODEL,
        "-o", "json",
        "--skip-trust",
        "--approval-mode", "auto_edit" if allow_edits else "plan",
    ]
    try:
        # stdin must be closed: with -p the CLI also reads stdin and would wait forever.
        result = subprocess.run(
            argv, cwd=cwd, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=CLI_TIMEOUT, env=_cli_env()
        )
    except FileNotFoundError:
        return {"status": "error", "message": "Gemini CLI not found. Install it with: npm install -g @google/gemini-cli"}
    except subprocess.TimeoutExpired:
        return {"status": "error", "message": f"Gemini CLI timed out after {CLI_TIMEOUT}s"}

    payload = _json_or_empty(result.stdout)
    if result.returncode != 0 and not payload:
        # On failure the CLI writes its JSON error object to stderr instead of stdout.
        payload = _json_or_empty(result.stderr[result.stderr.find("{"):]) if "{" in result.stderr else {}
    if result.returncode != 0 or "error" in payload:
        error = payload.get("error")
        detail = (error.get("message") if isinstance(error, dict) else error) or result.stderr.strip()[:2000]
        return {"status": "error", "message": detail}

    answer = payload.get("response", result.stdout)
    models = (payload.get("stats") or {}).get("models") or {}
    tokens = {name: (m.get("tokens") or {}).get("total") for name, m in models.items()}
    tools_used = ((payload.get("stats") or {}).get("tools") or {}).get("byName") or {}
    return {
        "status": "ok",
        "mode": "auto_edit" if allow_edits else "plan (read-only)",
        "response": answer[:MAX_OUTPUT_CHARS],
        "truncated": len(answer) > MAX_OUTPUT_CHARS,
        "tokens_by_model": tokens,
        "cli_tools_used": sorted(tools_used),
    }


def _json_or_empty(text: str) -> dict:
    try:
        value = json.loads(text)
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def show_repository_changes(repo_name: str) -> dict:
    """Shows files the Gemini CLI created or modified in the repo (git status and diff).

    Args:
        repo_name: The repo_name returned by clone_repository.
    """
    try:
        cwd = _repo_dir(repo_name)
    except ValueError as exc:
        return {"status": "error", "message": str(exc)}
    status = subprocess.run(["git", "status", "--short", "--untracked-files=all"], cwd=cwd, capture_output=True, text=True).stdout
    diff = subprocess.run(["git", "diff"], cwd=cwd, capture_output=True, text=True).stdout
    new_files = {}
    for line in status.splitlines():
        if line.startswith("??"):
            path = cwd / line[3:].strip()
            if path.is_file():
                new_files[line[3:].strip()] = path.read_text(errors="replace")[:6000]
    return {"status": "ok", "git_status": status or "clean", "diff": diff[:12000], "new_files": new_files}
