# CODEX_TASKS.md

> Полный план для автономной сборки продукта Codex’ом: **эпики → истории → тех‑таски**, с точными путями, Prisma‑схемами, API‑контрактами (DTO/JSON), DoD, тестами, командами. Чекбоксы совместимы с твоим стилем (галочка ставится Codex’ом по факту выполнения).

---

## Этап 0: Инициализация проекта
- [x] Monorepo (PNPM workspaces). Дерево: `apps/*` (сервисы), `packages/*` (общие пакеты), `infra/*` (Docker/CI). — 2025‑10‑16 20:10:00 +0500
- [x] Базовые сервисы с `/health`: `svc-auth`, `svc-enquiries`, `svc-vendors`, `svc-catalog`, `svc-guests`. — 2025‑10‑16 20:10:00 +0500
- [x] Добавить `svc-website` (Next.js/SSR) для **сайта пары** и **публичного RSVP**. — 2025-10-16 20:20:02 +0500
- [x] `.env.example` для каждого сервиса (см. ниже ENV список). — 2025-10-16 20:40:02 +0500
- [x] Dockerfiles + `infra/do/app.yaml` для DO Apps; локально — `docker-compose.yml` (Postgres, Redis, Minio). — 2025‑10‑16 20:10:00 +0500
- [x] GitHub Actions: линтер → unit → e2e → prisma migrate dry‑run → build → auto‑merge `codex`→`main` при зелёных чеках. — 2025-10-16 21:00:05 +0500

**ENV (общий список для .env.example):**
```
DATABASE_URL=postgresql://postgres:postgres@db:5432/wt
REDIS_URL=redis://redis:6379
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=wt
MINIO_SECRET_KEY=wtsecret
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
JWT_SECRET=change_me
HCAPTCHA_SECRET=change_me
APP_BASE_URL=https://weddingtech.uz
MAIL_FROM=noreply@weddingtech.uz
SMTP_URL=smtp://user:pass@smtp:587
DEFAULT_LOCALE=ru
```

---

## Этап 1: База данных и Prisma (пакет `packages/prisma`)
- [x] Создать пакет `packages/prisma` с единой схемой и генерацией типов.
- [x] Настроить генераторы: `client`, `nestjs-zod`, `er` (диаграмма). — 2025-10-16 21:13:52 +0500
- [ ] Добавить миграции и скрипты: `pnpm -w prisma:migrate`, `pnpm -w prisma:generate`.

**`packages/prisma/schema.prisma` (полная MVP‑схема):**
```prisma
generator client { provider = "prisma-client-js" }
datasource db { provider = "postgresql" url = env("DATABASE_URL") }

enum Role { PAIR VENDOR ADMIN MODERATOR }
enum EnquiryStatus { NEW QUOTE_SENT CONTRACT_SIGNED WON LOST }
enum RSVPStatus { INVITED GOING DECLINED NO_RESPONSE }
enum AvailabilityStatus { OPEN BUSY LATE }

model User {
  id           String   @id @default(cuid())
  email        String   @unique
  phone        String?  @unique
  role         Role
  locale       String   @default("ru")
  passwordHash String
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  Couple       Couple?
  Vendors      Vendor[]
}

model Couple {
  id          String   @id @default(cuid())
  userId      String   @unique
  weddingDate DateTime?
  city        String?
  preferences Json?
  user        User     @relation(fields: [userId], references: [id])
  Guests      Guest[]
  Tables      Table[]
  Budget      BudgetItem[]
  Website     Website?
}

model Vendor {
  id            String   @id @default(cuid())
  ownerUserId   String
  type          String   // e.g. TOYHANA, PHOTO, VIDEO, MUSIC, DRESS
  title         String
  city          String
  address       String?
  priceFrom     Int?
  rating        Float?   @default(0)
  verified      Boolean  @default(false)
  profileScore  Int      @default(0) // полнота профиля 0..100
  media         Json?
  docs          Json?
  owner         User     @relation(fields: [ownerUserId], references: [id])
  Venues        Venue[]
  Offers        Offer[]
  Availabilities AvailabilitySlot[]
}

model Venue {
  id         String  @id @default(cuid())
  vendorId   String
  title      String
  capacityMin Int?
  capacityMax Int?
  features    Json?
  vendor     Vendor  @relation(fields: [vendorId], references: [id])
  @@index([capacityMin, capacityMax])
}

model AvailabilitySlot {
  id        String             @id @default(cuid())
  vendorId  String
  venueId   String?
  date      DateTime
  status    AvailabilityStatus
  vendor    Vendor             @relation(fields: [vendorId], references: [id])
  venue     Venue?             @relation(fields: [venueId], references: [id])
  @@index([vendorId, date])
}

model Offer {
  id        String   @id @default(cuid())
  vendorId  String
  title     String
  description String?
  price     Int?
  validFrom DateTime?
  validTo   DateTime?
  isHighlighted Boolean @default(false)
  vendor    Vendor   @relation(fields: [vendorId], references: [id])
}

model Enquiry {
  id        String        @id @default(cuid())
  coupleId  String
  vendorId  String
  venueId   String?
  eventDate DateTime?
  guests    Int?
  budget    Int?
  status    EnquiryStatus @default(NEW)
  createdAt DateTime      @default(now())
  updatedAt DateTime      @updatedAt
  couple    Couple        @relation(fields: [coupleId], references: [id])
  vendor    Vendor        @relation(fields: [vendorId], references: [id])
  venue     Venue?        @relation(fields: [venueId], references: [id])
  notes     EnquiryNote[]
  reviews   Review[]
  @@index([status, eventDate])
}

model EnquiryNote {
  id        String   @id @default(cuid())
  enquiryId String
  authorId  String
  text      String
  createdAt DateTime @default(now())
  enquiry   Enquiry  @relation(fields: [enquiryId], references: [id])
}

model Review {
  id        String   @id @default(cuid())
  enquiryId String   @unique // отзыв возможен только по закрытой (WON) заявке
  rating    Int
  text      String?
  isPublished Boolean @default(false)
  moderationStatus String? // APPROVED/REJECTED/NEED_INFO
  enquiry   Enquiry  @relation(fields: [enquiryId], references: [id])
}

model Guest {
  id        String     @id @default(cuid())
  coupleId  String
  name      String
  phone     String?
  email     String?
  diet      String?
  plusOne   Boolean    @default(false)
  status    RSVPStatus @default(INVITED)
  couple    Couple     @relation(fields: [coupleId], references: [id])
  tableId   String?
  table     Table?     @relation(fields: [tableId], references: [id])
  @@index([coupleId, status])
}

model Table {
  id       String  @id @default(cuid())
  coupleId String
  name     String
  seats    Int
  sort     Int      @default(0)
  couple   Couple  @relation(fields: [coupleId], references: [id])
  Guests   Guest[]
}

model BudgetItem {
  id       String  @id @default(cuid())
  coupleId String
  category String
  planned  Int     @default(0)
  actual   Int     @default(0)
  note     String?
  couple   Couple  @relation(fields: [coupleId], references: [id])
}

model Website {
  id         String  @id @default(cuid())
  coupleId   String  @unique
  slug       String  @unique
  themeId    String
  isPublished Boolean @default(false)
  rsvpPublicEnabled Boolean @default(true)
  couple     Couple  @relation(fields: [coupleId], references: [id])
  RSVPs      RSVP[]
}

model RSVP {
  id        String  @id @default(cuid())
  websiteId String
  guestId   String?
  name      String
  contact   String?
  response  RSVPStatus
  message   String?
  createdAt DateTime @default(now())
  website   Website @relation(fields: [websiteId], references: [id])
}

model AuditEvent {
  id        String   @id @default(cuid())
  entity    String
  entityId  String
  type      String // e.g., ENQUIRY_STATUS_CHANGED
  data      Json?
  byUserId  String?
  createdAt DateTime @default(now())
}

model RankSignal {
  id        String  @id @default(cuid())
  vendorId  String
  venueId   String?
  signalType String  // CONVERSION, RATING, PROFILE, CALENDAR
  weight    Float   @default(0)
  ttl       DateTime?
  @@index([vendorId, signalType])
}
```

