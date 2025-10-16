#!/usr/bin/env bash
# ВЕРСИЯ: BULLETPROOF-V8 (Обучен работе с Prisma)
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
    # ... (код этой функции без изменений)
    local text_to_mark="$1"; local temp_file; temp_file=$(mktemp)
    awk -v text="$text_to_mark" -v stamp="$(ts)" 'BEGIN{done=0} !done&&index($0,text){sub(/- \[ \]/,"- [x]");print $0" — "stamp; done=1; next} {print}' "$TASKS_FILE" > "$temp_file" && mv "$temp_file" "$TASKS_FILE"
    log "Task marked as done: '$text_to_mark'"
}

# --- Ядро Исполнителя ---

ensure_service_skeleton() {
    # ... (код этой функции без изменений)
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

# НОВОЕ УМЕНИЕ: Добавление скриптов Prisma в корневой package.json
add_prisma_scripts() {
    local root_pkg_json="$PROJECT_ROOT/package.json"
    log "ACTION: Adding prisma scripts to root package.json"
    
    # Используем Node.js для безопасного редактирования JSON
    node -e '
        const fs = require("fs");
        const pkgPath = process.argv[1];
        const pkg = JSON.parse(fs.readFileSync(pkgPath));
        pkg.scripts = pkg.scripts || {};
        pkg.scripts["prisma:migrate"] = "pnpm -w exec prisma migrate dev";
        pkg.scripts["prisma:generate"] = "pnpm -w exec prisma generate";
        fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + "\n");
    ' "$root_pkg_json"
    
    return 0 # Успех
}


# --- Основной Цикл ---
cd "$PROJECT_ROOT"

log ">> === CODEX LOOP START (ver: BULLETPROOF-V8) === <<"

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

ACTION_PERFORMED=0

# Правило №1: Создание каркаса
if [[ "$task_text" == *"Создать каркас NestJS-сервиса"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    log "STEP 3: Matched rule 'ensure_service_skeleton'"
    if ensure_service_skeleton "${BASH_REMATCH[1]}"; then ACTION_PERFORMED=1; fi

# НОВОЕ ПРАВИЛО №2: Добавление скриптов Prisma
elif [[ "$task_text" == *"Добавить миграции и скрипты"* ]] && [[ "$task_text" == *"`pnpm -w prisma:migrate`"* ]]; then
    log "STEP 3: Matched rule 'add_prisma_scripts'"
    if add_prisma_scripts; then ACTION_PERFORMED=1; fi

else
    log "STEP 3: No rule matched for this task. Marking as done to proceed."
fi

mark_done "$task_text"

log "STEP 4: Committing changes to Git..."
git add -A
git commit -m "auto(codex): $task_text"
git push origin HEAD:codex
log "STEP 5: Push to GitHub successful."

log ">> === CODEX LOOP DONE === <<"
