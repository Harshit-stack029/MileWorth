# syntax=docker/dockerfile:1

# MileWorth API container.
#
# Note the app/ Flutter client is NOT containerised — it is a mobile app and is
# local-only anyway. This image is just the backend, and the compose file at the
# repo root pairs it with a MongoDB container so the API runs without an Atlas
# account. Render still deploys this service from its native Node runtime (see
# render.yaml); nothing here changes production.

FROM node:20-alpine AS base
WORKDIR /app
# engines in package.json requires node >=20.
ENV NODE_ENV=production

# --- dependencies -----------------------------------------------------------
# Split from the runtime stage so a source-only edit doesn't reinstall packages.
FROM base AS deps
# package-lock.json is committed, so `npm ci` installs the exact locked tree and
# fails loudly if the lockfile and package.json ever drift apart.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# --- runtime ----------------------------------------------------------------
FROM base AS runtime
ENV PORT=4000

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# The official node image ships an unprivileged `node` user. Running as root in
# a container is the default and is worth undoing.
USER node

EXPOSE 4000

# Node 20 has a global fetch, so the check needs no curl/wget in the image.
# Compose declares its own healthcheck too; this one makes the image
# self-describing when run standalone.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||4000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
