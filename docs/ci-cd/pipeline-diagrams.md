# Diagramas de pipeline CI/CD

Visão completa dos **4 workflows GitHub Actions**, gates de ambiente, promoção GitOps e integração com GCP.

---

## 1. Panorama geral

```mermaid
flowchart TB
    subgraph Triggers["Eventos GitHub"]
        PR["Pull Request"]
        PushMain["Push → main"]
        PRAny["PR aberto/atualizado"]
    end

    subgraph Workflows[".github/workflows/"]
        TF["terraform.yml"]
        APP["app-build.yml"]
        DOCS["docs.yml"]
        REV["pr-review.yml"]
    end

    subgraph Outputs["Saídas"]
        STG_GCP["GCP Staging"]
        PRD_GCP["GCP Production"]
        AR["Artifact Registry"]
        Pages["GitHub Pages"]
        Comment["Comentário PR"]
    end

    PR -->|paths: iac/**| TF
    PushMain -->|paths: iac/**| TF
    PR -->|paths: app/**| APP
    PushMain -->|paths: app/**| APP
    PR -->|paths: docs/**| DOCS
    PushMain -->|paths: docs/**| DOCS
    PRAny --> REV

    TF --> STG_GCP
    TF --> PRD_GCP
    APP --> AR
    DOCS --> Pages
    REV --> Comment
    APP -->|update overlay| STG_GCP
```

| Workflow | Arquivo | Trigger (paths) | Merge `main` |
|----------|---------|-----------------|--------------|
| Terraform | `terraform.yml` | `iac/**`, `scripts/**` | apply staging → apply production |
| App Build | `app-build.yml` | `app/**` | push imagem `:sha` |
| Documentation | `docs.yml` | `docs/**`, `mkdocs.yml` | deploy GitHub Pages |
| PR Review | `pr-review.yml` | qualquer PR | comentário checklist |

---

## 2. Pipeline Terraform (`terraform.yml`)

### 2.1 Pull Request — plan only

Nunca aplica infra em PR. Valida sintaxe e gera planos para **ambos** os projects (se vars configuradas).

```mermaid
flowchart TD
    Start["PR com mudanças em iac/**"] --> Validate

    subgraph Validate["Job: validate"]
        FMT["terraform fmt -check"]
        INIT["terraform init -backend=false"]
        VAL["terraform validate"]
    end

    Validate --> PlanSTG["Job: plan-staging"]
    Validate --> PlanPRD["Job: plan-production"]

    PlanSTG --> AuthSTG["google-github-actions/auth<br/>Workload Identity Federation"]
    AuthSTG --> InitSTG["init backends/staging.gcs.tfbackend"]
    InitSTG --> PlanS["plan -var-file=staging.tfvars"]
    PlanS --> ArtSTG["artifact: plan-staging.txt"]

    PlanPRD --> AuthPRD["auth WIF"]
    AuthPRD --> InitPRD["init backends/production.gcs.tfbackend"]
    InitPRD --> PlanP["plan -var-file=production.tfvars"]
    PlanP --> ArtPRD["artifact: plan-production.txt"]
```

**Condições:**

- `plan-staging`: roda se `vars.GCP_PROJECT_ID_STAGING != ''`
- `plan-production`: roda se `vars.GCP_PROJECT_ID_PRODUCTION != ''`
- Secret: `TF_VAR_db_admin_password` via `secrets.TF_VAR_DB_ADMIN_PASSWORD`

### 2.2 Push `main` — apply com gates

```mermaid
flowchart TD
    Merge["Merge em main<br/>paths: iac/**"] --> NeedPlan["needs: plan-staging"]
    NeedPlan --> ApplySTG["Job: apply-staging"]

    subgraph ApplySTG["environment: staging"]
        A1["init staging backend"]
        A2["terraform apply staging.tfvars<br/>-auto-approve"]
    end

    ApplySTG --> ApplyPRD["Job: apply-production"]
    ApplyPRD --> Gate{"GitHub Environment<br/>production<br/>required reviewers?"}

    Gate -->|aprovado| ApplyPRDJob["terraform apply production.tfvars"]
    Gate -->|pendente| Wait["Pipeline aguarda"]

    subgraph ApplyPRDJob["environment: production"]
        P1["init production backend"]
        P2["apply production.tfvars"]
    end
```

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GHA as terraform.yml
    participant STG as GCP Staging
    participant PRD as GCP Production

    Dev->>GH: PR iac/ → review → merge main
    GHA->>GHA: validate + plan (artifacts)
    GHA->>STG: apply-staging (auto)
    Note over GHA,PRD: environment gate
    GHA->>GH: aguarda approval "production"
    Dev->>GH: aprova deploy production
    GHA->>PRD: apply-production
```

**Autenticação GCP (todos os jobs apply/plan):**

```mermaid
flowchart LR
    GHA["GitHub Actions"] -->|OIDC token| WIF["Workload Identity<br/>Provider"]
    WIF --> SA["Service Account<br/>terraform@..."]
    SA --> APIs["GCP APIs<br/>GKE, SQL, IAM, ..."]
```

Secrets necessários:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `TF_VAR_DB_ADMIN_PASSWORD`

---

## 3. Pipeline App (`app-build.yml`)

Build, scan e push da imagem Docker para **Artifact Registry** (project staging).

### 3.1 Pull Request

```mermaid
flowchart LR
    PR["PR app/**"] --> Install["npm install<br/>server + web"]
    Install --> Lint["npm run lint"]
    Lint --> Build["npm run build"]
    Build --> Docker["docker build<br/>tag :github.sha"]
    Docker --> Trivy["Trivy scan<br/>CRITICAL/HIGH → SARIF"]
