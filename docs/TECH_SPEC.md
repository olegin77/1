WEDDINGTECH UZ — ТЗ ДЛЯ CODEX (v4.1 — DO-SAFE)
0) Почему раньше рвалось и как больше не допускать

Запрещено: директории frontend/pages/api и frontend/app/api (Next API Routes). Все API — только в NestJS-сервисах.

SSR для динамики: страницы /vendors/*, /planner/* не пререндерить SSG. Использовать SSR (App Router: dynamic="force-dynamic", revalidate=0; Pages Router: getServerSideProps).

Типы/версии: единственные версии react, react-dom, @types/*; включить skipLibCheck.

DO build: на фронте во ВРЕМЯ СБОРКИ нужны devDeps (TS/@types) ⇒ NPM_CONFIG_PRODUCTION=false в Build-time env.

Маршрутизация: ingress.rules (не «routes» внутри сервиса): /api → backend, / → frontend.

Health checks: обязателен /health в фронте и бэках.

1) Архитектура и каталогизация
/
├─ frontend/                # Next.js (B2C + B2B dashboard)
│  ├─ app/                  # App Router (рекомендуется)
│  │  ├─ health/route.ts    # 200 OK
│  │  ├─ planner/layout.tsx # SSR layout
│  │  └─ vendors/layout.tsx # SSR layout
│  ├─ pages/                # Pages Router (наследие допустимо)
│  │  ├─ health.tsx         # 200 OK
│  │  └─ index.tsx          # fallback главная (если нет своей)
│  ├─ tsconfig.json         # см. ниже (полный файл)
│  └─ package.json          # см. ниже (полный блок scripts/overrides)
│
├─ apps/
│  ├─ svc-vendors/          # NestJS + Prisma (VendorAvailability)
│  ├─ svc-enquiries/        # NestJS + Prisma (Enquiry/ROI)
│  └─ svc-search/           # NestJS + OpenSearch (GET /search?eventDate=...)
│
└─ do-app-spec.yaml         # Готовая спека для DigitalOcean (см. ниже)


НЕЛЬЗЯ создавать: frontend/pages/api/** и frontend/app/api/**.

2) DigitalOcean App Spec (вставить как есть: App → Settings → App Spec → Edit → Save & Deploy)
name: weddingtech
features:
  - buildpack-stack=ubuntu-22
ingress:
  rules:
    - component: { name: backend }
      match: { path: { prefix: /api } }
    - component: { name: frontend }
      match: { path: { prefix: / } }

services:
  - name: frontend
    environment_slug: node-js
    github: { repo: olegin77/weddingtech, branch: main, deploy_on_push: true }
    source_dir: frontend
    build_command: "npm ci && npm run build"
    run_command: "next start -p $PORT --hostname 0.0.0.0"
    http_port: 8080
    instance_count: 1
    instance_size_slug: basic-xxs
    envs:
      - { key: NODE_ENV, value: "production" }
      - { key: NODE_VERSION, value: "20" }
      - { key: NEXT_TELEMETRY_DISABLED, value: "1" }
      - { key: NEXT_PUBLIC_API_BASE, value: "/api" }
      # ВАЖНО: devDeps нужны на билде (typescript/@types)
      - { key: NPM_CONFIG_PRODUCTION, value: "false", scope: "BUILD_TIME" }
    health_check:
      http_path: "/health"
      initial_delay_seconds: 10
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3

  - name: backend
    environment_slug: node-js
    github: { repo: olegin77/weddingtech, branch: main, deploy_on_push: true }
    source_dir: backend
    build_command: "npm ci"
    run_command: "npm run start"
    http_port: 8080
    instance_count: 1
    instance_size_slug: basic-xxs
    envs:
      - { key: NODE_ENV, value: "production" }
      - { key: NODE_VERSION, value: "20" }
    health_check:
      http_path: "/health"
      initial_delay_seconds: 5
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3


Применение: после вставки — Force Rebuild + Clear build cache.

3) Фронтенд: «некрушимые» файлы (вставить/поддерживать как есть)
3.1 frontend/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["DOM", "ES2021"],
    "jsx": "preserve",
    "moduleResolution": "bundler",
    "baseUrl": ".",
    "paths": { "@/*": ["*"] },
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}

3.2 frontend/package.json (фрагмент — добавить/синхронизировать эти поля)
{
  "scripts": {
    "build": "next build",
    "start": "next start -p $PORT --hostname 0.0.0.0",
    "dev": "next dev -p 3000"
  },
  "engines": { "node": "20.x", "npm": "10.x" },
  "dependencies": {
    "next": "15.5.4",
    "react": "18.3.1",
    "react-dom": "18.3.1"
  },
  "devDependencies": {
    "typescript": "5.6.3",
    "@types/react": "18.3.10",
    "@types/react-dom": "18.3.0",
    "@types/node": "20.12.12"
  },
  "overrides": {
    "react": "18.3.1",
    "react-dom": "18.3.1",
    "@types/react": "18.3.10",
    "@types/react-dom": "18.3.0"
  }
}

3.3 App Router — типизированные SSR-layout’ы (Next 15)

frontend/app/vendors/layout.tsx

import type { LayoutProps } from "next";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = 'force-no-store';
export const dynamicParams = true;

export default function VendorsLayout(props: LayoutProps<"/vendors">) {
  return <>{props.children}</>;
}


frontend/app/planner/layout.tsx

import type { LayoutProps } from "next";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = 'force-no-store';
export const dynamicParams = true;

export default function PlannerLayout(props: LayoutProps<"/planner">) {
  return <>{props.children}</>;
}

3.4 Health и fallback-главная

frontend/app/health/route.ts

import { NextResponse } from 'next/server';
export async function GET(){ return new NextResponse('OK',{status:200}); }


frontend/pages/health.tsx

export default function Health(){ return <div>OK</div>; }


frontend/pages/index.tsx (если нет своей главной)

export default function Home(){
  return (
    <main style={{padding:24,fontFamily:'system-ui,sans-serif'}}>
      <h1>WeddingTech — Frontend OK</h1>
      <ul>
        <li><a href="/health">/health</a></li>
        <li><a href="/api/health">/api/health</a></li>
        <li><a href="/vendors/123">/vendors/[id] (пример)</a></li>
      </ul>
    </main>
  );
}

3.5 Pages Router (если остался) — запрет SSG

Во всех файлах frontend/pages/vendors/** и frontend/pages/planner/** удалить getStaticProps/getStaticPaths, добавить:

export async function getServerSideProps(){ return { props: {} }; }

4) Бэкенд-сервисы (NestJS)

Общие инварианты (для всех apps/svc-*):

Экспонировать GET /health → 200 OK.

PORT берётся из окружения (DO подставит).

Логировать ошибки и неподдержанные маршруты.

Enquiries (ROI): статусная машина включает
NEW → QUOTE_SENT → MEETING_SCHEDULED → CONTRACT_SIGNED/WON.
На CONTRACT_SIGNED/WON:

апдейт метрик конверсии (ROI) в PG;

флаг «пара может оставить отзыв».

VendorAvailability: CRUD; при изменении → публиковать событие в MQ.

Search (OpenSearch): подписан на событие из MQ; обновляет индекс; GET /search?eventDate=YYYY-MM-DD фильтрует доступных.

Персистентность: PostgreSQL/Prisma (Managed PostgreSQL DO; переменные окружения DATABASE_URL), OpenSearch — Managed (или Elastic-совместимый). RabbitMQ — внешний провайдер (CloudAMQP) или свой инстанс.

5) UX/Мобильность (минимум)

В frontend/pages/dashboard.tsx на мобиле: блок «Контроль follow-up» сразу под «Быстрая аналитика».

В frontend/styles/globals.css — медиа-правила @media (max-width: 640px) скрывают второстепенные поля карточек лида (оставить Имя, Приоритет, Статус, Телефон/Email). Таблицы — в 1 колонку.

6) Локализация/Финансы

RU/UZ (кириллица/латиница) — i18n на фронте (Next i18n routing или локальный i18n-пакет).

Валюта: UZS. Платежи: на фазе 3 — Uzcard/HUMO/Visa (интерфейсы/адаптеры заранее).

7) Документация/Код-стайл

Комментарии на русском (JSDoc/TSDoc на публичных методах).

Критические места (ROI-триггер, публикация в MQ) снабжать поясняющими строчными комментариями.

8) Нерушимые правила CI/CD (без PR)

Пуш напрямую в main (без PR).

На каждое изменение — автодеплой DO (включен deploy_on_push).

При изменениях во фронте, если DO «цепляется» за кэш, запускать Force Rebuild + Clear build cache.

Запрещено добавлять/сохранять в репо что-либо под frontend/pages/api/**, frontend/app/api/**.

9) (Опционально) Автофикс-скрипт для текущего репо

Введи целиком в Codex — он приведёт фронт к DO-safe состоянию, создаст health’и и положит do-app-spec.yaml:

#!/usr/bin/env bash
set -euo pipefail
REPO_URL="https://github.com/olegin77/weddingtech.git"
REPO_DIR="$HOME/weddingtech"
log(){ printf "\n\033[1;36m>> %s\033[0m\n" "$*"; }

log "sync repo"
if [ -d "$REPO_DIR/.git" ]; then cd "$REPO_DIR" && git fetch --all --prune && (git rebase --abort 2>/dev/null||true) && (git merge --abort 2>/dev/null||true) && git reset --hard origin/main;
else git clone --depth 1 "$REPO_URL" "$REPO_DIR" && cd "$REPO_DIR"; fi

log "purge Next API routes & legacy helpers"
git rm -r --ignore-unmatch frontend/pages/api || true
git rm -r --ignore-unmatch frontend/app/api   || true
git rm -f --ignore-unmatch frontend/lib/apiAuth.ts || true
git rm -f --ignore-unmatch frontend/pages/api/enquiries/export.ts || true

log "write tsconfig"
mkdir -p frontend
cat > frontend/tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["DOM", "ES2021"],
    "jsx": "preserve",
    "moduleResolution": "bundler",
    "baseUrl": ".",
    "paths": { "@/*": ["*"] },
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
JSON

log "normalize package.json"
node - <<'NODE'
const fs=require('fs'); const p='frontend/package.json';
const j=JSON.parse(fs.readFileSync(p,'utf8'));
j.scripts=Object.assign({build:"next build",start:"next start -p $PORT --hostname 0.0.0.0",dev:"next dev -p 3000"},j.scripts||{});
j.engines=Object.assign({node:"20.x",npm:"10.x"},j.engines||{});
j.dependencies=Object.assign({"next":"15.5.4","react":"18.3.1","react-dom":"18.3.1"},j.dependencies||{});
j.devDependencies=Object.assign({"typescript":"5.6.3","@types/react":"18.3.10","@types/react-dom":"18.3.0","@types/node":"20.12.12"},j.devDependencies||{});
j.overrides=Object.assign({"react":"18.3.1","react-dom":"18.3.1","@types/react":"18.3.10","@types/react-dom":"18.3.0"},j.overrides||{});
if (j.scripts && typeof j.scripts.preinstall==='string' && j.scripts.preinstall.includes('prune-legacy')) delete j.scripts.preinstall;
fs.writeFileSync(p,JSON.stringify(j,null,2)+'\n');
console.log('frontend/package.json updated');
NODE

log "SSR layouts"
mkdir -p frontend/app/vendors frontend/app/planner frontend/app/health frontend/pages
cat > frontend/app/vendors/layout.tsx <<'TSX'
import type { LayoutProps } from "next";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = 'force-no-store';
export const dynamicParams = true;
export default function VendorsLayout(props: LayoutProps<"/vendors">) { return <>{props.children}</>; }
TSX
cat > frontend/app/planner/layout.tsx <<'TSX'
import type { LayoutProps } from "next";
export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = 'force-no-store';
export const dynamicParams = true;
export default function PlannerLayout(props: LayoutProps<"/planner">) { return <>{props.children}</>; }
TSX

log "health & home"
cat > frontend/app/health/route.ts <<'TS'
import { NextResponse } from 'next/server';
export async function GET(){ return new NextResponse('OK',{status:200}); }
TS
cat > frontend/pages/health.tsx <<'TSX'
export default function Health(){ return <div>OK</div>; }
TSX
[ -f frontend/pages/index.tsx ] || cat > frontend/pages/index.tsx <<'TSX'
export default function Home(){ return (<main style={{padding:24,fontFamily:'system-ui,sans-serif'}}><h1>WeddingTech — Frontend OK</h1><ul><li><a href="/health">/health</a></li><li><a href="/api/health">/api/health</a></li><li><a href="/vendors/123">/vendors/[id] (пример)</a></li></ul></main>); }
TSX

log "DigitalOcean App Spec"
cat > do-app-spec.yaml <<'YAML'
name: weddingtech
features:
  - buildpack-stack=ubuntu-22
ingress:
  rules:
    - component: { name: backend }
      match: { path: { prefix: /api } }
    - component: { name: frontend }
      match: { path: { prefix: / } }
services:
  - name: frontend
    environment_slug: node-js
    github: { repo: olegin77/weddingtech, branch: main, deploy_on_push: true }
    source_dir: frontend
    build_command: "npm ci && npm run build"
    run_command: "next start -p $PORT --hostname 0.0.0.0"
    http_port: 8080
    instance_count: 1
    instance_size_slug: basic-xxs
    envs:
      - { key: NODE_ENV, value: "production" }
      - { key: NODE_VERSION, value: "20" }
      - { key: NEXT_TELEMETRY_DISABLED, value: "1" }
      - { key: NEXT_PUBLIC_API_BASE, value: "/api" }
      - { key: NPM_CONFIG_PRODUCTION, value: "false", scope: "BUILD_TIME" }
    health_check:
      http_path: "/health"
      initial_delay_seconds: 10
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
  - name: backend
    environment_slug: node-js
    github: { repo: olegin77/weddingtech, branch: main, deploy_on_push: true }
    source_dir: backend
    build_command: "npm ci"
    run_command: "npm run start"
    http_port: 8080
    instance_count: 1
    instance_size_slug: basic-xxs
    envs:
      - { key: NODE_ENV, value: "production" }
      - { key: NODE_VERSION, value: "20" }
    health_check:
      http_path: "/health"
      initial_delay_seconds: 5
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
YAML

log "final scan for forbidden imports"
left=0
grep -RIn --line-number "@/lib/apiAuth" frontend && left=1 || true
grep -RIn --line-number "@/lib/stores/enquiryStore" frontend && left=1 || true
if [ $left -ne 0 ]; then echo "НАЙДЕНЫ запрещённые импорты '@/lib/apiAuth' или '@/lib/stores/enquiryStore' во фронте — убери и перезапусти." >&2; exit 2; fi

git add -A
git commit -m "chore: DO-safe frontend (no Next API routes), typed SSR layouts, health, tsconfig/deps, DO spec" || true
git push origin main
echo "Готово. В DO: App → Settings → App Spec → Edit → вставь do-app-spec.yaml → Save & Deploy, затем Force Rebuild + Clear build cache."
