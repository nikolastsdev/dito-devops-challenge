# ADR-002: Google Kubernetes Engine (GKE)

## Status

Aceito

## Contexto

Requisito: cluster Kubernetes gerenciado.

## Decisão

**GKE Standard** via módulo oficial [`terraform-google-modules/kubernetes-engine//modules/private-cluster`](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/private-cluster) v33.1.

## Referência GCP

- [Provision GKE with Terraform](https://cloud.google.com/kubernetes-engine/docs/terraform)
- [Private clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

## Configuração cost-optimized (staging)

| Parâmetro | Valor | Motivo |
|-----------|-------|--------|
| `machine_type` | e2-small | Menor VM billável |
| `use_preemptible_nodes` | true | ~70% desconto |
| `node_count` | 1 | Mínimo para demo |
| `use_public_nodes` | true | Evita Cloud NAT |

## Configuração production (simulada)

| Parâmetro | Valor |
|-----------|-------|
| `machine_type` | e2-medium |
| `node_count` | 2 |
| `use_preemptible_nodes` | false |
| `use_public_nodes` | false (private + NAT) |

## Consequências

- Workload Identity habilitado
- Secondary IP ranges para pods/services
- Módulo wrapper: `iac/modules/kubernetes/` → delega para `private-cluster` oficial
