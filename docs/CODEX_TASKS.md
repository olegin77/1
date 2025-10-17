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

- [ ] T-0061 | Публичный RSVP (/w/[slug]/rsvp)
  - depends: [T-0060]
  - apply:
    ```bash
    echo "export default function RSVP(){return 'rsvp';}" > apps/svc-website/pages/w/[slug]/rsvp.js
    git add apps/svc-website/pages/w/[slug]/rsvp.js
    ```

- [ ] T-0062 | QR-код приглашения (генерация)
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

- [ ] T-1520 | Подписки на события (скелет)
  - depends: [T-0091]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/webhooks
    echo "export const subscribe=()=>true;" > apps/svc-analytics/src/webhooks/index.ts
    git add apps/svc-analytics/src/webhooks/index.ts
    ```

---

## ЭТАП 153. Интеграция Telegram-ботов (уведомления)

- [ ] T-1530 | Заглушка отправки в Telegram
  - depends: [T-0720]
  - apply:
    ```bash
    mkdir -p packages/telegram
    echo "export const notify=(chatId:string,msg:string)=>({chatId,msg});" > packages/telegram/index.ts
    git add packages/telegram/index.ts
    ```

---

## ЭТАП 154. Витрина идей с фильтрами (semantic+tags)

- [ ] T-1540 | Интеграция semantic в «inspo»
  - depends: [T-1410, T-0700]
  - apply:
    ```bash
    mkdir -p docs/inspo/index
    echo "# Каталог идей (семантическая выдача)" > docs/inspo/index/README.md
    git add docs/inspo/index/README.md
    ```

---

## ЭТАП 155. Контроль дубликатов поставщиков

- [ ] T-1550 | Эвристика duplicate-detector
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

- [ ] T-1560 | Маппинг субдоменов
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

- [ ] T-1570 | Индексация help-центра
  - depends: [T-1410, T-1230]
  - apply:
    ```bash
    mkdir -p docs/help/search
    echo "export const indexed=true;" > docs/help/search/index.ts
    git add docs/help/search/index.ts
    ```

---

## ЭТАП 158. Нормализация телефонов/форматов

- [ ] T-1580 | Нормализатор телефонов
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

- [ ] T-1590 | Сегментация RFM
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

- [ ] T-1600 | Типы Vendor/Enquiry/Invoice
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

- [ ] T-1610 | Дополнение сидера
  - depends: [T-0200]
  - apply:
    ```bash
    echo "console.log('seed vendors demo');" >> apps/seeder/index.js
    git add apps/seeder/index.js
    ```

---

## ЭТАП 162. Мини-ETL для аналитики

- [ ] T-1620 | Экспорт событий в CSV
  - depends: [T-0090]
  - apply:
    ```bash
    mkdir -p apps/svc-analytics/src/etl
    echo "export const toCsv=()=> 'ts,event';" > apps/svc-analytics/src/etl/to-csv.ts
    git add apps/svc-analytics/src/etl/to-csv.ts
    ```

---

## ЭТАП 163. Хранилище фич как артефактов

- [ ] T-1630 | Приземление в /infra/features
  - depends: [T-1421]
  - apply:
    ```bash
    mkdir -p infra/features
    echo "{}" > infra/features/.keep
    git add infra/features/.keep
    ```

---

## ЭТАП 164. Пресеты для конверсии карточки

- [ ] T-1640 | CTA-варианты (A/B)
  - depends: [T-0410]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/experiments
    echo "export const cta=['Запросить предложение','Связаться','Забронировать дату'];" > apps/svc-catalog/src/experiments/cta.ts
    git add apps/svc-catalog/src/experiments/cta.ts
    ```

---

## ЭТАП 165. Контент-генерация для SEO кластеров (скрипт)

- [ ] T-1650 | Генерация mdx по темплейту
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

- [ ] T-1660 | Заглушка Google Calendar импортера
  - depends: [T-0260]
  - apply:
    ```bash
    mkdir -p packages/ical/google
    echo "export const googleImport=()=>[];" > packages/ical/google/index.ts
    git add packages/ical/google/index.ts
    ```

