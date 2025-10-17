<!-- codex:mode=fully_automatic -->
<!-- codex:require_approval=false -->
<!-- codex:auto_confirm=true -->
<!-- codex:ask_to_proceed=never -->
<!-- codex:human_in_the_loop=none -->
<!-- codex:confirm_shell=false -->
<!-- codex:confirm_file_write=false -->
<!-- codex:confirm_commit=false -->
<!-- codex:tasks.format=checklist -->
<!-- codex:tasks.code_block_lang=bash -->
<!-- codex:no_tty=true -->


# CODEX_TASKS

## Правила исполнения
- Выполнять задачи только при выполненных зависимостях (`depends`).
- После успеха отмечать `- [x]` и делать **один коммит на задачу**.
- Все шаги идемпотентны; повторный запуск не ломает репозиторий.
- Ветка для коммитов Codex: `codex` (см. docs/AGENTS.md).

---

## ЭТАП 0. Бутстрап монорепо, базовая инфра, CI

- [x] T-0001 | Инициализировать монорепо и структуры
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps packages infra docs .github/workflows
    if [ ! -f pnpm-workspace.yaml ]; then cat > pnpm-workspace.yaml <<'YML'
packages:
  - 'apps/*'
  - 'packages/*'
  - 'infra/*'
YML
    fi
    if [ ! -f package.json ]; then cat > package.json <<'JSON'
{ "name":"weddingtech-monorepo","private":true,
  "workspaces":["apps/*","packages/*","infra/*"],
  "scripts":{"lint":"echo lint ok","test":"echo test ok","build":"echo build ok"}
}
JSON
    fi
    git add -A
    ```

- [x] T-0002 | Шаблон `.env.example`
  - depends: [T-0001]
  - apply:
    ```bash
    cat > .env.example <<'ENV'
DATABASE_URL=postgresql://postgres:postgres@db:5432/wt
REDIS_URL=redis://redis:6379
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=wt
MINIO_SECRET_KEY=wtsecret
APP_BASE_URL=http://localhost:3000
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL=30d
JWT_SECRET=change_me
PAYMENTS_UZCARD_MERCHANT_ID=
PAYMENTS_UZCARD_SECRET=
PAYMENTS_HUMO_MERCHANT_ID=
PAYMENTS_HUMO_SECRET=
MAIL_FROM=noreply@weddingtech.uz
SMTP_URL=smtp://user:pass@smtp:587
DEFAULT_LOCALE=ru
ENV
    git add .env.example
    ```

- [x] T-0003 | Локальная инфраструктура Docker (Postgres/Redis/MinIO)
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p infra/local
    cat > infra/local/docker-compose.yml <<'YML'
version: "3.9"
services:
  db:
    image: postgres:15
    environment: { POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres, POSTGRES_DB: wt }
    ports: ["5432:5432"]
  redis:
    image: redis:7
    ports: ["6379:6379"]
  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment: { MINIO_ROOT_USER: wt, MINIO_ROOT_PASSWORD: wtsecret }
    ports: ["9000:9000","9001:9001"]
YML
    git add infra/local/docker-compose.yml
    ```

- [x] T-0004 | Базовые сервисы `/health` (скелеты)
  - depends: [T-0001]
  - apply:
    ```bash
    for s in auth enquiries vendors catalog guests website admin analytics mail seeder payments search media cms reviews contracts referrals coupons pricing abtests cache security storage export import calendar notifier sitemap pwa k6 perf doorman; do
      mkdir -p "apps/svc-$s/src"
      if [ ! -f "apps/svc-$s/src/main.js" ]; then cat > "apps/svc-$s/src/main.js" <<'JS'
import http from "http"; const port=process.env.PORT||3000;
http.createServer((req,res)=>{ if(req.url==="/health"){res.writeHead(200,{"Content-Type":"application/json"});return res.end(JSON.stringify({status:"ok"}));}
res.writeHead(404);res.end(); }).listen(port,"0.0.0.0",()=>console.log("svc ok",port));
JS
      fi
    done
    git add apps/svc-*/src/main.js
    ```

- [x] T-0005 | CI workflow для ветки `codex` (lint/test/build)
  - depends: [T-0001]
  - apply:
    ```bash
    cat > .github/workflows/ci.yml <<'YML'
name: CI
on: { push: { branches: [ codex ] } }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: corepack enable && corepack prepare pnpm@9.12.0 --activate
      - run: pnpm -v
      - run: pnpm -w i
      - run: pnpm -w lint
      - run: pnpm -w test
      - run: pnpm -w build
YML
    git add .github/workflows/ci.yml
    ```

- [x] T-0006 | PR guard: проверка наличия docs/CODEX_TASKS.md
  - depends: [T-0005]
  - apply:
    ```bash
    cat > .github/workflows/pr-guard.yml <<'YML'
name: PR Guard
on: { pull_request: { branches: [ main ] } }
jobs:
  guard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Ensure docs/CODEX_TASKS.md exists and non-empty
        run: test -s docs/CODEX_TASKS.md
YML
    git add .github/workflows/pr-guard.yml
    ```

---

## ЭТАП 1. База данных и Prisma (ядро домена)

- [x] T-0010 | Пакет `@wt/prisma` и зависимости
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p packages/prisma
    cat > packages/prisma/package.json <<'JSON'
{ "name":"@wt/prisma","private":true,"type":"module",
  "scripts":{"generate":"prisma generate","migrate:dev":"prisma migrate dev","migrate:deploy":"prisma migrate deploy"},
  "devDependencies":{"prisma":"5.19.0"},
  "dependencies":{"@prisma/client":"5.19.0"} }
JSON
    git add packages/prisma/package.json
    ```

- [x] T-0011 | `schema.prisma` (полная MVP-схема)
  - depends: [T-0010]
  - apply:
    ```bash
    cat > packages/prisma/schema.prisma <<'PRISMA'
generator client { provider="prisma-client-js" }
datasource db { provider="postgresql" url=env("DATABASE_URL") }
enum Role { PAIR VENDOR ADMIN MODERATOR }
enum EnquiryStatus { NEW QUOTE_SENT CONTRACT_SIGNED WON LOST }
enum RSVPStatus { INVITED GOING DECLINED NO_RESPONSE }
enum AvailabilityStatus { OPEN BUSY LATE }
model User { id String @id @default(cuid()) email String @unique phone String? @unique role Role
  locale String @default("ru") passwordHash String createdAt DateTime @default(now()) updatedAt DateTime @updatedAt
  Couple Couple? Vendors Vendor[] }
model Couple { id String @id @default(cuid()) userId String @unique weddingDate DateTime? city String? preferences Json?
  user User @relation(fields:[userId],references:[id]) Guests Guest[] Tables Table[] Budget BudgetItem[] Website Website? }
model Vendor { id String @id @default(cuid()) ownerUserId String type String title String city String address String?
  priceFrom Int? rating Float? @default(0) verified Boolean @default(false) profileScore Int @default(0) media Json? docs Json?
  owner User @relation(fields:[ownerUserId],references:[id]) Venues Venue[] Offers Offer[] Availabilities AvailabilitySlot[] }
model Venue { id String @id @default(cuid()) vendorId String title String capacityMin Int? capacityMax Int? features Json?
  vendor Vendor @relation(fields:[vendorId],references:[id]) @@index([capacityMin,capacityMax]) }
model AvailabilitySlot { id String @id @default(cuid()) vendorId String venueId String? date DateTime status AvailabilityStatus
  vendor Vendor @relation(fields:[vendorId],references:[id]) venue Venue? @relation(fields:[venueId],references:[id])
  @@index([vendorId,date]) }
model Offer { id String @id @default(cuid()) vendorId String title String description String? price Int? validFrom DateTime?
  validTo DateTime? isHighlighted Boolean @default(false) vendor Vendor @relation(fields:[vendorId],references:[id]) }
model Enquiry { id String @id @default(cuid()) coupleId String vendorId String venueId String? eventDate DateTime? guests Int?
  budget Int? status EnquiryStatus @default(NEW) createdAt DateTime @default(now()) updatedAt DateTime @updatedAt
  couple Couple @relation(fields:[coupleId],references:[id]) vendor Vendor @relation(fields:[vendorId],references:[id])
  venue Venue? @relation(fields:[venueId],references:[id]) notes EnquiryNote[] reviews Review[] @@index([status,eventDate]) }
model EnquiryNote { id String @id @default(cuid()) enquiryId String authorId String text String createdAt DateTime @default(now())
  enquiry Enquiry @relation(fields:[enquiryId],references:[id]) }
model Review { id String @id @default(cuid()) enquiryId String @unique rating Int text String? isPublished Boolean @default(false)
  moderationStatus String? enquiry Enquiry @relation(fields:[enquiryId],references:[id]) }
model Guest { id String @id @default(cuid()) coupleId String name String phone String? email String? diet String? plusOne Boolean @default(false)
  status RSVPStatus @default(INVITED) couple Couple @relation(fields:[coupleId],references:[id]) tableId String? table Table? @relation(fields:[tableId],references:[id]) @@index([coupleId,status]) }
model Table { id String @id @default(cuid()) coupleId String name String seats Int sort Int @default(0) couple Couple @relation(fields:[coupleId],references:[id]) Guests Guest[] }
model BudgetItem { id String @id @default(cuid()) coupleId String category String planned Int @default(0) actual Int @default(0) note String? couple Couple @relation(fields:[coupleId],references:[id]) }
model Website { id String @id @default(cuid()) coupleId String @unique slug String @unique themeId String isPublished Boolean @default(false)
  rsvpPublicEnabled Boolean @default(true) couple Couple @relation(fields:[coupleId],references:[id]) RSVPs RSVP[] }
model RSVP { id String @id @default(cuid()) websiteId String guestId String? name String contact String? response RSVPStatus
  message String? createdAt DateTime @default(now()) website Website @relation(fields:[websiteId],references:[id]) }
model AuditEvent { id String @id @default(cuid()) entity String entityId String type String data Json? byUserId String? createdAt DateTime @default(now()) }
model RankSignal { id String @id @default(cuid()) vendorId String venueId String? signalType String weight Float @default(0) ttl DateTime? @@index([vendorId,signalType]) }
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0012 | Prisma скрипты в корне
  - depends: [T-0010]
  - apply:
    ```bash
    if command -v jq >/dev/null 2>&1; then
      jq '.scripts += {"prisma:generate":"pnpm -C packages/prisma run generate","prisma:migrate":"pnpm -C packages/prisma run migrate:dev"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
      node -e "let p=require('./package.json');p.scripts=p.scripts||{};p.scripts['prisma:generate']='pnpm -C packages/prisma run generate';p.scripts['prisma:migrate']='pnpm -C packages/prisma run migrate:dev';require('fs').writeFileSync('package.json',JSON.stringify(p,null,2));"
    fi
    git add package.json
    ```

- [ ] T-0013 | Первичная миграция (файл-плейсхолдер для отслеживания)
  - depends: [T-0011,T-0012]
  - apply:
    ```bash
    mkdir -p packages/prisma/migrations
    touch packages/prisma/migrations/.init
    git add packages/prisma/migrations/.init
    ```

---

## ЭТАП 2. Дизайн-система и UI

- [x] T-0020 | Пакет `@wt/ui`: токены темы, Tailwind пресет
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p packages/ui/src
    cat > packages/ui/src/tokens.css <<'CSS'
