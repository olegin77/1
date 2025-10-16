# Tasks

## Этап 1: Фундамент и Базовые Сервисы

- [x] svc-enquiries: обеспечить запуск на 0.0.0.0 и чтение $PORT
- [x] svc-enquiries: реализовать базовый /health эндпоинт
- [x] svc-vendors: создать каркас NestJS-сервиса (app.module, main.ts, health endpoint) — 2025-10-16 02:40:01 +0500
- [x] svc-auth: создать каркас NestJS-сервиса (app.module, main.ts, health endpoint) — 2025-10-16 03:00:02 +0500
- [x] svc-guests: создать каркас NestJS-сервиса (app.module, main.ts, health endpoint) — 2025-10-16 03:20:01 +0500
- [x] svc-catalog: создать каркас NestJS-сервиса (app.module, main.ts, health endpoint) — 2025-10-16 03:40:01 +0500
- [x] DevOps: создать базовый Dockerfile для сервиса `svc-vendors` — 2025-10-16 15:40:02 +0500
- [x] DevOps: создать базовый Dockerfile для сервиса `svc-auth` — 2025-10-16 16:00:02 +0500
- [ ] DevOps: создать базовый Dockerfile для сервиса `svc-guests`
- [ ] DevOps: добавить сервис `svc-vendors` в конфигурационный файл `do/app.yaml`
- [ ] DevOps: добавить сервис `svc-auth` в `do/app.yaml`
- [ ] DevOps: добавить сервис `svc-guests` в `do/app.yaml`

## Этап 2: Модели Данных (Prisma)

- [ ] Prisma: определить модель User (для svc-auth)
- [ ] Prisma: определить модель Couple (для svc-auth)
- [ ] Prisma: определить модель Vendor (для svc-vendors)
- [ ] Prisma: определить модель Venue (для svc-vendors)
- [ ] Prisma: определить модель AvailabilitySlot (для svc-vendors)
- [ ] Prisma: определить модель Offer (для svc-vendors)
- [ ] Prisma: определить модель Review (для svc-enquiries)
- [ ] Prisma: определить модель Guest (для svc-guests)
- [ ] Prisma: определить модель Table (для svc-guests)
- [ ] Prisma: определить модель BudgetItem (для svc-guests)
- [ ] Prisma: выполнить `prisma generate` для всех сервисов после изменения схем

## Этап 3: Реализация API Аутентификации (svc-auth)

- [ ] svc-auth: создать DTO для регистрации (register.dto.ts)
- [ ] svc-auth: создать DTO для логина (login.dto.ts)
- [ ] svc-auth: создать AuthController с методами register и login
- [ ] svc-auth: создать AuthService с логикой регистрации (хеширование пароля) и входа (JWT)

## Этап 4: Реализация API Вендоров (svc-vendors)

- [ ] svc-vendors: создать DTO (create-vendor.dto.ts) для создания профиля
- [ ] svc-vendors: создать VendorsController с методами create, findOne, findAll
- [ ] svc-vendors: создать VendorsService с базовой CRUD-логикой для профилей
- [ ] svc-vendors: реализовать API POST /vendors (создание профиля)
- [ ] svc-vendors: реализовать API GET /vendors/:id (получение одного профиля)
- [ ] svc-vendors: реализовать API GET /vendors (получение списка с фильтрацией по городу)

## Этап 5: Расширение API Заявок (svc-enquiries)

- [ ] svc-enquiries: убедиться, что DTO CreateEnquiryDto соответствует ТЗ
- [ ] svc-enquiries: реализовать логику проверки статусов (NEW -> QUOTE_SENT и т.д.) в EnquiriesService
- [ ] svc-enquiries: реализовать API PATCH /enquiries/:id/status для смены статуса заявки

## Этап 6: Реализация API Гостей (svc-guests)

- [ ] svc-guests: создать DTO для создания гостя (create-guest.dto.ts)
- [ ] svc-guests: создать GuestsController с методами create, findAll, update
- [ ] svc-guests: создать GuestsService с CRUD-логикой для гостей
- [ ] svc-guests: реализовать API POST /guests/import для импорта гостей (пока заглушка)

## Этап 7: Интеграция Фронтенда

- [ ] Frontend: создать страницу регистрации /auth/register и подключить к API
- [ ] Frontend: создать страницу входа /auth/login и подключить к API
- [ ] Frontend: переделать страницу каталога /vendors для получения данных с бэкенда
- [ ] Frontend: переделать страницу профиля /vendors/[vendorId] для получения данных с бэкенда
