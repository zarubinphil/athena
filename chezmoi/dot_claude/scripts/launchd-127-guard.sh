#!/usr/bin/env bash
# Athena — launchd status=127 guard.
# Назначение: каждый user LaunchAgent, что зовёт бинарь ГОЛОЙ командой, реально находит его
#   под PATH, который даст launchd. Ловит рекуррентный баг exit 127 (бинарь не на PATH).
# Два режима:
#   - запуск напрямую (`bash launchd-127-guard.sh`) → отчёт дописывается в $HOME/.claude/health.log;
#   - `source` из health-check.sh → отдаёт функцию chk_launchd (DRY, единый источник логики).
# Generic, без личных данных: читает что есть в ~/Library/LaunchAgents, имена не хардкодит.
set -uo pipefail

# chk_launchd: печатает строки отчёта в stdout, инкрементит $issues (если задан в окружении).
chk_launchd() {
  local dir="$HOME/Library/LaunchAgents" plist label args effpath inlinepath tool miss
  [ -d "$dir" ] || { echo "  ··  launchd: нет агентов (skip)"; return; }
  for plist in "$dir"/*.plist; do
    [ -e "$plist" ] || continue
    label="$(basename "$plist" .plist)"
    # ProgramArguments через PlistBuddy (невэкранированный вывод; plutil-json экранирует \" и ломает inline-PATH)
    args="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$plist" 2>/dev/null)" || continue
    [ -n "$args" ] || continue
    # эффективный PATH агента: EnvironmentVariables.PATH ∪ login-shell(-lc) ∪ inline `export PATH=`
    effpath="$(plutil -extract EnvironmentVariables.PATH raw -o - "$plist" 2>/dev/null)"
    if [ -z "$effpath" ] && printf '%s' "$args" | grep -q -- '-lc'; then
      effpath="$(env -i HOME="$HOME" /bin/zsh -lc 'printf %s "$PATH"' 2>/dev/null)"
    fi
    inlinepath="$(printf '%s' "$args" | grep -oE 'export PATH="[^"]*"' | head -1 | sed -E 's/^export PATH="//; s/"$//')"
    [ -n "$inlinepath" ] && effpath="$inlinepath:$effpath"
    effpath="${effpath//\$HOME/$HOME}"
    [ -n "$effpath" ] || effpath="/usr/bin:/bin"
    # тул считается вызванным ТОЛЬКО как голая команда (граница пробел/;/&/|/( ),
    # не подстрока в пути (.claude/, claude-telegram-bot) и не абсолютный путь (127 невозможен)
    miss=""
    for tool in claude chezmoi node yt-dlp ffmpeg whisper python3; do
      printf '%s' "$args" | grep -qE '(^|[[:space:];&|(])'"$tool"'([[:space:]]|$)' || continue
      PATH="$effpath" command -v "$tool" >/dev/null 2>&1 || miss="$miss $tool"
    done
    if [ -n "$miss" ]; then echo "  !!  launchd $label:$miss не на PATH (status=127)"; issues=$(( ${issues:-0} + 1 ))
    else echo "  ok  launchd $label"; fi
  done
}

# standalone-режим: дописать отчёт в health.log
if [ "${BASH_SOURCE[0]:-$0}" = "${0}" ]; then
  LOG="$HOME/.claude/health.log"; issues=0
  {
    echo "── launchd-127-guard $(date '+%Y-%m-%d %H:%M:%S') ──"
    chk_launchd
    echo "  итог: $issues 127-риск(ов)"
  } >>"$LOG" 2>&1
  exit 0
fi
