"""Gemini model handle with retries and quota fallback.

Transient 500/503/504 errors are retried with exponential backoff. A 429 means the
model's quota is used up (the Gemini free tier allows ~20 requests per model per day),
so instead of waiting the request moves to the next model in FALLBACK_MODELS and the
exhausted model is skipped for the rest of the process.
"""

import logging
import os
from typing import AsyncGenerator, ClassVar

from google.adk.models import Gemini
from google.adk.models.llm_request import LlmRequest
from google.adk.models.llm_response import LlmResponse
from google.genai import types

log = logging.getLogger(__name__)

DEFAULT_MODEL = "gemini-flash-latest"
FALLBACK_MODELS = [
    m.strip()
    for m in os.getenv(
        "FALLBACK_MODELS",
        "gemini-3.6-flash,gemini-3.5-flash,gemini-3-flash-preview,gemini-3.5-flash-lite,"
        "gemini-3.1-flash-lite,gemini-3.1-flash-lite-preview,gemini-flash-lite-latest",
    ).split(",")
    if m.strip()
]
RETRY = types.HttpRetryOptions(attempts=5, initial_delay=2, max_delay=30, http_status_codes=[500, 503, 504])


class FallbackGemini(Gemini):
    exhausted: ClassVar[set[str]] = set()

    async def generate_content_async(
        self, llm_request: LlmRequest, stream: bool = False
    ) -> AsyncGenerator[LlmResponse, None]:
        candidates = [m for m in dict.fromkeys([self.model, *FALLBACK_MODELS]) if m not in self.exhausted]
        for i, name in enumerate(candidates):
            llm_request.model = name
            try:
                async for response in super().generate_content_async(llm_request, stream):
                    yield response
                return
            except Exception as exc:
                # Only a per-model quota error means "try another model". Other 429s
                # (e.g. Google Search grounding quota) would fail on every model.
                per_model = "Quota exceeded for metric" in str(exc)
                if getattr(exc, "code", None) != 429 or not per_model or i == len(candidates) - 1:
                    raise
                self.exhausted.add(name)
                log.warning("%s quota exhausted, falling back to %s", name, candidates[i + 1])


def gemini(env_var: str = "FAST_MODEL") -> Gemini:
    return FallbackGemini(model=os.getenv(env_var) or DEFAULT_MODEL, retry_options=RETRY)
