# Workflows CI/CD

> **Diagramas completos:** [Diagramas de pipeline](pipeline-diagrams.md) — visão macro, Terraform PR vs apply, app-build, docs, promoção end-to-end.

## Visão geral

| Workflow | Trigger | Jobs |
|----------|---------|------|
| [`terraform.yml`](../../.github/workflows/terraform.yml) | PR/push `iac/**` | validate → plan-staging/production → apply-staging → apply-production |
| [`app-build.yml`](../../.github/workflows/app-build.yml) | PR/push `app/**` | build + Trivy → push Artifact Registry |
| [`docs.yml`](../../.github/workflows/docs.yml) | push `docs/**` | MkDocs build → GitHub Pages |
| [`pr-review.yml`](../../.github/workflows/pr-review.yml) | PR aberto | checklist automatizado |

## Terraform pipeline

```mermaid
flowchart LR
    PR[Pull Request] --> FMT[fmt check]
    FMT --> VAL[validate]
    VAL --> PLAN_S[plan staging]
    VAL --> PLAN_P[plan production]

    Main[merge main] --> STG[apply staging]
    STG --> PROD[apply production]
    PROD --> APPROVAL{environment gate}
```

- **PR:** apenas plan — nunca apply
- **main:** staging automático; production com `environment: production` (approval)

## App pipeline

1. `npm install` + lint TypeScript
2. `npm run build` (React + Express)
3. `docker build` → tag `:github.sha`
4. Trivy scan (CRITICAL/HIGH)
5. Push Artifact Registry (`southamerica-east1-docker.pkg.dev/.../dito-api-staging/dito-api`)

## Gestão de secrets

- Credenciais via GitHub Secrets — nunca hardcoded
- Workflows usam `secrets.*` sem echo
- `TF_VAR_db_admin_password` injetado como env var
- GCP auth via Workload Identity Federation (sem JSON key)

## Manifests (`manifests/`)

Conforme enunciado: **descrever** validação, não implementar workflow dedicado.

Ver [Validação de Manifests](manifests-validation.md).
