# Terraform — First Run & State Management

## O problema do ovo e da galinha

O pipeline usa **Workload Identity Federation (WIF)** para autenticar no GCP sem chave JSON.  
Mas o WIF é um recurso GCP criado *pelo próprio Terraform*.

```
Pipeline precisa de WIF para autenticar no GCP
           ↕
    WIF é criado pelo Terraform
           ↕
Terraform no pipeline precisa de WIF para rodar
```

A solução padrão da indústria é simples: **a primeira execução é sempre local**.  
Ela cria toda a infraestrutura, incluindo o WIF. A partir daí, o pipeline assume.

---

## As 4 Fases do Bootstrap

```
┌─────────────────────────────────────────────────────────────────┐
│  FASE 1 — Bootstrap (local, única vez)                          │
│  script: scripts/bootstrap-gcp-projects.sh                      │
│  ─────────────────────────────────────────────────────────────  │
│  • Cria 2 GCP Projects (staging / production)                   │
│  • Habilita APIs necessárias                                    │
│  • Cria buckets GCS para Terraform state                        │
│                                                                 │
│  Requer: gcloud auth login + billing account ID                 │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 2 — Primeiro terraform apply (local, única vez)           │
│  script: scripts/tf-first-apply.sh <env>                        │
│  ─────────────────────────────────────────────────────────────  │
│  • terraform init  →  conecta ao backend GCS (bucket da F1)     │
│  • terraform plan  →  mostra o que será criado                  │
│  • terraform apply →  provisiona TODA a infra:                  │
│      GKE · Cloud SQL · Secret Manager · Artifact Registry       │
│      IAM workload identity (pods → Secret Manager)              │
│      Workload Identity Federation (GitHub Actions → GCP)  ←★   │
│                                                                 │
│  Requer: gcloud auth application-default login                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 3 — Configurar GitHub Secrets (local, única vez)          │
│  script: scripts/configure-github-secrets.sh <env>              │
│  ─────────────────────────────────────────────────────────────  │
│  • Lê terraform output (WIF provider URL + CI SA email)         │
│  • Configura no GitHub via gh CLI:                              │
│      GCP_WORKLOAD_IDENTITY_PROVIDER                             │
│      GCP_SERVICE_ACCOUNT                                        │
│      GCP_PROJECT_ID_STAGING / GCP_PROJECT_ID_PRODUCTION         │
│      TF_VAR_DB_ADMIN_PASSWORD  (manual — não sai do Terraform)  │
│                                                                 │
│  Requer: gh auth login                                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 4 — Pipeline assume (para sempre)                         │
│  workflow: .github/workflows/terraform.yml                      │
│  ─────────────────────────────────────────────────────────────  │
│  PR com mudanças em iac/**                                      │
│    └─ fmt-check → validate → plan (staging + production)        │
│                                                                 │
│  merge em main                                                  │
│    ├─ terraform apply staging    (automático)                   │
│    └─ terraform apply production (aprovação manual no GitHub)   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Terraform State

### Onde fica

O state é armazenado em **Google Cloud Storage**, um bucket por projeto:

| Ambiente   | Bucket                             | Prefixo           |
|------------|-----------------------------------|-------------------|
| staging    | `dito-challenge-staging-tfstate`  | `terraform/state` |
| production | `dito-challenge-production-tfstate` | `terraform/state` |

O arquivo de configuração do backend fica em `iac/backends/`:

```hcl
# iac/backends/staging.gcs.tfbackend
bucket = "dito-challenge-staging-tfstate"
prefix = "terraform/state"
```

O `iac/backend.tf` usa **partial configuration** (sem valores hardcoded):

```hcl
terraform {
  backend "gcs" {}  # valores injetados via -backend-config no init
}
```

### Como o pipeline usa o state

```
terraform init -backend-config=backends/staging.gcs.tfbackend
      │
      ▼
 Conecta ao bucket GCS com autenticação WIF
      │
      ├── terraform plan  →  lê state atual do GCS → calcula delta
      │
      └── terraform apply →  executa mudanças → atualiza state no GCS
```

### State locking

O GCS fornece **locking automático** via metadados de objeto.  
Quando um `apply` começa, ele cria um lock file no bucket.  
Se outro processo tentar aplicar simultaneamente, recebe:

```
Error acquiring the state lock
```

Não é necessária nenhuma configuração extra — o provider Google ativa por padrão.

### Versionamento

O bucket tem **Object Versioning** habilitado (feito pelo bootstrap).  
Isso significa que cada `terraform apply` gera uma nova versão do state no GCS.

Para recuperar um state anterior:

```bash
# Listar versões
gsutil ls -a gs://dito-challenge-staging-tfstate/terraform/state/

