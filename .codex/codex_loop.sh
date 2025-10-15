#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ROOT="$(pwd)"
TASKS_FILE="docs/CODEX_TASKS.md"
SPEC_FILE="docs/TECH_SPEC.md"

# --- Утилиты ---
ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

# --- Ядро Исполнителя ---
ensure_service_skeleton() {
    local svc_name="$1"
    local app_dir="apps/$svc_name"
    [ -d "$app_dir" ] && return 1

    log "Action: Scaffolding new service: $svc_name"
    mkdir -p "$app_dir/src/health"
    
    # package.json и другие файлы...
    cat > "$app_dir/package.json" <<EOF
{
  "name": "$svc_name",
  "version": "0.1.0",
  "private": true,
  "scripts": { "build": "tsc -p tsconfig.build.json", "start": "node dist/main.js" },
  "engines": { "node": ">=18" }
}
EOF
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    cp "apps/svc-enquiries/tsconfig.build.json" "$app_dir/tsconfig.build.json"
    
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

    cat > "$app_dir/src/app.module.ts" <<TS
import { Module } from '@nestjs/common';
import { HealthModule } from './health/health.module';
@Module({ imports: [HealthModule] })
export class AppModule {}
TS

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
    
    return 0
}

# --- Основной Цикл ---
log ">> === CODEX LOOP START === <<"

git fetch origin
git reset --hard origin/codex
log "Repo synced with origin/codex"

declare -A COMPLETED_TASKS
while IFS= read -r line; do
    if [[ "$line" =~ ^-\ \[x\]\ (.+) ]]; then
        task_text=$(echo "${BASH_REMATCH[1]}" | sed -E 's/\s—\s[0-9-]+.*//' | xargs)
        COMPLETED_TASKS["$task_text"]=1
    fi
done < "$TASKS_FILE"
log "Read ${#COMPLETED_TASKS[@]} completed tasks"

NEXT_ACTION=""
NEXT_ACTION_DESC=""

while IFS= read -r svc_name; do
    task_desc="Создать каркас для сервиса $svc_name"
    # *** ИСПРАВЛЕНИЕ ЗДЕСЬ ***
    # Правильная проверка на существование ключа в ассоциативном массиве
    if ! [[ -v "COMPLETED_TASKS[$task_desc]" ]]; then
        NEXT_ACTION="ensure_service_skeleton $svc_name"
        NEXT_ACTION_DESC="$task_desc"
        break
    fi
done < <(grep -oE 'svc-[\w-]+' "$SPEC_FILE" | sort -u)

if [[ -z "$NEXT_ACTION" ]]; then
    log "No new actions found. Project is up to date."
    echo ">> === CODEX LOOP DONE (no new actions) === <<"
    exit 0
fi

log "Next action determined: $NEXT_ACTION_DESC"

CHANGES_MADE=0
# Выполняем действие; если оно возвращает 1 (уже существует), то CHANGES_MADE останется 0
eval "$NEXT_ACTION" || CHANGES_MADE=0 && CHANGES_MADE=1

if [[ "$CHANGES_MADE" -eq 0 ]]; then
    log "Action resulted in no changes. Skipping."
    echo "- [x] $NEXT_ACTION_DESC — $(ts)" >> "$TASKS_FILE"
    git add "$TASKS_FILE"
    git commit -m "chore(tasks): skip already completed task"
    git push origin HEAD:codex
    echo ">> === CODEX LOOP DONE (skipped task) === <<"
    exit 0
fi

log "Action executed successfully. Updating tasks and committing."
STAMP="$(ts)"

echo "- [x] $NEXT_ACTION_DESC — $STAMP" >> "$TASKS_FILE"
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
