#!/usr/bin/env bash
# Athena OS — health-check (launchd, daily). Целостность Мозга: бинари + канон-файлы.
# Лог: ~/.claude/health.log. Не чинит — только сигналит. Generic, без личных данных.
set -uo pipefail
LOG="$HOME/.claude/health.log"
ts="$(date '+%Y-%m-%d %H:%M:%S')"
issues=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "  ok  $1"; else echo "  !!  $1"; issues=$((issues + 1)); fi; }
# Guard каждого user LaunchAgent против status=127 (бинарь не на PATH launchd).
# Эфф. PATH = EnvironmentVariables.PATH ∪ login-shell(-lc) ∪ inline `export PATH=` в команде.
chk_launchd() {
  local dir="$HOME/Library/LaunchAgents" plist label args effpath inlinepath tool miss
  [ -d "$dir" ] || { echo "  ··  launchd: нет агентов (skip)"; return; }
  for plist in "$dir"/*.plist; do
    [ -e "$plist" ] || continue
    label="$(basename "$plist" .plist)"
    args="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$plist" 2>/dev/null)" || continue
    [ -n "$args" ] || continue
    effpath="$(plutil -extract EnvironmentVariables.PATH raw -o - "$plist" 2>/dev/null)"
    if [ -z "$effpath" ] && printf '%s' "$args" | grep -q -- '-lc'; then
      effpath="$(env -i HOME="$HOME" /bin/zsh -lc 'printf %s "$PATH"' 2>/dev/null)"
    fi
    inlinepath="$(printf '%s' "$args" | grep -oE 'export PATH="[^"]*"' | head -1 | sed -E 's/^export PATH="//; s/"$//')"
    [ -n "$inlinepath" ] && effpath="$inlinepath:$effpath"
    effpath="${effpath//\$HOME/$HOME}"
    [ -n "$effpath" ] || effpath="/usr/bin:/bin"
    miss=""
    for tool in claude chezmoi node yt-dlp ffmpeg whisper python3; do
      printf '%s' "$args" | grep -qE '(^|[[:space:];&|(])'"$tool"'([[:space:]]|$)' || continue
      PATH="$effpath" command -v "$tool" >/dev/null 2>&1 || miss="$miss $tool"
    done
    if [ -n "$miss" ]; then echo "  !!  launchd $label:$miss не на PATH (status=127)"; issues=$((issues + 1))
    else echo "  ok  launchd $label"; fi
  done
}
{
  echo "── health $ts ──"
  chk "claude CLI"        "command -v claude"
  chk "chezmoi"           "command -v chezmoi"
  chk "CLAUDE.md канон"   "test -f \"$HOME/.claude/CLAUDE.md\""
  chk "settings.json"     "test -f \"$HOME/.claude/settings.json\""
  chk "security-guard"    "test -f \"$HOME/.claude/hooks/security-guard.sh\""
  chk "rules/structure"   "test -f \"$HOME/.claude/rules/structure.md\""
  chk "registry"          "test -d \"$HOME/.agents/registry\""
  chk_launchd
  echo "  итог: $issues проблем(ы)"
} >"$LOG" 2>&1
exit 0