# Recuperar versão específica
gsutil cp "gs://dito-challenge-staging-tfstate/terraform/state/default.tfstate#<generation>" \
  terraform.tfstate.backup
```

---

## O que acontece no pipeline

### Em Pull Requests

```yaml
# terraform.yml (simplificado)
on:
  pull_request:
    paths: ['iac/**']

jobs:
  validate:
    - terraform fmt -check
    - terraform validate

  plan:
    - google-github-actions/auth@v2  # autentica via WIF (sem chave JSON)
    - terraform init -backend-config=backends/staging.gcs.tfbackend
    - terraform plan -var-file=environments/staging.tfvars
    # plan salvo como artefato do GitHub Actions
```

O `plan` é postado como comentário no PR para revisão.

### Em merge para `main`

```
main branch push
    │
    ├── apply staging  (automático, ~5 min)
    │       terraform apply → state atualizado no GCS
    │
    └── apply production  (requer aprovação manual)
            GitHub environment gate → revisor aprova
            terraform apply → state atualizado no GCS
```

---

## Workload Identity Federation — como funciona

```
GitHub Actions token  →  Google STS  →  SA de curta duração
(JWT do workflow)          exchange      (sem chave JSON)
```

1. GitHub emite um **OIDC token** (JWT) para o workflow  
2. `google-github-actions/auth@v2` troca esse token no **Google STS**  
3. O STS valida:  
   - Issuer: `https://token.actions.githubusercontent.com`  
   - `attribute.repository == "nikolastsdev/dito-devops-challenge"`  
4. STS retorna credenciais temporárias para o **CI Service Account**  
5. O Terraform usa essas credenciais para operar no GCP  

**Nenhuma chave JSON é gerada ou armazenada.**

O módulo `iac/modules/github-wif` cria:

| Recurso | Nome |
|---------|------|
| WIF Pool | `dito-github-pool` |
| WIF Provider | `github-provider` |
| CI Service Account | `dito-ci@<project>.iam.gserviceaccount.com` |
| IAM Binding | `dito-ci` pode impersonar o SA via WIF |

---

## Checklist de primeiro deploy

```bash
# 1. Autenticar localmente
gcloud auth login
gcloud auth application-default login
gh auth login

# 2. Fase 1 — Bootstrap
export GCP_BILLING_ACCOUNT_ID="012345-678901-ABCDEF"
./scripts/bootstrap-gcp-projects.sh

# 3. Editar tfvars com seus IDs reais
vim iac/environments/staging.tfvars     # billing_account_id, project_id
vim iac/environments/production.tfvars

# 4. Fase 2 — Primeiro apply (staging)
export TF_VAR_db_admin_password="SenhaForte123!"
./scripts/tf-first-apply.sh staging

# 5. Fase 3 — Configurar GitHub Secrets (staging)
./scripts/configure-github-secrets.sh staging

# 6. Repetir Fases 2 e 3 para production
./scripts/tf-first-apply.sh production
./scripts/configure-github-secrets.sh production

# 7. Fase 4 — a partir de agora, use o pipeline
git push origin main
```

---

## FAQ

**"Posso pular as fases locais e usar o pipeline desde o início?"**  
Não. O pipeline precisa de WIF para autenticar, e WIF é criado pelo Terraform.  
É um ciclo. A única saída é o primeiro apply local.

**"O state pode ser corrompido?"**  
O versionamento do GCS + state locking torna isso muito improvável.  
Em caso de corrompimento: `terraform state pull > backup.tfstate` antes de qualquer recuperação.

**"E se o apply falhar no meio?"**  
O Terraform salva o state parcial no GCS. No próximo `apply`, ele tenta continuar do ponto onde parou. Recursos já criados não são recriados.

**"Como vejo o state atual?"**  
```bash
terraform init -backend-config=backends/staging.gcs.tfbackend
terraform show
terraform state list
```

**"Como destruir tudo?"**  
```bash
terraform destroy -var-file=environments/staging.tfvars
# CUIDADO: isso apaga GKE, Cloud SQL, dados — sem volta fácil
```
