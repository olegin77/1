# .codex/codex_loop.sh
#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

echo ">> === $(ts) codex_loop.sh start ==="

# 1. Синхронизируемся с репозиторием
git fetch origin
git checkout -B codex origin/codex
git reset --hard origin/codex
log "Repository synced with origin/codex"

# 2. Запускаем сидер для пополнения задач (если нужно)
if [ -x .codex/codex_seed_from_spec.py ]; then
  log "Running task seeder..."
  python3 .codex/codex_seed_from_spec.py || true
  # Сразу коммитим новые задачи, если они появились
  if ! git diff --quiet --exit-code docs/CODEX_TASKS.md; then
    log "New tasks seeded. Committing..."
    git add docs/CODEX_TASKS.md
    git commit -m "auto(seed): add new tasks from spec"
    git push origin codex
    log "Pushed new tasks to origin."
  fi
fi

# 3. Запускаем исполнителя
if [ -x ".codex/codex_task_exec.sh" ]; then
  log "Running task executor..."
  .codex/codex_task_exec.sh || true
else
  log "!! Executor not found: .codex/codex_task_exec.sh"
fi

# 4. Проверяем, есть ли ВООБЩЕ какие-либо изменения после выполнения
if git diff --quiet --exit-code; then
    log "No changes made by executor. Exiting."
    echo ">> === $(ts) codex_loop.sh done (no changes) ==="
    exit 0
fi

# 5. Если изменения есть, коммитим и пушим ВСЁ.
log "Changes detected. Committing and pushing..."
git add -A

# Определяем сообщение коммита в зависимости от типа изменений
if git diff --quiet --staged -- . ':!docs/'; then
    git commit -m "chore(tasks): update task status"
else
    git commit -m "auto(codex): implement task"
fi

git push origin HEAD:codex
log ">> Push successful"


echo ">> === $(ts) codex_loop.sh done, RC=0 ==="
exit 0

