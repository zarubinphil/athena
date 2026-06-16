#!/usr/bin/env bash
# Athena — единый event-driven пересбор реестра способностей.
# Триггеры: launchd WatchPaths (установка скилла / запись overrides.jsonl) ИЛИ прямой вызов
# (Мнемозина-протокол, weekly-update, ручной). Идемпотентный, с lock+debounce-settle.
#
# Чейн: build-skill-index → build_registry(+эмбеддинги) → build_views → graphify update → validate.
# Эффект: новый скилл/знание становится routable «сразу же», не ждёт weekly-батч.
#
# Использование:
#   registry-rebuild.sh            # debounce-settle (для launchd WatchPaths)
#   registry-rebuild.sh --now      # без settle (прямой вызов: Мнемозина/ручной)
set -uo pipefail

REGDIR="$HOME/.agents/registry"
SCR="$REGDIR/scripts"
LOG="$HOME/.claude/capabilities/registry-rebuild.log"
LOCKDIR="$REGDIR/.rebuild.lock.d"
GRAPHDIR="$REGDIR/capability-system-graph"
SETTLE=12   # секунд «осесть» — установка пишет много файлов, коалесцируем всплеск

mkdir -p "$(dirname "$LOG")"
log(){ printf '[%s] %s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$*" >> "$LOG"; }

[ "${1:-}" = "--now" ] || sleep "$SETTLE"

# Lock: один пересбор за раз (mkdir атомарен и портативен — на macOS нет flock).
# Если уже идёт — выходим (текущий подхватит свежее состояние). Стейл-lock >10мин чистим.
if [ -d "$LOCKDIR" ] && [ -n "$(find "$LOCKDIR" -prune -mmin +10 2>/dev/null)" ]; then
  log "стейл-lock >10мин — снимаю"; rmdir "$LOCKDIR" 2>/dev/null || true
fi
if ! mkdir "$LOCKDIR" 2>/dev/null; then log "skip: пересбор уже идёт"; exit 0; fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

log "REBUILD START (${1:-watch})"
cd "$SCR" || { log "FAIL: нет $SCR"; exit 1; }

step(){ # step "имя" cmd...
  local name="$1"; shift
  if "$@" >>"$LOG" 2>&1; then log "  ✓ $name"; else log "  ✗ $name (rc=$?)"; fi
}

step "build-skill-index" node "$SCR/build-skill-index.mjs"
step "build_registry"    python3 "$SCR/build_registry.py"
step "build_views"       python3 "$SCR/build_views.py"
# graphify update — реген graph.json (без LLM). Опционально: нет graphify/dir → skip.
if command -v graphify >/dev/null && [ -d "$GRAPHDIR" ]; then
  step "graphify update" graphify update "$GRAPHDIR"
else
  log "  · graphify update skip (нет CLI или $GRAPHDIR)"
fi
step "validate"          python3 "$SCR/validate.py"

log "REBUILD DONE"
