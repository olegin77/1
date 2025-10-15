# .codex/codex_loop.sh
#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

echo ">> === $(ts) codex_loop.sh start ==="

# 1. Жестко синхронизируемся, чтобы предотвратить ошибки "local changes would be overwritten"
git fetch origin
git reset --hard origin/codex
log "Repository synced with origin/codex"

# 2. Запускаем сидер для пополнения задач
if [ -x .codex/codex_seed_from_spec.py ]; then
  log "Running task seeder..."
  python3 .codex/codex_seed_from_spec.py || true
fi

# 3. Запускаем исполнителя для выполнения одной задачи
if [ -x ".codex/codex_task_exec.sh" ]; then
  log "Running task executor..."
  .codex/codex_task_exec.sh || true
else
  log "!! Executor not found: .codex/codex_task_exec.sh"
fi

# 4. Проверяем, есть ли ВООБЩЕ какие-либо изменения
if git diff --quiet --exit-code; then
    log "No changes detected after execution. Exiting."
    echo ">> === $(ts) codex_loop.sh done (no changes) ==="
    exit 0
fi

# 5. Если изменения есть, определяем, нужно ли пушить.
# `git diff --quiet HEAD -- . ':!docs/'` проверяет, есть ли изменения вне папки docs/
if git diff --quiet HEAD -- . ':!docs/'; then
    # Изменения только в docs/. Делаем локальный коммит, но не пушим.
    log "Only doc changes found. Committing locally without push."
    git add docs/
    git commit -m "chore(tasks): update task status" || true
else
    # Есть изменения в коде. Коммитим всё и пушим.
    log "Code changes detected. Committing and pushing."
    git add -A
    git commit -m "auto(codex): implement task" || true
    git push origin HEAD:codex
    log ">> Push successful"
fi

echo ">> === $(ts) codex_loop.sh done, RC=0 ==="
exit 0

