"""(e) Production-quality e-commerce agent ("Finn", a sports store shopping assistant).

Data lives in Postgres (pgvector + PostGIS) and is reached only through MCP Toolbox
for Databases (`store_toolset`, Streamable HTTP MCP). The agent can search products
semantically, check per-store stock, find the nearest store, manage a shopping list,
place, change and cancel orders.

Identity: tools that touch customer data take `user_email`. The model never controls
it. `enforce_signed_in_user` overwrites it on every call with the email the server put
in session state at sign-in (`user:email`), so a prompt like "show bob@example.com's
orders" still only ever returns the signed-in customer's own data.
"""

import logging
import os
from typing import Any, Optional

from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from google.adk.tools.base_tool import BaseTool
from google.adk.tools.mcp_tool import McpToolset, StreamableHTTPConnectionParams
from google.adk.tools.tool_context import ToolContext

from .model import gemini
from .prompt import INSTRUCTION

log = logging.getLogger(__name__)
MODEL = gemini()
TOOLBOX_URL = os.getenv("MCP_TOOLBOX_URL", "http://127.0.0.1:5050")
# Used only by `adk web` / scripts, where there is no sign-in step. The FastAPI server
# (server.py) always sets the real user's email when it creates the session.
DEMO_USER_EMAIL = os.getenv("DEMO_USER_EMAIL", "alicia@example.com")
USER_KEY = "user:email"
NEEDS_CONFIRMATION = {"place-order", "cancel-order"}
USER_SCOPED = {
    "find-nearest-stores",
    "add-to-shopping-list",
    "show-shopping-list",
    "place-order",
    "get-my-orders",
    "update-order-delivery-method",
    "cancel-order",
}


def toolbox_auth_headers(_context=None) -> dict:
    """Cloud Run Toolbox is private: send a Google ID token for it. No-op for local http."""
    if not TOOLBOX_URL.startswith("https://"):
        return {}
    import google.auth.transport.requests
    import google.oauth2.id_token

    token = google.oauth2.id_token.fetch_id_token(google.auth.transport.requests.Request(), TOOLBOX_URL)
    return {"Authorization": f"Bearer {token}"}

store_mcp = McpToolset(
    connection_params=StreamableHTTPConnectionParams(url=f"{TOOLBOX_URL}/mcp/store_toolset", timeout=30),
    header_provider=toolbox_auth_headers,
)


def ensure_user(callback_context: CallbackContext) -> None:
    if not callback_context.state.get(USER_KEY):
        callback_context.state[USER_KEY] = DEMO_USER_EMAIL


def enforce_signed_in_user(tool: BaseTool, args: dict[str, Any], tool_context: ToolContext) -> Optional[dict]:
    """Pins user_email to the session's signed-in user and guards irreversible actions."""
    if tool.name in USER_SCOPED or "user_email" in args:
        email = tool_context.state.get(USER_KEY)
        if not email:
            return {"error": "No signed-in user for this session."}
        if args.get("user_email") not in (None, "", email):
            log.warning("Overriding model-supplied user_email %r with signed-in user", args.get("user_email"))
        args["user_email"] = email
    if tool.name in NEEDS_CONFIRMATION and not tool_context.state.get("temp:confirmed"):
        return {
            "error": "Not confirmed. Summarize the action (store, delivery, total or order id) "
            "for the customer, ask them to confirm, then call `confirm_action` and retry."
        }
    return None


def confirm_action(tool_context: ToolContext) -> dict:
    """Records that the customer explicitly confirmed the order placement or cancellation
    you just summarized. Call only right after the customer says yes."""
    tool_context.state["temp:confirmed"] = True
    return {"status": "confirmed"}


def who_am_i(tool_context: ToolContext) -> dict:
    """Returns the signed-in customer's email."""
    return {"email": tool_context.state.get(USER_KEY)}


root_agent = Agent(
    name="ecommerce_agent",
    model=MODEL,
    description="Finn, the sports store shopping assistant: product search, stock, stores, shopping list and orders.",
    instruction=INSTRUCTION,
    tools=[store_mcp, confirm_action, who_am_i],
    before_agent_callback=ensure_user,
    before_tool_callback=enforce_signed_in_user,
)
