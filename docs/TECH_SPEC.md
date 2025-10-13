 WeddingTech UZ — TECH_SPEC (MVP v1)

**Цель:** за 1–4 дня. собрать MVP двусторонней платформы для свадебного рынка Узбекистана с акцентом на B2B-ценность: **Enquiry Manager** (CRM-lite) и **Analytics Dashboard**, одновременно давая парам базовые инструменты планирования и каталог поставщиков/Тойхан.

**От чего пляшем:** рынок >300 тыс. браков/год, выраженная сезонность (осенний пик); конкурент TO'YBOP на старте; глобальный бенчмарк Bridebook = B2B ROI-инструменты важнее, чем «планировщик как игрушка». Следовательно, MVP приоритезирует **измеримый ROI для поставщиков** (лиды, аналитика, позиция в поиске), а B2C — в объёме, достаточном для генерации спроса. (Источник: экспертный отчёт «Стратегия цифровизации…», разделы I–II, IV–VI.) 

---

## 1. Приоритеты MVP (строго по убыванию)

1) **B2B / Enquiry Manager (CRM-lite)**  
   - Сущности: `Enquiry`, `Supplier`, `Venue`.  
   - Статусы лида: `NEW` → `CONTACTED` → `QUOTED` → `CONTRACT_SIGNED` → `WON` / `LOST`.  
   - Переходы валидируются; комментарии/заметки по лидам; вложения опционально.
2) **B2B / Analytics Dashboard**  
   - Метрики: `total_enquiries`, `monthly_enquiries`, `profile_views`, `conversion_rate`.  
   - Конкурентные метрики (premium): `search_position_per_region`, `monthly_search_appearances`.  
   - Срезы по региону/категории/статусу лида.
3) **B2C / Каталог (минимум для спроса)**  
   - Поиск по Тойханам/поставщикам: регион, дата доступности, вместимость (для Тойхан), бюджет, рейтинг.  
   - Профиль поставщика/Тойханы: медиагалерея, описание, прайс-диапазон, контакты.
4) **B2C / Базовые планировщики**  
   - Список гостей (500+), RSVP, экспорт/импорт CSV; чек-лист и бюджет — базово.
5) **Инфраструктура/операторка**  
   - БД: PostgreSQL (Docker).  
   - Миграции Prisma; .env/.env.example; docker-compose для локалки.  
   - CI: build+test для `apps/svc-enquiries` на PR из `codex` в `main`.  
   - i18n RU/UZ (минимум: статический контент/лейблы).

---

## 2. Архитектура/стек/структура репозитория

**Стек:** Node 20, NestJS (REST), Prisma ORM, PostgreSQL, Next.js (frontend), pnpm/npm, GitHub Actions.

**Монорепо (уже частично создано):**
apps/
svc-enquiries/ # NestJS + Prisma (B2B API + часть B2C катл.)
prisma/ # schema.prisma, миграции
src/
main.ts
app.module.ts
health/
prisma/
enquiries/ # контроллер/сервис/DTO/валидаторы
analytics/ # контроллер/сервис
frontend/ # Next.js; каталог/поиск/лендинг, позже — планировщик
docs/
TECH_SPEC.md
CODEX_TASKS.md
.env.example
docker-compose.yml

kotlin
Копировать код

---

## 3. Модель данных (Prisma, минимум для MVP)

