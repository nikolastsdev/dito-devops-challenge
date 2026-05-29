# Diagramas de arquitetura

Documentação visual da arquitetura escolhida para o Desafio DevOps III: **dois GCP Projects** isolados, **Terraform com módulos oficiais Google**, **GKE + Cloud SQL + Secret Manager**, **GitOps com ArgoCD** e **CI/CD via GitHub Actions**.

---

## 1. Visão macro — multi-project

Dois projects GCP na **mesma billing account** (créditos trial R$ 1.700 / 90 dias), região **southamerica-east1 (São Paulo)**.

```mermaid
flowchart TB
    subgraph Billing["Billing Account (trial R$ 1.700)"]
        Budget["Billing Budget<br/>alertas e-mail BRL"]
    end

    subgraph GitHub["GitHub — nikolastsdev/dito-devops-challenge"]
        Repo["Monorepo<br/>iac · app · manifests · gitops · docs"]
        GHA["GitHub Actions<br/>4 workflows"]
        Pages["GitHub Pages<br/>MkDocs"]
    end

    subgraph Staging["Project: dito-challenge-staging"]
        STG_VPC["VPC 10.10.0.0/16"]
        STG_GKE["GKE 1× e2-small preemptible"]
        STG_SQL["Cloud SQL db-f1-micro"]
        STG_AR["Artifact Registry"]
        STG_SM["Secret Manager"]
        STG_GCS["GCS tfstate"]
    end

    subgraph Production["Project: dito-challenge-production"]
        PRD_VPC["VPC 10.20.0.0/16"]
        PRD_GKE["GKE 2× e2-small preemptible"]
        PRD_SQL["Cloud SQL db-f1-micro"]
        PRD_AR["Artifact Registry"]
        PRD_SM["Secret Manager"]
        PRD_GCS["GCS tfstate"]
    end

    Budget --> Staging
    Budget --> Production
    GHA -->|terraform apply| Staging
    GHA -->|terraform apply + approval| Production
    GHA -->|docker push| STG_AR
    GHA -->|update manifests| Repo
    Repo --> Pages
    Repo -->|GitOps sync| STG_GKE
    Repo -->|GitOps sync manual| PRD_GKE
```

| Aspecto | Staging | Production |
|---------|---------|------------|
| Project ID | `dito-challenge-staging` | `dito-challenge-production` |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| GKE nodes | 1× e2-small preemptible | 2× e2-small preemptible |
| Cloud NAT | Desabilitado (`use_public_nodes=true`) | Desabilitado (trial) |
| Cloud SQL | db-f1-micro | db-f1-micro |
| Budget | Criado aqui (`enable_budget=true`) | Não recria (`enable_budget=false`) |
| Terraform apply (trial) | Automático no merge `main` | Com gate `environment: production` |

---

## 2. Topologia por project (GCP)

Cada project é provisionado de forma **independente** pelo Terraform, com state remoto isolado.

```mermaid
flowchart TB
    subgraph Internet
        Users["Usuários / Load Balancer"]
        GitHub["GitHub Actions<br/>Workload Identity Federation"]
    end

    subgraph GCP["GCP Project (staging ou production)"]
        subgraph Network["Módulo: terraform-google-modules/network"]
            VPC["VPC + subnet privada"]
            FW["Firewall rules"]
            NAT["Cloud NAT<br/>(opcional — desabilitado no trial)"]
        end

        subgraph Compute["Módulo: kubernetes-engine/private-cluster"]
            GKE["GKE Private Cluster"]
            NP["Node Pool<br/>preemptible e2-small"]
        end

        subgraph Data["Módulo: sql-db/postgresql"]
            SQL["Cloud SQL PostgreSQL<br/>Private IP"]
        end

        subgraph Security["Módulos: secrets + workload-identity"]
            SM["Secret Manager<br/>DB password, etc."]
            WI["Workload Identity<br/>KSA ↔ GSA"]
        end

        subgraph Registry["Artifact Registry (nativo)"]
            AR["dito-api-staging repo<br/>imagens :sha"]
        end

        subgraph State["GCS Backend"]
            TFState["{project-id}-tfstate<br/>terraform.tfstate"]
        end
    end

    subgraph GKE_Workloads["Pods no GKE"]
        Argo["ArgoCD"]
        API["dito-api Deployment"]
        ESO["External Secrets Operator"]
        Ingress["Ingress / Service"]
    end

    Users --> Ingress
    GitHub -->|OIDC + SA| GKE
    GitHub -->|terraform apply| TFState
    GitHub -->|docker push| AR

    VPC --> GKE
    VPC --> SQL
    GKE --> NP
    Argo --> API
    API --> ESO
    ESO -->|sync| SM
    API -->|Private IP| SQL
    WI --> ESO
    WI --> API
    Ingress --> API
    NAT -.->|egress se habilitado| Internet
    NP -.->|public nodes no trial| Internet
```

---

## 3. Mapeamento Terraform → módulos oficiais

Wrappers locais em `iac/modules/` encapsulam módulos **`terraform-google-modules`**.

