"""Dynamic fan-out research: one validate -> research -> format pipeline per company.

The number of companies is only known after the finder agent runs, so the parallel
branches are built at run time from session state rather than declared up front.
"""

from typing import AsyncGenerator, ClassVar

from google.adk.agents import BaseAgent, LlmAgent, ParallelAgent, SequentialAgent
from google.adk.agents.invocation_context import InvocationContext
from google.adk.events import Event, EventActions
from google.adk.tools import google_search
from google.genai import types

from ..config import FAST_MODEL, SMART_MODEL
from ..schemas import ResearchFindings, ValidationResult


def describe_company(company: dict) -> str:
    """Render a company dict as plain lines. Braces are stripped so ADK's state
    templating never mistakes company text for a placeholder."""
    lines = [f"- {k.replace('_', ' ')}: {v}" for k, v in company.items()]
    return "\n".join(lines).replace("{", "(").replace("}", ")")


def fill(template: str, **values: str) -> str:
    for key, value in values.items():
        template = template.replace(f"%({key})s", value)
    return template


class FanOutResearchAgent(BaseAgent):
    """Builds and runs one research pipeline per company found in `source_key`."""

    source_key: str
    list_field: str
    prefix: str
    validator_instruction: str
    researcher_instruction: str
    formatter_instruction: str

    model_config: ClassVar = {"arbitrary_types_allowed": True}

    def _pipelines(self, companies: list[dict]) -> list[SequentialAgent]:
        pipelines = []
        for i, company in enumerate(companies):
            text = describe_company(company)
            notes_key = f"{self.prefix}_notes_{i}"
            pipelines.append(
                SequentialAgent(
                    name=f"{self.prefix}_pipeline_{i}",
                    sub_agents=[
                        LlmAgent(
                            name=f"{self.prefix}_validator_{i}",
                            model=FAST_MODEL,
                            instruction=fill(self.validator_instruction, company=text),
                            output_schema=ValidationResult,
                            output_key=f"{self.prefix}_validation_{i}",
                            include_contents="none",
                        ),
                        LlmAgent(
                            name=f"{self.prefix}_researcher_{i}",
                            model=SMART_MODEL,
                            instruction=fill(self.researcher_instruction, company=text),
                            tools=[google_search],
                            output_key=notes_key,
                            include_contents="none",
                        ),
                        LlmAgent(
                            name=f"{self.prefix}_formatter_{i}",
                            model=FAST_MODEL,
                            instruction=fill(self.formatter_instruction, notes_key=notes_key),
                            output_schema=ResearchFindings,
                            output_key=f"{self.prefix}_findings_{i}",
                            include_contents="none",
                        ),
                    ],
                )
            )
        return pipelines

    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        found = ctx.session.state.get(self.source_key) or {}
        companies = found.get(self.list_field, [])
        if not companies:
            yield Event(
                author=self.name,
                content=types.Content(parts=[types.Part(text="No companies to research.")]),
            )
            return

        parallel = ParallelAgent(name=f"{self.prefix}_parallel", sub_agents=self._pipelines(companies))
        async for event in parallel.run_async(ctx):
            yield event


class ConsolidateFindingsAgent(BaseAgent):
    """Joins the per-company validation and findings into one block of text for the
    synthesizer. Written as a state_delta event so it survives AgentTool boundaries."""

    source_key: str
    list_field: str
    prefix: str
    output_key: str
    drop_invalid: bool = False

    async def _run_async_impl(self, ctx: InvocationContext) -> AsyncGenerator[Event, None]:
        state = ctx.session.state
        companies = (state.get(self.source_key) or {}).get(self.list_field, [])
        blocks, kept = [], 0
        for i, company in enumerate(companies):
            validation = state.get(f"{self.prefix}_validation_{i}") or {}
            findings = state.get(f"{self.prefix}_findings_{i}") or {}
            valid = bool(validation.get("is_valid"))
            if self.drop_invalid and not valid:
                continue
            kept += 1
            blocks.append(
                "\n".join(
                    [
                        f"--- {company.get('company_name', f'Company {i + 1}')} ---",
                        f"Validation: {'VALID' if valid else 'INVALID'} ({validation.get('reasoning', 'n/a')})",
                        f"Signals: {', '.join(findings.get('signals', [])) or 'none found'}",
                        f"Summary: {findings.get('summary', 'n/a')}",
                        "Sources: " + ", ".join(findings.get("sources", [])),
                    ]
                )
            )
        dropped = len(companies) - kept
        text = "\n\n".join(blocks) or "No findings."
        if self.drop_invalid:
            text += f"\n\n({dropped} candidate(s) dropped after validation.)"
        yield Event(
            author=self.name,
            content=types.Content(parts=[types.Part(text=f"Consolidated {kept} of {len(companies)} companies.")]),
            actions=EventActions(state_delta={self.output_key: text}),
        )
