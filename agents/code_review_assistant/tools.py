"""Deterministic tools for the code review assistant.

The LLM agents decide what to say; these functions produce the facts they say it about
(AST structure, PEP 8 violations, scores), so the numbers in a review are reproducible.
"""

import ast
import json
import logging
import re
import tempfile
import time
from pathlib import Path
from typing import Any

import pycodestyle
from google.adk.tools.tool_context import ToolContext
from google.genai import types

from .config import settings

log = logging.getLogger(__name__)

# Session-state keys shared across the pipeline. `user:` keys persist across sessions
# for the same user when a persistent session service is used (see main.py).
CODE = "code_to_review"
STRUCTURE = "structure_analysis"
STYLE = "style_check"
FIXED_CODE = "fixed_code"
FIXED_STYLE = "fixed_style_check"
HISTORY = "user:review_history"


def _strip_fences(code: str) -> str:
    match = re.search(r"```(?:python)?\n(.*?)```", code, re.DOTALL)
    return (match.group(1) if match else code).strip("\n") + "\n"


# --------------------------------------------------------------------- structure ---


def extract_structure(code: str) -> dict[str, Any]:
    tree = ast.parse(code)
    functions, classes, imports = [], [], []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            length = (node.end_lineno or node.lineno) - node.lineno + 1
            functions.append(
                {
                    "name": node.name,
                    "line": node.lineno,
                    "args": [a.arg for a in node.args.args],
                    "length": length,
                    "has_docstring": ast.get_docstring(node) is not None,
                    "complexity": _complexity(node),
                }
            )
        elif isinstance(node, ast.ClassDef):
            classes.append(
                {
                    "name": node.name,
                    "line": node.lineno,
                    "methods": [n.name for n in node.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))],
                    "has_docstring": ast.get_docstring(node) is not None,
                }
            )
        elif isinstance(node, ast.Import):
            imports.extend(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            imports.append(node.module or ".")
    issues = []
    for fn in functions:
        if fn["length"] > settings.max_function_length:
            issues.append(f"{fn['name']} is {fn['length']} lines (limit {settings.max_function_length})")
        if fn["complexity"] > settings.max_complexity:
            issues.append(f"{fn['name']} has cyclomatic complexity {fn['complexity']} (limit {settings.max_complexity})")
        if not fn["has_docstring"] and not fn["name"].startswith("_"):
            issues.append(f"{fn['name']} has no docstring")
    for handler in (n for n in ast.walk(tree) if isinstance(n, ast.ExceptHandler)):
        if handler.type is None:
            issues.append(f"bare except at line {handler.lineno}")
    return {
        "lines": len(code.splitlines()),
        "functions": functions,
        "classes": classes,
        "imports": sorted(set(imports)),
        "structural_issues": issues,
    }


def _complexity(node: ast.AST) -> int:
    branches = (ast.If, ast.For, ast.While, ast.AsyncFor, ast.With, ast.ExceptHandler, ast.IfExp, ast.comprehension)
    score = 1
    for child in ast.walk(node):
        if isinstance(child, branches):
            score += 1
        elif isinstance(child, ast.BoolOp):
            score += len(child.values) - 1
    return score


async def analyze_code_structure(code: str, tool_context: ToolContext) -> dict[str, Any]:
    """Parses Python code and reports its functions, classes, imports and structural issues.

    Args:
        code: The Python source exactly as the user submitted it.
    """
    code = _strip_fences(code)
    tool_context.state[CODE] = code
    try:
        result = extract_structure(code)
    except SyntaxError as exc:
        result = {"status": "syntax_error", "line": exc.lineno, "message": exc.msg, "text": (exc.text or "").strip()}
    else:
        result["status"] = "ok"
    tool_context.state[STRUCTURE] = result
    return result


# ------------------------------------------------------------------------- style ---


def style_report(code: str) -> dict[str, Any]:
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as handle:
        handle.write(code)
        path = handle.name
    issues: list[dict[str, Any]] = []

    class Collector(pycodestyle.StandardReport):
        def error(self, line_number, offset, text, check):  # noqa: D401 - pycodestyle hook
            code_, _, message = text.partition(" ")
            issues.append({"line": line_number, "column": offset + 1, "code": code_, "message": message})
            return super().error(line_number, offset, text, check)

    guide = pycodestyle.StyleGuide(max_line_length=settings.max_line_length, reporter=Collector, quiet=True)
    guide.check_files([path])
    Path(path).unlink(missing_ok=True)

    try:
        issues.extend(_naming_issues(ast.parse(code)))
    except SyntaxError:
        pass
    score = max(0, 100 - sum(5 if i["code"].startswith("E9") else 3 if i["code"].startswith("N") else 2 for i in issues))
    return {"score": score, "issue_count": len(issues), "issues": sorted(issues, key=lambda i: i["line"])[:40]}


def _naming_issues(tree: ast.AST) -> list[dict[str, Any]]:
    snake = re.compile(r"^_{0,2}[a-z][a-z0-9_]*_{0,2}$")
    pascal = re.compile(r"^_?[A-Z][A-Za-z0-9]*$")
    issues = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and not snake.match(node.name):
            issues.append({"line": node.lineno, "column": 1, "code": "N802", "message": f"function name '{node.name}' should be snake_case"})
        elif isinstance(node, ast.ClassDef) and not pascal.match(node.name):
            issues.append({"line": node.lineno, "column": 1, "code": "N801", "message": f"class name '{node.name}' should be PascalCase"})
    return issues


async def check_code_style(tool_context: ToolContext) -> dict[str, Any]:
    """Runs PEP 8 (pycodestyle) and naming checks on the code under review and scores it 0-100."""
    code = tool_context.state.get(CODE, "")
    if not code:
        return {"status": "error", "message": "No code in state; run analyze_code_structure first."}
    result = style_report(code)
    tool_context.state[STYLE] = result
    return {"status": "ok", **result}


# ------------------------------------------------------- history and persistence ---


async def search_past_feedback(tool_context: ToolContext) -> dict[str, Any]:
    """Returns this developer's previous review results so feedback can note recurring issues."""
    history = tool_context.state.get(HISTORY, [])
    recurring: dict[str, int] = {}
    for review in history:
        for code_ in review.get("style_codes", []):
            recurring[code_] = recurring.get(code_, 0) + 1
    return {
        "reviews_so_far": len(history),
        "recent": history[-3:],
        "recurring_style_codes": dict(sorted(recurring.items(), key=lambda kv: -kv[1])[:5]),
    }


async def save_review_report(feedback_markdown: str, tool_context: ToolContext) -> dict[str, Any]:
    """Saves the final review as a versioned artifact and records it in the developer's history.

    Args:
        feedback_markdown: The complete feedback text shown to the developer.
    """
    style = tool_context.state.get(STYLE, {})
    structure = tool_context.state.get(STRUCTURE, {})
    entry = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "style_score": style.get("score"),
        "style_codes": sorted({i["code"] for i in style.get("issues", [])}),
        "functions": [f["name"] for f in structure.get("functions", [])],
        "structural_issue_count": len(structure.get("structural_issues", [])),
    }
    tool_context.state[HISTORY] = (tool_context.state.get(HISTORY, []) + [entry])[-20:]
    report = {"summary": entry, "feedback": feedback_markdown, "code": tool_context.state.get(CODE, "")}
    version = await tool_context.save_artifact(
        "review_report.json",
        types.Part.from_bytes(data=json.dumps(report, indent=2).encode(), mime_type="application/json"),
    )
    return {"status": "saved", "artifact": "review_report.json", "version": version}


