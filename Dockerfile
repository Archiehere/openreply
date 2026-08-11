FROM node:22-bookworm-slim AS base
WORKDIR /app
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*

FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

FROM deps AS builder
COPY . .
RUN npm run build

# Web app: Next.js standalone output only, no source or full node_modules.
FROM base AS web
ENV NODE_ENV=production
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]

# Worker: runs TS directly via tsx, so it needs full node_modules + source.
FROM deps AS worker
ENV NODE_ENV=production
COPY . .
RUN npm run db:generate
CMD ["npm", "run", "worker"]
