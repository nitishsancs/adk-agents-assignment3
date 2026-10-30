# Postgres 17 with pgvector (semantic search) and PostGIS (store locations).
# Starts from the multi-arch pgvector image so it builds on both amd64 and arm64.
FROM pgvector/pgvector:pg17
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-17-postgis-3 \
 && rm -rf /var/lib/apt/lists/*
