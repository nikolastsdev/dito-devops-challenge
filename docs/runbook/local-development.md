# Desenvolvimento local

## Aplicação (Node.js + React)

```bash
cd app
cp .env.example .env
npm install
npm install --prefix server
npm install --prefix web
npm run dev
```

| Serviço | URL |
|---------|-----|
| API | http://localhost:3000 |
| Frontend (Vite) | http://localhost:5173 |
| Health liveness | http://localhost:3000/health/liveness |
| Health readiness | http://localhost:3000/health/readiness |
| Status JSON | http://localhost:3000/api/status |

## Build de produção

```bash
cd app
npm run build
npm start
```

Acesse http://localhost:3000 — o Express serve o React buildado de `server/public/`.

## Docker

```bash
docker build -t dito-api:local app/
docker run -p 8080:8080 \
  -e DB_PASSWORD=local-secret \
  -e DB_HOST=localhost \
  dito-api:local
```

## Variáveis de ambiente

| Variável | Sensível | Origem K8s |
|----------|----------|------------|
| `APP_NAME` | Não | ConfigMap |
| `LOG_LEVEL` | Não | ConfigMap |
| `DB_HOST` | Não | ConfigMap |
| `DB_PORT` | Não | ConfigMap |
| `DB_NAME` | Não | ConfigMap |
| `DB_PASSWORD` | **Sim** | Secret / ExternalSecret |
| `NODE_ENV` | Não | ConfigMap / overlay patch |
