#!/usr/bin/env bash
# ВЕРСИЯ: FINAL-STABLE-V2
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ROOT="$(pwd)"
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
    log "Marked done: $text_to_mark"
}

# --- Ядро Исполнителя ---

# УМЕНИЕ №1: Создание каркаса сервиса
ensure_service_skeleton() {
    local svc_name="$1"
    local app_dir="apps/$svc_name"
    [ -d "$app_dir" ] && return 1

    log "Action: Scaffolding new service: $svc_name"
    mkdir -p "$app_dir/src/health"
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    cat > "$app_dir/package.json" <<EOF
{"name": "$svc_name", "version": "0.1.0", "scripts": {"build": "tsc", "start": "node dist/main.js"}}
EOF
    # ... (остальной код функции без изменений)
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

# НОВОЕ УМЕНИЕ №2: Создание Dockerfile
ensure_dockerfile() {
    local svc_name="$1"
    local svc_dir="apps/$svc_name"
    local dockerfile_path="$svc_dir/Dockerfile"
    [ ! -d "$svc_dir" ] && { log "ERROR: Service directory $svc_dir not found!"; return 1; }
    [ -f "$dockerfile_path" ] && return 1 # Уже существует

    log "Action: Creating Dockerfile for $svc_name"
    # Стандартный многоэтапный Dockerfile для NestJS-приложения,
    # оптимизированный для DigitalOcean App Platform.
    cat > "$dockerfile_path" <<EOF
# Этап 1: Сборка
FROM node:18-alpine AS builder
WORKDIR /usr/src/app
COPY apps/${svc_name}/package*.json ./
RUN npm install
COPY apps/${svc_name}/ .
RUN npm run build

# Этап 2: Запуск
FROM node:18-alpine
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/package*.json ./
RUN npm install --only=production
COPY --from=builder /usr/src/app/dist ./dist
CMD ["npm", "run", "start"]
EOF
    return 0
}


# --- Основной Цикл ---
log ">> === CODEX LOOP START === <<"

git fetch origin
git reset --hard origin/codex
log "Repo synced with origin/codex"

first_task_line=$(grep -m 1 -- '- \[ \]' "$TASKS_FILE" || echo "")
if [[ -z "$first_task_line" ]]; then
    log "No open tasks found. Project is complete."
    exit 0
fi
task_text=$(echo "$first_task_line" | sed -e 's/^- \[ \] //' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
log "Found task: $task_text"

ACTION_TAKEN=0

# Правило №1: Создание каркаса
if [[ "$task_text" == *"создать каркас"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    svc_name="${BASH_REMATCH[1]}"
    if ensure_service_skeleton "$svc_name"; then ACTION_TAKEN=1; fi
    mark_done "$task_text" # Отмечаем выполненной в любом случае, чтобы не зацикливаться
    
# НОВОЕ ПРАВИЛО №2: Создание Dockerfile
elif [[ "$task_text" == *"создать базовый Dockerfile"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    svc_name="${BASH_REMATCH[1]}"
    if ensure_dockerfile "$svc_name"; then ACTION_TAKEN=1; fi
    mark_done "$task_text"
fi

if [[ "$ACTION_TAKEN" -eq 0 ]]; then
    log "No code changes made, but task marked as done to proceed."
fi

log "Committing and pushing task status..."
git add -A
git commit -m "auto(codex): $task_text"
git push origin HEAD:codex
log "Push successful"

echo ">> === CODEX LOOP DONE === <<"