**DoD (этап 1):** миграции прогоняются; генерятся типы; ER‑диаграмма сохранена в `docs/er/`.

---

## Этап 2: Аутентификация и роли — `apps/svc-auth`
- [ ] Зависимости: `@nestjs/jwt`, `argon2`, `class-validator`, `passport-jwt`.
- [ ] Файлы:
```
apps/svc-auth/src/app.module.ts
apps/svc-auth/src/auth.controller.ts
apps/svc-auth/src/auth.service.ts
apps/svc-auth/src/strategies/jwt.strategy.ts
apps/svc-auth/src/guards/roles.guard.ts
apps/svc-auth/src/dto/register.dto.ts
apps/svc-auth/src/dto/login.dto.ts
apps/svc-auth/src/dto/refresh.dto.ts
apps/svc-auth/test/auth.e2e-spec.ts
```
- [ ] API‑контракты:
```
POST /api/v1/auth/register
Req: {"email":"user@example.com","password":"Str0ngPass!23","role":"PAIR","locale":"ru"}
Res 201: {"id":"ck_..."}

POST /api/v1/auth/login
Req: {"email":"user@example.com","password":"Str0ngPass!23"}
Res 200: {"accessToken":"<jwt>","refreshToken":"<jwt>"}

POST /api/v1/auth/refresh
Req: {"refreshToken":"<jwt>"}
Res 200: {"accessToken":"<jwt>","refreshToken":"<jwt>"}
```
- [ ] Политики: throttle на `/auth/login`, `RolesGuard(Role)`; audit неуспешных логинов.
- [ ] DoD: p95 < 100мс; e2e покрытие: регистрация 201, повтор 409, логин 200, неверный пароль 401, refresh 200.

---

## Этап 3: Заявки / Enquiry Manager — `apps/svc-enquiries`
- [ ] Файлы:
```
apps/svc-enquiries/src/enquiries.controller.ts
apps/svc-enquiries/src/enquiries.service.ts
apps/svc-enquiries/src/dto/create-enquiry.dto.ts
apps/svc-enquiries/src/dto/update-enquiry.dto.ts
apps/svc-enquiries/src/dto/change-status.dto.ts
apps/svc-enquiries/src/status-machine.ts
apps/svc-enquiries/src/audit.publisher.ts
apps/svc-enquiries/test/enquiries.e2e-spec.ts
```
- [ ] Машина переходов (идемпотентно): `NEW → QUOTE_SENT → CONTRACT_SIGNED → WON|LOST`.
- [ ] API‑контракты:
```
POST /api/v1/enquiries
Req: {"vendorId":"v_1","venueId":"vn_1","eventDate":"2025-10-10","guests":300,"budget":20000}
Res 201: {"id":"e_1"}

GET /api/v1/enquiries/:id  (owner couple/vendor/admin)
Res 200: {...}

GET /api/v1/enquiries?status=NEW&date=2025-10-10&vendorId=v_1
Res 200: {"items":[...],"total":123}

PATCH /api/v1/enquiries/:id/status
Req: {"from":"NEW","to":"QUOTE_SENT"}
Res 200: {"id":"e_1","status":"QUOTE_SENT"}
```
- [ ] AuditEvent на каждый переход и заметку.
- [ ] DoD: юнит‑тест валидности переходов; e2e на права доступа; p95 < 150мс.

---

## Этап 4: Поставщики и площадки — `apps/svc-vendors`
- [ ] Файлы:
```
apps/svc-vendors/src/vendors.controller.ts
apps/svc-vendors/src/vendors.service.ts
apps/svc-vendors/src/dto/create-vendor.dto.ts
apps/svc-vendors/src/dto/update-vendor.dto.ts
apps/svc-vendors/src/dto/create-venue.dto.ts
apps/svc-vendors/src/dto/update-venue.dto.ts
apps/svc-vendors/src/dto/create-offer.dto.ts
apps/svc-vendors/src/dto/update-offer.dto.ts
apps/svc-vendors/src/media.service.ts (Minio)
apps/svc-vendors/test/vendors.e2e-spec.ts
```
- [ ] API‑контракты:
```
POST /api/v1/vendors
Req: {"type":"TOYHANA","title":"Navruz Palace","city":"Tashkent","priceFrom":2000}
Res 201: {"id":"v_1"}

PATCH /api/v1/vendors/:id
Req: {"verified":true,"profileScore":85}

GET /api/v1/vendors?city=Tashkent&type=TOYHANA
Res 200: {"items":[...],"total":42}

POST /api/v1/vendors/:id/venues
Req: {"title":"Grand Hall","capacityMin":200,"capacityMax":800}

POST /api/v1/vendors/:id/offers
Req: {"title":"Осеннее спец‑предложение","price":1500,"validTo":"2025-11-15","isHighlighted":true}

PUT /api/v1/vendors/:id/availability
Req: {"date":"2025-10-20","status":"LATE","venueId":"vn_1"}
```
- [ ] Модерация полей (`verified`), хранение документов‑доказательств (метаданные JSON, Minio для файлов).
- [ ] DoD: фильтры и сортировки; права (owner/admin); e2e на CRUD, медиа, верификацию.

