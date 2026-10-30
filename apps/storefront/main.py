"""Storefront web app for the (e) e-commerce agent.

    uv run uvicorn apps.storefront.main:app --port 8081   ->  http://127.0.0.1:8081

- Sign-in: the customer picks their account; the email is checked against storedb.users
  and stored in an HMAC-signed, HttpOnly cookie. (Swap `login` for Google Identity
  token verification in a real deployment; everything downstream stays the same.)
- Chat: each request runs the ADK agent with user_id = the signed-in email and the
  session state `user:email` set by the server, never by the browser or the model.
- Sessions persist in SQLite / Postgres through DatabaseSessionService.
- Replies stream to the browser as Server-Sent Events.
"""

import base64
import hashlib
import hmac
import json
import os
import sys
import uuid
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from fastapi import Cookie, FastAPI, HTTPException, Request, Response
from fastapi.responses import FileResponse, StreamingResponse
from google.adk.runners import Runner
from google.adk.sessions import DatabaseSessionService
from google.genai import types

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")
sys.path.insert(0, str(ROOT / "agents"))

from ecommerce_agent.agent import USER_KEY, root_agent  # noqa: E402

APP_NAME = "ecommerce_agent"
SECRET = os.getenv("STOREFRONT_SECRET", "dev-only-change-me").encode()
DSN = "host={} port=5432 user={} password={} dbname=storedb".format(
    os.getenv("DB_HOST", "127.0.0.1"), os.getenv("DB_USER", "postgres"), os.getenv("DB_PASSWORD", "postgres")
)
(ROOT / ".adk").mkdir(exist_ok=True)
sessions = DatabaseSessionService(
    db_url=os.getenv("STOREFRONT_SESSION_URI", f"sqlite+aiosqlite:///{ROOT / '.adk' / 'storefront.db'}")
)
runner = Runner(app_name=APP_NAME, agent=root_agent, session_service=sessions)
app = FastAPI(title="Finn storefront")


def sign(email: str) -> str:
    mac = hmac.new(SECRET, email.encode(), hashlib.sha256).hexdigest()
    return base64.urlsafe_b64encode(f"{email}|{mac}".encode()).decode()


def verify(token: str | None) -> str:
    try:
        email, mac = base64.urlsafe_b64decode(token or "").decode().rsplit("|", 1)
    except Exception:
        raise HTTPException(401, "Not signed in")
    if not hmac.compare_digest(mac, hmac.new(SECRET, email.encode(), hashlib.sha256).hexdigest()):
        raise HTTPException(401, "Bad session")
    return email


@app.get("/")
def index() -> FileResponse:
    return FileResponse(Path(__file__).with_name("index.html"))


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/api/customers")
def customers() -> list[dict]:
    with psycopg.connect(DSN) as conn:
        rows = conn.execute("SELECT first_name, last_name, email FROM users ORDER BY user_id").fetchall()
    return [{"name": f"{f} {l}", "email": e} for f, l, e in rows]


@app.post("/api/login")
async def login(request: Request, response: Response) -> dict:
    email = (await request.json()).get("email", "")
    with psycopg.connect(DSN) as conn:
        if not conn.execute("SELECT 1 FROM users WHERE email = %s", (email,)).fetchone():
            raise HTTPException(403, "Unknown customer")
    response.set_cookie("finn_session", sign(email), httponly=True, samesite="lax", secure=os.getenv("COOKIE_SECURE") == "1")
    return {"email": email}


@app.post("/api/logout")
def logout(response: Response) -> dict:
    response.delete_cookie("finn_session")
    return {"ok": True}


@app.get("/api/me")
def me(finn_session: str | None = Cookie(default=None)) -> dict:
    return {"email": verify(finn_session)}


@app.post("/api/chat")
async def chat(request: Request, finn_session: str | None = Cookie(default=None)) -> StreamingResponse:
    email = verify(finn_session)
    body = await request.json()
    message = (body.get("message") or "").strip()
    if not message:
        raise HTTPException(400, "Empty message")
    session_id = body.get("session_id") or str(uuid.uuid4())
    session = await sessions.get_session(app_name=APP_NAME, user_id=email, session_id=session_id)
    if session is None:
        session = await sessions.create_session(
            app_name=APP_NAME, user_id=email, session_id=session_id, state={USER_KEY: email}
        )

    async def stream():
        yield f"event: session\ndata: {json.dumps({'session_id': session.id})}\n\n"
        content = types.Content(role="user", parts=[types.Part(text=message)])
        async for event in runner.run_async(user_id=email, session_id=session.id, new_message=content):
            for part in (event.content.parts if event.content else []) or []:
                if part.function_call:
                    yield f"event: tool\ndata: {json.dumps({'name': part.function_call.name})}\n\n"
                elif part.text and not part.thought and event.is_final_response():
                    yield f"event: message\ndata: {json.dumps({'text': part.text})}\n\n"
        yield "event: done\ndata: {}\n\n"

    return StreamingResponse(stream(), media_type="text/event-stream")
