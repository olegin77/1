#!/usr/bin/env bash
# ВЕРСИЯ: THE-FINAL-ONE
set -Eeuo pipefail

# --- Глобальная ловушка ошибок ---
trap 'log "!!! FATAL ERROR: Script exited on line $LINENO with status $?."' ERR

export TZ=:Asia/Tashkent
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
TASKS_FILE="$PROJECT_ROOT/docs/CODEX_TASKS.md"

# --- Утилиты ---
ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }

mark_done(){
    local text_to_mark="$1"; local temp_file; temp_file=$(mktemp)
    awk -v text="$text_to_mark" -v stamp="$(ts)" 'BEGIN{done=0} !done&&index($0,text){sub(/- \[ \]/,"- [x]");print $0" — "stamp; done=1; next} {print}' "$TASKS_FILE" > "$temp_file" && mv "$temp_file" "$TASKS_FILE"
    log "Task marked as done: '$text_to_mark'"
}

# --- Ядро Исполнителя ---

ensure_service_skeleton() {
    local svc_name="$1"; local app_dir="$PROJECT_ROOT/apps/$svc_name"; [ -d "$app_dir" ] && return 1
    log "ACTION: Scaffolding new service: $svc_name"; mkdir -p "$app_dir/src/health"
    cp "$PROJECT_ROOT/apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
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

ensure_prisma_model() {
    local svc_name="$1"; local model_info="$2"; local schema_path="$PROJECT_ROOT/apps/$svc_name/prisma/schema.prisma"
    log "ACTION: Ensuring Prisma model in $schema_path"; mkdir -p "$(dirname "$schema_path")"
    if [ ! -f "$schema_path" ]; then
        cat > "$schema_path" <<EOF
datasource db { provider = "postgresql"; url = env("DATABASE_URL") }
generator client { provider = "prisma-client-js" }
EOF
    fi
    local model_name; model_name=$(echo "$model_info" | grep "model" | awk '{print $2}')
    if grep -q "model $model_name" "$schema_path"; then return 1; fi
    echo -e "\n$model_info" >> "$schema_path"; log "Model '$model_name' added to $schema_path"; return 0
}

# --- Основной Цикл ---
cd "$PROJECT_ROOT"
log ">> === CODEX LOOP START (ver: THE-FINAL-ONE) === <<"

git fetch origin; git reset --hard origin/codex
log "STEP 1: Repo synced with origin/codex"

first_task_line=$(grep -m 1 -- '- \[ \]' "$TASKS_FILE" || echo "")
if [[ -z "$first_task_line" ]]; then
    log "STEP 2: No open tasks found. Project is complete. Exiting."
    exit 0
fi
task_title=$(echo "$first_task_line" | sed -e 's/^- \[ \] //' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
log "STEP 2: Found task to execute: '$task_title'"

ACTION_PERFORMED=0

# Правило №1: Создание каркаса
if [[ "$task_title" == *"Создать каркас NestJS-сервиса"* ]] && [[ "$task_title" =~ (svc-[a-z-]+) ]]; then
    log "STEP 3: Matched rule 'ensure_service_skeleton'"
    if ensure_service_skeleton "${BASH_REMATCH[1]}"; then ACTION_PERFORMED=1; fi

# Правило №2: Работа с моделями Prisma
elif [[ "$task_title" == *"Prisma"* ]] && [[ "$task_title" =~ \(svc-([a-z-]+)\) ]]; then
    log "STEP 3: Matched rule 'ensure_prisma_model'"
    svc_name="${BASH_REMATCH[1]}"
    # Надежно извлекаем многострочный блок 'model ... { ... }' из файла задач
    # sed -n "/Шаблон начала/,/Шаблон конца/p"
    model_definition=$(sed -n "/${task_title//\*/\\\*}/,/\`\`\`/p" "$TASKS_FILE" | grep -v -- '- \[ \]' | sed -e 's/```//g' -e '/^\s*$/d')
    if [[ -n "$model_definition" ]]; then
        if ensure_prisma_model "$svc_name" "$model_definition"; then ACTION_PERFORMED=1; fi
    else
        log "WARNING: Could not extract model definition for task '$task_title'"
    fi
    
else
    log "STEP 3: No rule matched for '$task_title'. Marking as done to proceed."
fi

mark_done "$task_title"

log "STEP 4: Committing changes to Git..."
git add -A
git commit -m "auto(codex): $task_title"
git push origin HEAD:codex
log "STEP 5: Push to GitHub successful."

log ">> === CODEX LOOP DONE === <<"