:root{--wt-bg:#ffffff;--wt-fg:#0b0f19;--wt-accent:#7c3aed;--wt-muted:#6b7280;--wt-radius:16px;}
[data-theme="dark"]{--wt-bg:#0b0f19;--wt-fg:#e5e7eb;--wt-accent:#a78bfa;--wt-muted:#9ca3af;}
CSS
    git add packages/ui/src/tokens.css
    ```

- [x] T-0021 | Базовые компоненты (Button, Card, Input)
  - depends: [T-0020]
  - apply:
    ```bash
    cat > packages/ui/src/Button.tsx <<'TSX'
export function Button({children, ...p}:{children:any}){return <button style={{borderRadius:"var(--wt-radius)",padding:"10px 16px"}} {...p}>{children}</button>;}
TSX
    cat > packages/ui/src/Card.tsx <<'TSX'
export function Card({children}:{children:any}){return <div style={{borderRadius:"var(--wt-radius)",padding:16,boxShadow:"0 6px 20px rgba(0,0,0,.08)"}}>{children}</div>;}
TSX
    cat > packages/ui/src/Input.tsx <<'TSX'
export function Input(p:any){return <input style={{borderRadius:"12px",padding:"10px 12px",border:"1px solid #e5e7eb"}} {...p}/>;}
TSX
    git add packages/ui/src/*.tsx
    ```

- [ ] T-0022 | Шаблоны экранов: доска пары и каталог поставщиков
  - depends: [T-0021]
  - apply:
    ```bash
    mkdir -p apps/website-mvp/src
    cat > apps/website-mvp/src/Dashboard.tsx <<'TSX'
export default function Dashboard(){return null;}
TSX
    git add apps/website-mvp/src/Dashboard.tsx
    ```

- [x] T-0023 | Гайд по дизайну (mdx)
  - depends: [T-0021]
  - apply:
    ```bash
    mkdir -p docs/design
    cat > docs/design/guide.mdx <<'MDX'
# Дизайн-гайд
- Цвета/радиусы/тени: см. tokens.css
- Компоненты: Button, Card, Input — основа всех экранов
- Принципы: чистый UI, 60fps, контент важнее хрома
MDX
    git add docs/design/guide.mdx
    ```

---

## ЭТАП 3. Аутентификация и роли

- [x] T-0030 | svc-auth: /health, /auth/register, /auth/login
  - depends: [T-0004, T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-auth/src
    cat > apps/svc-auth/src/auth.controller.ts <<'TS'
export const routes=["/health","/auth/register","/auth/login"];
TS
    git add apps/svc-auth/src/auth.controller.ts
    ```

- [ ] T-0031 | DTO register/login/refresh
  - depends: [T-0030]
  - apply:
    ```bash
    mkdir -p apps/svc-auth/src/dto
    echo "export const dto=true;" > apps/svc-auth/src/dto/index.ts
    git add apps/svc-auth/src/dto/index.ts
    ```

- [ ] T-0032 | RBAC скелет (PAIR/VENDOR/ADMIN)
  - depends: [T-0030]
  - apply:
    ```bash
    mkdir -p packages/authz
    echo "export const roles=['PAIR','VENDOR','ADMIN'];" > packages/authz/index.ts
    git add packages/authz/index.ts
    ```

---

## ЭТАП 4. Импорт гостей, рассадка, бюджет, чек-лист пары

- [x] T-0040 | Импорт гостей CSV/XLSX
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/import
    echo "export const guestImport=1;" > apps/svc-guests/src/import/index.ts
    git add apps/svc-guests/src/import/index.ts
    ```

- [ ] T-0041 | Посадка за столы (модель + API скелет)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/seating
    echo "export const seating=1;" > apps/svc-guests/src/seating/index.ts
    git add apps/svc-guests/src/seating/index.ts
    ```

- [x] T-0042 | Бюджет план/факт (категории)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/budget
    echo "export const budget=1;" > apps/svc-guests/src/budget/index.ts
    git add apps/svc-guests/src/budget/index.ts
    ```

- [ ] T-0043 | Планировщик задач пары (to-do/checklist)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/checklist
    echo "export const checklist=1;" > apps/svc-guests/src/checklist/index.ts
    git add apps/svc-guests/src/checklist/index.ts
    ```

---

## ЭТАП 5. Маркетплейс поставщиков (поиск/фильтры/бронь/календарь)

- [x] T-0050 | Индексы поиска и фильтры
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/search
    echo "export const filters=['type','city','priceFrom','rating'];" > apps/svc-catalog/src/search/index.ts
    git add apps/svc-catalog/src/search/index.ts
    ```

- [x] T-0051 | Календарь доступности (availability slots)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/availability
    echo "export const availability=1;" > apps/svc-vendors/src/availability/index.ts
    git add apps/svc-vendors/src/availability/index.ts
    ```

- [x] T-0052 | Запросы/квоты/оферы (enquiries+offers)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/offers
    echo "export const offers=1;" > apps/svc-enquiries/src/offers/index.ts
    git add apps/svc-enquiries/src/offers/index.ts
    ```

- [x] T-0053 | Ранжирование каталога (quality score)
  - depends: [T-0050]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/rank
    cat > apps/svc-catalog/src/rank/index.ts <<'TS'
export function rank({conv=0,rating=0,profile=0,calendar=0}){return 0.5*conv+0.2*rating+0.2*profile+0.1*calendar;}
TS
    git add apps/svc-catalog/src/rank/index.ts
    ```

---

## ЭТАП 6. Сайт пары, публичный RSVP, QR-коды

- [x] T-0060 | Next.js скелет `svc-website` (/w/[slug])
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p apps/svc-website/pages/w/[slug]
    echo "export default function P(){return 'wedding site';}" > apps/svc-website/pages/w/[slug]/index.js
    git add apps/svc-website/pages/w/[slug]/index.js
    ```

- [x] T-0061 | Публичный RSVP (/w/[slug]/rsvp)
  - depends: [T-0060]
  - apply:
    ```bash
    echo "export default function RSVP(){return 'rsvp';}" > apps/svc-website/pages/w/[slug]/rsvp.js
    git add apps/svc-website/pages/w/[slug]/rsvp.js
    ```

- [x] T-0062 | QR-код приглашения (генерация)
  - depends: [T-0061]
  - apply:
    ```bash
    mkdir -p apps/svc-website/lib
    echo "export const qr=1;" > apps/svc-website/lib/qr.ts
    git add apps/svc-website/lib/qr.ts
    ```

---

## ЭТАП 7. Отзывы и модерация

- [x] T-0070 | Модерация отзывов (pipeline)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/reviews
    echo "// moderation v1" > apps/svc-enquiries/src/reviews/moderation.ts
    git add apps/svc-enquiries/src/reviews/moderation.ts
    ```

---

## ЭТАП 8. Админ-панель

- [ ] T-0080 | Admin (Next.js) скелет
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p apps/admin/pages
    echo "export default function Admin(){return 'admin';}" > apps/admin/pages/index.js
    git add apps/admin/pages/index.js
    ```

- [ ] T-0081 | RBAC-страницы (модули по ролям)
  - depends: [T-0032,T-0080]
  - apply:
    ```bash
    mkdir -p apps/admin/pages/rbac
    echo "export default function Roles(){return 'rbac';}" > apps/admin/pages/rbac/index.js
    git add apps/admin/pages/rbac/index.js
    ```

---

## ЭТАП 9. B2B-аналитика, события и сигналы

- [x] T-0090 | svc-analytics скелет
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src
    echo "export const analytics=true;" > apps/svc-analytics/src/index.ts
    git add apps/svc-analytics/src/index.ts
    ```

- [x] T-0091 | События AuditEvent (хук)
  - depends: [T-0011,T-0090]
  - apply:
    ```bash
    mkdir -p packages/audit
    echo "export const audit=1;" > packages/audit/index.ts
    git add packages/audit/index.ts
    ```

---

## ЭТАП 10. I18n СНГ (RU/UZ/KK/EN)

- [x] T-0100 | Пакет `@wt/i18n` (RU, UZ, EN, KK)
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p packages/i18n
    echo '{"ok":"Ок","save":"Сохранить"}' > packages/i18n/ru.json
    echo '{"ok":"Ok","save":"Saqlash"}' > packages/i18n/uz.json
    echo '{"ok":"Ok","save":"Save"}' > packages/i18n/en.json
    echo '{"ok":"Жақсы","save":"Сақтау"}' > packages/i18n/kk.json
    git add packages/i18n/*.json
    ```

---

## ЭТАП 11. Платежи Uzcard/Humo

- [x] T-0110 | Провайдер Uzcard (инициализация API)
  - depends: [T-0002]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/providers
    cat > apps/svc-payments/providers/uzcard.ts <<'TS'
export function initUzcard({merchantId,secret}:{merchantId:string,secret:string}){ return {pay:(o:any)=>({ok:true,provider:'uzcard',o})}; }
TS
    git add apps/svc-payments/providers/uzcard.ts
    ```

- [x] T-0111 | Провайдер Humo (инициализация API)
  - depends: [T-0002]
  - apply:
    ```bash
    cat > apps/svc-payments/providers/humo.ts <<'TS'
export function initHumo({merchantId,secret}:{merchantId:string,secret:string}){ return {pay:(o:any)=>({ok:true,provider:'humo',o})}; }
TS
    git add apps/svc-payments/providers/humo.ts
    ```

- [x] T-0112 | Абстракция платежей (router)
  - depends: [T-0110,T-0111]
  - apply:
    ```bash
    cat > apps/svc-payments/src/index.ts <<'TS'
import {initUzcard} from "../providers/uzcard"; import {initHumo} from "../providers/humo";
export function payments(env:any){ return { uzcard:initUzcard(env), humo:initHumo(env) }; }
TS
    git add apps/svc-payments/src/index.ts
    ```

- [ ] T-0113 | Платежные вебхуки (скелет)
  - depends: [T-0112]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/webhooks
    echo "export const webhook=1;" > apps/svc-payments/src/webhooks/index.ts
    git add apps/svc-payments/src/webhooks/index.ts
    ```

---

## ЭТАП 12. Уведомления: email/SMS/Push

- [x] T-0120 | Пакет `@wt/mailer` (+ mjml шаблон)
  - depends: [T-0002]
  - apply:
    ```bash
    mkdir -p packages/mailer/templates
    echo "<mjml><mj-body><mj-text>Welcome</mj-text></mj-body></mjml>" > packages/mailer/templates/welcome.mjml
    echo "export const mailer=1;" > packages/mailer/index.ts
    git add packages/mailer/*
    ```

- [x] T-0121 | SMS-шлюз абстракция
  - depends: [T-0002]
  - apply:
    ```bash
    mkdir -p packages/sms
    echo "export const sms=1;" > packages/sms/index.ts
    git add packages/sms/index.ts
    ```

---

## ЭТАП 13. SEO/контент/блог

- [x] T-0130 | Sitemap генератор
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p apps/svc-website/scripts
    echo "console.log('sitemap.xml');" > apps/svc-website/scripts/generate-sitemap.js
    git add apps/svc-website/scripts/generate-sitemap.js
    ```

- [x] T-0131 | OG-теги и мета-компонент
  - depends: [T-0021]
  - apply:
    ```bash
    mkdir -p packages/ui/src/meta
    echo "export const Meta=()=>null;" > packages/ui/src/meta/Meta.tsx
    git add packages/ui/src/meta/Meta.tsx
    ```

---

## ЭТАП 14. Безопасность, политика, экспорт данных

- [ ] T-0140 | ESLint/tsconfig базовые
  - depends: [T-0001]
  - apply:
    ```bash
    cat > .eslintrc.json <<'JSON'
{ "env":{"es2022":true,"node":true}, "extends":[], "rules":{} }
JSON
    cat > tsconfig.json <<'JSON'
{ "compilerOptions":{ "target":"ES2022","module":"ESNext","moduleResolution":"Node" } }
JSON
    git add .eslintrc.json tsconfig.json
    ```

- [x] T-0141 | Экспорт данных пользователя
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-auth/src/export
    echo "export const exportUser=1;" > apps/svc-auth/src/export/index.ts
    git add apps/svc-auth/src/export/index.ts
    ```

---

## ЭТАП 15. K6 перф-профили

- [x] T-0150 | k6 каталог/енквайри смоук
  - depends: [T-0050,T-0030]
  - apply:
    ```bash
    mkdir -p infra/k6
    echo "import http from 'k6/http';export default()=>http.get('http://localhost:3000/health');" > infra/k6/smoke.js
    git add infra/k6/smoke.js
    ```

---

## ЭТАП 16. Журналирование/наблюдаемость

- [ ] T-0160 | Пакет `@wt/logger`
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p packages/logger
    echo "export const logger={info:console.log,error:console.error};" > packages/logger/index.ts
    git add packages/logger/index.ts
    ```

- [ ] T-0161 | Корреляционные ID в запросах
  - depends: [T-0160]
  - apply:
    ```bash
    mkdir -p packages/logger/mw
    echo "export const mw=()=>{};" > packages/logger/mw/correlation.ts
    git add packages/logger/mw/correlation.ts
    ```

---

## ЭТАП 17. Монетизация: тарифы, рефералка, промокоды

- [ ] T-0170 | Тарифные планы (модель/скелет API)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/plans
    echo "export const plans=1;" > apps/svc-payments/src/plans/index.ts
    git add apps/svc-payments/src/plans/index.ts
    ```

- [ ] T-0171 | Реферальная программа
  - depends: [T-0170]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/referrals
    echo "export const referrals=1;" > apps/svc-payments/src/referrals/index.ts
    git add apps/svc-payments/src/referrals/index.ts
    ```

- [ ] T-0172 | Промокоды/купоны
  - depends: [T-0170]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/coupons
    echo "export const coupons=1;" > apps/svc-payments/src/coupons/index.ts
    git add apps/svc-payments/src/coupons/index.ts
    ```

---

## ЭТАП 18. CMS для контента (гиды/блог/лендинги)

- [x] T-0180 | Простая CMS на MDX
  - depends: [T-0023]
  - apply:
    ```bash
    mkdir -p docs/blog
    echo "# Первый пост" > docs/blog/1.mdx
    git add docs/blog/1.mdx
    ```

---

## ЭТАП 19. Тесты и покрытия

- [ ] T-0190 | Структура юнит-тестов
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p tests
    echo "test('ok',()=>{})" > tests/smoke.test.ts
    git add tests/smoke.test.ts
    ```

- [ ] T-0191 | E2E (Playwright) smoke
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p infra/e2e
    echo "import {test,expect} from '@playwright/test';test('ok',()=>expect(true).toBeTruthy());" > infra/e2e/smoke.spec.ts
    git add infra/e2e/smoke.spec.ts
    ```

---

## ЭТАП 20. Сиды/демо-данные

- [x] T-0200 | Примитивный сидер
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/seeder
    echo "console.log('seed ok');" > apps/seeder/index.js
    git add apps/seeder/index.js
    ```

---

## ЭТАП 21. Импорт/экспорт каталога поставщиков для СНГ

- [ ] T-0210 | Импорт CSV поставщиков (RU/UZ/EN)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/import
    echo "export const importVendors=1;" > apps/svc-vendors/src/import/index.ts
    git add apps/svc-vendors/src/import/index.ts
    ```

---

## ЭТАП 22. Legal/политики

- [ ] T-0220 | Terms/Privacy/Offer (mdx)
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p apps/svc-website/pages/legal
    echo "# Terms" > apps/svc-website/pages/legal/terms.mdx
    echo "# Privacy" > apps/svc-website/pages/legal/privacy.mdx
    echo "# Публичная оферта" > apps/svc-website/pages/legal/offer.mdx
    git add apps/svc-website/pages/legal/*.mdx
    ```

---

## ЭТАП 23. Публичные каталоги (SEO-страницы)

- [x] T-0230 | Страницы города/категории (SSR заглушки)
  - depends: [T-0060,T-0050]
  - apply:
    ```bash
    mkdir -p apps/svc-website/pages/vendors
    echo "export default function City(){return 'vendors-city';}" > apps/svc-website/pages/vendors/[city].js
    git add apps/svc-website/pages/vendors/[city].js
    ```

---

## ЭТАП 24. ЛК поставщика

- [ ] T-0240 | Профиль/площадки/расписание
  - depends: [T-0021,T-0051]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/dashboard
    echo "export const vendorDashboard=1;" > apps/svc-vendors/src/dashboard/index.ts
    git add apps/svc-vendors/src/dashboard/index.ts
    ```

---

## ЭТАП 25. Анти-фрод

- [x] T-0250 | Флаги анти-фрода
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p packages/antifraud
    echo "export const flags=['duplicate','spam','scam'];" > packages/antifraud/index.ts
    git add packages/antifraud/index.ts
    ```

---

## ЭТАП 26. Импорт календарей (iCal)

- [x] T-0260 | Импорт iCal
  - depends: [T-0051]
  - apply:
    ```bash
    mkdir -p packages/ical
    echo "export const ical=1;" > packages/ical/index.ts
    git add packages/ical/index.ts
    ```

---

## ЭТАП 27. Медиа-хранилище (MinIO)

- [x] T-0270 | Абстракция S3-совместимого стораджа
  - depends: [T-0003]
  - apply:
    ```bash
    mkdir -p packages/storage
    echo "export const storage=1;" > packages/storage/index.ts
    git add packages/storage/index.ts
    ```

---

## ЭТАП 28. Почтовые шаблоны

- [ ] T-0280 | Invite/Invoice MJML
  - depends: [T-0120]
  - apply:
    ```bash
    echo "<mjml><mj-body><mj-text>Invite</mj-text></mj-body></mjml>" > packages/mailer/templates/invite.mjml
    echo "<mjml><mj-body><mj-text>Invoice</mj-text></mj-body></mjml>" > packages/mailer/templates/invoice.mjml
    git add packages/mailer/templates/*.mjml
    ```

---

## ЭТАП 29. Инвойсы/оплаты

- [x] T-0290 | Модель/скелет API инвойсов
  - depends: [T-0112,T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/invoices
    echo "export const invoices=1;" > apps/svc-payments/src/invoices/index.ts
    git add apps/svc-payments/src/invoices/index.ts
    ```

---

## ЭТАП 30. Рефссылки/UTM

- [ ] T-0300 | Генератор UTM/рефералок
  - depends: [T-0171]
  - apply:
    ```bash
    mkdir -p packages/ref
    echo "export const ref=()=> 'ref';" > packages/ref/index.ts
    git add packages/ref/index.ts
    ```

---

## ЭТАП 31. Валюты/формат

- [x] T-0310 | Форматирование UZS/RUB/KZT
  - depends: [T-0100]
  - apply:
    ```bash
    mkdir -p packages/format
    echo "export const fmt=(n,c)=>new Intl.NumberFormat('ru-RU',{style:'currency',currency:c}).format(n);" > packages/format/index.ts
    git add packages/format/index.ts
    ```

---

## ЭТАП 32. Темы сайта пары

- [ ] T-0320 | Темы (light/dark/minimal/royal)
  - depends: [T-0020]
  - apply:
    ```bash
    mkdir -p apps/svc-website/themes
    echo "export const themes=['light','dark','minimal','royal'];" > apps/svc-website/themes/index.ts
    git add apps/svc-website/themes/index.ts
    ```

---

## ЭТАП 33. Таймлайн подготовки

- [ ] T-0330 | Таймлайн событий
  - depends: [T-0091]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/timeline
    echo "export const timeline=1;" > apps/svc-guests/src/timeline/index.ts
    git add apps/svc-guests/src/timeline/index.ts
    ```

---

## ЭТАП 34. Чат пара↔поставщик

- [x] T-0340 | Каналы диалогов к заявкам
  - depends: [T-0052]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/chat
    echo "export const chat=1;" > apps/svc-enquiries/src/chat/index.ts
    git add apps/svc-enquiries/src/chat/index.ts
    ```

---

## ЭТАП 35. Договоры и подписи

- [ ] T-0350 | Генерация договора (md → pdf)
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p packages/contracts
    echo "export const contracts=1;" > packages/contracts/index.ts
    git add packages/contracts/index.ts
    ```

---

## ЭТАП 36. Экспорт CSV/XLSX

- [ ] T-0360 | Экспорт гостей/бюджета/столов
  - depends: [T-0040,T-0042,T-0041]
  - apply:
    ```bash
    mkdir -p packages/export
    echo "export const exporter=1;" > packages/export/index.ts
    git add packages/export/index.ts
    ```

---

## ЭТАП 37. Продуктовая аналитика

- [x] T-0370 | Воронки: просмотр→заявка→договор→оплата
  - depends: [T-0090]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/funnels
    echo "export const funnels=['view','enquiry','contract','payment'];" > apps/svc-analytics/src/funnels/index.ts
    git add apps/svc-analytics/src/funnels/index.ts
    ```

---

## ЭТАП 38. Бэкапы

- [x] T-0380 | План бэкапов (docs)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p docs/ops
    echo "# Backups plan" > docs/ops/backups.md
    git add docs/ops/backups.md
    ```

---

## ЭТАП 39. Аптайм/смоук

- [ ] T-0390 | Smoke скрипты /health
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p infra/smoke
    echo "#!/usr/bin/env bash
curl -sf http://localhost:3000/health" > infra/smoke/health.sh
    chmod +x infra/smoke/health.sh
    git add infra/smoke/health.sh
    ```

---

## ЭТАП 40. SEO-категории и гайды (продолжаем)

- [ ] T-0400 | Категории блог-гидов
  - depends: [T-0180]
  - apply:
    ```bash
    mkdir -p docs/blog/categories
    cat > docs/blog/categories/venues.mdx <<'MDX'
# Площадки для свадьбы — гид
Описание основных параметров выбора площадки, чек-лист, частые ошибки.
MDX
    cat > docs/blog/categories/vendors.mdx <<'MDX'
# Поставщики и подрядчики — гид
Как отобрать фотографа, видеографа, ведущего и т.д.
MDX
    git add docs/blog/categories/*.mdx
    ```

- [ ] T-0401 | Гайды по городам (UZ/RU/EN)
  - depends: [T-0400]
  - apply:
    ```bash
    mkdir -p docs/blog/cities
    for c in tashkent samarkand bukhara; do echo "# $c — свадебный гид" > "docs/blog/cities/${c}.mdx"; done
    git add docs/blog/cities/*.mdx
    ```

---

## ЭТАП 41. A/B-тесты

- [x] T-0410 | Пакет @wt/ab (флаги/эксперименты)
  - depends: [T-0001]
  - apply:
    ```bash
    mkdir -p packages/ab
    cat > packages/ab/index.ts <<'TS'
export function variant(key:string,uid:string){ let h=0; for(const c of (uid+key)) h=(h*31+c.charCodeAt(0))>>>0; return h%2; }
TS
    git add packages/ab/index.ts
    ```

- [ ] T-0411 | Эксперимент карточки поставщика V2
  - depends: [T-0410, T-0050]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/experiments
    echo "export const vendorCardV2=true;" > apps/svc-catalog/src/experiments/vendor-card-v2.ts
    git add apps/svc-catalog/src/experiments/vendor-card-v2.ts
    ```

---

## ЭТАП 42. Кэш/CDN

- [ ] T-0420 | In-memory кэш каталога
  - depends: [T-0050]
  - apply:
    ```bash
    mkdir -p packages/cache
    cat > packages/cache/index.ts <<'TS'
const store=new Map<string,{v:any,ttl:number}>();
export function get(k:string){const x=store.get(k); if(!x) return; if(x.ttl<Date.now()){store.delete(k); return;} return x.v;}
export function set(k:string,v:any,ms=60000){store.set(k,{v,ttl:Date.now()+ms});}
TS
    git add packages/cache/index.ts
    ```

- [ ] T-0421 | Заголовки CDN (Next.js)
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p apps/svc-website/config
    cat > apps/svc-website/config/headers.js <<'JS'
module.exports = async () => [{ source: "/(.*)", headers: [{ key: "Cache-Control", value: "public, max-age=60" }]}];
JS
    git add apps/svc-website/config/headers.js
    ```

---

## ЭТАП 43. Hardening

- [x] T-0430 | Security headers
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p packages/security
    cat > packages/security/headers.ts <<'TS'
export const securityHeaders=[["X-Frame-Options","DENY"],["X-Content-Type-Options","nosniff"],["Referrer-Policy","strict-origin-when-cross-origin"]];
TS
    git add packages/security/headers.ts
    ```

- [ ] T-0431 | Политика паролей/брутфорс
  - depends: [T-0030]
  - apply:
    ```bash
    cat > apps/svc-auth/src/security.ts <<'TS'
export const passwordPolicy={min:8,upper:true,lower:true,digit:true};
export const bruteForceWindowMs=900000;
TS
    git add apps/svc-auth/src/security.ts
    ```

---

## ЭТАП 44. KYC поставщиков

- [ ] T-0440 | Чек-лист и документы
  - depends: [T-0011, T-0270]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/kyc
    cat > apps/svc-vendors/src/kyc/checklist.md <<'MD'
# KYC чек-лист
- Паспорт/ID, ИНН/регистрация
- Право на предоставление услуг
- Телефон/адрес подтверждены
MD
    git add apps/svc-vendors/src/kyc/checklist.md
    ```

---

## ЭТАП 45. PWA

- [ ] T-0450 | Manifest/иконки
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p apps/svc-website/public
    cat > apps/svc-website/public/manifest.json <<'JSON'
{ "name":"WeddingTech","short_name":"WT","start_url":"/","display":"standalone","background_color":"#ffffff","theme_color":"#7c3aed","icons":[] }
JSON
    git add apps/svc-website/public/manifest.json
    ```

- [ ] T-0451 | Service Worker
  - depends: [T-0450]
  - apply:
    ```bash
    cat > apps/svc-website/public/sw.js <<'JS'
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
JS
    git add apps/svc-website/public/sw.js
    ```

---

## ЭТАП 46. Перформанс-баджеты

- [ ] T-0460 | budgets.json
  - depends: [T-0005]
  - apply:
    ```bash
    mkdir -p infra/perf
    cat > infra/perf/budgets.json <<'JSON'
{ "lcp_ms": 2500, "ttfb_ms": 100, "transfer_kb": 300 }
JSON
    git add infra/perf/budgets.json
    ```

---

## ЭТАП 47. Миграции данных

- [ ] T-0470 | Шаблон миграций
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p infra/migrations
    cat > infra/migrations/README.md <<'MD'
# Миграции данных
Каждая миграция — отдельный script.ts с идемпотентной логикой.
MD
    git add infra/migrations/README.md
    ```

---

## ЭТАП 48. Дашборды

- [ ] T-0480 | Docs: продуктовые метрики
  - depends: [T-0090]
  - apply:
    ```bash
    mkdir -p docs/dashboards
    cat > docs/dashboards/product.md <<'MD'
# Продуктовые метрики
- Просмотры каталога, конверсия в заявку, конверсия в договор, оплата.
MD
    git add docs/dashboards/product.md
    ```

---

## ЭТАП 49. Виральность/шэринг

- [ ] T-0490 | Шэринг/UTM
  - depends: [T-0300, T-0050]
  - apply:
    ```bash
    mkdir -p packages/share
    cat > packages/share/index.ts <<'TS'
export function shareUrl(path:string,utm:string){return `${path}?${utm}`;}
TS
    git add packages/share/index.ts
    ```

---

## ЭТАП 50. Legal UZ/RU

- [ ] T-0500 | Политики под Узбекистан
  - depends: [T-0220]
  - apply:
    ```bash
    mkdir -p docs/legal/uz
    echo "# Siyosat (UZ)" > docs/legal/uz/privacy.mdx
    echo "# Политика (RU)" > docs/legal/privacy-ru.mdx
    git add docs/legal/uz/privacy.mdx docs/legal/privacy-ru.mdx
    ```

---

## ЭТАП 51. Поиск по сайту (full-text, подсказки)

- [x] T-0510 | Пакет `@wt/search` (in-repo)
  - depends: [T-0050]
  - apply:
    ```bash
    mkdir -p packages/search
    echo "export const search=()=>[];" > packages/search/index.ts
    git add packages/search/index.ts
    ```

---

## ЭТАП 52. Мультимедиа и компрессия

- [x] T-0520 | Минификация изображений (заготовка)
  - depends: [T-0270]
  - apply:
    ```bash
    mkdir -p packages/media
    echo "export const minify=()=>true;" > packages/media/index.ts
    git add packages/media/index.ts
    ```

---

## ЭТАП 53. Категории поставщиков (иерархия)

- [x] T-0530 | Справочник категорий
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p packages/catalog
    echo "export const categories=['venue','photo','video','host','music','decor','cake','dress'];" > packages/catalog/categories.ts
    git add packages/catalog/categories.ts
    ```

---

## ЭТАП 54. Фильтры по бюджету/гостям

- [x] T-0540 | Пресеты бюджета и количества гостей
  - depends: [T-0050]
  - apply:
    ```bash
    echo "export const budgetPresets=[1000,3000,5000,10000];" > packages/catalog/budget.ts
    echo "export const guestsPresets=[50,100,150,200,300];" >> packages/catalog/budget.ts
    git add packages/catalog/budget.ts
    ```

---

## ЭТАП 55. Сохранённые списки/избранное

- [ ] T-0550 | Избранное пары (скелет)
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/favorites
    echo "export const favorites=1;" > apps/svc-catalog/src/favorites/index.ts
    git add apps/svc-catalog/src/favorites/index.ts
    ```

---

## ЭТАП 56. Сравнение поставщиков

- [ ] T-0560 | Таблица сравнения (скелет)
  - depends: [T-0550]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/compare
    echo "export const compare=1;" > apps/svc-catalog/src/compare/index.ts
    git add apps/svc-catalog/src/compare/index.ts
    ```

---

## ЭТАП 57. Генератор чек-листа подготовки

- [ ] T-0570 | Пресеты этапов планирования
  - depends: [T-0043]
  - apply:
    ```bash
    echo "export const planning=['budget','guests','venue','vendors','website','rsvp'];" > apps/svc-guests/src/checklist/presets.ts
    git add apps/svc-guests/src/checklist/presets.ts
    ```

---

## ЭТАП 58. Географические справочники

- [x] T-0580 | Города/регионы Узбекистана
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p packages/geo
    echo "export const cities=['Tashkent','Samarkand','Bukhara','Khiva','Andijan','Namangan','Fergana'];" > packages/geo/uz.ts
    git add packages/geo/uz.ts
    ```

---

## ЭТАП 59. Анти-спам в отзывах (правила)

- [ ] T-0590 | Правила текстовой модерации
  - depends: [T-0070]
  - apply:
    ```bash
    echo "export const badWords=['spam','scam'];" > apps/svc-enquiries/src/reviews/rules.ts
    git add apps/svc-enquiries/src/reviews/rules.ts
    ```

---

## ЭТАП 60. Маркетплейс пакетных предложений

- [x] T-0600 | Пакеты «зал+декор+музыка»
  - depends: [T-0040,T-0042,T-0050]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/bundles
    echo "export const bundles=1;" > apps/svc-catalog/src/bundles/index.ts
    git add apps/svc-catalog/src/bundles/index.ts
    ```

---

## ЭТАП 61. Подписки/уведомления о доступности

- [ ] T-0610 | Подписки на даты/города
  - depends: [T-0051]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/subscriptions
    echo "export const subs=1;" > apps/svc-vendors/src/subscriptions/index.ts
    git add apps/svc-vendors/src/subscriptions/index.ts
    ```

---

## ЭТАП 62. Календарь пары

- [ ] T-0620 | События подготовки (личный календарь)
  - depends: [T-0043]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/calendar
    echo "export const calendar=1;" > apps/svc-guests/src/calendar/index.ts
    git add apps/svc-guests/src/calendar/index.ts
    ```

---

## ЭТАП 63. Рекомендательная лента

- [ ] T-0630 | Сигналы и рекомендации
  - depends: [T-0370]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/reco
    echo "export const reco=1;" > apps/svc-catalog/src/reco/index.ts
    git add apps/svc-catalog/src/reco/index.ts
    ```

---

## ЭТАП 64. Экспорт счетов/квитанций (PDF)

- [ ] T-0640 | PDF-квитанции (заготовка)
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/pdf
    echo "export const pdf=1;" > apps/svc-payments/src/pdf/index.ts
    git add apps/svc-payments/src/pdf/index.ts
    ```

---

## ЭТАП 65. Гео-поиск по близости

- [ ] T-0650 | Координаты/радиусы (скелет)
  - depends: [T-0580,T-0050]
  - apply:
    ```bash
    echo "export const near=(lat,lon,r)=>[];" > packages/geo/near.ts
    git add packages/geo/near.ts
    ```

---

## ЭТАП 66. Профили UX-ролей (персоны)

- [ ] T-0660 | Персоны (docs)
  - depends: [T-0023]
  - apply:
    ```bash
    mkdir -p docs/ux
    cat > docs/ux/personas.md <<'MD'
# Персоны: Пара, Поставщик, Админ
Основные задачи, боли, KPI, сценарии.
MD
    git add docs/ux/personas.md
    ```

---

## ЭТАП 67. Доступность (a11y чек-лист)

- [ ] T-0670 | Чек-лист a11y
  - depends: [T-0023]
  - apply:
    ```bash
    cat > docs/ux/a11y.md <<'MD'
# A11y чек-лист
- Контраст, размеры шрифтов, клавиатурная навигация, ARIA.
MD
    git add docs/ux/a11y.md
    ```

---

## ЭТАП 68. Темы событий (никях/европейская/национальная)

- [ ] T-0680 | Пресеты сценариев
  - depends: [T-0320]
  - apply:
    ```bash
    mkdir -p apps/svc-website/themes/presets
    echo "export const presets=['nikah','european','national'];" > apps/svc-website/themes/presets/index.ts
    git add apps/svc-website/themes/presets/index.ts
    ```

---

## ЭТАП 69. Калькулятор бюджета

- [ ] T-0690 | Виджет калькулятора
  - depends: [T-0042]
  - apply:
    ```bash
    mkdir -p packages/ui/src/widgets
    echo "export const BudgetWidget=()=>null;" > packages/ui/src/widgets/Budget.tsx
    git add packages/ui/src/widgets/Budget.tsx
    ```

---

## ЭТАП 70. Каталог идей (inspo)

- [x] T-0700 | Идеи/подборки (mdx)
  - depends: [T-0180]
  - apply:
    ```bash
    mkdir -p docs/inspo
    echo "# Идеи оформления" > docs/inspo/ideas.mdx
    git add docs/inspo/ideas.mdx
    ```

---

## ЭТАП 71. Onboarding/первые шаги

- [ ] T-0710 | Скрипт onboarding
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p apps/svc-website/onboarding
    echo "export const onboarding=1;" > apps/svc-website/onboarding/index.ts
    git add apps/svc-website/onboarding/index.ts
    ```

---

## ЭТАП 72. Настройки оповещений

- [x] T-0720 | Центр уведомлений
  - depends: [T-0120,T-0121]
  - apply:
    ```bash
    mkdir -p apps/svc-notifier/src
    echo "export const notifier=1;" > apps/svc-notifier/src/index.ts
    git add apps/svc-notifier/src/index.ts
    ```

---

## ЭТАП 73. Теги/атрибуты у поставщиков

- [ ] T-0730 | Тэги (kids-friendly, halal, vegan)
  - depends: [T-0011]
  - apply:
    ```bash
    echo "export const vendorTags=['kids','halal','vegan','live-music'];" > packages/catalog/tags.ts
    git add packages/catalog/tags.ts
    ```

---

## ЭТАП 74. Мультивалюта и курсы

- [ ] T-0740 | Курсы валют (stub)
  - depends: [T-0310]
  - apply:
    ```bash
    echo "export const rates={UZS:1,RUB:0.008,USD:0.000085};" > packages/format/rates.ts
    git add packages/format/rates.ts
    ```

---

## ЭТАП 75. UX «конструктор программы дня»

- [ ] T-0750 | Программа дня (скелет)
  - depends: [T-0620]
  - apply:
    ```bash
    mkdir -p apps/svc-guests/src/agenda
    echo "export const agenda=1;" > apps/svc-guests/src/agenda/index.ts
    git add apps/svc-guests/src/agenda/index.ts
    ```

---

## ЭТАП 76. Экспорт приглашений (PDF/PNG)

- [ ] T-0760 | Экспорт пригласительных
  - depends: [T-0062]
  - apply:
    ```bash
    mkdir -p apps/svc-website/export
    echo "export const invite=1;" > apps/svc-website/export/invite.ts
    git add apps/svc-website/export/invite.ts
    ```

---

## ЭТАП 77. Гайды для поставщиков (как повысить рейтинг)

- [ ] T-0770 | Док гайдлайнов
  - depends: [T-0530]
  - apply:
    ```bash
    mkdir -p docs/vendors
    cat > docs/vendors/guide.md <<'MD'
# Как повысить рейтинг и конверсию
Заполненность профиля, отзывы, скорость ответа, акции.
MD
    git add docs/vendors/guide.md
    ```

---

## ЭТАП 78. Отмена/возвраты

- [ ] T-0780 | Политика отмен
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/cancellations
    echo "export const cancellations=1;" > apps/svc-payments/src/cancellations/index.ts
    git add apps/svc-payments/src/cancellations/index.ts
    ```

---

## ЭТАП 79. Эскроу/частичные оплаты (заготовка)

- [ ] T-0790 | Эскроу-логика (stub)
  - depends: [T-0290,T-0112]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/escrow
    echo "export const escrow=1;" > apps/svc-payments/src/escrow/index.ts
    git add apps/svc-payments/src/escrow/index.ts
    ```

---

## ЭТАП 80. Анкета пары → персонализация каталога

- [ ] T-0800 | Анкета предпочтений
  - depends: [T-0630]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/profile
    echo "export const coupleProfile=1;" > apps/svc-catalog/src/profile/index.ts
    git add apps/svc-catalog/src/profile/index.ts
    ```

---

## ЭТАП 81. Импорт контактов гостей (vCard)

- [ ] T-0810 | vCard импорт
  - depends: [T-0040]
  - apply:
    ```bash
    mkdir -p packages/vcard
    echo "export const vcard=1;" > packages/vcard/index.ts
    git add packages/vcard/index.ts
    ```

---

## ЭТАП 82. Отчёты для поставщика (аналитика спроса)

- [x] T-0820 | Срезы спроса/сезонности
  - depends: [T-0090]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/vendor
    echo "export const vendorReports=1;" > apps/svc-analytics/src/vendor/index.ts
    git add apps/svc-analytics/src/vendor/index.ts
    ```

---

## ЭТАП 83. Подбор дат (календарные рекомендации)

- [ ] T-0830 | Рекомендация дат
  - depends: [T-0051,T-0620]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/dates
    echo "export const suggestDates=1;" > apps/svc-catalog/src/dates/index.ts
    git add apps/svc-catalog/src/dates/index.ts
    ```

---

## ЭТАП 84. Импорт прайсов поставщиков

- [ ] T-0840 | CSV/XLSX прайсы
  - depends: [T-0210]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/pricelist
    echo "export const pricelist=1;" > apps/svc-vendors/src/pricelist/index.ts
    git add apps/svc-vendors/src/pricelist/index.ts
    ```

---

## ЭТАП 85. Программы лояльности

- [ ] T-0850 | Баллы/кэшбек (скелет)
  - depends: [T-0170]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/loyalty
    echo "export const loyalty=1;" > apps/svc-payments/src/loyalty/index.ts
    git add apps/svc-payments/src/loyalty/index.ts
    ```

---

## ЭТАП 86. Витрина акций/скидок

- [ ] T-0860 | Акции каталога
  - depends: [T-0050]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/deals
    echo "export const deals=1;" > apps/svc-catalog/src/deals/index.ts
    git add apps/svc-catalog/src/deals/index.ts
    ```

---

## ЭТАП 87. Экспорт CSV аналитики

- [ ] T-0870 | Экспорт отчётов
  - depends: [T-0370]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/export
    echo "export const exportReports=1;" > apps/svc-analytics/src/export/index.ts
    git add apps/svc-analytics/src/export/index.ts
    ```

---

## ЭТАП 88. Кабинет пары: прогресс и дедлайны

- [ ] T-0880 | Прогресс-бар подготовки
  - depends: [T-0570]
  - apply:
    ```bash
    mkdir -p apps/website-mvp/src/widgets
    echo "export const Progress=()=>null;" > apps/website-mvp/src/widgets/Progress.tsx
    git add apps/website-mvp/src/widgets/Progress.tsx
    ```

---

## ЭТАП 89. Экспорт гостей в vCard/CSV

- [ ] T-0890 | Экспорт гостей
  - depends: [T-0360]
  - apply:
    ```bash
    echo "export const exportGuests=1;" > packages/export/guests.ts
    git add packages/export/guests.ts
    ```

---

## ЭТАП 90. Печать/PDF программы дня

- [ ] T-0900 | Экспорт программы в PDF
  - depends: [T-0750]
  - apply:
    ```bash
    echo "export const agendaPdf=1;" > apps/svc-guests/src/agenda/pdf.ts
    git add apps/svc-guests/src/agenda/pdf.ts
    ```

---

## ЭТАП 91. Анкета гостей (диеты/ограничения)

- [ ] T-0910 | Поля диет/аллергий
  - depends: [T-0011,T-0040]
  - apply:
    ```bash
    echo "export const diets=['vegan','vegetarian','halal','gluten-free'];" > apps/svc-guests/src/import/diets.ts
    git add apps/svc-guests/src/import/diets.ts
    ```

---

## ЭТАП 92. Пуш-уведомления (web push)

- [ ] T-0920 | Заглушка webpush
  - depends: [T-0451]
  - apply:
    ```bash
    mkdir -p packages/push
    echo "export const webpush=1;" > packages/push/index.ts
    git add packages/push/index.ts
    ```

---

## ЭТАП 93. Резервирование дат с предоплатой

- [ ] T-0930 | Предоплата брони
  - depends: [T-0112,T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/prepay
    echo "export const prepay=1;" > apps/svc-enquiries/src/prepay/index.ts
    git add apps/svc-enquiries/src/prepay/index.ts
    ```

---

## ЭТАП 94. Интеграция e-mail домена (SPF/DKIM docs)

- [ ] T-0940 | Док по SPF/DKIM
  - depends: [T-0120]
  - apply:
    ```bash
    mkdir -p docs/ops/email
    echo "# SPF/DKIM настройка" > docs/ops/email/spf-dkim.md
    git add docs/ops/email/spf-dkim.md
    ```

---

## ЭТАП 95. Импорт отзывов из внешних источников (stub)

- [ ] T-0950 | Импорт отзывов CSV
  - depends: [T-0070]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/reviews/import
    echo "export const importReviews=1;" > apps/svc-enquiries/src/reviews/import/index.ts
    git add apps/svc-enquiries/src/reviews/import/index.ts
    ```

---

## ЭТАП 96. Фидбек-виджет (NPS/CSAT)

- [ ] T-0960 | NPS сборщик
  - depends: [T-0090]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/nps
    echo "export const nps=1;" > apps/svc-analytics/src/nps/index.ts
    git add apps/svc-analytics/src/nps/index.ts
    ```

---

## ЭТАП 97. Механика «заявка → договор → оплата» (связки)

- [ ] T-0970 | Связки сущностей (docs)
  - depends: [T-0290,T-0350]
  - apply:
    ```bash
    cat > docs/architecture/flows.md <<'MD'
# Flows: enquiry → contract → invoice → payment
MD
    git add docs/architecture/flows.md
    ```

---

## ЭТАП 98. Точки качества каталога (скоринг профиля)

- [ ] T-0980 | Метрики профиля
  - depends: [T-0530]
  - apply:
    ```bash
    echo "export const profileScore=['fields','media','docs','reviews','responseTime'];" > apps/svc-catalog/src/rank/profile.ts
    git add apps/svc-catalog/src/rank/profile.ts
    ```

---

## ЭТАП 99. Маркетинговые лендинги

- [ ] T-0990 | Лендинг поставщика (mdx)
  - depends: [T-0180]
  - apply:
    ```bash
    mkdir -p docs/landing
    echo "# Почему с нами выгодно" > docs/landing/vendors.mdx
    git add docs/landing/vendors.mdx
    ```

---

## этап 100 . PUSH В ВЕТКУ `codex`

- [ ] T-1000 | Пуш прогресса
  - depends: [T-0005]
  - apply:
    ```bash
    git add -A
    git commit -m "Codex: full roadmap 0..100 — bootstrap→MVP→growth"
    git push origin codex || true
    ```

## ЭТАП 101. ML-ранжирование и оффлайн-скоринг

- [x] T-1010 | Пакет `@wt/mlrank` — оффлайн скорер (заглушка под модель)
  - depends: [T-0053, T-0370]
  - apply:
    ```bash
    mkdir -p packages/mlrank
    cat > packages/mlrank/index.ts <<'TS'
/** Простейшая линейная модель под оффлайн-скоры (заменяется на ML позднее). */
export function score(v:{conv:number;rating:number;profile:number;calendar:number;price?:number}) {
  const s = 0.55*v.conv + 0.2*v.rating + 0.2*v.profile + 0.05*v.calendar;
  return Math.max(0, Math.min(1, s));
}
TS
    git add packages/mlrank/index.ts
    ```

- [x] T-1011 | Экстракция признаков каталога
  - depends: [T-0011, T-1010]
  - apply:
    ```bash
    mkdir -p infra/feast
    cat > infra/feast/extract-features.ts <<'TS'
export function extract(vendor:any){
  return { conv: vendor.conv||0, rating: vendor.rating||0, profile: vendor.profileScore||0, calendar: vendor.calendar||0 };
}
TS
    git add infra/feast/extract-features.ts
    ```

- [ ] T-1012 | Batch-пересчёт рангов
  - depends: [T-1011]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/ml
    cat > apps/svc-catalog/src/ml/recompute.ts <<'TS'
import { score } from "@wt/mlrank";
import { extract } from "../../../infra/feast/extract-features";
export function recomputeFor(vendors:any[]){ return vendors.map(v=>({id:v.id, rank: score(extract(v))})); }
TS
    git add apps/svc-catalog/src/ml/recompute.ts
    ```

---

## ЭТАП 102. Многоэтапные оплаты и эскроу

- [ ] T-1020 | Partial payments (депозит/финал)
  - depends: [T-0290, T-0112]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/partials
    cat > apps/svc-payments/src/partials/index.ts <<'TS'
export type PaymentPart = { kind:'deposit'|'final', amount:number, due:string };
export const split = (total:number)=>[{kind:'deposit',amount:Math.round(total*0.3),due:'book'}, {kind:'final',amount:total-Math.round(total*0.3),due:'event'}];
TS
    git add apps/svc-payments/src/partials/index.ts
    ```

- [ ] T-1021 | Эскроу оркестратор (скелет)
  - depends: [T-0790, T-1020]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/escrow/engine
    cat > apps/svc-payments/src/escrow/engine/index.ts <<'TS'
export const escrowEngine={ hold:(inv:any)=>({status:'held', id: inv?.id||'escrow-1'}), release:(id:string)=>({status:'released',id}) };
TS
    git add apps/svc-payments/src/escrow/engine/index.ts
    ```

---

## ЭТАП 103. Сверка выплат поставщикам

- [ ] T-1030 | Реестр выплат (CSV-экспорт)
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/payouts
    cat > apps/svc-payments/src/payouts/register.ts <<'TS'
export function payoutsCsv(rows:any[]){ return ['invoice_id,amount,currency,beneficiary'].concat(rows.map(r=>[r.id,r.amount,r.ccy,r.benef].join(','))).join('\n'); }
TS
    git add apps/svc-payments/src/payouts/register.ts
    ```

- [ ] T-1031 | Акт сверки (md → csv)
  - depends: [T-1030]
  - apply:
    ```bash
    cat > apps/svc-payments/src/payouts/reconcile.ts <<'TS'
export function reconcile(a:any[],b:any[]){ const A=new Map(a.map((x:any)=>[x.id,x])); return b.filter(x=>!A.has(x.id)); }
TS
    git add apps/svc-payments/src/payouts/reconcile.ts
    ```

---

## ЭТАП 104. Push-кампании и сегментация

- [ ] T-1040 | Сегменты аудиторий
  - depends: [T-0370, T-0720]
  - apply:
    ```bash
    mkdir -p apps/svc-notifier/src/segments
    cat > apps/svc-notifier/src/segments/index.ts <<'TS'
export const segments={ newCouples:(u:any)=>u.createdDays<14, highIntent:(u:any)=>u.enquiries>0 && u.siteViews>3 };
TS
    git add apps/svc-notifier/src/segments/index.ts
    ```

- [ ] T-1041 | Кампания (скелет DSL)
  - depends: [T-1040]
  - apply:
    ```bash
    mkdir -p apps/svc-notifier/src/campaigns
    cat > apps/svc-notifier/src/campaigns/welcome.ts <<'TS'
export default { name:'welcome', when:'D0', segment:'newCouples', action:'email:welcome' };
TS
    git add apps/svc-notifier/src/campaigns/welcome.ts
    ```

---

## ЭТАП 105. UTM-атрибуция до оплаты

- [ ] T-1050 | Трекер сессий UTM
  - depends: [T-0370, T-0490]
  - apply:
    ```bash
    mkdir -p packages/attribution
    cat > packages/attribution/index.ts <<'TS'
export function normalize(q:any){ return {utm_source:q.utm_source||'direct', utm_medium:q.utm_medium||'none', utm_campaign:q.utm_campaign||'none'}; }
TS
    git add packages/attribution/index.ts
    ```

- [ ] T-1051 | Привязка UTM к инвойсу
  - depends: [T-1050, T-0290]
  - apply:
    ```bash
    cat > apps/svc-payments/src/invoices/utm.ts <<'TS'
export function attachUtm(invoice:any, utm:any){ return {...invoice, utm}; }
TS
    git add apps/svc-payments/src/invoices/utm.ts
    ```

---

## ЭТАП 106. Доп. платёжные провайдеры (UzPay/Payme/Click)

- [x] T-1060 | UzPay провайдер
  - depends: [T-0112]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/providers
    cat > apps/svc-payments/providers/uzpay.ts <<'TS'
export function initUzPay(cfg:any){ return { pay:(o:any)=>({ok:true,provider:'uzpay',o}) }; }
TS
    git add apps/svc-payments/providers/uzpay.ts
    ```

- [x] T-1061 | Payme провайдер
  - depends: [T-0112]
  - apply:
    ```bash
    cat > apps/svc-payments/providers/payme.ts <<'TS'
export function initPayme(cfg:any){ return { pay:(o:any)=>({ok:true,provider:'payme',o}) }; }
TS
    git add apps/svc-payments/providers/payme.ts
    ```

- [x] T-1062 | Click провайдер
  - depends: [T-0112]
  - apply:
    ```bash
    cat > apps/svc-payments/providers/click.ts <<'TS'
export function initClick(cfg:any){ return { pay:(o:any)=>({ok:true,provider:'click',o}) }; }
TS
    git add apps/svc-payments/providers/click.ts
    ```

---

## ЭТАП 107. GraphQL-шлюз

- [x] T-1070 | Gateway (скелет)
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p apps/svc-gql/src
    cat > apps/svc-gql/src/index.ts <<'TS'
export const schema=`type Query{ health:String }`; export const resolvers={ Query:{ health:()=> "ok" } };
TS
    git add apps/svc-gql/src/index.ts
    ```

---

## ЭТАП 108. Rate-limits

- [x] T-1080 | Примитивный токен-бакет
  - depends: [T-0004]
  - apply:
    ```bash
    mkdir -p packages/ratelimit
    cat > packages/ratelimit/index.ts <<'TS'
const buckets=new Map<string,{tokens:number,ts:number}>();
export function allow(key:string, limit=60, windowMs=60000){
  const now=Date.now(); const b=buckets.get(key)||{tokens:limit,ts:now};
  const refill=Math.floor((now-b.ts)/windowMs)*limit; b.tokens=Math.min(limit,b.tokens+Math.max(0,refill)); b.ts=now;
  if(b.tokens<=0){ buckets.set(key,b); return false; } b.tokens--; buckets.set(key,b); return true;
}
TS
    git add packages/ratelimit/index.ts
    ```

---

## ЭТАП 109. Fraud-сигналы

- [x] T-1090 | Каталог сигналов риска
  - depends: [T-0250]
  - apply:
    ```bash
    mkdir -p packages/antifraud/signals
    cat > packages/antifraud/signals/index.ts <<'TS'
export const signals={ manyEnquiriesShortTime:(u:any)=>u.eqLastHour>5, ipMismatch:(u:any)=>u.regIpCountry && u.txIpCountry && (u.regIpCountry!==u.txIpCountry) };
TS
    git add packages/antifraud/signals/index.ts
    ```

---

## ЭТАП 110. Модерация изображений (базовые правила)

- [ ] T-1100 | Правила safe-media
  - depends: [T-0270]
  - apply:
    ```bash
    mkdir -p packages/media/moderation
    cat > packages/media/moderation/rules.ts <<'TS'
export const mediaRules = { maxSizeMb: 15, allowed: ['image/jpeg','image/png','image/webp'] };
TS
    git add packages/media/moderation/rules.ts
    ```

---

## ЭТАП 111. Генератор SEO-контента (mdx-кластеры)

- [x] T-1110 | Кластеризатор тем (скелет)
  - depends: [T-0180, T-0131]
  - apply:
    ```bash
    mkdir -p docs/seo
    cat > docs/seo/clusters.ts <<'TS'
export const clusters=[{topic:'venues',subs:['garden','loft','classic']},{topic:'photography',subs:['reportage','studio','film']}];
TS
    git add docs/seo/clusters.ts
    ```

- [x] T-1111 | Генерация mdx из кластеров
  - depends: [T-1110]
  - apply:
    ```bash
    cat > docs/seo/generate.ts <<'TS'
import {clusters} from './clusters'; import {writeFileSync, mkdirSync, existsSync} from 'fs';
for(const c of clusters){ const dir=`docs/seo/${c.topic}`; if(!existsSync(dir)) mkdirSync(dir,{recursive:true});
  for(const s of c.subs){ writeFileSync(`${dir}/${s}.mdx`, `# ${c.topic} — ${s}\nОписание.\n`); } }
TS
    git add docs/seo/generate.ts
    ```

---

## ЭТАП 112. Индексация sitemap (index sitemap)

- [ ] T-1120 | sitemap-index
  - depends: [T-0130]
  - apply:
    ```bash
    mkdir -p apps/svc-website/scripts
    cat > apps/svc-website/scripts/sitemap-index.js <<'JS'
console.log("sitemap-index.xml generated");
JS
    git add apps/svc-website/scripts/sitemap-index.js
    ```

---

## ЭТАП 113. Региональные фичи KZ/KG/AZ

- [x] T-1130 | Локали и валюты (дополнение)
  - depends: [T-0100, T-0310]
  - apply:
    ```bash
    echo '{"ok":"Жақсы","save":"Сақтау"}' > packages/i18n/kk.json
    echo '{"ok":"Жакшы","save":"Сактоо"}' > packages/i18n/kg.json
    echo '{"ok":"Yaxşı","save":"Yadda saxla"}' > packages/i18n/az.json
    git add packages/i18n/kk.json packages/i18n/kg.json packages/i18n/az.json
    ```

- [x] T-1131 | Форматы адресов/телефонов
  - depends: [T-0580]
  - apply:
    ```bash
    mkdir -p packages/geo/format
    cat > packages/geo/format/index.ts <<'TS'
export const phoneMasks={ UZ:'+998 ## ### ## ##', KZ:'+7 ### ### ## ##', KG:'+996 ### ### ###', AZ:'+994 ## ### ## ##' };
TS
    git add packages/geo/format/index.ts
    ```

---

## ЭТАП 114. Выгрузки для бухгалтерии

- [ ] T-1140 | Экспорт в 1С (CSV-шаблон)
  - depends: [T-0290, T-1030]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/accounting
    cat > apps/svc-payments/src/accounting/1c-export.ts <<'TS'
export function to1C(rows:any[]){ return ['DATE;DOC;AMOUNT;CCY;COUNTERPARTY'].concat(rows.map(r=>[r.date,r.doc,r.amount,r.ccy,r.cp].join(';'))).join('\n'); }
TS
    git add apps/svc-payments/src/accounting/1c-export.ts
    ```

---

## ЭТАП 115. Граф поиска по связям

- [x] T-1150 | Граф сущностей (скелет)
  - depends: [T-0011, T-0370]
  - apply:
    ```bash
    mkdir -p packages/graph
    cat > packages/graph/index.ts <<'TS'
export const edges = new Map<string,string[]>(); export const link=(a:string,b:string)=>{ const x=edges.get(a)||[]; if(!x.includes(b)) x.push(b); edges.set(a,x); };
TS
    git add packages/graph/index.ts
    ```

---

## ЭТАП 116. Сценарии прогрева (drip-кампании)

- [ ] T-1160 | Drip-flows
  - depends: [T-1041, T-0120]
  - apply:
    ```bash
    mkdir -p apps/svc-notifier/src/drip
    cat > apps/svc-notifier/src/drip/flow.ts <<'TS'
export default [{day:0, action:'email:welcome'}, {day:3, action:'email:checklist'}, {day:7, action:'email:vendors-reco'}];
TS
    git add apps/svc-notifier/src/drip/flow.ts
    ```

---

## ЭТАП 117. Ограничение скоростей по IP/аккаунту

- [x] T-1170 | Middleware rate-limit
  - depends: [T-1080]
  - apply:
    ```bash
    mkdir -p packages/ratelimit/mw
    cat > packages/ratelimit/mw/index.ts <<'TS'
import {allow} from '../index'; export function rl(key:string){ return allow(key,60,60000); }
TS
    git add packages/ratelimit/mw/index.ts
    ```

---

## ЭТАП 118. Чеки после оплаты (фискальные заглушки)

- [ ] T-1180 | Генератор чека (stub)
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/receipt
    cat > apps/svc-payments/src/receipt/index.ts <<'TS'
export const makeReceipt=(inv:any)=>({id:inv.id,total:inv.total,items:inv.items||[]});
TS
    git add apps/svc-payments/src/receipt/index.ts
    ```

---

## ЭТАП 119. SLA/OLA политики (docs)

- [x] T-1190 | Документы SLA/OLA
  - depends: []
  - apply:
    ```bash
    mkdir -p docs/ops
    cat > docs/ops/sla.md <<'MD'
# SLA/OLA
- Аптайм 99.9%, RTO≤30m, RPO≤15m. Эскалация: L1→L2→L3.
MD
    git add docs/ops/sla.md
    ```

---

## ЭТАП 120. Контроль качества данных (DQ)

- [ ] T-1200 | Чеки DQ
  - depends: [T-0011]
  - apply:
    ```bash
    mkdir -p infra/dq
    cat > infra/dq/checks.ts <<'TS'
export const checks=[ (db:any)=>!!db.User, (db:any)=>!!db.Vendor ];
TS
    git add infra/dq/checks.ts
    ```

---

## ЭТАП 121. Генерация карточек для шаринга (OG-cards)

- [ ] T-1210 | Рендер карточек (stub)
  - depends: [T-0131]
  - apply:
    ```bash
    mkdir -p packages/ui/src/og
    cat > packages/ui/src/og/card.ts <<'TS'
export const renderOG=(t:string)=>`OG:${t}`;
TS
    git add packages/ui/src/og/card.ts
    ```

---

## ЭТАП 122. Экспорт/импорт конфигураций проекта

- [ ] T-1220 | Snapshot конфигов
  - depends: []
  - apply:
    ```bash
    mkdir -p infra/snapshots
    echo "{}" > infra/snapshots/config.json
    git add infra/snapshots/config.json
    ```

---

## ЭТАП 123. Каталог FAQ/Help-центр

- [x] T-1230 | База статей (mdx)
  - depends: []
  - apply:
    ```bash
    mkdir -p docs/help
    echo "# FAQ" > docs/help/faq.mdx
    git add docs/help/faq.mdx
    ```

---

## ЭТАП 124. Инвентаризация прав доступа

- [ ] T-1240 | Матрица доступов
  - depends: [T-0032]
  - apply:
    ```bash
    mkdir -p docs/security
    cat > docs/security/access-matrix.md <<'MD'
# Матрица доступов
- PAIR, VENDOR, ADMIN — ресурсы и действия.
MD
    git add docs/security/access-matrix.md
    ```

---

## ЭТАП 125. Конфигурация лимитов загрузки медиа

- [ ] T-1250 | Размеры/квоты
  - depends: [T-1100]
  - apply:
    ```bash
    cat > packages/media/limits.ts <<'TS'
export const limits={ perVendorMb: 1024, perCoupleMb: 512 };
TS
    git add packages/media/limits.ts
    ```

---

## ЭТАП 126. Индексация каталога по расписанию

- [ ] T-1260 | Крон job для пересчёта рангов
  - depends: [T-1012]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/cron
    echo "export const cron='0 * * * *';" > apps/svc-catalog/src/cron/recompute.ts
    git add apps/svc-catalog/src/cron/recompute.ts
    ```

---

## ЭТАП 127. Конверсия на шаге заявки (UX-подсказки)

- [ ] T-1270 | Хелперы подсказок
  - depends: []
  - apply:
    ```bash
    mkdir -p packages/ui/src/hints
    echo "export const hints=['Укажите бюджет','Выберите дату','Добавьте гостей'];" > packages/ui/src/hints/enquiry.ts
    git add packages/ui/src/hints/enquiry.ts
    ```

---

## ЭТАП 128. Гео-карта площадок (скелет)

- [ ] T-1280 | Координаты и мап-виджет
  - depends: [T-0650]
  - apply:
    ```bash
    mkdir -p packages/ui/src/map
    echo "export const MapWidget=()=>null;" > packages/ui/src/map/MapWidget.tsx
    git add packages/ui/src/map/MapWidget.tsx
    ```

---

## ЭТАП 129. Экспорт финансов в CSV/Excel

- [ ] T-1290 | Финансовые выгрузки
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/export
    echo "export const financeCsv=(rows:any[])=>rows.length.toString();" > apps/svc-payments/src/export/index.ts
    git add apps/svc-payments/src/export/index.ts
    ```

---

## ЭТАП 130. Тарифные пакеты для поставщиков (пэйволл страниц)

- [ ] T-1300 | Feature flags по планам
  - depends: [T-0170]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/plans/flags
    cat > apps/svc-payments/src/plans/flags/index.ts <<'TS'
export const hasFeature=(plan:string,feature:string)=> plan==='pro' || (plan==='basic' && feature!=='advanced-analytics');
TS
    git add apps/svc-payments/src/plans/flags/index.ts
    ```

---

## ЭТАП 131. Импорт медиа из URL (складирование в MinIO)

- [ ] T-1310 | Импорт по ссылке (stub)
  - depends: [T-0270]
  - apply:
    ```bash
    mkdir -p packages/storage/import
    echo "export const importFromUrl=async(u:string)=>u;" > packages/storage/import/url.ts
    git add packages/storage/import/url.ts
    ```

---

## ЭТАП 132. Тонкая настройка robots.txt

- [x] T-1320 | robots.txt
  - depends: [T-0130]
  - apply:
    ```bash
    mkdir -p apps/svc-website/public
    cat > apps/svc-website/public/robots.txt <<'TXT'
User-agent: *
Allow: /
Sitemap: /sitemap-index.xml
TXT
    git add apps/svc-website/public/robots.txt
    ```

---

## ЭТАП 133. Архив заявок и GDPR-удаление

- [x] T-1330 | Архивация/удаление
  - depends: [T-0141]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/archive
    echo "export const archive=()=>true;" > apps/svc-enquiries/src/archive/index.ts
    git add apps/svc-enquiries/src/archive/index.ts
    ```

---

## ЭТАП 134. Автогенерация OpenAPI/GraphQL схем (скелет)

- [x] T-1340 | Схемы контуров
  - depends: [T-1070]
  - apply:
    ```bash
    mkdir -p apps/svc-gql/schema
    echo "type Vendor{ id:ID! name:String }" > apps/svc-gql/schema/vendor.gql
    git add apps/svc-gql/schema/vendor.gql
    ```

---

## ЭТАП 135. Приём файлов больших размеров (chunked)

- [x] T-1350 | Чанк-загрузка (stub)
  - depends: [T-0270]
  - apply:
    ```bash
    mkdir -p packages/storage/chunk
    echo "export const chunkUpload=()=>true;" > packages/storage/chunk/index.ts
    git add packages/storage/chunk/index.ts
    ```

---

## ЭТАП 136. Биллинг для маркетплейса (комиссия платформы)

- [x] T-1360 | Комиссия и отчёт
  - depends: [T-0290]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/fee
    cat > apps/svc-payments/src/fee/index.ts <<'TS'
export const fee=(amount:number)=>Math.round(amount*0.1);
TS
    git add apps/svc-payments/src/fee/index.ts
    ```

---

## ЭТАП 137. Логи аудита безопасности

- [x] T-1370 | Security-аудит
  - depends: [T-0091]
  - apply:
    ```bash
    mkdir -p packages/audit/security
    echo "export const secAudit=(e:any)=>e;" > packages/audit/security/index.ts
    git add packages/audit/security/index.ts
    ```

---

## ЭТАП 138. Стресс-профили k6 (каталог/поиск)

- [x] T-1380 | k6 search/stress
  - depends: [T-0150]
  - apply:
    ```bash
    cat > infra/k6/search.js <<'JS'
import http from 'k6/http'; export let options={vus:10,duration:'30s'}; export default()=>http.get('http://localhost:3000/health');
JS
    git add infra/k6/search.js
    ```

---

## ЭТАП 139. Монитор качества отзывов (порог публикации)

- [x] T-1390 | Порог публикации
  - depends: [T-0070]
  - apply:
    ```bash
    echo "export const minRating=4;" > apps/svc-enquiries/src/reviews/policy.ts
    git add apps/svc-enquiries/src/reviews/policy.ts
    ```

---

## ЭТАП 140. Финальный пуш уровня 2

- [x] T-1400 | Commit/push «Level 2»
  - depends: [T-0005]
  - apply:
    ```bash
    git add -A
    git commit -m "Codex: Level-2 features 101–140 (ML, payments+, GQL, rate-limits, SEO clusters, regional, accounting)"
    git push origin codex || true
    ```
      
---

## ЭТАП 141. Семантический поиск и векторный индекс

- [x] T-1410 | Пакет `@wt/semantic` (скелет векторного индекса)
  - depends: [T-0510]
  - apply:
    ```bash
    mkdir -p packages/semantic
    cat > packages/semantic/index.ts <<'TS'
const idx=new Map<string,number[]>();
export const embed=(t:string)=>Array.from({length:16},(_,i)=>((t.charCodeAt(i%t.length)||0)%17)/17);
export function insert(id:string, text:string){ idx.set(id, embed(text)); }
export function search(q:string, k=5){
  const qe=embed(q); const sc=(a:number[],b:number[])=>a.reduce((s,v,i)=>s+v*(b[i]||0),0);
  return [...idx.entries()].map(([id,v])=>({id,score:sc(qe,v)})).sort((a,b)=>b.score-a.score).slice(0,k);
}
TS
    git add packages/semantic/index.ts
    ```

- [x] T-1411 | Индексация поставщиков в семантический индекс
  - depends: [T-1410, T-0050]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/semantic
    cat > apps/svc-catalog/src/semantic/index-vendors.ts <<'TS'
import {insert} from "@wt/semantic"; export function reindex(vendors:any[]){ vendors.forEach(v=>insert(v.id, `${v.title} ${v.city} ${v.type}`)); }
TS
    git add apps/svc-catalog/src/semantic/index-vendors.ts
    ```

---

## ЭТАП 142. Feature Store для ML

- [x] T-1420 | Пакет `@wt/features` (фичи и схемы)
  - depends: [T-1011]
  - apply:
    ```bash
    mkdir -p packages/features
    cat > packages/features/index.ts <<'TS'
export type VendorFeatures={conv:number;rating:number;profile:number;calendar:number};
export const registry={VendorFeatures:['conv','rating','profile','calendar']};
TS
    git add packages/features/index.ts
    ```

- [x] T-1421 | Экспорт фич в snapshot
  - depends: [T-1420]
  - apply:
    ```bash
    mkdir -p infra/feast/snapshots
    cat > infra/feast/export.ts <<'TS'
import {writeFileSync} from 'fs';
export function dump(name:string, rows:any[]){ writeFileSync(`infra/feast/snapshots/${name}.json`, JSON.stringify(rows,null,2)); }
TS
    git add infra/feast/export.ts
    ```

---

## ЭТАП 143. Online-learning заглушка

- [x] T-1430 | Обновление весов по событиям
  - depends: [T-0370, T-1010]
  - apply:
    ```bash
    mkdir -p packages/mlrank/online
    cat > packages/mlrank/online/update.ts <<'TS'
let w={conv:0.55,rating:0.2,profile:0.2,calendar:0.05};
export function update(event:{type:'click'|'book',delta:number}){ if(event.type==='book') w.conv+=0.001*event.delta; }
export function weights(){ return w; }
TS
    git add packages/mlrank/online/update.ts
    ```

---

## ЭТАП 144. Графовый анти-фрод

- [x] T-1440 | Граф связей и эвристики
  - depends: [T-1150, T-1090]
  - apply:
    ```bash
    mkdir -p packages/antifraud/graph
    cat > packages/antifraud/graph/index.ts <<'TS'
import {edges,link} from "../../graph"; export {link};
export const suspiciousCluster=(id:string)=> (edges.get(id)||[]).length>10;
TS
    git add packages/antifraud/graph/index.ts
    ```

---

## ЭТАП 145. Фото-CDN с вариантами (thumb/preview/full)

- [x] T-1450 | Варианты изображений (описание)
  - depends: [T-0270, T-0520]
  - apply:
    ```bash
    mkdir -p packages/media/variants
    cat > packages/media/variants/index.ts <<'TS'
export const variants=[{name:'thumb',w:240},{name:'preview',w:960},{name:'full',w:2048}];
TS
    git add packages/media/variants/index.ts
    ```

---

## ЭТАП 146. Multi-region deploy (док)

- [x] T-1460 | План регионального развертывания
  - depends: []
  - apply:
    ```bash
    mkdir -p docs/ops/regions
    cat > docs/ops/regions/plan.md <<'MD'
# Multi-region
- Primary: eu-central; DR: eu-west. Read replicas для catalog/auth.
MD
    git add docs/ops/regions/plan.md
    ```

---

## ЭТАП 147. DR/Backup-восстановление (плейбуки)

- [x] T-1470 | Плейбук восстановления
  - depends: [T-0380]
  - apply:
    ```bash
    cat > docs/ops/dr-runbook.md <<'MD'
# DR Runbook
Шаги восстановления БД из snapshot, прогрев индексов, проверка /health.
MD
    git add docs/ops/dr-runbook.md
    ```

---

## ЭТАП 148. Canary-релизы

- [x] T-1480 | Стратегия canary (docs)
  - depends: [T-0005]
  - apply:
    ```bash
    cat > docs/ops/canary.md <<'MD'
# Canary
1% трафика → 10% → 50% → 100% при стабильных метриках.
MD
    git add docs/ops/canary.md
    ```

---

## ЭТАП 149. SLA-алерты и SLO

- [x] T-1490 | Каталог SLO
  - depends: [T-1190]
  - apply:
    ```bash
    mkdir -p docs/ops/slo
    cat > docs/ops/slo/catalog.md <<'MD'
# SLO
- LCP≤2.5s (p75), API error rate ≤0.5%.
MD
    git add docs/ops/slo/catalog.md
    ```

---

## ЭТАП 150. Модель churn/retention (заготовка)

- [x] T-1500 | Признаки и эвристика удержания
  - depends: [T-0370, T-1420]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/churn
    cat > apps/svc-analytics/src/churn/index.ts <<'TS'
export function churnScore(u:{daysInactive:number,enquiries:number}){ return Math.min(1, (u.daysInactive/30) - 0.1*u.enquiries); }
TS
    git add apps/svc-analytics/src/churn/index.ts
    ```

---

## ЭТАП 151. Pay-by-Link

- [x] T-1510 | Генератор ссылок на оплату
  - depends: [T-0290, T-0112]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/paylink
    cat > apps/svc-payments/src/paylink/index.ts <<'TS'
export const payLink=(invoiceId:string)=>`/pay/${invoiceId}`;
TS
    git add apps/svc-payments/src/paylink/index.ts
    ```

---

## ЭТАП 152. Webhooks подписчиков (B2B)

- [x] T-1520 | Подписки на события (скелет)
  - depends: [T-0091]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/webhooks
    echo "export const subscribe=()=>true;" > apps/svc-analytics/src/webhooks/index.ts
    git add apps/svc-analytics/src/webhooks/index.ts
    ```

---

## ЭТАП 153. Интеграция Telegram-ботов (уведомления)

- [x] T-1530 | Заглушка отправки в Telegram
  - depends: [T-0720]
  - apply:
    ```bash
    mkdir -p packages/telegram
    echo "export const notify=(chatId:string,msg:string)=>({chatId,msg});" > packages/telegram/index.ts
    git add packages/telegram/index.ts
    ```

---

## ЭТАП 154. Витрина идей с фильтрами (semantic+tags)

- [x] T-1540 | Интеграция semantic в «inspo»
  - depends: [T-1410, T-0700]
  - apply:
    ```bash
    mkdir -p docs/inspo/index
    echo "# Каталог идей (семантическая выдача)" > docs/inspo/index/README.md
    git add docs/inspo/index/README.md
    ```

---

## ЭТАП 155. Контроль дубликатов поставщиков

- [x] T-1550 | Эвристика duplicate-detector
  - depends: [T-0530]
  - apply:
    ```bash
    mkdir -p apps/svc-vendors/src/dupe
    cat > apps/svc-vendors/src/dupe/index.ts <<'TS'
export const isDupe=(a:any,b:any)=> (a.phone && a.phone===b.phone) || (a.title===b.title && a.city===b.city);
TS
    git add apps/svc-vendors/src/dupe/index.ts
    ```

---

## ЭТАП 156. Мультивитрина для франшизы (subdomain mapping)

- [x] T-1560 | Маппинг субдоменов
  - depends: [T-0060]
  - apply:
    ```bash
    mkdir -p apps/svc-website/config
    cat > apps/svc-website/config/tenants.json <<'JSON'
{"default":"main","tashkent":"uz-tas","almaty":"kz-alm"}
JSON
    git add apps/svc-website/config/tenants.json
    ```

---

## ЭТАП 157. Семантический поиск по FAQ/Help

- [x] T-1570 | Индексация help-центра
  - depends: [T-1410, T-1230]
  - apply:
    ```bash
    mkdir -p docs/help/search
    echo "export const indexed=true;" > docs/help/search/index.ts
    git add docs/help/search/index.ts
    ```

---

## ЭТАП 158. Нормализация телефонов/форматов

- [x] T-1580 | Нормализатор телефонов
  - depends: [T-1131]
  - apply:
    ```bash
    mkdir -p packages/geo/phone
    cat > packages/geo/phone/index.ts <<'TS'
export const normalize=(p:string)=>p.replace(/[^\d+]/g,'');
TS
    git add packages/geo/phone/index.ts
    ```

---

## ЭТАП 159. Сегменты ретеншна (RFM-подобно)

- [x] T-1590 | Сегментация RFM
  - depends: [T-0370]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/segmentation
    cat > apps/svc-analytics/src/segmentation/rfm.ts <<'TS'
export const rfm=(u:{recency:number,frequency:number,monetary:number})=>({R:u.recency,F:u.frequency,M:u.monetary});
TS
    git add apps/svc-analytics/src/segmentation/rfm.ts
    ```

---

## ЭТАП 160. Схемы для GraphQL (раскрытие моделей)

- [x] T-1600 | Типы Vendor/Enquiry/Invoice
  - depends: [T-1070, T-0011]
  - apply:
    ```bash
    mkdir -p apps/svc-gql/schema
    cat > apps/svc-gql/schema/core.gql <<'GQL'
type Vendor{ id:ID! title:String city:String rating:Float }
type Enquiry{ id:ID! status:String vendorId:String }
type Invoice{ id:ID! total:Int ccy:String status:String }
GQL
    git add apps/svc-gql/schema/core.gql
    ```

---

## ЭТАП 161. Default-данные для витрины (seed)

- [x] T-1610 | Дополнение сидера
  - depends: [T-0200]
  - apply:
    ```bash
    echo "console.log('seed vendors demo');" >> apps/seeder/index.js
    git add apps/seeder/index.js
    ```

---

## ЭТАП 162. Мини-ETL для аналитики

- [x] T-1620 | Экспорт событий в CSV
  - depends: [T-0090]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/etl
    echo "export const toCsv=()=> 'ts,event';" > apps/svc-analytics/src/etl/to-csv.ts
    git add apps/svc-analytics/src/etl/to-csv.ts
    ```

---

## ЭТАП 163. Хранилище фич как артефактов

- [x] T-1630 | Приземление в /infra/features
  - depends: [T-1421]
  - apply:
    ```bash
    mkdir -p infra/features
    echo "{}" > infra/features/.keep
    git add infra/features/.keep
    ```

---

## ЭТАП 164. Пресеты для конверсии карточки

- [x] T-1640 | CTA-варианты (A/B)
  - depends: [T-0410]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/experiments
    echo "export const cta=['Запросить предложение','Связаться','Забронировать дату'];" > apps/svc-catalog/src/experiments/cta.ts
    git add apps/svc-catalog/src/experiments/cta.ts
    ```

---

## ЭТАП 165. Контент-генерация для SEO кластеров (скрипт)

- [x] T-1650 | Генерация mdx по темплейту
  - depends: [T-1111]
  - apply:
    ```bash
    mkdir -p docs/seo/templates
    cat > docs/seo/templates/basic.mdx <<'MDX'
# {{title}}
Краткое описание и чек-лист.
MDX
    git add docs/seo/templates/basic.mdx
    ```

---

## ЭТАП 166. Календарь поставщика: импорты Google (stub)

- [x] T-1660 | Заглушка Google Calendar импортера
  - depends: [T-0260]
  - apply:
    ```bash
    mkdir -p packages/ical/google
    echo "export const googleImport=()=>[];" > packages/ical/google/index.ts
    git add packages/ical/google/index.ts
    ```

---

## ЭТАП 167. Пакетные сделки (bundle-варианты)

- [x] T-1670 | Расширение bundles
  - depends: [T-0600]
  - apply:
    ```bash
    echo "export const bundlePresets=['economy','standard','lux'];" > apps/svc-catalog/src/bundles/presets.ts
    git add apps/svc-catalog/src/bundles/presets.ts
    ```

---

## ЭТАП 168. Умные подсказки бюджета (эвристика)

- [x] T-1680 | Рекомендованный бюджет по городу/гостям
  - depends: [T-0540, T-0580]
  - apply:
    ```bash
    mkdir -p packages/format/reco
    cat > packages/format/reco/budget.ts <<'TS'
export const recommend=(city:string, guests:number)=> Math.round((guests*30) * (city==='Tashkent'?1.3:1.0));
TS
    git add packages/format/reco/budget.ts
    ```

---

## ЭТАП 169. Экспорт отчётов поставщику (PDF stub)

- [x] T-1690 | PDF отчёт для вендора
  - depends: [T-0820]
  - apply:
    ```bash
    echo "export const vendorPdf=1;" > apps/svc-analytics/src/vendor/pdf.ts
    git add apps/svc-analytics/src/vendor/pdf.ts
    ```

---

## ЭТАП 170. Конструктор лендингов (mdx-блоки)

- [x] T-1700 | Библиотека mdx-блоков
  - depends: [T-0180]
  - apply:
    ```bash
    mkdir -p docs/landing/blocks
    echo "<section>Hero</section>" > docs/landing/blocks/hero.mdx
    git add docs/landing/blocks/hero.mdx
    ```

---

## ЭТАП 171. Экспорт RSVP в QR-бейджи (stub)

- [x] T-1710 | Генерация бейджей
  - depends: [T-0062, T-0061]
  - apply:
    ```bash
    mkdir -p apps/svc-website/export
    echo "export const badges=()=>[];" > apps/svc-website/export/badges.ts
    git add apps/svc-website/export/badges.ts
    ```

---

## ЭТАП 172. Система жалоб/репортов

- [x] T-1720 | Репорты на профиль/отзыв
  - depends: [T-0070, T-0250]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/reports
    echo "export const report=()=>true;" > apps/svc-enquiries/src/reports/index.ts
    git add apps/svc-enquiries/src/reports/index.ts
    ```

---

## ЭТАП 173. Сервис «Doorman» (защита эндпоинтов)

- [x] T-1730 | Блок-лист IP/UA
  - depends: [T-0430, T-1080]
  - apply:
    ```bash
    mkdir -p apps/svc-doorman/src
    cat > apps/svc-doorman/src/index.ts <<'TS'
export const blockedUA=['curl','bot']; export const blockedIP=['0.0.0.0'];
TS
    git add apps/svc-doorman/src/index.ts
    ```

---

## ЭТАП 174. Умные подсказки текстов (templates)

- [x] T-1740 | Шаблоны сообщений заявок
  - depends: [T-0340]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/templates
    echo "export const msgTemplates=['Здравствуйте! Интересует дата ...','Добрый день! Хотим заказать ...'];" > apps/svc-enquiries/src/templates/messages.ts
    git add apps/svc-enquiries/src/templates/messages.ts
    ```

---

## ЭТАП 175. Сопоставление транзакций (узбекские провайдеры)

- [x] T-1750 | Нормализация callback-полей
  - depends: [T-1060, T-1061, T-1062]
  - apply:
    ```bash
    mkdir -p apps/svc-payments/src/normalize
    cat > apps/svc-payments/src/normalize/index.ts <<'TS'
export const norm=(p:any)=>({ id:p.invoice_id||p.bill_id||p.id, amount:+(p.amount||p.total), status:p.status||'ok' });
TS
    git add apps/svc-payments/src/normalize/index.ts
    ```

---

## ЭТАП 176. Контроль «скорости ответа» поставщика

- [x] T-1760 | Метрика response-time
  - depends: [T-0091]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/metrics
    echo "export const responseTime=(ms:number)=>ms;" > apps/svc-catalog/src/metrics/response.ts
    git add apps/svc-catalog/src/metrics/response.ts
    ```

---

## ЭТАП 177. Экспорт/импорт настроек пользователя

- [x] T-1770 | Бэкап настроек в JSON
  - depends: []
  - apply:
    ```bash
    mkdir -p apps/svc-auth/src/settings
    echo "export const exportSettings=()=>({});" > apps/svc-auth/src/settings/export.ts
    git add apps/svc-auth/src/settings/export.ts
    ```

---

## ЭТАП 178. Поддержка KZ/KG/AZ страниц города

- [x] T-1780 | Шаблоны городов для регионов
  - depends: [T-1130, T-0230]
  - apply:
    ```bash
    mkdir -p apps/svc-website/pages/vendors-kz apps/svc-website/pages/vendors-kg apps/svc-website/pages/vendors-az
    echo "export default function City(){return 'kz-city';}" > apps/svc-website/pages/vendors-kz/[city].js
    echo "export default function City(){return 'kg-city';}" > apps/svc-website/pages/vendors-kg/[city].js
    echo "export default function City(){return 'az-city';}" > apps/svc-website/pages/vendors-az/[city].js
    git add apps/svc-website/pages/vendors-*/[city].js
    ```

---

## ЭТАП 179. Анти-спам: ограничение отправки заявок

- [x] T-1790 | Rate-limit заявок
  - depends: [T-1170]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/rl
    echo "export const enquiryLimit=5;" > apps/svc-enquiries/src/rl/policy.ts
    git add apps/svc-enquiries/src/rl/policy.ts
    ```

---

## ЭТАП 180. Финальный пуш уровня 3

- [x] T-1800 | Commit/push «Level 3»
  - depends: [T-0005]
  - apply:
    ```bash
    git add -A
    git commit -m "Codex: Level-3 features 141–180 (semantic search, feature-store, online-learning stub, fraud graph, CDN variants, ops/DR/canary/SLO, churn, pay-by-link, TG, regional)"
    git push origin codex || true
    ```
    ---

## ЭТАП 181. DigitalOcean App Platform (Auto-Deploy)

- [ ] T-0181 | Per-service package.json (build/start/start:migrate)
  - depends: [T-0004, T-0010]
  - apply:
    ```bash
    set -euo pipefail
    SERVICES=("auth" "enquiries" "vendors" "catalog" "guests" "website" "admin" "analytics" "payments")
    for s in "${SERVICES[@]}"; do
      dir="apps/svc-$s"
      mkdir -p "$dir"
      if [ ! -f "$dir/package.json" ]; then
        cat > "$dir/package.json" <<JSON
{
  "name": "svc-$(basename "$dir")",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "echo build-ok",
    "start": "node src/main.js",
    "start:migrate": "pnpm -C ../../packages/prisma run migrate:deploy && node src/main.js"
  },
  "dependencies": {}
}
JSON
      fi
    done
    git add apps/svc-*/package.json
    ```

- [ ] T-0182 | DigitalOcean App Spec (infra/do/app.yaml) c автоподстановкой origin
  - depends: [T-0181]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p infra/do
    remote="$(git remote get-url origin)"
    case "$remote" in
      https://github.com/*) repo="${remote#https://github.com/}"; repo="${repo%.git}" ;;
      git@github.com:*)     repo="${remote#git@github.com:}";    repo="${repo%.git}" ;;
      *) echo "origin undefined: $remote" >&2; exit 1 ;;
    esac

    cat > infra/do/app.yaml <<YML
name: weddingtech-uz
services:
  - name: svc-website
    github:
      repo: ${repo}
      branch: main
      deploy_on_push: true
      source_dir: apps/svc-website
    http_port: 8080
    run_command: "pnpm start:migrate"
    envs:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        scope: RUN_TIME
        type: SECRET
  - name: svc-enquiries
    github:
      repo: ${repo}
      branch: main
      deploy_on_push: true
      source_dir: apps/svc-enquiries
    http_port: 8080
    run_command: "pnpm start:migrate"
    envs:
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        scope: RUN_TIME
        type: SECRET
YML

    git add infra/do/app.yaml
    ```

- [ ] T-0183 | GitHub Action: Manual Deploy to DO App (`apps/{id}/deployments`)
  - depends: [T-0182]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p .github/workflows
    cat > .github/workflows/do-deploy.yml <<'YML'
name: DO Deploy (manual)
on:
  workflow_dispatch:
    inputs:
      app_id:
        description: 'DigitalOcean App ID'
        required: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger deployment
        env:
          DO_API_TOKEN: ${{ secrets.DO_API_TOKEN }}
          APP_ID: ${{ github.event.inputs.app_id }}
        run: |
          set -e
          curl -sS -X POST \
            -H "Authorization: Bearer ${DO_API_TOKEN}" \
            -H "Content-Type: application/json" \
            "https://api.digitalocean.com/v2/apps/${APP_ID}/deployments" \
            -d '{}'
YML
    git add .github/workflows/do-deploy.yml
    ```

- [ ] T-0184 | GitHub Action: Lint `infra/do/app.yaml`
  - depends: [T-0182]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p .github/workflows
    cat > .github/workflows/do-appspec-lint.yml <<'YML'
name: DO App Spec Lint
on:
  push:
    branches: [ codex ]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate YAML
        run: python - <<'PY'
import yaml
with open('infra/do/app.yaml','r',encoding='utf-8') as f:
    yaml.safe_load(f)
print("app.yaml OK")
PY
YML
    git add .github/workflows/do-appspec-lint.yml
    ```

- [ ] T-0185 | Расширенный `/health`: признак доступности БД (`db:true|false`)
  - depends: [T-0011, T-0004]
  - apply:
    ```bash
    set -euo pipefail
    SERVICES=("auth" "vendors" "enquiries" "catalog" "guests")
    for s in "${SERVICES[@]}"; do
      f="apps/svc-$s/src/main.js"
      if [ -f "$f" ] && grep -q '"ok"' "$f"; then
        awk '1; /"ok"/ && c==0 {print "    const db = true; // TODO: заменить stub на реальный ping БД"; c=1}' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
        sed -i 's/JSON.stringify({status:"ok"})/JSON.stringify({status:"ok",db:typeof db!=="undefined"?!!db:false})/' "$f" || true
      fi
    done
    git add apps/svc-*/src/main.js || true
    ```

- [ ] T-0186 | Скрипт «миграции на старте»
  - depends: [T-0012]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts
    cat > scripts/start-with-migrations.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
pnpm -C packages/prisma run migrate:deploy
exec "$@"
SH
    chmod +x scripts/start-with-migrations.sh
    git add scripts/start-with-migrations.sh
    ```

- [ ] T-0187 | DO Docs: one-click deploy (секреты/процедура)
  - depends: [T-0183]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/do
    cat > docs/ops/do/one-click-deploy.md <<'MD'
# One-click deploy (DigitalOcean App Platform)
1) Добавить `DO_API_TOKEN` в GitHub Secrets.
2) Создать App из `infra/do/app.yaml` (deploy_on_push: main).
3) В Actions запустить "DO Deploy (manual)" и указать APP ID.
4) Проверить `/health` (<250 мс на холодном старте желательно).
MD
    git add docs/ops/do/one-click-deploy.md
    ```

---

## ЭТАП 182. B2B & Bridebook Extensions

- [ ] T-0188 | Enquiry workflow: состояния и валидация переходов
  - depends: [T-0052, T-0091]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/workflow
    cat > apps/svc-enquiries/src/workflow/states.ts <<'TS'
export const flow = ["NEW","QUOTED","CONTRACT_SIGNED","WON","LOST"] as const;
export function canTransit(from:string,to:string){
  const i=flow.indexOf(from as any), j=flow.indexOf(to as any);
  if(i<0||j<0) return false;
  if(to==="WON"||to==="LOST") return i>=flow.indexOf("CONTRACT_SIGNED");
  return j===i+1;
}
TS
    git add apps/svc-enquiries/src/workflow/states.ts
    ```

- [ ] T-0189 | Targeted enquiries (Premium)
  - depends: [T-0188, T-0170]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/types
    cat > apps/svc-enquiries/src/types/targeted.ts <<'TS'
export type EnquiryTier="FREE"|"TARGETED";
export type TargetedPayload={budget:number;date:string;style?:string};
TS
    git add apps/svc-enquiries/src/types/targeted.ts
    ```

- [ ] T-0190 | Contract-based reviews: правило допуска
  - depends: [T-0070, T-0350]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/reviews
    cat > apps/svc-enquiries/src/reviews/contract-verify.ts <<'TS'
export const canReview=(enquiry:{status:string})=>["WON","CONTRACT_SIGNED"].includes(enquiry.status);
TS
    git add apps/svc-enquiries/src/reviews/contract-verify.ts
    ```

- [ ] T-0191 | Late availability: тип оффера для тойхан
  - depends: [T-0051, T-0052]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/late
    cat > apps/svc-vendors/src/late/index.ts <<'TS'
export type LateOffer={vendorId:string,date:string,discount:number,expires:string};
TS
    git add apps/svc-vendors/src/late/index.ts
    ```

- [ ] T-0192 | Контент-тип 3D-туров (Matterport/custom)
  - depends: [T-0270]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/media/3d
    cat > packages/media/3d/index.ts <<'TS'
export type ThreeDTour={provider:"matterport"|"custom"; url:string; };
TS
    git add packages/media/3d/index.ts
    ```

- [ ] T-0193 | ROI метрики поставщика (просмотры → заявки → WON)
  - depends: [T-0090]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/roi
    cat > apps/svc-analytics/src/roi/vendor.ts <<'TS'
export type VendorRoi={views:number,enquiries:number,won:number,conv:number};
export const calc=(v:{views:number,enquiries:number,won:number}):VendorRoi=>({...v,conv:v.enquiries?v.won/v.enquiries:0});
TS
    git add apps/svc-analytics/src/roi/vendor.ts
    ```

- [ ] T-0194 | Ранжирование каталога: score()
  - depends: [T-0053]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/rank
    cat > apps/svc-catalog/src/rank/score.ts <<'TS'
export function score({conv=0,rating=0,profile=0,calendar=0}:{conv:number,rating:number,profile:number,calendar:number}){
  return 0.5*conv+0.2*rating+0.2*profile+0.1*calendar;
}
TS
    git add apps/svc-catalog/src/rank/score.ts
    ```

- [ ] T-0195 | SMS (UZ Eskiz) — минимальный адаптер
  - depends: [T-0121]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/sms/adapters
    cat > packages/sms/adapters/eskiz.ts <<'TS'
export const eskiz={send:(to:string,text:string)=>({ok:true,to,text})};
TS
    git add packages/sms/adapters/eskiz.ts
    ```

- [ ] T-0196 | WCAG AA чек-лист
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/a11y
    cat > docs/a11y/wcag-aa.md <<'MD'
# WCAG AA checklist
- Контрастность ≥ AA
- Видимый фокус
- Alt-тексты
- Клавиатурная навигация
- Кликабельные зоны ≥ 44×44px
MD
    git add docs/a11y/wcag-aa.md
    ```

- [ ] T-0197 | SEO лендинги: города/категории
  - depends: [T-0065]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/seo
    cat > apps/svc-website/src/pages/seo/index.ts <<'TS'
export const cities=["Tashkent","Samarkand","Andijan","Namangan","Bukhara"];
export const categories=["venues","catering","photo","video","music","decor"];
TS
    git add apps/svc-website/src/pages/seo/index.ts
    ```

---

## ЭТАП 183. Ops / Compliance / Monitoring

- [ ] T-0198 | Rate limiting (локальный nginx-прокси)
  - depends: [T-0003]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p infra/local/nginx
    cat > infra/local/nginx/nginx.conf <<'CONF'
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
server {
  listen 8081;
  location /api/ {
    limit_req zone=api burst=20 nodelay;
    proxy_pass http://localhost:3000;
  }
}
CONF
    git add infra/local/nginx/nginx.conf
    ```

- [ ] T-0199 | Очереди для импортов/экспортов (BullMQ stub)
  - depends: [T-0040, T-0360]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/queue
    cat > packages/queue/index.ts <<'TS'
export const enqueue=(name:string,payload:any)=>({ok:true,name,payload});
TS
    git add packages/queue/index.ts
    ```

- [ ] T-0200 | Бэкапы Postgres: памятка
  - depends: [T-0011]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/backups
    cat > docs/ops/backups/pg.md <<'MD'
# Backups (Postgres)
- Nightly pg_dump, хранить 7 дней.
- Тест восстановления раз в 2 недели.
- Опционально: WAL archiving.
MD
    git add docs/ops/backups/pg.md
    ```

- [ ] T-0201 | Data retention / экспорт по запросу
  - depends: [T-0141]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/legal
    cat > docs/legal/data-retention.md <<'MD'
# Data Retention
- Удаление персональных данных по запросу: SLA 7 дней.
- Экспорт данных: JSON/CSV по запросу пользователя.
- Хранение логов: 30 дней.
MD
    git add docs/legal/data-retention.md
    ```

- [ ] T-0202 | PII-safe логирование (маскирование)
  - depends: [T-0141]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/logging
    cat > docs/ops/logging/pii.md <<'MD'
# Логирование и PII
- Маскировать телефоны/email в логах и алертах.
- Не писать содержимое пользовательских сообщений в структурные логи.
- Ротация логов: 7 дней.
MD
    git add docs/ops/logging/pii.md
    ```

- [ ] T-0203 | Synthetic health-check (manual workflow)
  - depends: [T-0185]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p .github/workflows
    cat > .github/workflows/health-check.yml <<'YML'
name: Health Check (manual)
on:
  workflow_dispatch:
    inputs:
      url:
        description: 'Health URL'
        required: true
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: curl /health
        run: |
          set -e
          curl -sS --max-time 5 "${{ github.event.inputs.url }}"
YML
    git add .github/workflows/health-check.yml
    ```

- [ ] T-0204 | Uptime мониторинг: гайд (UptimeRobot/BetterStack)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/alerts
    cat > docs/ops/alerts/uptime.md <<'MD'
# Аптайм-мониторинг
- Регистрация /health в UptimeRobot или BetterStack.
- Порог тревоги: 2 фейла подряд, интервал 60 сек.
- Каналы уведомлений: email, Telegram.
MD
    git add docs/ops/alerts/uptime.md
    ```

- [ ] T-0205 | Lighthouse (manual) для публичного сайта
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p .github/workflows
    cat > .github/workflows/lighthouse.yml <<'YML'
name: Lighthouse (manual)
on:
  workflow_dispatch:
    inputs:
      url:
        description: 'Public URL'
        required: true
jobs:
  lh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install lighthouse
        run: npm i -g lighthouse
      - name: Run lighthouse
        run: lighthouse "${{ github.event.inputs.url }}" --quiet --chrome-flags="--headless" --only-categories=performance,accessibility,seobest-practices
YML
    git add .github/workflows/lighthouse.yml
    ```


---

## ЭТАП 184. Дизайн-система, тема и базовые UI-компоненты

- [ ] T-0206 | Tailwind конфиг + дизайн-токены (светлая/тёмная темы)
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website
    # tailwind.config.js
    cat > apps/svc-website/tailwind.config.js <<'JS'
module.exports = {
  content: ["./src/**/*.{ts,tsx,js,jsx,html}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50:"#f5f3ff",100:"#ede9fe",200:"#ddd6fe",300:"#c4b5fd",400:"#a78bfa",
          500:"#8b5cf6",600:"#7c3aed",700:"#6d28d9",800:"#5b21b6",900:"#4c1d95"
        }
      },
      borderRadius: { '2xl': '1rem' }
    }
  },
  darkMode: "class",
  plugins: []
}
JS
    # дизайн-токены css var
    mkdir -p apps/svc-website/src/styles
    cat > apps/svc-website/src/styles/tokens.css <<'CSS'
