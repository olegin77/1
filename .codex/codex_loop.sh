#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ROOT="$(pwd)"
TASKS_FILE="docs/CODEX_TASKS.md"
SPEC_FILE="docs/TECH_SPEC.md"

# --- Утилиты ---
ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

# --- Ядро Исполнителя (бывшие "правила") ---
# Эти функции будут вызываться на основе анализа ТЗ
ensure_service_skeleton() {
    local svc_name="$1"
    local app_dir="apps/$svc_name"
    [ -d "$app_dir" ] && return 1 # Уже существует

    log "Action: Scaffolding new service: $svc_name"
    mkdir -p "$app_dir/src/health"
    
    # package.json
    cat > "$app_dir/package.json" <<EOF
{
  "name": "$svc_name",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "build": "tsc -p tsconfig.build.json",
    "start": "node dist/main.js",
    "prisma:generate": "prisma generate"
  },
  "engines": { "node": ">=18" }
}
EOF

    # tsconfig.json
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    cp "apps/svc-enquiries/tsconfig.build.json" "$app_dir/tsconfig.build.json"
    
    # main.ts
    cat > "$app_dir/src/main.ts" <<TS
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');
  Logger.log(\`🚀 Service $svc_name listening on \${port}\`, 'Bootstrap');
}
bootstrap();
TS

    # app.module.ts
    cat > "$app_dir/src/app.module.ts" <<TS
import { Module } from '@nestjs/common';
import { HealthModule } from './health/health.module';
@Module({ imports: [HealthModule] })
export class AppModule {}
TS

    # Health Module
    cat > "$app_dir/src/health/health.controller.ts" <<TS
import { Controller, Get } from '@nestjs/common';
@Controller('health')
export class HealthController { @Get() getHealth() { return { status: 'ok' }; } }
TS
    cat > "$app_dir/src/health/health.module.ts" <<TS
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
@Module({ controllers: [HealthController] })
export class HealthModule {}
TS
    
    return 0 # Успех
}

# --- Основной Цикл ---
log ">> === CODEX LOOP START === <<"

# 1. Синхронизация с Git
git fetch origin
git reset --hard origin/codex
log "Repo synced with origin/codex"

# 2. Чтение состояния (что уже сделано)
declare -A COMPLETED_TASKS
while IFS= read -r line; do
    if [[ "$line" =~ ^-\ \[x\]\ (.+) ]]; then
        task_text=$(echo "${BASH_REMATCH[1]}" | sed -E 's/\s—\s[0-9-]+.*//' | xargs)
        COMPLETED_TASKS["$task_text"]=1
    fi
done < "$TASKS_FILE"
log "Read ${#COMPLETED_TASKS[@]} completed tasks from $TASKS_FILE"

# 3. Анализ ТЗ и принятие решения
NEXT_ACTION=""
NEXT_ACTION_DESC=""

# Ищем сервисы в ТЗ, которых еще нет
while IFS= read -r svc_name; do
    task_desc="Создать каркас для сервиса $svc_name"
    if [[ -z "${COMPLETED_TASKS[$task_desc]}" ]]; then
        NEXT_ACTION="ensure_service_skeleton $svc_name"
        NEXT_ACTION_DESC="$task_desc"
        break
    fi
done < <(grep -oE 'svc-[\w-]+' "$SPEC_FILE" | sort -u)

# Если нашли, что делать, то выходим из анализа
if [[ -n "$NEXT_ACTION" ]]; then
    log "Next action determined: $NEXT_ACTION_DESC"
else
    log "No new actions found based on TECH_SPEC. Project is up to date."
    echo ">> === CODEX LOOP DONE (no new actions) === <<"
    exit 0
fi

# 4. Исполнение
CHANGES_MADE=0
eval "$NEXT_ACTION" && CHANGES_MADE=1

if [[ "$CHANGES_MADE" -eq 0 ]]; then
    log "Action was determined, but resulted in no changes. Skipping."
    # Отмечаем задачу как выполненную, чтобы не зацикливаться
    echo "- [x] $NEXT_ACTION_DESC — $(ts)" >> "$TASKS_FILE"
    git add "$TASKS_FILE"
    git commit -m "chore(tasks): skip already completed task"
    git push origin HEAD:codex
    echo ">> === CODEX LOOP DONE (skipped task) === <<"
    exit 0
fi

# 5. Отчетность и сохранение
log "Action executed successfully. Updating tasks and committing."
STAMP="$(ts)"

# Добавляем отметку о выполнении
echo "- [x] $NEXT_ACTION_DESC — $STAMP" >> "$TASKS_FILE"

# Добавляем отчет в конец файла
{
    echo ""
    echo "## Отчёт — $STAMP"
    echo "Выполнена задача: **$NEXT_ACTION_DESC**."
    echo "Внесены изменения в следующие файлы:"
    git status --porcelain | sed 's/^/ - /'
} >> "$TASKS_FILE"

git add -A
git commit -m "auto(codex): $NEXT_ACTION_DESC"
git push origin HEAD:codex
log "Push successful"

echo ">> === CODEX LOOP DONE (task completed) === <<"
