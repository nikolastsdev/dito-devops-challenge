#!/usr/bin/env bash
# Funções compartilhadas pelos scripts de bootstrap/Terraform/GitHub.

set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

load_local_env() {
  local root
  root="$(repo_root)"
  if [[ -f "$root/.env.terraform.local" ]]; then
    # shellcheck source=/dev/null
    source "$root/.env.terraform.local"
  fi
}

ensure_gcloud_path() {
  local gcloud_path="$HOME/google-cloud-sdk/google-cloud-sdk/path.bash.inc"
  if [[ -f "$gcloud_path" ]]; then
    # shellcheck source=/dev/null
    source "$gcloud_path"
  fi
}

require_gcloud() {
  ensure_gcloud_path
  if ! command -v gcloud &>/dev/null; then
    echo "Erro: gcloud não encontrado. Rode ./scripts/setup-local-gcloud.sh"
    exit 1
  fi
}

require_terraform() {
  if ! command -v terraform &>/dev/null; then
    echo "Erro: terraform não encontrado."
    exit 1
  fi
}

require_db_password() {
  load_local_env
  if [[ -z "${TF_VAR_db_admin_password:-}" ]]; then
    echo "Erro: defina TF_VAR_db_admin_password ou crie .env.terraform.local"
    exit 1
  fi
}

tfvars_value() {
  local file="$1"
  local key="$2"
  grep "^[[:space:]]*${key}[[:space:]]*=" "$file" | head -1 | awk -F'"' '{print $2}'
}

iac_paths() {
  local env="$1"
  local root
  root="$(repo_root)"
  echo "IAC_DIR=$root/iac"
  echo "TFVARS=$root/iac/environments/${env}.tfvars"
  echo "BACKEND=$root/iac/backends/${env}.gcs.tfbackend"
}

ensure_github_environment() {
  local owner="$1"
  local repo="$2"
  local env_name="$3"

  gh api "repos/${owner}/${repo}/environments/${env_name}" -X PUT \
    --input - <<< '{}' >/dev/null 2>&1 || true
}
