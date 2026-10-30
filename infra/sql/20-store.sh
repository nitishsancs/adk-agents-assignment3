#!/bin/bash
# Part (e): load the sanitized sports store dump into storedb, then give the seeded
# customers sign-in emails (the original dump leaves them NULL for Google Sign-In).
set -euo pipefail
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname storedb -f /docker-entrypoint-initdb.d/store/store.sql
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname storedb <<'SQL'
UPDATE users SET email = lower(first_name) || '@example.com' WHERE email IS NULL;
UPDATE users SET city = trim(city), postal_code = trim(postal_code);
UPDATE stores SET postal_code = trim(postal_code), country = trim(country);
SQL
