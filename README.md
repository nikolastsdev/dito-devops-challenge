# Dito DevOps Challenge

Repositório de entrega do **Desafio DevOps III** — infraestrutura GCP, GitOps, CI/CD e controle de custos.

## Estrutura

| Pasta | Descrição |
|-------|-----------|
| [`iac/`](iac/) | Terraform — GCP (VPC, GKE, Cloud SQL, Secret Manager, Artifact Registry) |
| [`app/`](app/) | API NestJS (TypeScript) + frontend React — app **Groove** (playlists) |
| [`manifests/`](manifests/) | Kubernetes (Kustomize) + Workload Identity + External Secrets |
| [`gitops/`](gitops/) | ArgoCD Applications |
| [`docs/`](docs/) | MkDocs — [documentação publicada](https://nikolastsdev.github.io/dito-devops-challenge/) |

---

## Executar localmente

### Docker Compose (recomendado)

```bash
cd app/
docker compose up -d --build
```

Aguarda o build (~2 min na primeira vez) e acesse **http://localhost:8080**.  
O banco é populado automaticamente com 22 músicas no primeiro startup.

```bash
# Logs em tempo real
docker compose logs -f api

# Derrubar (mantém dados)
docker compose down

# Derrubar + apagar banco
docker compose down -v
```

### Sem Docker (hot-reload para desenvolvimento)

```bash
# 1. Postgres
docker run -d --name groove-pg \
  -e POSTGRES_DB=groove -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=changeme-local-only \
  -p 5432:5432 postgres:16-alpine

# 2. Copiar env
cd app && cp .env.example .env

# 3. Backend (porta 8080)
cd server && npm install && npm run dev

# 4. Frontend com proxy (porta 5173 → 8080)
cd web && npm install && npm run dev
```

---

## Cloud: Google Cloud Platform

| Recurso | Serviço GCP |
|---------|-------------|
| VPC + NAT | VPC, Cloud NAT |
| Kubernetes | **GKE** (southamerica-east1) |
| PostgreSQL | **Cloud SQL** |
| Secrets | **Secret Manager** + Workload Identity |
| Registry | **Artifact Registry** |
| State | **GCS** |
| Orçamento | **Billing Budget** (alertas em BRL) |

## Dois ambientes (2 GCP Projects)

Staging e production rodam em **projects separados** na mesma billing account (créditos compartilhados).

| Project | ID | Custo ~mês |
|---------|----|-----------|
| Staging | `dito-challenge-staging` | ~R$ 145 (1 cluster free) |
| Production | `dito-challenge-production` | ~R$ 563 (2º cluster $73 fixo) |

Guia completo: [`docs/runbook/multi-project-setup.md`](docs/runbook/multi-project-setup.md)

---

## Secrets — fluxo de credenciais

Nenhuma senha toca o repositório. Fluxo end-to-end:

```
Terraform apply
    └─→ GCP Secret Manager: "dito-db-password-staging"
            └─→ External Secrets Operator (via Workload Identity)
                    └─→ Kubernetes Secret: dito-api-secrets
                            └─→ Pod env var: DB_PASSWORD
```

| Dado | Onde fica | Como chega ao pod |
|------|-----------|-------------------|
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` | ConfigMap | `envFrom.configMapRef` |
| `DB_PASSWORD` | GCP Secret Manager | ExternalSecret → K8s Secret → `env.secretKeyRef` |

Sem JSON key files. A autenticação usa **Workload Identity Federation** (KSA → GSA).

Guia completo: [`docs/runbook/secrets-setup.md`](docs/runbook/secrets-setup.md)

---

## Bootstrap GCP

```bash
# 1. Criar projects + buckets de state
export GCP_BILLING_ACCOUNT_ID="012345-678901-ABCDEF"
./scripts/bootstrap-gcp-projects.sh

# 2. Preencher tfvars com IDs reais
# iac/environments/staging.tfvars   → project_id, billing_account_id, budget_alert_emails
# iac/environments/production.tfvars → idem

# 3. Aplicar infraestrutura staging
export TF_VAR_db_admin_password='SenhaForte123!'
./scripts/tf-apply.sh staging apply

# 4. (Opcional) Aplicar production — atenção ao custo
./scripts/tf-apply.sh production apply
```

Detalhes: [`docs/runbook/gcp-setup.md`](docs/runbook/gcp-setup.md)

## Controle de custos (R$ 1.700 / 90 dias)

- `e2-medium` preemptible, `db-f1-micro`, sem Cloud NAT em staging
- Billing Budget com alertas 25% → 100%
- Production como **código/tfvars** — não aplicar no trial

Estimativa real (GCP Calculator): [`docs/runbook/budget-and-costs.md`](docs/runbook/budget-and-costs.md)

---

## Autor

[Nikolass Schaffer](https://github.com/nikolastsdev)
