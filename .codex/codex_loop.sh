#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ROOT="$(pwd)"
TASKS_FILE="docs/CODEX_TASKS.md"

# --- Утилиты ---
ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }
mark_done(){
    local pattern="$1"
    local stamp; stamp="$(date '+%Y-%m-%d %H:%M')"
    # Используем sed для надежной замены в файле
    sed -i "0,/- \[ \] .*${pattern}/s|- \[ \] |- [x] |; t; d" "$TASKS_FILE"
    sed -i "s/\(^- \[x\] .*${pattern}\)\$/\1 — ${stamp}/" "$TASKS_FILE"
    log "Marked done: $pattern"
}

# --- Ядро Исполнителя ---
ensure_service_skeleton() {
    local svc_name="$1"
    local app_dir="apps/$svc_name"
    [ -d "$app_dir" ] && return 1

    log "Action: Scaffolding new service: $svc_name"
    mkdir -p "$app_dir/src/health"
    
    cat > "$app_dir/package.json" <<EOF
{"name": "$svc_name", "version": "0.1.0", "scripts": {"build": "tsc", "start": "node dist/main.js"}}
EOF
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    
    cat > "$app_dir/src/main.ts" <<TS
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  await app.listen(process.env.PORT || 3000, '0.0.0.0');
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
export class HealthController { @Get() ok() { return { status: 'ok' }; } }
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

# 1. Находим первую невыполненную задачу
first_task=$(grep -m 1 -- '- \[ \]' "$TASKS_FILE" || echo "")
if [[ -z "$first_task" ]]; then
    log "No open tasks found. Exiting."
    exit 0
fi
log "Found task: $first_task"

# 2. Определяем, что делать
ACTION_TAKEN=0
task_text=$(echo "$first_task" | sed 's/- \[ \] //')

if [[ "$task_text" =~ Создать\ каркас\ для\ сервиса\ (svc-[\w-]+) ]]; then
    svc_name="${BASH_REMATCH[1]}"
    if ensure_service_skeleton "$svc_name"; then
        mark_done "$task_text"
        ACTION_TAKEN=1
    else
        log "Service skeleton for $svc_name likely already exists. Marking as done to prevent loop."
        mark_done "$task_text"
        ACTION_TAKEN=1 # Мы предприняли действие - отметили задачу выполненной
    fi
fi

# 3. Если ничего не было сделано, выходим
if [[ "$ACTION_TAKEN" -eq 0 ]]; then
    log "No rule matched for task: $task_text. Waiting for human intervention."
    exit 0
fi

# 4. Сохраняем результат
log "Changes detected. Committing and pushing..."
git add -A
git commit -m "auto(codex): ${task_text}"
git push origin HEAD:codex
log "Push successful"

echo ">> === CODEX LOOP DONE (task completed) === <<"
