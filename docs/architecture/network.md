# Rede (VPC)

## Requisito

> VPC com pelo menos uma subnet privada e um NAT

## Implementação GCP

| Recurso | Propósito |
|---------|-----------|
| **VPC** | Rede custom (`10.10.0.0/16` staging) |
| **Subnet privada** | Nodes GKE + secondary ranges (pods/services) |
| **Cloud Router + NAT** | Egress para nodes privados |
| **Private Service Access** | Cloud SQL com IP privado |
| **Firewall** | Tráfego interno + health checks GCP |

## Cost hack (staging)

`use_public_nodes = true` **desabilita Cloud NAT** — economia ~R$ 150–220/mês.

Trade-off: nodes com IP público (aceitável para staging/dev).

## Módulo

`iac/modules/network/`

## NAT em production

Production usa `use_public_nodes = false` → NAT habilitado (melhor prática).
