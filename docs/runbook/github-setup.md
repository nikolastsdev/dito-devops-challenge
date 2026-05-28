# GitHub Setup

Guia para publicar o repositório e ativar GitHub Pages + CI/CD.

## 1. Criar repositório

No Cursor terminal:

```bash
cd dito-devops-challenge
git init
git add .
git commit -m "feat: scaffold desafio DevOps III — OCI, GitOps, GitHub Actions"
gh auth login
gh repo create dito-devops-challenge --public --source=. --remote=origin --push
```

Ou via GitHub UI: https://github.com/new → nome `dito-devops-challenge`

## 2. Habilitar GitHub Pages

1. Repositório → **Settings** → **Pages**
2. Source: **GitHub Actions** (não "Deploy from branch")
3. O workflow `docs.yml` publica automaticamente no push para `main`

URL final: **https://nikolasschafer.github.io/dito-devops-challenge/**

## 3. Environments (approval gates)

Settings → Environments → criar:

| Environment | Protection rules |
|-------------|------------------|
| `staging` | Opcional — deploy automático |
| `production` | **Required reviewers** (você mesmo) |
| `github-pages` | Criado automaticamente pelo Pages |

## 4. Secrets (quando for executar na OCI)

Settings → Secrets and variables → Actions:

| Secret | Descrição |
|--------|-----------|
| `TF_VAR_DB_ADMIN_PASSWORD` | Senha admin Autonomous DB |
| `OCI_TENANCY_OCID` | Tenancy OCID |
| `OCIR_AUTH_TOKEN` | Token auth OCIR |
| `OCIR_USERNAME` | `{namespace}/{username}` |

| Variable | Descrição |
|----------|-----------|
| `OCI_COMPARTMENT_OCID` | Compartment OCID |
| `OCIR_NAMESPACE` | Tenancy namespace OCIR |

!!! tip "Modo simulado"
    Sem secrets, os workflows rodam em modo simulado (`echo` dos comandos) —
    suficiente para o desafio conforme enunciado.

## 5. Autenticar `gh` no Cursor

```bash
gh auth login
# GitHub.com → HTTPS → Login with browser (ou token)
gh auth status
```

## 6. Verificar workflows

Após push, abra **Actions** no GitHub e confirme:

- ✅ Documentation (Pages)
- ✅ Terraform (validate)
- ✅ App Build (lint + build)
