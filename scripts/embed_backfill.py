"""Fill the vector(768) columns that Toolbox searches against.

    uv run python scripts/embed_backfill.py

Embeds tickets.description and products (name + brand + category + description) with
gemini-embedding-001 at 768 dimensions, the same model and size Toolbox uses for
queries via `embeddedBy`, so query and row vectors live in one space.
Only rows with a NULL embedding are touched, so it is safe to re-run.
"""

import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from google import genai
from google.genai import types

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

DSN = "host={h} port=5432 user={u} password={p} dbname={{db}}".format(
    h=os.getenv("DB_HOST", "127.0.0.1"), u=os.getenv("DB_USER", "postgres"), p=os.getenv("DB_PASSWORD", "postgres")
)
TARGETS = {
    "ticketsdb": ("tickets", "ticket_id", "description"),
    "storedb": ("products", "product_id", "concat_ws('. ', name, brand, category, description)"),
}
client = genai.Client()


def embed(texts: list[str]) -> list[list[float]]:
    result = client.models.embed_content(
        model="gemini-embedding-001",
        contents=texts,
        config=types.EmbedContentConfig(output_dimensionality=768, task_type="RETRIEVAL_DOCUMENT"),
    )
    return [e.values for e in result.embeddings]


for db, (table, key, text_sql) in TARGETS.items():
    with psycopg.connect(DSN.format(db=db)) as conn:
        rows = conn.execute(f"SELECT {key}, {text_sql} FROM {table} WHERE embedding IS NULL ORDER BY {key}").fetchall()
        for start in range(0, len(rows), 50):
            batch = rows[start : start + 50]
            vectors = embed([text for _, text in batch])
            with conn.cursor() as cur:
                cur.executemany(
                    f"UPDATE {table} SET embedding = %s::vector WHERE {key} = %s",
                    [(str(vec), row_id) for (row_id, _), vec in zip(batch, vectors)],
                )
            conn.commit()
        total = conn.execute(f"SELECT count(*) FROM {table} WHERE embedding IS NOT NULL").fetchone()[0]
        print(f"{db}.{table}: embedded {len(rows)} new rows, {total} rows searchable")
