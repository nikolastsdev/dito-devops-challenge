# IaC — Módulos oficiais Google Cloud

Este diretório usa **wrappers finos** em torno dos módulos oficiais [`terraform-google-modules`](https://github.com/terraform-google-modules), conforme recomendado pela documentação GCP:

- [Terraform on Google Cloud](https://cloud.google.com/docs/terraform)
- [Provision GKE with Terraform](https://cloud.google.com/kubernetes-engine/docs/terraform)
- [Terraform blueprints](https://cloud.google.com/docs/terraform/blueprints/terraform-blueprints)

## Padrão wrapper

```
iac/modules/<domínio>/main.tf   → chama módulo oficial do Registry
iac/environments/*.tfvars       → parâmetros por ambiente
iac/backends/*.gcs.tfbackend    → state isolado por GCP project
```

## Módulos oficiais utilizados

| Domínio | Módulo oficial | Versão | Submodule |
|---------|----------------|--------|-----------|
| **Rede** | [network/google](https://registry.terraform.io/modules/terraform-google-modules/network/google) | ~> 10.0 | — |
| **Cloud NAT** | [cloud-router/google](https://registry.terraform.io/modules/terraform-google-modules/cloud-router/google) | ~> 6.0 | — |
| **GKE** | [kubernetes-engine/google](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google) | ~> 33.1 | `//modules/private-cluster` |
| **Cloud SQL** | [sql-db/google](https://registry.terraform.io/modules/terraform-google-modules/sql-db/google) | ~> 25.2 | `//modules/postgresql` |
| **Workload Identity** | kubernetes-engine | ~> 33.1 | `//modules/workload-identity` |

## Recursos nativos (sem módulo oficial dedicado)

| Recurso | Motivo |
|---------|--------|
| Private Service Access (Cloud SQL) | Padrão documentado GCP — [configure private IP](https://cloud.google.com/sql/docs/postgres/configure-private-ip) |
| Secret Manager | Provider `google_secret_manager_*` — módulo oficial não necessário |
| Artifact Registry | Provider `google_artifact_registry_*` |
| Billing Budget | Provider `google_billing_budget` |

## Providers

| Provider | Versão |
|----------|--------|
| hashicorp/google | >= 6.47, < 7.0 |
| hashicorp/google-beta | >= 6.47, < 7.0 |

> **Nota de compatibilidade:** `kubernetes-engine` v44+ exige `google` >= 7.17, conflitando com `cloud-router` v6 (< 7.0). Por isso usamos **GKE v33.1** + **network v10** + **google 6.50** — conjunto validado com `terraform validate`.

## Apply por ambiente

```bash
./scripts/tf-apply.sh staging plan
./scripts/tf-apply.sh staging apply
./scripts/tf-apply.sh production apply
```

Ver também: [Multi-project setup](../docs/runbook/multi-project-setup.md)
