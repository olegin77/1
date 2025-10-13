# syntax=docker/dockerfile:1

FROM node:20-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@9.12.0 --activate
WORKDIR /repo

# --- deps (root monorepo) ---
FROM base AS deps
COPY package.json pnpm-lock.yaml ./
COPY apps/svc-enquiries/package.json apps/svc-enquiries/package.json
RUN pnpm install --frozen-lockfile

# --- build (svc-enquiries only) ---
FROM base AS build
COPY --from=deps /repo/node_modules /repo/node_modules
COPY . .
RUN pnpm -w apps/svc-enquiries prisma:generate
RUN pnpm -w apps/svc-enquiries build

# --- runtime ---
FROM node:20-slim AS runner
ENV NODE_ENV=production
WORKDIR /repo

# non-root
RUN useradd -m -u 10001 nodeuser

# копируем только нужное
COPY --from=build /repo/apps/svc-enquiries/dist apps/svc-enquiries/dist
COPY --from=build /repo/apps/svc-enquiries/node_modules apps/svc-enquiries/node_modules
COPY --from=build /repo/node_modules/.prisma node_modules/.prisma
COPY --from=build /repo/apps/svc-enquiries/prisma apps/svc-enquiries/prisma
COPY apps/svc-enquiries/docker-cmd.sh docker-cmd.sh

ENV PORT=8080
EXPOSE 8080
USER nodeuser

CMD ["bash","-lc","./docker-cmd.sh"]
