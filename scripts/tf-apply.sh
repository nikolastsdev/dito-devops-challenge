#!/usr/bin/env bash
# Wrapper Terraform — plan/apply por ambiente (uso local ou pós-bootstrap)
#
# Uso:
#   source .env.terraform.local
#   ./scripts/tf-apply.sh staging plan
#   ./scripts/tf-apply.sh staging apply

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?Uso: $0 <staging|production> <plan|apply|destroy|output>}"
ACTION="${2:-plan}"

if [[ "$ENV" != "staging" && "$ENV" != "production" ]]; then
  echo "Ambiente inválido: $ENV"
  exit 1
fi

load_local_env

ROOT="$(repo_root)"
IAC_DIR="$ROOT/iac"
TFVARS="$IAC_DIR/environments/${ENV}.tfvars"
BACKEND="$IAC_DIR/backends/${ENV}.gcs.tfbackend"

if [[ ! -f "$TFVARS" || ! -f "$BACKEND" ]]; then
  echo "Arquivo não encontrado para ambiente $ENV"
  exit 1
fi

require_terraform

if [[ "$ACTION" == "plan" || "$ACTION" == "apply" || "$ACTION" == "destroy" ]]; then
  require_db_password
fi

cd "$IAC_DIR"

echo "==> Ambiente: $ENV | Ação: $ACTION"
terraform init -backend-config="$BACKEND" -reconfigure

case "$ACTION" in
  plan)
    terraform plan -var-file="$TFVARS" -input=false
    ;;
  apply)
    terraform apply -var-file="$TFVARS" -input=false
    ;;
  destroy)
    echo "⚠️  Destroy em $ENV — confirme"
    terraform destroy -var-file="$TFVARS"
    ;;
  output)
    terraform output
    ;;
  validate)
    terraform validate
    ;;
  *)
    echo "Ação desconhecida: $ACTION"
    exit 1
    ;;
esac