# --------------------------------------------------------------------------- fix ---


async def validate_fixed_style(tool_context: ToolContext) -> dict[str, Any]:
    """Re-runs the parse and style checks on the fixed code and compares with the original."""
    fixed = _strip_fences(tool_context.state.get(FIXED_CODE, ""))
    if not fixed.strip():
        return {"status": "error", "message": "No fixed code in state."}
    tool_context.state[FIXED_CODE] = fixed
    try:
        ast.parse(fixed)
    except SyntaxError as exc:
        return {"status": "syntax_error", "line": exc.lineno, "message": exc.msg}
    result = style_report(fixed)
    tool_context.state[FIXED_STYLE] = result
    before = tool_context.state.get(STYLE, {}).get("score")
    return {"status": "ok", "original_score": before, "fixed_score": result["score"], "remaining_issues": result["issues"][:10]}


async def save_fixed_code(tool_context: ToolContext) -> dict[str, Any]:
    """Saves the fixed code as a versioned `fixed_code.py` artifact."""
    fixed = tool_context.state.get(FIXED_CODE, "")
    if not fixed:
        return {"status": "error", "message": "No fixed code in state."}
    version = await tool_context.save_artifact("fixed_code.py", types.Part.from_bytes(data=fixed.encode(), mime_type="text/x-python"))
    return {"status": "saved", "artifact": "fixed_code.py", "version": version}


def exit_fix_loop(tool_context: ToolContext) -> dict[str, Any]:
    """Stops the fix loop. Call only when tests pass and the style score is at or above target."""
    tool_context.actions.escalate = True
    return {"status": "loop_exited"}
