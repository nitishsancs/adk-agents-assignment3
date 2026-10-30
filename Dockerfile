# Agent API server for all five agents (server.py). Includes Node + Gemini CLI for part (b).
FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl ca-certificates \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && npm install -g @google/gemini-cli@0.66.0 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.9.5 /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY agents ./agents
COPY apps ./apps
COPY server.py ./

RUN useradd --create-home app && mkdir -p /app/.adk /app/workspace && chown -R app /app
USER app
ENV PATH="/app/.venv/bin:$PATH" PORT=8080 GEMINI_CLI_WORKSPACE=/app/workspace
EXPOSE 8080
CMD ["sh", "-c", "uvicorn server:app --host 0.0.0.0 --port ${PORT}"]
