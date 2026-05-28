# Estratégia de promoção

## Princípio: Build Once, Deploy Everywhere

A mesma imagem Docker identificada por SHA é promovida entre ambientes alterando apenas a referência no GitOps.

## Fluxo staging → production

### 1. Desenvolvimento

```bash
# Alteração em app/ → merge para main
# GitHub Actions builda e publica:
#   sa-saopaulo-1.ocir.io/{namespace}/dito-api:{sha}
```

### 2. Deploy automático em staging

ArgoCD Application `dito-api-staging` observa `manifests/overlays/staging/`.

Após merge, CI (ou PR manual) atualiza:

```yaml
# manifests/overlays/staging/kustomization.yaml
images:
  - name: sa-saopaulo-1.ocir.io/namespace/dito-api
    newTag: abc1234  # SHA do commit
```

ArgoCD sincroniza automaticamente (`automated: selfHeal, prune`).

### 3. Promoção para production

1. Abrir PR alterando **somente** `manifests/overlays/production/kustomization.yaml`
2. Tag imutável: `v1.0.0` ou SHA já validado em staging
3. Review + merge com approval
4. **Sync manual** no ArgoCD (`dito-api-production`)

### 4. Rollback

```bash
# Reverter tag no overlay production via git revert
git revert HEAD
# Sync manual no ArgoCD
argocd app sync dito-api-production
```

## Gates de qualidade

| Gate | staging | production |
|------|---------|------------|
| CI build + lint | ✅ | ✅ |
| Trivy scan | ✅ | ✅ |
| Terraform plan | N/A | ✅ (se iac/ mudou) |
| Review humano | Opcional | **Obrigatório** |
| ArgoCD sync | Automático | Manual |

## Referência

Padrão idêntico ao fluxo NDD Cargo documentado em ArgoCD wiki (dev → homolog → prod com re-tag de imagem).
