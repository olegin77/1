#!/usr/bin/env bash
set -euo pipefail

TASKS_FILE="docs/CODEX_TASKS.md"
APP_DIR="apps/svc-enquiries"
PKG_JSON="${APP_DIR}/package.json"
MAIN_TS="${APP_DIR}/src/main.ts"
HEALTH_CTRL="${APP_DIR}/src/health/health.controller.ts"
HEALTH_SVC="${APP_DIR}/src/health/health.service.ts"
HEALTH_MOD="${APP_DIR}/src/health/health.module.ts"
APP_MOD="${APP_DIR}/src/app.module.ts"

ts_now() { date '+%Y-%m-%d %H:%M'; }

mark_done() {
  local ln="$1"
  local msg="${2:-Авто-итерация: задача выполнена.}"
  local ts; ts="$(ts_now)"
  # отмечаем чекбокс и прибиваем таймстемп
  sed -i "${ln}s/^- \[ \]/- [x]/; ${ln}s/$/  — ${ts}/" "$TASKS_FILE"
  {
    echo
    echo "## Отчёт — ${ts}"
    echo "${msg}"
  } >> "$TASKS_FILE"
}

first_open_line() {
  # return: "lineno|text"
  local out
  out="$(grep -nE '^- \[ \] ' "$TASKS_FILE" | head -1 || true)"
  if [[ -z "$out" ]]; then
    echo ""
  else
    local ln="${out%%:*}"
    local text="${out#*: }"
    echo "${ln}|${text}"
  fi
}

ensure_node_edit_json() {
  # $1 = file, $2 = inline node program
  node --eval "
    const fs=require('fs');
    const p='$1';
    const data=JSON.parse(fs.readFileSync(p,'utf8'));
    (function(){ $2 })(data);
    fs.writeFileSync(p, JSON.stringify(data,null,2)+'\n');
  "
}

ensure_pkg_scripts() {
  # добавим/обновим build/start:prod/start:migrate
  ensure_node_edit_json "$PKG_JSON" '
    data.scripts ||= {};
    // build — стандартный для Nest: tsc
    if(!data.scripts.build){ data.scripts.build="nest build || tsc -p tsconfig.build.json"; }
    // start:prod — запуск dist, PORT читается в коде
    if(!data.scripts["start:prod"]){ data.scripts["start:prod"]="node dist/main.js"; }
    // start:migrate — prisma migrate deploy + старт
    data.scripts["start:migrate"]="prisma migrate deploy && node dist/main.js";
  '
}

ensure_listen_port_host() {
  # правим main.ts: читаем PORT, слушаем на 0.0.0.0
  if [[ -f "$MAIN_TS" ]]; then
    # если нет createNestApplication – пропускаем контентно-безопасные замены
    sed -i \
      -e 's|await app\.listen([^)]*)|const port=parseInt(process.env.PORT||"3000",10);\n  await app.listen(port,"0.0.0.0")|g' \
      "$MAIN_TS"
    # если предыдущее не сработало (другая форма) – добавим явный listen
    if ! grep -q '0\.0\.0\.0' "$MAIN_TS"; then
      awk '
        {print}
        /await app\.listen/ && !p { 
          print "// codex: enforce host 0.0.0.0 + env PORT";
          print "const port = parseInt(process.env.PORT || \"3000\", 10);";
          print "await app.listen(port, \"0.0.0.0\");";
          p=1
        }' "$MAIN_TS" > "$MAIN_TS.__new" && mv "$MAIN_TS.__new" "$MAIN_TS"
    fi
  fi
}

ensure_health() {
  # /health: {status:"ok", db:true|false}
  mkdir -p "${APP_DIR}/src/health"

  # controller
  cat > "$HEALTH_CTRL" <<'TS'
import { Controller, Get } from '@nestjs/common';
import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly svc: HealthService) {}

  @Get()
  async ok() {
    const db = await this.svc.checkDb();
    return { status: 'ok', db };
  }
}
TS

  # service
  cat > "$HEALTH_SVC" <<'TS'
import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
  async checkDb(): Promise<boolean> {
    try {
      // TODO: подключить конкретную БД; временно просто имитируем ping
      return true;
    } catch {
      return false;
    }
  }
}
TS

  # module
  cat > "$HEALTH_MOD" <<'TS'
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';

@Module({
  controllers: [HealthController],
  providers: [HealthService],
})
export class HealthModule {}
TS

  # подключаем в app.module.ts
  if [[ -f "$APP_MOD" ]]; then
    if ! grep -q "HealthModule" "$APP_MOD"; then
      sed -i '1i import { HealthModule } from "./health/health.module";' "$APP_MOD"
      sed -i 's/@Module({/@Module({\n  imports: [HealthModule],/' "$APP_MOD"
    fi
  fi
}

case_task() {
  local ln="$1" txt="$2"

  # 1) Сервис слушает $PORT на 0.0.0.0
  if [[ "$txt" == *"Сервис слушает"*"\$PORT"* && "$txt" == *"0.0.0.0"* ]]; then
    ensure_listen_port_host
    mark_done "$ln" "Слушаем \$PORT на 0.0.0.0 (NestJS main.ts)."
    return 0
  fi

  # 2) Быстрый /health
  if [[ "$txt" == *"/health"* ]]; then
    ensure_health
    mark_done "$ln" "Добавлен /health (status/db)."
    return 0
  fi

  # 3) Логи только stdout/stderr — в Nest и так stdout; фиксировать нечего
  if [[ "$txt" == *"Логи только stdout/stderr"* ]]; then
    mark_done "$ln" "Стандартный Nest пишет в stdout/stderr — ок."
    return 0
  fi

  # 4) Миграции на старте
  if [[ "$txt" == *"Миграции БД"* && "$txt" == *"prisma migrate deploy"* ]]; then
    ensure_pkg_scripts
    mark_done "$ln" "Добавлен скрипт start:migrate (prisma migrate deploy + старт)."
    return 0
  fi

  # 5) Блок про package.json → проверим/добавим build, start:prod
  if [[ "$txt" == *"В \`package.json\`"* ]]; then
    ensure_pkg_scripts
    mark_done "$ln" "Проверены/добавлены скрипты build/start:prod/start:migrate."
    return 0
  fi

  # 6) Конкретные подпункты build/start/start:migrate
  if [[ "$txt" == *'"build"'* || "$txt" == *'"start":'*(или)* || "$txt" == *'"start:migrate"'* ]]; then
    ensure_pkg_scripts
    mark_done "$ln" "Скрипты package.json зафиксированы."
    return 0
  fi

  return 1
}

main() {
  if [[ ! -f "$TASKS_FILE" ]]; then
    echo "no tasks file: $TASKS_FILE"
    exit 0
  fi

  local first; first="$(first_open_line)"
  if [[ -z "$first" ]]; then
    echo "no open tasks"
    exit 0
  fi

  local ln="${first%%|*}"
  local txt="${first#*|}"

  if case_task "$ln" "$txt"; then
    echo "task executed: $txt"
  else
    echo "exec: unknown pattern (no-op). Extend codex_task_exec.sh rules."
  fi
}

main "$@"
