# ADR-005: ArgoCD + Kustomize

## Status

Aceito

## Contexto

Configurar entrega GitOps com sync automático (staging) e manual com aprovação (production).

## Decisão

**ArgoCD** com manifests **Kustomize** (base + overlays).

## Alternativas

| Ferramenta | Avaliação |
|------------|-----------|
| **FluxCD** | Excelente; autor usa ArgoCD em produção NDD Cargo |
| Helm puro | Mais templates; Kustomize mais declarativo para overlays |
| kubectl apply na pipeline | Anti-GitOps; descartado |

## Sync policies

| Ambiente | Policy |
|----------|--------|
| staging | `automated: { prune: true, selfHeal: true }` |
| production | Sem `automated` — sync manual no ArgoCD UI/CLI |

## Consequências

- Promoção = PR alterando tag no overlay production
- Histórico Git auditable
- Padrão idêntico ao `ndd-cargo-argocd` (dev/homolog/prod)

Ver [Fluxo GitOps](../architecture/gitops-flow.md).
