# .codex/codex_task_exec.sh
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(pwd)"
APP_DIR="apps/svc-enquiries"
SRC_DIR="$APP_DIR/src"
PKG="$APP_DIR/package.json"

ts(){ date '+%F %T %z'; }
log(){ echo "[$(ts)] $*"; }

ensure_file(){
  local path="$1" content="$2"
  if [ ! -f "$path" ]; then
    mkdir -p "$(dirname "$path")"
    printf "%s\n" "$content" > "$path"
    return 0
  fi
  return 1
}

json_has_key(){ # file keypath(with dots)
  node -e 'const fs=require("fs");const f=process.argv[1];const k=process.argv[2].split(".");const j=JSON.parse(fs.readFileSync(f,"utf8"));let o=j;for(const p of k){if(!(p in o)){process.exit(2)}o=o[p]}process.exit(0)' "$1" "$2" >/dev/null 2>&1
}

json_write_key(){ # file key value(json)
  node -e '
    const fs=require("fs");
    const file=process.argv[1], key=process.argv[2].split("."), val=JSON.parse(process.argv[3]);
    const j=fs.existsSync(file)?JSON.parse(fs.readFileSync(file,"utf8")):{};
    let o=j; for (let i=0;i<key.length-1;i++){ const k=key[i]; o[k]=o[k]||{}; o=o[k]; }
    o[key[key.length-1]] = val;
    fs.writeFileSync(file, JSON.stringify(j,null,2)+"\n");
  ' "$1" "$2" "$3"
}

mark_done(){
  local pattern="$1"
  local stamp
  stamp="$(date '+%Y-%m-%d %H:%M')"
  awk -v pat="$pattern" -v stamp="$stamp" '
    BEGIN{done=0; IGNORECASE=1}
    {
      if(!done && $0 ~ /^- \[ \] / && $0 ~ pat){
        sub(/^- \[ \] /,"- [x] ")
        $0 = $0 "  — " stamp
        done=1
      }
      print
    }
  ' docs/CODEX_TASKS.md > docs/.CODEX_TASKS.md.tmp && mv docs/.CODEX_TASKS.md.tmp docs/CODEX_TASKS.md
}

first_open_task(){
  awk '
    BEGIN{IGNORECASE=1}
    /^- \[ \] /{print; exit}
  ' docs/CODEX_TASKS.md
}

ensure_node_tools(){
  if ! command -v node >/dev/null 2>&1; then
    log "Node.js is required for JSON edits (package.json)."
    return 1
  fi
  return 0
}

# --- RULES ---

rule_listen_port(){
  # “Сервис слушает $PORT на 0.0.0.0” → apps/svc-enquiries/src/main.ts
  local main="$SRC_DIR/main.ts"
  ensure_file "$main" '/* bootstrap placeholder; will be overwritten by codex */' || true
  if ! grep -q 'listen(.*process.env.PORT' "$main" 2>/dev/null || ! grep -qi "0\.0\.0\.0" "$main"; then
    cat > "$main" <<'TS'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const port = Number(process.env.PORT || 8080);
  await app.listen(port, '0.0.0.0');
}
bootstrap();
TS
    log "Updated apps/svc-enquiries/src/main.ts to listen on $PORT and 0.0.0.0"
    return 0
  fi
  return 1
}

rule_health_endpoint(){
  # “Быстрый /health (200 OK, {status:"ok", db:true|false})”
  local mod="$SRC_DIR/health/health.module.ts"
  local svc="$SRC_DIR/health/health.service.ts"
  local ctl="$SRC_DIR/health/health.controller.ts"
  local appmod="$SRC_DIR/app.module.ts"

  ensure_file "$mod" '' || true

  cat > "$svc" <<'TS'
import { Injectable } from '@nestjs/common';

@Injectable()
export class HealthService {
  async check() {
    // TODO: wire real DB ping when Prisma present
    const db = false;
    return { status: 'ok', db };
  }
}
TS

  cat > "$ctl" <<'TS'
import { Controller, Get } from '@nestjs/common';
import { HealthService } from './health.service';

@Controller('health')
export class HealthController {
  constructor(private readonly health: HealthService) {}
  @Get()
  async get() {
    return await this.health.check();
  }
}
TS

  cat > "$mod" <<'TS'
import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';

@Module({
  controllers: [HealthController],
  providers: [HealthService],
})
export class HealthModule {}
TS

  ensure_file "$appmod" "export class AppModule {}" || true
  if ! grep -q 'HealthModule' "$appmod" 2>/dev/null; then
    cat > "$appmod" <<'TS'
import { Module } from '@nestjs/common';
import { HealthModule } from './health/health.module';

@Module({
  imports: [HealthModule],
})
export class AppModule {}
TS
    log "Wired HealthModule in app.module.ts"
  fi
  log "Health endpoint scaffolded"
  return 0
}

