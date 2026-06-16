#!/usr/bin/env bash
# dry-validate.sh — ЭМУЛЯЦИЯ рендера merged-source БЕЗ установки chezmoi (clean-room).
#
# Собирает generic⊕private overlay в temp, подставляет известные chezmoi-переменные,
# валидирует: плисты (plutil), JSON (settings), скрипты (bash/zsh -n), run_once_,
# + ловит неизвестные {{ }}-переменные (типобезопасность шаблонов).
#
# Это НЕ настоящий `chezmoi execute-template` (chezmoi на машине нет — clean-room).
# Истинный рендер на живой dest → Фаза 5 (e2e на чистом таргете, где chezmoi стоит).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"            # корень athena
PRIV="${ATHENA_PRIVATE_DIR:-$HOME/Проекты/athena-private}"
FAKE_HOME="$(mktemp -d)"; MERGED="$(mktemp -d)"
trap 'rm -rf "$FAKE_HOME" "$MERGED"' EXIT
FAIL=0; WARN=0
red(){ printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; FAIL=$((FAIL+1)); }
grn(){ printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
yel(){ printf '\033[1;33m  ! %s\033[0m\n' "$*"; WARN=$((WARN+1)); }
say(){ printf '\033[1;36m▸ %s\033[0m\n' "$*"; }

VPS="root@vps.example:/srv/agent-os"      # эмуляция .athena.vps_host (host:path)
VHOST="${VPS%%:*}"; VROOT="${VPS#*:}"

# Эмулировать chezmoi-подстановки известных переменных + срезать строки-объявления $vars.
render() {
  sed -E \
    -e '/^\{\{-.*:=.*-\}\}$/d' \
    -e "s#\{\{-? *\.chezmoi\.homeDir *-?\}\}#${FAKE_HOME}#g" \
    -e "s#\{\{-? *\.node_bin *-?\}\}#/usr/local/bin/node#g" \
    -e "s#\{\{ *\\\$home *\}\}#${FAKE_HOME}#g" \
    -e "s#\{\{ *\\\$vps *\}\}#${VHOST}#g" \
    -e "s#\{\{ *\\\$root *\}\}#${VROOT}#g" \
    -e "s#\{\{-? *\.athena\.vps_host *-?\}\}#${VPS}#g" \
    "$1"
}

# ── 1. Сборка merged-source (как в bootstrap layer1) ──
say "1. merged-source: generic ⊕ private overlay → temp"
rsync -a --delete --exclude '.git' "$HERE/chezmoi/" "$MERGED/"
if [ -d "$PRIV/chezmoi" ]; then
  rsync -a --exclude '.git' "$PRIV/chezmoi/" "$MERGED/"
  # overlay приземлился? проверяем приватный маркер-файл
  [ -f "$MERGED/run_once_after_30-telegram-env.sh.tmpl" ] && grn "overlay наложен (run_once_ виден в merged)" || red "overlay НЕ наложен — run_once_ отсутствует в merged"
elif [ "${ATHENA_EXPECT_OVERLAY:-0}" = 1 ]; then
  red "приватный overlay ОЖИДАЛСЯ ($PRIV/chezmoi), но отсутствует — generic-only прогон НЕ полон (ATHENA_EXPECT_OVERLAY=1)"
else
  grn "generic-only прогон (overlay не ожидается; для полной системы владельца выставь ATHENA_EXPECT_OVERLAY=1)"
fi
[ -f "$MERGED/.chezmoidata.yaml" ] || cp "$MERGED/.chezmoidata.yaml.example" "$MERGED/.chezmoidata.yaml" 2>/dev/null || true
[ -f "$MERGED/.chezmoidata.yaml" ] && grn ".chezmoidata.yaml присутствует" || red "нет .chezmoidata.yaml (и .example)"

# ── 2. Плисты launchd (generic + private): sed $HOME → plutil -lint ──
say "2. launchd плисты → plutil -lint"
for dir in "$HERE/launchd" "$PRIV/launchd"; do
  [ -d "$dir" ] || continue
  for p in "$dir"/*.plist; do [ -e "$p" ] || continue
    r="$MERGED/.lint-$(basename "$p")"
    sed "s#\$HOME#$FAKE_HOME#g" "$p" > "$r"
    if plutil -lint "$r" >/dev/null 2>&1; then grn "plist $(basename "$p")"; else red "plist НЕВАЛИДЕН: $p"; fi
  done
done
# telegram .template: __POETRY_BIN__ + $HOME → plutil
TG="$(ls "$PRIV"/launchd/*.claudetelegrambot.plist.template 2>/dev/null | head -1)"
if [ -f "$TG" ]; then
  r="$MERGED/.lint-telegram.plist"
  sed -e "s#__POETRY_BIN__#$FAKE_HOME/venv/bin/bot#g" -e "s#\$HOME#$FAKE_HOME#g" "$TG" > "$r"
  plutil -lint "$r" >/dev/null 2>&1 && grn "plist telegram.template (rendered)" || red "telegram.template НЕВАЛИДЕН"
fi

# ── 3. settings.json.tmpl → render → JSON-валидация ──
say "3. settings.json → render → json"
SJ="$MERGED/dot_claude/settings.json.tmpl"
if [ -f "$SJ" ]; then
  render "$SJ" > "$MERGED/.settings.json"
  if python3 -m json.tool "$MERGED/.settings.json" >/dev/null 2>&1; then grn "settings.json валиден (homeDir+node_bin)"; else red "settings.json НЕВАЛИДЕН после рендера"; fi
else yel "нет settings.json.tmpl в merged"; fi

# ── 4. Скрипты-шаблоны (*.sh.tmpl, run_once_) → render → bash/zsh -n ──
say "4. скрипты-шаблоны → синтаксис после рендера"
while IFS= read -r f; do
  base="$(basename "$f")"
  r="$MERGED/.script-render.sh"; render "$f" > "$r"
  sh1="$(head -1 "$r")"
  case "$sh1" in
    *zsh*) chk="zsh -n" ;;
    *bash*|*sh*) chk="bash -n" ;;
    *) chk="bash -n" ;;
  esac
  if $chk "$r" 2>/dev/null; then grn "$chk: $base"; else red "синтаксис: $base"; fi
  head -1 "$r" | grep -q '^#!' || yel "$base — нет shebang на строке 1 после рендера"
done < <(find "$MERGED" -name '*.sh.tmpl' -type f)

# ── 5. Неизвестные {{ }}-переменные (типобезопасность шаблонов) ──
say "5. неизвестные {{ }} после рендера известных vars"
unknown=0
while IFS= read -r f; do
  leftover="$(render "$f" | grep -oE '\{\{[^}]*\}\}' | sort -u)"
  if [ -n "$leftover" ]; then
    yel "нерендеренные токены в $(basename "$f"):"
    printf '      %s\n' $leftover
    unknown=$((unknown+1))
  fi
done < <(find "$MERGED" -name '*.tmpl' -type f)
[ "$unknown" = 0 ] && grn "0 неизвестных {{ }}-переменных (все известны эмулятору)"

# ── Итог ──
echo
if [ "$FAIL" = 0 ]; then
  printf '\033[1;32mDRY-VALIDATE OK\033[0m (warn: %s). Эмуляция — истинный chezmoi execute-template → Фаза 5.\n' "$WARN"
else
  printf '\033[1;31mDRY-VALIDATE FAIL: %s ошибок\033[0m (warn: %s)\n' "$FAIL" "$WARN"; exit 1
fi
