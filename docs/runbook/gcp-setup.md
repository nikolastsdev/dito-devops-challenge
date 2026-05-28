# Setup Google Cloud Platform

Passo a passo para conectar sua conta GCP ao projeto.

## 1. Informações que você precisa anotar

Após criar a conta trial, colete:

| Item | Onde encontrar |
|------|----------------|
| **Project ID** | Console → seletor de project → ID |
| **Billing Account ID** | Billing → Account management → formato `012345-678901-ABCDEF` |
| **Region** | `southamerica-east1` (São Paulo) |

## 2. Habilitar APIs

```bash
gcloud config set project SEU-PROJECT-ID

gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  secretmanager.googleapis.com \
  artifactregistry.googleapis.com \
  servicenetworking.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com \
  billingbudgets.googleapis.com \
  monitoring.googleapis.com
```

## 3. Autenticação local (Terraform)

```bash
gcloud auth application-default login
gcloud config set project SEU-PROJECT-ID
```

## 4. Configurar tfvars

Edite `iac/environments/staging.tfvars`:

```hcl
project_id          = "seu-project-id"
billing_account_id  = "012345-678901-ABCDEF"
budget_alert_emails = ["seu-email@gmail.com"]
db_admin_password   = # via TF_VAR ou -var
```

Senha do banco (não commitar):

```bash
export TF_VAR_db_admin_password='SuaSenhaForte123!'
```

## 5. Bootstrap do state (GCS)

```bash
gsutil mb -l southamerica-east1 gs://SEU-PROJECT-ID-dito-tfstate
gsutil versioning set on gs://SEU-PROJECT-ID-dito-tfstate
```

Depois descomente `backend "gcs"` em `iac/backend.tf`.

## 6. Apply staging

```bash
cd iac
terraform init
terraform plan -var-file=environments/staging.tfvars
terraform apply -var-file=environments/staging.tfvars
```

!!! tip "Ordem recomendada"
    1. Configure **Budget** primeiro (Console ou Terraform)
    2. Apply **staging** apenas
    3. Valide custos no Billing Reports após 24–48h
    4. Só então considere production

## 7. Kubeconfig

```bash
gcloud container clusters get-credentials dito-gke-staging \
  --region southamerica-east1 \
  --project SEU-PROJECT-ID
```

## 8. GitHub Actions (Workload Identity Federation)

Para CI sem JSON key:

1. Criar Service Account `github-actions@PROJECT.iam.gserviceaccount.com`
2. Roles: `roles/editor` (ou custom mínimo)
3. Configurar Workload Identity Federation com GitHub OIDC
4. Secrets no GitHub:

| Secret / Variable | Valor |
|-------------------|-------|
| `GCP_PROJECT_ID` (variable) | Project ID |
| `GCP_BILLING_ACCOUNT_ID` (variable) | Billing account |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Provider resource name |
| `GCP_SERVICE_ACCOUNT` | SA email |
| `TF_VAR_DB_ADMIN_PASSWORD` | Senha SQL |

Guia oficial: [google-github-actions/auth](https://github.com/google-github-actions/auth)

## 9. Atualizar manifests

Após apply, substitua placeholders:

- `PROJECT` → seu project ID
- `DB_HOST` nos ConfigMaps → IP privado Cloud SQL (output `cloud_sql_private_ip`)
- ServiceAccount annotation → email do GSA (output `workload_service_account`)

## 10. Próximo passo

Configure o orçamento: [Orçamento e custos](budget-and-costs.md)