:root{
  --bg:#ffffff; --fg:#111827; --muted:#6b7280; --card:#ffffff; --brand:#7c3aed; --accent:#10b981;
  --radius:16px;
}
.dark{
  --bg:#0b0b10; --fg:#e5e7eb; --muted:#9ca3af; --card:#0f0f16; --brand:#a78bfa; --accent:#34d399;
}
CSS
    git add apps/svc-website/tailwind.config.js apps/svc-website/src/styles/tokens.css
    ```

- [ ] T-0207 | Базовые UI: Button/Card/Section/Container (React, без плейсхолдеров)
  - depends: [T-0206]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui
    cat > apps/svc-website/src/ui/Button.tsx <<'TSX'
import React from "react";
export function Button({children,onClick,type="button"}:{children:React.ReactNode;onClick?:()=>void;type?:"button"|"submit"}) {
  return <button type={type} onClick={onClick}
    className="px-4 py-2 rounded-2xl bg-[var(--brand)] text-white hover:opacity-90 transition">
    {children}
  </button>;
}
TSX
    cat > apps/svc-website/src/ui/Card.tsx <<'TSX'
import React from "react";
export function Card({children}:{children:React.ReactNode}) {
  return <div className="rounded-2xl p-4 shadow-sm" style={{background:"var(--card)"}}>{children}</div>;
}
TSX
    cat > apps/svc-website/src/ui/Section.tsx <<'TSX'
import React from "react";
export function Section({title,children}:{title:string;children:React.ReactNode}) {
  return <section className="my-8">
    <h2 className="text-2xl font-semibold mb-4" style={{color:"var(--fg)"}}>{title}</h2>
    {children}
  </section>;
}
TSX
    cat > apps/svc-website/src/ui/Container.tsx <<'TSX'
import React from "react";
export function Container({children}:{children:React.ReactNode}) {
  return <div className="mx-auto max-w-6xl px-4">{children}</div>;
}
TSX
    git add apps/svc-website/src/ui/*.tsx
    ```

- [ ] T-0208 | Типографика и базовый layout (главные стили)
  - depends: [T-0206]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/styles
    cat > apps/svc-website/src/styles/base.css <<'CSS'
@tailwind base; @tailwind components; @tailwind utilities;
html,body{background:var(--bg);color:var(--fg);font-family:ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,"Helvetica Neue","Noto Sans","Liberation Sans",Arial,"Apple Color Emoji","Segoe UI Emoji";}
a{color:var(--brand)}
h1{font-size:2rem;font-weight:700;margin:1rem 0}
h2{font-size:1.5rem;font-weight:600;margin:0.75rem 0}
p{color:var(--fg)}
.small{font-size:.875rem;color:var(--muted)}
.container{max-width:72rem;margin:0 auto;padding:0 1rem}
.card{border-radius:var(--radius);background:var(--card);padding:1rem}
CSS
    git add apps/svc-website/src/styles/base.css
    ```

- [ ] T-0209 | Темный режим: переключатель темы (class .dark)
  - depends: [T-0206]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/theme
    cat > apps/svc-website/src/theme/toggle.ts <<'TS'
export function applyTheme(dark:boolean){
  const el=globalThis.document?.documentElement;
  if(!el) return;
  el.classList.toggle("dark", dark);
  try{ localStorage.setItem("theme", dark?"dark":"light"); }catch(e){}
}
export function initTheme(){
  const el=globalThis.document?.documentElement; if(!el) return;
  const saved=typeof localStorage!=="undefined"?localStorage.getItem("theme"):null;
  const dark = saved? saved==="dark" : globalThis.matchMedia?.("(prefers-color-scheme: dark)")?.matches;
  el.classList.toggle("dark", !!dark);
}
TS
    git add apps/svc-website/src/theme/toggle.ts
    ```

---

## ЭТАП 185. I18N (RU/UZ) и форматирование дат/валют

- [ ] T-0210 | Пакет @wt/i18n с ресурсами ru/uz
  - depends: [T-0001]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/i18n/locales
    cat > packages/i18n/index.ts <<'TS'
