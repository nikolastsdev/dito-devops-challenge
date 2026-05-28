#!/usr/bin/env bash
# =============================================================================
# Fase 2 — Primeiro terraform apply (local, única vez por ambiente)
#
# Uso:
#   source .env.terraform.local
#   ./scripts/tf-first-apply.sh staging
#   ./scripts/tf-first-apply.sh production
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?Informe o ambiente: staging | production}"

if [[ "$ENV" != "staging" && "$ENV" != "production" ]]; then
  echo "Erro: ambiente deve ser 'staging' ou 'production'"
  exit 1
fi

load_local_env
require_db_password
require_terraform
require_gcloud

ROOT="$(repo_root)"
IAC_DIR="$ROOT/iac"
BACKEND_FILE="$IAC_DIR/backends/${ENV}.gcs.tfbackend"
TFVARS_FILE="$IAC_DIR/environments/${ENV}.tfvars"
PROJECT_ID="$(tfvars_value "$TFVARS_FILE" project_id)"

echo "=============================================="
echo " FASE 2 — Primeiro terraform apply: $ENV"
echo "=============================================="
echo ""
echo "Project : $PROJECT_ID"
echo "Backend : $BACKEND_FILE"
echo "Tfvars  : $TFVARS_FILE"
echo ""

gcloud config set project "$PROJECT_ID"

cd "$IAC_DIR"

echo "--> terraform init"
terraform init -backend-config="$BACKEND_FILE" -reconfigure

echo ""
echo "--> terraform plan"
terraform plan \
  -var-file="$TFVARS_FILE" \
  -out="${ENV}.tfplan"

echo ""
echo "─────────────────────────────────────────────────────"
echo "Revise o plan acima. Continuar com apply? [s/N]"
read -r CONFIRM

if [[ "$CONFIRM" != "s" && "$CONFIRM" != "S" ]]; then
  echo "Apply cancelado."
  rm -f "${ENV}.tfplan"
  exit 0
fi

echo ""
echo "--> terraform apply"
terraform apply "${ENV}.tfplan"
rm -f "${ENV}.tfplan"

echo ""
echo "=============================================="
echo " Apply de $ENV concluído!"
echo "=============================================="
echo ""
terraform output -raw github_wif_provider 2>/dev/null && echo "" || true
terraform output -raw github_ci_sa_email 2>/dev/null && echo "" || true
echo ""
echo "Próximo passo:"
echo "  ./scripts/configure-github-secrets.sh $ENV"
echo ""
