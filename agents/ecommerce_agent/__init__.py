from pathlib import Path

from dotenv import load_dotenv

# The repo-level .env holds the model backend settings shared by all five agents.
load_dotenv(Path(__file__).resolve().parents[2] / ".env")

from . import agent  # noqa: E402,F401
