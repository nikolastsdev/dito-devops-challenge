#!/usr/bin/env bash
# Bootstrap staging/production — use --print para só ver os comandos
#
#   ./scripts/bootstrap-gcp-projects.sh --print staging   # copiar/colar no terminal
#   ./scripts/bootstrap-gcp-projects.sh staging           # executa passo a passo

set -euo pipefail

SCOPE="${1:-staging}"
if [[ "$1" == "--print" ]]; then
  SCOPE="${2:-staging}"
  PRINT_ONLY=1
else
  PRINT_ONLY=0
fi

PROJECT="${STAGING_PROJECT:-dito-staging}"
BILLING="${GCP_BILLING_ACCOUNT_ID:-01817D-297FE7-229CDF}"
REGION="${GCP_REGION:-southamerica-east1}"

if [[ "$SCOPE" == "production" ]]; then
  PROJECT="${PRODUCTION_PROJECT:-dito-production}"
fi

APIS=(
  compute.googleapis.com
  container.googleapis.com
  sqladmin.googleapis.com
  secretmanager.googleapis.com
  artifactregistry.googleapis.com
  servicenetworking.googleapis.com
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  iamcredentials.googleapis.com
  sts.googleapis.com
  billingbudgets.googleapis.com
  monitoring.googleapis.com
)

if [[ "$PRINT_ONLY" == "1" ]]; then
  cat <<EOF
# === Bootstrap $SCOPE — cole no terminal ===

export PROJECT=$PROJECT
export BILLING=$BILLING
export REGION=$REGION

gcloud config set project \$PROJECT
gcloud billing projects describe \$PROJECT

# APIs (uma por vez — demora ~1-2 min cada lote)
$(for api in "${APIS[@]}"; do echo "gcloud services enable $api"; done)

# Bucket Terraform state
gsutil ls -b gs://\${PROJECT}-tfstate || gsutil mb -l \$REGION gs://\${PROJECT}-tfstate
gsutil versioning set on gs://\${PROJECT}-tfstate

# Credenciais para Terraform (abre browser)
gcloud auth application-default login

# Terraform
cd iac
source ../.env.terraform.local
terraform init -backend-config=backends/${SCOPE}.gcs.tfbackend
terraform plan -var-file=environments/${SCOPE}.tfvars
terraform apply -var-file=environments/${SCOPE}.tfvars

EOF
  exit 0
fi

echo "==> Bootstrap $SCOPE | project=$PROJECT"
gcloud config set project "$PROJECT"
gcloud billing projects link "$PROJECT" --billing-account="$BILLING" 2>/dev/null || true

for api in "${APIS[@]}"; do
  echo "  enable $api ..."
  gcloud services enable "$api"
done

BUCKET="${PROJECT}-tfstate"
if gsutil ls -b "gs://${BUCKET}" &>/dev/null; then
  echo "  bucket gs://${BUCKET} ok"
else
  gsutil mb -l "$REGION" "gs://${BUCKET}"
  gsutil versioning set on "gs://${BUCKET}"
  echo "  bucket gs://${BUCKET} criado"
fi

echo ""
echo "Pronto. Próximo:"
echo "  gcloud auth application-default login"
echo "  cd iac && terraform init -backend-config=backends/${SCOPE}.gcs.tfbackend"
