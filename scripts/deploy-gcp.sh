#!/bin/bash
# Deploy the chatbot to GCP (Cloud Run + Cloud Storage + Firebase Hosting + Vertex AI).
#
# Usage:
#   GCP_PROJECT_ID=my-project FIREBASE_PROJECT_ID=my-project \
#     bash scripts/deploy-gcp.sh dev
#
# Required environment variables:
#   GCP_PROJECT_ID       - target GCP project ID
#   FIREBASE_PROJECT_ID  - Firebase project ID hosting the static frontend
# Optional:
#   GCP_REGION           - default us-central1
#   PROJECT_NAME         - default customer-support-chatbot
#   TF_STATE_BUCKET      - default ${GCP_PROJECT_ID}-terraform-state
#
# This script does NOT touch any AWS resources. The AWS deploy path
# (scripts/deploy.sh) remains fully functional and unchanged.

set -euo pipefail

ENVIRONMENT=${1:-dev}                # dev | test | prod
PROJECT_NAME=${PROJECT_NAME:-customer-support}
GCP_REGION=${GCP_REGION:-europe-west1}

if [ -z "${GCP_PROJECT_ID:-}" ]; then
  echo "ERROR: GCP_PROJECT_ID env var is required" >&2
  exit 1
fi
if [ -z "${FIREBASE_PROJECT_ID:-}" ]; then
  echo "ERROR: FIREBASE_PROJECT_ID env var is required" >&2
  exit 1
fi

TF_STATE_BUCKET=${TF_STATE_BUCKET:-"${GCP_PROJECT_ID}-terraform-state"}
NAME_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"
REPO="${NAME_PREFIX}"
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)
IMAGE="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT_ID}/${REPO}/api:${IMAGE_TAG}"

echo "Deploying ${NAME_PREFIX} to GCP project ${GCP_PROJECT_ID} (${GCP_REGION})..."
cd "$(dirname "$0")/.."

# 0. Make sure the Terraform state bucket exists. This is the GCP analog of the
#    S3 + DynamoDB backend that scripts/deploy.sh sets up implicitly.
if ! gcloud storage buckets describe "gs://${TF_STATE_BUCKET}" --project="${GCP_PROJECT_ID}" >/dev/null 2>&1; then
  echo "Creating Terraform state bucket gs://${TF_STATE_BUCKET}..."
  gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${GCP_REGION}" \
    --uniform-bucket-level-access
fi

# 1. Make sure the Artifact Registry repo exists before the first build (the
#    Terraform run below also declares it, but Cloud Build needs it to push).
gcloud services enable artifactregistry.googleapis.com cloudbuild.googleapis.com run.googleapis.com aiplatform.googleapis.com storage.googleapis.com \
  --project="${GCP_PROJECT_ID}"

if ! gcloud artifacts repositories describe "${REPO}" \
      --project="${GCP_PROJECT_ID}" \
      --location="${GCP_REGION}" >/dev/null 2>&1; then
  echo "Creating Artifact Registry repo ${REPO}..."
  gcloud artifacts repositories create "${REPO}" \
    --project="${GCP_PROJECT_ID}" \
    --location="${GCP_REGION}" \
    --repository-format=docker \
    --description="Container images for ${NAME_PREFIX}"
fi

# 2. Build + push the container with Cloud Build (no local Docker needed).
echo "Building container ${IMAGE}..."
gcloud builds submit backend \
  --project="${GCP_PROJECT_ID}" \
  --region="${GCP_REGION}" \
  --tag="${IMAGE}"

# 3. Apply Terraform — provisions GCS bucket, service account, Cloud Run service.
#    All terraform commands use -chdir= so we never depend on cwd.
echo "Applying Terraform..."
terraform -chdir=terraform/gcp init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=${ENVIRONMENT}/${PROJECT_NAME}"

if [ "${ENVIRONMENT}" = "prod" ]; then
  TFVARS_FILE="prod.tfvars"
else
  TFVARS_FILE="dev.tfvars"
fi

terraform -chdir=terraform/gcp apply \
  -var-file="${TFVARS_FILE}" \
  -var="project_id=${GCP_PROJECT_ID}" \
  -var="environment=${ENVIRONMENT}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="region=${GCP_REGION}" \
  -var="image=${IMAGE}" \
  -auto-approve

# Capture cloud_run_url with a hard guard. `set -e` does NOT propagate failures
# from $() assignments in older bash, so we explicitly check the value AND the
# exit code via a temp file. This is what crashed the previous run.
TF_OUTPUT_TMP=$(mktemp)
trap 'rm -f "${TF_OUTPUT_TMP}"' EXIT

if ! terraform -chdir=terraform/gcp output -raw cloud_run_url > "${TF_OUTPUT_TMP}" 2>/dev/null; then
  echo "ERROR: 'terraform output -raw cloud_run_url' failed. Has terraform apply completed?" >&2
  echo "Try: terraform -chdir=terraform/gcp output" >&2
  exit 1
fi

CLOUD_RUN_URL=$(cat "${TF_OUTPUT_TMP}")
if [ -z "${CLOUD_RUN_URL}" ]; then
  echo "ERROR: cloud_run_url terraform output is empty" >&2
  exit 1
fi

echo "Cloud Run URL : ${CLOUD_RUN_URL}"

# 4. Build the Next.js static export pointed at the Cloud Run URL.
echo "Building frontend with NEXT_PUBLIC_API_URL=${CLOUD_RUN_URL}..."
echo "NEXT_PUBLIC_API_URL=${CLOUD_RUN_URL}" > frontend/.env.production
(cd frontend && npm install && npm run build)

# 5. Deploy the static export to Firebase Hosting.
echo "Deploying frontend to Firebase Hosting..."
(cd frontend && npx --yes firebase-tools deploy \
  --only hosting \
  --project="${FIREBASE_PROJECT_ID}" \
  --non-interactive)

echo ""
echo "Deployment complete."
echo "Cloud Run API : ${CLOUD_RUN_URL}"
echo "Firebase host : https://${FIREBASE_PROJECT_ID}.web.app"
