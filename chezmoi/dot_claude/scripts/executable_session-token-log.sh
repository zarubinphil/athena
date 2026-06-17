#!/usr/bin/env bash
# session-token-log.sh — SessionEnd-хук: пишет токен-расход сессии в self-learning лог.
# Получает на stdin JSON хука (transcript_path). Тихий, без падений (хук не должен ломать выход).
set -uo pipefail

LOG="$HOME/.claude/self-learning/token-spend.log"
mkdir -p "$(dirname "$LOG")"

IN=$(cat 2>/dev/null || true)
TP=$(printf '%s' "$IN" | python3 -c "import sys,json;
try: print(json.load(sys.stdin).get('transcript_path',''))
except Exception: print('')" 2>/dev/null)

[ -n "$TP" ] && [ -f "$TP" ] || exit 0   # нет транскрипта — тихо выходим

{
  echo "── $(date '+%F %T') ──"
  "$HOME/.claude/scripts/token-spend.sh" "$TP" 2>/dev/null
  echo
} >> "$LOG" 2>/dev/null || true
exit 0
