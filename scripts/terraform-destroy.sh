#!/usr/bin/env bash
# Destroy Terraform — ordem correta para evitar erros de dependência no GCP.
#
# Problemas que este script previne:
#   - GKE deletion_protection bloqueando destroy
#   - Subnet em uso por node pool (GKE destruído antes da VPC)
#   - PSA connection travada após Cloud SQL (deletion_policy=ABANDON no Terraform)
#
# NÃO cancele o workflow no meio — deixa lock órfão no GCS state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?Informe o ambiente: staging | production}"
REPO_ROOT="$(repo_root)"
IAC_DIR="$REPO_ROOT/iac"
TFVARS="$IAC_DIR/environments/${ENV}.tfvars"

load_local_env
require_gcloud

PROJECT_ID="$(tfvars_value "$TFVARS" project_id)"
PROJECT_NAME="$(tfvars_value "$TFVARS" project_name)"
PROJECT_NAME="${PROJECT_NAME:-dito}"
REGION="southamerica-east1"
CLUSTER="${PROJECT_NAME}-gke-${ENV}"
SQL_INSTANCE="${PROJECT_NAME}-pg-${ENV}"

log() { echo "--> $*" >&2; }
skip() { echo "    [skip] $*" >&2; }

TF_ARGS=(
  -var-file="environments/${ENV}.tfvars"
  -var="gke_deletion_protection=false"
  -auto-approve
  -input=false
)

disable_gke_deletion_protection() {
  if ! gcloud container clusters describe "$CLUSTER" \
    --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    skip "GKE $CLUSTER não existe"
    return 0
  fi

  log "Desabilitando deletion protection do GKE $CLUSTER..."
  local token
  token="$(gcloud auth print-access-token)"
  curl -sf -X PATCH \
    "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER}?updateMask=deletionProtection" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"deletionProtection": false}' \
    && skip "deletion protection desabilitada" \
    || skip "PATCH falhou — destroy tentará mesmo assim"
}

wait_for_gke_gone() {
  local attempts="${1:-30}" interval="${2:-20}"
  log "Aguardando GKE $CLUSTER ser removido..."
  for i in $(seq 1 "$attempts"); do
    if ! gcloud container clusters describe "$CLUSTER" \
      --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
      skip "GKE removido"
      return 0
    fi
    sleep "$interval"
  done
  skip "GKE ainda presente após timeout — continuando"
}

wait_for_sql_gone() {
  local attempts="${1:-30}" interval="${2:-20}"
  log "Aguardando Cloud SQL $SQL_INSTANCE ser removido..."
  for i in $(seq 1 "$attempts"); do
    if ! gcloud sql instances describe "$SQL_INSTANCE" \
      --project="$PROJECT_ID" &>/dev/null; then
      skip "Cloud SQL removido"
      return 0
    fi
    sleep "$interval"
  done
  skip "Cloud SQL ainda presente após timeout — continuando"
}

destroy_target() {
  local label="$1" target="$2"
  log "Destroy: $label ($target)"
  terraform destroy -target="$target" "${TF_ARGS[@]}"
}

destroy_all() {
  local attempts="${1:-2}" interval="${2:-60}"
  for i in $(seq 1 "$attempts"); do
    log "Destroy completo (tentativa $i/$attempts)..."
    if terraform destroy "${TF_ARGS[@]}"; then
      return 0
    fi
    [[ "$i" -lt "$attempts" ]] && sleep "$interval"
  done
  return 1
}

cd "$IAC_DIR"

log "Destroy Terraform: $ENV (project=$PROJECT_ID)"
disable_gke_deletion_protection

destroy_target "IAM" "module.iam" || true
destroy_target "GKE" "module.kubernetes" || true
wait_for_gke_gone

destroy_target "Database" "module.database" || true
wait_for_sql_gone

destroy_all 2 60
log "Destroy concluído"
