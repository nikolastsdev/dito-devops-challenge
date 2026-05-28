# Riscos e limitações

## Limitações

| Limitação | Mitigação |
|-----------|-----------|
| Créditos R$ 1.700 / 90 dias | Budget alerts + staging cost-optimized |
| Cloud NAT caro | Desabilitado em staging (`use_public_nodes=true`) |
| Nodes preemptible | Podem ser interrompidos — OK para staging |
| Production cara | **Não aplicar** no trial — só código/tfvars |
| External Secrets bootstrap | ClusterSecretStore manual pós-GKE |

## Riscos financeiros

| Risco | Probabilidade | Ação |
|-------|---------------|------|
| Esgotar créditos antes de 90 dias | Baixa (só staging) | Billing Reports semanal |
| Cobrança pós-trial | Média se esquecer destroy | `terraform destroy` + delete project |
| Cloud SQL rodando 24/7 | Alta | Parar instância quando não usar |
| Production apply acidental | Média | GitHub Environment approval |

## O que faria com mais tempo

1. Workload Identity Federation completo no GitHub Actions
2. GKE Autopilot (comparar custo vs Standard)
3. Cloud SQL Auth Proxy sidecar
4. Manifests validate workflow (kubeconform)
5. FinOps dashboard (Billing export → BigQuery)

## Adequação ao desafio

Execução real em **GCP staging** dentro dos créditos trial — alinhado ao ambiente Dito e ao enunciado.

Documentação de custos: [Orçamento e custos](runbook/budget-and-costs.md)
