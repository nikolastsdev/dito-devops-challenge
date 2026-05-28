# Validação de Manifests (recomendação)

Conforme o enunciado do desafio, para a pasta `manifests/` recomenda-se o seguinte workflow de validação **sem necessidade de implementação completa**.

## Pipeline proposto (PR)

```yaml
# .github/workflows/manifests-validate.yml (futuro)
jobs:
  validate:
    steps:
      - run: kubectl kustomize manifests/overlays/staging
      - run: kubectl kustomize manifests/overlays/production
      - run: kubeconform -summary -output json manifests/overlays/staging
      - run: kube-score score manifests/overlays/staging
      - run: conftest test manifests/overlays/staging --policy policies/
```

## Ferramentas

| Ferramenta | Propósito |
|------------|-----------|
| **kustomize build** | Garantir que overlays compilam |
| **kubeconform** | Validar schema Kubernetes (Deployment, Service, etc.) |
| **kube-score** | Boas práticas: probes, limits, replicas |
| **conftest (OPA/Rego)** | Policies customizadas |
| **trivy config** | Scan de misconfigurations em YAML |

## Policies sugeridas (conftest)

```rego
# policies/required_probes.rego
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.livenessProbe
  msg := "Container must have livenessProbe"
}

deny[msg] {
  input.kind == "Deployment"
  input.spec.replicas < 2
  msg := "Production workloads require >= 2 replicas"
}
```

## Checklist manual (PR review)

O workflow [`pr-review.yml`](../../.github/workflows/pr-review.yml) posta automaticamente:

- [ ] ≥ 2 réplicas
- [ ] liveness + readiness probes
- [ ] resource requests/limits
- [ ] `runAsNonRoot: true`
- [ ] secrets via ExternalSecret (não plain text)
- [ ] Service tipo ClusterIP (acesso interno)
- [ ] topologySpreadConstraints / podAntiAffinity

## Por que não implementar agora?

O enunciado pede **descrever a abordagem** no README/docs. A implementação completa seria o próximo passo com mais tempo — ver [Limitações](../risks/limitations.md).