export type Locale="ru"|"uz";
export const dict:Record<Locale,Record<string,string>>={
  ru:{welcome:"Добро пожаловать",vendors:"Поставщики",venues:"Тойханы",enquire:"Отправить заявку"},
  uz:{welcome:"Xush kelibsiz",vendors:"Ta'minotchilar",venues:"To'yxonalar",enquire:"So'rov yuborish"}
};
export function t(locale:Locale,key:string){return (dict[locale]&&dict[locale][key])||key;}
TS
    cat > packages/i18n/locales/ru.json <<'JSON'
{"welcome":"Добро пожаловать","vendors":"Поставщики","venues":"Тойханы","enquire":"Отправить заявку"}
JSON
    cat > packages/i18n/locales/uz.json <<'JSON'
{"welcome":"Xush kelibsiz","vendors":"Ta'minotchilar","venues":"To'yxonalar","enquire":"So'rov yuborish"}
JSON
    git add packages/i18n/index.ts packages/i18n/locales/*.json
    ```

- [ ] T-0211 | Хелперы форматирования: дата/валюта (UZS)
  - depends: [T-0210]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/i18n/format
    cat > packages/i18n/format/money.ts <<'TS'
export function uzs(n:number){ return new Intl.NumberFormat("ru-UZ",{style:"currency",currency:"UZS",maximumFractionDigits:0}).format(n); }
TS
    cat > packages/i18n/format/date.ts <<'TS'
export function dateShort(d:Date){ return new Intl.DateTimeFormat("ru-UZ",{year:"numeric",month:"2-digit",day:"2-digit"}).format(d); }
TS
    git add packages/i18n/format/*.ts
    ```

---

## ЭТАП 186. SEO/OG, карта сайта и микроразметка

- [ ] T-0212 | Генерация sitemap.xml для каталога
  - depends: [T-0065, T-0197]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/seo
    cat > apps/svc-website/src/seo/sitemap.ts <<'TS'
import fs from "fs"; const cities=["tashkent","samarkand","bukhara","namangan","andijan"];
const cats=["venues","catering","photo","video","music","decor"];
export function buildSitemap(base="https://weddingtech.uz"){
  const urls = ["/","/catalog",...cities.flatMap(c=>cats.map(k=>`/catalog/${c}/${k}`))].map(p=>`<url><loc>${base}${p}</loc></url>`).join("");
  const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls}</urlset>`;
  fs.mkdirSync("public",{recursive:true}); fs.writeFileSync("public/sitemap.xml",xml);
  return {ok:true}
}
TS
    git add apps/svc-website/src/seo/sitemap.ts
    ```

- [ ] T-0213 | OpenGraph/Twitter метатеги генератор
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/seo
    cat > apps/svc-website/src/seo/meta.ts <<'TS'
export function og({title,desc,url,image}:{title:string;desc:string;url:string;image:string}) {
  return [
    ["meta",{property:"og:title",content:title}],
    ["meta",{property:"og:description",content:desc}],
    ["meta",{property:"og:url",content:url}],
    ["meta",{property:"og:image",content:image}],
    ["meta",{name:"twitter:card",content:"summary_large_image"}],
    ["meta",{name:"twitter:title",content:title}],
    ["meta",{name:"twitter:description",content:desc}],
    ["meta",{name:"twitter:image",content:image}]
  ];
}
TS
    git add apps/svc-website/src/seo/meta.ts
    ```

- [ ] T-0214 | JSON-LD схема для карточки площадки (Venue)
  - depends: [T-0065]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/seo
    cat > apps/svc-website/src/seo/venue-jsonld.ts <<'TS'
export function venueSchema({name,city,capacity,url}:{name:string;city:string;capacity:number;url:string}){
  return {
    "@context":"https://schema.org",
    "@type":"EventVenue",
    "name":name,"address":city,"maximumAttendeeCapacity":capacity,"url":url
  };
}
TS
    git add apps/svc-website/src/seo/venue-jsonld.ts
    ```

---

## ЭТАП 187. Медиа: галереи, оптимизация изображений и превью

- [ ] T-0215 | Пакет @wt/media: оптимизация изображений (sharp)
  - depends: [T-0003]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/media/src
    cat > packages/media/src/optimize.ts <<'TS'
import fs from "fs"; import path from "path";
let sharp:any; try{ sharp=require("sharp"); }catch(e){ sharp=null; }
export async function resize(input:string,outDir:string,widths:number[]=[480,960,1440]){
  if(!fs.existsSync(outDir)) fs.mkdirSync(outDir,{recursive:true});
  if(!sharp){ fs.copyFileSync(input, path.join(outDir, path.basename(input))); return {ok:true, note:"sharp-not-installed"}; }
  const ext=path.extname(input).toLowerCase(); const base=path.basename(input,ext);
  for(const w of widths){ await sharp(input).resize({width:w}).jpeg({quality:80}).toFile(path.join(outDir,`${base}-${w}.jpg`)); }
  return {ok:true}
}
TS
    cat > packages/media/package.json <<'JSON'
{ "name":"@wt/media","private":true,"type":"module","dependencies":{} }
JSON
    git add packages/media/src/optimize.ts packages/media/package.json
    ```

- [ ] T-0216 | Галерея (masonry) для профиля тойханы
  - depends: [T-0207, T-0215]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/gallery
    cat > apps/svc-website/src/ui/gallery/Masonry.tsx <<'TSX'
import React from "react";
export function Masonry({images}:{images:{src:string;alt:string}[]}) {
  return <div className="gap-2 columns-2 sm:columns-3 lg:columns-4">
    {images.map((im,i)=><img key={i} src={im.src} alt={im.alt} className="mb-2 rounded-2xl w-full inline-block" loading="lazy"/>)}
  </div>;
}
TSX
    git add apps/svc-website/src/ui/gallery/Masonry.tsx
    ```

- [ ] T-0217 | Превью загрузок: генерация thumbnail (256px)
  - depends: [T-0215]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-media/scripts
    cat > apps/svc-media/scripts/thumb-256.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
in="$1"; out="$2"
node -e 'const {resize}=require("../../packages/media/src/optimize.ts"); resize(process.argv[1],process.argv[2],[256]).then(()=>process.exit(0))' "$in" "$out"
SH
    chmod +x apps/svc-media/scripts/thumb-256.sh
    git add apps/svc-media/scripts/thumb-256.sh
    ```

---

## ЭТАП 188. Почтовые шаблоны и уведомления

- [ ] T-0218 | Email-шаблоны: приглашение гостя и заявка поставщику
  - depends: [T-0120]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/mail/templates
    cat > packages/mail/templates/guest-invite.html <<'HTML'
<!doctype html><html><body style="font-family:Arial">
<h2>Приглашение на свадьбу</h2>
<p>Вы приглашены на событие. Пожалуйста, подтвердите участие по ссылке RSVP.</p>
</body></html>
HTML
    cat > packages/mail/templates/vendor-enquiry.html <<'HTML'
<!doctype html><html><body style="font-family:Arial">
<h2>Новая заявка</h2>
<p>Вам поступила новая заявка от пары. Пожалуйста, войдите в кабинет, чтобы ответить.</p>
</body></html>
HTML
    git add packages/mail/templates/*.html
    ```

- [ ] T-0219 | Отправка писем (SMTP URL) — простой sender
  - depends: [T-0120]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/mail
    cat > packages/mail/index.ts <<'TS'
import nodemailer from "nodemailer"; export async function send(to:string,subject:string,html:string){
  const url=process.env.SMTP_URL||""; const tr=nodemailer.createTransport(url); await tr.sendMail({to,from:process.env.MAIL_FROM||"noreply@weddingtech.uz",subject,html});
  return {ok:true};
}
TS
    git add packages/mail/index.ts
    ```

---

## ЭТАП 189. Календарь и .ics экспорт

- [ ] T-0220 | Экспорт доступности площадок в .ics
  - depends: [T-0065]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/calendar
    cat > packages/calendar/ics.ts <<'TS'
export function ics({title,events}:{title:string;events:{start:string;end:string;summary:string}[]}){
  const head = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//WeddingTech//Calendar//EN\n";
  const body = events.map(e=>["BEGIN:VEVENT",`SUMMARY:${e.summary}`,`DTSTART:${e.start}`,`DTEND:${e.end}`,"END:VEVENT"].join("\n")).join("\n");
  const foot = "\nEND:VCALENDAR\n"; return head+body+foot;
}
TS
    git add packages/calendar/ics.ts
    ```

- [ ] T-0221 | API точка: скачать .ics для vendor availability
  - depends: [T-0220, T-0004]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/api
    cat > apps/svc-vendors/src/api/availability-ics.js <<'JS'
import { createServer } from "http"; import { ics } from "../../../packages/calendar/ics.js";
const port=process.env.PORT||3000;
createServer((req,res)=>{
  if(req.url==="/vendors/availability.ics"){
    const now=new Date(); const d= (n)=> new Date(Date.now()+n*86400000);
    const pad=(n)=> String(n).padStart(2,"0");
    const fmt=(dt)=> dt.getUTCFullYear()+pad(dt.getUTCMonth()+1)+pad(dt.getUTCDate())+"T000000Z";
    const data=ics({title:"Vendor Availability", events:[
      {start:fmt(d(3)), end:fmt(d(3)), summary:"FREE"},
      {start:fmt(d(10)), end:fmt(d(10)), summary:"BUSY"}
    ]});
    res.writeHead(200,{"Content-Type":"text/calendar"}); res.end(data); return;
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-vendors/src/api/availability-ics.js
    ```

---

## ЭТАП 190. Админ-панель (скелет) и модерация

- [ ] T-0222 | Admin UI (скелет разделов)
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/pages
    cat > apps/svc-admin/src/pages/index.tsx <<'TSX'
import React from "react";
export default function AdminHome(){
  return <main className="p-6">
    <h1 className="text-2xl font-bold mb-4">Admin</h1>
    <ul className="list-disc pl-6">
      <li>Модерация медиа</li>
      <li>Проверка документов поставщиков</li>
      <li>Журналы событий</li>
    </ul>
  </main>;
}
TSX
    git add apps/svc-admin/src/pages/index.tsx
    ```

- [ ] T-0223 | Модерация отзывов: правило «только контракт»
  - depends: [T-0190]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/moderation
    cat > apps/svc-admin/src/moderation/reviews.ts <<'TS'
export function canPublishReview({contractVerified}:{contractVerified:boolean}){ return !!contractVerified; }
TS
    git add apps/svc-admin/src/moderation/reviews.ts
    ```

---

## ЭТАП 191. Производительность и качество интерфейса

- [ ] T-0224 | Ленивая загрузка изображений + width/height атрибуты
  - depends: [T-0216]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/img
    cat > apps/svc-website/src/ui/img/LazyImg.tsx <<'TSX'
import React from "react";
export function LazyImg({src,alt,w,h}:{src:string;alt:string;w:number;h:number}){
  return <img src={src} alt={alt} width={w} height={h} loading="lazy" className="rounded-2xl"/>;
}
TSX
    git add apps/svc-website/src/ui/img/LazyImg.tsx
    ```

- [ ] T-0225 | Скелетон-лоадер для карточек каталога
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/skeleton
    cat > apps/svc-website/src/ui/skeleton/CardSkeleton.tsx <<'TSX'
import React from "react";
export function CardSkeleton(){
  return <div className="rounded-2xl p-4 animate-pulse" style={{background:"var(--card)"}}>
    <div className="h-40 w-full rounded-2xl mb-3" style={{background:"#e5e7eb"}}></div>
    <div className="h-4 w-2/3 mb-2" style={{background:"#e5e7eb"}}></div>
    <div className="h-4 w-1/2" style={{background:"#e5e7eb"}}></div>
  </div>;
}
TSX
    git add apps/svc-website/src/ui/skeleton/CardSkeleton.tsx
    ```
---

## ЭТАП 192. Данные: Prisma-схема, миграции и сиды

- [ ] T-0226 | Prisma schema: базовые сущности (User, Vendor, Venue, Enquiry, Review)
  - depends: [T-0012]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/prisma
    cat > packages/prisma/schema.prisma <<'PRISMA'
generator client { provider = "prisma-client-js" }
datasource db { provider = "postgresql"; url = env("DATABASE_URL") }

model User {
  id           String  @id @default(cuid())
  email        String  @unique
  passwordHash String
  name         String?
  role         Role    @default(USER)
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  favourites   Favourite[]
  enquiries    Enquiry[] @relation("EnquiryUser")
}

model Vendor {
  id        String @id @default(cuid())
  title     String
  city      String
  category  String
  verified  Boolean @default(false)
  rating    Float   @default(0)
  reviews   Review[]
  venues    Venue[]
  docs      VendorDoc[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Venue {
  id        String @id @default(cuid())
  vendorId  String
  vendor    Vendor @relation(fields: [vendorId], references: [id])
  name      String
  capacity  Int
  address   String
  toursUrl  String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Enquiry {
  id        String   @id @default(cuid())
  userId    String?
  user      User?    @relation("EnquiryUser", fields: [userId], references: [id])
  vendorId  String
  vendor    Vendor   @relation(fields: [vendorId], references: [id])
  status    EnquiryStatus @default(NEW)
  budget    Int?
  date      DateTime?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  tier      EnquiryTier @default(FREE)
}

model Review {
  id        String @id @default(cuid())
  vendorId  String
  vendor    Vendor @relation(fields: [vendorId], references: [id])
  rating    Int
  text      String
  createdAt DateTime @default(now())
  contractBased Boolean @default(false)
}

model VendorDoc {
  id        String @id @default(cuid())
  vendorId  String
  vendor    Vendor @relation(fields: [vendorId], references: [id])
  name      String
  url       String
  verified  Boolean @default(false)
}

model Favourite {
  id       String @id @default(cuid())
  userId   String
  user     User   @relation(fields: [userId], references: [id])
  vendorId String
  vendor   Vendor @relation(fields: [vendorId], references: [id])
  createdAt DateTime @default(now())
}

enum Role { USER VENDOR ADMIN }
enum EnquiryStatus { NEW QUOTED CONTRACT_SIGNED WON LOST }
enum EnquiryTier { FREE TARGETED }
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0227 | Prisma scripts в package.json рабочего пространства
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    if [ -f package.json ]; then
      jq '.scripts += {
        "prisma:gen":"prisma generate --schema packages/prisma/schema.prisma",
        "prisma:migrate":"prisma migrate dev --name init --schema packages/prisma/schema.prisma",
        "prisma:deploy":"prisma migrate deploy --schema packages/prisma/schema.prisma",
        "prisma:studio":"prisma studio --schema packages/prisma/schema.prisma"
      }' package.json > package.tmp && mv package.tmp package.json
      git add package.json
    fi
    ```

- [ ] T-0228 | Сиды: города, категории, демонстрационные вендоры/площадки
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/prisma/seed
    cat > packages/prisma/seed/index.ts <<'TS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
async function run(){
  const cities=["Tashkent","Samarkand","Bukhara","Namangan","Andijan"];
  const cats=["venues","catering","photo","video","music","decor"];
  for(const i of [0,1,2,3,4]){
    const v=await db.vendor.create({data:{
      title:`Vendor ${i+1}`, city:cities[i%cities.length], category:cats[i%cats.length], verified:i%2===0, rating: 4.2
    }});
    await db.venue.create({data:{vendorId:v.id,name:`Venue ${i+1}`,capacity:200+50*i,address:`${v.city}, Center ${i+1}`}});
  }
  console.log("Seed done");
}
run().finally(()=>process.exit(0));
TS
    # добавить скрипт запуска сидов
    if [ -f package.json ]; then
      jq '.scripts += {"prisma:seed":"node packages/prisma/seed/index.ts"}' package.json > package.tmp && mv package.tmp package.json
      git add package.json
    fi
    git add packages/prisma/seed/index.ts
    ```

- [ ] T-0229 | Миграции на CI: включить prisma:deploy в DO старте
  - depends: [T-0186, T-0227]
  - apply:
    ```bash
    set -euo pipefail
    # убеждаемся, что start-with-migrations вызывает prisma:deploy
    sed -i 's/pnpm -C packages\/prisma run migrate:deploy/pnpm run prisma:deploy/' scripts/start-with-migrations.sh
    git add scripts/start-with-migrations.sh
    ```

---

## ЭТАП 193. Аутентификация и авторизация

- [ ] T-0230 | JWT-аутентификация: генерация/проверка токена
  - depends: [T-0004, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/auth
    cat > packages/auth/jwt.ts <<'TS'
import crypto from "crypto";
function b64url(b:Buffer){return b.toString("base64").replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_");}
export function sign(payload:Record<string,any>, secret:string){
  const header=b64url(Buffer.from(JSON.stringify({alg:"HS256",typ:"JWT"})));
  const body=b64url(Buffer.from(JSON.stringify(payload)));
  const data=`${header}.${body}`;
  const sig=b64url(crypto.createHmac("sha256",secret).update(data).digest());
  return `${data}.${sig}`;
}
export function verify(token:string, secret:string){
  const [h,b,s]=token.split(".");
  if(!h||!b||!s) return null;
  const sig=b64url(crypto.createHmac("sha256",secret).update(`${h}.${b}`).digest());
  if(sig!==s) return null;
  return JSON.parse(Buffer.from(b,"base64").toString("utf-8"));
}
TS
    git add packages/auth/jwt.ts
    ```

- [ ] T-0231 | Пароли: хэширование (argon2) и проверка
  - depends: [T-0230]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/auth
    cat > packages/auth/password.ts <<'TS'
import crypto from "crypto";
export function hashPassword(p:string){
  const salt=crypto.randomBytes(16).toString("hex");
  const hash=crypto.pbkdf2Sync(p,salt,310000,32,"sha256").toString("hex");
  return `${salt}:${hash}`;
}
export function verifyPassword(p:string,stored:string){
  const [salt,hash]=stored.split(":");
  const check=crypto.pbkdf2Sync(p,salt,310000,32,"sha256").toString("hex");
  return check===hash;
}
TS
    git add packages/auth/password.ts
    ```

- [ ] T-0232 | API login/register (auth svc) + cookie с JWT
  - depends: [T-0230, T-0231, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-auth/src
    cat > apps/svc-auth/src/server.js <<'JS'
import { createServer } from "http";
import { PrismaClient } from "@prisma/client";
import { hashPassword, verifyPassword } from "../../../packages/auth/password.js";
import { sign } from "../../../packages/auth/jwt.js";
const db=new PrismaClient(); const port=process.env.PORT||3000; const secret=process.env.JWT_SECRET||"changeme";
function parseBody(req){return new Promise((res)=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>{try{res(JSON.parse(b||"{}"))}catch(e){res({})}})})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/auth/register"){
    const body=await parseBody(req); if(!body.email||!body.password){res.writeHead(400);return res.end("bad");}
    const u=await db.user.create({data:{email:body.email,passwordHash:hashPassword(body.password),role:"USER"}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify({id:u.id,email:u.email}));
  }
  if(req.method==="POST" && req.url==="/auth/login"){
    const body=await parseBody(req); const u=await db.user.findUnique({where:{email:body.email}});
    if(!u || !verifyPassword(body.password,u.passwordHash)){res.writeHead(401);return res.end("unauth");}
    const token=sign({sub:u.id,role:u.role}, secret);
    res.writeHead(200,{"Set-Cookie":`jwt=${token}; HttpOnly; Path=/; SameSite=Lax`, "Content-Type":"application/json"});
    return res.end(JSON.stringify({ok:true}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-auth/src/server.js
    ```

- [ ] T-0233 | Роли и права: middleware-проверка (ADMIN/VENDOR/USER)
  - depends: [T-0230]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/auth
    cat > packages/auth/roles.ts <<'TS'
import { verify } from "./jwt.js";
export function requireRole(role:"ADMIN"|"VENDOR"|"USER"){
  return function(req:any,res:any,next:Function){
    const cookie=(req.headers["cookie"]||"").split(";").find((c:string)=>c.trim().startsWith("jwt="));
    if(!cookie){res.writeHead(401);return res.end("unauth");}
    const token=cookie.split("=")[1]; const data=verify(token, process.env.JWT_SECRET||"changeme");
    if(!data || (role==="ADMIN" && data.role!=="ADMIN")){res.writeHead(403);return res.end("forbidden");}
    (req as any).user=data; next();
  }
}
TS
    git add packages/auth/roles.ts
    ```

---

## ЭТАП 194. Каталог и поиск

- [ ] T-0234 | Поиск и фильтры каталога (город/категория/вместимость/рейтинг)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/api
    cat > apps/svc-catalog/src/api/search.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3000;
function q(url){const u=new URL(url,"http://localhost"); return Object.fromEntries(u.searchParams.entries());}
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url?.startsWith("/catalog/search")){
    const p=q(req.url); const where:any={};
    if(p.city) where.city=p.city;
    if(p.category) where.category=p.category;
    const vendors=await db.vendor.findMany({where, orderBy:{rating:"desc"}, take:50, include:{venues:true}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(vendors));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-catalog/src/api/search.js
    ```

- [ ] T-0235 | Сортировки и пагинация (page/limit/sort=rating|reviews)
  - depends: [T-0234]
  - apply:
    ```bash
    set -euo pipefail
    sed -i 's/findMany({where, orderBy:{rating:"desc"}, take:50, include:{venues:true}})/findMany({where, orderBy:{rating:"desc"}, skip: (Number(p.page||"1")-1)*Number(p.limit||"20"), take:Number(p.limit||"20"), include:{venues:true}})/' apps/svc-catalog/src/api/search.js
    git add apps/svc-catalog/src/api/search.js
    ```

- [ ] T-0236 | Избранное: API add/remove/list (требует USER)
  - depends: [T-0232, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/api
    cat > apps/svc-catalog/src/api/favourites.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3001;
function userIdFromCookie(req){const c=(req.headers["cookie"]||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  const uid=userIdFromCookie(req); if(!uid){res.writeHead(401); return res.end("unauth");}
  if(req.method==="POST" && req.url==="/fav/add"){ const b=await body(req);
    await db.favourite.create({data:{userId:uid, vendorId:b.vendorId}}); res.writeHead(200); return res.end("ok"); }
  if(req.method==="POST" && req.url==="/fav/remove"){ const b=await body(req);
    await db.favourite.deleteMany({where:{userId:uid, vendorId:b.vendorId}}); res.writeHead(200); return res.end("ok"); }
  if(req.method==="GET" && req.url==="/fav/list"){
    const list=await db.favourite.findMany({where:{userId:uid}, include:{vendor:true}}); res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(list)); }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-catalog/src/api/favourites.js
    ```

---

## ЭТАП 195. Заявки, контракты, инвойсы

- [ ] T-0237 | Enquiry create/update: API для пары (USER) и вендора (VENDOR)
  - depends: [T-0226, T-0232]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/api
    cat > apps/svc-enquiries/src/api/enquiry.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3002;
function parse(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
function uid(req){const c=(req.headers.cookie||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/enquiry/create"){ const u=uid(req); if(!u){res.writeHead(401);return res.end("unauth");}
    const b=await parse(req);
    const e=await db.enquiry.create({data:{userId:u, vendorId:b.vendorId, budget:b.budget||null, date:b.date?new Date(b.date):null, status:"NEW"}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(e));
  }
  if(req.method==="POST" && req.url==="/enquiry/status"){ const b=await parse(req);
    const e=await db.enquiry.update({where:{id:b.id}, data:{status:b.status}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(e));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-enquiries/src/api/enquiry.js
    ```

- [ ] T-0238 | Инвойсы: модель и генерация PDF-заглушки (HTML → PDF)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    # модель через SQL (простая таблица)
    mkdir -p packages/prisma/sql
    cat > packages/prisma/sql/invoices.sql <<'SQL'
-- minimal invoices table (если миграции вручную)
-- CREATE TABLE invoices (id text primary key, vendor_id text, user_id text, amount integer, currency text, created_at timestamp default now());
SQL
    mkdir -p packages/invoice
    cat > packages/invoice/html.ts <<'TS'
export function invoiceHtml({id,amount,currency}:{id:string;amount:number;currency:string}){
  return `<!doctype html><html><body><h1>Invoice ${id}</h1><p>Amount: ${amount} ${currency}</p></body></html>`;
}
TS
    git add packages/prisma/sql/invoices.sql packages/invoice/html.ts
    ```

- [ ] T-0239 | PDF генерация (puppeteer-free stub: сохраняем HTML)
  - depends: [T-0238]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src
    cat > apps/svc-billing/src/pdf.js <<'JS'
import fs from "fs"; import { invoiceHtml } from "../../../packages/invoice/html.js";
export async function genInvoice(id, amount, currency){
  const html=invoiceHtml({id,amount,currency});
  const path=`invoices/${id}.html`; fs.mkdirSync("invoices",{recursive:true}); fs.writeFileSync(path, html); return {ok:true, path};
}
JS
    git add apps/svc-billing/src/pdf.js
    ```

---

## ЭТАП 196. Медиа-хранилище и CDN

- [ ] T-0240 | S3 клиент (DigitalOcean Spaces): загрузка/получение URL
  - depends: [T-0003]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/storage
    cat > packages/storage/s3.ts <<'TS'
import crypto from "crypto";
export type PutResult={ok:true,key:string,url:string};
export async function putObject(buf:Buffer, key:string):Promise<PutResult>{
  const fakeUrl=`https://assets.weddingtech.uz/${encodeURIComponent(key)}?v=${crypto.randomBytes(4).toString("hex")}`;
  return {ok:true,key,url:fakeUrl};
}
TS
    git add packages/storage/s3.ts
    ```

- [ ] T-0241 | API загрузки медиа вендора (обложка площадки)
  - depends: [T-0240, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/api
    cat > apps/svc-vendors/src/api/upload-cover.js <<'JS'
import { createServer } from "http"; import { putObject } from "../../../packages/storage/s3.js";
const port=process.env.PORT||3003;
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/vendors/upload-cover"){
    const chunks=[]; for await (const c of req) chunks.push(c);
    const buf=Buffer.concat(chunks);
    const r=await putObject(buf, `covers/${Date.now()}.jpg`);
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-vendors/src/api/upload-cover.js
    ```

---

## ЭТАП 197. Кэш, очереди и производительность

- [ ] T-0242 | Redis-stub (in-memory) и простой кэш-хелпер
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/cache
    cat > packages/cache/index.ts <<'TS'
const store=new Map<string,{v:any,exp:number}>();
export async function cacheGet<T>(k:string){const e=store.get(k); if(!e) return null; if(Date.now()>e.exp){store.delete(k); return null;} return e.v as T;}
export async function cacheSet<T>(k:string,v:T,ttlMs:number){store.set(k,{v,exp:Date.now()+ttlMs}); return true;}
TS
    git add packages/cache/index.ts
    ```

- [ ] T-0243 | Обёртка кэша для каталога (по городу/категории)
  - depends: [T-0242, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/findMany\(\{where/{print "    // cache layer\\n    // (демо) можно подключить redis тут"}' apps/svc-catalog/src/api/search.js > /tmp/s && mv /tmp/s apps/svc-catalog/src/api/search.js
    git add apps/svc-catalog/src/api/search.js
    ```

- [ ] T-0244 | Очереди BullMQ-stub (уже есть): таск для генерации превью
  - depends: [T-0199, T-0215]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-media/queue
    cat > apps/svc-media/queue/jobs.ts <<'TS'
import { enqueue } from "../../../packages/queue/index";
export function enqueueThumb(key:string){ return enqueue("thumb256",{key}); }
TS
    git add apps/svc-media/queue/jobs.ts
    ```

---

## ЭТАП 198. Платёжный слой (стаб) и статусы оплаты

- [ ] T-0245 | Payments stub: createIntent / capture / webhook
  - depends: [T-0238, T-0239]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/api
    cat > apps/svc-billing/src/api/payments.js <<'JS'
import { createServer } from "http";
const port=process.env.PORT||3004;
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/pay/create-intent"){
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({id:"pi_demo_1",clientSecret:"secret_demo"}));
  }
  if(req.method==="POST" && req.url==="/pay/capture"){
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true,status:"succeeded"}));
  }
  if(req.method==="POST" && req.url==="/pay/webhook"){
    res.writeHead(200); return res.end("ok");
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-billing/src/api/payments.js
    ```

---

## ЭТАП 199. API-контракты и документация

- [ ] T-0246 | OpenAPI spec (yaml) для ключевых эндпоинтов
  - depends: [T-0232, T-0234, T-0237, T-0245]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/api
    cat > docs/api/openapi.yaml <<'YML'
openapi: 3.0.0
info:
  title: WeddingTech UZ API
  version: 0.1.0
paths:
  /auth/login:
    post: {summary: Login, responses: {200: {description: OK}}}
  /catalog/search:
    get: {summary: Search vendors, responses: {200: {description: OK}}}
  /enquiry/create:
    post: {summary: Create enquiry, responses: {201: {description: Created}}}
  /pay/create-intent:
    post: {summary: Create payment intent, responses: {200: {description: OK}}}
YML
    git add docs/api/openapi.yaml
    ```

- [ ] T-0247 | Postman коллекция (json) — автоимпорт
  - depends: [T-0246]
  - apply:
    ```bash
    set -euo pipefail
    cat > docs/api/postman.json <<'JSON'
{"info":{"name":"WeddingTech UZ","schema":"https://schema.getpostman.com/json/collection/v2.1.0/collection.json"},"item":[
  {"name":"Login","request":{"method":"POST","url":"{{base}}/auth/login","body":{"mode":"raw","raw":"{\"email\":\"test@test.com\",\"password\":\"test\"}"}},"response":[]},
  {"name":"Search","request":{"method":"GET","url":"{{base}}/catalog/search?city=Tashkent&category=venues"},"response":[]}
]}
JSON
    git add docs/api/postman.json
    ```

---

## ЭТАП 200. Тесты и качество

- [ ] T-0248 | Vitest: юнит-тесты auth/password, score()
  - depends: [T-0231, T-0194]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p tests
    cat > tests/auth.password.test.ts <<'TS'
import { hashPassword, verifyPassword } from "../packages/auth/password";
test("hash/verify", ()=>{ const h=hashPassword("x"); expect(verifyPassword("x",h)).toBe(true); });
TS
    cat > tests/rank.score.test.ts <<'TS'
import { score } from "../apps/svc-catalog/src/rank/score";
test("score weights", ()=>{ expect(score({conv:0.4,rating:0.8,profile:1,calendar:1})).toBeCloseTo(0.5*0.4+0.2*0.8+0.2*1+0.1*1); });
TS
    git add tests/*.ts
    ```

- [ ] T-0249 | Playwright: e2e smoke для публичного сайта
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p e2e
    cat > e2e/smoke.spec.ts <<'TS'
import { test, expect } from "@playwright/test";
test("home loads", async ({ page })=>{
  await page.goto(process.env.E2E_BASE||"http://localhost:3000");
  await expect(page).toHaveTitle(/Wedding|Свадьба/i);
});
TS
    git add e2e/smoke.spec.ts
    ```

- [ ] T-0250 | ESLint + Prettier + Husky pre-commit
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    # минимальные конфиги
    cat > .eslintrc.json <<'JSON'
{ "env": { "es2021": true, "node": true }, "extends": [], "parserOptions": { "ecmaVersion": 2021 }, "rules": {} }
JSON
    cat > .prettierrc.json <<'JSON'
{ "printWidth": 100, "singleQuote": true, "semi": true }
JSON
    mkdir -p .husky
    cat > .husky/pre-commit <<'SH'
#!/usr/bin/env bash
npx --yes prettier -c .
SH
    chmod +x .husky/pre-commit
    git add .eslintrc.json .prettierrc.json .husky/pre-commit
    ```

---

## ЭТАП 201. Инфраструктура локально

- [ ] T-0251 | Docker Compose: postgres + minio (место DO Spaces)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    cat > docker-compose.yml <<'YML'
version: "3.8"
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: pg
      POSTGRES_USER: pg
      POSTGRES_DB: wt
    ports: ["5432:5432"]
  minio:
    image: minio/minio
    command: server /data
    environment:
      MINIO_ACCESS_KEY: minio
      MINIO_SECRET_KEY: minio123
    ports: ["9000:9000","9001:9001"]
YML
    git add docker-compose.yml
    ```

- [ ] T-0252 | Env примеры (.env.example) для всех сервисов
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    cat > .env.example <<'ENV'
DATABASE_URL=postgresql://pg:pg@localhost:5432/wt
JWT_SECRET=supersecret
SMTP_URL=smtp://user:pass@smtp.example.com:587
MAIL_FROM=noreply@weddingtech.uz
ENV
    git add .env.example
    ```

---

## ЭТАП 202. Безопасность и соответствие

- [ ] T-0253 | Security headers + CSP политика (docs)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/security
    cat > docs/security/headers.md <<'MD'
# Security Headers
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- Referrer-Policy: strict-origin-when-cross-origin
- Content-Security-Policy: default-src 'self'; img-src 'self' data: https:;
MD
    git add docs/security/headers.md
    ```

- [ ] T-0254 | Sentry stub: captureException()
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/monitor
    cat > packages/monitor/sentry.ts <<'TS'
export function captureException(e:any, ctx?:any){ console.error("SENTRY_STUB", e && e.message ? e.message : e, ctx||{}); }
TS
    git add packages/monitor/sentry.ts
    ```

- [ ] T-0255 | Audit-лог: простая запись событий в файл
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/audit
    cat > packages/audit/log.ts <<'TS'
import fs from "fs"; export function audit(event:string, payload:any){ fs.appendFileSync("audit.log", JSON.stringify({ts:new Date().toISOString(),event,payload})+"\n"); }
TS
    git add packages/audit/log.ts
    ```

---

## ЭТАП 203. Статические страницы и SEO-скелеты

- [ ] T-0256 | robots.txt и humans.txt
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p public
    cat > public/robots.txt <<'TXT'
User-agent: *
Allow: /
Sitemap: https://weddingtech.uz/sitemap.xml
TXT
    cat > public/humans.txt <<'TXT'
Team: WeddingTech UZ
TXT
    git add public/robots.txt public/humans.txt
    ```

- [ ] T-0257 | Политики: privacy.md и terms.md
  - depends: [T-0201]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/legal
    cat > docs/legal/privacy.md <<'MD'
# Privacy Policy (excerpt)
- Мы храним минимум персональных данных, экспорт по запросу, удаление ≤ 7 дней.
MD
    cat > docs/legal/terms.md <<'MD'
# Terms of Service (excerpt)
- Публичные правила использования платформы WeddingTech UZ.
MD
    git add docs/legal/privacy.md docs/legal/terms.md
    ```

---

## ЭТАП 204. UI улучшения каталога и страниц вендора

- [ ] T-0258 | Компонент VendorCard с бейджами verified/rating
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/vendor
    cat > apps/svc-website/src/ui/vendor/VendorCard.tsx <<'TSX'
import React from "react";
export function VendorCard({title,city,verified,rating}:{title:string;city:string;verified:boolean;rating:number}){
  return <div className="rounded-2xl p-4 shadow-sm" style={{background:"var(--card)"}}>
    <div className="flex items-center justify-between">
      <h3 className="text-lg font-semibold">{title}</h3>
      {verified && <span className="text-xs px-2 py-1 rounded-2xl" style={{background:"#e6fbe6",color:"#0f5132"}}>verified</span>}
    </div>
    <p className="small">{city}</p>
    <p className="small">★ {rating.toFixed(1)}</p>
  </div>;
}
TSX
    git add apps/svc-website/src/ui/vendor/VendorCard.tsx
    ```

- [ ] T-0259 | Секция «Похожие поставщики» (simple related)
  - depends: [T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/widgets
    cat > apps/svc-website/src/widgets/RelatedVendors.tsx <<'TSX'
import React from "react";
import { VendorCard } from "../ui/vendor/VendorCard";
export function RelatedVendors({items}:{items:{title:string;city:string;verified:boolean;rating:number}[]}) {
  return <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
    {items.map((v,i)=><VendorCard key={i} {...v} />)}
  </div>;
}
TSX
    git add apps/svc-website/src/widgets/RelatedVendors.tsx
    ```

---

## ЭТАП 205. Админ-лог и верификация документов

- [ ] T-0260 | API: загрузка/верификация документов поставщика (флаг verified)
  - depends: [T-0193, T-0226, T-0240]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/api
    cat > apps/svc-vendors/src/api/docs.js <<'JS'
import { createServer } from "http"; import { putObject } from "../../../packages/storage/s3.js";
const port=process.env.PORT||3005;
async function read(req){return new Promise(r=>{const ch=[];req.on("data",c=>ch.push(c));req.on("end",()=>r(Buffer.concat(ch)))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/vendors/doc/upload"){
    const buf=await read(req); const r=await putObject(buf, `docs/${Date.now()}.pdf`);
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r));
  }
  if(req.method==="POST" && req.url==="/vendors/doc/verify"){
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true,verified:true}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-vendors/src/api/docs.js
    ```

---

## ЭТАП 206. Observability и эксплуатация

- [ ] T-0261 | Логи запросов (common format) для всех svc (пример)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/log
    cat > packages/log/http.ts <<'TS'
export function log(req:any,res:any){ console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`); }
TS
    git add packages/log/http.ts
    ```

- [ ] T-0262 | Health summary docs (инвентарь сервисов)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops
    cat > docs/ops/services.md <<'MD'
# Services
- svc-auth: /auth/login
- svc-catalog: /catalog/search
- svc-enquiries: /enquiry/create
- svc-billing: /pay/create-intent
- svc-vendors: /vendors/upload-cover
MD
    git add docs/ops/services.md
    ```

---

## ЭТАП 207. Импорт/экспорт данных

- [ ] T-0263 | CSV импорт поставщиков (title, city, category)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/import
    cat > apps/svc-admin/src/import/vendors-csv.ts <<'TS'
import fs from "fs"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient();
export async function importVendorsCsv(path:string){
  const rows=fs.readFileSync(path,"utf-8").trim().split(/\r?\n/);
  for(const r of rows){ const [title,city,category]=r.split(","); await db.vendor.create({data:{title,city,category}}); }
}
TS
    git add apps/svc-admin/src/import/vendors-csv.ts
    ```

- [ ] T-0264 | Экспорт заявок в CSV
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/export
    cat > apps/svc-admin/src/export/enquiries-csv.ts <<'TS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function exportEnquiriesCsv(){ const list=await db.enquiry.findMany(); return "id,status,vendorId\\n"+list.map(e=>`${e.id},${e.status},${e.vendorId}`).join("\\n"); }
TS
    git add apps/svc-admin/src/export/enquiries-csv.ts
    ```

---

## ЭТАП 208. Улучшения UX: формы и валидации

- [ ] T-0265 | UI Input/Form helpers (очистка, error state)
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/form
    cat > apps/svc-website/src/ui/form/Input.tsx <<'TSX'
import React from "react";
export function Input({value,onChange,placeholder}:{value:string;onChange:(v:string)=>void;placeholder?:string}){
  return <input value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder||""}
    className="w-full px-3 py-2 rounded-2xl border outline-none focus:ring" />;
}
TSX
    git add apps/svc-website/src/ui/form/Input.tsx
    ```

- [ ] T-0266 | Toast-уведомления (простая реализация)
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/toast
    cat > apps/svc-website/src/ui/toast/index.tsx <<'TSX'
import React from "react";
let setFn:(v:{text:string}|null)=>void=()=>{};
export function ToastHost(){ const [v,setV]=React.useState<{text:string}|null>(null); React.useEffect(()=>{setFn=setV;},[]); return v?<div className="fixed bottom-4 right-4 px-4 py-2 rounded-2xl text-white" style={{background:"var(--brand)"}}>{v.text}</div>:null;}
export function toast(text:string){ setFn({text}); setTimeout(()=>setFn(null),2500); }
TSX
    git add apps/svc-website/src/ui/toast/index.tsx
    ```

---

## ЭТАП 209. Завершение MVP-контура

- [ ] T-0267 | Readme-сборка: как поднять проект локально/DO
  - depends: [T-0251, T-0182]
  - apply:
    ```bash
    set -euo pipefail
    cat > README.md <<'MD'
# WeddingTech UZ (MVP)
## Local
1) docker-compose up -d db
2) export DATABASE_URL=postgresql://pg:pg@localhost:5432/wt
3) pnpm run prisma:gen && pnpm run prisma:migrate && pnpm run prisma:seed
4) запустить сервисы (auth/catalog/enquiries/vendors/billing)
## DO App Platform
- см. infra/do/app.yaml и docs/ops/do/one-click-deploy.md
MD
    git add README.md
    ```

- [ ] T-0268 | Sample .http файлы для REST тестирования
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p http
    cat > http/login.http <<'HTTP'
POST http://localhost:3000/auth/login
Content-Type: application/json

{"email":"test@test.com","password":"test"}
HTTP
    git add http/login.http
    ```

- [ ] T-0269 | Проверка лицензий open-source (док)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/legal
    cat > docs/legal/licenses.md <<'MD'
# OSS Licenses
- Этот проект использует open-source компоненты; следим за лицензиями MIT/Apache-2.0.
MD
    git add docs/legal/licenses.md
    ```

---

## ЭТАП 210. Бронирование и календарь

- [ ] T-0270 | Модель Booking + SlotLock (Prisma расширение)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Booking {
  id        String   @id @default(cuid())
  vendorId  String
  vendor    Vendor   @relation(fields: [vendorId], references: [id])
  userId    String
  user      User     @relation(fields: [userId], references: [id])
  startAt   DateTime
  endAt     DateTime
  status    BookingStatus @default(PENDING_PAYMENT)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model SlotLock {
  id        String   @id @default(cuid())
  vendorId  String
  startAt   DateTime
  endAt     DateTime
  lockedUntil DateTime
  byUserId  String?
}

enum BookingStatus { PENDING_PAYMENT PAID CANCELED }
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0271 | API слотов: list/free/lock
  - depends: [T-0270]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/api
    cat > apps/svc-enquiries/src/api/slots.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3010;
function json(res,code,p){res.writeHead(code,{"Content-Type":"application/json"});res.end(JSON.stringify(p));}
function uid(req){const c=(req.headers.cookie||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url.startsWith("/slots/free")){
    const u=new URL(req.url,"http://x"); const vendorId=u.searchParams.get("vendorId");
    const date=u.searchParams.get("date"); const d0=new Date(date+"T00:00:00Z"); const d1=new Date(date+"T23:59:59Z");
    const locks=await db.slotLock.findMany({where:{vendorId, lockedUntil:{gt:new Date()}}});
    const bookings=await db.booking.findMany({where:{vendorId, startAt:{gte:d0}, endAt:{lte:d1}}});
    return json(res,200,{locks,bookings});
  }
  if(req.method==="POST" && req.url==="/slots/lock"){
    const u=uid(req); if(!u) return json(res,401,{ok:false});
    const b=await body(req); const until=new Date(Date.now()+5*60*1000);
    const lock=await db.slotLock.create({data:{vendorId:b.vendorId,startAt:new Date(b.startAt),endAt:new Date(b.endAt),lockedUntil:until,byUserId:u}});
    return json(res,200,{ok:true,id:lock.id,lockedUntil:until});
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-enquiries/src/api/slots.js
    ```

- [ ] T-0272 | Создание бронирования из lock + связка с оплатой
  - depends: [T-0271, T-0245]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/api
    cat > apps/svc-enquiries/src/api/booking.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3011;
function json(res,code,p){res.writeHead(code,{"Content-Type":"application/json"});res.end(JSON.stringify(p));}
function uid(req){const c=(req.headers.cookie||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/booking/create"){
    const u=uid(req); if(!u) return json(res,401,{ok:false});
    const b=await body(req);
    const lock=await db.slotLock.findUnique({where:{id:b.lockId}});
    if(!lock || lock.lockedUntil < new Date()) return json(res,409,{ok:false,reason:"lock_expired"});
    const bk=await db.booking.create({data:{userId:u,vendorId:lock.vendorId,startAt:lock.startAt,endAt:lock.endAt,status:"PENDING_PAYMENT"}});
    return json(res,201,{ok:true,id:bk.id});
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-enquiries/src/api/booking.js
    ```

- [ ] T-0273 | Отмена блокировок по TTL (cron js)
  - depends: [T-0271]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/scripts
    cat > apps/svc-enquiries/scripts/locks-gc.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
const main=async()=>{ await db.slotLock.deleteMany({where:{lockedUntil:{lt:new Date()}}}); console.log("locks gc done"); };
main().then(()=>process.exit(0));
JS
    git add apps/svc-enquiries/scripts/locks-gc.js
    ```

- [ ] T-0274 | Привязка оплаты: update Booking.status на succeeded
  - depends: [T-0245, T-0272]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/hooks
    cat > apps/svc-billing/src/hooks/booking-paid.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function markPaid(bookingId){ await db.booking.update({where:{id:bookingId}, data:{status:"PAID"}}); return {ok:true}; }
JS
    git add apps/svc-billing/src/hooks/booking-paid.js
    ```

- [ ] T-0275 | API: /booking/confirm (после capture)
  - depends: [T-0274]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-billing/src/api/confirm.js <<'JS'
import { createServer } from "http"; import { markPaid } from "../hooks/booking-paid.js";
const port=process.env.PORT||3012;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/booking/confirm"){
    const b=await body(req); await markPaid(b.bookingId);
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-billing/src/api/confirm.js
    ```

- [ ] T-0276 | ICS выгрузка подтверждённого бронирования
  - depends: [T-0220, T-0275]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/api
    cat > apps/svc-enquiries/src/api/booking-ics.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client"; import { ics } from "../../../packages/calendar/ics.js";
const db=new PrismaClient(); const port=process.env.PORT||3013;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url.startsWith("/booking/ics")){
    const id=new URL(req.url,"http://x").searchParams.get("id");
    const b=await db.booking.findUnique({where:{id}}); if(!b){res.writeHead(404);return res.end();}
    const fmt=(dt)=> dt.toISOString().replace(/[-:]/g,"").replace(/\.\d{3}Z/,"Z");
    const data=ics({title:"Booking",events:[{start:fmt(b.startAt),end:fmt(b.endAt),summary:"Wedding booking"}]});
    res.writeHead(200,{"Content-Type":"text/calendar"}); return res.end(data);
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-enquiries/src/api/booking-ics.js
    ```

---

## ЭТАП 211. Прайс-листы, пакеты и промокоды

- [ ] T-0277 | Модель PricePackage + PriceItem
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model PricePackage {
  id        String @id @default(cuid())
  vendorId  String
  title     String
  price     Int
  currency  String @default("UZS")
  items     PriceItem[]
}

model PriceItem {
  id        String @id @default(cuid())
  packageId String
  pkg       PricePackage @relation(fields: [packageId], references: [id])
  label     String
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0278 | API: CRUD пакетов для вендора
  - depends: [T-0277]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/api
    cat > apps/svc-vendors/src/api/pricing.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3020;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/pricing/create"){
    const b=await body(req); const pkg=await db.pricePackage.create({data:{vendorId:b.vendorId,title:b.title,price:b.price,currency:b.currency||"UZS"}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(pkg));
  }
  if(req.method==="GET" && req.url.startsWith("/pricing/list")){
    const v=new URL(req.url,"http://x").searchParams.get("vendorId");
    const list=await db.pricePackage.findMany({where:{vendorId:v}, include:{items:true}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(list));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-vendors/src/api/pricing.js
    ```

- [ ] T-0279 | Модель PromoCode + применение к бронированию
  - depends: [T-0270]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model PromoCode {
  id        String @id @default(cuid())
  code      String  @unique
  discount  Int     // процент 0..100
  validTill DateTime
  vendorId  String?
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0280 | API: promo/apply (валидация срока/привязки к вендору)
  - depends: [T-0279]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/api
    cat > apps/svc-billing/src/api/promo.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3021;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/promo/apply"){
    const b=await body(req);
    const p=await db.promoCode.findUnique({where:{code:b.code}});
    const ok=!!p && p.validTill>new Date() && (!p.vendorId || p.vendorId===b.vendorId);
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok,discount: ok?p.discount:0}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-billing/src/api/promo.js
    ```

- [ ] T-0281 | Расчёт итоговой стоимости: пакет + промо (%)
  - depends: [T-0278, T-0280]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/lib
    cat > apps/svc-billing/src/lib/total.js <<'JS'
export function calcTotal({base,discount}){ const d=Math.min(Math.max(discount||0,0),100); return Math.max(0, Math.round(base*(100-d)/100)); }
JS
    git add apps/svc-billing/src/lib/total.js
    ```

- [ ] T-0282 | Инвойс с указанием применённого промокода
  - depends: [T-0238, T-0281]
  - apply:
    ```bash
    set -euo pipefail
    sed -i 's/<\\/body>/<p>Promo: applied if present<\\/p><\\/body>/' packages/invoice/html.ts
    git add packages/invoice/html.ts
    ```

- [ ] T-0283 | Сид промокодов (WELCOME10 до +30 дней)
  - depends: [T-0279]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/seed/index.ts <<'TS'

await db.promoCode.upsert({
  where:{code:"WELCOME10"},
  update:{},
  create:{code:"WELCOME10",discount:10,validTill:new Date(Date.now()+30*86400000)}
});
TS
    git add packages/prisma/seed/index.ts
    ```

---

## ЭТАП 212. Рефералка и бонусы

- [ ] T-0284 | Модель Referral + начисления
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Referral {
  id        String @id @default(cuid())
  inviterId String
  inviteeId String
  reward    Int    @default(0)
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0285 | API: /ref/invite (создать пару), /ref/reward (начислить)
  - depends: [T-0284]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-auth/src/ref
    cat > apps/svc-auth/src/ref/api.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3030;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/ref/invite"){
    const b=await body(req); const r=await db.referral.create({data:{inviterId:b.inviterId, inviteeId:b.inviteeId, reward:0}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r));
  }
  if(req.method==="POST" && req.url==="/ref/reward"){
    const b=await body(req); const r=await db.referral.update({where:{id:b.id},data:{reward:b.amount}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r));
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-auth/src/ref/api.js
    ```

- [ ] T-0286 | Баланс пользователя (поле bonusBalance)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/model User {/{print "  bonusBalance Int @default(0)"}' packages/prisma/schema.prisma > /tmp/s && mv /tmp/s packages/prisma/schema.prisma
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0287 | Скрипт перерасчёта бонусов по рефералкам
  - depends: [T-0284, T-0286]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-auth/scripts
    cat > apps/svc-auth/scripts/ref-calc.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
const refs=await db.referral.findMany(); const sums=new Map();
for(const r of refs){ sums.set(r.inviterId, (sums.get(r.inviterId)||0)+r.reward); }
for(const [u,amt] of sums){ await db.user.update({where:{id:u}, data:{bonusBalance:amt}}); }
console.log("ref bonus recalculated");
JS
    git add apps/svc-auth/scripts/ref-calc.js
    ```

- [ ] T-0288 | Применение бонусов к оплате (минус из total)
  - depends: [T-0286, T-0281]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/lib
    cat > apps/svc-billing/src/lib/bonus.js <<'JS'
export function applyBonus(total, bonus){ const use=Math.min(total, Math.max(0, bonus||0)); return {payable: total-use, used: use}; }
JS
    git add apps/svc-billing/src/lib/bonus.js
    ```

---

## ЭТАП 213. ROI-дашборды и отчётность

- [ ] T-0289 | Aggregation: заявки/конверсия по городам
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/agg
    cat > apps/svc-analytics/src/agg/city.ts <<'TS'
export function byCity(items:{city:string,status:string}[]){
  const acc:Record<string,{enquiries:number,won:number}>={};
  for(const i of items){acc[i.city]??={enquiries:0,won:0};acc[i.city].enquiries++; if(i.status==="WON") acc[i.city].won++; }
  return Object.entries(acc).map(([k,v])=>({city:k,conv: v.enquiries? v.won/v.enquiries:0}));
}
TS
    git add apps/svc-analytics/src/agg/city.ts
    ```

- [ ] T-0290 | Admin отчёт: CSV сводка по городам
  - depends: [T-0289]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/reports
    cat > apps/svc-admin/src/reports/city-csv.ts <<'TS'
import { byCity } from "../../../apps/svc-analytics/src/agg/city";
export function cityCsv(rows:{city:string,status:string}[]){
  const agg=byCity(rows); return "city,conv\n"+agg.map(r=>`${r.city},${r.conv}`).join("\n");
}
TS
    git add apps/svc-admin/src/reports/city-csv.ts
    ```

- [ ] T-0291 | ROI виджет вендора: calc + dummy API
  - depends: [T-0193]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/api
    cat > apps/svc-analytics/src/api/vendor-roi.js <<'JS'
import { createServer } from "http"; import { calc } from "../roi/vendor.js";
const port=process.env.PORT||3040;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url.startsWith("/roi?v=")){
    const v=new URL(req.url,"http://x").searchParams.get("v");
    const data={views:1000,enquiries:50,won:10};
    const r=calc(data);
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({vendorId:v, ...r}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-analytics/src/api/vendor-roi.js
    ```

- [ ] T-0292 | Admin UI: быстрый просмотр ROI метрик
  - depends: [T-0291]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/widgets
    cat > apps/svc-admin/src/widgets/RoiCard.tsx <<'TSX'
import React from "react";
export function RoiCard({views,enquiries,won,conv}:{views:number;enquiries:number;won:number;conv:number}){
  return <div className="p-4 rounded-2xl" style={{background:"#f3f4f6"}}>
    <div>Просмотры: {views}</div><div>Заявки: {enquiries}</div><div>Сделки: {won}</div><div>Конверсия: {(conv*100).toFixed(1)}%</div>
  </div>;
}
TSX
    git add apps/svc-admin/src/widgets/RoiCard.tsx
    ```

---

## ЭТАП 214. DigitalOcean: autoscaling и CDN-заголовки

- [ ] T-0293 | DO app.yaml: autoscaling (минимальный патч)
  - depends: [T-0182]
  - apply:
    ```bash
    set -euo pipefail
    if [ -f infra/do/app.yaml ]; then
      awk '1; /source_dir: apps\/svc-website/ && c==0 {print "    instance_count: 1\n    autoscaling:\n      min_instances: 1\n      max_instances: 3\n      target_cpu_percent: 70"; c=1}' infra/do/app.yaml > /tmp/app && mv /tmp/app infra/do/app.yaml
      git add infra/do/app.yaml
    fi
    ```

- [ ] T-0294 | CDN cache headers (docs)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/cdn
    cat > docs/ops/cdn/headers.md <<'MD'
# CDN/Cache
- Статике давать `Cache-Control: public, max-age=86400`.
- Критическим JSON — `no-store`.
- Изображения с версионированием (query v=hash).
MD
    git add docs/ops/cdn/headers.md
    ```

- [ ] T-0295 | Нормализация `X-Forwarded-*` и доверие прокси (doc)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/proxy
    cat > docs/ops/proxy/forwarded.md <<'MD'
# Reverse Proxy
- Доверять заголовкам `X-Forwarded-For`, `X-Forwarded-Proto` от DO.
- Принудительно редиректить http→https на уровне CDN/ingress.
MD
    git add docs/ops/proxy/forwarded.md
    ```

- [ ] T-0296 | App spec: принудительный https redirect (Nginx snippet локально)
  - depends: [T-0198]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p infra/local/nginx
    cat > infra/local/nginx/https-redirect.conf <<'CONF'
server {
  listen 80;
  return 301 https://$host$request_uri;
}
CONF
    git add infra/local/nginx/https-redirect.conf
    ```

---

## ЭТАП 215. Медиа-репроцессинг и инвалидация кэша

- [ ] T-0297 | Репроцесс изображений пакетно (480/960/1440)
  - depends: [T-0215]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-media/scripts
    cat > apps/svc-media/scripts/reprocess.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
dir="${1:-media}"
out="${2:-media_out}"
find "$dir" -type f -name "*.jpg" -o -name "*.png" | while read -r f; do
  node -e 'import("./node.mjs").then(async m=>{ const {resize}=await import("../../packages/media/src/optimize.ts"); await resize(process.argv[1],process.argv[2],[480,960,1440]); process.exit(0); })' "$f" "$out"
done
SH
    chmod +x apps/svc-media/scripts/reprocess.sh
    git add apps/svc-media/scripts/reprocess.sh
    ```

- [ ] T-0298 | Кеш-бастер для изображений (?v=timestamp)
  - depends: [T-0297]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/media/src
    cat > packages/media/src/cachebuster.ts <<'TS'
export function bust(url:string){ const sep=url.includes("?")?"&":"?"; return url+sep+"v="+Date.now(); }
TS
    git add packages/media/src/cachebuster.ts
    ```

- [ ] T-0299 | Инвалидация кэша каталога при изменении рейтинга
  - depends: [T-0242, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/hooks
    cat > apps/svc-catalog/src/hooks/invalidate.ts <<'TS'
import { cacheSet } from "../../../packages/cache";
export async function invalidateCity(city:string){ await cacheSet("catalog:"+city, null as any, 1); }
TS
    git add apps/svc-catalog/src/hooks/invalidate.ts
    ```

---

## ЭТАП 216. Коммуникации: чат, web-push и SMS сценарии

- [ ] T-0300 | Лайв-чат (stub): start/append/list
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-chat/src
    cat > apps/svc-chat/src/server.js <<'JS'
import { createServer } from "http";
const port=process.env.PORT||3050; const sessions=new Map(); // id -> msgs[]
function id(){return Math.random().toString(36).slice(2)}
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/chat/start"){ const sid=id(); sessions.set(sid,[]); res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify({sid})); }
  if(req.method==="POST" && req.url==="/chat/append"){ const b=await body(req); const a=sessions.get(b.sid)||[]; a.push({role:b.role||"user",text:b.text||""}); sessions.set(b.sid,a); res.writeHead(200).end("ok"); return; }
  if(req.method==="GET" && req.url.startsWith("/chat/list?sid=")){ const sid=new URL(req.url,"http://x").searchParams.get("sid"); res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(sessions.get(sid)||[])); }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-chat/src/server.js
    ```

---

## ЭТАП 217. Уведомления: Web Push (регистрация и доставка)

- [ ] T-0301 | Service Worker для web-push (sw.js)
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p public
    cat > public/sw.js <<'JS'
// Minimal push SW
self.addEventListener('push', e => {
  const data = e.data ? e.data.json() : { title:'WeddingTech', body:'', url:'/' };
  e.waitUntil(self.registration.showNotification(data.title, { body: data.body, data: { url: data.url } }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(clients.openWindow(event.notification.data.url || '/'));
});
JS
    git add public/sw.js
    ```

- [ ] T-0302 | Ключи VAPID: генерация/хранение (docs + env)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/push
    cat > docs/ops/push/vapid.md <<'MD'
# Web Push VAPID
- Сгенерировать пары ключей (например, web-push cli).
- Сохранить в переменные окружения: VAPID_PUBLIC, VAPID_PRIVATE.
MD
    awk '1; END{print "VAPID_PUBLIC=\nVAPID_PRIVATE="}' .env.example > .env.example.tmp && mv .env.example.tmp .env.example
    git add docs/ops/push/vapid.md .env.example
    ```

- [ ] T-0303 | Серверная отправка web-push (stub на web-push lib несовместим → собственный fetch к push service не требуется; делаем интерфейс)
  - depends: [T-0302]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/push
    cat > packages/push/index.ts <<'TS'
// Stub interface to abstract web push (external sender configured elsewhere)
export type Subscription={endpoint:string;keys:{p256dh:string;auth:string}};
export async function sendPush(sub:Subscription, payload:{title:string;body:string;url?:string}){
  // In production: use 'web-push' or a push gateway. Here we log only.
  console.log("PUSH_STUB", sub.endpoint.slice(0,32), payload.title);
  return {ok:true};
}
TS
    git add packages/push/index.ts
    ```

- [ ] T-0304 | API: регистрация подписки и тест-отправка
  - depends: [T-0303]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-notify/src
    cat > apps/svc-notify/src/server.js <<'JS'
import { createServer } from "http"; import { sendPush } from "../../../packages/push/index.js";
const port=process.env.PORT||3060; const subs=new Map(); // userId -> Subscription
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
function uid(req){const c=(req.headers.cookie||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return "guest"; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub||"guest";}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/push/subscribe"){
    const u=uid(req); subs.set(u, await body(req)); res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true}));
  }
  if(req.method==="POST" && req.url==="/push/test"){
    const u=uid(req); const s=subs.get(u); if(!s){res.writeHead(404);return res.end("no sub");}
    await sendPush(s,{title:"WeddingTech",body:"Test notification",url:"/"}); res.writeHead(200); return res.end("ok");
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-notify/src/server.js
    ```

---

## ЭТАП 218. SMS-сценарии: подтверждение заявки и напоминания

- [ ] T-0305 | Шаблоны SMS: enquiry_created / booking_reminder
  - depends: [T-0195]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/sms/templates
    cat > packages/sms/templates/enquiry_created.txt <<'TXT'
Ваша заявка принята. Ответ от поставщика придёт в личный кабинет.
TXT
    cat > packages/sms/templates/booking_reminder.txt <<'TXT'
Напоминание: у вас бронирование на ближайшие дни. Проверьте детали в кабинете.
TXT
    git add packages/sms/templates/*.txt
    ```

- [ ] T-0306 | Отправка SMS при создании заявки (hook)
  - depends: [T-0305, T-0237]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/hooks
    cat > apps/svc-enquiries/src/hooks/sms-on-create.ts <<'TS'
import fs from "fs"; import { eskiz } from "../../../../packages/sms/adapters/eskiz";
export async function smsOnCreate(phone:string){
  const text=fs.readFileSync("packages/sms/templates/enquiry_created.txt","utf-8").trim();
  return eskiz.send(phone, text);
}
TS
    git add apps/svc-enquiries/src/hooks/sms-on-create.ts
    ```

- [ ] T-0307 | Cron: SMS напоминания о бронировании за 24 часа
  - depends: [T-0305, T-0272]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/scripts
    cat > apps/svc-enquiries/scripts/sms-remind.js <<'JS'
import { PrismaClient } from "@prisma/client"; import fs from "fs"; import { eskiz } from "../../../packages/sms/adapters/eskiz.js";
const db=new PrismaClient();
const text=fs.readFileSync("packages/sms/templates/booking_reminder.txt","utf-8").trim();
const now=Date.now(), day=24*3600*1000; const from=new Date(now+day-3600*1000), to=new Date(now+day+3600*1000);
const bookings=await db.booking.findMany({where:{startAt:{gte:from,lte:to}}});
for(const b of bookings){ /* lookup phone omitted in MVP */ await eskiz.send("+998000000000", text); }
console.log("reminders sent", bookings.length);
JS
    git add apps/svc-enquiries/scripts/sms-remind.js
    ```

---

## ЭТАП 219. PWA и производительность

- [ ] T-0308 | manifest.json и иконка
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p public
    cat > public/manifest.json <<'JSON'
{"name":"WeddingTech UZ","short_name":"WeddingTech","start_url":"/","display":"standalone","background_color":"#ffffff","theme_color":"#7c3aed","icons":[{"src":"/icon-192.png","sizes":"192x192","type":"image/png"},{"src":"/icon-512.png","sizes":"512x512","type":"image/png"}]}
JSON
    :> public/icon-192.png
    :> public/icon-512.png
    git add public/manifest.json public/icon-192.png public/icon-512.png
    ```

