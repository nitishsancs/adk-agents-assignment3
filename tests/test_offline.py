"""Unit tests for the deterministic parts of all five agents. No API key or network needed.

    uv run pytest -q
"""

import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "agents"))


class FakeToolContext:
    def __init__(self, state=None):
        self.state = dict(state or {})
        self.actions = SimpleNamespace(escalate=False)


# ---------------------------------------------------------------- (a) lead gen ---


def test_company_text_cannot_inject_state_placeholders():
    from lead_generation_agent.sub_agents.fanout import describe_company, fill

    text = describe_company({"company_name": "Acme {country}", "business_description": "x"})
    assert "{" not in text and "}" not in text
    assert fill("Company:\n%(company)s\nin {country?}", company=text).endswith("in {country?}")


def test_research_scope_is_bounded():
    from lead_generation_agent.agent import set_research_scope

    ctx = FakeToolContext()
    assert set_research_scope(ctx, k=3)["k"] == 3
    assert set_research_scope(ctx, m=11)["status"] == "error"
    assert "m" not in ctx.state


# ----------------------------------------------------------- (b) gemini cli tool ---


@pytest.mark.parametrize(
    "url",
    ["http://github.com/a/b", "https://evil.com/a/b", "https://github.com/a/b; rm -rf /", "https://github.com/a/../../etc"],
)
def test_clone_rejects_non_github_urls(url):
    from gemini_cli_agent.tools import clone_repository

    assert clone_repository(url, FakeToolContext())["status"] == "error"


def test_cli_rejects_path_traversal_and_missing_repo():
    from gemini_cli_agent.tools import run_gemini_cli

    assert run_gemini_cli("explain", "../../etc")["status"] == "error"
    assert "clone_repository" in run_gemini_cli("explain", "never-cloned-repo-xyz")["message"]


# ------------------------------------------------------------ (c) and (e) toolbox ---


def load_toolbox_docs():
    return [d for d in yaml.safe_load_all((ROOT / "infra/toolbox/tools.yaml").read_text()) if d]


def test_every_toolset_tool_is_defined_and_uses_a_known_source():
    docs = load_toolbox_docs()
    tools = {d["name"]: d for d in docs if d["kind"] == "tool"}
    sources = {d["name"] for d in docs if d["kind"] == "source"}
    for toolset in (d for d in docs if d["kind"] == "toolset"):
        for name in toolset["tools"]:
            assert name in tools, f"{toolset['name']} references undefined tool {name}"
            assert tools[name]["source"] in sources


def test_customer_tools_all_take_user_email():
    from ecommerce_agent.agent import USER_SCOPED

    tools = {d["name"]: d for d in load_toolbox_docs() if d["kind"] == "tool"}
    declared = {n for n, t in tools.items() if any(p["name"] == "user_email" for p in t.get("parameters", []))}
    assert declared == USER_SCOPED


# --------------------------------------------------------------- (d) code review ---


BUGGY = '''
import os
def AddNumbers(a,b):
    try:
        return a+b
    except:
        pass
class bad_class:
    pass
'''


def test_structure_finds_functions_classes_and_bare_except():
    from code_review_assistant.tools import extract_structure

    result = extract_structure(BUGGY)
    assert [f["name"] for f in result["functions"]] == ["AddNumbers"]
    assert [c["name"] for c in result["classes"]] == ["bad_class"]
    assert any("bare except" in issue for issue in result["structural_issues"])


def test_style_report_flags_pep8_and_naming():
    from code_review_assistant.tools import style_report

    report = style_report(BUGGY)
    codes = {i["code"] for i in report["issues"]}
    assert {"N802", "N801", "E231"} <= codes
    assert report["score"] < 100
    clean = style_report('def add(a, b):\n    """Add."""\n    return a + b\n')
    assert clean["score"] == 100


@pytest.mark.asyncio
async def test_exit_fix_loop_escalates():
    from code_review_assistant.tools import exit_fix_loop

    ctx = FakeToolContext()
    exit_fix_loop(ctx)
    assert ctx.actions.escalate is True


# ---------------------------------------------------------------- (e) ecommerce ---


def test_user_email_is_pinned_to_signed_in_user():
    from ecommerce_agent.agent import enforce_signed_in_user

    ctx = FakeToolContext({"user:email": "alicia@example.com"})
    args = {"user_email": "bob@example.com"}
    assert enforce_signed_in_user(SimpleNamespace(name="get-my-orders"), args, ctx) is None
    assert args["user_email"] == "alicia@example.com"


def test_orders_require_explicit_confirmation():
    from ecommerce_agent.agent import confirm_action, enforce_signed_in_user

    ctx = FakeToolContext({"user:email": "alicia@example.com"})
    tool = SimpleNamespace(name="place-order")
    blocked = enforce_signed_in_user(tool, {"store_name": "x", "delivery_method": "y"}, ctx)
    assert "Not confirmed" in blocked["error"]
    confirm_action(ctx)
    assert enforce_signed_in_user(tool, {"store_name": "x", "delivery_method": "y"}, ctx) is None


def test_no_signed_in_user_blocks_customer_tools():
    from ecommerce_agent.agent import enforce_signed_in_user

    result = enforce_signed_in_user(SimpleNamespace(name="show-shopping-list"), {}, FakeToolContext())
    assert "No signed-in user" in result["error"]
