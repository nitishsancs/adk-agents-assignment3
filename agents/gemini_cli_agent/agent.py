"""(b) Advanced tool agent that uses the Gemini CLI as a tool inside an ADK pipeline.

repo_analysis_pipeline (SequentialAgent)
  1. repo_preparer         clone_repository -> state.repo_name
  2. cli_analysts          ParallelAgent of three agents, each calling run_gemini_cli
                           with a different brief (architecture, test plan, risk review)
  3. report_writer         merges the three CLI outputs into one report

The root agent runs that pipeline for "analyze this repo" requests and calls the CLI
directly for one-off tasks, including edit tasks such as generating unit tests.
"""

import os

from google.adk.agents import Agent, LlmAgent, ParallelAgent, SequentialAgent
from google.adk.tools.agent_tool import AgentTool

from .tools import clone_repository, run_gemini_cli, show_repository_changes

MODEL = os.getenv("FAST_MODEL", "gemini-2.5-flash")


def cli_analyst(name: str, brief: str, output_key: str) -> LlmAgent:
    return LlmAgent(
        name=name,
        model=MODEL,
        instruction=f"""
You delegate codebase reading to the Gemini CLI. Call `run_gemini_cli` exactly once with
repo_name="{{repo_name?}}", allow_edits=false, and this task:

{brief}

Then return the CLI's response verbatim. If the tool returns an error, return the error.
""",
        tools=[run_gemini_cli],
        output_key=output_key,
        include_contents="none",
    )


repo_analysis_pipeline = SequentialAgent(
    name="repo_analysis_pipeline",
    description="Clones a GitHub repo and produces an architecture, testing and risk report using the Gemini CLI.",
    sub_agents=[
        LlmAgent(
            name="repo_preparer",
            model=MODEL,
            instruction=(
                "Find the GitHub URL in the request and call `clone_repository` with it. "
                "Reply with the repo_name and a one-line inventory from the tool result."
            ),
            tools=[clone_repository],
            output_key="repo_inventory",
        ),
        ParallelAgent(
            name="cli_analysts",
            sub_agents=[
                cli_analyst(
                    "architecture_analyst",
                    "Explain this codebase's architecture: entry points, main modules and how a "
                    "request or command flows through them. Reference file paths. Under 400 words.",
                    "architecture_notes",
                ),
                cli_analyst(
                    "test_planner",
                    "Write a prioritized test plan for this codebase: what is untested today, the "
                    "10 most valuable unit or integration tests to add (name the file and function "
                    "each targets), and how to run them. Under 400 words.",
                    "test_plan",
                ),
                cli_analyst(
                    "risk_reviewer",
                    "Review this codebase for the 5 most important bugs, security risks or "
                    "maintainability problems. For each give file:line, why it matters, and a fix. "
                    "Under 400 words.",
                    "risk_review",
                ),
            ],
        ),
        LlmAgent(
            name="report_writer",
            model=MODEL,
            instruction="""
Write a repository report in markdown for {github_url?} using only these Gemini CLI findings.

Inventory: {repo_inventory?}

## Architecture
{architecture_notes?}

## Test plan
{test_plan?}

## Risks
{risk_review?}

Structure: a 3-sentence summary, then Architecture, Test plan, Top risks (as a table:
Risk | Location | Fix), and a short "Next 3 actions" list. Keep file paths exact.
""",
            output_key="repo_report",
            include_contents="none",
        ),
    ],
)

root_agent = Agent(
    name="gemini_cli_agent",
    model=MODEL,
    description="Software engineering assistant that uses the Gemini CLI as a tool to analyze and change GitHub repos.",
    instruction="""
You are a senior software engineer. Your most powerful tool is the Gemini CLI, which can
read a whole repository on its own. Never guess about code you have not seen through it.

- When the user wants a repository analyzed, reviewed or explained in full, call
  `repo_analysis_pipeline` with their message (it must contain the GitHub URL) and
  return its report.
- For a focused question or task on a repo (current repo: {repo_name?}):
  1. If the repo is not cloned yet, call `clone_repository`.
  2. Call `run_gemini_cli` with a precise task. Set allow_edits=true ONLY when the user
     asks you to write or change files (e.g. "generate unit tests for utils.py").
  3. After an edit task, call `show_repository_changes` and show the user what changed.
- Say which tool produced each answer.
""",
    tools=[AgentTool(agent=repo_analysis_pipeline), clone_repository, run_gemini_cli, show_repository_changes],
)