---

## Этап 5: Каталог и Ранжирование — `apps/svc-catalog`
- [ ] Индексация: денормализованный документ `CatalogItem` по vendor/venue/availability/offer.
- [ ] Ранжирование: сигналы `CONVERSION(WON)`, `RATING`, `PROFILE`, `CALENDAR` → формула
```
rank = 0.5*conversion + 0.2*rating + 0.2*profile + 0.1*calendar
```
- [ ] API‑контракты:
```
GET /api/v1/search/vendors?city=Tashkent&capacity>=500&date=2025-10-10&price<=3000&sort=rank
Res 200: {"items":[{"vendorId":"v_1","rank":0.87,...}],"total":120}
```
- [ ] DoD: p95 выдачи ≤ 200мс при индексе 1k карточек; unit‑тесты монотоничности ранга.

---

## Этап 6: Гости / RSVP / Посадка / Бюджет — `apps/svc-guests`
- [ ] Очереди BullMQ (Redis) для импорта 10k+ гостей, батч 500, идемпотентность по email/phone.
- [ ] API‑контракты:
```
POST /api/v1/guests/import (CSV/XLSX)
Res 202: {"jobId":"j_1"}
GET  /api/v1/guests/import/:jobId/status → {"progress":0..100}

GET /api/v1/guests?status=INVITED
POST /api/v1/guests
PATCH /api/v1/guests/:id {"status":"GOING"}

POST /api/v1/tables {"name":"Family","seats":10}
POST /api/v1/tables/auto-assign {"strategy":"fill"}

POST /api/v1/budget {"category":"Decor","planned":2000}
```
- [ ] DoD: импорт 10k за разумное время (<3 мин на стенде), p95 API < 200мс; e2e флоу гостей/посадки/бюджета.

---

## Этап 7: Сайт пары + публичный RSVP — `apps/svc-website` (Next.js)
- [ ] Страницы: `/w/:slug`, `/w/:slug/rsvp`, `/w/:slug/info`.
- [ ] Темы (2 шт), локальные шрифты, RU/UZ строки, SEO/OG, генерация OG‑изображения.
- [ ] Публичный RSVP (hCaptcha, rate‑limit IP+slug).
- [ ] Экспорт пригласительных (PDF) + QR‑ссылка.
- [ ] DoD: WCAG AA для публичных страниц; e2e флоу «создать сайт → включить RSVP → получить ответы».

---

## Этап 8: Отзывы и модерация — `apps/svc-enquiries` + Admin
- [ ] Правило: отзыв только по `Enquiry.status = WON`.
- [ ] Админ‑модерация: approve/reject, причина отказа.
- [ ] Антифрод‑лимиты (per user/day), эвристики.
- [ ] DoD: отзыв влияет на `RATING` сигналы ранга; e2e публикация → отражение в каталоге.

---

## Этап 9: Админ‑панель — `apps/admin` (Next.js)
- [ ] Разделы: пользователи/роли, модерация профилей/медиа/отзывов, справочники (города/категории/валюты), верификация документов.
- [ ] RBAC: `ADMIN` полный доступ; `MODERATOR` — модерация/справочники.
- [ ] Отчёты: активность модерации, очередь на проверку, журнал AuditEvent.
- [ ] DoD: аудит кликов (важные действия); экспорт CSV.

---

## Этап 10: B2B‑Аналитика — `apps/svc-analytics`
- [ ] Метрики: `Total enquiries`, `Search position (by city)`, `Monthly search appearances`, `Conversion → WON`, средний чек, загруженность дат, эффективность офферов, источники лидов.
- [ ] Сбор: событийная шина + периодические агрегации.
- [ ] API: `/api/v1/analytics/vendor/:id/*` (серии, таблицы); экспорт CSV.
- [ ] DoD: корректность расчётов при изменении статусов/ранга (e2e‑снепшоты).

---

## Этап 11: i18n RU/UZ — пакет `packages/i18n`
- [ ] Файлы `ru.json`, `uz.json` для фронта/бэка (ошибки, формы, письма).
- [ ] Переключатель локали на фронте; формат дат/валют; pluralization.
- [ ] DoD: 100% пользовательских строк покрыты RU/UZ; fallback EN.

---

## Этап 12: Дизайн‑система и UX — `packages/ui`
- [ ] Компоненты: Button, Input, Select, Modal, Card, Empty, Table, Tabs, Toast.
- [ ] Паттерны: состояния загрузки/ошибок, skeletons, a11y (focus/contrast/keyboard).
- [ ] Маршруты фронта:
```
/app (дашборд пары): Гости/RSVP/Столы/Бюджет/Чек‑лист
/vendors (каталог), /vendors/:id (профайл)
/b2b (дашборд вендора): заявки/календарь/офферы/аналитика
/admin (модерация)
```
- [ ] DoD: визуальное соответствие макетам; responsive ≥ 360px.

---

## Этап 13: Производительность и масштабирование
- [ ] Индексы БД (см. Prisma), connection‑pool, кеш каталога.
- [ ] k6 профили: p95 — каталог ≤200мс, auth ≤100мс, enquiries ≤150мс.
- [ ] CDN для публичного сайта пары; инвалидация по публикации.

---

## Этап 14: Безопасность и приватность
- [ ] OWASP: DTO‑валидация, санитизация, ограничение PATCH/fields.
- [ ] RBAC везде; rate‑limits; hCaptcha на публичных формах.
- [ ] Логи безопасности: неуспешные логины, аномалии.
- [ ] Политика данных: хранить минимум, PII в зашифрованных сторах там, где нужно.

---

