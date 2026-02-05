# ============================================
# Stage 1: Build
# ============================================
FROM node:20-alpine AS builder

RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

COPY package.json pnpm-lock.yaml* ./

RUN corepack enable && corepack prepare pnpm@latest --activate

RUN pnpm install --frozen-lockfile

COPY prisma ./prisma
RUN pnpm exec prisma generate

COPY tsconfig.json ./
COPY src ./src

RUN pnpm run build

# ============================================
# Stage 2: Production Dependencies
# ============================================
FROM node:20-alpine AS deps

RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

COPY package.json pnpm-lock.yaml* ./

RUN corepack enable && corepack prepare pnpm@latest --activate

RUN pnpm install --frozen-lockfile --prod

# ============================================
# Stage 3: Runtime
# ============================================
FROM node:20-alpine AS runtime

RUN apk add --no-cache openssl dumb-init curl

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/out ./out
COPY --from=builder --chown=nodejs:nodejs /app/prisma ./prisma
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./package.json

USER nodejs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

ENTRYPOINT ["dumb-init", "--"]

CMD ["sh", "-c", "npx prisma migrate deploy && node out/index.js"]
