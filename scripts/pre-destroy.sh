#!/usr/bin/env bash
# Pré-destroy — libera Cloud SQL antes do Terraform remover a PSA connection.
# GCP demora para liberar o Service Networking Connection após deletar o Cloud SQL.

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
SQL_INSTANCE="${PROJECT_NAME}-pg-${ENV}"
PSA_WAIT_SECONDS="${PSA_WAIT_SECONDS:-120}"
SQL_POLL_ATTEMPTS="${SQL_POLL_ATTEMPTS:-36}"
SQL_POLL_INTERVAL="${SQL_POLL_INTERVAL:-20}"

log() { echo "--> $*" >&2; }
skip() { echo "    [skip] $*" >&2; }

log "Pré-destroy: $ENV (project=$PROJECT_ID, sql=$SQL_INSTANCE)"

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

log "Pré-destroy concluído"
