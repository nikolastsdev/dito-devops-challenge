# Orçamento e custos GCP

Guia para **não ser cobrado além dos créditos** (R$ 1.700 / 90 dias).

---

## Estimativa GCP Calculator (referência final)

Estimativa gerada em **2026-05-28** via GCP Pricing Calculator.
Configuração: **PostgreSQL · e2-medium Spot · southamerica-east1 · 180h (simulação 1 semana)**.

### Breakdown do CSV (180h — 1 semana de uso)

| SKU | Região | Qtd | USD |
|-----|--------|-----|-----|
| GKE Zonal Cluster (control plane) | global | 1 mês **fixo** | **$73,00** |
| E2 Spot Core (e2-medium) | southamerica-east1 | 180 core-h | $1,14 |
| E2 Spot RAM (e2-medium) | southamerica-east1 | 720 GB-h | $0,61 |
| Balanced PD (disco do node) | southamerica-east1 | 2,5 GB | $0,38 |
| PostgreSQL micro (180h) | **southamerica-east1** | 180h | $2,84 |
| PostgreSQL storage (50 GB × 180h) | **southamerica-east1** | 9.000 GB-h | $3,14 |
| **Total CSV** | | | **$81,12** |

!!! warning "GKE control plane é custo fixo mensal"
    O $73 é cobrado **independente de quantas horas** o cluster fica ligado — 1h ou 730h no mês, o valor é o mesmo.
    Representa **90% do custo total** nessa simulação de 180h.
    Esse custo só existe para o **2º cluster** — o 1º zonal por billing account é gratuito.

### Extrapolação para mês completo (730h)

| Recurso | 180h (CSV) | 730h (mês) | R$/mês |
|---------|-----------|-----------|--------|
| GKE control plane | $73,00 | $73,00 | ~R$ 423 |
| E2-medium Spot compute | $1,75 | **$7,10** | ~R$ 41 |
| PostgreSQL micro | $2,84 | **$11,52** | ~R$ 67 |
| Storage 10 GB | ~$0,70 | **$2,55** | ~R$ 15 |
| PD, SM, AR, GCS, egress | ~$0,75 | **$3,00** | ~R$ 17 |
| **Total (2º cluster)** | — | **~$97/mês** | **~R$ 563/mês** |
| **Total (1º cluster — free)** | — | **~$24/mês** | **~R$ 139/mês** |

> **VM confirmada pelo CSV:** 180 core-hours ÷ 180h = 1 vCPU · 720 GB-hours ÷ 180h = 4 GB → **`e2-medium`**, exatamente o configurado em `staging.tfvars`.

---

## Projeção real por cenário

### Cenário A — Staging only (recomendado para o trial)

| Recurso | Config | USD/mês | R$/mês |
|---------|--------|---------|--------|
| GKE control plane | Zonal — **free tier** (1º cluster da billing account) | **$0** | R$ 0 |
| GKE node | 1× e2-medium Spot, 730h | $7,10 | ~R$ 41 |
| Balanced PD (disco node) | 10 GB | $1,50 | ~R$ 9 |
| Cloud SQL | PostgreSQL db-f1-micro, 10 GB, southamerica-east1 | $14,07 | ~R$ 82 |
| Cloud NAT | **Desabilitado** (`use_public_nodes=true`) | $0 | R$ 0 |
| Secret Manager | 2–3 secrets | $0,10 | ~R$ 1 |
| Artifact Registry | ~1 GB imagens | $1,50 | ~R$ 9 |
| GCS (state) | < 1 GB | $0,05 | ~R$ 0 |
| Egress | Baixo (dev) | $1,00 | ~R$ 6 |
| **Total staging** | | **~$25/mês** | **~R$ 145/mês** |

```
R$ 1.700 ÷ R$ 145/mês ≈ 11,7 meses só com staging
Trial = 90 dias → créditos ficam bem tranquilos ✅
```

### Cenário B — Staging + Production (2 clusters)

| Recurso | Extra vs cenário A | USD/mês | R$/mês |
|---------|--------------------|---------|--------|
| GKE control plane — production | **2º cluster cobrado** (sem free tier) | +$73,00 | +R$ 423 |
| GKE nodes — production | 2× e2-medium Spot | +$14,20 | +R$ 82 |
| Cloud SQL — production | PostgreSQL db-f1-micro | +$14,07 | +R$ 82 |
| **Total 2 clusters** | | **~$126/mês** | **~R$ 732/mês** |

```
R$ 1.700 ÷ R$ 732 ≈ 2,3 meses → cabe no trial (90 dias), mas com margem mínima ⚠️
```

!!! warning "Free tier GKE — detalhe importante"
    O GCP fornece **1 cluster zonal gratuito por billing account** (não por project).
    Como os 2 projects compartilham a mesma billing account, apenas o cluster de **staging** é free.
    O cluster de **production** paga **$73/mês fixo** pelo control plane — independente de quantas horas rodar.

!!! danger "Recomendação para o trial"
    Para o desafio, **staging real + production como código** é o perfil ideal.
    Ativar o 2º cluster (production) adiciona $73/mês fixo — torna o trial apertado.

---

## Escolha de VM — análise de custo

Recomendação: **`e2-medium` preemptible** para staging.

