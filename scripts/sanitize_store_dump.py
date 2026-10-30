"""Turn the AlloyDB dump from mtoscano84/sports-agent-adk-mcp-alloydb into plain Postgres.

    uv run python scripts/sanitize_store_dump.py <path/to/store_backup.sql> infra/sql/store.sql

- drops statements that reference AlloyDB-managed roles
- drops AlloyDB-only extensions (google_ml_integration, alloydb_scann, columnar engine,
  db advisor, hypopg) and the ScaNN index, adding an HNSW pgvector index instead
- blanks the product embeddings: they were made with text-embedding-005, while queries
  here are embedded by Toolbox with gemini-embedding-001, so they are recomputed by
  scripts/embed_backfill.py to keep both sides in the same vector space
"""

import re
import sys

ALLOYDB_ONLY = ("google_ml_integration", "alloydb_scann", "google_columnar_engine", "google_db_advisor", "hypopg")

src, dst = sys.argv[1], sys.argv[2]
out, in_products_copy = [], False
for line in open(src, encoding="utf-8"):
    if any(ext in line for ext in ALLOYDB_ONLY) and line.startswith(("CREATE EXTENSION", "COMMENT ON EXTENSION")):
        continue
    if re.search(r"\balloydb\w*", line) and not line.startswith("--"):
        continue  # ownership/grants for AlloyDB-managed roles that do not exist in plain Postgres
    if "USING scann" in line:
        out.append("CREATE INDEX idx_products_embedding_hnsw ON public.products USING hnsw (embedding public.vector_cosine_ops);\n")
        continue
    if line.startswith("COPY public.products (") and line.rstrip().endswith("embedding) FROM stdin;"):
        in_products_copy = True
        out.append(line)
        continue
    if in_products_copy:
        if line.startswith("\\."):
            in_products_copy = False
        else:
            cols = line.rstrip("\n").split("\t")
            cols[-1] = "\\N"
            line = "\t".join(cols) + "\n"
    out.append(line)

text = "".join(out)
leftover = [e for e in ALLOYDB_ONLY if re.search(rf"\b{e}\b", text)]
open(dst, "w", encoding="utf-8").write(text)
print(f"wrote {dst}; AlloyDB references left (comments only expected): {leftover}")
