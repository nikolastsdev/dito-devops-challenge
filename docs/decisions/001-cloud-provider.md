# ADR-001: Google Cloud Platform

## Status

Aceito (revisão — migrado de OCI)

## Contexto

O desafio permite GCP, AWS ou Azure. A Dito usa majoritariamente **GCP**.

Conta trial ativa: **R$ 1.700 em créditos / 90 dias**.

## Decisão

Usar **Google Cloud Platform**, região **southamerica-east1** (São Paulo).

## Justificativa

| Critério | GCP |
|----------|-----|
| Alinhamento Dito | Ambiente interno majoritariamente GCP |
| Créditos trial | R$ 1.700 para validar execução real |
| GKE | Managed Kubernetes maduro |
| Cloud SQL PostgreSQL | Atende requisito Postgres nativamente |
| Secret Manager | Integração Workload Identity |
| Billing Budget | Alertas nativos em BRL |

## Alternativas descartadas

| Provider | Motivo |
|----------|--------|
| OCI | Free tier, mas sem créditos trial ativos |
| AWS | EKS caro (~US$ 73/mês control plane) |
| Azure | Menor alinhamento com Dito |

## Análise de custo — GCP vs OCI

A Oracle Cloud (OCI) tem custo menor em TCO puro graças ao **Always Free** permanente.
A decisão por GCP foi baseada em alinhamento e execução real dentro dos créditos trial.

| Critério | OCI | GCP (decisão) |
|----------|-----|---------------|
| Custo longo prazo | ✅ Always Free (sem expiração) | ❌ Pós-trial é pago |
| Custo no trial (90 dias) | ✅ $0 dentro do free tier | ✅ ~R$ 103/mês — cobre 16+ meses com staging |
| 2 ambientes isolados | ⚠️ Free tier tem caps de shape/região | ✅ 2 GCP Projects, billing única |
| Alinhamento com Dito | ❌ | ✅ GCP é o ambiente interno |
| FinOps demonstrável | Parcial (sem budget nativo em BRL) | ✅ Billing Budget BRL nativo |
| Kubernetes gerenciado | OKE (free tier com limites) | GKE (1 cluster zonal free por billing account) |

**Conclusão:** OCI compensa mais em TCO puro de longo prazo. GCP foi escolhido por
alinhamento organizacional, execução real dentro do trial e narrativa FinOps exigida
pelo desafio. A decisão não foi "qual cloud é mais barata no absoluto", e sim "qual
entrega mais valor para este desafio dentro de um orçamento finito".

## Estimativa de custo real (GCP Calculator — 2026-05-28)

Baseado em GCP Pricing Calculator, PostgreSQL, região southamerica-east1, e2-medium preemptible:

| Cenário | USD/mês | R$/mês | Trial 90 dias |
|---------|---------|--------|---------------|
| Staging only (1º cluster — free tier) | ~$25 | ~R$ 145 | R$ 435 — cabe com margem ✅ |
| Staging + Production (2 clusters) | ~$126 | ~R$ 732 | R$ 2.196 — estourou ⚠️ |

> **Custo dominante ao ter 2 clusters:** GKE control plane = $73/mês fixo por cluster adicional,
> independente de quantas horas o cluster roda. O compute e SQL são secundários.

> VM escolhida: `e2-medium` preemptible (1 vCPU, 4 GB RAM) — 4,6× mais barato que N4 para
> a mesma carga de lab. ArgoCD + ESO + dito-api rodam sem OOMKill com 4 GB.

## Consequências

- Terraform provider `hashicorp/google`
- Módulo `budget` para alertas de custo em BRL
- VM `e2-medium` preemptible em staging
- Production apenas como código/tfvars — não aplicado no trial
- Detalhes: [Orçamento e custos](../runbook/budget-and-costs.md)
