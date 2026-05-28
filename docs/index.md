# Dito DevOps Challenge — GCP

Infraestrutura **Google Cloud Platform** para o Desafio DevOps III.

## Destaques

- **GKE** + **Cloud SQL PostgreSQL** + **Secret Manager**
- **Billing Budget** com alertas em BRL (R$ 1.700 trial)
- Perfil **cost-optimized** em staging (~R$ 140–230/mês)
- GitOps ArgoCD + GitHub Actions

## Comece por aqui

1. [Setup GCP](runbook/gcp-setup.md)
2. [Orçamento e custos](runbook/budget-and-costs.md) ← **leia antes do apply**
3. [Desenvolvimento local](runbook/local-development.md)
4. [ADRs](decisions/index.md)

## Créditos trial

| | |
|---|---|
| Valor | R$ 1.700 |
| Prazo | 90 dias |
| Staging estimado | ~R$ 180/mês |
| Margem | ~9 meses se só staging |

!!! warning
    Configure **Billing Budget** antes do primeiro `terraform apply`.
