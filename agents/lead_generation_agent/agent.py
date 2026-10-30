"""(a) Deep research agent for lead generation.

Root agent drives an interactive, two-phase deep-research workflow:
  1. pattern_discovery_agent learns what companies did before entering a market.
  2. lead_generation_agent finds companies showing those signals today.
Each phase fans out one validate -> research -> format pipeline per company in parallel.
"""

from datetime import date
from typing import Optional

from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from google.adk.tools.agent_tool import AgentTool
from google.adk.tools.tool_context import ToolContext

from . import prompts
from .config import SMART_MODEL
from .sub_agents.pipelines import intent_extractor_agent, lead_generation_agent, pattern_discovery_agent

STATE_DEFAULTS = {"country": "", "industry": "", "k": "", "m": "", "stage": "initial"}


def set_research_scope(tool_context: ToolContext, k: Optional[int] = None, m: Optional[int] = None) -> dict:
    """Records how many companies to study (k) and how many leads to find (m).

    Args:
        k: Number of recently-invested companies to analyze for patterns, 1 to 10.
        m: Number of new leads to find, 1 to 10.
    """
    for name, value in (("k", k), ("m", m)):
        if value is not None:
            if not 1 <= int(value) <= 10:
                return {"status": "error", "message": f"{name} must be between 1 and 10"}
            tool_context.state[name] = int(value)
    return {"status": "ok", "k": tool_context.state.get("k"), "m": tool_context.state.get("m")}


def reset_research(tool_context: ToolContext) -> dict:
    """Clears the market, scope and findings so the user can start a new search."""
    for key, value in STATE_DEFAULTS.items():
        tool_context.state[key] = value
    for key in ("discovered_patterns", "lead_report"):
        tool_context.state[key] = ""
    return {"status": "reset"}


def init_state(callback_context: CallbackContext) -> None:
    callback_context.state["current_date"] = date.today().isoformat()
    for key, value in STATE_DEFAULTS.items():
        if key not in callback_context.state:
            callback_context.state[key] = value


def track_stage(tool, args, tool_context: ToolContext, tool_response) -> None:
    """Copies structured results into the flat state keys the prompts use."""
    if tool.name == intent_extractor_agent.name:
        result = tool_context.state.get("intent_extraction_result") or {}
        for key in ("country", "industry"):
            if result.get(key):
                tool_context.state[key] = result[key]
        tool_context.state["stage"] = "scoping"
    elif tool.name == pattern_discovery_agent.name and tool_context.state.get("discovered_patterns"):
        tool_context.state["stage"] = "patterns_shown"
    elif tool.name == lead_generation_agent.name and tool_context.state.get("lead_report"):
        tool_context.state["stage"] = "report_delivered"
    return None


root_agent = Agent(
    name="lead_research_assistant",
    model=SMART_MODEL,
    description="Interactive deep-research agent that discovers market-entry patterns and finds new leads.",
    instruction=prompts.ROOT_INSTRUCTION,
    tools=[
        AgentTool(agent=intent_extractor_agent),
        AgentTool(agent=pattern_discovery_agent),
        AgentTool(agent=lead_generation_agent),
        set_research_scope,
        reset_research,
    ],
    before_agent_callback=init_state,
    after_tool_callback=track_stage,
)
