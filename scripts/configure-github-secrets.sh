#!/usr/bin/env bash
# =============================================================================
# Fase 3 — Configura GitHub Environments + secrets por ambiente
#
# Secrets ficam no Environment (staging / production), não no repo.
# Cada project GCP tem seu próprio WIF + Service Account.
#
# Uso:
#   ./scripts/configure-github-secrets.sh staging
#   ./scripts/configure-github-secrets.sh production
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?Informe o ambiente: staging | production}"
FROM_GCLOUD="${2:-}"

if [[ "$ENV" != "staging" && "$ENV" != "production" ]]; then
  echo "Erro: ambiente deve ser 'staging' ou 'production'"
  exit 1
fi

if [[ "$2" == "--from-gcloud" ]]; then
  FROM_GCLOUD=1
fi

load_local_env
require_gcloud

ROOT="$(repo_root)"
IAC_DIR="$ROOT/iac"
BACKEND_FILE="$IAC_DIR/backends/${ENV}.gcs.tfbackend"
TFVARS_FILE="$IAC_DIR/environments/${ENV}.tfvars"
PROJECT_ID="$(tfvars_value "$TFVARS_FILE" project_id)"
OWNER="$(tfvars_value "$TFVARS_FILE" github_owner)"
REPO="$(tfvars_value "$TFVARS_FILE" github_repo)"
DB_PASSWORD="${TF_VAR_db_admin_password:-}"

echo "=============================================="
echo " FASE 3 — GitHub secrets ($ENV)"
echo "=============================================="

if [[ -n "$FROM_GCLOUD" ]]; then
  PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
  WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/dito-github-pool/providers/github-provider"
  CI_SA_EMAIL="dito-ci@${PROJECT_ID}.iam.gserviceaccount.com"
else
  require_terraform
  cd "$IAC_DIR"
  terraform init -backend-config="$BACKEND_FILE" -reconfigure -input=false
  WIF_PROVIDER=$(terraform output -raw github_wif_provider)
  CI_SA_EMAIL=$(terraform output -raw github_ci_sa_email)
  PROJECT_ID=$(terraform output -raw project_id)
fi

echo ""
echo "Repositório : $OWNER/$REPO"
echo "Environment : $ENV"
echo "Project ID  : $PROJECT_ID"
echo "WIF Provider: $WIF_PROVIDER"
echo "CI SA Email : $CI_SA_EMAIL"
echo ""

print_manual_instructions() {
  echo "Configure manualmente:"
  echo ""
  echo "  GitHub → Settings → Environments → $ENV → Secrets"
  echo "    GCP_WORKLOAD_IDENTITY_PROVIDER = $WIF_PROVIDER"
  echo "    GCP_SERVICE_ACCOUNT            = $CI_SA_EMAIL"
  echo "    TF_VAR_DB_ADMIN_PASSWORD       = <senha do postgres>"
  echo ""
  if [[ "$ENV" == "staging" ]]; then
    echo "  GitHub → Settings → Variables (repo)"
    echo "    GCP_PROJECT_ID_STAGING = $PROJECT_ID"
  else
    echo "    GCP_PROJECT_ID_PRODUCTION = $PROJECT_ID"
  fi
}

if ! command -v gh &>/dev/null; then
  echo "gh CLI não encontrado."
  print_manual_instructions
  exit 0
fi

echo "Criando/verificando GitHub Environment: $ENV"
ensure_github_environment "$OWNER" "$REPO" "$ENV"

echo "Configurando secrets no environment '$ENV'..."
gh secret set GCP_WORKLOAD_IDENTITY_PROVIDER \
  --env "$ENV" \
  --body "$WIF_PROVIDER" \
  --repo "$OWNER/$REPO"
echo "  ✓ GCP_WORKLOAD_IDENTITY_PROVIDER (environment: $ENV)"

gh secret set GCP_SERVICE_ACCOUNT \
  --env "$ENV" \
  --body "$CI_SA_EMAIL" \
  --repo "$OWNER/$REPO"
echo "  ✓ GCP_SERVICE_ACCOUNT (environment: $ENV)"

if [[ -n "$DB_PASSWORD" ]]; then
  gh secret set TF_VAR_DB_ADMIN_PASSWORD \
    --env "$ENV" \
    --body "$DB_PASSWORD" \
    --repo "$OWNER/$REPO"
  echo "  ✓ TF_VAR_DB_ADMIN_PASSWORD (environment: $ENV, de .env.terraform.local)"
else
  echo ""
  echo "  ! TF_VAR_db_admin_password não definida localmente"
  echo "    Rode: gh secret set TF_VAR_DB_ADMIN_PASSWORD --env $ENV --repo $OWNER/$REPO"
fi

if [[ "$ENV" == "staging" ]]; then
  gh variable set GCP_PROJECT_ID_STAGING \
    --body "$PROJECT_ID" \
    --repo "$OWNER/$REPO"
  echo "  ✓ GCP_PROJECT_ID_STAGING (repo variable)"
else
  gh variable set GCP_PROJECT_ID_PRODUCTION \
    --body "$PROJECT_ID" \
    --repo "$OWNER/$REPO"
  echo "  ✓ GCP_PROJECT_ID_PRODUCTION (repo variable)"
fi

echo ""
echo "=============================================="
echo " Fase 3 concluída para $ENV"
echo "=============================================="
echo ""
echo "Dica: em production, configure 'Required reviewers' no GitHub Environment"
echo "      Settings → Environments → production → Protection rules"
echo ""

if [[ "$ENV" == "staging" ]]; then
  echo "Staging pronto. Production fica para depois:"
  echo "  ./scripts/bootstrap-gcp-projects.sh production"
  echo "  ./scripts/tf-first-apply.sh production"
  echo "  ./scripts/configure-github-secrets.sh production"
fi
