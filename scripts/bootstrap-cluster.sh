#!/usr/bin/env bash
# =============================================================================
# Bootstrap pós-cluster — idempotente (pode rodar várias vezes com segurança)
#
# Fluxo:
#   1. Credenciais GKE
#   2. ArgoCD (Helm) — só instala se ainda não existir
#   3. cert-manager + ClusterIssuer (Helm/kubectl — confiável no bootstrap)
#   4. AppProjects + Applications GitOps (Traefik + app)
#   5. IngressRoute ArgoCD (nip.io + Let's Encrypt)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ENV="${1:?Informe o ambiente: staging | production}"
REPO_ROOT="$(repo_root)"

load_local_env
require_gcloud

TFVARS="$REPO_ROOT/iac/environments/${ENV}.tfvars"
PROJECT_ID="$(tfvars_value "$TFVARS" project_id)"
REGION="southamerica-east1"
CLUSTER_NAME="dito-gke-${ENV}"
ARGOCD_VERSION="7.8.23"
CERT_MANAGER_VERSION="v1.14.5"
ARGOCD_INGRESS_DIR="$REPO_ROOT/manifests/infra/argocd-ingress"

log() { echo "--> $*"; }
skip() { echo "    [skip] $*"; }
warn() { echo "    [warn] $*" >&2; }

helm_release_exists() {
  helm status "$1" -n "$2" &>/dev/null
}

deployment_ready() {
  local ns="$1" name="$2"
  kubectl get deployment "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -qE '^[1-9]'
}

cert_manager_ready() {
  deployment_ready cert-manager cert-manager-webhook \
    && deployment_ready cert-manager cert-manager \
    && kubectl get clusterissuer letsencrypt-prod &>/dev/null
}

wait_for_traefik_ip() {
  local timeout="${1:-600}" elapsed=0 ip=""
  log "Aguardando IP externo do Traefik (timeout ${timeout}s)..."
  while [[ $elapsed -lt $timeout ]]; do
    ip="$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "Timeout aguardando IP do Traefik" >&2
  return 1
}

wait_for_cert_manager() {
  local timeout="${1:-300}" elapsed=0
  log "Aguardando cert-manager + ClusterIssuer (timeout ${timeout}s)..."
  while [[ $elapsed -lt $timeout ]]; do
    if cert_manager_ready; then
      return 0
    fi
    if (( elapsed > 0 && elapsed % 30 == 0 )); then
      kubectl get pods -n cert-manager 2>/dev/null || true
      kubectl get clusterissuer 2>/dev/null || true
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  echo "Timeout aguardando cert-manager / ClusterIssuer" >&2
  kubectl get pods -n cert-manager 2>/dev/null || true
  kubectl get clusterissuer 2>/dev/null || true
  return 1
}

wait_for_argocd_controller() {
  local timeout="${1:-300}" elapsed=0
  log "Aguardando ArgoCD controller..."
  while [[ $elapsed -lt $timeout ]]; do
    if deployment_ready argocd argocd-application-controller \
      && deployment_ready argocd argocd-repo-server; then
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  echo "Timeout aguardando ArgoCD controller" >&2
  return 1
}

install_argocd() {
  helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
  helm repo update argo >/dev/null

  if helm_release_exists argocd argocd && deployment_ready argocd argocd-server; then
    skip "ArgoCD já instalado e pronto"
    return 0
  fi

  log "Instalando ArgoCD (Helm)..."
  helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --create-namespace \
    --version "$ARGOCD_VERSION" \
    --set server.service.type=ClusterIP \
    --set configs.params."server\.insecure"=true \
    --wait --timeout 5m
}

ensure_cert_manager() {
  if cert_manager_ready; then
    skip "cert-manager + ClusterIssuer já prontos"
    return 0
  fi

  if ! helm_release_exists cert-manager cert-manager; then
    log "Instalando cert-manager (Helm)..."
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    helm repo update jetstack >/dev/null
    helm upgrade --install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --version "$CERT_MANAGER_VERSION" \
      --set crds.enabled=true \
      --set prometheus.enabled=false \
      --wait --timeout 5m
  else
    skip "Release cert-manager já existe"
  fi

  if ! kubectl get clusterissuer letsencrypt-prod &>/dev/null; then
    log "Aplicando ClusterIssuer letsencrypt-prod..."
    kubectl apply -k "$REPO_ROOT/manifests/infra/cluster-issuers"
  fi

  wait_for_cert_manager 300
}

apply_application() {
  local file="$1"
  kubectl apply -f "$file"
}

apply_argocd_ingress() {
  local traefik_ip="$1"
  local host="argocd.${traefik_ip}.nip.io"

  export ARGOCD_HOST="$host"
  log "Configurando IngressRoute ArgoCD: https://${host}"

  for tpl in middleware-redirect.yaml.tpl certificate.yaml.tpl ingressroute-http.yaml.tpl ingressroute-https.yaml.tpl; do
    envsubst '${ARGOCD_HOST}' < "$ARGOCD_INGRESS_DIR/$tpl" | kubectl apply -f -
  done

  if helm_release_exists argocd argocd; then
    log "Atualizando URL externa do ArgoCD..."
    helm upgrade argocd argo/argo-cd -n argocd \
      --reuse-values \
      --set configs.cm.url="https://${host}" \
      --wait --timeout 3m
  fi

  echo ""
  echo "  ArgoCD UI: https://${host}"
  echo "  User: admin"
}

echo "=============================================="
echo " Bootstrap pós-cluster: $ENV"
echo " Project : $PROJECT_ID"
echo " Cluster : $CLUSTER_NAME"
echo "=============================================="

log "Obtendo credenciais do GKE..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID"

install_argocd
wait_for_argocd_controller 300

ensure_cert_manager

log "Aplicando AppProjects..."
kubectl apply -f "$REPO_ROOT/gitops/argocd/projects/infra.yaml"
kubectl apply -f "$REPO_ROOT/gitops/argocd/projects/dito-challenge.yaml"

log "Aplicando Applications (Traefik + app)..."
apply_application "$REPO_ROOT/gitops/argocd/applications/traefik-${ENV}.yaml"
apply_application "$REPO_ROOT/gitops/argocd/applications/${ENV}.yaml"

TRAEFIK_IP="$(wait_for_traefik_ip 600)"
apply_argocd_ingress "$TRAEFIK_IP"

echo ""
echo "=============================================="
echo " Bootstrap concluído!"
echo "=============================================="
echo ""
kubectl get applications -n argocd 2>/dev/null || true
echo ""
kubectl get certificate -n argocd 2>/dev/null || true
echo ""
echo "Senha ArgoCD admin:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo || true
