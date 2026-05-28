# ADR-007: Módulos Terraform oficiais Google

## Status

Aceito

## Contexto

O IaC inicial usava recursos nativos (`google_container_cluster`, etc.) escritos manualmente. Para alinhar com **documentação GCP** e **boas práticas Dito**, migramos para módulos oficiais `terraform-google-modules`.

## Decisão

Usar **wrappers locais** que delegam para módulos do Terraform Registry:

| Wrapper | Módulo oficial |
|---------|----------------|
| `modules/network/` | `terraform-google-modules/network` + `cloud-router` |
| `modules/kubernetes/` | `kubernetes-engine//modules/private-cluster` |
| `modules/database/` | `sql-db//modules/postgresql` |
| `modules/iam/` | `kubernetes-engine//modules/workload-identity` |

## Referências GCP

| Documento | URL |
|-----------|-----|
| Terraform on Google Cloud | https://cloud.google.com/docs/terraform |
| GKE + Terraform | https://cloud.google.com/kubernetes-engine/docs/terraform |
| Private clusters | https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters |
| Workload Identity | https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity |
| Cloud SQL private IP | https://cloud.google.com/sql/docs/postgres/configure-private-ip |
| Terraform blueprints | https://cloud.google.com/docs/terraform/blueprints/terraform-blueprints |

## Alternativas consideradas

| Opção | Avaliação |
|-------|-----------|
| Recursos nativos only | Legível, mas não segue blueprints Google |
| CFT / fabric (enterprise) | Overkill para desafio |
| kubernetes-engine v44 + google 7.x | Conflito de provider com cloud-router v6 |

## Compatibilidade de versões

Conjunto pinado e validado:

```
network/google         ~> 10.0
cloud-router/google    ~> 6.0
kubernetes-engine      ~> 33.1
sql-db/postgresql      ~> 25.2
hashicorp/google       >= 6.47, < 7.0
```

## Consequências

- `.terraform.lock.hcl` deve ser commitado
- `terraform init -upgrade` pode exigir revisão se módulos forem atualizados
- Documentação em `iac/README.md`

## MCP GCP

Não há MCP oficial Google Cloud no Cursor. Referências via docs + Registry + `gcloud` CLI.
