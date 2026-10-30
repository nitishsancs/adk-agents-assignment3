"""The two research phases: learn patterns from past investors, then predict new leads."""

from google.adk.agents import LlmAgent, SequentialAgent

from .. import prompts
from ..config import FAST_MODEL, SMART_MODEL
from ..websearch import research_tools
from ..schemas import CompanyFinderOutput, IntentExtractionResult, LeadFinderOutput
from .fanout import ConsolidateFindingsAgent, FanOutResearchAgent

intent_extractor_agent = LlmAgent(
    name="intent_extractor_agent",
    model=FAST_MODEL,
    description="Extracts the target country and industry from the user's request.",
    instruction=prompts.INTENT_EXTRACTOR_INSTRUCTION,
    output_schema=IntentExtractionResult,
    output_key="intent_extraction_result",
)

# ---- Phase 1: pattern discovery (learning from companies that already invested) ----

pattern_discovery_agent = SequentialAgent(
    name="pattern_discovery_agent",
    description=(
        "Finds k foreign companies that recently invested in the target market, researches "
        "what each did before investing, and synthesizes the common pre-investment patterns."
    ),
    sub_agents=[
        LlmAgent(
            name="company_finder",
            model=SMART_MODEL,
            instruction=prompts.COMPANY_FINDER_INSTRUCTION,
            tools=research_tools(),
            output_key="company_finder_output",
        ),
        LlmAgent(
            name="company_formatter",
            model=FAST_MODEL,
            instruction=prompts.FORMATTER_INSTRUCTION,
            output_schema=CompanyFinderOutput,
            output_key="companies_found",
            include_contents="none",
        ),
        FanOutResearchAgent(
            name="company_research_fanout",
            source_key="companies_found",
            list_field="companies_found",
            prefix="company",
            validator_instruction=prompts.VALIDATOR_INSTRUCTION,
            researcher_instruction=prompts.SIGNAL_SEARCHER_INSTRUCTION,
            formatter_instruction=prompts.RESEARCH_FORMATTER_INSTRUCTION,
        ),
        ConsolidateFindingsAgent(
            name="consolidate_company_findings",
            source_key="companies_found",
            list_field="companies_found",
            prefix="company",
            output_key="all_research_findings",
        ),
        LlmAgent(
            name="pattern_synthesizer",
            model=SMART_MODEL,
            instruction=prompts.PATTERN_SYNTHESIZER_INSTRUCTION,
            output_key="discovered_patterns",
            include_contents="none",
        ),
    ],
)

# ---- Phase 2: lead generation (finding companies showing those patterns today) ----

lead_generation_agent = SequentialAgent(
    name="lead_generation_agent",
    description=(
        "Uses the discovered patterns to find m companies showing the same signals today, "
        "validates and researches each in parallel, and compiles a ranked lead report."
    ),
    sub_agents=[
        LlmAgent(
            name="lead_finder",
            model=SMART_MODEL,
            instruction=prompts.LEAD_FINDER_INSTRUCTION,
            tools=research_tools(),
            output_key="lead_finder_output",
        ),
        LlmAgent(
            name="lead_formatter",
            model=FAST_MODEL,
            instruction=prompts.LEAD_FORMATTER_INSTRUCTION,
            output_schema=LeadFinderOutput,
            output_key="leads_found",
            include_contents="none",
        ),
        FanOutResearchAgent(
            name="lead_research_fanout",
            source_key="leads_found",
            list_field="potential_leads",
            prefix="lead",
            validator_instruction=prompts.LEAD_VALIDATOR_INSTRUCTION,
            researcher_instruction=prompts.LEAD_ANALYZER_INSTRUCTION,
            formatter_instruction=prompts.RESEARCH_FORMATTER_INSTRUCTION,
        ),
        ConsolidateFindingsAgent(
            name="consolidate_lead_findings",
            source_key="leads_found",
            list_field="potential_leads",
            prefix="lead",
            output_key="all_lead_findings",
            drop_invalid=True,
        ),
        LlmAgent(
            name="report_compiler",
            model=SMART_MODEL,
            instruction=prompts.REPORT_COMPILER_INSTRUCTION,
            output_key="lead_report",
            include_contents="none",
        ),
    ],
)
