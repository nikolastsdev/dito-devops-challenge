# ADR-006: GitHub Actions

## Status

Aceito

## Contexto

Pipeline CI/CD em GitHub Actions conforme estrutura `iac/`, `app/`, `manifests/`.

## Decisão

Quatro workflows:

| Workflow | Responsabilidade |
|----------|------------------|
| `terraform.yml` | fmt, validate, plan (PR); apply staging/prod (main) |
| `app-build.yml` | lint, build, Trivy, push OCIR |
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
