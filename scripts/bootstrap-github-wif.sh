#!/usr/bin/env bash
# Bootstrap Workload Identity Federation (1x por ambiente) — ANTES do primeiro apply na pipeline
#
# O PDF pede Terraform via CI/CD. A pipeline precisa de WIF para autenticar,
# mas o WIF também é criado pelo Terraform → este script quebra o ciclo via gcloud.
#
# Uso:
#   ./scripts/bootstrap-github-wif.sh staging
#   ./scripts/configure-github-secrets.sh staging --from-gcloud

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?staging | production}"

case "$ENV" in
  staging)    PROJECT="${STAGING_PROJECT:-dito-staging}" ;;
  production) PROJECT="${PRODUCTION_PROJECT:-dito-production}" ;;
  *) echo "Ambiente inválido: $ENV"; exit 1 ;;
esac

ROOT="$(repo_root)"
TFVARS="$ROOT/iac/environments/${ENV}.tfvars"
GITHUB_OWNER="$(tfvars_value "$TFVARS" github_owner)"
GITHUB_REPO="$(tfvars_value "$TFVARS" github_repo)"

POOL_ID="dito-github-pool"
PROVIDER_ID="github-provider"
SA_ID="dito-ci"
SA_EMAIL="${SA_ID}@${PROJECT}.iam.gserviceaccount.com"

require_gcloud
gcloud config set project "$PROJECT"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
REPO_PRINCIPAL="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_OWNER}/${GITHUB_REPO}"

echo "==> WIF bootstrap | env=$ENV project=$PROJECT"

# Pool
if gcloud iam workload-identity-pools describe "$POOL_ID" \
  --project="$PROJECT" --location=global &>/dev/null; then
  echo "  pool $POOL_ID já existe"
else
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --project="$PROJECT" \
    --location=global \
    --display-name="GitHub Actions"
  echo "  pool $POOL_ID criado"
fi

# Provider OIDC
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
  --project="$PROJECT" --location=global \
  --workload-identity-pool="$POOL_ID" &>/dev/null; then
  echo "  provider $PROVIDER_ID já existe"
else
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --project="$PROJECT" \
    --location=global \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
    --attribute-condition="attribute.repository == '${GITHUB_OWNER}/${GITHUB_REPO}'"
  echo "  provider $PROVIDER_ID criado"
fi

# Service Account CI
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT" &>/dev/null; then
  echo "  SA $SA_EMAIL já existe"
else
  gcloud iam service-accounts create "$SA_ID" \
    --project="$PROJECT" \
    --display-name="GitHub Actions CI — $ENV"
  echo "  SA $SA_EMAIL criado"
fi

ROLES=(
  roles/compute.admin
  roles/container.admin
  roles/cloudsql.admin
  roles/secretmanager.admin
  roles/artifactregistry.admin
  roles/iam.serviceAccountAdmin
  roles/iam.workloadIdentityPoolAdmin
  roles/storage.admin
  roles/resourcemanager.projectIamAdmin
  roles/monitoring.editor
  roles/billing.viewer
)

for role in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role" \
    --condition=None \
    --quiet >/dev/null
done
echo "  roles IAM ok"

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$PROJECT" \
  --role="roles/iam.workloadIdentityUser" \
  --member="$REPO_PRINCIPAL" \
  --quiet >/dev/null
echo "  WIF binding ok"

WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

echo ""
echo "=============================================="
echo " WIF pronto para $ENV"
echo "=============================================="
echo "GCP_WORKLOAD_IDENTITY_PROVIDER=$WIF_PROVIDER"
echo "GCP_SERVICE_ACCOUNT=$SA_EMAIL"
echo ""
echo "Próximo:"
echo "  ./scripts/configure-github-secrets.sh $ENV --from-gcloud"
echo "  git push origin main   # pipeline roda terraform apply"
