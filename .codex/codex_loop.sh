#!/usr/bin/env bash
set -Eeuo pipefail
export TZ=:Asia/Tashkent

ROOT="$(pwd)"
TASKS_FILE="docs/CODEX_TASKS.md"

# --- Утилиты ---
ts(){ date '+%F %T %z'; }
log(){ echo >&2 "[$(ts)] $*"; }
mark_done(){
    local text_to_mark="$1"
    # Эта команда надежно найдет и заменит первую строку с нужным текстом
    # и добавит timestamp.
    local temp_file=$(mktemp)
    awk -v text="$text_to_mark" -v stamp="$(ts)" '
        BEGIN { done=0 }
        !done && $0 ~ text {
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
ensure_service_skeleton() {
    local svc_name="$1"
    local app_dir="apps/$svc_name"
    [ -d "$app_dir" ] && return 1 # Уже существует, выходим с ошибкой

    log "Action: Scaffolding new service: $svc_name"
    mkdir -p "$app_dir/src/health"
    
    # Создаем файлы...
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    cat > "$app_dir/package.json" <<EOF
{"name": "$svc_name", "version": "0.1.0", "scripts": {"build": "tsc", "start": "node dist/main.js"}}
EOF
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
    
    return 0 # Успех
}

# --- Основной Цикл ---
log ">> === CODEX LOOP START === <<"

git fetch origin
git reset --hard origin/codex
log "Repo synced with origin/codex"

# 1. Находим первую невыполненную задачу
first_task_line=$(grep -m 1 -- '- \[ \]' "$TASKS_FILE" || echo "")
if [[ -z "$first_task_line" ]]; then
    log "No open tasks found. Exiting."
    exit 0
fi
task_text=$(echo "$first_task_line" | sed -e 's/^- \[ \] //' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
log "Found task: $task_text"

# 2. Определяем, что делать, и выполняем
ACTION_TAKEN=0

if [[ "$task_text" =~ Создать\ каркас\ для\ сервиса\ (svc-[\w-]+) ]]; then
    svc_name="${BASH_REMATCH[1]}"
    if ensure_service_skeleton "$svc_name"; then
        mark_done "$task_text"
        ACTION_TAKEN=1
    else
        log "Service skeleton for $svc_name likely already exists. Marking as done to prevent loop."
        mark_done "$task_text"
        ACTION_TAKEN=1
    fi
fi
# Сюда можно будет добавлять другие 'elif' для новых типов задач

# 3. Если задача не была распознана, выходим
if [[ "$ACTION_TAKEN" -eq 0 ]]; then
    log "No rule matched for task: '$task_text'. Waiting for human intervention."
    exit 0
fi

# 4. Сохраняем результат
log "Changes detected. Committing and pushing..."
git add -A
git commit -m "auto(codex): $task_text"
git push origin HEAD:codex
log "Push successful"

echo ">> === CODEX LOOP DONE (task completed) === <<"
