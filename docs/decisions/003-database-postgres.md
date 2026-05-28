# ADR-003: Cloud SQL PostgreSQL

## Status

Aceito

## Contexto

Requisito: Postgres gerenciado.

## Decisão

**Cloud SQL for PostgreSQL 15**, tier `db-f1-micro` (staging).

## Justificativa

| Aspecto | Cloud SQL |
|---------|-----------|
| Requisito Postgres | Nativo |
| Custo staging | ~R$ 45–65/mês (db-f1-micro) |
| IP privado | Via Private Service Access |
| Backups | Automáticos |

## Alternativas

| Opção | Avaliação |
|-------|-----------|
| Postgres em GKE (pod) | Não gerenciado — descartado |
| AlloyDB | Overkill e caro para desafio |

## Consequências

- Private IP only (`ipv4_enabled = false`)
- Senha replicada no Secret Manager
- Pode ser **parado** via CLI quando não usar (economia)

Módulo: `iac/modules/database/`
