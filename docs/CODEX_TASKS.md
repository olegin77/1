# Tasks

- [ ] Тип деплоя: **из исходников** (GitHub repo), сборку и запуск определяет App Platform по `package.json`
- [ ] Требования:
- [ ] Сервис слушает **$PORT** на **0.0.0.0**
- [ ] Быстрый **/health** (200 OK, {status:"ok", db:true|false})
- [ ] Логи только stdout/stderr
- [ ] Миграции БД **на старте**: `prisma migrate deploy` (идемпотентно)
- [ ] В `package.json`:
- [ ] `"build"`: сборка прод-артефактов
- [ ] `"start"` (или `"start:prod"`): чтение `$PORT`, запуск сервера
- [ ] (Опционально) `"start:migrate"`: миграции + старт
- [x] Быстрый /health (200 OK, {status:"ok", db:true|false}) — 2025-10-15 02:48
- [x] Тип деплоя: из исходников (GitHub repo), сборку и запуск определяет App Platform по `package.json` — 2025-10-15 02:58
- [x] "build": сборка прод-артефактов — 2025-10-15 02:10
- [x] NODE_ENV=production, DATABASE_URL=<секрет>, PORT=<авто> — 2025-10-15 02:16
- [x] "start" (или "start:prod"): чтение $PORT, запуск сервера — 2025-10-15 02:20
- [x] Логи только stdout/stderr — 2025-10-15 02:05
- [x] Миграции БД на старте: prisma migrate deploy (идемпотентно) — 2025-10-15 01:40
- [x] Сервис слушает **$PORT** на **0.0.0.0** — 2025-10-15 02:00