```

### 3.2 Push `main`

```mermaid
flowchart TD
    Merge["merge main app/**"] --> BuildJob["Job: build<br/>(mesmos passos do PR)"]
    BuildJob --> PushJob["Job: push<br/>needs: build"]

    subgraph PushJob["environment: staging"]
        Auth["google-github-actions/auth"]
        GCloud["setup-gcloud"]
        Push["docker push<br/>southamerica-east1-docker.pkg.dev/.../dito-api:sha"]
    end

    PushJob --> Sim{"vars.GCP_PROJECT_ID<br/>configurado?"}
    Sim -->|não| Notice["simula push<br/>::notice::"]
    Sim -->|sim| Real["push real para AR"]
```

**Imagem produzida:**

```
southamerica-east1-docker.pkg.dev/{GCP_PROJECT_ID}/dito-api-staging/dito-api:{github.sha}
```

---

## 4. Pipeline Docs (`docs.yml`)

```mermaid
flowchart TD
    Trigger["push/PR docs/** ou mkdocs.yml"] --> Build["Job: build"]
    Build --> Pip["pip install requirements-docs.txt"]
    Pip --> MkDocs["mkdocs build"]
    MkDocs --> Artifact["upload-pages-artifact"]

    Trigger --> DeployCheck{"ref == main?"}
    DeployCheck -->|sim| Deploy["Job: deploy<br/>environment: github-pages"]
    Deploy --> Pages["actions/deploy-pages@v4"]
    Pages --> URL["nikolasschafer.github.io/dito-devops-challenge"]
    DeployCheck -->|PR| BuildOnly["apenas build — sem deploy"]
```

**Concurrency:** `group: pages` com `cancel-in-progress: true` — evita deploys paralelos.

---

## 5. Pipeline PR Review (`pr-review.yml`)

```mermaid
flowchart TD
    PR["PR opened / synchronize / reopened"] --> Kust["kubectl kustomize<br/>staging + production"]
    PR --> TFmt["terraform fmt -check<br/>(se iac/ alterado)"]
    Kust --> Script["github-script"]
    TFmt --> Script
    Script --> Comment["Comentário no PR<br/>checklist ia/app/manifests/docs"]
```

Checklist automático:

- ✅/⬜ Alterações em `iac/`, `app/`, `manifests/`, `docs/`
- Recomendações: kubeconform, kube-score, conftest
- Link para [validação de manifests](manifests-validation.md)

---

## 6. Fluxo end-to-end — da feature ao production

Integração **CI (build)** + **GitOps (deploy)** + **IaC (infra)**.

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Developer
    participant GH as GitHub Repo
    participant AppCI as app-build.yml
    participant AR as Artifact Registry
    participant ArgoS as ArgoCD Staging
    participant ArgoP as ArgoCD Production
    participant STG as GKE Staging
    participant PRD as GKE Production

    Note over Dev,GH: Fase 1 — desenvolvimento
    Dev->>GH: PR app/ → merge main
    AppCI->>AppCI: lint + build + Trivy
    AppCI->>AR: push dito-api:abc123
    Dev->>GH: PR atualiza overlay staging<br/>image tag → abc123
    ArgoS->>STG: auto-sync deploy abc123

    Note over Dev,PRD: Fase 2 — promoção
    Dev->>GH: PR staging tag → production tag
    Note over GH: code review + approval
    Dev->>ArgoP: Sync manual (production)
    ArgoP->>PRD: deploy mesma imagem abc123
```

### Build Once, Deploy Everywhere

```mermaid
flowchart LR
    SHA["Imagem única<br/>:abc123"] --> STG_OV["overlay staging"]
    SHA --> PRD_OV["overlay production<br/>(via PR)"]
    STG_OV --> STG["GKE Staging<br/>auto"]
    PRD_OV --> PRD["GKE Production<br/>manual sync"]
```

---

## 7. Matriz de gates e ambientes GitHub

```mermaid
flowchart TB
    subgraph Environments["GitHub Environments"]
        E_STG["staging"]
        E_PRD["production"]
        E_PAGES["github-pages"]
    end

    TF_STG["terraform apply-staging"] --> E_STG
    TF_PRD["terraform apply-production"] --> E_PRD
    APP_PUSH["app-build push"] --> E_STG
    DOCS_DEP["docs deploy"] --> E_PAGES

    E_PRD --> Reviewers["Required reviewers<br/>(configurar no repo)"]
```

| Job | Environment | Proteção recomendada |
|-----|-------------|----------------------|
| `apply-staging` | `staging` | Opcional |
| `apply-production` | `production` | **Required reviewers** |
| `push` (app) | `staging` | Opcional |
| `deploy` (docs) | `github-pages` | Padrão GitHub Pages |

---

## 8. Ordem típica de bootstrap

```mermaid
flowchart TD
    A["1. bootstrap-gcp-projects.sh<br/>cria 2 projects + buckets tfstate"] --> B["2. Configurar WIF + SA + GitHub secrets/vars"]
    B --> C["3. terraform apply staging<br/>(local ou GHA)"]
    C --> D["4. Instalar ArgoCD nos clusters"]
    D --> E["5. Aplicar gitops/argocd/applications/"]
    E --> F["6. merge app/ → imagem no AR"]
    F --> G["7. Atualizar overlay staging → auto deploy"]
    G --> H["8. PR promoção → production sync manual"]
```

---

## Referências

- [Workflows (detalhe textual)](workflows.md)
- [Estratégia de promoção](promotion-strategy.md)
- [Fluxo GitOps](../architecture/gitops-flow.md)
- [Diagramas de arquitetura](../architecture/diagrams.md)
- [Setup GitHub](../runbook/github-setup.md)
