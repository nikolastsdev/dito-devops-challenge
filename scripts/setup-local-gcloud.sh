#!/usr/bin/env bash
# Configura gcloud no WSL + carrega variáveis locais do Terraform
set -euo pipefail

GCLOUD_PATH="$HOME/google-cloud-sdk/google-cloud-sdk/path.bash.inc"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env.terraform.local"
BASHRC="$HOME/.bashrc"

# 1. PATH do gcloud no .bashrc
if [[ -f "$GCLOUD_PATH" ]] && ! grep -q "google-cloud-sdk/path.bash.inc" "$BASHRC" 2>/dev/null; then
  cat >> "$BASHRC" <<'EOF'

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/google-cloud-sdk/path.bash.inc" ]; then
  source "$HOME/google-cloud-sdk/google-cloud-sdk/path.bash.inc"
fi
EOF
  echo "✓ gcloud adicionado ao ~/.bashrc"
fi

# shellcheck source=/dev/null
[[ -f "$GCLOUD_PATH" ]] && source "$GCLOUD_PATH"

if ! command -v gcloud &>/dev/null; then
  echo "Erro: gcloud não encontrado. Rode a instalação do SDK primeiro."
  exit 1
fi

echo "gcloud: $(gcloud --version | head -1)"
echo ""

# 2. Login (abre o browser — precisa interação)
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
  echo "→ Faça login no Google (vai abrir o browser):"
  gcloud auth login
fi

echo "→ Credenciais para Terraform/providers:"
gcloud auth application-default login 2>/dev/null || {
  echo "  Rode manualmente: gcloud auth application-default login"
}

# 3. Project default
gcloud config set project dito-staging
echo "✓ project default: dito-staging"

# 4. Variáveis locais
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  echo "✓ variáveis carregadas de .env.terraform.local"
else
  echo "! .env.terraform.local não encontrado"
fi

echo ""
echo "Pronto. Rode staging primeiro:"
echo "  source $ENV_FILE"
echo "  ./scripts/bootstrap-gcp-projects.sh staging"
echo "  ./scripts/tf-first-apply.sh staging"
echo "  ./scripts/configure-github-secrets.sh staging"
