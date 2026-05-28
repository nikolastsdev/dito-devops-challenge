# Gerenciamento de secrets

Nenhuma senha, token ou credencial está no repositório.
Este documento descreve o fluxo completo de credenciais, do Terraform ao pod.

---

## Fluxo end-to-end

```
┌─────────────────────────────────────────────────────────────┐
│  Developer / CI                                             │
│  TF_VAR_db_admin_password (env var no GitHub Actions)      │
└──────────────────────────┬──────────────────────────────────┘
                           │ terraform apply
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  GCP Secret Manager (por project)                          │
│  Secret: "dito-db-password-staging"                        │
│  Secret: "dito-db-password-production"                     │
└──────────────────────────┬──────────────────────────────────┘
                           │ Workload Identity (sem JSON key)
                           │ KSA dito-api → GSA dito-app-staging@
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  External Secrets Operator (no cluster GKE)                │
│  ClusterSecretStore → ExternalSecret → sync a cada 1h     │
└──────────────────────────┬──────────────────────────────────┘
                           │ cria/atualiza
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Kubernetes Secret: "dito-api-secrets"                     │
│  data.db_password = <valor do Secret Manager>             │
└──────────────────────────┬──────────────────────────────────┘
                           │ secretKeyRef
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Pod dito-api                                               │
│  env DB_PASSWORD = <montado em memória, não em disco>      │
└─────────────────────────────────────────────────────────────┘
```

---

## O que vai onde

| Dado | Tipo | Onde fica | Como chega ao pod |
|------|------|-----------|-------------------|
| `DB_HOST` | Não-sensível | ConfigMap `dito-api-config` | `envFrom.configMapRef` |
| `DB_PORT` | Não-sensível | ConfigMap | `envFrom.configMapRef` |
| `DB_NAME` | Não-sensível | ConfigMap | `envFrom.configMapRef` |
| `DB_USER` | Não-sensível | ConfigMap | `envFrom.configMapRef` |
| `NODE_ENV` | Não-sensível | ConfigMap | `envFrom.configMapRef` |
| `DB_PASSWORD` | **Sensível** | GCP Secret Manager | ExternalSecret → K8s Secret → `env.secretKeyRef` |

---

## Componentes

### 1. Terraform — cria o secret no GCP

O módulo `iac/modules/secrets/` cria automaticamente durante o `terraform apply`:

```hcl
resource "google_secret_manager_secret" "db_password" {
  secret_id = "dito-db-password-staging"   # ou production
}

resource "google_secret_manager_secret_version" "db_password" {
  secret_data = var.db_password            # vem de TF_VAR_db_admin_password
}
```

O valor nunca aparece em logs, tfstate local ou outputs.
O módulo `iac/modules/iam/` cria e associa a GSA com permissão `roles/secretmanager.secretAccessor`.

### 2. Workload Identity — autenticação sem credenciais estáticas

O GKE permite que um Kubernetes Service Account (KSA) represente um Google Service Account (GSA) **sem JSON key file**.

```
KSA: dito-api (namespace dito-app)
  ↕  anotação: iam.gke.io/gcp-service-account: dito-app-staging@dito-challenge-staging.iam.gserviceaccount.com
GSA: dito-app-staging@dito-challenge-staging.iam.gserviceaccount.com
  └  roles/secretmanager.secretAccessor no project
```

O binding é criado pelo Terraform (módulo IAM). O KSA está em `manifests/base/serviceaccount.yaml`.

### 3. External Secrets Operator — ponte K8s ↔ Secret Manager

O ESO é instalado via Helm **uma vez** por cluster:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace
```

**ClusterSecretStore** — configurado uma vez após o cluster:

```bash
# staging
kubectl apply -f manifests/cluster-secret-store-staging.yaml \
  --context=gke_dito-challenge-staging_southamerica-east1_dito-gke-staging

# production
kubectl apply -f manifests/cluster-secret-store-production.yaml \
  --context=gke_dito-challenge-production_southamerica-east1_dito-gke-production
