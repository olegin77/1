# Этап 1: Сборка
FROM node:18-alpine AS builder
WORKDIR /usr/src/app
COPY apps/svc-vendors/package*.json ./
RUN npm install
COPY apps/svc-vendors/ .
RUN npm run build

# Этап 2: Запуск
FROM node:18-alpine
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/package*.json ./
RUN npm install --only=production
COPY --from=builder /usr/src/app/dist ./dist
CMD ["npm", "run", "start"]
