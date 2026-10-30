#!/usr/bin/env bash
# Deploy the stack to Google Cloud: Cloud SQL (Postgres + pgvector), MCP Toolbox,
# the agent API server and the storefront, all on Cloud Run.
#
#   PROJECT_ID=my-project REGION=us-central1 ./deploy/cloud_run.sh
#
# Needs: billing enabled, gcloud authenticated, GOOGLE_API_KEY exported (or switch the
# agents to Vertex AI by setting GOOGLE_GENAI_USE_VERTEXAI=TRUE below).
set -euo pipefail
: "${PROJECT_ID:?set PROJECT_ID}"; REGION="${REGION:-us-central1}"; : "${GOOGLE_API_KEY:?export GOOGLE_API_KEY}"
DB_INSTANCE="${DB_INSTANCE:-adk-agents-pg}"; DB_PASSWORD="${DB_PASSWORD:-$(openssl rand -hex 16)}"
REPO="${REGION}-docker.pkg.dev/${PROJECT_ID}/adk-agents"
gcloud config set project "$PROJECT_ID"

echo "== 1. APIs"
gcloud services enable run.googleapis.com sqladmin.googleapis.com secretmanager.googleapis.com \
  artifactregistry.googleapis.com cloudbuild.googleapis.com aiplatform.googleapis.com

echo "== 2. Cloud SQL Postgres 17 (pgvector is built in; PostGIS for store locations)"
gcloud sql instances describe "$DB_INSTANCE" >/dev/null 2>&1 || gcloud sql instances create "$DB_INSTANCE" \
  --database-version=POSTGRES_17 --tier=db-custom-1-3840 --region="$REGION" --edition=ENTERPRISE
gcloud sql users set-password postgres --instance="$DB_INSTANCE" --password="$DB_PASSWORD"
for db in ticketsdb storedb; do gcloud sql databases create "$db" --instance="$DB_INSTANCE" 2>/dev/null || true; done
echo "   Load schema + data with the Cloud SQL Auth Proxy, then run scripts/embed_backfill.py:"
echo "   psql -h 127.0.0.1 -U postgres -f infra/sql/10-tickets.sql; psql ... -d storedb -f infra/sql/store.sql"

echo "== 3. Secrets"
upsert_secret() { gcloud secrets describe "$1" >/dev/null 2>&1 || gcloud secrets create "$1" --replication-policy=automatic; printf '%s' "$2" | gcloud secrets versions add "$1" --data-file=-; }
upsert_secret google-api-key "$GOOGLE_API_KEY"
upsert_secret db-password "$DB_PASSWORD"
upsert_secret storefront-secret "$(openssl rand -hex 32)"
gcloud secrets describe toolbox-tools >/dev/null 2>&1 || gcloud secrets create toolbox-tools --replication-policy=automatic
gcloud secrets versions add toolbox-tools --data-file=infra/toolbox/tools.yaml

echo "== 4. Service account"
SA="adk-agents@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts describe "$SA" >/dev/null 2>&1 || gcloud iam service-accounts create adk-agents
for role in roles/cloudsql.client roles/secretmanager.secretAccessor roles/aiplatform.user; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:$SA" --role="$role" --condition=None >/dev/null
done
CONN="$(gcloud sql instances describe "$DB_INSTANCE" --format='value(connectionName)')"

echo "== 5. MCP Toolbox on Cloud Run (private: only the agents' service account may call it)"
gcloud run deploy toolbox --region="$REGION" --service-account="$SA" --no-allow-unauthenticated \
  --image=us-central1-docker.pkg.dev/database-toolbox/toolbox/toolbox:1.15.0 \
  --args="--tools-file=/config/tools.yaml,--address=0.0.0.0,--port=8080" \
  --set-secrets="/config/tools.yaml=toolbox-tools:latest,DB_PASSWORD=db-password:latest,GOOGLE_API_KEY=google-api-key:latest" \
  --set-env-vars="DB_HOST=/cloudsql/${CONN},DB_USER=postgres" --add-cloudsql-instances="$CONN"
TOOLBOX_URL="$(gcloud run services describe toolbox --region="$REGION" --format='value(status.url)')"

echo "== 6. Build images"
gcloud artifacts repositories describe adk-agents --location="$REGION" >/dev/null 2>&1 || \
  gcloud artifacts repositories create adk-agents --repository-format=docker --location="$REGION"
gcloud builds submit --tag "$REPO/agents:latest" .
gcloud builds submit --config=- . <<YAML
steps: [{name: gcr.io/cloud-builders/docker, args: [build, -f, apps/storefront/Dockerfile, -t, $REPO/storefront:latest, .]}]
images: [$REPO/storefront:latest]
YAML

COMMON_ENV="GOOGLE_GENAI_USE_VERTEXAI=FALSE,MCP_TOOLBOX_URL=${TOOLBOX_URL},DB_HOST=/cloudsql/${CONN},DB_USER=postgres"
echo "== 7. Agent API server (sessions in Cloud SQL, dev UI off)"
gcloud run deploy adk-agents --image="$REPO/agents:latest" --region="$REGION" --service-account="$SA" \
  --memory=2Gi --cpu=2 --timeout=900 --no-allow-unauthenticated --add-cloudsql-instances="$CONN" \
  --set-secrets="GOOGLE_API_KEY=google-api-key:latest,DB_PASSWORD=db-password:latest" \
  --set-env-vars="${COMMON_ENV},SERVE_WEB_UI=false,MAX_LLM_CALLS=150"

echo "== 8. Storefront (public)"
gcloud run deploy finn-storefront --image="$REPO/storefront:latest" --region="$REGION" --service-account="$SA" \
  --allow-unauthenticated --add-cloudsql-instances="$CONN" \
  --set-secrets="GOOGLE_API_KEY=google-api-key:latest,DB_PASSWORD=db-password:latest,STOREFRONT_SECRET=storefront-secret:latest" \
  --set-env-vars="${COMMON_ENV}"
echo "Done. Storefront: $(gcloud run services describe finn-storefront --region="$REGION" --format='value(status.url)')"
