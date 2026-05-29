#!/usr/bin/env bash
# =============================================================================
# Bootstrap pós-cluster — idempotente, não trava em cert-manager
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
CERT_MANAGER_CHART_VERSION="v1.14.5"
ARGOCD_INGRESS_DIR="$REPO_ROOT/manifests/infra/argocd-ingress"

log() { echo "--> $*" >&2; }
skip() { echo "    [skip] $*" >&2; }
warn() { echo "    [warn] $*" >&2; }

helm_release_exists() {
  helm status "$1" -n "$2" &>/dev/null
}

deployment_ready() {
  local ns="$1" name="$2"
  kubectl get deployment "$name" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -qE '^[1-9]'
}

crds_installed() {
  kubectl get crd certificates.cert-manager.io &>/dev/null
}

cert_manager_ready() {
  crds_installed \
    && deployment_ready cert-manager cert-manager-webhook \
    && deployment_ready cert-manager cert-manager
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
  warn "Timeout aguardando IP do Traefik"
  return 1
}

wait_for_argocd_controller() {
  local timeout="${1:-180}" elapsed=0
  log "Aguardando ArgoCD controller (timeout ${timeout}s)..."
  while [[ $elapsed -lt $timeout ]]; do
    if deployment_ready argocd argocd-application-controller \
      && deployment_ready argocd argocd-repo-server; then
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  warn "ArgoCD controller ainda não pronto — continuando"
  return 0
}

install_cert_manager() {
  if cert_manager_ready; then
    skip "cert-manager já pronto"
    return 0
  fi

  log "Criando namespace cert-manager..."
  kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

  # Recomendação oficial cert-manager para GitOps: aplicar CRDs separadamente via
  # kubectl ANTES do Helm, nunca via hooks (ArgoCD não executa Helm hooks no sync).
  # https://cert-manager.io/docs/installation/helm/#option-2-install-crds-as-part-of-the-helm-release
  if ! crds_installed; then
    log "Aplicando CRDs cert-manager ${CERT_MANAGER_VERSION}..."
    kubectl apply -f \
      "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml" \
      --server-side=true || {
      warn "Falha ao aplicar CRDs cert-manager — verificar conectividade"
      return 1
    }
    # Aguarda CRDs serem estabelecidos antes de instalar o chart
    log "Aguardando CRDs serem estabelecidos..."
    kubectl wait --for=condition=Established crd/certificates.cert-manager.io \
      --timeout=60s 2>/dev/null || warn "CRD certificates.cert-manager.io não estabelecido em 60s"
  else
    skip "CRDs cert-manager já presentes"
  fi

  helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
  helm repo update jetstack >/dev/null

  log "Instalando cert-manager ${CERT_MANAGER_CHART_VERSION} via Helm..."
  # crds.enabled=false: CRDs já aplicados acima via kubectl (abordagem GitOps correta)
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --version "${CERT_MANAGER_CHART_VERSION}" \
    --set crds.enabled=false \
    --set startupapicheck.enabled=false \
    --wait \
    --timeout 3m || warn "Helm cert-manager retornou aviso — verificar estado depois"
}

ensure_cluster_issuer() {
  if ! crds_installed; then
    warn "CRDs cert-manager ausentes — ClusterIssuer será aplicado na próxima execução"
    return 0
  fi
  if kubectl get clusterissuer letsencrypt-prod &>/dev/null; then
    skip "ClusterIssuer letsencrypt-prod já existe"
    return 0
  fi
  log "Aplicando ClusterIssuer letsencrypt-prod..."
  kubectl apply -k "$REPO_ROOT/manifests/infra/cluster-issuers" || warn "ClusterIssuer falhou — tentar de novo depois"
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

apply_application() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    warn "Application não encontrada: $file"
    return 0
  fi
  log "Aplicando Application: $(basename "$file")"
  kubectl apply -f "$file"
}

apply_infra_applications() {
  local apps=(
    "cert-manager-${ENV}"
    "cluster-issuers-${ENV}"
    "eso-${ENV}"
    "traefik-${ENV}"
  )

  for app in "${apps[@]}"; do
    apply_application "$REPO_ROOT/gitops/argocd/applications/${app}.yaml"
  done
}

