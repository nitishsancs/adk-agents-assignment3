"""Structured outputs passed between the research stages."""

from typing import Literal, Optional

from pydantic import BaseModel, Field


class IntentExtractionResult(BaseModel):
    country: Optional[str] = Field(default=None, description="Target country, e.g. 'Thailand'.")
    industry: Optional[str] = Field(default=None, description="Target industry, e.g. 'fintech'.")
    intent: Literal["find_leads", "find_patterns", "general_chat"] = Field(
        description="What the user is asking for."
    )
    reasoning: str = Field(description="One sentence explaining the extraction.")


class Company(BaseModel):
    company_name: str
    country_of_origin: str = Field(description="Where the company is headquartered.")
    investment_type: str = Field(description="New office, acquisition, partnership, licence, etc.")
    investment_date: str = Field(description="Approximate date, e.g. '2025-Q2'.")
    source_url: str = Field(description="Article or press release that reports the investment.")
    business_description: str = Field(description="One sentence on what the company does.")


class CompanyFinderOutput(BaseModel):
    companies_found: list[Company]


class ValidationResult(BaseModel):
    company_name: str
    is_valid: bool = Field(description="True if the company is foreign and the investment is recent.")
    reasoning: str


class ResearchFindings(BaseModel):
    summary: str = Field(description="The signals found, with dates where known.")
    signals: list[str] = Field(description="Short labels, one per signal.")
    sources: list[str] = Field(description="URLs backing the findings.")


class Lead(BaseModel):
    company_name: str
    country_of_origin: str
    business_description: str
    why_now: str = Field(description="The current signal that makes this company a lead.")


class LeadFinderOutput(BaseModel):
    potential_leads: list[Lead]
