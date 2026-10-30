"""Production API server for all five agents (ADK FastAPI app + health check).

    uv run uvicorn server:app --port 8080

Differences from `adk web` that matter in production:
- sessions persist in a database (SQLite locally, Cloud SQL Postgres in Cloud Run via
  SESSION_SERVICE_URI), so conversations and `user:` history survive restarts
- artifacts (review reports, fixed code) go to GCS when ARTIFACT_SERVICE_URI=gs://...
- MAX_LLM_CALLS caps model calls per request so a looping agent cannot run up cost
- /healthz for Cloud Run probes; SERVE_WEB_UI=false turns the dev UI off
"""

import os
from pathlib import Path

from dotenv import load_dotenv
from google.adk.cli.fast_api import get_fast_api_app

ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")
(ROOT / ".adk").mkdir(exist_ok=True)

app = get_fast_api_app(
    agents_dir=str(ROOT / "agents"),
    session_service_uri=os.getenv("SESSION_SERVICE_URI", f"sqlite+aiosqlite:///{ROOT / '.adk' / 'sessions.db'}"),
    artifact_service_uri=os.getenv("ARTIFACT_SERVICE_URI") or None,
    allow_origins=[o for o in os.getenv("ALLOW_ORIGINS", "").split(",") if o],
    web=os.getenv("SERVE_WEB_UI", "true").lower() == "true",
    max_llm_calls=int(os.getenv("MAX_LLM_CALLS", "200")),
    otel_to_cloud=os.getenv("OTEL_TO_CLOUD", "false").lower() == "true",
)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "agents": sorted(p.name for p in (ROOT / "agents").iterdir() if (p / "agent.py").exists())}
