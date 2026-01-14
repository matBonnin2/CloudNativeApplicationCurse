# ---------- build stage ----------
FROM node:20-alpine AS build
WORKDIR /app

# OpenSSL 3 (Alpine récent)
RUN apk add --no-cache openssl

# Dépendances
COPY package*.json ./
RUN npm ci

# Prisma
COPY prisma ./prisma
RUN npx prisma generate

# Code
COPY . .

# ---------- production stage ----------
FROM node:20-alpine AS production
WORKDIR /app

RUN apk add --no-cache openssl

ENV NODE_ENV=production

RUN addgroup -S app && adduser -S app -G app

COPY --from=build /app/package*.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/seed ./seed
COPY --from=build /app/src ./src

USER app

EXPOSE 3000
CMD ["sh", "-c", "npx prisma migrate deploy && npm run seed && node src/index.js"]