## Этап 15: Телеметрия, аудит, алерты
- [ ] Централизованный логгер (стенд/прод), request‑ids, correlation‑ids.
- [ ] AuditEvent для смен статусов, модерации, публикаций.
- [ ] Тех‑метрики: p95, error rate, saturation; дешборд SRE; алерты по порогам.

---

## Этап 16: Письма и уведомления — `apps/svc-mail`
- [ ] MJML шаблоны RU/UZ: регистрация, восстановление, подтверждение заявок.
- [ ] SMTP провайдер; ретраи; DLQ.
- [ ] Webhooks: внешние BI/CRM событийные интеграции.

---

## Этап 17: SEO и контент
- [ ] Публичные страницы: мета‑теги, OG, карта сайта.
- [ ] schema.org для профилей/площадок; генерация OG image.

---

## Этап 18: CI/CD и ветвление — `infra/ci/*.yml`
- [ ] Workflows: lint → test → e2e → migrate → build → deploy.
- [ ] Автосоздание PR из `codex` в `main`; auto‑merge при зелёных чеках.
- [ ] Стенды: локалка (compose), stage, prod (DO Apps); smoke‑тесты.

---

## Этап 19: Сиды и демо‑данные — `apps/seeder`
- [ ] Пользователи: 1 ADMIN, 2 VENDOR, 1 PAIR.
- [ ] 10 поставщиков (в т.ч. тойханы 500+), офферы, поздняя доступность.
- [ ] 1 пара с 300 гостями и преднастроенным сайтом.

---

## Этап 20: Е2Е и регресс
- [ ] Playwright: B2C — онбординг пары → гости → сайт → публичный RSVP → заявки.
- [ ] B2B — онбординг вендора → календарь/офферы → входящие заявки → конверсия → отзыв → аналитика.
- [ ] Перф‑тесты k6 по расписанию.

---

## Этап 21: Платежи/биллинг (этап 2)
- [ ] Каркас интеграции локальных провайдеров (UZ) и подписок B2B.
- [ ] Фин‑дашборд: комиссии, объём оплат, конверсия финансирования.

---

## Этап 22: Релиз‑план
- [ ] Этап 0 (≤2н): каркас сервисов, Auth, БД схемы, базовая админка.
- [ ] Этап 1 (4–6н): B2C ядро (гости/RSVP/посадка/чек‑лист/бюджет), каталог+фильтры, сайт пары.
- [ ] Этап 2 (4–6н): B2B (заявки машина статусов, аналитика, офферы/late availability, верификация).
- [ ] Этап 3 (2–4н): перф/SEO/контент, финальные регрессы, go‑live.

---

# Приложение A — DTO и валидация (файловая раскладка)

## svc-auth/dto
```ts
// register.dto.ts
import { IsEmail, IsIn, IsString, MinLength, IsOptional } from 'class-validator';
export class RegisterDto {
  @IsEmail() email: string;
  @IsString() @MinLength(8) password: string;
  @IsIn(['PAIR','VENDOR']) role: 'PAIR'|'VENDOR';
  @IsOptional() @IsString() locale?: string; // 'ru' | 'uz'
}

// login.dto.ts
export class LoginDto { @IsEmail() email: string; @IsString() password: string; }

// refresh.dto.ts
export class RefreshDto { @IsString() refreshToken: string; }
```

## svc-enquiries/dto
```ts
// create-enquiry.dto.ts
import { IsDateString, IsInt, IsOptional, IsString, Min } from 'class-validator';
export class CreateEnquiryDto {
  @IsString() vendorId: string;
  @IsOptional() @IsString() venueId?: string;
  @IsOptional() @IsDateString() eventDate?: string;
  @IsOptional() @IsInt() @Min(1) guests?: number;
  @IsOptional() @IsInt() @Min(0) budget?: number;
}

// change-status.dto.ts
import { IsIn, IsString } from 'class-validator';
export class ChangeStatusDto {
  @IsIn(['NEW','QUOTE_SENT','CONTRACT_SIGNED','WON','LOST']) to: string;
  @IsString() from: string;
}
```

## svc-vendors/dto
```ts
// create-vendor.dto.ts
import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';
export class CreateVendorDto {
  @IsString() type: string; // 'TOYHANA' | 'PHOTO' | ...
  @IsString() title: string;
  @IsString() city: string;
  @IsOptional() @IsInt() @Min(0) priceFrom?: number;
}

// update-vendor.dto.ts
export class UpdateVendorDto {
  @IsOptional() @IsBoolean() verified?: boolean;
  @IsOptional() @IsInt() @Min(0) profileScore?: number;
}

// create-venue.dto.ts
export class CreateVenueDto {
  @IsString() title: string;
  @IsOptional() @IsInt() capacityMin?: number;
  @IsOptional() @IsInt() capacityMax?: number;
}

// create-offer.dto.ts
export class CreateOfferDto {
  @IsString() title: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsInt() price?: number;
  @IsOptional() @IsString() validFrom?: string;
  @IsOptional() @IsString() validTo?: string;
  @IsOptional() isHighlighted?: boolean;
}
```

## svc-guests/dto
```ts
// guest.dto.ts
import { IsEmail, IsOptional, IsPhoneNumber, IsString, IsIn, IsBoolean } from 'class-validator';
export class GuestDto {
  @IsString() name: string;
  @IsOptional() @IsPhoneNumber('UZ') phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() diet?: string;
  @IsOptional() @IsBoolean() plusOne?: boolean;
  @IsOptional() @IsIn(['INVITED','GOING','DECLINED','NO_RESPONSE']) status?: string;
}
```

---

# Приложение B — Команды
```
pnpm -w i
pnpm -w prisma:generate
pnpm -w prisma:migrate dev
pnpm -w lint && pnpm -w test && pnpm -w test:e2e
pnpm -w build
docker compose up -d
```

---

# Приложение C — DoD (единые критерии)
- Линтер/юнит/е2е зелёные; миграции применяются; OpenAPI отражает все эндпоинты.
- RU/UZ i18n покрывает все пользовательские тексты и ошибки.
- AuditEvent создаётся на ключевые изменения (статусы заявок, модерация, публикации).
- Перф: p95 каталога ≤200мс, auth ≤100мс, enquiries ≤150мс; импорт 10k гостей укладывается в целевой SLA.
- CI/CD автосборка и автодеплой на stage; smoke‑тест стенда зелёный.

