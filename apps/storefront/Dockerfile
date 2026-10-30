# Storefront for part (e). Build from the repo root:
#   docker build -f apps/storefront/Dockerfile -t finn-storefront .
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.9.5 /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project
COPY agents ./agents
COPY apps ./apps
RUN useradd --create-home app && mkdir -p /app/.adk && chown -R app /app
USER app
ENV PATH="/app/.venv/bin:$PATH" PORT=8080 COOKIE_SECURE=1
EXPOSE 8080
CMD ["sh", "-c", "uvicorn apps.storefront.main:app --host 0.0.0.0 --port ${PORT}"]