```prisma
// prisma/schema.prisma (apps/svc-enquiries/prisma)
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
generator client {
  provider = "prisma-client-js"
}

model Supplier {
  id          String   @id @default(cuid())
  type        String   // "venue" | "photographer" | ...
  name        String
  region      String   // "Tashkent" | "Samarkand" | ...
  address     String?
  capacity    Int?     // для Тойханы
  priceMin    Int?     // UZS
  priceMax    Int?
  rating      Float?   // 0..5
  photos      Json?    // массив ссылок
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
  enquiries   Enquiry[]
}

model Enquiry {
  id          String   @id @default(cuid())
  supplierId  String
  supplier    Supplier @relation(fields: [supplierId], references: [id], onDelete: Cascade)
  coupleName  String
  phone       String?
  email       String?
  eventDate   DateTime?
  budgetUZS   Int?
  guests      Int?
  status      EnquiryStatus @default(NEW)
  notes       String?
  source      String?  // "catalog", "invite", "direct"
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}

enum EnquiryStatus {
  NEW
  CONTACTED
  QUOTED
  CONTRACT_SIGNED
  WON
  LOST
}

model VenueAvailability {
  id         String   @id @default(cuid())
  supplierId String
  supplier   Supplier @relation(fields: [supplierId], references: [id], onDelete: Cascade)
  date       DateTime
  available  Boolean  @default(true)
  @@index([supplierId, date])
}
Инициализация: обязательны сиды (минимум: 3 Тойханы Ташкента + 2 поставщика других категорий; 5–10 Enquiry для аналитики).

4. API (NestJS, svc-enquiries)
4.1. Enquiries (CRUD + статусы)
bash
Копировать код
POST   /enquiries                     body: CreateEnquiryDto
GET    /enquiries                     query: EnquiryQueryDto (пагинация, фильтры)
GET    /enquiries/:id
PATCH  /enquiries/:id                 body: UpdateEnquiryDto
PATCH  /enquiries/:id/status          body: UpdateEnquiryStatusDto {status}
Статусы и переходы (валидация на сервисе):
NEW → CONTACTED → QUOTED → CONTRACT_SIGNED → WON/LOST (прямые обратные переходы запрещать).

DTO (валидация):

ts
Копировать код
// CreateEnquiryDto
{ supplierId: string; coupleName: string; phone?: string; email?: string; eventDate?: string(ISO); budgetUZS?: number; guests?: number; source?: string; notes?: string }

// EnquiryQueryDto
{ status?: EnquiryStatus; supplierId?: string; region?: string; dateFrom?: ISO; dateTo?: ISO; q?: string; page?: number; pageSize?: number }

// UpdateEnquiryDto
{ coupleName?: string; phone?: string; email?: string; eventDate?: ISO; budgetUZS?: number; guests?: number; notes?: string }

// UpdateEnquiryStatusDto
{ status: EnquiryStatus }
4.2. Suppliers/Venues (минимум)
bash
Копировать код
POST /suppliers
GET  /suppliers?type=venue&region=...&capacity>=...&date=YYYY-MM-DD
GET  /suppliers/:id
PATCH /suppliers/:id
Особое: для Тойхан — фильтр по дате/вместимости. Таблица VenueAvailability используется для ответа по доступности на дату.

4.3. Analytics (B2B дашборд)
rust
Копировать код
GET /analytics/overview?supplierId=...
 -> { totalEnquiries, monthlyEnquiries: [{month, count}], profileViews, conversionRate }

GET /analytics/competitive?supplierId=...   // premium
 -> { searchPositionPerRegion: [{region, position}], monthlySearchAppearances: [{month, count}] }
profileViews и конкурентные метрики сначала мокируются (счётчики на стороне сервиса + фиктивные данные), затем подключается реальная телеметрия фронта.

5. B2C (минимум)
Каталог/поиск (Next.js): страницы списка/деталей поставщика, фильтры (регион/дата/вместимость/бюджет/рейтинг).

Гости/RSVP: сервер хранит лист (до 5k записей), импорт CSV, экспорт CSV; RSVP через публичную ссылку (минимально).

Локализация RU/UZ (статические строки).

6. UX/Контент
Профиль поставщика: галерея (10–20 фото), цены в UZS, регион, контакты, FAQ.

Тойхана: акцент на вместимость, примеры рассадки, возможность загрузить план зала (пока файл).

Фронт минималистичный, адаптивный; SEO для страниц Тойхан.

7. Нефункциональные и соответствия
Производительность API: p95 < 300ms при 100 RPS на небольших инстансах.

Логи: уровень info+error; трассировка запросов.

Безопасность: rate limit публичных POST; валидация DTO; CORS.

I18n: RU/UZ (латиница), валюта UZS.

8. Конфигурация/окружение
.env.example (корень):

ini
Копировать код
# Postgres
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/weddingtech?schema=public

# Node
NODE_ENV=development
PORT=3001
docker-compose.yml (корень, локальный dev):

yaml
Копировать код
version: "3.9"
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: weddingtech
    ports: ["5432:5432"]
    volumes:
      - pg_data:/var/lib/postgresql/data
volumes:
  pg_data:
9. Сборка/команды (svc-enquiries)
bash
Копировать код
# в apps/svc-enquiries
npm ci
npm run prisma:generate
npm run prisma:migrate:dev   # применит миграции
npm run build
npm run start:dev
npm run test
npm run test:e2e
Скрипты npm (обязательно в package.json):

json
Копировать код
"scripts": {
  "build": "tsc -p tsconfig.build.json",
  "start": "node dist/main.js",
  "start:dev": "nest start --watch",
  "lint": "eslint .",
  "test": "jest --passWithNoTests",
  "test:e2e": "jest --config ./test/jest-e2e.json",
  "prisma:generate": "prisma generate",
  "prisma:migrate:dev": "prisma migrate dev --name init"
}
10. CI/CD
Workflow (уже есть auto-merge-codex.yml) — оставляем. Дополнительно (создать Codex-ом):

ci-enquiries.yml (trigger: pull_request в main из codex): Node 20 → npm ci → npm run prisma:generate → npm run build → npm test.

Статус этого CI обязателен для автомёрджа (правила защиты ветки — по мере надобности).

11. Критерии приёмки (MVP)
Enquiry Manager:

Создание лида (валидные/невалидные кейсы), смена статусов по разрешённым переходам.

Фильтры/пагинация на GET /enquiries.

Метрики overview возвращают корректные суммы по текущим данным.

Каталог:

GET /suppliers фильтрует по региону/типу, для Тойхан учитывает date и вместимость.

Профиль поставщика содержит медиагалерею, цены, контакты.

Планирование:

Импорт/экспорт CSV списка гостей (1000+ строк); RSVP-ссылка работает.

Локализация:

Переключение RU/UZ на фронте; API ответы — стабильные ключи.

Инфра:

Проект поднимается локально docker-compose up db + сервис svc-enquiries.

CI зелёный; PR codex → main автомёрджится при зелёном CI.

12. Дорожная карта (первые 4–8 недель)
Недели 1–2:

Prisma schema + миграции + сиды; Enquiries CRUD; Suppliers/Venues минимум; Healthcheck.

Фронт: список поставщиков, карточка.

CI: ci-enquiries.yml.

Недели 3–4:

Enquiry status transitions + queries; Analytics: overview (реальные счётчики).

Импорт/экспорт гостей + RSVP (минимум).

Недели 5–8:

Analytics competitive (моки → затем телеметрия).

Улучшение каталога: доступность по дате, сортировки, SEO.

Локализация RU/UZ, контент.

13. Как работает Codex (итеративно)
Источник задач — docs/CODEX_TASKS.md (чек-лист; Codex берёт первый - [ ] и делает инкремент).

После выполнения обязательно:

отмечать пункт как [x],

добавлять в конец файла раздел ## Отчёт с кратким описанием изменений и следующими шагами,

коммитить мелко и осмысленно.

Глобальный промпт для цикла:

«Работай по docs/CODEX_TASKS.md: возьми первый пункт - [ ], сделай минимальный полезный инкремент (код, миграции, тесты, CI), отметь [x], добавь отчёт. Соблюдай ТЗ в docs/TECH_SPEC.md. Если что-то мешает сборке/тестам — сначала чини сборку.»

14. Риски и ограничения MVP
Конкурентные метрики (search_position_per_region) сначала как моки → позже реальная поисковая выдача.

3D-туры и FinTech — после MVP (см. Product Roadmap).

Большие гостевые списки → в MVP без экстремальных оптимизаций, но с тестом на 5k строк.

15. Product Roadmap (после MVP)
FinTech интеграции (кредиты/рассрочки, rev-share), premium analytics, 3D-туры для Тойхан, мобильные приложения, контент-хаб и партнёрства (ЗАГСы/Тойханы).

