# Terraform (GCP)

## Validar localmente

```bash
cd iac
terraform init -backend=false
terraform fmt -recursive
terraform validate
```

## Plan staging (requer gcloud auth)

```bash
gcloud auth application-default login
export TF_VAR_db_admin_password='SuaSenhaForte123!'

terraform plan \
  -var-file=environments/staging.tfvars \
  -var="project_id=SEU-PROJECT-ID"
```

## Módulos

| Módulo | Recursos GCP |
|--------|--------------|
| `backend` | GCS bucket (state) |
| `network` | VPC, subnet, NAT, PSA, firewall |
| `kubernetes` | GKE cluster + node pool |
| `database` | Cloud SQL PostgreSQL |
| `secrets` | Secret Manager |
| `iam` | GSA + Workload Identity |
| `registry` | Artifact Registry |
| `budget` | Billing Budget + alertas e-mail |

## Backend remoto (GCS)

Ver [`iac/backend.tf`](../../iac/backend.tf) e [Setup GCP](gcp-setup.md).

## Variáveis cost-optimized

| Variável | Staging | Efeito |
|----------|---------|--------|
| `use_public_nodes` | `true` | Sem Cloud NAT ($$$) |
| `use_preemptible_nodes` | `true` | ~70% desconto nodes |
| `machine_type` | `e2-small` | Menor VM |
| `cloud_sql_tier` | `db-f1-micro` | Menor SQL |
| `node_count` | `1` | Mínimo |

## Outputs

`gke_cluster_name`, `cloud_sql_private_ip`, `artifact_registry_url`, `workload_service_account`, `estimated_monthly_cost_brl`