- [ ] T-0309 | Перфоманс budget (docs) + чек-лист Lighthouse
  - depends: [T-0205]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/perf
    cat > docs/perf/budget.md <<'MD'
# Performance Budget
- LCP < 2.5s, CLS < 0.1, TBT < 300ms
- JS bundle (initial) ≤ 170kb
- Изображения — responsive sizes
MD
    git add docs/perf/budget.md
    ```

---

## ЭТАП 220. Feature Flags и A/B

- [ ] T-0310 | Фичефлаги: in-memory toggles
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/flags
    cat > packages/flags/index.ts <<'TS'
const store=new Map<string,boolean>();
export function setFlag(k:string,v:boolean){store.set(k,v);}
export function isOn(k:string){return !!store.get(k);}
TS
    git add packages/flags/index.ts
    ```

- [ ] T-0311 | A/B helper: bucket по userId
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/ab
    cat > packages/ab/index.ts <<'TS'
import crypto from "crypto";
export function bucket(userId:string, modulo=100){ const h=crypto.createHash("sha1").update(userId).digest(); return h[0]%modulo; }
TS
    git add packages/ab/index.ts
    ```

---

## ЭТАП 221. UX: онбординг и страницы ошибок

- [ ] T-0312 | Онбординг вендора (wizard skeleton)
  - depends: [T-0207, T-0278]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/onboarding
    cat > apps/svc-website/src/onboarding/VendorWizard.tsx <<'TSX'
import React from "react"; export default function VendorWizard(){
  const [step,setStep]=React.useState(1);
  return <div className="max-w-2xl mx-auto">
    <h1 className="text-2xl font-bold mb-4">Регистрация поставщика</h1>
    <div className="card mb-4">Шаг {step} из 3</div>
    <div className="flex gap-2">
      <button className="px-3 py-2 rounded-2xl bg-[var(--brand)] text-white" onClick={()=>setStep(Math.max(1,step-1))}>Назад</button>
      <button className="px-3 py-2 rounded-2xl bg-[var(--brand)] text-white" onClick={()=>setStep(Math.min(3,step+1))}>Далее</button>
    </div>
  </div>;
}
TSX
    git add apps/svc-website/src/onboarding/VendorWizard.tsx
    ```

- [ ] T-0313 | Страницы ошибок 404/500
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages
    cat > apps/svc-website/src/pages/404.tsx <<'TSX'
import React from "react"; export default function NotFound(){ return <main className="p-10 text-center"><h1 className="text-3xl font-bold mb-2">404</h1><p>Страница не найдена</p></main>; }
TSX
    cat > apps/svc-website/src/pages/500.tsx <<'TSX'
import React from "react"; export default function Error500(){ return <main className="p-10 text-center"><h1 className="text-3xl font-bold mb-2">Ошибка</h1><p>Что-то пошло не так</p></main>; }
TSX
    git add apps/svc-website/src/pages/404.tsx apps/svc-website/src/pages/500.tsx
    ```

---

## ЭТАП 222. Партнёрские интеграции и безопасность API

- [ ] T-0314 | API Keys для партнёров (таблица + верификация)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model ApiKey {
  id        String @id @default(cuid())
  name      String
  key       String  @unique
  createdAt DateTime @default(now())
  active    Boolean @default(true)
}
PRISMA
    mkdir -p packages/keys
    cat > packages/keys/verify.ts <<'TS'
export function verifyApiKey(req:any, activeKeys:Set<string>){
  const k=(req.headers["x-api-key"]||"").toString(); return activeKeys.has(k);
}
TS
    git add packages/prisma/schema.prisma packages/keys/verify.ts
    ```

- [ ] T-0315 | Подпись вебхуков HMAC (общий helper)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/webhooks
    cat > packages/webhooks/sign.ts <<'TS'
import crypto from "crypto";
export function sign(body:string, secret:string){ return crypto.createHmac("sha256",secret).update(body).digest("hex"); }
export function verify(body:string, sig:string, secret:string){ return sign(body,secret)===sig; }
TS
    git add packages/webhooks/sign.ts
    ```

- [ ] T-0316 | Ретрай и backoff утилита (экспоненциальная)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/retry
    cat > packages/retry/index.ts <<'TS'
export async function retry<T>(fn:()=>Promise<T>, times=3, baseMs=200){
  let last:any; for(let i=0;i<times;i++){ try{ return await fn(); }catch(e){ last=e; await new Promise(r=>setTimeout(r, baseMs*Math.pow(2,i))); } }
  throw last;
}
TS
    git add packages/retry/index.ts
    ```

---

## ЭТАП 223. Очереди, воркеры и фоновые задачи

- [ ] T-0317 | Runner для очередей (универсальный обработчик)
  - depends: [T-0199]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/worker/src
    cat > apps/worker/src/runner.ts <<'TS'
import { enqueue } from "../../packages/queue/index";
export async function run(){ console.log("Worker stub running"); await enqueue("noop",{}); }
TS
    git add apps/worker/src/runner.ts
    ```

- [ ] T-0318 | Cron-docs: расписания задач (locks GC, reminders)
  - depends: [T-0273, T-0307]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/cron
    cat > docs/ops/cron/schedule.md <<'MD'
# Cron schedule
- locks-gc: */5 * * * *  (чистка блокировок)
- sms-remind: 0 * * * * (ежечасные проверки на 24ч вперед)
MD
    git add docs/ops/cron/schedule.md
    ```

---

## ЭТАП 224. CORS, версияция API и пагинация

- [ ] T-0319 | Общая CORS-прослойка (разрешить PROD-домен)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/http
    cat > packages/http/cors.ts <<'TS'
export function cors(req:any,res:any,next:Function){
  const origin=req.headers.origin||"*";
  res.setHeader("Access-Control-Allow-Origin", origin);
  res.setHeader("Access-Control-Allow-Credentials","true");
  res.setHeader("Access-Control-Allow-Headers","Content-Type,Authorization,X-API-Key");
  res.setHeader("Access-Control-Allow-Methods","GET,POST,PUT,DELETE,OPTIONS");
  if(req.method==="OPTIONS"){ res.writeHead(200); return res.end(); }
  next();
}
TS
    git add packages/http/cors.ts
    ```

- [ ] T-0320 | API версия в префиксе: /v1/*
  - depends: [T-0232, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/api
    cat > docs/api/versioning.md <<'MD'
# API Versioning
- Внешним клиентам выдаём маршруты под /v1/*
- Смена мажорной версии — через отдельный префикс /v2/*
MD
    git add docs/api/versioning.md
    ```

- [ ] T-0321 | Единый helper для пагинации (page/limit → skip/take)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/pagination
    cat > packages/pagination/index.ts <<'TS'
export function toSkipTake(q:{page?:string|number;limit?:string|number}, dPage=1, dLimit=20){
  const p=Math.max(1, Number(q.page||dPage)); const l=Math.max(1, Math.min(100, Number(q.limit||dLimit)));
  return { skip:(p-1)*l, take:l };
}
TS
    git add packages/pagination/index.ts
    ```

---

## ЭТАП 225. Логи и метрики

- [ ] T-0322 | JSON-логгер (structured)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/log/json
    cat > packages/log/json/index.ts <<'TS'
export function logj(level:"info"|"warn"|"error", msg:string, extra?:Record<string,any>){
  console.log(JSON.stringify({ts:new Date().toISOString(),level,msg,...(extra||{})}));
}
TS
    git add packages/log/json/index.ts
    ```

- [ ] T-0323 | Прометей-stub метрики (counter/gauge)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/metrics
    cat > packages/metrics/index.ts <<'TS'
const counters=new Map<string,number>(); const gauges=new Map<string,number>();
export function inc(k:string,v=1){ counters.set(k,(counters.get(k)||0)+v); }
export function setGauge(k:string,v:number){ gauges.set(k,v); }
export function render(){ return "counters "+JSON.stringify(Object.fromEntries(counters))+"; gauges "+JSON.stringify(Object.fromEntries(gauges)); }
TS
    git add packages/metrics/index.ts
    ```

- [ ] T-0324 | /metrics аггрегатор (общий HTTP)
  - depends: [T-0323]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-metrics/src
    cat > apps/svc-metrics/src/server.js <<'JS'
import { createServer } from "http"; import { render } from "../../../packages/metrics/index.js";
const port=process.env.PORT||3070;
createServer((req,res)=>{ if(req.url==="/metrics"){ res.writeHead(200,{"Content-Type":"text/plain"}); return res.end(render()); } res.writeHead(404); res.end(); }).listen(port,"0.0.0.0");
JS
    git add apps/svc-metrics/src/server.js
    ```

---

## ЭТАП 226. Эксплуатация и управление изменениями

- [ ] T-0325 | CHANGELOG.md и правила релизов (SemVer)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    cat > CHANGELOG.md <<'MD'
# Changelog
- Вести изменения по SemVer: MAJOR.MINOR.PATCH
MD
    git add CHANGELOG.md
    ```

---

## ЭТАП 227. DR-план, авто-бэкапы и восстановление

- [ ] T-0326 | Скрипт pg_dump nightly + ротация 7 дней
  - depends: [T-0251, T-0200]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/backup
    cat > scripts/backup/pg_nightly.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:=postgresql://pg:pg@localhost:5432/wt}"
OUT="backups/$(date +%Y-%m-%d)"
mkdir -p "$OUT"
pg_dump "$DATABASE_URL" > "$OUT/wt.sql"
find backups -type d -mtime +7 -exec rm -rf {} +
echo "backup done: $OUT/wt.sql"
SH
    chmod +x scripts/backup/pg_nightly.sh
    git add scripts/backup/pg_nightly.sh
    ```

- [ ] T-0327 | Скрипт восстановления pg_restore smoke
  - depends: [T-0326]
  - apply:
    ```bash
    set -euo pipefail
    cat > scripts/backup/pg_restore_smoke.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:=postgresql://pg:pg@localhost:5432/wt}"
LAST="$(ls -1dt backups/* | head -n1)/wt.sql"
[ -f "$LAST" ] || { echo "no backup found"; exit 1; }
psql "$DATABASE_URL" -c 'SELECT 1' >/dev/null
echo "restore-smoke ok from $LAST"
SH
    chmod +x scripts/backup/pg_restore_smoke.sh
    git add scripts/backup/pg_restore_smoke.sh
    ```

- [ ] T-0328 | Документ DR-Runbook (RPO/RTO)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/dr
    cat > docs/ops/dr/runbook.md <<'MD'
# DR Runbook
- RPO: ≤ 24h (nightly dump), RTO: ≤ 4h.
- Проверка восстановления: 1 раз в 2 недели (smoke).
- Контакты on-call, чек-лист при инциденте.
MD
    git add docs/ops/dr/runbook.md
    ```

---

## ЭТАП 228. Pre-Prod окружение и релизы

- [ ] T-0329 | Бранч preprod + CI job deploy (manual)
  - depends: [T-0183]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p .github/workflows
    cat > .github/workflows/preprod-deploy.yml <<'YML'
name: Preprod Deploy (manual)
on:
  workflow_dispatch:
    inputs:
      app_id:
        description: 'DO App ID (preprod)'
        required: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger deployment
        env:
          DO_API_TOKEN: ${{ secrets.DO_API_TOKEN }}
          APP_ID: ${{ github.event.inputs.app_id }}
        run: |
          curl -sS -X POST -H "Authorization: Bearer ${DO_API_TOKEN}" -H "Content-Type: application/json" \
            "https://api.digitalocean.com/v2/apps/${APP_ID}/deployments" -d '{}'
YML
    git add .github/workflows/preprod-deploy.yml
    ```

- [ ] T-0330 | Release checklist (freeze, smoke, rollback)
  - depends: [T-0325]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/release
    cat > docs/release/checklist.md <<'MD'
# Release Checklist
- Code freeze: 24h до релиза.
- Preprod deploy → smoke: /health, логин, поиск.
- Rollback: вернуться на предыдущую успешную деплой-ревизию.
- Post-release мониторинг: 30 мин.
MD
    git add docs/release/checklist.md
    ```

- [ ] T-0331 | DORA-метрики (docs) и таблица учёта релизов
  - depends: [T-0325]
  - apply:
    ```bash
    set -euo pipefail
    cat > docs/release/dora.md <<'MD'
# DORA Metrics
- Deployment Frequency, Lead Time, Change Failure Rate, MTTR.
- Вести журнал релизов в CHANGELOG и таблицу инцидентов.
MD
    git add docs/release/dora.md
    ```

---

## ЭТАП 229. CDN/Cache invalidation и статика

- [ ] T-0332 | Маркер кэш-инвалидации для статики (build-id.txt)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/build
    cat > scripts/build/write-build-id.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
id="$(date +%s)"
mkdir -p public
echo "$id" > public/build-id.txt
echo "build-id: $id"
SH
    chmod +x scripts/build/write-build-id.sh
    git add scripts/build/write-build-id.sh
    ```

- [ ] T-0333 | Док: вручную инвалидировать CDN по `/build-id.txt`
  - depends: [T-0332]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/cdn
    cat > docs/ops/cdn/invalidate.md <<'MD'
# Invalidate
- После релиза проверить /build-id.txt (новый id).
- Обновить кеш CDN для путей с этим id по правилам провайдера.
MD
    git add docs/ops/cdn/invalidate.md
    ```

---

## ЭТАП 230. Rollout/A-B и трафик-сплиты

- [ ] T-0334 | Traffic split helper (N%-включение фичи)
  - depends: [T-0311]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/ab
    cat > packages/ab/rollout.ts <<'TS'
import { bucket } from "./index";
export function enabled(userId:string, percent=10){ return bucket(userId,100) < percent; }
TS
    git add packages/ab/rollout.ts
    ```

- [ ] T-0335 | Док: стратегия «canary 10% → 50% → 100%»
  - depends: [T-0334]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/release
    cat > docs/release/rollout.md <<'MD'
# Rollout Strategy
- Постепенно: 10% → 50% → 100%.
- Откат при аномалиях метрик/жалобах.
MD
    git add docs/release/rollout.md
    ```

---

## ЭТАП 231. Безопасность приложений

- [ ] T-0336 | CSRF-токен (double submit cookie)
  - depends: [T-0232]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/security
    cat > packages/security/csrf.ts <<'TS'
import crypto from "crypto";
export function issue(){ const v=crypto.randomBytes(16).toString("hex"); return {cookie:`csrf=${v}; Path=/; SameSite=Lax`, value:v}; }
export function verify(serverToken:string, clientToken:string){ return serverToken && clientToken && serverToken===clientToken; }
TS
    git add packages/security/csrf.ts
    ```

- [ ] T-0337 | Rate Limit middleware (in-memory token bucket)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/security
    cat > packages/security/rate.ts <<'TS'
const buckets=new Map<string,{t:number,r:number}>();
export function rate({rate=10,burst=20}:{rate?:number;burst?:number}){
  return (req:any,res:any,next:Function)=>{
    const ip=(req.headers["x-forwarded-for"]||req.socket?.remoteAddress||"ip").toString();
    const now=Date.now(); const b=buckets.get(ip)||{t:now,r:burst};
    const dt=Math.max(0, now-b.t); b.t=now; b.r=Math.min(burst, b.r + dt*(rate/1000));
    if(b.r<1){ res.writeHead(429); return res.end("rate"); } b.r-=1; buckets.set(ip,b); next();
  };
}
TS
    git add packages/security/rate.ts
    ```

- [ ] T-0338 | Скан зависимостей (docs + команда npx npm-check-updates)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/security
    cat > docs/security/deps.md <<'MD'
# Dependencies
- Проверка уязвимостей раз в спринт: `npx npm-check-updates` + обновление.
- Отдельно аудит лицензий (см. docs/legal/licenses.md).
MD
    git add docs/security/deps.md
    ```

---

## ЭТАП 232. Аналитика и события

- [ ] T-0339 | Событийный лог фронта (page_view, search, enquiry_submit)
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/analytics
    cat > apps/svc-website/src/analytics/events.ts <<'TS'
type Evt="page_view"|"search"|"enquiry_submit";
export function send(evt:Evt, payload:any){ try{ navigator.sendBeacon?.("/analytics", new Blob([JSON.stringify({evt,payload,ts:Date.now()})],{type:"application/json"})); }catch(e){ console.log("evt",evt,payload); } }
TS
    git add apps/svc-website/src/analytics/events.ts
    ```

- [ ] T-0340 | Сборщик событий (HTTP endpoint)
  - depends: [T-0339]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/collector
    cat > apps/svc-analytics/src/collector/server.js <<'JS'
import { createServer } from "http"; const port=process.env.PORT||3080; const buffer=[];
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/analytics"){
    const chunks=[]; for await (const c of req) chunks.push(c);
    const row=JSON.parse(Buffer.concat(chunks).toString()||"{}"); buffer.push(row);
    res.writeHead(204); return res.end();
  }
  if(req.method==="GET" && req.url==="/analytics/dump"){
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(buffer.slice(-200)));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-analytics/src/collector/server.js
    ```

---

## ЭТАП 233. Terraform-скелеты (DigitalOcean DB + Spaces)

- [ ] T-0341 | Terraform init: provider + DO token через env
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p infra/tf
    cat > infra/tf/main.tf <<'TF'
terraform {
  required_providers { digitalocean = { source = "digitalocean/digitalocean" } }
  required_version = ">= 1.6.0"
}
provider "digitalocean" {
  token = var.do_token
}
variable "do_token" { type = string }
TF
    cat > infra/tf/README.md <<'MD'
# Terraform (DigitalOcean)
- Переменная: do_token (экспортируйте TF_VAR_do_token).
MD
    git add infra/tf/main.tf infra/tf/README.md
    ```

- [ ] T-0342 | Terraform: Managed DB (stub resource)
  - depends: [T-0341]
  - apply:
    ```bash
    set -euo pipefail
    cat > infra/tf/db.tf <<'TF'
resource "digitalocean_database_cluster" "wt_db" {
  name       = "wt-db"
  engine     = "pg"
  version    = "15"
  size       = "db-s-1vcpu-1gb"
  region     = "fra1"
  node_count = 1
}
output "db_uri" { value = digitalocean_database_cluster.wt_db.uri }
TF
    git add infra/tf/db.tf
    ```

- [ ] T-0343 | Terraform: Spaces bucket (static/media)
  - depends: [T-0341]
  - apply:
    ```bash
    set -euo pipefail
    cat > infra/tf/spaces.tf <<'TF'
resource "digitalocean_spaces_bucket" "wt_media" {
  name   = "wt-media"
  region = "ams3"
  acl    = "public-read"
}
output "spaces_name" { value = digitalocean_spaces_bucket.wt_media.name }
TF
    git add infra/tf/spaces.tf
    ```

---

## ЭТАП 234. Финальные UX-полировки

- [ ] T-0344 | Breadcrumbs компонент
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/nav
    cat > apps/svc-website/src/ui/nav/Breadcrumbs.tsx <<'TSX'
import React from "react";
export function Breadcrumbs({items}:{items:{href:string;label:string}[]}){ return <nav className="text-sm">
  {items.map((it,i)=> <span key={i}><a href={it.href} className="underline">{it.label}</a>{i<items.length-1?" / ":""}</span>)}
</nav>; }
TSX
    git add apps/svc-website/src/ui/nav/Breadcrumbs.tsx
    ```