render_template() {
  local tpl="$1" host="$2"
  sed "s/__ARGOCD_HOST__/${host}/g" "$tpl"
}

normalize_ip() {
  # Remove whitespace/newlines — evita host inválido ao capturar stdout de funções
  echo "$1" | tr -d '[:space:]'
}

apply_argocd_ingress() {
  local traefik_ip host tls_ready=false

  traefik_ip="$(normalize_ip "$1")"
  if [[ ! "$traefik_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    warn "IP Traefik inválido: '${traefik_ip}' — pulando IngressRoute"
    return 1
  fi

  host="argocd.${traefik_ip}.nip.io"

  cert_manager_ready && tls_ready=true

  log "Configurando IngressRoute ArgoCD: https://${host}"

  if $tls_ready; then
    log "cert-manager pronto — aplicando Certificate + HTTPS"
    ensure_cluster_issuer
    render_template "$ARGOCD_INGRESS_DIR/middleware-redirect.yaml.tpl" "$host" | kubectl apply -f -
    render_template "$ARGOCD_INGRESS_DIR/ingressroute-http.yaml.tpl" "$host" | kubectl apply -f -
    render_template "$ARGOCD_INGRESS_DIR/certificate.yaml.tpl" "$host" | kubectl apply -f -
    render_template "$ARGOCD_INGRESS_DIR/ingressroute-https.yaml.tpl" "$host" | kubectl apply -f -
  else
    warn "cert-manager não pronto — ArgoCD acessível via HTTP temporário"
    warn "Reexecute bootstrap quando cert-manager subir para habilitar HTTPS"
    kubectl delete ingressroute argocd-http argocd-https -n argocd --ignore-not-found=true 2>/dev/null || true
    kubectl apply -f - <<EOF
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: argocd-http-direct
  namespace: argocd
spec:
  entryPoints:
    - web
  routes:
    - match: "Host(\`${host}\`)"
      kind: Rule
      services:
        - name: argocd-server
          port: 80
          scheme: http
EOF
  fi

  if helm_release_exists argocd argocd; then
    log "Atualizando URL externa do ArgoCD..."
    helm upgrade argocd argo/argo-cd -n argocd \
      --reuse-values \
      --set configs.cm.url="https://${host}" \
      --timeout 3m || warn "helm upgrade argocd URL falhou — ignorando"
  fi

  echo ""
  if $tls_ready; then
    echo "  ArgoCD UI: https://${host}"
  else
    echo "  ArgoCD UI (HTTP temp): http://${host}"
  fi
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
wait_for_argocd_controller 180

# Dispara cert-manager cedo (sem bloquear) — pods sobem em paralelo com Traefik
install_cert_manager &

log "Aplicando AppProjects..."
kubectl apply -f "$REPO_ROOT/gitops/argocd/projects/infra.yaml"
kubectl apply -f "$REPO_ROOT/gitops/argocd/projects/dito-challenge.yaml"

log "Aplicando Applications de infra (cert-manager, cluster-issuers, traefik)..."
apply_infra_applications

log "Aplicando Application da app..."
apply_application "$REPO_ROOT/gitops/argocd/applications/${ENV}.yaml"

# Aguarda cert-manager em background (não falha se demorar)
wait %1 2>/dev/null || warn "install_cert_manager em background terminou com aviso"

TRAEFIK_IP=""
TRAEFIK_IP="$(normalize_ip "$(wait_for_traefik_ip 600 || true)")"
if [[ -z "$TRAEFIK_IP" ]] || [[ ! "$TRAEFIK_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  warn "Traefik sem IP válido ainda — pulando IngressRoute ArgoCD"
else
  apply_argocd_ingress "$TRAEFIK_IP"
fi

echo ""
echo "=============================================="
echo " Bootstrap concluído!"
echo "=============================================="
kubectl get pods -n cert-manager 2>/dev/null || true
echo ""
kubectl get applications -n argocd 2>/dev/null || true
echo ""
kubectl get certificate -n argocd 2>/dev/null || true
echo ""
echo "Senha ArgoCD admin:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo || true