---

## ЭТАП 167. Пакетные сделки (bundle-варианты)

- [ ] T-1670 | Расширение bundles
  - depends: [T-0600]
  - apply:
    ```bash
    echo "export const bundlePresets=['economy','standard','lux'];" > apps/svc-catalog/src/bundles/presets.ts
    git add apps/svc-catalog/src/bundles/presets.ts
    ```

---

## ЭТАП 168. Умные подсказки бюджета (эвристика)

- [ ] T-1680 | Рекомендованный бюджет по городу/гостям
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

- [ ] T-1690 | PDF отчёт для вендора
  - depends: [T-0820]
  - apply:
    ```bash
    echo "export const vendorPdf=1;" > apps/svc-analytics/src/vendor/pdf.ts
    git add apps/svc-analytics/src/vendor/pdf.ts
    ```

---

## ЭТАП 170. Конструктор лендингов (mdx-блоки)

- [ ] T-1700 | Библиотека mdx-блоков
  - depends: [T-0180]
  - apply:
    ```bash
    mkdir -p docs/landing/blocks
    echo "<section>Hero</section>" > docs/landing/blocks/hero.mdx
    git add docs/landing/blocks/hero.mdx
    ```

---

## ЭТАП 171. Экспорт RSVP в QR-бейджи (stub)

- [ ] T-1710 | Генерация бейджей
  - depends: [T-0062, T-0061]
  - apply:
    ```bash
    mkdir -p apps/svc-website/export
    echo "export const badges=()=>[];" > apps/svc-website/export/badges.ts
    git add apps/svc-website/export/badges.ts
    ```

---

## ЭТАП 172. Система жалоб/репортов

- [ ] T-1720 | Репорты на профиль/отзыв
  - depends: [T-0070, T-0250]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/reports
    echo "export const report=()=>true;" > apps/svc-enquiries/src/reports/index.ts
    git add apps/svc-enquiries/src/reports/index.ts
    ```

---

## ЭТАП 173. Сервис «Doorman» (защита эндпоинтов)

- [ ] T-1730 | Блок-лист IP/UA
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

- [ ] T-1740 | Шаблоны сообщений заявок
  - depends: [T-0340]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/templates
    echo "export const msgTemplates=['Здравствуйте! Интересует дата ...','Добрый день! Хотим заказать ...'];" > apps/svc-enquiries/src/templates/messages.ts
    git add apps/svc-enquiries/src/templates/messages.ts
    ```

---

## ЭТАП 175. Сопоставление транзакций (узбекские провайдеры)

- [ ] T-1750 | Нормализация callback-полей
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

- [ ] T-1760 | Метрика response-time
  - depends: [T-0091]
  - apply:
    ```bash
    mkdir -p apps/svc-catalog/src/metrics
    echo "export const responseTime=(ms:number)=>ms;" > apps/svc-catalog/src/metrics/response.ts
    git add apps/svc-catalog/src/metrics/response.ts
    ```

---

## ЭТАП 177. Экспорт/импорт настроек пользователя

- [ ] T-1770 | Бэкап настроек в JSON
  - depends: []
  - apply:
    ```bash
    mkdir -p apps/svc-auth/src/settings
    echo "export const exportSettings=()=>({});" > apps/svc-auth/src/settings/export.ts
    git add apps/svc-auth/src/settings/export.ts
    ```

---

## ЭТАП 178. Поддержка KZ/KG/AZ страниц города

- [ ] T-1780 | Шаблоны городов для регионов
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

- [ ] T-1790 | Rate-limit заявок
  - depends: [T-1170]
  - apply:
    ```bash
    mkdir -p apps/svc-enquiries/src/rl
    echo "export const enquiryLimit=5;" > apps/svc-enquiries/src/rl/policy.ts
    git add apps/svc-enquiries/src/rl/policy.ts
    ```

---

## ЭТАП 180. Финальный пуш уровня 3

- [ ] T-1800 | Commit/push «Level 3»
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
