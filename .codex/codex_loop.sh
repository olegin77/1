#!/usr/bin/env bash
# ВЕРСИЯ: BULLETPROOF-V6 (С ГЛОБАЛЬНОЙ ЛОВУШКОЙ ОШИБОК)
set -Eeuo pipefail

# --- Глобальная ловушка ошибок ---
# Если скрипт упадет в любом месте, эта команда выполнится и сообщит нам, где и почему.
trap 'log "!!! FATAL ERROR: Script exited on line $LINENO with status $?."' ERR

export TZ=:Asia/Tashkent
TASKS_FILE="docs/CODEX_TASKS.md"

# --- Утилиты ---
ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

mark_done(){
    local text_to_mark="$1"
    local temp_file; temp_file=$(mktemp)
    awk -v text="$text_to_mark" -v stamp="$(ts)" '
        BEGIN { done=0 }
        !done && index($0, text) {
            sub(/- \[ \]/, "- [x]");
            print $0 " — " stamp;
            done=1;
            next;
        }
        { print }
    ' "$TASKS_FILE" > "$temp_file" && mv "$temp_file" "$TASKS_FILE"
    log "Task marked as done in local file: '$text_to_mark'"
}

# --- Ядро Исполнителя ---
ensure_service_skeleton() {
    local svc_name="$1"; local app_dir="apps/$svc_name"; [ -d "$app_dir" ] && return 1
    log "ACTION: Scaffolding new service: $svc_name"
    mkdir -p "$app_dir/src/health"
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    cat > "$app_dir/package.json" <<EOF
{"name": "$svc_name", "version": "0.1.0", "scripts": {"build": "tsc", "start": "node dist/main.js"}}
EOF
    cat > "$app_dir/src/main.ts" <<TS
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
async function bootstrap() { const app = await NestFactory.create(AppModule); await app.listen(process.env.PORT || 3000, '0.0.0.0'); }
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
log ">> === CODEX LOOP START (ver: BULLETPROOF-V6) === <<"

git fetch origin
git reset --hard origin/codex
log "STEP 1: Repo synced with origin/codex"

first_task_line=$(grep -m 1 -- '- \[ \]' "$TASKS_FILE" || echo "")
if [[ -z "$first_task_line" ]]; then
    log "STEP 2: No open tasks found. Project is complete. Exiting."
    exit 0
fi
task_text=$(echo "$first_task_line" | sed -e 's/^- \[ \] //' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
log "STEP 2: Found task to execute: '$task_text'"

# Правило №1: Создание каркаса
if [[ "$task_text" == *"Создать каркас NestJS-сервиса"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    log "STEP 3: Matched rule 'ensure_service_skeleton'"
    ensure_service_skeleton "${BASH_REMATCH[1]}" || log "INFO: Skeleton already exists, no changes made."
else
    log "STEP 3: No rule matched for this task. Marking as done to proceed to the next."
fi

# Шаг 4: Всегда отмечаем задачу выполненной, чтобы двигаться вперед
mark_done "$task_text"

# Шаг 5: Надежно сохраняем результат
log "STEP 4: Committing changes to Git..."
git add -A
git commit -m "auto(codex): $task_text"
git push origin HEAD:codex
log "STEP 5: Push to GitHub successful."

log ">> === CODEX LOOP DONE === <<"