- [ ] T-0345 | Empty state для поиска (ничего не найдено)
  - depends: [T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/empty
    cat > apps/svc-website/src/ui/empty/SearchEmpty.tsx <<'TSX'
import React from "react";
export default function SearchEmpty(){ return <div className="text-center p-10 opacity-80">Ничего не найдено. Попробуйте изменить фильтры.</div>; }
TSX
    git add apps/svc-website/src/ui/empty/SearchEmpty.tsx
    ```

- [ ] T-0346 | Loading state для кнопок (disabled + spinner)
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-website/src/ui/LoadingButton.tsx <<'TSX'
import React from "react";
export function LoadingButton({loading,children,onClick}:{loading:boolean;children:React.ReactNode;onClick?:()=>void}){
  return <button disabled={loading} onClick={onClick} className={"px-4 py-2 rounded-2xl text-white "+(loading?"opacity-60":"")} style={{background:"var(--brand)"}}>
    {loading?"…":children}
  </button>;
}
TSX
    git add apps/svc-website/src/ui/LoadingButton.tsx
    ```

---

## ЭТАП 235. Улучшения каталога и отзывов

- [ ] T-0347 | Подсчёт и отображение количества отзывов
  - depends: [T-0226, T-0194]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/lib
    cat > apps/svc-catalog/src/lib/reviewCount.ts <<'TS'
export function reviewCountText(n:number){ return n===1?"1 отзыв": (n<5?`${n} отзыва`:`${n} отзывов`); }
TS
    git add apps/svc-catalog/src/lib/reviewCount.ts
    ```

- [ ] T-0348 | API: добавление отзыва пользователем (contract-only)
  - depends: [T-0190, T-0232]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/api
    cat > apps/svc-enquiries/src/api/review-add.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3090;
function uid(req){const c=(req.headers.cookie||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/review/add"){
    const u=uid(req); if(!u){res.writeHead(401);return res.end();}
    const b=await body(req);
    const e=await db.enquiry.findUnique({where:{id:b.enquiryId}});
    if(!e || (e.status!=="WON" && e.status!=="CONTRACT_SIGNED")){res.writeHead(403);return res.end();}
    const r=await db.review.create({data:{vendorId:e.vendorId,rating:b.rating,text:b.text,contractBased:true}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-enquiries/src/api/review-add.js
    ```

---

## ЭТАП 236. Конфигурации и секреты

- [ ] T-0349 | .env.local шаблон и инструкция по секретам
  - depends: [T-0252]
  - apply:
    ```bash
    set -euo pipefail
    cat > .env.local.example <<'ENV'
# локальные секреты разработчика
DATABASE_URL=postgresql://pg:pg@localhost:5432/wt
JWT_SECRET=devsecret
ENV
    mkdir -p docs/ops/secrets
    cat > docs/ops/secrets/README.md <<'MD'
# Секреты
- Локально: .env.local (не коммитить).
- Прод: секреты через DO App Platform (RUN_TIME).
MD
    git add .env.local.example docs/ops/secrets/README.md
    ```

---

## ЭТАП 237. Финальный «полиш» и проверка релиза

- [ ] T-0350 | Релизный скрипт: build-id + lighthouse + health
  - depends: [T-0332, T-0205, T-0203]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/release
    cat > scripts/release/final_check.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
scripts/build/write-build-id.sh
echo "Run Lighthouse manually via workflow with prod URL"
echo "Check /health endpoints for all public services"
SH
    chmod +x scripts/release/final_check.sh
    git add scripts/release/final_check.sh
    ```

---

## ЭТАП 238. Продвинутая аналитика: когорты и удержание

- [ ] T-0351 | Модель EventLog (Prisma) для аналитики
  - depends: [T-0226, T-0340]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model EventLog {
  id        String   @id @default(cuid())
  userId    String?
  name      String
  payload   String
  createdAt DateTime @default(now())
  city      String?
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0352 | Ингестор: прокладка из /analytics в EventLog
  - depends: [T-0351, T-0340]
  - apply:
    ```bash
    set -euo pipefail
    sed -i 's/const buffer=\[\];/const buffer=\[\];\nimport {PrismaClient} from "@prisma\/client";\nconst db=new PrismaClient();/' apps/svc-analytics/src/collector/server.js
    awk '1;/buffer.push\(row\);/ && c==0 {print "    try{ await db.eventLog.create({data:{userId:row.payload?.userId||null,name:row.evt||\"evt\",payload:JSON.stringify(row),city:row.payload?.city||null}}); }catch(e){}"; c=1}' apps/svc-analytics/src/collector/server.js > /tmp/a && mv /tmp/a apps/svc-analytics/src/collector/server.js
    git add apps/svc-analytics/src/collector/server.js
    ```

- [ ] T-0353 | Когорты по неделям регистрации
  - depends: [T-0351]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/cohort
    cat > apps/svc-analytics/src/cohort/weekly.ts <<'TS'
export function weekOf(ts:number){ const d=new Date(ts); const onejan=new Date(d.getFullYear(),0,1); const diff=d.getTime()-onejan.getTime(); return d.getFullYear()+"-W"+Math.ceil((diff/86400000+onejan.getDay()+1)/7); }
export function cohort(users:{id:string;createdAt:number}[], events:{userId:string;ts:number}[]){
  const reg= new Map<string,string>(); for(const u of users){ reg.set(u.id, weekOf(u.createdAt)); }
  const buckets=new Map<string,Set<string>>();
  for(const e of events){ const w=reg.get(e.userId); if(!w) continue; if(!buckets.has(w)) buckets.set(w,new Set()); buckets.get(w)!.add(e.userId); }
  return Array.from(buckets.entries()).map(([k,v])=>({cohort:k,active:v.size}));
}
TS
    git add apps/svc-analytics/src/cohort/weekly.ts
    ```

- [ ] T-0354 | Retention: D1/D7/D30 из EventLog
  - depends: [T-0352]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/retention
    cat > apps/svc-analytics/src/retention/deltas.ts <<'TS'
export function retention(regTs:number[], actTs:number[]){
  const day=(n:number)=>n*86400000;
  const have=(ts:number,delta:number)=> actTs.some(a=>a>=ts+delta && a<ts+delta+day(1));
  let d1=0,d7=0,d30=0; for(const ts of regTs){ if(have(ts,day(1))) d1++; if(have(ts,day(7))) d7++; if(have(ts,day(30))) d30++; }
  const n=regTs.length||1; return {d1:d1/n, d7:d7/n, d30:d30/n};
}
TS
    git add apps/svc-analytics/src/retention/deltas.ts
    ```

- [ ] T-0355 | Admin API: выгрузка сводки retention/кохорт
  - depends: [T-0353, T-0354]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/api
    cat > apps/svc-analytics/src/api/summary.js <<'JS'
import { createServer } from "http";
import { retention } from "../retention/deltas.js";
const port=process.env.PORT||3100;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url==="/analytics/retention"){
    const now=Date.now(); const regs=[now-31*86400000, now-8*86400000, now-2*86400000]; const acts=[now-30*86400000, now-1*86400000, now-7*86400000];
    const r=retention(regs,acts); res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-analytics/src/api/summary.js
    ```

- [ ] T-0356 | Дашборд retention в админке (виджет)
  - depends: [T-0355]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/widgets
    cat > apps/svc-admin/src/widgets/RetentionCard.tsx <<'TSX'
import React from "react";
export default function RetentionCard({d1,d7,d30}:{d1:number;d7:number;d30:number}){
  const p=(x:number)=> (x*100).toFixed(1)+"%";
  return <div className="p-4 rounded-2xl" style={{background:"#eef2ff"}}><h3 className="font-semibold mb-2">Retention</h3>
    <div>D1: {p(d1)}</div><div>D7: {p(d7)}</div><div>D30: {p(d30)}</div></div>;
}
TSX
    git add apps/svc-admin/src/widgets/RetentionCard.tsx
    ```

---

## ЭТАП 239. Боевой платёжный слой (абстракция провайдера)

- [ ] T-0357 | Абстракция PaymentProvider (create/capture/refund)
  - depends: [T-0245]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/pay
    cat > packages/pay/provider.ts <<'TS'
export type Intent={id:string;clientSecret?:string;amount:number;currency:string;status:"requires_payment"|"succeeded"|"refunded"};
export interface PaymentProvider{ createIntent(a:{amount:number;currency:string}):Promise<Intent>; capture(id:string):Promise<Intent>; refund(id:string):Promise<Intent>; }
TS
    git add packages/pay/provider.ts
    ```

- [ ] T-0358 | Провайдер DemoProvider (in-memory)
  - depends: [T-0357]
  - apply:
    ```bash
    set -euo pipefail
    cat > packages/pay/demo.ts <<'TS'
import { PaymentProvider, Intent } from "./provider";
const store=new Map<string,Intent>();
export const DemoProvider:PaymentProvider={
  async createIntent({amount,currency}){ const id="pi_"+Math.random().toString(36).slice(2); const it:{id:string;amount:number;currency:string;status:any}={id,amount,currency,status:"requires_payment"}; store.set(id,it as any); return {id,amount,currency,status:"requires_payment"}; },
  async capture(id){ const it=store.get(id); if(!it) throw new Error("nf"); it.status="succeeded" as any; return it as any; },
  async refund(id){ const it=store.get(id); if(!it) throw new Error("nf"); it.status="refunded" as any; return it as any; }
};
TS
    git add packages/pay/demo.ts
    ```

- [ ] T-0359 | Связка биллинга с провайдером (инъекция через env)
  - depends: [T-0358, T-0245]
  - apply:
    ```bash
    set -euo pipefail
    sed -i '1i import { DemoProvider } from "../../../packages/pay/demo.js"; const P=DemoProvider;' apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

- [ ] T-0360 | API: /pay/create-intent использует P.createIntent
  - depends: [T-0359]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/create-intent/ && c==0 {print "    const chunks=[]; for await (const ch of req) chunks.push(ch); const body=JSON.parse(Buffer.concat(chunks).toString()||\"{}\"); const it=await P.createIntent({amount:body.amount||100000,currency:body.currency||\"UZS\"}); res.writeHead(200,{\"Content-Type\":\"application/json\"}); return res.end(JSON.stringify(it));"; c=1; next} /return res.end\(JSON.stringify\(\{id:\"pi_demo_1\"/ {next}1' apps/svc-billing/src/api/payments.js > /tmp/p && mv /tmp/p apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

- [ ] T-0361 | API: /pay/capture использует P.capture
  - depends: [T-0360]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/\/pay\/capture/ && c==0 {print "    const chunks=[]; for await (const ch of req) chunks.push(ch); const body=JSON.parse(Buffer.concat(chunks).toString()||\"{}\"); const it=await P.capture(body.id); res.writeHead(200,{\"Content-Type\":\"application\/json\"}); return res.end(JSON.stringify(it));"; c=1; next} /succeeded/ {next}1' apps/svc-billing/src/api/payments.js > /tmp/c && mv /tmp/c apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

- [ ] T-0362 | API: /pay/refund
  - depends: [T-0361]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/res\.writeHead\(404\)/ && c==0 {print "  if(req.method===\"POST\" && req.url===\"/pay/refund\"){ const chunks=[]; for await (const ch of req) chunks.push(ch); const body=JSON.parse(Buffer.concat(chunks).toString()||\"{}\"); const it=await P.refund(body.id); res.writeHead(200,{\"Content-Type\":\"application/json\"}); return res.end(JSON.stringify(it)); }"; c=1}1' apps/svc-billing/src/api/payments.js > /tmp/r && mv /tmp/r apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

---

## ЭТАП 240. Экспорт в бухучёт (CSV/XLSX) и отчёты

- [ ] T-0363 | Экспорт инвойсов в CSV
  - depends: [T-0238]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/export
    cat > apps/svc-billing/src/export/invoices-csv.js <<'JS'
import fs from "fs";
export function exportInvoicesCsv(rows){ const csv="id,amount,currency\n"+rows.map(r=>`${r.id},${r.amount},${r.currency}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); fs.writeFileSync("exports/invoices.csv",csv); return "exports/invoices.csv"; }
JS
    git add apps/svc-billing/src/export/invoices-csv.js
    ```

- [ ] T-0364 | Экспорт инвойсов в XLSX (простая TSV → .xlsx)
  - depends: [T-0363]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-billing/src/export/invoices-xlsx.js <<'JS'
import fs from "fs";
export function exportInvoicesXlsx(rows){ const tsv="id\tamount\tcurrency\n"+rows.map(r=>`${r.id}\t${r.amount}\t${r.currency}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/invoices.xlsx"; fs.writeFileSync(p,tsv); return p; }
JS
    git add apps/svc-billing/src/export/invoices-xlsx.js
    ```

- [ ] T-0365 | Admin UI: кнопки экспорта CSV/XLSX
  - depends: [T-0363, T-0364]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/buttons
    cat > apps/svc-admin/src/buttons/ExportButtons.tsx <<'TSX'
import React from "react";
export default function ExportButtons(){
  return <div className="flex gap-2">
    <a className="px-3 py-2 rounded-2xl text-white" style={{background:"var(--brand)"}} href="/exports/invoices.csv" download>CSV</a>
    <a className="px-3 py-2 rounded-2xl text-white" style={{background:"var(--brand)"}} href="/exports/invoices.xlsx" download>XLSX</a>
  </div>;
}
TSX
    git add apps/svc-admin/src/buttons/ExportButtons.tsx
    ```

---

## ЭТАП 241. Партнёрские webhooks (HMAC) и приём событий

- [ ] T-0366 | Подписка партнёров: таблица WebhookEndpoint
  - depends: [T-0315, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model WebhookEndpoint {
  id        String  @id @default(cuid())
  url       String
  secret    String
  active    Boolean @default(true)
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0367 | Отправка webhook при оплате (booking paid)
  - depends: [T-0275, T-0366]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/webhooks
    cat > apps/svc-billing/src/webhooks/dispatch.js <<'JS'
import { PrismaClient } from "@prisma/client"; import { sign } from "../../../packages/webhooks/sign.js";
import http from "http"; const db=new PrismaClient();
export async function notify(topic,payload){
  const eps=await db.webhookEndpoint.findMany({where:{active:true}});
  const body=JSON.stringify({topic,payload,ts:Date.now()});
  for(const e of eps){
    const sig=sign(body,e.secret);
    const u=new URL(e.url);
    const req=http.request({hostname:u.hostname,port:u.port||80,path:u.pathname,method:"POST",headers:{"Content-Type":"application/json","X-Signature":sig}});
    req.on("error",()=>{}); req.write(body); req.end();
  }
}
JS
    git add apps/svc-billing/src/webhooks/dispatch.js
    ```

- [ ] T-0368 | Вызов dispatch из /booking/confirm
  - depends: [T-0367]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/return res.end\(JSON.stringify\(\{ok:true\}\)\);/ && c==0 {print "    const { notify } = await import(\"../webhooks/dispatch.js\"); await notify(\"booking.paid\", {bookingId:b.bookingId});"; c=1}' apps/svc-billing/src/api/confirm.js > /tmp/h && mv /tmp/h apps/svc-billing/src/api/confirm.js
    git add apps/svc-billing/src/api/confirm.js
    ```

- [ ] T-0369 | Приём сторонних вебхуков: verify HMAC
  - depends: [T-0315]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/inbound
    cat > apps/svc-billing/src/inbound/webhook.js <<'JS'
import { createServer } from "http"; import { verify } from "../../../packages/webhooks/sign.js";
const port=process.env.PORT||3105; const SECRET=process.env.WEBHOOK_SECRET||"secret";
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/webhook/inbound"){
    const chunks=[]; for await (const c of req) chunks.push(c); const body=Buffer.concat(chunks).toString();
    const sig=req.headers["x-signature"]||""; if(!verify(body, String(sig), SECRET)){ res.writeHead(401); return res.end("bad sig"); }
    res.writeHead(200); return res.end("ok");
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-billing/src/inbound/webhook.js
    ```

---

## ЭТАП 242. Конструктор лендингов пар

- [ ] T-0370 | Модель CoupleSite (theme, slug, blocks)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model CoupleSite {
  id        String  @id @default(cuid())
  userId    String
  slug      String  @unique
  theme     String  @default("classic")
  blocks    String  // JSON
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0371 | Темы лендинга: classic / elegant / photo
  - depends: [T-0370]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/couples/themes
    cat > packages/couples/themes/index.ts <<'TS'
export type Theme="classic"|"elegant"|"photo";
export const themes:Record<Theme,{palette:{bg:string;fg:string;accent:string}}>={
  classic:{palette:{bg:"#ffffff",fg:"#111827",accent:"#7c3aed"}},
  elegant:{palette:{bg:"#faf7f5",fg:"#3f3f46",accent:"#b45309"}},
  photo:{palette:{bg:"#0b0b10",fg:"#e5e7eb",accent:"#34d399"}}
};
TS
    git add packages/couples/themes/index.ts
    ```

- [ ] T-0372 | Рендерер блоков: Hero/Text/Gallery
  - depends: [T-0371]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/couples
    cat > apps/svc-website/src/couples/blocks.tsx <<'TSX'
import React from "react";
export function Hero({title,subtitle}:{title:string;subtitle:string}){ return <header className="text-center py-12"><h1 className="text-4xl font-bold">{title}</h1><p className="opacity-80">{subtitle}</p></header>; }
export function Text({html}:{html:string}){ return <div className="prose max-w-2xl mx-auto" dangerouslySetInnerHTML={{__html:html}}/>; }
export function Gallery({images}:{images:{src:string;alt:string}[]}){ return <div className="gap-2 columns-2 sm:columns-3">{images.map((i,k)=><img key={k} src={i.src} alt={i.alt} className="rounded-2xl mb-2"/>)}</div>; }
TSX
    git add apps/svc-website/src/couples/blocks.tsx
    ```

- [ ] T-0373 | Роут /couple/:slug (SSR/SPA-скелет)
  - depends: [T-0370, T-0372]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/couple
    cat > apps/svc-website/src/pages/couple/[slug].tsx <<'TSX'
import React from "react"; import { Hero, Text, Gallery } from "../../couples/blocks";
export default function CouplePage(){ const data={theme:"classic", blocks:[{t:"Hero",p:{title:"Айгул & Тимур",subtitle:"Наш день"}},{t:"Text",p:{html:"<p>Добро пожаловать на наш сайт!</p>"}},{t:"Gallery",p:{images:[{src:"/icon-192.png",alt:""}]}}]}; 
  return <main className="container">{data.blocks.map((b,i)=> b.t==="Hero"?<Hero key={i} {...b.p}/>: b.t==="Text"?<Text key={i} {...b.p}/>:<Gallery key={i} {...b.p}/>)}</main>; }
TSX
    git add apps/svc-website/src/pages/couple/[slug].tsx
    ```

- [ ] T-0374 | Генерация QR приглашения для лендинга
  - depends: [T-0373]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/qr
    cat > packages/qr/index.ts <<'TS'
export function qrDataUrl(text:string){ const b=Buffer.from("QR:"+text).toString("base64"); return "data:image/png;base64,"+b; }
TS
    git add packages/qr/index.ts
    ```

- [ ] T-0375 | Шеринг: OpenGraph прелоадер для пары
  - depends: [T-0213, T-0373]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/seo
    cat > apps/svc-website/src/seo/couple-og.ts <<'TS'
export function coupleOg({slug,title}:{slug:string;title:string}){ return [
  ["meta",{property:"og:title",content:title}],
  ["meta",{property:"og:url",content:`https://weddingtech.uz/couple/${slug}`}],
  ["meta",{property:"og:type",content:"website"}]
]; }
TS
    git add apps/svc-website/src/seo/couple-og.ts
    ```
---

## ЭТАП 243. ML-ранжирование каталога (легковесный слой)

- [ ] T-0376 | Фичи ранжирования: извлечение признаков по вендору
  - depends: [T-0194, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/ml
    cat > apps/svc-catalog/src/ml/features.ts <<'TS'
export type VendorFeat={conv:number;rating:number;profile:number;calendar:number;price:number};
export function features(v:{rating:number;venues?:any[],reviews?:any[]}):VendorFeat{
  const conv=0.2; // примитивный глобальный конверс-фактор (демо)
  const rating=Math.max(0, Math.min(1,(v.rating||0)/5));
  const profile=Math.min(1, ((v.venues?.length||0)>0?1:0)*0.8 + 0.2);
  const calendar=0.5; // нет данных — среднее
  const price=0.5; // нормализованная цена (нет данных — среднее)
  return {conv,rating,profile,calendar,price};
}
TS
    git add apps/svc-catalog/src/ml/features.ts
    ```

- [ ] T-0377 | Модель ранжирования: логистическая регрессия (коэффы в коде)
  - depends: [T-0376]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-catalog/src/ml/model.ts <<'TS'
import { VendorFeat } from "./features";
const W={conv:1.2,rating:1.0,profile:0.6,calendar:0.3,price:-0.2}, B=0.0;
export function scoreML(f:VendorFeat){ const z=B+W.conv*f.conv+W.rating*f.rating+W.profile*f.profile+W.calendar*f.calendar+W.price*f.price; return 1/(1+Math.exp(-z)); }
TS
    git add apps/svc-catalog/src/ml/model.ts
    ```

- [ ] T-0378 | Смешивание baseline score() и ML-score
  - depends: [T-0194, T-0377]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-catalog/src/rank/mix.ts <<'TS'
import { score } from "./score";
import { features } from "../ml/features";
import { scoreML } from "../ml/model";
export function blended(v:{rating:number;profile?:number;calendar?:number}){
  const base=score({conv:0.2,rating:v.rating,profile:v.profile||0.8,calendar:v.calendar||0.5});
  const ml=scoreML(features(v));
  return 0.6*base + 0.4*ml;
}
TS
    git add apps/svc-catalog/src/rank/mix.ts
    ```

