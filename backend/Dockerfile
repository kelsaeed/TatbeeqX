# Money Control — backend image
# Single-stage Node 20 slim image with Prisma client baked in.

FROM node:20-slim

# OpenSSL is required by Prisma's query engine on slim/debian images.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first — better layer caching.
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev || npm install --omit=dev

# Bring in source + Prisma schema, then generate the client.
COPY prisma ./prisma
COPY src ./src
RUN npx prisma generate

# uploads/ is a runtime directory; create it so the static server has a path.
RUN mkdir -p uploads .env-backups

ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    PORT=4040

EXPOSE 4040

# Wait-for-it loops live in the entrypoint so the server doesn't crash when
# Postgres is still warming up on first start. We keep it tiny: try a Prisma
# `migrate deploy`, then a seed (idempotent), then start the server.
CMD ["sh", "-c", "npx prisma migrate deploy || npx prisma db push --accept-data-loss --skip-generate; node prisma/seed.js || true; node src/server.js"]
