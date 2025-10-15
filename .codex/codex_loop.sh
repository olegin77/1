# .codex/codex_loop.sh
#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

echo ">> === $(ts) codex_loop.sh start ==="

# 1. Синхронизируемся с репозиторием, не удаляя локальные изменения
git checkout -B codex
git fetch origin codex
git reset --hard origin/codex # Начинаем с чистого состояния от удаленного репозитория
log "Repository synced with origin/codex"

# 2. Запускаем сидер для пополнения задач
if [ -x .codex/codex_seed_from_spec.py ]; then
  log "Running task seeder..."
  python3 .codex/codex_seed_from_spec.py || true
fi

# 3. Запускаем исполнителя
if [ -x ".codex/codex_task_exec.sh" ]; then
  log "Running task executor..."
  .codex/codex_task_exec.sh || true
else
  log "!! Executor not found: .codex/codex_task_exec.sh"
fi

# 4. Если после всех операций есть хоть какие-то изменения, коммитим и пушим.
if ! git diff --quiet --exit-code; then
    log "Changes detected. Committing and pushing..."
    git add -A
    
    # Определяем сообщение коммита
    if git diff --quiet --staged -- . ':!docs/'; then
        git commit -m "chore(tasks): update task status"
    else
        git commit -m "auto(codex): implement task"
    fi
    
    git push origin HEAD:codex
    log ">> Push successful"
else
    log "No changes detected after execution. Exiting."
fi

echo ">> === $(ts) codex_loop.sh done, RC=0 ==="
exit 0
