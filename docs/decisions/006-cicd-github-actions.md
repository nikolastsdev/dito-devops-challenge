# ADR-006: GitHub Actions

## Status

Aceito

## Contexto

Pipeline CI/CD em GitHub Actions conforme estrutura `iac/`, `app/`, `manifests/`.

## Decisão

Workflows separados por ciclo de vida (evita grafo poluído e isola operação destrutiva):

| Workflow | Responsabilidade |
|----------|------------------|
| `terraform-staging.yml` | fmt, validate, plan (PR); plan→apply→bootstrap (push main) |
| `terraform-production.yml` | dispatch gated: plan \| apply→bootstrap (1 aprovação) |
| `terraform-destroy.yml` | dispatch gated + confirm: drain → destroy staged |
| `app-build.yml` | lint, build, Trivy, push por digest → overlay staging |
| `app-promote.yml` | dispatch gated: copia digest staging→production |
| `docs.yml` | MkDocs → GitHub Pages |
| `pr-review.yml` | Checklist automatizado + comentário no PR |

## Padrões de segurança

- Secrets via `secrets.*` — nunca echo em logs
- `environment: production` com approval gate no GitHub
- Modo simulado quando credenciais OCI ausentes (permitido pelo desafio)
- Trivy SARIF upload para GitHub Security

## Alternativas

| Opção | Avaliação |
|-------|-----------|
| Azure DevOps | Experiência NDD Cargo; desafio pede GitHub Actions |
| GitLab CI | Não aplicável |

## Agentes de IA

Workflow `pr-review.yml` posta checklist inteligível no PR. Extensível para:

- Resumo de `terraform plan`
- Review de manifests (probes, replicas, securityContext)

## Consequências

Workflows em [`.github/workflows/`](../../.github/workflows/).

Documentação: [Workflows](../ci-cd/workflows.md).
