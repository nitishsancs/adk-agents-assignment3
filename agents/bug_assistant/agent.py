"""(c) MCP-tools-based agent for software bug assistance.

Tool sources, one of each kind ADK supports:
- MCP (Streamable HTTP) -> MCP Toolbox for Databases, `tickets_toolset` over Postgres/pgvector
- MCP (Streamable HTTP) -> GitHub's remote MCP server (read-only issue/PR tools)
- Built-in tool         -> Google Search, wrapped in its own agent via AgentTool
- Third-party tool      -> LangChain StackExchange search via LangchainTool
- Function tool         -> get_current_date
"""

import logging
import os
from datetime import date

from google.adk.agents import Agent
from google.adk.tools import google_search
from google.adk.tools.agent_tool import AgentTool
from google.adk.tools.langchain_tool import LangchainTool
from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams

from .prompt import INSTRUCTION

log = logging.getLogger(__name__)
MODEL = os.getenv("FAST_MODEL", "gemini-2.5-flash")
TOOLBOX_URL = os.getenv("MCP_TOOLBOX_URL", "http://127.0.0.1:5000")
GITHUB_TOKEN = os.getenv("GITHUB_PERSONAL_ACCESS_TOKEN", "")


def toolbox_auth_headers(_context=None) -> dict:
    """Cloud Run Toolbox is private: send a Google ID token for it. No-op for local http."""
    if not TOOLBOX_URL.startswith("https://"):
        return {}
    import google.auth.transport.requests
    import google.oauth2.id_token

    token = google.oauth2.id_token.fetch_id_token(google.auth.transport.requests.Request(), TOOLBOX_URL)
    return {"Authorization": f"Bearer {token}"}


def get_current_date() -> dict:
    """Returns today's date as YYYY-MM-DD. Use it to resolve 'last week', 'today', etc."""
    return {"current_date": date.today().isoformat()}


search_agent = Agent(
    name="google_search_agent",
    model=MODEL,
    description="Searches the web for error messages, CVEs, release notes and known fixes.",
    instruction="You are a Google Search specialist. Search, then answer concisely with source URLs.",
    tools=[google_search],
)

tickets_mcp = McpToolset(
    connection_params=StreamableHTTPConnectionParams(url=f"{TOOLBOX_URL}/mcp/tickets_toolset", timeout=30),
    header_provider=toolbox_auth_headers,
)

tools = [get_current_date, AgentTool(agent=search_agent), tickets_mcp]

try:
    from langchain_community.tools import StackExchangeTool
    from langchain_community.utilities import StackExchangeAPIWrapper

    tools.append(LangchainTool(tool=StackExchangeTool(api_wrapper=StackExchangeAPIWrapper(max_results=3))))
except Exception as exc:  # stackapi missing or network-restricted environment
    log.warning("StackExchange tool disabled: %s", exc)

if GITHUB_TOKEN:
    tools.append(
        McpToolset(
            connection_params=StreamableHTTPConnectionParams(
                url="https://api.githubcopilot.com/mcp/",
                headers={"Authorization": f"Bearer {GITHUB_TOKEN}"},
                timeout=30,
            ),
            tool_filter=[
                "search_repositories",
                "search_issues",
                "list_issues",
                "get_issue",
                "list_pull_requests",
                "get_pull_request",
            ],
        )
    )

root_agent = Agent(
    name="bug_assistant",
    model=MODEL,
    description="Triages and debugs software bugs using an MCP ticket database, GitHub, StackOverflow and web search.",
    instruction=INSTRUCTION,
    tools=tools,
)
