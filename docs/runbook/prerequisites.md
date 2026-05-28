# Pré-requisitos

## Para desenvolvimento local (app)

| Ferramenta | Versão mínima |
|------------|---------------|
| Node.js | 20+ |
| npm | 10+ |
| Docker | 24+ (opcional, para build de imagem) |

## Para IaC

| Ferramenta | Versão mínima |
|------------|---------------|
| Terraform | 1.5+ |
| Conta OCI | Opcional (validate funciona sem credenciais reais) |

## Para Kubernetes / GitOps

| Ferramenta | Uso |
|------------|-----|
| kubectl | Validar Kustomize (`kubectl kustomize`) |
| kustomize | Overlays staging/production |
| ArgoCD CLI | Sync manual production (opcional) |

## Para documentação

```bash
pip install -r requirements-docs.txt
```

## Credenciais OCI (opcional — execução real)

1. Criar API key em OCI Console → User Settings
2. Salvar em `~/.oci/oci_api_key.pem`
3. Configurar `~/.oci/config` com tenancy, user, fingerprint, region
4. Adicionar secrets no GitHub (ver [GitHub Setup](github-setup.md))