```

O `ClusterSecretStore` declara: *"para acessar o Secret Manager, use a identidade do KSA dito-api via Workload Identity"*.

**ExternalSecret** — gerenciado pelo ArgoCD via GitOps:

```yaml
# manifests/base/external-secret.yaml
spec:
  refreshInterval: 1h          # re-sync automático a cada hora
  secretStoreRef:
    name: gcp-secret-manager   # ClusterSecretStore acima
  data:
    - secretKey: db_password   # chave no K8s Secret
      remoteRef:
        key: dito-db-password-staging  # nome no Secret Manager
```

A produção usa uma chave diferente, aplicada via patch JSON 6902 no overlay:

```yaml
# manifests/overlays/production/kustomization.yaml
patches:
  - target:
      kind: ExternalSecret
      name: dito-api-secrets
    patch: |-
      - op: replace
        path: /spec/data/0/remoteRef/key
        value: dito-db-password-production
```

### 4. Kubernetes Secret — gerado pelo ESO

O ESO cria e mantém o Secret automaticamente:

```
kubectl get secret dito-api-secrets -n dito-app -o yaml
# data.db_password = <base64 da senha>
```

O Deployment referencia com `secretKeyRef` — o valor é injetado como variável de ambiente em memória, nunca escrito em disco.

---

## Rotação de senha

Para trocar a senha do banco sem downtime:

```bash
# 1. Gerar nova senha
NEW_PASS=$(openssl rand -base64 32)

# 2. Atualizar no Cloud SQL
gcloud sql users set-password postgres \
  --instance=dito-pg-staging \
  --password="$NEW_PASS" \
  --project=dito-challenge-staging

# 3. Criar nova versão no Secret Manager (a anterior é preservada)
echo -n "$NEW_PASS" | gcloud secrets versions add dito-db-password-staging \
  --data-file=- \
  --project=dito-challenge-staging

# 4. ESO sincroniza em até 1h — ou forçar:
kubectl annotate externalsecret dito-api-secrets \
  force-sync="$(date +%s)" -n dito-app
```

---

## Verificações de saúde

```bash
# Status do ExternalSecret
kubectl get externalsecret -n dito-app
# READY=True → K8s Secret foi criado e está sincronizado

# Ver eventos (útil para debug de WI ou permissão)
kubectl describe externalsecret dito-api-secrets -n dito-app

# Confirmar que o K8s Secret existe
kubectl get secret dito-api-secrets -n dito-app

# Testar endpoint de readiness (verifica conexão com DB)
curl http://<CLUSTER_IP>/health/readiness
# {"status":"ready","checks":{"database":true}}
```

---

## Erros comuns

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `ExternalSecret` com `READY=False` | WI não configurado ou GSA sem permissão | Verificar `terraform apply` do módulo IAM |
| Pod em `CrashLoopBackOff` | K8s Secret não criado ainda | Aguardar ESO ou verificar ClusterSecretStore |
| `PERMISSION_DENIED` nos logs do ESO | GSA sem `roles/secretmanager.secretAccessor` | Reconfirmar binding no Terraform |
| `ClusterSecretStore` não encontrado | ESO não instalado ou CSS não aplicado | Instalar ESO + aplicar CSS manualmente |

---

## Por que não usar K8s Secrets diretamente?

| Abordagem | Prós | Contras |
|-----------|------|---------|
| K8s Secret manual | Simples | Precisa de acesso manual ao cluster; não auditável; risco de vazar em `kubectl get` |
| ConfigMap com senha | Muito simples | ❌ Completamente inseguro — base64 não é criptografia |
| **Secret Manager + ESO** *(escolhido)* | Auditoria completa; rotação automática; sem acesso direto ao cluster para criar secrets | Mais peças para instalar (ESO) |
| Vault (HashiCorp) | Muito completo | Operação mais complexa; custo adicional para o desafio |

---

## Referências

- [External Secrets Operator — GCP Provider](https://external-secrets.io/latest/provider/google-secrets-manager/)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [GCP Secret Manager](https://cloud.google.com/secret-manager/docs)
- [ClusterSecretStore — staging](../../manifests/cluster-secret-store-staging.yaml)
- [ClusterSecretStore — production](../../manifests/cluster-secret-store-production.yaml)
- [ExternalSecret — base](../../manifests/base/external-secret.yaml)
- [IAM module](../../iac/modules/iam/)
- [Secrets module](../../iac/modules/secrets/)