# CODEX_TASKS.md

> Полный план для автономной сборки продукта Codex’ом: **эпики → истории → тех‑таски**, с точными путями, Prisma‑схемами, API‑контрактами (DTO/JSON), DoD, тестами, командами. Чекбоксы совместимы с твоим стилем (галочка ставится Codex’ом по факту выполнения).

---

## Этап 0: Инициализация проекта
- [x] Monorepo (PNPM workspaces). Дерево: `apps/*` (сервисы), `packages/*` (общие пакеты), `infra/*` (Docker/CI). — 2025‑10‑16 20:10:00 +0500
- [x] Базовые сервисы с `/health`: `svc-auth`, `svc-enquiries`, `svc-vendors`, `svc-catalog`, `svc-guests`. — 2025‑10‑16 20:10:00 +0500
- [ ] Добавить `svc-website` (Next.js/SSR) для **сайта пары** и **публичного RSVP**.
- [ ] `.env.example` для каждого сервиса (см. ниже ENV список).
- [x] Dockerfiles + `infra/do/app.yaml` для DO Apps; локально — `docker-compose.yml` (Postgres, Redis, Minio). — 2025‑10‑16 20:10:00 +0500
- [ ] GitHub Actions: линтер → unit → e2e → prisma migrate dry‑run → build → auto‑merge `codex`→`main` при зелёных чеках.

**ENV (общий список для .env.example):**
```
DATABASE_URL=postgresql://postgres:postgres@db:5432/wt
REDIS_URL=redis://redis:6379
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=wt
MINIO_SECRET_KEY=wtsecret
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
JWT_SECRET=change_me
HCAPTCHA_SECRET=change_me
APP_BASE_URL=https://weddingtech.uz
MAIL_FROM=noreply@weddingtech.uz
SMTP_URL=smtp://user:pass@smtp:587
DEFAULT_LOCALE=ru
```

---

## Этап 1: База данных и Prisma (пакет `packages/prisma`)
- [x] Создать пакет `packages/prisma` с единой схемой и генерацией типов.
- [ ] Настроить генераторы: `client`, `nestjs-zod`, `er` (диаграмма).
- [ ] Добавить миграции и скрипты: `pnpm -w prisma:migrate`, `pnpm -w prisma:generate`.

**`packages/prisma/schema.prisma` (полная MVP‑схема):**
```prisma
generator client { provider = "prisma-client-js" }
datasource db { provider = "postgresql" url = env("DATABASE_URL") }

enum Role { PAIR VENDOR ADMIN MODERATOR }
enum EnquiryStatus { NEW QUOTE_SENT CONTRACT_SIGNED WON LOST }
enum RSVPStatus { INVITED GOING DECLINED NO_RESPONSE }
enum AvailabilityStatus { OPEN BUSY LATE }

model User {
  id           String   @id @default(cuid())
  email        String   @unique
  phone        String?  @unique
  role         Role
  locale       String   @default("ru")
  passwordHash String
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  Couple       Couple?
  Vendors      Vendor[]
}

model Couple {
  id          String   @id @default(cuid())
  userId      String   @unique
  weddingDate DateTime?
  city        String?
  preferences Json?
  user        User     @relation(fields: [userId], references: [id])
  Guests      Guest[]
  Tables      Table[]
  Budget      BudgetItem[]
  Website     Website?
}

model Vendor {
  id            String   @id @default(cuid())
  ownerUserId   String
  type          String   // e.g. TOYHANA, PHOTO, VIDEO, MUSIC, DRESS
  title         String
  city          String
  address       String?
  priceFrom     Int?
  rating        Float?   @default(0)
  verified      Boolean  @default(false)
  profileScore  Int      @default(0) // полнота профиля 0..100
  media         Json?
  docs          Json?
  owner         User     @relation(fields: [ownerUserId], references: [id])
  Venues        Venue[]
  Offers        Offer[]
  Availabilities AvailabilitySlot[]
}

model Venue {
  id         String  @id @default(cuid())
  vendorId   String
  title      String
  capacityMin Int?
  capacityMax Int?
  features    Json?
  vendor     Vendor  @relation(fields: [vendorId], references: [id])
  @@index([capacityMin, capacityMax])
}

model AvailabilitySlot {
  id        String             @id @default(cuid())
  vendorId  String
  venueId   String?
  date      DateTime
  status    AvailabilityStatus
  vendor    Vendor             @relation(fields: [vendorId], references: [id])
  venue     Venue?             @relation(fields: [venueId], references: [id])
  @@index([vendorId, date])
}

model Offer {
  id        String   @id @default(cuid())
  vendorId  String
  title     String
  description String?
  price     Int?
  validFrom DateTime?
  validTo   DateTime?
  isHighlighted Boolean @default(false)
  vendor    Vendor   @relation(fields: [vendorId], references: [id])
}

model Enquiry {
  id        String        @id @default(cuid())
  coupleId  String
  vendorId  String
  venueId   String?
  eventDate DateTime?
  guests    Int?
  budget    Int?
  status    EnquiryStatus @default(NEW)
  createdAt DateTime      @default(now())
  updatedAt DateTime      @updatedAt
  couple    Couple        @relation(fields: [coupleId], references: [id])
  vendor    Vendor        @relation(fields: [vendorId], references: [id])
  venue     Venue?        @relation(fields: [venueId], references: [id])
  notes     EnquiryNote[]
  reviews   Review[]
  @@index([status, eventDate])
}

model EnquiryNote {
  id        String   @id @default(cuid())
  enquiryId String
  authorId  String
  text      String
  createdAt DateTime @default(now())
  enquiry   Enquiry  @relation(fields: [enquiryId], references: [id])
}

model Review {
  id        String   @id @default(cuid())
  enquiryId String   @unique // отзыв возможен только по закрытой (WON) заявке
  rating    Int
  text      String?
  isPublished Boolean @default(false)
  moderationStatus String? // APPROVED/REJECTED/NEED_INFO
  enquiry   Enquiry  @relation(fields: [enquiryId], references: [id])
}

model Guest {
  id        String     @id @default(cuid())
  coupleId  String
  name      String
  phone     String?
  email     String?
  diet      String?
  plusOne   Boolean    @default(false)
  status    RSVPStatus @default(INVITED)
  couple    Couple     @relation(fields: [coupleId], references: [id])
  tableId   String?
  table     Table?     @relation(fields: [tableId], references: [id])
  @@index([coupleId, status])
}

model Table {
  id       String  @id @default(cuid())
  coupleId String
  name     String
  seats    Int
  sort     Int      @default(0)
  couple   Couple  @relation(fields: [coupleId], references: [id])
  Guests   Guest[]
}

model BudgetItem {
  id       String  @id @default(cuid())
  coupleId String
  category String
  planned  Int     @default(0)
  actual   Int     @default(0)
  note     String?
  couple   Couple  @relation(fields: [coupleId], references: [id])
}

model Website {
  id         String  @id @default(cuid())
  coupleId   String  @unique
  slug       String  @unique
  themeId    String
  isPublished Boolean @default(false)
  rsvpPublicEnabled Boolean @default(true)
  couple     Couple  @relation(fields: [coupleId], references: [id])
  RSVPs      RSVP[]
}

model RSVP {
  id        String  @id @default(cuid())
  websiteId String
  guestId   String?
  name      String
  contact   String?
  response  RSVPStatus
  message   String?
  createdAt DateTime @default(now())
  website   Website @relation(fields: [websiteId], references: [id])
}

model AuditEvent {
  id        String   @id @default(cuid())
  entity    String
  entityId  String
  type      String // e.g., ENQUIRY_STATUS_CHANGED
  data      Json?
  byUserId  String?
  createdAt DateTime @default(now())
}

model RankSignal {
  id        String  @id @default(cuid())
  vendorId  String
  venueId   String?
  signalType String  // CONVERSION, RATING, PROFILE, CALENDAR
  weight    Float   @default(0)
  ttl       DateTime?
  @@index([vendorId, signalType])
}
```

