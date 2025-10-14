# .codex/codex_loop.sh
#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ts(){ date '+%F %T %z'; }

echo ">> === $(ts) codex_loop.sh start (exec-tasks) ==="

git fetch --prune origin
git checkout -B codex origin/codex
git pull --ff-only origin codex || { git reset --hard origin/codex; git clean -fdx; }

# сидер — дозаправка задач (если нужен; файл существует — ок)
if [ -x .codex/codex_seed_from_spec.py ]; then
  python3 .codex/codex_seed_from_spec.py || true
  git add docs/CODEX_TASKS.md || true
  git commit -m "auto(seed): задачи из TECH_SPEC (threshold)" || true
fi

echo ">> executing first open task"
before="$(git status --porcelain)"
if [ -x ".codex/codex_task_exec.sh" ]; then
  .codex/codex_task_exec.sh || true
else
  echo "!! executor not found: .codex/codex_task_exec.sh"
fi
after="$(git status --porcelain)"

# коммитим ТОЛЬКО если есть изменения НЕ в docs/
if git diff --name-only | grep -qvE '^(docs/|README|LICENSE)'; then
  git add -A
  git commit -m "auto(codex): iteration" || true
  git push origin HEAD:codex
  echo ">> commit & push done"
else
  echo ">> only docs changed; skipping commit"
fi

echo ">> === $(ts) codex_loop.sh done, RC=0 ==="
exit 0