```mermaid
flowchart LR
    subgraph Root["iac/ (root module)"]
        ENV["environments/*.tfvars"]
        BE["backends/*.gcs.tfbackend"]
    end

    subgraph Modules["iac/modules/"]
        NET["network<br/>~> 10.0"]
        K8S["kubernetes<br/>private-cluster ~> 33.1"]
        DB["database<br/>postgresql ~> 25.2"]
        IAM["iam<br/>workload-identity ~> 33.1"]
        SEC["secrets<br/>Secret Manager"]
        REG["registry<br/>Artifact Registry"]
        BUD["budget<br/>Billing Budget"]
    end

    subgraph Official["terraform-google-modules"]
        M_NET["network + cloud-router"]
        M_GKE["kubernetes-engine"]
        M_SQL["sql-db"]
    end

    ENV --> Root
    BE --> Root
    Root --> NET & K8S & DB & IAM & SEC & REG & BUD
    NET --> M_NET
    K8S --> M_GKE
    DB --> M_SQL
    IAM --> M_GKE
```

| Wrapper local | Módulo upstream | Recursos principais |
|---------------|-----------------|---------------------|
| `modules/network/` | `network` + `cloud-router` | VPC, subnet, NAT (opcional) |
| `modules/kubernetes/` | `private-cluster` | GKE, node pool, IP aliases |
| `modules/database/` | `postgresql` | Cloud SQL, usuário, DB |
| `modules/iam/` | `workload-identity` | GSA + binding KSA |
| `modules/secrets/` | nativo | Secret Manager versions |
| `modules/registry/` | nativo | Docker repo Artifact Registry |
| `modules/budget/` | nativo | Budget BRL + alertas |

**Providers:** `google` / `google-beta` **6.50.0** (compatibilidade GKE v33 + cloud-router v6).

---

## 4. Fluxo de secrets e identidade

Credenciais **nunca** ficam no Git. Pipeline injeta senha DB; cluster consome via External Secrets.

```mermaid
sequenceDiagram
    participant TF as Terraform (GHA)
    participant SM as Secret Manager
    participant WI as Workload Identity
    participant ESO as External Secrets
    participant Pod as dito-api Pod
    participant SQL as Cloud SQL

    Note over TF,SM: Bootstrap infra
    TF->>SM: Cria secret db-admin-password
    TF->>WI: GSA + binding KSA external-secrets

    Note over ESO,Pod: Runtime no cluster
    ESO->>SM: Lê secret (via GSA/WI)
    ESO->>Pod: Kubernetes Secret montado
    Pod->>SQL: Conexão PostgreSQL (private IP)
```

| Origem | Secret | Destino |
|--------|--------|---------|
| GitHub Secret `TF_VAR_DB_ADMIN_PASSWORD` | Senha admin DB | Terraform → Secret Manager |
| Secret Manager | `db-admin-password` | ExternalSecret → K8s Secret |
| Workload Identity | GSA `external-secrets@...` | ESO pod autentica no GCP |
| GitHub OIDC | WIF Provider | GHA autentica sem JSON key |

---

## 5. GitOps — fonte da verdade

Um único repositório; ambientes separados por **overlays Kustomize**.

```mermaid
flowchart TB
    subgraph Repo["Git Repository"]
        Base["manifests/base/<br/>Deployment, Service, Ingress"]
        STG_OV["overlays/staging/<br/>imagem por digest (sha256)"]
        PRD_OV["overlays/production/<br/>mesmo digest promovido"]
        ArgoApps["gitops/argocd/applications/"]
    end

    subgraph StagingCluster["GKE Staging"]
        ArgoSTG["ArgoCD App<br/>dito-api-staging"]
        PodsSTG["dito-api pods"]
    end

    subgraph ProdCluster["GKE Production"]
        ArgoPRD["ArgoCD App<br/>dito-api-production"]
        PodsPRD["dito-api pods"]
    end

    Base --> STG_OV
    Base --> PRD_OV
    ArgoApps --> ArgoSTG
    ArgoApps --> ArgoPRD
    STG_OV -->|auto-sync| ArgoSTG --> PodsSTG
    PRD_OV -->|sync manual| ArgoPRD --> PodsPRD
```

---

## 6. Fluxo de dados da aplicação

```mermaid
flowchart LR
    Client["Browser / curl"] --> LB["Ingress / LoadBalancer"]
    LB --> SVC["Service dito-api"]
    SVC --> Pod["Pod dito-api<br/>Express + React estático"]
    Pod --> PG["Cloud SQL PostgreSQL"]
    Pod --> Health["/health endpoint"]

    subgraph Build["Fora do cluster"]
        CI["GHA app-build"] --> AR["Artifact Registry<br/>:github.sha"]
        AR --> Pod
    end
```

---

## 7. Decisões de custo (trial)

```mermaid
mindmap
  root((Cost-aware trial))
    Compute
      preemptible nodes
      e2-small
      1 node staging / 2 production
    Network
      public nodes
      sem Cloud NAT
      economia ~R$ 180/mês
    Database
      db-f1-micro ambos
    FinOps
      budget único R$ 1700
      alertas e-mail
      apply production gated
```

---

## Referências

- [Visão geral](overview.md)
- [Rede](network.md)
- [Fluxo GitOps](gitops-flow.md)
- [Diagramas de pipeline](../ci-cd/pipeline-diagrams.md)
- [ADR 007 — Módulos Terraform oficiais](../decisions/007-official-terraform-modules.md)
