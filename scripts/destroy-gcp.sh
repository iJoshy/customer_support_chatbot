#!/bin/bash
# Tear down the GCP deployment for a single environment. The AWS deploy
# path (scripts/destroy.sh) is unaffected.
#
# Usage:
#   GCP_PROJECT_ID=my-project bash scripts/destroy-gcp.sh dev

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "ERROR: environment is required (dev | test | prod)" >&2
  exit 1
fi

ENVIRONMENT=$1
PROJECT_NAME=${PROJECT_NAME:-customer-support-chatbot}
GCP_REGION=${GCP_REGION:-us-central1}

if [ -z "${GCP_PROJECT_ID:-}" ]; then
  echo "ERROR: GCP_PROJECT_ID env var is required" >&2
  exit 1
fi

TF_STATE_BUCKET=${TF_STATE_BUCKET:-"${GCP_PROJECT_ID}-terraform-state"}
NAME_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"
MEMORY_BUCKET="${NAME_PREFIX}-memory-${GCP_PROJECT_ID}"

echo "Destroying ${NAME_PREFIX} in GCP project ${GCP_PROJECT_ID}..."
cd "$(dirname "$0")/../terraform/gcp"

terraform init -input=false -reconfigure \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=${ENVIRONMENT}/${PROJECT_NAME}"

# Empty the memory bucket so the bucket resource can be removed.
if gcloud storage buckets describe "gs://${MEMORY_BUCKET}" --project="${GCP_PROJECT_ID}" >/dev/null 2>&1; then
  echo "Emptying gs://${MEMORY_BUCKET}..."
  gcloud storage rm --recursive "gs://${MEMORY_BUCKET}/**" --project="${GCP_PROJECT_ID}" 2>/dev/null || true
fi

if [ "${ENVIRONMENT}" = "prod" ]; then
  TFVARS_FILE="prod.tfvars"
else
  TFVARS_FILE="dev.tfvars"
fi

terraform destroy \
  -var-file="${TFVARS_FILE}" \
  -var="project_id=${GCP_PROJECT_ID}" \
  -var="environment=${ENVIRONMENT}" \
  -var="project_name=${PROJECT_NAME}" \
  -var="region=${GCP_REGION}" \
  -var="image=placeholder/placeholder:placeholder" \
  -auto-approve

echo "Infrastructure for ${ENVIRONMENT} has been destroyed."
