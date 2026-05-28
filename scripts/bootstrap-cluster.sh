#!/usr/bin/env bash
# =============================================================================
# Bootstrap pós-cluster — roda UMA VEZ após terraform apply criar o GKE
#
# O que faz:
#   1. Conecta ao cluster GKE
#   2. Instala ArgoCD via Helm
#   3. Aplica os AppProjects (infra, dito-challenge)
#   4. Aplica as Applications (Traefik + app Groove)
#      → ArgoCD assume e mantém tudo sincronizado a partir daí
#
# Pré-requisitos:
#   - gcloud autenticado (gcloud auth login + application-default login)
#   - kubectl e helm instalados
#   - terraform apply já executado (cluster e IP estático existem)
#
# Uso:
#   ./scripts/bootstrap-cluster.sh staging
#   ./scripts/bootstrap-cluster.sh production
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
ARGOCD_VERSION="7.8.x"

echo "=============================================="
echo " Bootstrap pós-cluster: $ENV"
echo " Project : $PROJECT_ID"
echo " Cluster : $CLUSTER_NAME"
echo "=============================================="

# ── 1. Credenciais do cluster ─────────────────────────────────────────────────
echo ""
echo "--> Obtendo credenciais do GKE..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID"

kubectl cluster-info

# ── 2. ArgoCD via Helm ────────────────────────────────────────────────────────
echo ""
echo "--> Instalando ArgoCD (Helm)..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version "$ARGOCD_VERSION" \
  --set server.service.type=ClusterIP \
  --set configs.params."server\.insecure"=true \
  --wait --timeout 5m

echo "  ArgoCD instalado."

# ── 3. AppProjects ────────────────────────────────────────────────────────────
echo ""
echo "--> Aplicando AppProjects..."
kubectl apply -f "$REPO_ROOT/gitops/argocd/projects/infra.yaml"
kubectl apply -f "$REPO_ROOT/gitops/argocd/projects/dito-challenge.yaml"
echo "  AppProjects ok."

# ── 4. Applications ───────────────────────────────────────────────────────────
# Traefik PRIMEIRO (sync-wave: "-1" já garante a ordem dentro do ArgoCD,
# mas aplicamos antes para dar tempo de o LB receber o IP estático)
echo ""
echo "--> Aplicando Application: traefik-${ENV}..."
kubectl apply -f "$REPO_ROOT/gitops/argocd/applications/traefik-${ENV}.yaml"

echo "--> Aplicando Application: dito-api-${ENV}..."
kubectl apply -f "$REPO_ROOT/gitops/argocd/applications/${ENV}.yaml"

echo ""
echo "=============================================="
echo " Bootstrap concluído!"
echo "=============================================="
echo ""
echo "Monitorar sync:"
echo "  kubectl get applications -n argocd"
echo ""
echo "Aguardar IP do Load Balancer Traefik (~2 min):"
echo "  kubectl get svc traefik -n traefik -w"
echo ""
echo "Senha inicial do ArgoCD admin:"
echo "  kubectl -n argocd get secret argocd-initial-admin-secret \\"
echo "    -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "Port-forward ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Acesse: http://localhost:8080  (user: admin)"
echo ""
