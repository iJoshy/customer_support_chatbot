# Meridian Electronics Customer Support Chatbot

A production-shaped hackathon prototype for Meridian Electronics support. The app connects an LLM-powered chat experience to Meridian's internal order MCP server so customers can search products, check inventory, authenticate with email/PIN, view order history, and place orders.

The backend is **dual-cloud**: the same `backend/server.py` runs on **AWS Lambda + Bedrock + S3** or on **GCP Cloud Run + Vertex AI Gemini + Cloud Storage**, picked at startup by two env vars. Neither cloud is a "migration target" of the other — both are first-class deploy paths.

## What It Does

- Discovers MCP tools from `https://order-mcp-74afyau24q-uc.a.run.app/mcp`
- Talks to either AWS Bedrock Nova or Vertex AI Gemini as the LLM backend
- Calls MCP tools for product, customer, and order workflows
- Preserves session memory and authenticated customer state
- Guards protected tools so order history and order creation require customer verification
- Provides a Next.js chat UI with demo prompts for the final presentation

## MCP Tools

The backend discovers these tools at runtime:

- `list_products`
- `get_product`
- `search_products`
- `get_customer`
- `verify_customer_pin`
- `list_orders`
- `get_order`
- `create_order`

## Provider switching

Two environment variables select the backend implementation. Everything else stays the same.

| Variable        | Values                       | Default   |
|-----------------|------------------------------|-----------|
| `LLM_PROVIDER`  | `bedrock` \| `vertex`        | `bedrock` |
| `SESSION_STORE` | `local` \| `s3` \| `gcs`     | `local` (or `s3` if legacy `USE_S3=true`) |

Common combinations:

- **Local dev (default)** — `LLM_PROVIDER=bedrock` (or `vertex`) + `SESSION_STORE=local`. Uses `MEMORY_DIR` for sessions, no cloud storage required.
- **AWS deploy** (set automatically by [terraform/main.tf](terraform/main.tf)) — `LLM_PROVIDER=bedrock` + `SESSION_STORE=s3`.
- **GCP deploy** (set automatically by [terraform/gcp/main.tf](terraform/gcp/main.tf)) — `LLM_PROVIDER=vertex` + `SESSION_STORE=gcs`.

The two abstractions are independent, so mix-and-match works (e.g. `LLM_PROVIDER=vertex` + `SESSION_STORE=s3`) for cross-cloud debugging without code changes.

## Local Development

Backend:

```bash
cd backend
uv run server.py
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:3000`.

## Environment

Copy `.env.example` to `.env` and edit the relevant section. The full set of variables is documented in [.env.example](.env.example).

## Architecture

```text
                          Browser / Next.js
                                |
                                | POST /chat
                                v
                          FastAPI backend (server.py)
                                |
              +-----------------+-----------------+
              |                 |                 |
              v                 v                 v
        chat_provider     run_mcp_tool      session_store
        (llm.py)          (server.py)       (storage.py)
              |                 |                 |
   +----------+----------+      |      +----------+----------+
   |                     |      |      |                     |
BedrockProvider   VertexProvider |   S3Store  GCSStore  LocalFileStore
   |                     |      |      |          |
   v                     v      v      v          v
AWS Bedrock        Vertex AI    MCP    AWS S3   Google Cloud
(Nova)             (Gemini)     server          Storage
                                (Cloud Run)
```

The `chat_provider` and `session_store` instances are constructed once at import time from `get_chat_provider()` and `get_session_store()` based on env vars. `server.py` itself imports neither `boto3` nor `google.cloud` directly.

## Deploying

### To AWS (Lambda + API Gateway + S3 + CloudFront + Bedrock)

```bash
bash scripts/deploy.sh dev
```

Builds the Lambda zip via [backend/deploy.py](backend/deploy.py), applies [terraform/main.tf](terraform/main.tf), and syncs the Next.js export to the S3 website bucket behind CloudFront. Tear down with `bash scripts/destroy.sh dev`.

### To GCP (Cloud Run + Cloud Storage + Firebase Hosting + Vertex AI)

```bash
export GCP_PROJECT_ID=my-gcp-project
export FIREBASE_PROJECT_ID=my-firebase-project
bash scripts/deploy-gcp.sh dev
```

Builds the container with Cloud Build using [backend/Dockerfile](backend/Dockerfile), applies [terraform/gcp/main.tf](terraform/gcp/main.tf) (provisions Artifact Registry, GCS memory bucket, service account, Cloud Run service with `LLM_PROVIDER=vertex` + `SESSION_STORE=gcs` baked in), and deploys the Next.js static export to Firebase Hosting. Tear down with `bash scripts/destroy-gcp.sh dev`.

Prereqs (one time): `gcloud auth login`, `gcloud auth application-default login`, `gcloud config set project ${GCP_PROJECT_ID}`, `npx firebase-tools login`.

## Useful Demo Script

1. Ask: `I need a 27-inch monitor. What do you have in stock?`
2. Authenticate: `My email is donaldgarcia@example.net and my PIN is 7912.`
3. Ask: `Show my recent orders.`
4. Ask: `I want to order 2 units of MON-0054.`
5. Confirm only after the bot summarizes price, stock, and total.

## Verification Done

- 16 backend unit tests in `backend/tests/test_server.py` cover guardrails, MCP tool guards, session storage, content sanitization, and the chat endpoint, on both providers.
- Python syntax check passes for backend files.
- Next.js production build passes.
- `/health` works locally on either provider.
- `/tools` discovers all MCP tools.
- Product search chat flow works through both Bedrock and Vertex AI Gemini.
- Authenticated order history flow works through both Bedrock and Vertex AI Gemini.
