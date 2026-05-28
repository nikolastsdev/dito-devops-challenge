# ADR-004: Secret Manager + Workload Identity

## Status

Aceito

## Contexto

Secret Manager com secret referenciado pelo workload + IAM mínimo.

## Decisão

1. **Secret Manager** — secret `dito-db-password-{env}`
2. **External Secrets Operator** — sync para K8s Secret
3. **GSA + Workload Identity** — sem JSON keys em pods

## Fluxo

```
Terraform → Secret Manager (db_password)
                ↓
ExternalSecret → K8s Secret
                ↓
Pod ← secretKeyRef + ServiceAccount (WI)
```

## IAM mínimo (GSA)

| Role | Propósito |
|------|-----------|
| `roles/secretmanager.secretAccessor` | Ler secret |
| `roles/cloudsql.client` | Conectar Cloud SQL |

## Consequências

- `manifests/base/serviceaccount.yaml` com annotation WI
- `manifests/base/external-secret.yaml` com ClusterSecretStore GCP

Módulos: `iac/modules/secrets/`, `iac/modules/iam/`