rule_package_scripts(){
  # “В package.json: build/start/start:migrate”
  ensure_node_tools || return 1
  ensure_file "$PKG" '{ "name":"svc-enquiries","version":"0.0.0" }' || true

  json_write_key "$PKG" "scripts.build"         '"nest build || tsc -p tsconfig.build.json || true"'
  json_write_key "$PKG" "scripts.start"         '"node dist/main.js"'
  json_write_key "$PKG" "scripts.start:prod"    '"node dist/main.js"'
  json_write_key "$PKG" "scripts.start:migrate" '"prisma migrate deploy && node dist/main.js"'
  json_write_key "$PKG" "scripts.dev"           '"nest start --watch || ts-node src/main.ts || true"'
  json_write_key "$PKG" "engines.node"          '">=18"'

  log "package.json scripts ensured"
  return 0
}

rule_do_yaml(){
  # DigitalOcean app.yaml базовый
  local DO="do/app.yaml"
  ensure_file "$DO" '' || true
  cat > "$DO" <<'YAML'
name: weddingtech-uz
region: fra
services:
  - name: svc-enquiries
    dockerfile_path: apps/svc-enquiries/Dockerfile
    http_port: 8080
    instance_count: 1
    instance_size_slug: basic-xxs
    routes:
      - path: /api
    envs:
      - key: NODE_ENV
        value: production
        scope: RUN_AND_BUILD_TIME
      - key: DATABASE_URL
        scope: RUN_AND_BUILD_TIME
        type: SECRET
    health_check:
      http_path: /health
      initial_delay_seconds: 10
      period_seconds: 10
      timeout_seconds: 5
      success_threshold: 1
      failure_threshold: 3
YAML
  log "do/app.yaml ensured"
  return 0
}

# --- SELECT FIRST OPEN TASK & EXECUTE ---

[ -f docs/CODEX_TASKS.md ] || { echo "# Tasks" > docs/CODEX_TASKS.md; }

task="$(first_open_task || true)"
if [ -z "${task:-}" ]; then
  log "no open tasks — nothing to do"
  exit 0
fi

log "first open task: $task"

shopt -s nocasematch
changed=0
if [[ "$task" =~ (0\.0\.0\.0|PORT|\$PORT) ]]; then rule_listen_port && changed=1; fi
if [[ "$task" =~ (health|/health) ]]; then rule_health_endpoint && changed=1; fi
if [[ "$task" =~ (package\.json|scripts|build|start) ]]; then rule_package_scripts && changed=1; fi
if [[ "$task" =~ (DigitalOcean|App Platform|DO|app\.ya?ml) ]]; then rule_do_yaml && changed=1; fi
shopt -u nocasematch

if [ "$changed" -eq 1 ]; then
  if [[ "$task" =~ (health|/health) ]]; then mark_done "health"; fi
  if [[ "$task" =~ (0\.0\.0\.0|PORT|\$PORT) ]]; then mark_done "PORT|0\.0\.0\.0"; fi
  if [[ "$task" =~ (package\.json|scripts|build|start) ]]; then mark_done "package\\.json|scripts|build|start"; fi
  if [[ "$task" =~ (DigitalOcean|App Platform|DO|app\.ya?ml) ]]; then mark_done "DigitalOcean|App Platform|app\\.ya?ml"; fi
  exit 0
else
  log "no matching rule for first open task — skipping"
  exit 0
fi

