#!/usr/bin/env bash
set -Eeuo pipefail

export TZ=:Asia/Tashkent

ts(){ date '+%F %T %z'; }
echo ">> === $(ts) codex_loop.sh start (exec-tasks) ==="

# 0) чистый git в ветке codex
git fetch --prune origin
git checkout -B codex origin/codex
git pull --ff-only origin codex || { git reset --hard origin/codex; git clean -fdx; }

# 1) сидер — дозаправка задач из TECH_SPEC (без дублей)
mkdir -p docs
[ -f docs/TECH_SPEC.md ] || : > docs/TECH_SPEC.md
[ -f docs/CODEX_TASKS.md ] || printf "# Tasks\n\n" > docs/CODEX_TASKS.md

python3 .codex/codex_seed_from_spec.py || true
git add docs/CODEX_TASKS.md
git commit -m "auto(seed): задачи из TECH_SPEC (threshold)" || true

# 2) исполнитель — реальный код по первой открытой задаче
echo ">> executing first open task"
before="$(git status --porcelain)"
if [ -x ".codex/codex_task_exec.sh" ]; then
  .codex/codex_task_exec.sh || true
else
  echo "!! executor not found: .codex/codex_task_exec.sh"
fi
after="$(git status --porcelain)"

# 3) коммитим ТОЛЬКО если есть изменения (никаких авто-галочек)
if [[ "$before" != "$after" ]]; then
  git add -A
  git commit -m "auto(codex): iteration" || true
  git push origin HEAD:codex
  echo ">> commit & push done"
else
  echo ">> no changes by executor; skipping commit"
fi

echo ">> === $(ts) codex_loop.sh done, RC=0 ==="
exit 0
