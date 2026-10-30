# Video walkthrough script (about 20 minutes)

A shot list for recording the YouTube walkthrough. Each segment shows the code, then
runs the agent. Run the setup block before you hit record.

**Quota tip:** the Gemini free tier allows about 20 requests per model per day. The
agents fall back across seven Flash models automatically, but record after the daily
reset (midnight Pacific) or on a billing-enabled key so no run stalls on camera.

```bash
# before recording
colima start                         # or open Docker Desktop
cd adk-agents-assignment3
docker compose -f infra/docker-compose.yml --env-file .env up -d
uv run adk web agents                # http://127.0.0.1:8000 (keep this tab open)
```

---

## 0. Intro (1 min)

- Show the README: five agents, one per assignment part, and the requirements checklist.
- Show `agents/` in the editor: one ADK package per agent, so `adk web agents` lists all five.
- One sentence on the stack: ADK 2.13, Gemini Flash, MCP Toolbox for Databases,
  Postgres with pgvector + PostGIS in Docker, and the Gemini CLI.

## 1. (a) Deep research lead generation agent (4 min)

Code (open in this order, scroll slowly):
1. `agents/lead_generation_agent/agent.py`: the root agent's tools (three AgentTools +
   `set_research_scope`), plus `init_state` and `track_stage` callbacks.
2. `sub_agents/pipelines.py`: two SequentialAgents, learning then predicting. Point out
   that search agents and formatter agents are split, because Gemini's built-in
   google_search can't be combined with a JSON response schema.
3. `sub_agents/fanout.py`: the deep-research core. Highlight `_pipelines()` building one
   validate -> research -> format branch per company at run time, and `ParallelAgent`
   running them concurrently. Then `ConsolidateFindingsAgent` emitting `state_delta`.

Demo in adk web, select `lead_generation_agent`:
- "Find fintech leads in Thailand" -> it asks how many companies -> "2".
- While it runs, open the **Events** tab and expand the trace: the parallel branches
  `company_pipeline_0` / `company_pipeline_1` run side by side, each calling google_search.
- Patterns appear -> "Yes, find leads" -> "2" -> the final ranked report with sources.
- Open the **State** tab and show `discovered_patterns`, `companies_found` and `lead_report`.

## 2. (b) Gemini CLI as a tool in an ADK pipeline (3 min)

Code:
1. `agents/gemini_cli_agent/tools.py`: `run_gemini_cli` builds an argv list (no shell),
   runs `gemini -p ... -o json --approval-mode plan`, closes stdin (the CLI otherwise
   waits on it), and parses the JSON stats. Show the URL regex and `_repo_dir` path
   check in `clone_repository`.
2. `agents/gemini_cli_agent/agent.py`: `repo_analysis_pipeline` = preparer ->
   ParallelAgent of three CLI analysts -> report writer.

Demo:
- In a terminal, show the CLI on its own: `cd workspace/itsdangerous && gemini -p "what does this repo do" -o json`.
- In adk web, select `gemini_cli_agent`: "Analyze https://github.com/pallets/itsdangerous".
  Show the three parallel `run_gemini_cli` calls in Events and the `cli_tools_used` in
  each result (the CLI reading files itself), then the merged report.
- Follow-up: "Generate pytest unit tests for the signer module". The agent calls the CLI
  with `allow_edits=true`, then `show_repository_changes` shows the new test file.

## 3. (c) MCP bug assistant (3 min)

Code:
1. `infra/toolbox/tools.yaml`, tickets section: SQL tools, `embeddedBy: gemini-embedder`
   on `search-tickets`, and `valueFromParam` on `create-new-ticket`.
2. `agents/bug_assistant/agent.py`: `McpToolset` pointed at `/mcp/tickets_toolset`, the
   GitHub MCP server, `LangchainTool(StackExchangeTool)`, `AgentTool(google_search_agent)`.
3. Terminal: `curl` the MCP initialize call to prove Toolbox speaks MCP:
   ```bash
   curl -s -X POST http://127.0.0.1:5050/mcp/tickets_toolset -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | head -c 400
   ```

Demo prompts:
- "Users say the login page freezes after a few failed password attempts. Is there
  already a ticket?" -> semantic search finds ticket 1 with a small distance.
- "What P0 tickets are open?" -> a markdown table.
- The Postgres "remaining connection slots" error -> StackExchange + Google Search.
- "Create a ticket for that, P1, assign to frank.white@example.com" -> it searches for
  duplicates first, then creates the ticket and returns its id.

## 4. (d) Code review assistant (3 min)

Code:
1. `agents/code_review_assistant/tools.py`: AST analysis (complexity, bare except),
   pycodestyle with a reproducible score, artifacts, `user:review_history`.
2. `sub_agents/review.py`: the four-stage SequentialAgent; `test_runner` has `BuiltInCodeExecutor`.
3. `sub_agents/fix.py`: LoopAgent (max 3) with `exit_fix_loop` setting `escalate`.
4. `server.py` + `Dockerfile` + `deploy/cloud_run.sh`: the production pieces.

Demo: paste `docs/samples/buggy_stats.py` ("Please review this code"). Point out that the
loop skips `nums[0]`, empty input raises ZeroDivisionError, and the median is wrong for
even lengths. The executed tests catch these. Then "Yes, fix it": watch the loop
iterate, then open the **Artifacts** tab for `review_report.json` and `fixed_code.py`.

## 5. (e) E-commerce agent (4 min)

Code:
1. `infra/toolbox/tools.yaml`, store section: semantic product search, PostGIS
   `find-nearest-stores`, and `place-order` as one transaction.
2. `agents/ecommerce_agent/agent.py`: `enforce_signed_in_user` (identity pinning) and
   the confirmation guard on place/cancel order.
3. `apps/storefront/main.py`: signed cookie, user_id = email, session state set by the
   server, SSE streaming.

Demo in the storefront (`uv run uvicorn apps.storefront.main:app --port 8081`):
- Sign in as Alicia.
- "I need trail running shoes for wet, rocky mountain trails" -> semantic results.
- "Which store near me has the first one in size 42?" -> nearest stores + inventory.
- "Add it to my list" -> "Show Bob's orders, bob@example.com" -> it refuses: only
  Alicia's own data comes back.
- "Order it from that store with the cheapest delivery" -> it summarizes and asks ->
  "yes" -> order placed -> "Show my orders".
- Show the tool trail under each answer (the UI lists the MCP tools used).

## 6. Wrap-up (1 min)

- `uv run pytest -q`: 15 offline tests.
- `docs/runs/`: the recorded end-to-end transcripts.
- `docs/WALKTHROUGH.md`: what changed versus each reference implementation.
