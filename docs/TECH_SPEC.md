<!-- policy:do_not_ask_for_approvals -->
<!-- policy:non_interactive_mode=on -->
<!-- policy:if_uncertain_choose_most_conservative_non_destructive_action -->
<!-- policy:commit_unit=per_task -->
<!-- policy:rollback_on_failure=leave_task_unchecked -->

# WeddingTech UZ — Техническое задание (v0.1)

## 1. Цели и KPI
- Упростить коммуникацию «пара ↔ поставщики».
- Сократить цикл сделки до ≤ 7 дней.
- NPS ≥ 60, TTFB сайта ≤ 100 мс (UAE), аптайм ≥ 99.9%.

## 2. MVP-объём
- B2C: сайт пары (slug), публичный RSVP, списки гостей/столы/бюджет.
- B2B: профиль поставщика, площадки, офферы, календарь занятости.
- Заявки/переписка, отзывы с модерацией, рейтинг/ранжирование.

## 3. Архитектура
- Монорепо (apps/*, packages/*, infra/*).
- Микросервисы: `svc-auth`, `svc-enquiries`, `svc-vendors`, `svc-catalog`, `svc-guests`, `svc-website`, `admin`, `svc-analytics`, `svc-mail`, `svc-payments`, `seeder`.
- Хранилища: Postgres, Redis, MinIO. Очереди позже (опц.).

## 4. Модели данных (Prisma)
- См. `packages/prisma/schema.prisma` (User, Couple, Vendor, Venue, AvailabilitySlot, Enquiry, Review, Guest, Table, BudgetItem, Website, RSVP, AuditEvent, RankSignal).

## 5. API контуры (минимум)
- `/health` на каждом сервисе.
- Auth: `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh` (после реализации).
- Vendors: `GET /vendors/:id`, `POST /vendors` (после реализации).
- Enquiries: `POST /enquiries`, `GET /enquiries/:id` (после реализации).

## 6. Нефункциональные требования
- Идемпотентность задач Codex, один коммит на задачу.
- Локализация RU/UZ, базовые UI-компоненты.
- Логи/аудит: `packages/logger`, таблица `AuditEvent`.
- Безопасность: ESLint/tsconfig, no secrets в Git.

## 7. CI/CD
- Ветка разработки агента: `codex` → авто-PR → `main`.
- CI: lint/test/build на каждом пуше в `codex`.
- Deploy (опционально) с `main`.

## 8. Definition of Done (DoD)
- Задача отмечена `[x]`, тест/смоук пройден, схема/миграции актуальны, логика идемпотентна.

