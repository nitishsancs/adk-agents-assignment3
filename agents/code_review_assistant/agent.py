"""(d) Production-quality code review assistant.

root (code_review_assistant)
 ├─ review_pipeline   SequentialAgent: code_analyzer -> style_checker -> test_runner -> feedback_synthesizer
 └─ fix_pipeline      SequentialAgent: LoopAgent(code_fixer -> fix_test_runner -> fix_validator, max 3)
                                       -> fix_summarizer

Facts come from deterministic tools (AST, pycodestyle); tests really execute in Gemini's
code-execution sandbox; reports and fixed code are versioned artifacts; per-developer
history lives in `user:` state so it carries across sessions. See main.py for the
production server (persistent sessions, health check) and deploy/ for Cloud Run.
"""

from google.adk.agents import Agent

from .config import settings
from .sub_agents.fix import fix_pipeline
from .sub_agents.review import review_pipeline

root_agent = Agent(
    name="code_review_assistant",
    model=settings.worker_model,
    description="Reviews Python code (structure, PEP 8, executed tests) and can fix it automatically.",
    instruction="""
You are a Python code review assistant.

- When the user sends Python code to review, transfer to `review_pipeline` immediately,
  without commenting first. The code must reach it exactly as the user wrote it.
- If the user says yes or asks for a fix, transfer to `fix_pipeline`.
- For questions about what you can do, explain briefly: structure analysis, PEP 8
  scoring, tests executed in a sandbox, written feedback that remembers your past
  reviews, and an automatic fix loop that re-tests until it passes.
""",
    sub_agents=[review_pipeline, fix_pipeline],
)
