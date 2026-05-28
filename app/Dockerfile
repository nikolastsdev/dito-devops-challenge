# syntax=docker/dockerfile:1

# --- Build frontend ---
FROM node:20-alpine AS web-build
WORKDIR /app/web
COPY web/package*.json ./
RUN npm install
COPY web/ ./
RUN npm run build

# --- Build backend ---
FROM node:20-alpine AS server-build
WORKDIR /app/server
COPY server/package*.json ./
RUN npm install
COPY server/ ./
RUN npm run build

# --- Production ---
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=8080

COPY server/package*.json ./
RUN npm install --omit=dev

COPY --from=server-build /app/server/dist ./dist
COPY --from=web-build /app/web/dist ./public

EXPOSE 8080
USER node

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/health/liveness || exit 1

CMD ["node", "dist/main"]
