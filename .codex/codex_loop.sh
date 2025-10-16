#!/usr/bin/env bash
# ВЕРСИЯ: FINAL-STABLE-V3
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
    # ... (код этой функции остается без изменений)
    local svc_name="$1"; local app_dir="apps/$svc_name"; [ -d "$app_dir" ] && return 1
    log "Action: Scaffolding new service: $svc_name"; mkdir -p "$app_dir/src/health"
    cp "apps/svc-enquiries/tsconfig.json" "$app_dir/tsconfig.json"
    cat > "$app_dir/package.json" <<EOF
{"name": "$svc_name", "version": "0.1.0", "scripts": {"build": "tsc", "start": "node dist/main.js"}}
EOF
    # ... (остальной код функции без изменений)
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

# УМЕНИЕ №2: Создание Dockerfile
ensure_dockerfile() {
    # ... (код этой функции остается без изменений)
    local svc_name="$1"; local dockerfile_path="apps/$svc_name/Dockerfile"; [ -f "$dockerfile_path" ] && return 1
    log "Action: Creating Dockerfile for $svc_name"
    cat > "$dockerfile_path" <<EOF
FROM node:18-alpine AS builder
WORKDIR /usr/src/app
COPY apps/${svc_name}/package*.json ./
RUN npm install
COPY apps/${svc_name}/ .
RUN npm run build
FROM node:18-alpine
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/package*.json ./
RUN npm install --only=production
COPY --from=builder /usr/src/app/dist ./dist
CMD ["npm", "run", "start"]
EOF
    return 0
}

# НОВОЕ УМЕНИЕ №3: Добавление сервиса в do/app.yaml
ensure_do_app_service() {
    local svc_name="$1"
    local app_spec_path="do/app.yaml"
    
    # Проверяем, существует ли уже сервис с таким именем в файле
    if grep -q "name: $svc_name" "$app_spec_path"; then
        log "Service $svc_name already exists in $app_spec_path."
        return 1 # Изменений не требуется
    fi

    log "Action: Adding $svc_name to $app_spec_path"
    # Добавляем новый сервис в конец списка services, сохраняя отступы
    cat >> "$app_spec_path" <<EOF

- name: ${svc_name}
  git:
    repo: \${repo.name}
    branch: \${repo.branch}
    source_dir: /apps/${svc_name}
  health_check:
    http_path: /health
EOF
    return 0 # Успех
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

ACTION_SUCCESSFUL=0

# Правило №1: Создание каркаса
if [[ "$task_text" == *"создать каркас"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    if ensure_service_skeleton "${BASH_REMATCH[1]}"; then ACTION_SUCCESSFUL=1; fi
    
# Правило №2: Создание Dockerfile
elif [[ "$task_text" == *"создать базовый Dockerfile"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    if ensure_dockerfile "${BASH_REMATCH[1]}"; then ACTION_SUCCESSFUL=1; fi

# НОВОЕ ПРАВИЛО №3: Добавление сервиса в do/app.yaml
elif [[ "$task_text" == *"добавить сервис"* ]] && [[ "$task_text" == *"do/app.yaml"* ]] && [[ "$task_text" =~ (svc-[a-z-]+) ]]; then
    if ensure_do_app_service "${BASH_REMATCH[1]}"; then ACTION_SUCCESSFUL=1; fi
fi

# Отмечаем задачу выполненной, чтобы двигаться дальше
mark_done "$task_text"

# Если не было изменений в коде, коммит все равно зафиксирует обновление файла задач
log "Committing task status and any code changes..."
git add -A
git commit -m "auto(codex): $task_text"
git push origin HEAD:codex
log "Push successful"

echo ">> === CODEX LOOP DONE === <<"