| VM | vCPU | RAM | Custo preemptible/mês (730h) | Adequação |
|----|------|-----|------------------------------|-----------|
| `e2-micro` | 0.25 | 1 GB | ~R$ 8 | ❌ RAM insuficiente — ArgoCD + app = OOMKill |
| `e2-small` | 0.5 | 2 GB | ~R$ 16 | ⚠️ Funciona, mas sem folga para 3+ pods |
| **`e2-medium`** | 1 | 4 GB | **~R$ 23** | ✅ ArgoCD + dito-api + ESO sem pressão |
| `e2-standard-2` | 2 | 8 GB | ~R$ 60 | ✅ Confortável, custo 2.5× sem ganho real |

ArgoCD + External Secrets Operator + dito-api consomem ~2–2,5 GB de RAM em estado idle.
`e2-small` (2 GB) fica com < 200 MB livres → pods evicados frequentemente.

Configuração em `staging.tfvars`:
```hcl
machine_type          = "e2-medium"
use_preemptible_nodes = true
node_count            = 1
```

---

## Comparativo E2 vs N4 (do CSV da calculadora)

| Família | Geração | e2-medium preemptible (730h) | n4-standard-2 spot (730h) |
|---------|---------|------------------------------|---------------------------|
| E2 | 2ª geração | **~$4,00/mês** | — |
| N4 | 4ª geração | — | ~$25,00/mês |
| Diferença | — | **6× mais barato** | — |

> N4 tem melhor performance por vCPU, mas para um lab que vai ficar ocioso a maior parte do tempo, E2 é a escolha correta de FinOps.

---

## Painel que você precisa monitorar

| Onde | URL / caminho | O que ver |
|------|---------------|-----------|
| **Billing Overview** | [console.cloud.google.com/billing](https://console.cloud.google.com/billing) | Gasto total vs créditos |
| **Reports** | Billing → Reports | Custo por serviço (GKE, SQL, NAT…) |
| **Budgets & alerts** | Billing → Budgets & alerts | Alertas configurados |
| **Cost table** | Billing → Cost table | Detalhe diário por SKU |
| **GKE** | Kubernetes Engine → Clusters | Nodes ativos |
| **Cloud SQL** | SQL → Instâncias | Tier e status (RUNNABLE) |

### Configurar alertas (Terraform + Console)

O módulo `iac/modules/budget/` cria automaticamente:

- Orçamento de **R$ 1.700** filtrado pela billing account
- Alertas em **25%, 50%, 75%, 90% e 100%**
- E-mail para os endereços em `budget_alert_emails`

No Console (backup manual):

1. Billing → **Budgets & alerts** → Create Budget
2. Amount: **R$ 1.700**
3. Thresholds: 50%, 90%, 100%
4. Conecte seu e-mail

!!! warning "Créditos vs cobrança"
    Enquanto houver créditos, a fatura mostra **R$ 0 a pagar** — mas o **Reports** ainda mostra o consumo real.
    Monitore o **consumo**, não só "amount due".

---

## Maiores vilões de custo (evitar)

| Serviço | Por que é caro | Como evitamos |
|---------|----------------|---------------|
| **2º GKE cluster** | $73/mês control plane | Não aplicar production no trial |
| **Cloud NAT** | ~$32/mês + egress | `use_public_nodes=true` em staging |
| **N4 / n2 nodes** | 3–6× vs E2 | `e2-medium` preemptible |
| **Cloud SQL grande** | db-n1-* ou regional | `db-f1-micro` zonal |
| **Load Balancer externo** | ~$18/mês | ClusterIP interno |
| **Flow logs VPC** | Por GB logado | Desabilitado em staging |

---

## Checklist anti-surpresa

- [ ] Billing Budget criado (Terraform ou Console)
- [ ] E-mail de alerta configurado
- [ ] `staging.tfvars` com `use_public_nodes = true`
- [ ] `use_preemptible_nodes = true`
- [ ] `machine_type = "e2-medium"`
- [ ] `node_count = 1` em staging
- [ ] **Não** aplicar `production.tfvars` no trial
- [ ] Verificar Billing Reports semanalmente
- [ ] `terraform destroy` quando terminar o desafio

---

## Comandos úteis

```bash
# Ver custo por serviço
gcloud billing accounts list
gcloud billing projects describe SEU-PROJECT-ID

# Parar Cloud SQL quando não usar (economiza ~60% compute SQL)
gcloud sql instances patch dito-pg-staging --activation-policy NEVER

# Religar quando precisar
gcloud sql instances patch dito-pg-staging --activation-policy ALWAYS

# Ver nodes GKE
gcloud container clusters describe dito-gke-staging --region southamerica-east1

# Destruir tudo (fim do desafio)
cd iac && terraform destroy -var-file=environments/staging.tfvars
```

---

## O que acontece após os 90 dias?

1. Créditos acabam → cobrança no cartão cadastrado
2. Se não configurou budget → pode ser cobrado sem aviso prévio claro
3. **Solução:** `terraform destroy` antes do fim OU desativar billing no project

Para **desativar billing** (último recurso):

Billing → Account management → **Close billing account** (só se não tiver outros projects).

Mais seguro: **delete o project** após exportar o que precisar.