**DoD (этап 1):** миграции прогоняются; генерятся типы; ER‑диаграмма сохранена в `docs/er/`.

---

## Этап 2: Аутентификация и роли — `apps/svc-auth`
- [ ] Зависимости: `@nestjs/jwt`, `argon2`, `class-validator`, `passport-jwt`.
- [ ] Файлы:
```
apps/svc-auth/src/app.module.ts
apps/svc-auth/src/auth.controller.ts
apps/svc-auth/src/auth.service.ts
apps/svc-auth/src/strategies/jwt.strategy.ts
apps/svc-auth/src/guards/roles.guard.ts
apps/svc-auth/src/dto/register.dto.ts
apps/svc-auth/src/dto/login.dto.ts
apps/svc-auth/src/dto/refresh.dto.ts
apps/svc-auth/test/auth.e2e-spec.ts
```
- [ ] API‑контракты:
```
POST /api/v1/auth/register
Req: {"email":"user@example.com","password":"Str0ngPass!23","role":"PAIR","locale":"ru"}
Res 201: {"id":"ck_..."}

POST /api/v1/auth/login
Req: {"email":"user@example.com","password":"Str0ngPass!23"}
Res 200: {"accessToken":"<jwt>","refreshToken":"<jwt>"}

POST /api/v1/auth/refresh
Req: {"refreshToken":"<jwt>"}
Res 200: {"accessToken":"<jwt>","refreshToken":"<jwt>"}
```
- [ ] Политики: throttle на `/auth/login`, `RolesGuard(Role)`; audit неуспешных логинов.
- [ ] DoD: p95 < 100мс; e2e покрытие: регистрация 201, повтор 409, логин 200, неверный пароль 401, refresh 200.

---

## Этап 3: Заявки / Enquiry Manager — `apps/svc-enquiries`
- [ ] Файлы:
```
apps/svc-enquiries/src/enquiries.controller.ts
apps/svc-enquiries/src/enquiries.service.ts
apps/svc-enquiries/src/dto/create-enquiry.dto.ts
apps/svc-enquiries/src/dto/update-enquiry.dto.ts
apps/svc-enquiries/src/dto/change-status.dto.ts
apps/svc-enquiries/src/status-machine.ts
apps/svc-enquiries/src/audit.publisher.ts
apps/svc-enquiries/test/enquiries.e2e-spec.ts
```
- [ ] Машина переходов (идемпотентно): `NEW → QUOTE_SENT → CONTRACT_SIGNED → WON|LOST`.
- [ ] API‑контракты:
```
POST /api/v1/enquiries
Req: {"vendorId":"v_1","venueId":"vn_1","eventDate":"2025-10-10","guests":300,"budget":20000}
Res 201: {"id":"e_1"}

GET /api/v1/enquiries/:id  (owner couple/vendor/admin)
Res 200: {...}

GET /api/v1/enquiries?status=NEW&date=2025-10-10&vendorId=v_1
Res 200: {"items":[...],"total":123}

PATCH /api/v1/enquiries/:id/status
Req: {"from":"NEW","to":"QUOTE_SENT"}
Res 200: {"id":"e_1","status":"QUOTE_SENT"}
```
- [ ] AuditEvent на каждый переход и заметку.
- [ ] DoD: юнит‑тест валидности переходов; e2e на права доступа; p95 < 150мс.

---

## Этап 4: Поставщики и площадки — `apps/svc-vendors`
- [ ] Файлы:
```
apps/svc-vendors/src/vendors.controller.ts
apps/svc-vendors/src/vendors.service.ts
apps/svc-vendors/src/dto/create-vendor.dto.ts
apps/svc-vendors/src/dto/update-vendor.dto.ts
apps/svc-vendors/src/dto/create-venue.dto.ts
apps/svc-vendors/src/dto/update-venue.dto.ts
apps/svc-vendors/src/dto/create-offer.dto.ts
apps/svc-vendors/src/dto/update-offer.dto.ts
apps/svc-vendors/src/media.service.ts (Minio)
apps/svc-vendors/test/vendors.e2e-spec.ts
```
- [ ] API‑контракты:
```
POST /api/v1/vendors
Req: {"type":"TOYHANA","title":"Navruz Palace","city":"Tashkent","priceFrom":2000}
Res 201: {"id":"v_1"}

PATCH /api/v1/vendors/:id
Req: {"verified":true,"profileScore":85}

GET /api/v1/vendors?city=Tashkent&type=TOYHANA
Res 200: {"items":[...],"total":42}

POST /api/v1/vendors/:id/venues
Req: {"title":"Grand Hall","capacityMin":200,"capacityMax":800}

POST /api/v1/vendors/:id/offers
Req: {"title":"Осеннее спец‑предложение","price":1500,"validTo":"2025-11-15","isHighlighted":true}

PUT /api/v1/vendors/:id/availability
Req: {"date":"2025-10-20","status":"LATE","venueId":"vn_1"}
```
- [ ] Модерация полей (`verified`), хранение документов‑доказательств (метаданные JSON, Minio для файлов).
- [ ] DoD: фильтры и сортировки; права (owner/admin); e2e на CRUD, медиа, верификацию.

