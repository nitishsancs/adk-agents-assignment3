"""Review pipeline: structure -> style -> executed tests -> synthesized feedback."""

from google.adk.agents import Agent, SequentialAgent
from google.adk.code_executors import BuiltInCodeExecutor

from ..config import settings
from ..tools import analyze_code_structure, check_code_style, save_review_report, search_past_feedback

code_analyzer = Agent(
    name="code_analyzer",
    model=settings.worker_model,
    description="Parses the submitted code and reports its structure.",
    instruction="""
Call `analyze_code_structure` with the Python code from the user's message, passed
EXACTLY as written (do not fix, reformat or complete it). Then summarize: number of
functions and classes, any syntax error with its line, and the structural issues.
""",
    tools=[analyze_code_structure],
    output_key="structure_summary",
)

style_checker = Agent(
    name="style_checker",
    model=settings.worker_model,
    description="Scores PEP 8 compliance.",
    instruction="""
Call `check_code_style` (no arguments). Report the score out of 100 and group the
issues by kind (line length, whitespace, naming, imports...) with line numbers.
Mention at most the 8 most important issues.
""",
    tools=[check_code_style],
    output_key="style_summary",
    include_contents="none",
)

test_runner = Agent(
    name="test_runner",
    model=settings.worker_model,
    description="Writes and executes tests for the submitted code in a sandbox.",
    instruction="""
You are a testing specialist. The code under review is:

```python
{code_to_review}
```

1. Infer what each public function is meant to do from its name, docstring and body.
2. Write 8 to 15 focused tests (normal cases, edge cases, invalid input) using plain
   asserts in try/except blocks so every test runs and is counted.
3. EXECUTE the code and the tests with your code executor. Do not guess results.
4. Output ONLY this JSON:
{{"tests_run": n, "passed": n, "failed": n, "errors": n,
  "failures": [{{"test": "...", "input": "...", "expected": "...", "actual": "...", "likely_bug": "..."}}],
  "verdict": "WORKING|BUGGY|BROKEN"}}
""",
    code_executor=BuiltInCodeExecutor(),
    output_key="test_results",
    include_contents="none",
)

feedback_synthesizer = Agent(
    name="feedback_synthesizer",
    model=settings.critic_model,
    description="Turns the analysis, style and test results into constructive feedback.",
    instruction="""
You are a senior engineer mentoring the author. First call `search_past_feedback` to see
whether they have been told about the same issues before.

Inputs:
- Structure: {structure_summary}
- Style: {style_summary}
- Tests (executed): {test_results}

Write markdown feedback:
## Summary
Two sentences, starting with what the code does well.
## Correctness
Failing tests first, each with the input, expected vs actual, and the root cause.
## Style (score N/100)
The few issues that matter most, with line numbers.
## Design
Function length, complexity, docstrings, error handling.
## Recurring patterns
Only if past feedback shows repeats; say so kindly.
## Next steps
At most 3 prioritized actions.

Then call `save_review_report` with the full markdown you wrote, and finally output the
same markdown. If any test failed, the style score is below 90, or there are structural
issues, end the output with: "**Would you like me to fix these issues automatically?**"
""",
    tools=[search_past_feedback, save_review_report],
    output_key="review_feedback",
    include_contents="none",
)

review_pipeline = SequentialAgent(
    name="review_pipeline",
    description="Full code review: structure analysis, PEP 8 scoring, executed tests and written feedback.",
    sub_agents=[code_analyzer, style_checker, test_runner, feedback_synthesizer],
)
