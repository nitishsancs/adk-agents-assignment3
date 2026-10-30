"""Web research tools with a switchable backend.

SEARCH_BACKEND=google (default) uses ADK's built-in `google_search` grounding tool.
SEARCH_BACKEND=ddg uses keyless DuckDuckGo search plus a page fetcher, for API keys
where Google Search grounding has no quota (e.g. the Gemini free tier). Both give the
research agents the same ability: find sources, then read them, citing URLs.
"""

import os
import re
from html import unescape

import httpx
from google.adk.tools import google_search

BACKEND = os.getenv("SEARCH_BACKEND", "google").lower()


def web_search(query: str, max_results: int = 6) -> dict:
    """Searches the web and returns result titles, URLs and snippets.

    Args:
        query: The search query. Use specific terms, names and years.
        max_results: How many results to return (1-10).
    """
    from ddgs import DDGS

    try:
        hits = DDGS().text(query, max_results=max(1, min(int(max_results), 10)))
    except Exception as exc:  # network errors and empty result sets
        return {"status": "error", "message": str(exc)[:300], "results": []}
    return {
        "status": "ok",
        "results": [{"title": h.get("title"), "url": h.get("href"), "snippet": h.get("body")} for h in hits],
    }


def fetch_page(url: str) -> dict:
    """Downloads a web page and returns its readable text (first ~6,000 characters).

    Args:
        url: An http(s) URL from a search result.
    """
    if not url.startswith(("http://", "https://")):
        return {"status": "error", "message": "Only http(s) URLs are allowed."}
    try:
        response = httpx.get(url, timeout=15, follow_redirects=True, headers={"User-Agent": "Mozilla/5.0 research-agent"})
    except httpx.HTTPError as exc:
        return {"status": "error", "message": str(exc)[:300]}
    html = re.sub(r"(?is)<(script|style|noscript|svg).*?</\1>", " ", response.text)
    text = unescape(re.sub(r"\s+", " ", re.sub(r"(?s)<[^>]+>", " ", html))).strip()
    return {"status": "ok", "url": str(response.url), "text": text[:6000]}


def research_tools() -> list:
    return [web_search, fetch_page] if BACKEND == "ddg" else [google_search]
