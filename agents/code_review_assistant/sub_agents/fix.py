"""Fix pipeline: a bounded fix -> test -> validate loop, then a summary of what changed."""

from google.adk.agents import Agent, LoopAgent, SequentialAgent
from google.adk.code_executors import BuiltInCodeExecutor

from ..config import settings
from ..tools import exit_fix_loop, save_fixed_code, validate_fixed_style

code_fixer = Agent(
    name="code_fixer",
    model=settings.critic_model,
    description="Rewrites the code to fix the problems found in review.",
    instruction="""
Fix this Python code.

Original:
```python
{code_to_review}
```

Review feedback: {review_feedback}
Previous fix attempt, if any: {fixed_code?}
Validator notes on that attempt, if any: {fix_validation?}

Fix every failing test's root cause, PEP 8 issues (max line length 100) and missing
docstrings. Keep the public function names and signatures unless the feedback shows the
interface itself is the bug. Output ONLY the complete fixed code in one ```python block.
""",
    output_key="fixed_code",
    include_contents="none",
)

fix_test_runner = Agent(
    name="fix_test_runner",
    model=settings.worker_model,
    description="Re-runs the tests against the fixed code.",
    instruction="""
Execute tests against this fixed code with your code executor:

{fixed_code}

Re-create the failing cases from the original test run and add edge cases:
{test_results}

Output ONLY JSON: {{"tests_run": n, "passed": n, "failed": n, "errors": n, "failures": [...]}}
""",
    code_executor=BuiltInCodeExecutor(),
    output_key="fix_test_results",
    include_contents="none",
)

fix_validator = Agent(
    name="fix_validator",
    model=settings.worker_model,
    description="Decides whether the fix is good enough to stop iterating.",
    instruction=f"""
1. Call `validate_fixed_style` (no arguments).
2. Read the test results: {{fix_test_results}}
3. If failed == 0, errors == 0 and fixed_score >= {settings.target_style_score}: call
   `exit_fix_loop`, then reply "SUCCESS: <one line>".
   Otherwise reply "RETRY: <the specific remaining problems for the next attempt>".
""",
    tools=[validate_fixed_style, exit_fix_loop],
    output_key="fix_validation",
    include_contents="none",
)

fix_summarizer = Agent(
    name="fix_summarizer",
    model=settings.worker_model,
    description="Presents the final fixed code and what changed.",
    instruction="""
Call `save_fixed_code`. Then write markdown for the developer:

## Fix result
SUCCESS or PARTIAL, from: {fix_validation}
## What changed
Bullet list of each fix and why, comparing against the review: {review_feedback}
## Tests after fix
From: {fix_test_results}
## Fixed code
{fixed_code}
""",
    tools=[save_fixed_code],
    output_key="fix_summary",
    include_contents="none",
)

fix_pipeline = SequentialAgent(
    name="fix_pipeline",
    description="Automatically fixes the reviewed code, re-testing until it passes or attempts run out.",
    sub_agents=[
        LoopAgent(
            name="fix_attempt_loop",
            sub_agents=[code_fixer, fix_test_runner, fix_validator],
            max_iterations=settings.max_fix_attempts,
        ),
        fix_summarizer,
    ],
)