---

## Этап 5: Каталог и Ранжирование — `apps/svc-catalog`
- [ ] Индексация: денормализованный документ `CatalogItem` по vendor/venue/availability/offer.
- [ ] Ранжирование: сигналы `CONVERSION(WON)`, `RATING`, `PROFILE`, `CALENDAR` → формула
```
rank = 0.5*conversion + 0.2*rating + 0.2*profile + 0.1*calendar
```
- [ ] API‑контракты:
```
GET /api/v1/search/vendors?city=Tashkent&capacity>=500&date=2025-10-10&price<=3000&sort=rank
Res 200: {"items":[{"vendorId":"v_1","rank":0.87,...}],"total":120}
```
- [ ] DoD: p95 выдачи ≤ 200мс при индексе 1k карточек; unit‑тесты монотоничности ранга.

---

## Этап 6: Гости / RSVP / Посадка / Бюджет — `apps/svc-guests`
- [ ] Очереди BullMQ (Redis) для импорта 10k+ гостей, батч 500, идемпотентность по email/phone.
- [ ] API‑контракты:
```
POST /api/v1/guests/import (CSV/XLSX)
Res 202: {"jobId":"j_1"}
GET  /api/v1/guests/import/:jobId/status → {"progress":0..100}

GET /api/v1/guests?status=INVITED
POST /api/v1/guests
PATCH /api/v1/guests/:id {"status":"GOING"}

POST /api/v1/tables {"name":"Family","seats":10}
POST /api/v1/tables/auto-assign {"strategy":"fill"}

POST /api/v1/budget {"category":"Decor","planned":2000}
```
- [ ] DoD: импорт 10k за разумное время (<3 мин на стенде), p95 API < 200мс; e2e флоу гостей/посадки/бюджета.

---

## Этап 7: Сайт пары + публичный RSVP — `apps/svc-website` (Next.js)
- [ ] Страницы: `/w/:slug`, `/w/:slug/rsvp`, `/w/:slug/info`.
- [ ] Темы (2 шт), локальные шрифты, RU/UZ строки, SEO/OG, генерация OG‑изображения.
- [ ] Публичный RSVP (hCaptcha, rate‑limit IP+slug).
- [ ] Экспорт пригласительных (PDF) + QR‑ссылка.
- [ ] DoD: WCAG AA для публичных страниц; e2e флоу «создать сайт → включить RSVP → получить ответы».

---

## Этап 8: Отзывы и модерация — `apps/svc-enquiries` + Admin
- [ ] Правило: отзыв только по `Enquiry.status = WON`.
- [ ] Админ‑модерация: approve/reject, причина отказа.
- [ ] Антифрод‑лимиты (per user/day), эвристики.
- [ ] DoD: отзыв влияет на `RATING` сигналы ранга; e2e публикация → отражение в каталоге.

---

## Этап 9: Админ‑панель — `apps/admin` (Next.js)
- [ ] Разделы: пользователи/роли, модерация профилей/медиа/отзывов, справочники (города/категории/валюты), верификация документов.
- [ ] RBAC: `ADMIN` полный доступ; `MODERATOR` — модерация/справочники.
- [ ] Отчёты: активность модерации, очередь на проверку, журнал AuditEvent.
- [ ] DoD: аудит кликов (важные действия); экспорт CSV.

---

## Этап 10: B2B‑Аналитика — `apps/svc-analytics`
- [ ] Метрики: `Total enquiries`, `Search position (by city)`, `Monthly search appearances`, `Conversion → WON`, средний чек, загруженность дат, эффективность офферов, источники лидов.
- [ ] Сбор: событийная шина + периодические агрегации.
- [ ] API: `/api/v1/analytics/vendor/:id/*` (серии, таблицы); экспорт CSV.
- [ ] DoD: корректность расчётов при изменении статусов/ранга (e2e‑снепшоты).

---

## Этап 11: i18n RU/UZ — пакет `packages/i18n`
- [ ] Файлы `ru.json`, `uz.json` для фронта/бэка (ошибки, формы, письма).
- [ ] Переключатель локали на фронте; формат дат/валют; pluralization.
- [ ] DoD: 100% пользовательских строк покрыты RU/UZ; fallback EN.

---

## Этап 12: Дизайн‑система и UX — `packages/ui`
- [ ] Компоненты: Button, Input, Select, Modal, Card, Empty, Table, Tabs, Toast.
- [ ] Паттерны: состояния загрузки/ошибок, skeletons, a11y (focus/contrast/keyboard).
- [ ] Маршруты фронта:
```
/app (дашборд пары): Гости/RSVP/Столы/Бюджет/Чек‑лист
/vendors (каталог), /vendors/:id (профайл)
/b2b (дашборд вендора): заявки/календарь/офферы/аналитика
/admin (модерация)
```
- [ ] DoD: визуальное соответствие макетам; responsive ≥ 360px.

---

## Этап 13: Производительность и масштабирование
- [ ] Индексы БД (см. Prisma), connection‑pool, кеш каталога.
- [ ] k6 профили: p95 — каталог ≤200мс, auth ≤100мс, enquiries ≤150мс.
- [ ] CDN для публичного сайта пары; инвалидация по публикации.

---

## Этап 14: Безопасность и приватность
- [ ] OWASP: DTO‑валидация, санитизация, ограничение PATCH/fields.
- [ ] RBAC везде; rate‑limits; hCaptcha на публичных формах.
- [ ] Логи безопасности: неуспешные логины, аномалии.
- [ ] Политика данных: хранить минимум, PII в зашифрованных сторах там, где нужно.

---

