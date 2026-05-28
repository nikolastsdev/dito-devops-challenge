#!/usr/bin/env bash
# Pré-destroy — prepara o ambiente para terraform destroy (sem terraform apply).
# 1. Desabilita deletion protection do GKE via API (evita recriar recursos)
# 2. Remove Cloud SQL e aguarda PSA connection liberar

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?Informe o ambiente: staging | production}"
REPO_ROOT="$(repo_root)"

load_local_env
require_gcloud

TFVARS="$REPO_ROOT/iac/environments/${ENV}.tfvars"
PROJECT_ID="$(tfvars_value "$TFVARS" project_id)"
PROJECT_NAME="$(tfvars_value "$TFVARS" project_name)"
PROJECT_NAME="${PROJECT_NAME:-dito}"
REGION="southamerica-east1"
CLUSTER="${PROJECT_NAME}-gke-${ENV}"
SQL_INSTANCE="${PROJECT_NAME}-pg-${ENV}"
PSA_WAIT_SECONDS="${PSA_WAIT_SECONDS:-120}"
SQL_POLL_ATTEMPTS="${SQL_POLL_ATTEMPTS:-36}"
SQL_POLL_INTERVAL="${SQL_POLL_INTERVAL:-20}"

log() { echo "--> $*" >&2; }
skip() { echo "    [skip] $*" >&2; }
warn() { echo "    [warn] $*" >&2; }

disable_gke_deletion_protection() {
  if ! gcloud container clusters describe "$CLUSTER" \
    --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    skip "GKE $CLUSTER não existe"
    return 0
  fi

  log "Desabilitando deletion protection do GKE $CLUSTER (API)..."
  local token
  token="$(gcloud auth print-access-token)"
  if curl -sf -X PATCH \
    "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER}?updateMask=deletionProtection" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"deletionProtection": false}'; then
    skip "deletion protection desabilitada"
  else
    warn "Não foi possível desabilitar deletion protection via API — destroy pode falhar no GKE"
  fi
}

delete_cloud_sql() {
  if gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" &>/dev/null; then
    log "Deletando Cloud SQL $SQL_INSTANCE..."
    gcloud sql instances delete "$SQL_INSTANCE" \
      --project="$PROJECT_ID" \
      --quiet
  else
    skip "Cloud SQL $SQL_INSTANCE já removido"
  fi

  log "Aguardando Cloud SQL finalizar remoção..."
  for attempt in $(seq 1 "$SQL_POLL_ATTEMPTS"); do
    if ! gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" &>/dev/null; then
      skip "Cloud SQL removido (tentativa $attempt/$SQL_POLL_ATTEMPTS)"
      break
    fi
    sleep "$SQL_POLL_INTERVAL"
  done

  if gcloud sql instances describe "$SQL_INSTANCE" --project="$PROJECT_ID" &>/dev/null; then
    echo "Erro: Cloud SQL $SQL_INSTANCE ainda existe após timeout" >&2
    exit 1
  fi

  log "Aguardando ${PSA_WAIT_SECONDS}s para GCP liberar Service Networking Connection..."
  sleep "$PSA_WAIT_SECONDS"
}

log "Pré-destroy: $ENV (project=$PROJECT_ID)"
disable_gke_deletion_protection
delete_cloud_sql
log "Pré-destroy concluído"
