#!/usr/bin/env bash
# session-reaper — закрывает зависшие сессии Claude Code.
# Критерий: состояние Wait (ждёт ввода) И возраст ≥ THRESHOLD_MIN. Exec (активные) и свежие НЕ трогает.
# Перед kill — сохраняет хэндофф-запись (проект, возраст, последнее сообщение, путь транскрипта) в ~/.claude/handoff/.
# DRY_RUN=1 — только показать кандидатов, без kill.
set -uo pipefail

ABTOP="$HOME/.cargo/bin/abtop"
HANDOFF_DIR="$HOME/.claude/handoff"
LOG="$HOME/.claude/scripts/session-reaper.log"
THRESHOLD_MIN="${THRESHOLD_MIN:-120}"   # 2 часа
DRY_RUN="${DRY_RUN:-0}"
mkdir -p "$HANDOFF_DIR"
ts() { date '+%F %T'; }
exec >>"$LOG" 2>&1
[ -x "$ABTOP" ] || { echo "$(ts) abtop недоступен"; exit 0; }

# Путь к свежему транскрипту сессии по PID (cwd → projects-dir → последний jsonl). Пусто при неудаче.
tx_path() {
  local pid="$1" cwd dir
  cwd="$(lsof -a -d cwd -p "$pid" -Fn 2>/dev/null | grep '^n' | head -1 | cut -c2-)"
  [ -n "$cwd" ] || return 1
  dir="$HOME/.claude/projects/$(printf '%s' "$cwd" | python3 -c "import re,sys;print(re.sub(r'[^a-zA-Z0-9]','-',sys.stdin.read().strip()))" 2>/dev/null)"
  [ -d "$dir" ] || return 1
  ls -t "$dir"/*.jsonl 2>/dev/null | head -1
}

# Токен-расход reaped-сессии: SessionEnd-хук (async) не успевает при kill жнеца → логируем сами.
# Guard: скрипт-логгер опционален (live-слой) — generic-каркас валиден без него.
log_token_spend() {
  local pid="$1" tx logger="$HOME/.claude/scripts/session-token-log.sh"
  [ -x "$logger" ] || return 0
  tx="$(tx_path "$pid")"; [ -n "$tx" ] && [ -f "$tx" ] || return 0
  printf '{"transcript_path":"%s"}' "$tx" | bash "$logger" 2>/dev/null \
    && echo "$(ts) token-spend залогирован (reaped PID $pid)"
}

# Сессия ждёт СБРОСА ЛИМИТА (не заброшена) → щадить. cwd по PID → транскрипт → маркер лимита в хвосте.
# Не смогли проверить → тоже щадим (безопасный дефолт: лучше не убить лимит-сессию).
is_rate_limited() {
  local pid="$1" tx
  tx="$(tx_path "$pid")"
  [ -n "$tx" ] || return 0   # не смогли транскрипт → щадим
  # маркеры реального лимита в последних ~40 событиях
  tail -40 "$tx" 2>/dev/null | grep -qiE 'rate_limit_error|"type":"rate_limit|hit your[^"]{0,25}limit|usage_limit|reset[s]? (at )?[0-9]{1,2}:[0-9]{2}|Retry-After|overloaded_error|5-hour limit|weekly limit|лимит[^"]{0,20}сброс' && return 0
  return 1   # лимита нет → можно убивать
}

# возраст "Nh Nm" / "Nm" / "Nh" → минуты
age_min() {
  local s="$1" h=0 m=0
  [[ "$s" =~ ([0-9]+)h ]] && h="${BASH_REMATCH[1]}"
  [[ "$s" =~ ([0-9]+)m ]] && m="${BASH_REMATCH[1]}"
  echo $((h*60+m))
}

OUT="$("$ABTOP" --once 2>/dev/null)"
reaped=0
# строки сессий: начинаются с пробелов+PID, содержат " Wait "/" Exec " и возраст в конце
while IFS= read -r line; do
  # только верхнеуровневые строки сессий (PID + project), не дочерние (└─, npm, node)
  [[ "$line" =~ ^[[:space:]]+([0-9]+)[[:space:]]+([^[:space:]]+) ]] || continue
  pid="${BASH_REMATCH[1]}"
  proj="${BASH_REMATCH[2]}"
  # состояние
  state=""
  echo "$line" | grep -q " Wait " && state="Wait"
  echo "$line" | grep -q " Exec " && state="Exec"
  [ "$state" = "Wait" ] || continue   # только Wait
  # возраст — последний токен вида Nh/Nm в строке
  agetok="$(echo "$line" | grep -oE '[0-9]+h[[:space:]]*[0-9]*m?|[0-9]+m' | tail -1)"
  [ -n "$agetok" ] || continue
  mins=$(age_min "$agetok")
  [ "$mins" -ge "$THRESHOLD_MIN" ] || continue
  # последнее сообщение (между project и маркером состояния) — для хэндоффа
  lastmsg="$(echo "$line" | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+[^[:space:]]+[[:space:]]*//; s/[◌●?].*$//' | head -c 200)"
  # подтверждение, что PID жив и это claude
  ps -p "$pid" -o command= 2>/dev/null | grep -qi "claude" || continue

  # ⛔ щадить сессии, ждущие СБРОСА ЛИМИТА (не заброшены — возобновятся)
  if is_rate_limited "$pid"; then
    echo "$(ts) ЩАЖУ PID $pid ($proj, $agetok) — ждёт сброса лимита/непроверяемо, НЕ убиваю"
    continue
  fi

  # ── сохранить хэндофф-запись ──
  rec="$HANDOFF_DIR/reaped-$(date '+%Y%m%d-%H%M%S')-$pid.md"
  {
    echo "# Закрытая сессия (reaper $(ts))"
    echo "- PID: $pid · проект: $proj · возраст: $agetok ($mins мин, Wait)"
    echo "- Последнее: $lastmsg"
    echo "- Транскрипт: ~/.claude/projects/ (по проекту $proj) — для /resume при необходимости"
    echo "- Причина: зависла в ожидании ввода ≥ $THRESHOLD_MIN мин → закрыта жнецом."
  } > "$rec"

  if [ "$DRY_RUN" = "1" ]; then
    echo "$(ts) [DRY] кандидат PID $pid ($proj, $agetok) → хэндофф $rec"
  else
    log_token_spend "$pid"   # token-учёт ДО kill (async SessionEnd не успеет)
    kill -TERM "$pid" 2>/dev/null && echo "$(ts) ЗАКРЫТА PID $pid ($proj, $agetok) → $rec" || echo "$(ts) kill fail PID $pid"
    reaped=$((reaped+1))
  fi
done <<< "$OUT"

echo "$(ts) reaper done (закрыто: $reaped, порог ${THRESHOLD_MIN}мин, dry=$DRY_RUN)"