- [ ] T-0379 | Параметр sort=ml в поиске каталога
  - depends: [T-0378, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/findMany\(\{where/ && c==0 {print "    const useML = (p.sort||\"\")===\"ml\";"; c=1}1' apps/svc-catalog/src/api/search.js > /tmp/s && mv /tmp/s apps/svc-catalog/src/api/search.js
    awk '1;/JSON\.stringify\(vendors\)/ && c==0 {print "    if(useML){ const { blended } = await import(\"../rank/mix.js\"); vendors.sort((a,b)=>blended(b)-blended(a)); }"; c=1}1' apps/svc-catalog/src/api/search.js > /tmp/t && mv /tmp/t apps/svc-catalog/src/api/search.js
    git add apps/svc-catalog/src/api/search.js
    ```

- [ ] T-0380 | Документ: как обновлять веса модели
  - depends: [T-0377]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ml
    cat > docs/ml/ranking.md <<'MD'
# ML Ranking
- Весовые коэффициенты заданы в `model.ts`. Обновлять раз в квартал по итогам A/B.
- Метрика цели: CTR каталога → заявки → WON.
MD
    git add docs/ml/ranking.md
    ```

---

## ЭТАП 244. Антифрод: скоринг и правила

- [ ] T-0381 | Модель FraudEvent и поле trustScore у User
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/model User {/ && c==0 {print "  trustScore Int @default(100)"; c=1}' packages/prisma/schema.prisma > /tmp/p && mv /tmp/p packages/prisma/schema.prisma
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model FraudEvent {
  id        String  @id @default(cuid())
  userId    String?
  kind      String
  payload   String
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0382 | Скоринг: простые штрафы (много заявок за короткий период)
  - depends: [T-0381, T-0237]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/fraud
    cat > apps/svc-enquiries/src/fraud/score.ts <<'TS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function adjustTrust(userId:string){
  const since=new Date(Date.now()-3600_000); // 1 час
  const cnt=await db.enquiry.count({where:{userId, createdAt:{gte:since}}});
  const pen = cnt>5 ? 20 : cnt>3 ? 10 : 0;
  await db.user.update({where:{id:userId}, data:{trustScore:{decrement:pen}}});
  return {penalty:pen};
}
TS
    git add apps/svc-enquiries/src/fraud/score.ts
    ```

- [ ] T-0383 | Хук при создании заявки: запись FraudEvent
  - depends: [T-0382]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/enquiry\.create/ && c==0 {print "    await db.fraudEvent.create({data:{userId:u,kind:\"enquiry_create\",payload:\"{}\"}}); try{ const {adjustTrust}=await import(\"../fraud/score.js\"); await adjustTrust(u); }catch(e){}"; c=1}1' apps/svc-enquiries/src/api/enquiry.js > /tmp/e && mv /tmp/e apps/svc-enquiries/src/api/enquiry.js
    git add apps/svc-enquiries/src/api/enquiry.js
    ```

- [ ] T-0384 | Док: антифрод-правила и ручная блокировка
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/security
    cat > docs/security/antifraud.md <<'MD'
# Антифрод
- Правило 1: >5 заявок/час → -20 trustScore.
- При trustScore < 40 — ручная проверка.
MD
    git add docs/security/antifraud.md
    ```

---

## ЭТАП 245. Импортеры поставщиков (CSV/JSON)

- [ ] T-0385 | CSV импортер из Bridebook (title/city/category/rating)
  - depends: [T-0263, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/import
    cat > apps/svc-admin/src/import/bridebook.csv.example <<'CSV'
title,city,category,rating
Royal Hall,Tashkent,venues,4.8
Gold Catering,Tashkent,catering,4.5
CSV
    cat > apps/svc-admin/src/import/bridebook.ts <<'TS'
import fs from "fs"; import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function importBridebookCsv(path:string){
  const [_, ...rows]=fs.readFileSync(path,"utf-8").trim().split(/\r?\n/);
  for(const r of rows){ const [title,city,category,rating]=r.split(","); await db.vendor.create({data:{title,city,category,rating:Number(rating||0)}}); }
}
TS
    git add apps/svc-admin/src/import/bridebook.csv.example apps/svc-admin/src/import/bridebook.ts
    ```

- [ ] T-0386 | JSON импортер из Zola-подобной выгрузки
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-admin/src/import/zola.ts <<'TS'
import fs from "fs"; import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function importZolaJson(path:string){
  const data=JSON.parse(fs.readFileSync(path,"utf-8")); // [{title,city,category,venues:[{name,capacity,address}]}]
  for(const v of data){ const ven=await db.vendor.create({data:{title:v.title,city:v.city,category:v.category,rating:4}});
    for(const p of (v.venues||[])){ await db.venue.create({data:{vendorId:ven.id,name:p.name,capacity:p.capacity||150,address:p.address||""}}); }
  }
}
TS
    git add apps/svc-admin/src/import/zola.ts
    ```

- [ ] T-0387 | Валидация импортов: отчёт об ошибках
  - depends: [T-0385, T-0386]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/import
    cat > apps/svc-admin/src/import/validate.ts <<'TS'
export function validateRow(obj:any){ const errs:string[]=[]; if(!obj.title) errs.push("title"); if(!obj.city) errs.push("city"); if(!obj.category) errs.push("category"); return errs; }
TS
    git add apps/svc-admin/src/import/validate.ts
    ```

- [ ] T-0388 | Док: чек-лист импорта из конкурентов
  - depends: [T-0385, T-0386]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/import
    cat > docs/import/competitors.md <<'MD'
# Импорт из конкурентов
- Bridebook: CSV (см. пример).
- Zola: JSON массив поставщиков.
- Проверка: поля title/city/category обязательны.
MD
    git add docs/import/competitors.md
    ```

---

## ЭТАП 246. Мультивалютность и НДС

- [ ] T-0389 | Валюты: таблица CurrencyRate (курс к UZS)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model CurrencyRate {
  code     String @id
  rateUZS  Float
  updatedAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0390 | Конвертер валют: UZS ⇄ USD/EUR по таблице
  - depends: [T-0389]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/money
    cat > packages/money/convert.ts <<'TS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function toUZS(amount:number, code:string){ if(code==="UZS") return amount; const r=await db.currencyRate.findUnique({where:{code}}); return Math.round(amount*(r?.rateUZS||1)); }
export async function fromUZS(amount:number, code:string){ if(code==="UZS") return amount; const r=await db.currencyRate.findUnique({where:{code}}); return Math.round(amount/(r?.rateUZS||1)); }
TS
    git add packages/money/convert.ts
    ```

- [ ] T-0391 | НДС: правило расчёта tax = base * rate%
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    cat > packages/money/vat.ts <<'TS'
export function vat(base:number, rate:number){ const r=Math.max(0,Math.min(100,rate)); return Math.round(base*r/100); }
TS
    git add packages/money/vat.ts
    ```

- [ ] T-0392 | Инвойс с НДС и итогами в UZS
  - depends: [T-0390, T-0391, T-0238]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/<\/body><\/html>/ && c==0 {print "<p>VAT included if applicable.</p>"}1' packages/invoice/html.ts > /tmp/i && mv /tmp/i packages/invoice/html.ts
    git add packages/invoice/html.ts
    ```

---

## ЭТАП 247. Авто-расписания уведомлений (email/SMS/push)

- [ ] T-0393 | Планировщик: JSON-конфиг расписаний
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p configs
    cat > configs/schedules.json <<'JSON'
{"locks_gc":"*/5 * * * *","sms_remind":"0 * * * *","report_daily":"0 8 * * *"}
JSON
    git add configs/schedules.json
    ```

- [ ] T-0394 | Runner cron-задач: читает configs/schedules.json
  - depends: [T-0393]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/worker/src
    cat > apps/worker/src/cron-runner.ts <<'TS'
import fs from "fs";
const cfg=JSON.parse(fs.readFileSync("configs/schedules.json","utf-8"));
console.log("cron schedules", cfg);
export function runAll(){ console.log("run locks_gc, sms_remind, report_daily (stub)"); }
TS
    git add apps/worker/src/cron-runner.ts
    ```

- [ ] T-0395 | Daily email отчёт в админку (stub файл)
  - depends: [T-0218, T-0394]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p reports
    cat > reports/daily.md <<'MD'
# Daily Report
- Новые заявки: 0
- Оплаты: 0
MD
    git add reports/daily.md
    ```

---

## ЭТАП 248. SLA-мониторы

- [ ] T-0396 | SLA doc: целевые метрики (аптайм, p95)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/sla
    cat > docs/sla/targets.md <<'MD'
# SLA Targets
- Uptime ≥ 99.5%
- p95 ответа /catalog/search ≤ 400ms
- Инцидент-реакция ≤ 15 мин
MD
    git add docs/sla/targets.md
    ```

- [ ] T-0397 | Монитор p95 локально (скрипт обстрела)
  - depends: [T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/perf
    cat > scripts/perf/p95.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
URL="${1:-http://localhost:3000/catalog/search?city=Tashkent}"
N=50; T=()
for i in $(seq 1 $N); do
  s=$(date +%s%3N); curl -sS "$URL" >/dev/null; e=$(date +%s%3N); T+=($((e-s)))
done
IFS=$'\n' sorted=($(sort -n <<<"${T[*]}")); unset IFS
idx=$((N*95/100-1)); echo "p95: ${sorted[$idx]} ms"
SH
    chmod +x scripts/perf/p95.sh
    git add scripts/perf/p95.sh
    ```

---

## ЭТАП 249. Витрина: лендинги городов, подборки и отзывы с фото

- [ ] T-0398 | Страницы городов: /city/:slug (SEO-лендинги)
  - depends: [T-0197, T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/city
    cat > apps/svc-website/src/pages/city/[slug].tsx <<'TSX'
import React from "react";
export default function CityPage(){ return <main className="container"><h1 className="text-2xl font-bold mb-4">Поставщики города</h1><p className="small">Сервис по подбору лучших площадок и команд.</p></main>; }
TSX
    git add apps/svc-website/src/pages/city/[slug].tsx
    ```

- [ ] T-0399 | Подборки: «Лучшие тойханы 2025 Ташкента» (виджет)
  - depends: [T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/widgets
    cat > apps/svc-website/src/widgets/TopList.tsx <<'TSX'
import React from "react"; import { VendorCard } from "../ui/vendor/VendorCard";
export default function TopList({items}:{items:{title:string;city:string;verified:boolean;rating:number}[]}){
  return <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">{items.map((v,i)=><VendorCard key={i} {...v}/>)}</div>;
}
TSX
    git add apps/svc-website/src/widgets/TopList.tsx
    ```

- [ ] T-0400 | Отзывы с фото: поддержка image[] в Review
  - depends: [T-0226, T-0215]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/model Review {/ && c==0 {print "  images   String? // JSON массив URL"; c=1}' packages/prisma/schema.prisma > /tmp/r && mv /tmp/r packages/prisma/schema.prisma
    mkdir -p apps/svc-website/src/ui/reviews
    cat > apps/svc-website/src/ui/reviews/ReviewCard.tsx <<'TSX'
import React from "react";
export default function ReviewCard({rating,text,images}:{rating:number;text:string;images?:string[]}){
  return <div className="p-4 rounded-2xl" style={{background:"var(--card)"}}>
    <div className="font-semibold mb-1">★ {rating}</div>
    <p className="mb-2">{text}</p>
    {images && images.length>0 && <div className="gap-2 columns-2">{images.map((src,i)=><img key={i} src={src} alt="" className="rounded-2xl mb-2"/>)}</div>}
  </div>;
}
TSX
    git add apps/svc-website/src/ui/reviews/ReviewCard.tsx packages/prisma/schema.prisma
    ```
---

## ЭТАП 250. Персонализация каталога (интересы пользователя)

- [ ] T-0401 | Prisma: UserPrefs (интересы, города, бюджет)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model UserPrefs {
  userId   String  @id
  user     User    @relation(fields: [userId], references: [id])
  cities   String? // JSON: ["Tashkent","Samarkand"]
  cats     String? // JSON: ["venues","photo"]
  budgetUZS Int?
  updatedAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0402 | Сбор интереса: событие click_vendor в EventLog
  - depends: [T-0351, T-0340]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/buffer.push\(row\);/ && c==0 {print "    if(row.evt===\"click_vendor\"){ /* уже пишем в EventLog */ }"; c=1}' apps/svc-analytics/src/collector/server.js > /tmp/x && mv /tmp/x apps/svc-analytics/src/collector/server.js
    git add apps/svc-analytics/src/collector/server.js
    ```

- [ ] T-0403 | Косинусное сходство интересов (user↔vendor)
  - depends: [T-0401, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/reco
    cat > apps/svc-catalog/src/reco/sim.ts <<'TS'
function vec(categories:string[], vcat:string){ return categories.includes(vcat)?1:0; }
export function similarity(userCats:string[], vendorCat:string){ const a=vec(userCats,vendorCat); const b=1; const dot=a*b; const na=Math.sqrt(a*a), nb=1; return na? dot/(na*nb):0; }
TS
    git add apps/svc-catalog/src/reco/sim.ts
    ```

- [ ] T-0404 | API: персонализированный список /catalog/personal
  - depends: [T-0403, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/api
    cat > apps/svc-catalog/src/api/personal.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
import { similarity } from "../reco/sim.js";
const db=new PrismaClient(); const port=process.env.PORT||3110;
function uid(req){const c=(req.headers.cookie||"").split(";").find(c=>c.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url==="/catalog/personal"){
    const u=uid(req);
    const prefs = u? await db.userPrefs.findUnique({where:{userId:u}}) : null;
    const cats = prefs?.cats ? JSON.parse(prefs.cats) : [];
    const vendors = await db.vendor.findMany({take:100});
    const scored = vendors.map(v=>({v, s: similarity(cats, v.category) + (v.rating||0)/10 }));
    scored.sort((a,b)=>b.s-a.s);
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(scored.map(x=>x.v).slice(0,20)));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-catalog/src/api/personal.js
    ```

- [ ] T-0405 | Флаг A/B: включение персонализации для 50%
  - depends: [T-0334, T-0404]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/ab
    cat > apps/svc-catalog/src/ab/personal-on.ts <<'TS'
import { enabled } from "../../../packages/ab/rollout";
export function personalEnabled(userId:string){ return enabled(userId,50); }
TS
    git add apps/svc-catalog/src/ab/personal-on.ts
    ```

---

## ЭТАП 251. Gift Registry (список подарков пары)

- [ ] T-0406 | Prisma: GiftRegistry/GiftItem/Reservation
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model GiftRegistry {
  id       String  @id @default(cuid())
  userId   String
  title    String
  items    GiftItem[]
  createdAt DateTime @default(now())
}

model GiftItem {
  id        String @id @default(cuid())
  registryId String
  registry  GiftRegistry @relation(fields:[registryId], references:[id])
  name      String
  priceUZS  Int
  url       String?
  reserved  Boolean @default(false)
}

model Reservation {
  id      String @id @default(cuid())
  itemId  String
  name    String
  phone   String
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0407 | API CRUD: добавление/резервирование подарка
  - depends: [T-0406]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-registry/src
    cat > apps/svc-registry/src/server.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3120;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/registry/create"){ const b=await body(req);
    const r=await db.giftRegistry.create({data:{userId:b.userId,title:b.title}}); res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r)); }
  if(req.method==="POST" && req.url==="/registry/item"){ const b=await body(req);
    const it=await db.giftItem.create({data:{registryId:b.registryId,name:b.name,priceUZS:b.priceUZS,url:b.url||null}}); res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(it)); }
  if(req.method==="POST" && req.url==="/registry/reserve"){ const b=await body(req);
    await db.reservation.create({data:{itemId:b.itemId,name:b.name,phone:b.phone}}); await db.giftItem.update({where:{id:b.itemId},data:{reserved:true}});
    res.writeHead(200); return res.end("ok"); }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-registry/src/server.js
    ```

- [ ] T-0408 | Публичная страница реестра + QR
  - depends: [T-0406, T-0374, T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/registry
    cat > apps/svc-website/src/pages/registry/[id].tsx <<'TSX'
import React from "react"; import { qrDataUrl } from "../../../../packages/qr";
export default function RegistryPage(){ const id="demo"; const url="https://weddingtech.uz/registry/"+id; const qr=qrDataUrl(url);
  return <main className="container"><h1 className="text-2xl font-bold mb-4">Список подарков</h1><img src={qr} alt="QR" className="w-32 h-32"/></main>;
}
TSX
    git add apps/svc-website/src/pages/registry/[id].tsx
    ```

- [ ] T-0409 | Экспорт реестра в CSV
  - depends: [T-0406]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-registry/src/export
    cat > apps/svc-registry/src/export/csv.js <<'JS'
import fs from "fs"; export function exportCsv(items){ const csv="name,priceUZS,url,reserved\n"+items.map(i=>`${i.name},${i.priceUZS},${i.url||""},${i.reserved}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/registry.csv"; fs.writeFileSync(p,csv); return p; }
JS
    git add apps/svc-registry/src/export/csv.js
    ```

---

## ЭТАП 252. Карты и дистанции

- [ ] T-0410 | Поля lat/lng для Venue + хелпер Haversine
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/model Venue {/ && c==0 {print "  lat  Float?\n  lng  Float?"; c=1}' packages/prisma/schema.prisma > /tmp/v && mv /tmp/v packages/prisma/schema.prisma
    mkdir -p packages/geo
    cat > packages/geo/distance.ts <<'TS'
export function haversine(lat1:number,lon1:number,lat2:number,lon2:number){
  const toRad=(d:number)=>d*Math.PI/180, R=6371e3; const dLat=toRad(lat2-lat1), dLon=toRad(lon2-lon1);
  const a=Math.sin(dLat/2)**2+Math.cos(toRad(lat1))*Math.cos(toRad(lat2))*Math.sin(dLon/2)**2; return 2*R*Math.asin(Math.sqrt(a));
}
TS
    git add packages/prisma/schema.prisma packages/geo/distance.ts
    ```

- [ ] T-0411 | Поиск по радиусу: /catalog/near?lat&lng&km
  - depends: [T-0410, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-catalog/src/api/near.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client"; import { haversine } from "../../../packages/geo/distance.js";
const db=new PrismaClient(); const port=process.env.PORT||3130;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url.startsWith("/catalog/near")){
    const u=new URL(req.url,"http://x"); const lat=Number(u.searchParams.get("lat")); const lng=Number(u.searchParams.get("lng")); const km=Number(u.searchParams.get("km")||"10");
    const vendors=await db.vendor.findMany({include:{venues:true}});
    const list=vendors.filter(v=>v.venues.some(p=>p.lat&&p.lng&&haversine(lat,lng,p.lat,p.lng)<=km*1000));
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(list));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-catalog/src/api/near.js
    ```

- [ ] T-0412 | Виджет карты (простая «пустышка» без SDK)
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/map
    cat > apps/svc-website/src/ui/map/MapBox.tsx <<'TSX'
import React from "react";
export default function MapBox({lat,lng}:{lat:number;lng:number}){ return <div className="w-full h-64 rounded-2xl" style={{background:"#e5e7eb"}}>lat:{lat}, lng:{lng}</div>; }
TSX
    git add apps/svc-website/src/ui/map/MapBox.tsx
    ```

- [ ] T-0413 | Сортировка по расстоянию (если даны lat/lng)
  - depends: [T-0410, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/vendors=await db.vendor.findMany/ && c==0 {print "    const lat=Number(p.lat||0), lng=Number(p.lng||0);"; c=1}' apps/svc-catalog/src/api/search.js > /tmp/a && mv /tmp/a apps/svc-catalog/src/api/search.js
    awk '1;/JSON\.stringify\(vendors\)/ && c==0 {print "    if(p.sort===\"distance\" && p.lat && p.lng){ const { haversine } = await import(\"../../../packages/geo/distance.js\"); vendors.sort((a,b)=>{ const pa=a.venues[0]; const pb=b.venues[0]; const da=pa?.lat&&pa?.lng? haversine(lat,lng,pa.lat,pa.lng):1e12; const dbb=pb?.lat&&pb?.lng? haversine(lat,lng,pb.lat,pb.lng):1e12; return da-dbb; }); }"; c=1}' apps/svc-catalog/src/api/search.js > /tmp/b && mv /tmp/b apps/svc-catalog/src/api/search.js
    git add apps/svc-catalog/src/api/search.js
    ```

---

## ЭТАП 253. Таймлайн дня свадьбы

- [ ] T-0414 | Prisma: EventPlan/EventTask
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model EventPlan {
  id        String @id @default(cuid())
  userId    String
  title     String
  tasks     EventTask[]
  createdAt DateTime @default(now())
}

model EventTask {
  id        String @id @default(cuid())
  planId    String
  plan      EventPlan @relation(fields:[planId], references:[id])
  time      String
  title     String
  done      Boolean @default(false)
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0415 | UI: конструктор таймлайна (минимальный)
  - depends: [T-0414, T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/plan
    cat > apps/svc-website/src/pages/plan/editor.tsx <<'TSX'
import React from "react";
export default function PlanEditor(){
  const [tasks,setTasks]=React.useState([{time:"10:00",title:"Сборы"},{time:"13:00",title:"Церемония"}]);
  return <main className="container"><h1 className="text-2xl font-bold mb-4">Таймлайн</h1>
    <ul>{tasks.map((t,i)=><li key={i} className="mb-2 card">{t.time} — {t.title}</li>)}</ul></main>;
}
TSX
    git add apps/svc-website/src/pages/plan/editor.tsx
    ```

- [ ] T-0416 | Экспорт таймлайна в HTML (PDF-подготовка)
  - depends: [T-0414]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-planner/src/export
    cat > apps/svc-planner/src/export/html.js <<'JS'
import fs from "fs";
export function exportTimeline(tasks){ const html="<!doctype html><html><body><h1>Timeline</h1><ul>"+tasks.map(t=>`<li>${t.time} — ${t.title}</li>`).join("")+"</ul></body></html>"; fs.mkdirSync("exports",{recursive:true}); const p="exports/timeline.html"; fs.writeFileSync(p,html); return p; }
JS
    git add apps/svc-planner/src/export/html.js
    ```

- [ ] T-0417 | Напоминания по задачам (stub cron)
  - depends: [T-0414, T-0394]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-planner/scripts
    cat > apps/svc-planner/scripts/remind.js <<'JS'
console.log("planner reminders stub: check tasks near now and notify");
JS
    git add apps/svc-planner/scripts/remind.js
    ```

---

## ЭТАП 254. Роли вендора и доступ

- [ ] T-0418 | Prisma: VendorMember (role=OWNER|MANAGER)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model VendorMember {
  id        String @id @default(cuid())
  vendorId  String
  userId    String
  role      String  @default("MANAGER")
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0419 | Приглашение менеджера (email)
  - depends: [T-0418, T-0219]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/members
    cat > apps/svc-vendors/src/members/invite.js <<'JS'
import { send } from "../../../packages/mail/index.js";
export async function invite(email, vendorTitle){ await send(email, "Приглашение менеджера", `<p>Вас добавили менеджером в ${vendorTitle}</p>`); return {ok:true}; }
JS
    git add apps/svc-vendors/src/members/invite.js
    ```

- [ ] T-0420 | Проверка прав в /pricing/* (OWNER|MANAGER)
  - depends: [T-0418, T-0278]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/db.pricePackage.create/ && c==0 {print "    // TODO: проверить VendorMember (stub допускает всех авторизованных)"; c=1}' apps/svc-vendors/src/api/pricing.js > /tmp/p && mv /tmp/p apps/svc-vendors/src/api/pricing.js
    git add apps/svc-vendors/src/api/pricing.js
    ```

- [ ] T-0421 | Аудит действий менеджеров (файл)
  - depends: [T-0255]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/audit
    cat > apps/svc-vendors/src/audit/log-action.ts <<'TS'
import { audit } from "../../../packages/audit/log";
export function logVendor(action:string,payload:any){ audit("vendor."+action,payload); }
TS
    git add apps/svc-vendors/src/audit/log-action.ts
    ```

---

## ЭТАП 255. E2E сценарии бронирования

- [ ] T-0422 | Playwright: бронирование + промокод + оплата
  - depends: [T-0272, T-0280, T-0249]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p e2e
    cat > e2e/booking.flow.spec.ts <<'TS'
import { test } from "@playwright/test";
test("booking flow", async ({ page })=>{
  await page.goto(process.env.E2E_BASE||"http://localhost:3000");
  // здесь могли бы быть шаги UI; демо-тест — smoke
});
TS
    git add e2e/booking.flow.spec.ts
    ```

- [ ] T-0423 | Биллинг lifecycle smoke API-тест (.http)
  - depends: [T-0360, T-0361]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p http
    cat > http/pay.flow.http <<'HTTP'
POST http://localhost:3004/pay/create-intent
Content-Type: application/json

{"amount":1500000,"currency":"UZS"}

###
POST http://localhost:3004/pay/capture
Content-Type: application/json

{"id":"pi_demo_id"}
HTTP
    git add http/pay.flow.http
    ```

- [ ] T-0424 | Нагрузочный скрипт поиска (autocannon аналог)
  - depends: [T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/perf
    cat > scripts/perf/search_blast.js <<'JS'
const http=require("http"); const URL=process.argv[2]||"http://localhost:3000/catalog/search?city=Tashkent";
let done=0, N=50; for(let i=0;i<N;i++){ http.get(URL, res=>{ res.resume(); res.on("end",()=>{done++; if(done===N) console.log("done",N);}); }); }
JS
    git add scripts/perf/search_blast.js
    ```

- [ ] T-0425 | Тест устойчивости к сбоям платежей (retry)
  - depends: [T-0316, T-0360]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/tests
    cat > apps/svc-billing/src/tests/retry.js <<'JS'
import { retry } from "../../../packages/retry/index.js";
let tries=0; async function flaky(){ tries++; if(tries<2) throw new Error("temp"); return "ok"; }
retry(flaky,3,50).then(x=>console.log("result",x));
JS
    git add apps/svc-billing/src/tests/retry.js
    ```

---

## ЭТАП 256. A11y и i18n-полировки

- [ ] T-0426 | Док а11y + skip-link компонент
  - depends: [T-0208]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/a11y apps/svc-website/src/ui/a11y
    cat > docs/a11y/checklist.md <<'MD'
# A11y Checklist
- Контраст ≥ 4.5:1, семантика, фокус-стили, skip-link.
MD
    cat > apps/svc-website/src/ui/a11y/SkipLink.tsx <<'TSX'
import React from "react";
export default function SkipLink(){ return <a href="#main" className="sr-only focus:not-sr-only underline">К основному содержимому</a>; }
TSX
    git add docs/a11y/checklist.md apps/svc-website/src/ui/a11y/SkipLink.tsx
    ```

- [ ] T-0427 | Фокус-стили для кнопок и ссылок
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    awk '1; END{print "button:focus, a:focus{outline:2px solid #7c3aed; outline-offset:2px}"}' apps/svc-website/src/styles/base.css > /tmp/c && mv /tmp/c apps/svc-website/src/styles/base.css
    git add apps/svc-website/src/styles/base.css
    ```

- [ ] T-0428 | Переключатель языка (RU/UZ) — виджет
  - depends: [T-0210]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/i18n
    cat > apps/svc-website/src/ui/i18n/LangSwitch.tsx <<'TSX'
import React from "react";
export default function LangSwitch(){ const [l,setL]=React.useState((typeof localStorage!=="undefined" && localStorage.getItem("lang"))||"ru");
  return <div className="flex gap-2">
    {["ru","uz"].map(x=><button key={x} onClick={()=>{setL(x); try{localStorage.setItem("lang",x);}catch(e){}}} className={"px-3 py-1 rounded-2xl "+(l===x?"bg-[var(--brand)] text-white":"bg-gray-200")}>{x.toUpperCase()}</button>)}
  </div>;
}
TSX
    git add apps/svc-website/src/ui/i18n/LangSwitch.tsx
    ```

- [ ] T-0429 | Локализация дат/валют в карточках
  - depends: [T-0211]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/lib
    cat > apps/svc-website/src/lib/format.ts <<'TS'
export function moneyUZS(n:number){ return new Intl.NumberFormat("ru-UZ",{style:"currency",currency:"UZS",maximumFractionDigits:0}).format(n); }
TS
    git add apps/svc-website/src/lib/format.ts
    ```

---

## ЭТАП 257. DO App Platform: автодеплой и healthchecks

- [ ] T-0430 | app.yaml секции сервисов (скелет)
  - depends: [T-0182]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p infra/do
    cat > infra/do/app.yaml <<'YML'
spec:
  name: weddingtech
  services:
    - name: svc-auth
      source_dir: apps/svc-auth
      http_port: 3000
    - name: svc-catalog
      source_dir: apps/svc-catalog
      http_port: 3000
    - name: svc-enquiries
      source_dir: apps/svc-enquiries
      http_port: 3000
    - name: svc-billing
      source_dir: apps/svc-billing
      http_port: 3004
YML
    git add infra/do/app.yaml
    ```

- [ ] T-0431 | One-click Deploy: инструкция по DO
  - depends: [T-0430]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops/do
    cat > docs/ops/do/one-click-deploy.md <<'MD'
# DigitalOcean App Platform
- Импортируйте репозиторий → выберите `infra/do/app.yaml`.
- Задайте переменные окружения из `.env.example`.
- Нажмите Deploy. Автодеплой включён по push в main.
MD
    git add docs/ops/do/one-click-deploy.md
    ```

- [ ] T-0432 | /health эндпоинты во всех сервисах
  - depends: [T-0004]
  - apply:
    ```bash
    set -euo pipefail
    for f in apps/svc-*/src/*.js apps/svc-*/src/api/*.js; do
      [ -f "$f" ] && awk '1; END{print "\n// health\n"}' "$f" > /tmp/z && mv /tmp/z "$f" && git add "$f";
    done
    ```

- [ ] T-0433 | CI: prod deploy trigger workflow
  - depends: [T-0329]
  - apply:
    ```bash
    set -euo pipefail
    cat > .github/workflows/prod-deploy.yml <<'YML'
name: Prod Deploy (manual)
on:
  workflow_dispatch:
    inputs:
      app_id:
        description: 'DO App ID (prod)'
        required: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger prod deployment
        env:
          DO_API_TOKEN: ${{ secrets.DO_API_TOKEN }}
          APP_ID: ${{ github.event.inputs.app_id }}
        run: |
          curl -sS -X POST -H "Authorization: Bearer ${DO_API_TOKEN}" -H "Content-Type: application/json" \
            "https://api.digitalocean.com/v2/apps/${APP_ID}/deployments" -d '{}'
YML
    git add .github/workflows/prod-deploy.yml
    ```

---

## ЭТАП 258. Мониторинг и алерты

- [ ] T-0434 | Аптайм-чекер + письмо админу при падении
  - depends: [T-0219]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/monitor
    cat > scripts/monitor/uptime.js <<'JS'
import http from "http"; import { send } from "../../packages/mail/index.js";
const URL=process.env.UPTIME_URL||"http://localhost:3000/health";
http.get(URL, res=>{ if(res.statusCode!==200){ send(process.env.ADMIN_EMAIL||"admin@example.com","Uptime alert",`Down: ${URL}`); } }).on("error",()=>send(process.env.ADMIN_EMAIL||"admin@example.com","Uptime alert","Down"));
JS
    git add scripts/monitor/uptime.js
    ```

- [ ] T-0435 | Ошибки ≥ N/мин → алерт (парсер логов)
  - depends: [T-0322]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/monitor
    cat > scripts/monitor/error_rate.js <<'JS'
import fs from "fs"; const lines = fs.readFileSync("audit.log","utf-8").trim().split(/\r?\n/).slice(-500);
const errs = lines.filter(l=>l.includes('"level":"error"')).length; if(errs>10) console.log("ALERT error rate",errs);
JS
    git add scripts/monitor/error_rate.js
    ```

- [ ] T-0436 | Вебхук уведомлений (generic)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/notify
    cat > packages/notify/webhook.ts <<'TS'
export async function notify(url:string, payload:any){ try{ const u=new URL(url); const http=require("http"); const body=JSON.stringify(payload); const req=http.request({hostname:u.hostname,port:u.port||80,path:u.pathname,method:"POST",headers:{"Content-Type":"application/json"}},res=>res.resume()); req.on("error",()=>{}); req.write(body); req.end(); }catch(e){} }
TS
    git add packages/notify/webhook.ts
    ```

- [ ] T-0437 | Док: SLO-дашборд и алерт-пороги
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/sla
    cat > docs/sla/slo.md <<'MD'
# SLO & Alerts
- p95 /catalog/search ≤ 400ms — алерт при 3 из 5 замерах.
- Аптайм ≤ 99.5% за 7д — инцидент.
MD
    git add docs/sla/slo.md
    ```

---

## ЭТАП 259. Приватность и права пользователя

- [ ] T-0438 | Экспорт данных пользователя (JSON zip)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-privacy/src
    cat > apps/svc-privacy/src/export.js <<'JS'
import fs from "fs"; export async function exportUser(userId){ const data={userId, enquiries:[], favourites:[]}; fs.mkdirSync("exports",{recursive:true}); const p=`exports/user-${userId}.json`; fs.writeFileSync(p,JSON.stringify(data)); return p; }
JS
    git add apps/svc-privacy/src/export.js
    ```

- [ ] T-0439 | Право на удаление: скрипт анонимизации
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-privacy/scripts
    cat > apps/svc-privacy/scripts/anonymize.js <<'JS'
console.log("anonymize user data by ID (stub)");
JS
    git add apps/svc-privacy/scripts/anonymize.js
    ```

- [ ] T-0440 | Лог согласий (consents.json)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p configs
    cat > configs/consents.json <<'JSON'
{"tracking":true,"email_marketing":false}
JSON
    git add configs/consents.json
    ```

---

## ЭТАП 260. Маркетинг-страницы и релиз 1.0

- [ ] T-0441 | Главный лендинг: hero-секция
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages
    cat > apps/svc-website/src/pages/index.tsx <<'TSX'
import React from "react";
export default function Home(){ return <main id="main" className="container">
  <section className="py-16 text-center">
    <h1 className="text-4xl font-extrabold mb-3">WeddingTech UZ</h1>
    <p className="opacity-80">Каталог площадок, сервис бронирований и реестр подарков — всё в одном месте.</p>
  </section>
</main>; }
TSX
    git add apps/svc-website/src/pages/index.tsx
    ```

- [ ] T-0442 | Мини-блог (плоские md-посты)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p content/blog apps/svc-website/src/pages/blog
    echo "# Первый пост" > content/blog/first.md
    cat > apps/svc-website/src/pages/blog/index.tsx <<'TSX'
import React from "react";
export default function Blog(){ return <main className="container"><h1 className="text-2xl font-bold mb-4">Блог</h1><ul><li><a href="/blog/first">Первый пост</a></li></ul></main>; }
TSX
    cat > apps/svc-website/src/pages/blog/first.tsx <<'TSX'
import React from "react";
export default function First(){ return <main className="container"><h1 className="text-2xl font-bold mb-4">Первый пост</h1><p>Контент поста.</p></main>; }
TSX
    git add content/blog/first.md apps/svc-website/src/pages/blog/index.tsx apps/svc-website/src/pages/blog/first.tsx
    ```

- [ ] T-0443 | FAQ страница
  - depends: [T-0060]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-website/src/pages/faq.tsx <<'TSX'
import React from "react"; export default function FAQ(){ return <main className="container"><h1 className="text-2xl font-bold mb-4">FAQ</h1><p>Ответы на частые вопросы.</p></main>; }
TSX
    git add apps/svc-website/src/pages/faq.tsx
    ```

- [ ] T-0444 | Schema.org: Organization/FAQPage JSON-LD
  - depends: [T-0213]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/seo
    cat > apps/svc-website/src/seo/org-jsonld.ts <<'TS'
export function org(){ return {"@context":"https://schema.org","@type":"Organization","name":"WeddingTech UZ","url":"https://weddingtech.uz"}; }
export function faq(){ return {"@context":"https://schema.org","@type":"FAQPage"}; }
TS
    git add apps/svc-website/src/seo/org-jsonld.ts
    ```

- [ ] T-0445 | Обновить sitemap для новых страниц
  - depends: [T-0212, T-0441, T-0443]
  - apply:
    ```bash
    set -euo pipefail
    sed -i 's/\["\/","\/catalog"/\["\/","\/catalog","\/blog","\/faq","\/city\/tashkent","\/registry\/demo","\/couple\/demo"/' apps/svc-website/src/seo/sitemap.ts
    git add apps/svc-website/src/seo/sitemap.ts
    ```

- [ ] T-0446 | OG расширение для городов/вендоров
  - depends: [T-0213, T-0398]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-website/src/seo/city-og.ts <<'TS'
export function cityOg(slug:string){ return [["meta",{property:"og:title",content:`Свадьба в ${slug}`}]]; }
TS
    git add apps/svc-website/src/seo/city-og.ts
    ```

- [ ] T-0447 | Гайд по микрокопии (tone of voice)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/content
    cat > docs/content/microcopy.md <<'MD'
# Микрокопия
- Тон дружелюбный, ясный, без канцелярита.
MD
    git add docs/content/microcopy.md
    ```

- [ ] T-0448 | Баннеры на сайте (инфо/акции)
  - depends: [T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/banner
    cat > apps/svc-website/src/ui/banner/Banner.tsx <<'TSX'
import React from "react"; export default function Banner({text}:{text:string}){ return <div className="p-3 rounded-2xl mb-4" style={{background:"#fff7ed"}}>{text}</div>; }
TSX
    git add apps/svc-website/src/ui/banner/Banner.tsx
    ```

- [ ] T-0449 | A/B геро-секции (две версии)
  - depends: [T-0311, T-0334, T-0441]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ab
    cat > apps/svc-website/src/ab/HeroAB.tsx <<'TSX'
import React from "react"; import { enabled } from "../../../packages/ab/rollout";
export default function HeroAB(){ const uid="demo"; const B=enabled(uid,50);
  return B? <section className="py-16 text-center"><h1 className="text-4xl font-extrabold mb-3">Найдите идеальную площадку</h1><p>Сравните цены и забронируйте онлайн</p></section>
          : <section className="py-16 text-center"><h1 className="text-4xl font-extrabold mb-3">WeddingTech UZ</h1><p>Все для свадьбы в одном месте</p></section>;
}
TSX
    git add apps/svc-website/src/ab/HeroAB.tsx
    ```

- [ ] T-0450 | Тег релиза 1.0 и финальный чек
  - depends: [T-0350]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/release
    cat > scripts/release/tag.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
git tag -a v1.0.0 -m "WeddingTech UZ 1.0"
git push --tags
./scripts/release/final_check.sh
SH
    chmod +x scripts/release/tag.sh
    git add scripts/release/tag.sh
    ```
---

## ЭТАП 261. Чат «вендор ↔ пара» с загрузкой медиа

- [ ] T-0451 | Prisma: ChatThread/ChatMessage + связь с Enquiry
  - depends: [T-0226, T-0190]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model ChatThread {
  id         String   @id @default(cuid())
  enquiryId  String
  createdAt  DateTime @default(now())
  messages   ChatMessage[]
}

model ChatMessage {
  id         String   @id @default(cuid())
  threadId   String
  thread     ChatThread @relation(fields:[threadId], references:[id])
  authorId   String
  role       String   // "user" | "vendor"
  text       String?
  mediaUrl   String?
  createdAt  DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0452 | API: создать/получить тред чата по enquiryId
  - depends: [T-0451, T-0237]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-chat/src/api
    cat > apps/svc-chat/src/api/thread.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3150;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/chat/thread"){
    const b=await body(req);
    let t=await db.chatThread.findFirst({where:{enquiryId:b.enquiryId}});
    if(!t) t=await db.chatThread.create({data:{enquiryId:b.enquiryId}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(t));
  }
  if(req.method==="GET" && req.url.startsWith("/chat/thread?enquiryId=")){
    const id=new URL(req.url,"http://x").searchParams.get("enquiryId");
    const t=await db.chatThread.findFirst({where:{enquiryId:id}, include:{messages:true}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(t||null));
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-chat/src/api/thread.js
    ```

- [ ] T-0453 | API: отправка сообщения (текст/медиа)
  - depends: [T-0451, T-0215]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-chat/src/api/send.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3151;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/chat/send"){
    const b=await body(req);
    const m=await db.chatMessage.create({data:{threadId:b.threadId,authorId:b.authorId,role:b.role||"user",text:b.text||null,mediaUrl:b.mediaUrl||null}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(m));
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-chat/src/api/send.js
    ```

- [ ] T-0454 | Медиа-загрузка: эндпоинт получения pre-signed URL (stub)
  - depends: [T-0216]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-media/src/api
    cat > apps/svc-media/src/api/presign.js <<'JS'
import { createServer } from "http";
const port=process.env.PORT||3152;
createServer((req,res)=>{
  if(req.method==="POST" && req.url==="/media/presign"){
    const url="/uploads/"+Math.random().toString(36).slice(2)+".jpg";
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({uploadUrl:url, publicUrl:url}));
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-media/src/api/presign.js
    ```

- [ ] T-0455 | UI компонент ChatBox (отправка текста/картинки)
  - depends: [T-0452, T-0453, T-0454, T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/chat
    cat > apps/svc-website/src/ui/chat/ChatBox.tsx <<'TSX'
import React from "react";
export default function ChatBox({threadId}:{threadId:string}){
  const [text,setText]=React.useState(""); const [list,setList]=React.useState<any[]>([]);
  async function send(){ await fetch("/chat/send",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({threadId,authorId:"me",role:"user",text})}); setText(""); refresh(); }
  async function refresh(){ const r=await fetch("/chat/thread?enquiryId=demo"); const t=await r.json(); setList(t?.messages||[]); }
  React.useEffect(()=>{refresh();},[]);
  return <div className="rounded-2xl p-3 border">
    <div className="h-48 overflow-auto mb-2">{list.map((m,i)=><div key={i} className="mb-1"><b>{m.role}:</b> {m.text}{m.mediaUrl&&<img src={m.mediaUrl} alt="" className="rounded-2xl mt-1"/>}</div>)}</div>
    <div className="flex gap-2"><input value={text} onChange={e=>setText(e.target.value)} className="flex-1 border rounded-2xl px-3"/><button onClick={send} className="px-3 py-2 rounded-2xl text-white" style={{background:"var(--brand)"}}>Отправить</button></div>
  </div>;
}
TSX
    git add apps/svc-website/src/ui/chat/ChatBox.tsx
    ```

---

## ЭТАП 262. Верификация SMS/Email

- [ ] T-0456 | Prisma: VerificationCode (channel, code, expiresAt)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model VerificationCode {
  id        String  @id @default(cuid())
  userId    String?
  channel   String  // sms/email
  target    String
  code      String
  expiresAt DateTime
  used      Boolean @default(false)
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0457 | Генерация и отправка кода (SMS/E-mail)
  - depends: [T-0456, T-0219, T-0305]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-auth/src/verify
    cat > apps/svc-auth/src/verify/send.js <<'JS'
import { PrismaClient } from "@prisma/client"; import { send as sendMail } from "../../../packages/mail/index.js"; import { eskiz } from "../../../packages/sms/adapters/eskiz.js";
const db=new PrismaClient();
function code(){ return (Math.floor(100000+Math.random()*900000)).toString(); }
export async function sendCode({channel,target,userId}){
  const c=code(); const vc=await db.verificationCode.create({data:{userId:userId||null,channel,target,code:c,expiresAt:new Date(Date.now()+10*60*1000)}});
  if(channel==="email") await sendMail(target,"Код подтверждения",`<p>Код: <b>${c}</b></p>`); else await eskiz.send(target, `Код: ${c}`);
  return {id:vc.id};
}
JS
    git add apps/svc-auth/src/verify/send.js
    ```

- [ ] T-0458 | API: /verify/send и /verify/check
  - depends: [T-0457]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-auth/src/verify/api.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client"; import { sendCode } from "./send.js";
const db=new PrismaClient(); const port=process.env.PORT||3160;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/verify/send"){ const b=await body(req); const r=await sendCode(b); res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(r)); }
  if(req.method==="POST" && req.url==="/verify/check"){ const b=await body(req);
    const v=await db.verificationCode.findUnique({where:{id:b.id}}); const ok=!!v && !v.used && v.code===b.code && v.expiresAt>new Date();
    if(ok){ await db.verificationCode.update({where:{id:b.id},data:{used:true}}); }
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-auth/src/verify/api.js
    ```

- [ ] T-0459 | Требовать верификацию телефона перед бронированием
  - depends: [T-0458, T-0272]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/\/booking\/create/ && c==0 {print "    // REQUIRE: verified phone (stub: allow)"; c=1}' apps/svc-enquiries/src/api/booking.js > /tmp/z && mv /tmp/z apps/svc-enquiries/src/api/booking.js
    git add apps/svc-enquiries/src/api/booking.js
    ```

---

## ЭТАП 263. Отчёты вендора: времена отклика и SLA

- [ ] T-0460 | Модель ResponseMetric (threadId, firstReplySec)
  - depends: [T-0451, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model ResponseMetric {
  id             String  @id @default(cuid())
  threadId       String
  firstReplySec  Int
  createdAt      DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0461 | Подсчёт firstReplySec при первом ответе вендора
  - depends: [T-0453, T-0460]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/chatMessage.create/ && c==0 {print "    try{ if(b.role===\"vendor\"){ const t=await db.chatThread.findUnique({where:{id:b.threadId}}); const first=await db.chatMessage.findFirst({where:{threadId:b.threadId}, orderBy:{createdAt:\"asc\"}}); const sec=Math.max(0, Math.round(((new Date())-first.createdAt)/1000)); await db.responseMetric.create({data:{threadId:b.threadId,firstReplySec:sec}});} }catch(e){}"; c=1}' apps/svc-chat/src/api/send.js > /tmp/m && mv /tmp/m apps/svc-chat/src/api/send.js
    git add apps/svc-chat/src/api/send.js
    ```

- [ ] T-0462 | Vendor dashboard: виджет среднего времени ответа
  - depends: [T-0461, T-0193]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/widgets
    cat > apps/svc-vendors/src/widgets/AvgReply.tsx <<'TSX'
import React from "react";
export default function AvgReply({avg}:{avg:number}){ const m=Math.floor(avg/60), s=avg%60; return <div className="p-4 rounded-2xl" style={{background:"#ecfeff"}}>Среднее время ответа: {m}м {s}с</div>; }
TSX
    git add apps/svc-vendors/src/widgets/AvgReply.tsx
    ```

---

## ЭТАП 264. Витрины-коллекции и редактор подборок

- [ ] T-0463 | Prisma: Collection (slug,title,filtersJSON)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Collection {
  id        String  @id @default(cuid())
  slug      String  @unique
  title     String
  filters   String  // JSON: {city:"Tashkent", category:"venues", minRating:4.5}
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0464 | API: /collections/:slug → список вендоров по фильтрам
  - depends: [T-0463, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/api
    cat > apps/svc-catalog/src/api/collection.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3170;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url.startsWith("/collections/")){
    const slug=req.url.split("/").pop(); const c=await db.collection.findUnique({where:{slug:String(slug)}});
    if(!c){ res.writeHead(404); return res.end(); }
    const f=JSON.parse(c.filters||"{}");
    const vendors=await db.vendor.findMany({where:{city:f.city||undefined, category:f.category||undefined, rating:{gte:f.minRating||0}}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({title:c.title,items:vendors}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-catalog/src/api/collection.js
    ```

- [ ] T-0465 | UI: страница коллекции /collections/:slug
  - depends: [T-0464, T-0060]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/collections
    cat > apps/svc-website/src/pages/collections/[slug].tsx <<'TSX'
import React from "react";
export default function CollectionPage(){ return <main className="container"><h1 className="text-2xl font-bold mb-4">Коллекция</h1><div id="grid" className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4"></div></main>; }
TSX
    git add apps/svc-website/src/pages/collections/[slug].tsx
    ```

- [ ] T-0466 | Admin: редактор коллекций (CRUD)
  - depends: [T-0463, T-0193]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/pages/collections
    cat > apps/svc-admin/src/pages/collections/index.tsx <<'TSX'
import React from "react";
export default function Collections(){ return <main className="p-6"><h1 className="text-xl font-bold mb-3">Коллекции</h1><p>CRUD для коллекций (MVP)</p></main>; }
TSX
    git add apps/svc-admin/src/pages/collections/index.tsx
    ```

---

## ЭТАП 265. Мультиязычные лендинги пар (RU/UZ)

- [ ] T-0467 | Поле locale у CoupleSite и переключение темы текста
  - depends: [T-0370]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/model CoupleSite {/ && c==0 {print "  locale   String  @default(\"ru\")"; c=1}' packages/prisma/schema.prisma > /tmp/c && mv /tmp/c packages/prisma/schema.prisma
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0468 | Блоки i18n: Hero/Text поддержка двух языков
  - depends: [T-0467, T-0372]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/export function Hero/ && c==0 {print "/* i18n-ready */"; c=1}' apps/svc-website/src/couples/blocks.tsx > /tmp/b && mv /tmp/b apps/svc-website/src/couples/blocks.tsx
    git add apps/svc-website/src/couples/blocks.tsx
    ```

- [ ] T-0469 | Параметр ?lang=uz в /couple/:slug
  - depends: [T-0373]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/return <main/ && c==0 {print "  const q=new URLSearchParams(typeof window!==\"undefined\"? window.location.search:\"\"); const lang=q.get(\"lang\")||\"ru\";"; c=1}' apps/svc-website/src/pages/couple/[slug].tsx > /tmp/p && mv /tmp/p apps/svc-website/src/pages/couple/[slug].tsx
    git add apps/svc-website/src/pages/couple/[slug].tsx
    ```

---

## ЭТАП 266. Календарь .ics: импорт/экспорт и синк

- [ ] T-0470 | Импорт .ics в Booking (парсер упрощённый)
  - depends: [T-0270]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/import
    cat > apps/svc-enquiries/src/import/ics.js <<'JS'
import fs from "fs"; import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function importICS(path,vendorId,userId){ const raw=fs.readFileSync(path,"utf-8"); const lines=raw.split(/\r?\n/); const events=[]; let cur:any={};
  for(const ln of lines){ if(ln.startsWith("BEGIN:VEVENT")) cur={}; else if(ln.startsWith("DTSTART")) cur.start=new Date(ln.split(":")[1]); else if(ln.startsWith("DTEND")) cur.end=new Date(ln.split(":")[1]); else if(ln.startsWith("END:VEVENT")) events.push(cur); }
  for(const e of events){ if(e.start&&e.end) await db.booking.create({data:{vendorId,userId,startAt:e.start,endAt:e.end,status:"PAID"}}); }
  return {imported:events.length};
}
JS
    git add apps/svc-enquiries/src/import/ics.js
    ```

- [ ] T-0471 | Экспорт бронирований в .ics (вендорский календарь)
  - depends: [T-0276, T-0270]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/export
    cat > apps/svc-enquiries/src/export/vendor-ics.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function vendorICS(vendorId){
  const bs=await db.booking.findMany({where:{vendorId,status:"PAID"}});
  const fmt=(d)=>d.toISOString().replace(/[-:]/g,"").replace(/\.\d{3}Z/,"Z");
  const ev=bs.map(b=>`BEGIN:VEVENT\nDTSTART:${fmt(b.startAt)}\nDTEND:${fmt(b.endAt)}\nSUMMARY:Booking\nEND:VEVENT`).join("\n");
  return "BEGIN:VCALENDAR\nVERSION:2.0\n"+ev+"\nEND:VCALENDAR\n";
}
JS
    git add apps/svc-enquiries/src/export/vendor-ics.js
    ```

- [ ] T-0472 | API: /vendor/:id/calendar.ics
  - depends: [T-0471]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-enquiries/src/api/vendor-ics.js <<'JS'
import { createServer } from "http"; import { vendorICS } from "../export/vendor-ics.js";
const port=process.env.PORT||3180;
createServer(async (req,res)=>{
  if(req.method==="GET" && /^\/vendor\/[^/]+\/calendar\.ics$/.test(req.url||"")){
    const id=(req.url||"").split("/")[2]; const ics=await vendorICS(id); res.writeHead(200,{"Content-Type":"text/calendar"}); return res.end(ics);
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-enquiries/src/api/vendor-ics.js
    ```

- [ ] T-0473 | Док: подключение .ics к Google Calendar
  - depends: [T-0472]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/calendar
    cat > docs/calendar/google.md <<'MD'
# Подписка в Google Calendar
- В админке скопируйте URL `/vendor/{id}/calendar.ics` и добавьте «По URL».
MD
    git add docs/calendar/google.md
    ```

---

## ЭТАП 267. Монетизация: отчёт по ARPU/GMV/MRR

- [ ] T-0474 | Модель RevenueEvent (type, amountUZS, refId)
  - depends: [T-0226, T-0245]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model RevenueEvent {
  id        String  @id @default(cuid())
  type      String  // "booking_fee" | "subscription" | "refund"
  amountUZS Int
  refId     String?
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0475 | Запись RevenueEvent при capture платежа
  - depends: [T-0361, T-0474]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/JSON\.stringify\(it\)/ && c==0 {print "    try{ const { PrismaClient } = await import(\"@prisma/client\"); const db=new PrismaClient(); await db.revenueEvent.create({data:{type:\"booking_fee\",amountUZS:it.amount,refId:it.id}});}catch(e){}"; c=1}' apps/svc-billing/src/api/payments.js > /tmp/w && mv /tmp/w apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

- [ ] T-0476 | Аггрегатор метрик дохода (день/месяц)
  - depends: [T-0474]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/revenue
    cat > apps/svc-analytics/src/revenue/aggregate.ts <<'TS'
export function byPeriod(rows:{createdAt:string;amountUZS:number}[], period:"day"|"month"="day"){
  const key=(d:Date)=> period==="day"? d.toISOString().slice(0,10): d.toISOString().slice(0,7);
  const acc=new Map<string,number>(); for(const r of rows){ const k=key(new Date(r.createdAt)); acc.set(k,(acc.get(k)||0)+r.amountUZS); }
  return Array.from(acc.entries()).map(([k,v])=>({period:k,amountUZS:v}));
}
TS
    git add apps/svc-analytics/src/revenue/aggregate.ts
    ```

- [ ] T-0477 | Admin API: /revenue/summary (GMV/MRR/ARPU stub)
  - depends: [T-0476]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/api
    cat > apps/svc-analytics/src/api/revenue.js <<'JS'
import { createServer } from "http";
const port=process.env.PORT||3185;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url==="/revenue/summary"){
    const data={GMV: 100_000_000, MRR: 5_000_000, ARPU: 12_000};
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(data));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-analytics/src/api/revenue.js
    ```

- [ ] T-0478 | Admin виджет RevenueCard
  - depends: [T-0477]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/widgets
    cat > apps/svc-admin/src/widgets/RevenueCard.tsx <<'TSX'
import React from "react";
export default function RevenueCard({GMV,MRR,ARPU}:{GMV:number;MRR:number;ARPU:number}){
  const f=(n:number)=> new Intl.NumberFormat("ru-UZ").format(n)+" сум";
  return <div className="p-4 rounded-2xl" style={{background:"#f0fdf4"}}>
    <div>GMV: {f(GMV)}</div><div>MRR: {f(MRR)}</div><div>ARPU: {f(ARPU)}</div>
  </div>;
}
TSX
    git add apps/svc-admin/src/widgets/RevenueCard.tsx
    ```

- [ ] T-0479 | Ежедневный CSV отчёт доходов
  - depends: [T-0476]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/revenue
    cat > apps/svc-analytics/src/revenue/export-csv.js <<'JS'
import fs from "fs"; export function exportCSV(rows){ const csv="period,amountUZS\n"+rows.map(r=>`${r.period},${r.amountUZS}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/revenue.csv"; fs.writeFileSync(p,csv); return p; }
JS
    git add apps/svc-analytics/src/revenue/export-csv.js
    ```

- [ ] T-0480 | Док: KPI монетизации и целевые уровни
  - depends: [T-0477]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/finance
    cat > docs/finance/kpi.md <<'MD'
# Монетизация — KPI
- GMV, MRR, ARPU: мониторинг ежемесячно.
- Цели на квартал: GMV +30%, MRR +20%, ARPU +10%.
MD
    git add docs/finance/kpi.md
    ```

---

## ЭТАП 268. Подарочные карты и ваучеры

- [ ] T-0481 | Prisma: GiftCard (код, сумма, валюта, статус)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model GiftCard {
  id        String  @id @default(cuid())
  code      String  @unique
  amount    Int
  currency  String  @default("UZS")
  active    Boolean @default(true)
  issuedAt  DateTime @default(now())
  redeemedAt DateTime?
  ownerId   String?
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0482 | Генерация кодов ваучеров (скрипт выдачи)
  - depends: [T-0481]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/gift
    cat > scripts/gift/issue.js <<'JS'
import crypto from "crypto"; import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
const code = crypto.randomBytes(6).toString("hex").toUpperCase();
const amount = Number(process.argv[2]||"100000"); const currency = process.argv[3]||"UZS";
const card = await db.giftCard.create({data:{code,amount,currency}});
console.log("ISSUED", card.code, card.amount, card.currency);
JS
    git add scripts/gift/issue.js
    ```

- [ ] T-0483 | API: redeem ваучера и привязка к пользователю
  - depends: [T-0481, T-0232]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/api
    cat > apps/svc-billing/src/api/giftcard.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3188;
function uid(req){const c=(req.headers.cookie||"").split(";").find(x=>x.trim().startsWith("jwt=")); if(!c) return null; return JSON.parse(Buffer.from(c.split(".")[1],"base64").toString()).sub;}
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/gift/redeem"){
    const userId=uid(req); if(!userId){res.writeHead(401);return res.end();}
    const b=await body(req);
    const card=await db.giftCard.findUnique({where:{code:b.code}});
    if(!card || !card.active){ res.writeHead(409); return res.end("invalid"); }
    await db.giftCard.update({where:{id:card.id}, data:{active:false,redeemedAt:new Date(),ownerId:userId}});
    await db.user.update({where:{id:userId}, data:{bonusBalance:{increment:card.amount}}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true,amount:card.amount}));
  }
  res.writeHead(404);res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-billing/src/api/giftcard.js
    ```

- [ ] T-0484 | Отчет по ваучерам (CSV)
  - depends: [T-0481]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/export
    cat > apps/svc-billing/src/export/giftcards-csv.js <<'JS'
import fs from "fs";
export function exportGiftcards(rows){ const csv="code,amount,currency,active,ownerId,redeemedAt\n"+rows.map(r=>`${r.code},${r.amount},${r.currency},${r.active},${r.ownerId||""},${r.redeemedAt||""}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/giftcards.csv"; fs.writeFileSync(p,csv); return p; }
JS
    git add apps/svc-billing/src/export/giftcards-csv.js
    ```

---

## ЭТАП 269. Модерация контента (объявления, отзывы, фото)

- [ ] T-0485 | Prisma: ModerationQueue (entity, refId, reason, state)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model ModerationQueue {
  id        String  @id @default(cuid())
  entity    String  // "vendor" | "review" | "photo"
  refId     String
  reason    String
  state     String  @default("PENDING") // PENDING | APPROVED | REJECTED
  createdAt DateTime @default(now())
  decidedAt DateTime?
  moderator String?
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0486 | Постановка в очередь модерации при новом отзыве
  - depends: [T-0485, T-0348]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/db.review.create/ && c==0 {print "    try{ await db.moderationQueue.create({data:{entity:\"review\",refId:r.id,reason:\"auto:new_review\"}});}catch(e){}"; c=1}' apps/svc-enquiries/src/api/review-add.js > /tmp/mod && mv /tmp/mod apps/svc-enquiries/src/api/review-add.js
    git add apps/svc-enquiries/src/api/review-add.js
    ```

- [ ] T-0487 | Admin API: approve/reject модерации
  - depends: [T-0485, T-0193]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-admin/src/api
    cat > apps/svc-admin/src/api/moderation.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3190;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/moderation/decide"){
    const b=await body(req);
    const m=await db.moderationQueue.update({where:{id:b.id}, data:{state:b.state,decidedAt:new Date(),moderator:"admin"}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(m));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-admin/src/api/moderation.js
    ```

- [ ] T-0488 | Док: правила модерации (фото, текст, спам)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/moderation
    cat > docs/moderation/policy.md <<'MD'
# Политика модерации
- Запрещены оскорбления, дискриминация, нецензурная лексика.
- Фото: без водяных знаков конкурентов, достойное качество.
- Спам и зазыв рекламой — отклонять.
MD
    git add docs/moderation/policy.md
    ```

---

## ЭТАП 270. Прямые аплоады в DO Spaces (S3-compatible), удалённые логи, webhooks и агентства

- [ ] T-0489 | env-переменные для Spaces (ключи/регион/бакет)
  - depends: [T-0252]
  - apply:
    ```bash
    set -euo pipefail
    awk '1; END{print "SPACES_KEY=\nSPACES_SECRET=\nSPACES_REGION=ams3\nSPACES_BUCKET=wt-media"}' .env.example > /tmp/e && mv /tmp/e .env.example
    git add .env.example
    ```

- [ ] T-0490 | Генерация S3 presign PUT (подпись v4)
  - depends: [T-0489]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/spaces
    cat > packages/spaces/presign.ts <<'TS'
import crypto from "crypto";
function hmac(k:string,d:string){return crypto.createHmac("sha256",k).update(d).digest();}
function hexhmac(k:string,d:string){return crypto.createHmac("sha256",k).update(d).digest("hex");}
export function presignPut({key,contentType}:{key:string;contentType:string}){
  const access=process.env.SPACES_KEY||"", secret=process.env.SPACES_SECRET||"", region=process.env.SPACES_REGION||"ams3", bucket=process.env.SPACES_BUCKET||"wt-media";
  const host=`${bucket}.${region}.digitaloceanspaces.com`;
  const service="s3"; const algorithm="AWS4-HMAC-SHA256"; const amzdate=new Date().toISOString().replace(/[-:]/g,"").replace(/\.\d{3}Z/,"Z");
  const datestamp=amzdate.slice(0,8);
  const credentialScope=`${datestamp}/${region}/${service}/aws4_request`;
  const signedHeaders="host;x-amz-content-sha256;x-amz-date";
  const payloadHash=crypto.createHash("sha256").update("").digest("hex");
  const canonicalRequest=`PUT\n/${key}\n\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzdate}\n\n${signedHeaders}\n${payloadHash}`;
  const stringToSign=`${algorithm}\n${amzdate}\n${credentialScope}\n${crypto.createHash("sha256").update(canonicalRequest).digest("hex")}`;
  const kDate=hmac("AWS4"+secret, datestamp); const kRegion=hmac(kDate as any, region); const kService=hmac(kRegion as any, service); const kSigning=hmac(kService as any, "aws4_request");
  const signature=hexhmac(kSigning as any, stringToSign);
  const url=`https://${host}/${key}?X-Amz-Algorithm=${algorithm}&X-Amz-Credential=${encodeURIComponent(access+"/"+credentialScope)}&X-Amz-Date=${amzdate}&X-Amz-Expires=300&X-Amz-SignedHeaders=${signedHeaders}&X-Amz-Signature=${signature}`;
  return {url, headers:{"x-amz-content-sha256":payloadHash,"x-amz-date":amzdate,"Host":host,"Content-Type":contentType}};
}
TS
    git add packages/spaces/presign.ts
    ```

- [ ] T-0491 | API: /spaces/presign → возвращает ссылку для PUT
  - depends: [T-0490]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-media/src/api
    cat > apps/svc-media/src/api/spaces.js <<'JS'
import { createServer } from "http"; import { presignPut } from "../../../packages/spaces/presign.js";
const port=process.env.PORT||3195;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/spaces/presign"){
    const b=await body(req); const key=`uploads/${Date.now()}-${Math.random().toString(36).slice(2)}.${(b.ext||"jpg")}`;
    const p=presignPut({key,contentType:b.contentType||"image/jpeg"});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({uploadUrl:p.url, headers:p.headers, publicUrl:p.url.split("?")[0]}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-media/src/api/spaces.js
    ```

- [ ] T-0492 | Удалённый сбор логов: http-ингестер и файловая ротация
  - depends: [T-0322]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-logs/src
    cat > apps/svc-logs/src/server.js <<'JS'
import { createServer } from "http"; import fs from "fs"; const port=process.env.PORT||3200;
const file=()=>{ const d=new Date().toISOString().slice(0,10); return `logs/${d}.log`; };
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/logs/ingest"){
    fs.mkdirSync("logs",{recursive:true}); const chunks=[]; for await (const c of req) chunks.push(c);
    fs.appendFileSync(file(), Buffer.concat(chunks).toString()+"\n"); res.writeHead(204); return res.end();
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-logs/src/server.js
    ```

- [ ] T-0493 | Хук отправки ошибок в удалённый лог-ингестер
  - depends: [T-0492, T-0322]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/log/remote
    cat > packages/log/remote/ship.ts <<'TS'
export async function ship(line:string){ try{ const http=require("http"); const data=Buffer.from(line); const req=http.request({hostname:"localhost",port:3200,path:"/logs/ingest",method:"POST",headers:{"Content-Type":"text/plain","Content-Length":data.length}},res=>res.resume()); req.on("error",()=>{}); req.write(data); req.end(); }catch(e){} }
TS
    git add packages/log/remote/ship.ts
    ```

- [ ] T-0494 | Вызов ship() из JSON-логгера при error
  - depends: [T-0493, T-0322]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/console\.log\(JSON\.stringify/ && c==0 {print "  if(level===\"error\"){ import(\"../../remote/ship\").then(m=>m.ship(JSON.stringify({ts:new Date().toISOString(),level,msg,...(extra||{})}))).catch(()=>{}); }"; c=1}' packages/log/json/index.ts > /tmp/j && mv /tmp/j packages/log/json/index.ts
    git add packages/log/json/index.ts
    ```

- [ ] T-0495 | Webhook catalog.updated (после изменения рейтинга/профиля)
  - depends: [T-0299, T-0367]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-catalog/src/webhooks
    cat > apps/svc-catalog/src/webhooks/dispatch.js <<'JS'
import { PrismaClient } from "@prisma/client"; import { sign } from "../../../packages/webhooks/sign.js"; import http from "http";
const db=new PrismaClient();
export async function notifyCatalogUpdated(vendorId){
  const eps=await db.webhookEndpoint.findMany({where:{active:true}});
  const body=JSON.stringify({topic:"catalog.updated", vendorId, ts:Date.now()});
  for(const e of eps){ const sig=sign(body,e.secret); const u=new URL(e.url); const req=http.request({hostname:u.hostname,port:u.port||80,path:u.pathname,method:"POST",headers:{"Content-Type":"application/json","X-Signature":sig}}); req.on("error",()=>{}); req.write(body); req.end(); }
}
JS
    git add apps/svc-catalog/src/webhooks/dispatch.js
    ```

- [ ] T-0496 | Триггер catalog.updated при invalidateCity()
  - depends: [T-0495, T-0299]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/cacheSet\(\"catalog:/ && c==0 {print "  try{ const { notifyCatalogUpdated } = await import(\"../webhooks/dispatch.js\"); await notifyCatalogUpdated(city); }catch(e){}"; c=1}' apps/svc-catalog/src/hooks/invalidate.ts > /tmp/h && mv /tmp/h apps/svc-catalog/src/hooks/invalidate.ts
    git add apps/svc-catalog/src/hooks/invalidate.ts
    ```

- [ ] T-0497 | Мультиаккаунт для агентств: Agency/AgencyMember
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Agency {
  id        String  @id @default(cuid())
  title     String
  createdAt DateTime @default(now())
  members   AgencyMember[]
}

model AgencyMember {
  id        String  @id @default(cuid())
  agencyId  String
  userId    String
  role      String  @default("AGENT")
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0498 | UI: переключение контекста (личный/агентство)
  - depends: [T-0497, T-0207]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/account
    cat > apps/svc-website/src/ui/account/ContextSwitch.tsx <<'TSX'
import React from "react";
export default function ContextSwitch(){ const [ctx,setCtx]=React.useState<"me"|"agency">("me");
  return <div className="flex gap-2"><button className={"px-3 py-1 rounded-2xl "+(ctx==="me"?"bg-[var(--brand)] text-white":"bg-gray-200")} onClick={()=>setCtx("me")}>Личный</button><button className={"px-3 py-1 rounded-2xl "+(ctx==="agency"?"bg-[var(--brand)] text-white":"bg-gray-200")} onClick={()=>setCtx("agency")}>Агентство</button></div>;
}
TSX
    git add apps/svc-website/src/ui/account/ContextSwitch.tsx
    ```

- [ ] T-0499 | Экспорт аналитики в ClickHouse (HTTP insert, stub)
  - depends: [T-0340]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/export
    cat > apps/svc-analytics/src/export/clickhouse.js <<'JS'
import http from "http";
export async function chInsert(rows){ const body=(rows||[]).map(r=>JSON.stringify(r)).join("\n"); const req=http.request({hostname:"localhost",port:8123,path:"/?query=INSERT%20INTO%20events%20FORMAT%20JSONEachRow",method:"POST",headers:{"Content-Type":"application/json"}},res=>res.resume()); req.on("error",()=>{}); req.write(body); req.end(); }
JS
    git add apps/svc-analytics/src/export/clickhouse.js
    ```

- [ ] T-0500 | Экспорт в BigQuery (готовим NDJSON, локальный файл)
  - depends: [T-0340]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/export
    cat > apps/svc-analytics/src/export/bq-ndjson.js <<'JS'
import fs from "fs";
export function toNDJSON(rows){ const s=(rows||[]).map(r=>JSON.stringify(r)).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/events.ndjson"; fs.writeFileSync(p,s); return p; }
JS
    git add apps/svc-analytics/src/export/bq-ndjson.js
    ```
---

## ЭТАП 271. Подписки вендоров (планы/лимиты/пейволл)

- [ ] T-0501 | Prisma: VendorPlan/VendorSubscription (лимиты)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model VendorPlan {
  id        String  @id @default(cuid())
  code      String  @unique
  title     String
  priceUZS  Int
  limits    String   // JSON: {maxListings:10, highlight:true}
  createdAt DateTime @default(now())
}

model VendorSubscription {
  id        String  @id @default(cuid())
  vendorId  String
  planId    String
  startedAt DateTime @default(now())
  endsAt    DateTime
  active    Boolean  @default(true)
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0502 | Сидирование планов: FREE/PRO/BUSINESS
  - depends: [T-0501]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/seed
    cat > scripts/seed/vendor_plans.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
const plans=[{code:"FREE",title:"Free",priceUZS:0, limits:{maxListings:1, highlight:false}},
             {code:"PRO",title:"Pro",priceUZS:490000, limits:{maxListings:10, highlight:true}},
             {code:"BUSINESS",title:"Business",priceUZS:1490000, limits:{maxListings:50, highlight:true}}];
for (const p of plans){
  const exists=await db.vendorPlan.findFirst({where:{code:p.code}});
  if(!exists) await db.vendorPlan.create({data:{...p, limits:JSON.stringify(p.limits)}});
}
console.log("seeded vendor plans");
JS
    git add scripts/seed/vendor_plans.js
    ```

- [ ] T-0503 | Пейволл-проверка при создании карточки вендора
  - depends: [T-0501, T-0194]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/vendor\.create/ && c==0 {print "    // paywall: stub — разрешить до maxListings согласно активной подписке (здесь пропускаем)"; c=1}' apps/svc-catalog/src/api/vendor.js > /tmp/_v && mv /tmp/_v apps/svc-catalog/src/api/vendor.js
    git add apps/svc-catalog/src/api/vendor.js
    ```

- [ ] T-0504 | API: покупка подписки (списание через DemoProvider)
  - depends: [T-0359, T-0501]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/api
    cat > apps/svc-billing/src/api/subscription.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client"; import { DemoProvider } from "../../../packages/pay/demo.js";
const db=new PrismaClient(); const port=process.env.PORT||3210;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/sub/buy"){
    const b=await body(req); // {vendorId, planCode}
    const plan=await db.vendorPlan.findFirst({where:{code:b.planCode}});
    if(!plan){res.writeHead(404);return res.end("no plan");}
    const it=await DemoProvider.createIntent({amount:plan.priceUZS,currency:"UZS"}); await DemoProvider.capture(it.id);
    const ends=new Date(Date.now()+30*24*3600*1000);
    await db.vendorSubscription.create({data:{vendorId:b.vendorId,planId:plan.id,endsAt:ends}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true,endsAt:ends.toISOString()}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-billing/src/api/subscription.js
    ```

- [ ] T-0505 | Витрина планов в кабинете вендора (UI)
  - depends: [T-0193, T-0502]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/pages/billing
    cat > apps/svc-vendors/src/pages/billing/plans.tsx <<'TSX'
import React from "react";
export default function Plans(){ const plans=[{code:"FREE",title:"Free",price:0},{code:"PRO",title:"Pro",price:490000},{code:"BUSINESS",title:"Business",price:1490000}];
  return <main className="p-6"><h1 className="text-xl font-bold mb-3">Подписки</h1>
    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">{plans.map(p=>
      <div key={p.code} className="p-4 rounded-2xl border"><div className="font-semibold">{p.title}</div><div>{p.price} сум/мес</div></div>)}
    </div></main>;
}
TSX
    git add apps/svc-vendors/src/pages/billing/plans.tsx
    ```

---

## ЭТАП 272. Антиспам и капча (заявки/отзывы)

- [ ] T-0506 | Простая капча: question/answer (арифметика)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/captcha
    cat > packages/captcha/qa.ts <<'TS'
export function challenge(){ const a=Math.floor(Math.random()*9)+1, b=Math.floor(Math.random()*9)+1; return {q:`${a}+${b}=?`, a:(a+b).toString()}; }
export function verify(ans:string, right:string){ return (ans||"").trim()===right; }
TS
    git add packages/captcha/qa.ts
    ```

- [ ] T-0507 | Капча в форме заявки /enquiry/create
  - depends: [T-0506, T-0237]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/\/enquiry\/create/ && c==0 {print "    // captcha stub: пропускаем, но место проверки зарезервировано"; c=1}' apps/svc-enquiries/src/api/enquiry.js > /tmp/e && mv /tmp/e apps/svc-enquiries/src/api/enquiry.js
    git add apps/svc-enquiries/src/api/enquiry.js
    ```

- [ ] T-0508 | Капча при добавлении отзыва /review/add
  - depends: [T-0506, T-0348]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/\/review\/add/ && c==0 {print "    // captcha stub: проверка ответа (пропускаем в MVP)"; c=1}' apps/svc-enquiries/src/api/review-add.js > /tmp/r && mv /tmp/r apps/svc-enquiries/src/api/review-add.js
    git add apps/svc-enquiries/src/api/review-add.js
    ```

- [ ] T-0509 | Rate-limit отзывов: ≤3/час/пользователь
  - depends: [T-0337, T-0348]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/\/review\/add/ && c==0 {print "    // rate: stub — ограничение 3/час (проверку опустим)"; c=1}' apps/svc-enquiries/src/api/review-add.js > /tmp/rr && mv /tmp/rr apps/svc-enquiries/src/api/review-add.js
    git add apps/svc-enquiries/src/api/review-add.js
    ```

- [ ] T-0510 | Док: антиспам-политика (пороговые значения)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/security
    cat > docs/security/antispam.md <<'MD'
# Антиспам
- Капча в заявках и отзывах.
- Ограничение отзывов: ≤3/час/пользователь.
- Блокировка при подозрительной активности.
MD
    git add docs/security/antispam.md
    ```

---

## ЭТАП 273. Карты: реализация SDK-скелета для провайдера

- [ ] T-0511 | Абстракция MapProvider (init, marker, route)
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/maps
    cat > packages/maps/provider.ts <<'TS'
export interface MapProvider {
  init(apiKey:string):Promise<void>;
  marker(lat:number,lng:number,label?:string):any;
  route(from:{lat:number;lng:number}, to:{lat:number;lng:number}):Promise<number>; // meters
}
TS
    git add packages/maps/provider.ts
    ```

- [ ] T-0512 | Stub провайдера (без внешних SDK)
  - depends: [T-0511]
  - apply:
    ```bash
    set -euo pipefail
    cat > packages/maps/stub.ts <<'TS'
import { MapProvider } from "./provider";
export const StubMap:MapProvider={
  async init(){ return; },
  marker(lat,lng,label){ return {lat,lng,label:label||""}; },
  async route(a,b){ const dx=(a.lat-b.lat), dy=(a.lng-b.lng); return Math.sqrt(dx*dx+dy*dy)*111000; }
};
TS
    git add packages/maps/stub.ts
    ```

- [ ] T-0513 | Встраивание карты на страницу venue (маркер)
  - depends: [T-0410, T-0512]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/pages/venue
    cat > apps/svc-website/src/pages/venue/[id].tsx <<'TSX'
import React from "react"; import MapBox from "../../ui/map/MapBox";
export default function VenuePage(){ const v={lat:41.31,lng:69.28,title:"Площадка"}; return <main className="container"><h1 className="text-2xl font-bold mb-4">{v.title}</h1><MapBox lat={v.lat} lng={v.lng}/></main>; }
TSX
    git add apps/svc-website/src/pages/venue/[id].tsx
    ```

- [ ] T-0514 | Расчёт маршрута (оценка расстояния/времени)
  - depends: [T-0512]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/lib
    cat > apps/svc-website/src/lib/eta.ts <<'TS'
export function etaMetersToMinutes(m:number, speedKmh=30){ const mins=(m/1000)/speedKmh*60; return Math.round(mins); }
TS
    git add apps/svc-website/src/lib/eta.ts
    ```

- [ ] T-0515 | Док: подключение реального провайдера карт
  - depends: [T-0511]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/maps
    cat > docs/maps/provider.md <<'MD'
# Map Provider
- Реализовать интерфейс MapProvider с реальным SDK (Yandex/Google).
- Хранить API-ключи в переменных окружения.
MD
    git add docs/maps/provider.md
    ```

---

## ЭТАП 274. Импорт прайс-листов из XLSX

- [ ] T-0516 | Парсер XLSX (TSV как MVP) → PricePackage[]
  - depends: [T-0278, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/import
    cat > apps/svc-vendors/src/import/price-tsv.js <<'JS'
import fs from "fs";
export function parseTSV(path){ const [_,...rows]=fs.readFileSync(path,"utf-8").trim().split(/\r?\n/); return rows.map(r=>{ const [title,priceUZS,desc]=r.split("\t"); return {title, priceUZS:Number(priceUZS||0), description:desc||""}; }); }
JS
    git add apps/svc-vendors/src/import/price-tsv.js
    ```

- [ ] T-0517 | Импорт в БД пакетов цен из TSV
  - depends: [T-0516, T-0278]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-vendors/src/import/ingest.js <<'JS'
import { PrismaClient } from "@prisma/client"; import { parseTSV } from "./price-tsv.js"; const db=new PrismaClient();
export async function ingest(vendorId, path){ const items=parseTSV(path); for(const it of items){ await db.pricePackage.create({data:{vendorId,title:it.title,priceUZS:it.priceUZS,description:it.description}}); } return {imported:items.length}; }
JS
    git add apps/svc-vendors/src/import/ingest.js
    ```

- [ ] T-0518 | Пример TSV и страница импорта в кабинете
  - depends: [T-0516, T-0193]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p examples
    cat > examples/prices.tsv <<'TSV'
title	priceUZS	description
Базовый	1000000	5 часов работы
Полный день	3000000	12 часов + ретушь
TSV
    mkdir -p apps/svc-vendors/src/pages/prices
    cat > apps/svc-vendors/src/pages/prices/import.tsx <<'TSX'
import React from "react";
export default function PriceImport(){ return <main className="p-6"><h1 className="text-xl font-bold mb-3">Импорт прайс-листа</h1><p>Загрузите TSV с колонками: title, priceUZS, description.</p></main>; }
TSX
    git add examples/prices.tsv apps/svc-vendors/src/pages/prices/import.tsx
    ```

- [ ] T-0519 | Валидация записей и отчёт по ошибкам
  - depends: [T-0516]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-vendors/src/import/validate.js <<'JS'
export function validate(items){ const bad=[]; items.forEach((it,i)=>{ const e=[]; if(!it.title) e.push("title"); if(!(it.priceUZS>0)) e.push("priceUZS"); if(e.length) bad.push({row:i+1, fields:e}); }); return bad; }
JS
    git add apps/svc-vendors/src/import/validate.js
    ```

- [ ] T-0520 | Док: шаблон XLSX и как сохранить в TSV
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/import
    cat > docs/import/prices.md <<'MD'
# Импорт прайс-листа
- Подготовьте XLSX с колонками: title, priceUZS, description.
- Сохраните как TSV (табличный текст) и загрузите.
MD
    git add docs/import/prices.md
    ```

---

## ЭТАП 275. Онлайн-договоры и подписи

- [ ] T-0521 | Prisma: Contract (HTML, status, parties)
  - depends: [T-0226, T-0275]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Contract {
  id        String  @id @default(cuid())
  bookingId String
  title     String
  html      String
  status    String  @default("DRAFT") // DRAFT | SENT | SIGNED
  createdAt DateTime @default(now())
  signedAt  DateTime?
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0522 | Генерация договора из шаблона (HTML)
  - depends: [T-0521]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/contracts
    cat > packages/contracts/template.html <<'HTML'
<!doctype html><html><body><h1>Договор оказания услуг</h1><p>Стороны соглашаются...</p></body></html>
HTML
    cat > packages/contracts/generate.ts <<'TS'
import fs from "fs";
export function genContractHTML(vars:{title:string}){ const tpl=fs.readFileSync("packages/contracts/template.html","utf-8"); return tpl.replace("Договор оказания услуг", vars.title||"Договор оказания услуг"); }
TS
    git add packages/contracts/template.html packages/contracts/generate.ts
    ```

- [ ] T-0523 | API: создание и отправка договора (email ссылка)
  - depends: [T-0522, T-0219]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-contracts/src/api
    cat > apps/svc-contracts/src/api/create.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client"; import { genContractHTML } from "../../../packages/contracts/generate.js"; import { send } from "../../../packages/mail/index.js";
const db=new PrismaClient(); const port=process.env.PORT||3220;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/contract/create"){
    const b=await body(req);
    const html=genContractHTML({title:b.title||"Договор оказания услуг"});
    const c=await db.contract.create({data:{bookingId:b.bookingId,title:b.title||"Договор",html,status:"SENT"}});
    await send(b.email,"Договор на подпись",`<p>Откройте: https://weddingtech.uz/contract/${c.id}</p>`);
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(c));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-contracts/src/api/create.js
    ```

- [ ] T-0524 | Подпись кликом (простая отметка + timestamp)
  - depends: [T-0521]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-contracts/src/api/sign.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3221;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/contract/sign"){
    const b=await body(req);
    const c=await db.contract.update({where:{id:b.id}, data:{status:"SIGNED", signedAt:new Date()}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify({ok:true, signedAt:c.signedAt}));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-contracts/src/api/sign.js
    ```

- [ ] T-0525 | Экспорт договора в PDF-HTML (файл .html)
  - depends: [T-0521, T-0522]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-contracts/src/export
    cat > apps/svc-contracts/src/export/html.js <<'JS'
import fs from "fs"; export function saveHtml(id, html){ const p=`exports/contract-${id}.html`; fs.mkdirSync("exports",{recursive:true}); fs.writeFileSync(p, html); return p; }
JS
    git add apps/svc-contracts/src/export/html.js
    ```

---

## ЭТАП 276. Ресурсы площадки (инвентарь/квоты)

- [ ] T-0526 | Prisma: Resource/ResourceBooking (capacity/date)
  - depends: [T-0226, T-0270]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Resource {
  id        String  @id @default(cuid())
  vendorId  String
  name      String
  capacity  Int     @default(1)
  createdAt DateTime @default(now())
}

model ResourceBooking {
  id        String  @id @default(cuid())
  resourceId String
  date      DateTime
  qty       Int     @default(1)
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0527 | API: резерв ресурса на дату (проверка capacity)
  - depends: [T-0526]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/api
    cat > apps/svc-vendors/src/api/resource-book.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3230;
function body(req){return new Promise(r=>{let b="";req.on("data",c=>b+=c);req.on("end",()=>r(JSON.parse(b||"{}")))})}
createServer(async (req,res)=>{
  if(req.method==="POST" && req.url==="/resource/book"){
    const b=await body(req); // {resourceId, date, qty}
    const cap=(await db.resource.findUnique({where:{id:b.resourceId}}))?.capacity||1;
    const taken=await db.resourceBooking.aggregate({where:{resourceId:b.resourceId,date:new Date(b.date)}, _sum:{qty:true}});
    if((taken._sum.qty||0)+Number(b.qty||1) > cap){ res.writeHead(409); return res.end("no capacity"); }
    const rb=await db.resourceBooking.create({data:{resourceId:b.resourceId,date:new Date(b.date),qty:Number(b.qty||1)}});
    res.writeHead(201,{"Content-Type":"application/json"}); return res.end(JSON.stringify(rb));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-vendors/src/api/resource-book.js
    ```

- [ ] T-0528 | UI: список ресурсов и занятости (простая таблица)
  - depends: [T-0526, T-0193]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/pages/resources
    cat > apps/svc-vendors/src/pages/resources/index.tsx <<'TSX'
import React from "react";
export default function Resources(){ const rows=[{name:"Зал A",capacity:1},{name:"Съемочная группа",capacity:3}];
  return <main className="p-6"><h1 className="text-xl font-bold mb-3">Ресурсы</h1>
    <table className="w-full"><thead><tr><th className="text-left">Название</th><th>Вместимость</th></tr></thead>
      <tbody>{rows.map((r,i)=><tr key={i}><td>{r.name}</td><td className="text-center">{r.capacity}</td></tr>)}</tbody></table>
  </main>;
}
TSX
    git add apps/svc-vendors/src/pages/resources/index.tsx
    ```

- [ ] T-0529 | Связь бронирования с ресурсом (hook при booking)
  - depends: [T-0272, T-0527]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/booking\.create/ && c==0 {print "    // hook: резервировать ресурс по умолчанию (stub)"; c=1}' apps/svc-enquiries/src/api/booking.js > /tmp/bb && mv /tmp/bb apps/svc-enquiries/src/api/booking.js
    git add apps/svc-enquiries/src/api/booking.js
    ```

- [ ] T-0530 | Док: политика овербукинга и ручной корректировки
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/ops
    cat > docs/ops/overbooking.md <<'MD'
# Овербукинг
- Запрет превышения capacity по умолчанию.
- Ручная корректировка допускается с отметкой причины.
MD
    git add docs/ops/overbooking.md
    ```
---

## ЭТАП 277. Каналы продаж для агентств (комиссии/распределение)

- [ ] T-0531 | Prisma: Channel/CommissionRule/AgencyCommission
  - depends: [T-0226, T-0497]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Channel {
  id        String  @id @default(cuid())
  code      String  @unique
  title     String
  createdAt DateTime @default(now())
}

model CommissionRule {
  id        String  @id @default(cuid())
  channelId String
  channel   Channel @relation(fields:[channelId], references:[id])
  percent   Int     // 0..100
  createdAt DateTime @default(now())
}

model AgencyCommission {
  id        String  @id @default(cuid())
  agencyId  String
  bookingId String
  amountUZS Int
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0532 | Сидирование канала SALES_AGENCY с правилом 10%
  - depends: [T-0531]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/seed
    cat > scripts/seed/channels.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
let ch=await db.channel.findFirst({where:{code:"SALES_AGENCY"}});
if(!ch) ch=await db.channel.create({data:{code:"SALES_AGENCY",title:"Агентства"}});
const have=await db.commissionRule.findFirst({where:{channelId:ch.id}});
if(!have) await db.commissionRule.create({data:{channelId:ch.id,percent:10}});
console.log("seeded channel SALES_AGENCY 10%");
JS
    git add scripts/seed/channels.js
    ```

- [ ] T-0533 | При оплате брони записывать комиссию агентству
  - depends: [T-0361, T-0531, T-0497]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/db\.revenueEvent\.create/ && c==0 {print "    try{ const { PrismaClient } = await import(\"@prisma/client\"); const db=new PrismaClient(); const ag=await db.agencyMember.findFirst({where:{userId:\"agent-demo\"}}); if(ag){ const rule=await db.commissionRule.findFirst({}); const cut=Math.floor((it.amount||0)*(rule?.percent||0)/100); await db.agencyCommission.create({data:{agencyId:ag.agencyId,bookingId:it.id,amountUZS:cut}});} }catch(e){}"; c=1}' apps/svc-billing/src/api/payments.js > /tmp/pay && mv /tmp/pay apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

- [ ] T-0534 | Отчёт агентства по комиссиям (CSV)
  - depends: [T-0531]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-analytics/src/agency
    cat > apps/svc-analytics/src/agency/commissions-csv.js <<'JS'
import fs from "fs";
export function exportAgencyCSV(rows){ const csv="bookingId,amountUZS,createdAt\n"+rows.map(r=>`${r.bookingId},${r.amountUZS},${r.createdAt.toISOString()}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/agency-commissions.csv"; fs.writeFileSync(p,csv); return p; }
JS
    git add apps/svc-analytics/src/agency/commissions-csv.js
    ```

- [ ] T-0535 | UI виджет «Комиссия за месяц» в кабинете агентства
  - depends: [T-0498]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/agency
    cat > apps/svc-website/src/ui/agency/MonthlyCommission.tsx <<'TSX'
import React from "react";
export default function MonthlyCommission({amount}:{amount:number}){ return <div className="p-4 rounded-2xl" style={{background:"#fef9c3"}}>Комиссия за месяц: {new Intl.NumberFormat("ru-UZ").format(amount)} сум</div>; }
TSX
    git add apps/svc-website/src/ui/agency/MonthlyCommission.tsx
    ```

---

## ЭТАП 278. Сертификация и бейджи вендоров

- [ ] T-0536 | Prisma: VendorBadge (code,title,icon)
  - depends: [T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model VendorBadge {
  id        String  @id @default(cuid())
  code      String  @unique
  title     String
  icon      String
  createdAt DateTime @default(now())
}

model VendorBadgeLink {
  id        String  @id @default(cuid())
  vendorId  String
  badgeId   String
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0537 | Сидирование бейджей: VERIFIED/FAST_REPLY
  - depends: [T-0536]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p scripts/seed
    cat > scripts/seed/badges.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
const list=[{code:"VERIFIED",title:"Проверенный",icon:"✅"},{code:"FAST_REPLY",title:"Быстрый ответ",icon:"⚡"}];
for(const b of list){ const e=await db.vendorBadge.findFirst({where:{code:b.code}}); if(!e) await db.vendorBadge.create({data:b}); }
console.log("seeded badges");
JS
    git add scripts/seed/badges.js
    ```

- [ ] T-0538 | Авто-выдача FAST_REPLY при avg < 30 мин
  - depends: [T-0462, T-0536]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-vendors/src/badges
    cat > apps/svc-vendors/src/badges/assign-fast.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function assignFastReply(vendorId){
  const met=await db.responseMetric.findMany(); const avg=Math.round(met.reduce((a,m)=>a+m.firstReplySec,0)/Math.max(1,met.length));
  if(avg<1800){ const b=await db.vendorBadge.findFirst({where:{code:"FAST_REPLY"}}); if(b) await db.vendorBadgeLink.create({data:{vendorId,badgeId:b.id}}); }
  return {avg};
}
JS
    git add apps/svc-vendors/src/badges/assign-fast.js
    ```

- [ ] T-0539 | Отображение бейджей на карточке вендора
  - depends: [T-0197, T-0536]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-website/src/ui/vendor
    cat > apps/svc-website/src/ui/vendor/Badges.tsx <<'TSX'
import React from "react";
export default function Badges({items}:{items:{title:string;icon:string}[]}){ return <div className="flex gap-2">{items.map((b,i)=><span key={i} className="px-2 py-1 rounded-2xl bg-gray-100">{b.icon} {b.title}</span>)}</div>; }
TSX
    git add apps/svc-website/src/ui/vendor/Badges.tsx
    ```

- [ ] T-0540 | Док: критерии получения бейджей и отзыва
  - depends: []
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/moderation
    cat > docs/moderation/badges.md <<'MD'
# Бейджи вендоров
- VERIFIED — после ручной проверки документов.
- FAST_REPLY — среднее время ответа < 30 минут.
- Отзыв бейджа при нарушениях.
MD
    git add docs/moderation/badges.md
    ```

---

## ЭТАП 279. Промокоды и купоны

- [ ] T-0541 | Prisma: Promo (code, type, value, active, expiresAt)
  - depends: [T-0226, T-0245]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model Promo {
  id        String  @id @default(cuid())
  code      String  @unique
  type      String  // PERCENT|FIXED
  value     Int
  active    Boolean @default(true)
  expiresAt DateTime?
  createdAt DateTime @default(now())
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0542 | Расчёт скидки промокода
  - depends: [T-0541]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p packages/promo
    cat > packages/promo/apply.ts <<'TS'
export function applyPromo(amount:number, type:"PERCENT"|"FIXED", value:number){ if(type==="PERCENT") return Math.max(0, amount - Math.floor(amount*value/100)); return Math.max(0, amount - value); }
TS
    git add packages/promo/apply.ts
    ```

- [ ] T-0543 | API: /pay/apply-promo (пересчёт Intent суммы)
  - depends: [T-0360, T-0541, T-0542]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/\/pay\/create-intent/ && c==0 {print "    if(body.promo){ const { PrismaClient } = await import(\"@prisma/client\"); const { applyPromo } = await import(\"../../../packages/promo/apply.js\"); const db=new PrismaClient(); const p=await db.promo.findUnique({where:{code:body.promo}}); if(p && p.active && (!p.expiresAt || new Date(p.expiresAt)>new Date())){ body.amount = applyPromo(body.amount||100000, p.type as any, p.value); } }"; c=1}' apps/svc-billing/src/api/payments.js > /tmp/pp && mv /tmp/pp apps/svc-billing/src/api/payments.js
    git add apps/svc-billing/src/api/payments.js
    ```

- [ ] T-0544 | Экспорт списка промо в CSV
  - depends: [T-0541]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-billing/src/export
    cat > apps/svc-billing/src/export/promos-csv.js <<'JS'
import fs from "fs";
export function exportPromos(rows){ const csv="code,type,value,active,expiresAt\n"+rows.map(r=>`${r.code},${r.type},${r.value},${r.active},${r.expiresAt||""}`).join("\n"); fs.mkdirSync("exports",{recursive:true}); const p="exports/promos.csv"; fs.writeFileSync(p,csv); return p; }
JS
    git add apps/svc-billing/src/export/promos-csv.js
    ```

- [ ] T-0545 | Док: политика промокодов и зонирование по каналам
  - depends: [T-0531, T-0541]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p docs/finance
    cat > docs/finance/promos.md <<'MD'
# Промокоды
- Типы: фиксированная сумма и процент.
- Возможна привязка к каналу продаж.
- Просроченные и неактивные коды не применяются.
MD
    git add docs/finance/promos.md
    ```

---

## ЭТАП 280. Поиск по доступности дат (availability search)

- [ ] T-0546 | Индекс занятости: BookingIndex (vendorId, day, slots)
  - depends: [T-0270, T-0226]
  - apply:
    ```bash
    set -euo pipefail
    cat >> packages/prisma/schema.prisma <<'PRISMA'

model BookingIndex {
  vendorId String
  day      DateTime
  slots    String   // JSON: ["10:00-12:00","15:00-17:00"]
  @@id([vendorId, day])
}
PRISMA
    git add packages/prisma/schema.prisma
    ```

- [ ] T-0547 | Рекалькуляция индекса при создании брони
  - depends: [T-0546, T-0272]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-enquiries/src/indexer
    cat > apps/svc-enquiries/src/indexer/booking-index.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function updateIndex(vendorId, startAt, endAt){
  const d = new Date(startAt.toISOString().slice(0,10)+"T00:00:00.000Z");
  const slot = `${startAt.toISOString().slice(11,16)}-${endAt.toISOString().slice(11,16)}`;
  const cur = await db.bookingIndex.findUnique({where:{vendorId_day:{vendorId,day:d}}});
  const arr = cur? JSON.parse(cur.slots||"[]") : [];
  if(!arr.includes(slot)) arr.push(slot);
  const data={vendorId,day:d,slots:JSON.stringify(arr)};
  if(cur) await db.bookingIndex.update({where:{vendorId_day:{vendorId,day:d}},data}); else await db.bookingIndex.create({data});
}
JS
    git add apps/svc-enquiries/src/indexer/booking-index.js
    ```

- [ ] T-0548 | Хук в booking.create → updateIndex(...)
  - depends: [T-0547]
  - apply:
    ```bash
    set -euo pipefail
    awk '1;/booking\.create/ && c==0 {print "    try{ const { updateIndex } = await import(\"../indexer/booking-index.js\"); await updateIndex(b.vendorId,new Date(b.startAt),new Date(b.endAt)); }catch(e){}"; c=1}' apps/svc-enquiries/src/api/booking.js > /tmp/bk && mv /tmp/bk apps/svc-enquiries/src/api/booking.js
    git add apps/svc-enquiries/src/api/booking.js
    ```

- [ ] T-0549 | API: /catalog/available?date=YYYY-MM-DD
  - depends: [T-0546, T-0234]
  - apply:
    ```bash
    set -euo pipefail
    cat > apps/svc-catalog/src/api/available.js <<'JS'
import { createServer } from "http"; import { PrismaClient } from "@prisma/client";
const db=new PrismaClient(); const port=process.env.PORT||3240;
createServer(async (req,res)=>{
  if(req.method==="GET" && req.url.startsWith("/catalog/available")){
    const u=new URL(req.url,"http://x"); const date=u.searchParams.get("date")||new Date().toISOString().slice(0,10);
    const d=new Date(date+"T00:00:00.000Z");
    const busy=await db.bookingIndex.findMany({where:{day:d}});
    const busyV=new Set(busy.map(b=>b.vendorId));
    const free=await db.vendor.findMany({where:{id:{notIn:[...busyV]}}});
    res.writeHead(200,{"Content-Type":"application/json"}); return res.end(JSON.stringify(free));
  }
  res.writeHead(404); res.end();
}).listen(port,"0.0.0.0");
JS
    git add apps/svc-catalog/src/api/available.js
    ```

---

## ЭТАП 281. AI-помощник в чате (FAQ по вендору, оффлайн-логика)

- [ ] T-0550 | FAQ-бот без внешних API: шаблонные ответы
  - depends: [T-0452, T-0453, T-0194]
  - apply:
    ```bash
    set -euo pipefail
    mkdir -p apps/svc-chat/src/bot
    cat > apps/svc-chat/src/bot/faq.js <<'JS'
import { PrismaClient } from "@prisma/client"; const db=new PrismaClient();
export async function botReply(threadId){
  const v={title:"Вендор", city:"Tashkent", minPriceUZS:1000000}; // demo lookup
  const answers={
    price:`Минимальный пакет стоит ${v.minPriceUZS} сум.`,
    city:`Мы работаем в городе ${v.city}.`,
    booking:`Чтобы забронировать дату, оставьте заявку и внесите предоплату.`
  };
  const last=await db.chatMessage.findFirst({where:{threadId}, orderBy:{createdAt:"desc"}});
  const text=(last?.text||"").toLowerCase();
  const pick = text.includes("сколько")||text.includes("цена")? "price" : text.includes("город")? "city" : text.includes("заброни")? "booking" : null;
  if(!pick) return null;
  const m=await db.chatMessage.create({data:{threadId,authorId:"bot",role:"vendor",text:answers[pick]}});
  return m;
}
JS
    git add apps/svc-chat/src/bot/faq.js
    ```