## Этап 15: Телеметрия, аудит, алерты
- [ ] Централизованный логгер (стенд/прод), request‑ids, correlation‑ids.
- [ ] AuditEvent для смен статусов, модерации, публикаций.
- [ ] Тех‑метрики: p95, error rate, saturation; дешборд SRE; алерты по порогам.

---

## Этап 16: Письма и уведомления — `apps/svc-mail`
- [ ] MJML шаблоны RU/UZ: регистрация, восстановление, подтверждение заявок.
- [ ] SMTP провайдер; ретраи; DLQ.
- [ ] Webhooks: внешние BI/CRM событийные интеграции.

---

## Этап 17: SEO и контент
- [ ] Публичные страницы: мета‑теги, OG, карта сайта.
- [ ] schema.org для профилей/площадок; генерация OG image.

---

## Этап 18: CI/CD и ветвление — `infra/ci/*.yml`
- [ ] Workflows: lint → test → e2e → migrate → build → deploy.
- [ ] Автосоздание PR из `codex` в `main`; auto‑merge при зелёных чеках.
- [ ] Стенды: локалка (compose), stage, prod (DO Apps); smoke‑тесты.

---

## Этап 19: Сиды и демо‑данные — `apps/seeder`
- [ ] Пользователи: 1 ADMIN, 2 VENDOR, 1 PAIR.
- [ ] 10 поставщиков (в т.ч. тойханы 500+), офферы, поздняя доступность.
- [ ] 1 пара с 300 гостями и преднастроенным сайтом.

---

## Этап 20: Е2Е и регресс
- [ ] Playwright: B2C — онбординг пары → гости → сайт → публичный RSVP → заявки.
- [ ] B2B — онбординг вендора → календарь/офферы → входящие заявки → конверсия → отзыв → аналитика.
- [ ] Перф‑тесты k6 по расписанию.

---

## Этап 21: Платежи/биллинг (этап 2)
- [ ] Каркас интеграции локальных провайдеров (UZ) и подписок B2B.
- [ ] Фин‑дашборд: комиссии, объём оплат, конверсия финансирования.

---

## Этап 22: Релиз‑план
- [ ] Этап 0 (≤2н): каркас сервисов, Auth, БД схемы, базовая админка.
- [ ] Этап 1 (4–6н): B2C ядро (гости/RSVP/посадка/чек‑лист/бюджет), каталог+фильтры, сайт пары.
- [ ] Этап 2 (4–6н): B2B (заявки машина статусов, аналитика, офферы/late availability, верификация).
- [ ] Этап 3 (2–4н): перф/SEO/контент, финальные регрессы, go‑live.

---

# Приложение A — DTO и валидация (файловая раскладка)

## svc-auth/dto
```ts
// register.dto.ts
import { IsEmail, IsIn, IsString, MinLength, IsOptional } from 'class-validator';
export class RegisterDto {
  @IsEmail() email: string;
  @IsString() @MinLength(8) password: string;
  @IsIn(['PAIR','VENDOR']) role: 'PAIR'|'VENDOR';
  @IsOptional() @IsString() locale?: string; // 'ru' | 'uz'
}

// login.dto.ts
export class LoginDto { @IsEmail() email: string; @IsString() password: string; }

// refresh.dto.ts
export class RefreshDto { @IsString() refreshToken: string; }
```

## svc-enquiries/dto
```ts
// create-enquiry.dto.ts
import { IsDateString, IsInt, IsOptional, IsString, Min } from 'class-validator';
export class CreateEnquiryDto {
  @IsString() vendorId: string;
  @IsOptional() @IsString() venueId?: string;
  @IsOptional() @IsDateString() eventDate?: string;
  @IsOptional() @IsInt() @Min(1) guests?: number;
  @IsOptional() @IsInt() @Min(0) budget?: number;
}

// change-status.dto.ts
import { IsIn, IsString } from 'class-validator';
export class ChangeStatusDto {
  @IsIn(['NEW','QUOTE_SENT','CONTRACT_SIGNED','WON','LOST']) to: string;
  @IsString() from: string;
}
```

## svc-vendors/dto
```ts
// create-vendor.dto.ts
import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';
export class CreateVendorDto {
  @IsString() type: string; // 'TOYHANA' | 'PHOTO' | ...
  @IsString() title: string;
  @IsString() city: string;
  @IsOptional() @IsInt() @Min(0) priceFrom?: number;
}

// update-vendor.dto.ts
export class UpdateVendorDto {
  @IsOptional() @IsBoolean() verified?: boolean;
  @IsOptional() @IsInt() @Min(0) profileScore?: number;
}

// create-venue.dto.ts
export class CreateVenueDto {
  @IsString() title: string;
  @IsOptional() @IsInt() capacityMin?: number;
  @IsOptional() @IsInt() capacityMax?: number;
}

// create-offer.dto.ts
export class CreateOfferDto {
  @IsString() title: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsInt() price?: number;
  @IsOptional() @IsString() validFrom?: string;
  @IsOptional() @IsString() validTo?: string;
  @IsOptional() isHighlighted?: boolean;
}
```

## svc-guests/dto
```ts
// guest.dto.ts
import { IsEmail, IsOptional, IsPhoneNumber, IsString, IsIn, IsBoolean } from 'class-validator';
export class GuestDto {
  @IsString() name: string;
  @IsOptional() @IsPhoneNumber('UZ') phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() diet?: string;
  @IsOptional() @IsBoolean() plusOne?: boolean;
  @IsOptional() @IsIn(['INVITED','GOING','DECLINED','NO_RESPONSE']) status?: string;
}
```

---

# Приложение B — Команды
```
pnpm -w i
pnpm -w prisma:generate
pnpm -w prisma:migrate dev
pnpm -w lint && pnpm -w test && pnpm -w test:e2e
pnpm -w build
docker compose up -d
```

---

# Приложение C — DoD (единые критерии)
- Линтер/юнит/е2е зелёные; миграции применяются; OpenAPI отражает все эндпоинты.
- RU/UZ i18n покрывает все пользовательские тексты и ошибки.
- AuditEvent создаётся на ключевые изменения (статусы заявок, модерация, публикации).
- Перф: p95 каталога ≤200мс, auth ≤100мс, enquiries ≤150мс; импорт 10k гостей укладывается в целевой SLA.
- CI/CD автосборка и автодеплой на stage; smoke‑тест стенда зелёный.


