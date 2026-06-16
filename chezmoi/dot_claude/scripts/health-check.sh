#!/usr/bin/env bash
# Athena — health-check (launchd, daily). Целостность Мозга: бинари + канон-файлы.
# Лог: ~/.claude/health.log. Не чинит — только сигналит. Generic, без личных данных.
set -uo pipefail
LOG="$HOME/.claude/health.log"
ts="$(date '+%Y-%m-%d %H:%M:%S')"
issues=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "  ok  $1"; else echo "  !!  $1"; issues=$((issues + 1)); fi; }
# launchd status=127 guard — единый источник в launchd-127-guard.sh (DRY, sourceable).
GUARD="$HOME/.claude/scripts/launchd-127-guard.sh"
[ -f "$GUARD" ] && . "$GUARD"
{
  echo "── health $ts ──"
  chk "claude CLI"        "command -v claude"
  chk "chezmoi"           "command -v chezmoi"
  chk "CLAUDE.md канон"   "test -f \"$HOME/.claude/CLAUDE.md\""
  chk "settings.json"     "test -f \"$HOME/.claude/settings.json\""
  chk "security-guard"    "test -f \"$HOME/.claude/hooks/security-guard.sh\""
  chk "rules/structure"   "test -f \"$HOME/.claude/rules/structure.md\""
  chk "registry"          "test -d \"$HOME/.agents/registry\""
  command -v chk_launchd >/dev/null 2>&1 && chk_launchd
  echo "  итог: $issues проблем(ы)"
} >"$LOG" 2>&1
exit 0
