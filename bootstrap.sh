#!/usr/bin/env bash
# Athena OS — оркестратор полного разворота на чистом Mac.
# Один прогон: база → Мозг(дотфайлы) → реестр → проекты → знания → секреты+MCP+launchd → smoke.
# Идемпотентно. Личные значения — в athena.config.sh (gitignored, из athena.config.example.sh).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${TMPDIR:-/tmp}/athena-bootstrap-$(date +%Y%m%d-%H%M%S).log"
DRY=0; ONLY=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --only=*) ONLY="${a#*=}" ;;
    -h|--help) grep -E '^# ' "$0" | sed 's/^# //'; exit 0 ;;
  esac
done

say()  { printf '\033[1;36m▸ %s\033[0m\n' "$*" | tee -a "$LOG"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*" | tee -a "$LOG"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*" | tee -a "$LOG"; }
run()  { if [ "$DRY" = 1 ]; then echo "  [dry] $*" | tee -a "$LOG"; else eval "$@" >>"$LOG" 2>&1; fi; }
phase(){ [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

[ "$(uname)" = "Darwin" ] || { warn "не macOS — OCR/launchd-части пропустятся"; }

# Личная конфигурация (репо дотфайлов, vault, манифест проектов)
CFG="$HERE/athena.config.sh"
if [ -f "$CFG" ]; then . "$CFG"; else warn "нет athena.config.sh — скопируй из athena.config.example.sh и заполни"; fi
: "${ATHENA_DOTFILES_REPO:=}"      # ПРОДВИНУТОЕ: готовый внешний chezmoi-source целиком (минует merge)
: "${ATHENA_PRIVATE_REPO:=}"       # git URL приватного overlay (athena-private) ИЛИ пусто = generic-only
: "${ATHENA_PRIVATE_DIR:=$HOME/Проекты/athena-private}"   # куда клонится/лежит overlay
: "${ATHENA_VAULT_REPO:=}"         # git URL приватного vault-znaniya
: "${ATHENA_PROJECTS_MANIFEST:=$HERE/projects.manifest}"
MERGED="${ATHENA_MERGED_SOURCE:-$HOME/.local/share/athena-merged-source}"  # собранный generic⊕private source

# ───────── Слой 0: база (Homebrew + CLI) ─────────
layer0_base() {
  phase 0 || return 0; say "Слой 0 — база системы"
  if ! xcode-select -p >/dev/null 2>&1; then run "xcode-select --install || true"; fi
  if ! command -v brew >/dev/null; then
    run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
  command -v brew >/dev/null && run "brew bundle --file '$HERE/Brewfile'" && ok "Brewfile применён"
  command -v claude >/dev/null && ok "claude CLI готов" || warn "claude CLI: установи Claude Code"
}

# ───────── Слой 1: Мозг (дотфайлы через chezmoi merged-source) ─────────
# Источник = generic-канон (./chezmoi) ⊕ приватный overlay (athena-private/chezmoi).
# Overlay побеждает на конфликте; добавляет личное (references, launchd-скрипты, run_once_).
layer1_brain() {
  phase 1 || return 0; say "Слой 1 — Мозг (дотфайлы, merged-source)"
  command -v chezmoi >/dev/null || run "brew install chezmoi"

  # Продвинутый escape-hatch: готовый внешний source целиком, без merge.
  if [ -n "$ATHENA_DOTFILES_REPO" ]; then
    run "chezmoi init --apply '$ATHENA_DOTFILES_REPO'"
    ok "дотфайлы из внешнего source ($ATHENA_DOTFILES_REPO)"; return 0
  fi

  # Клон приватного overlay, если задан репо и его ещё нет.
  if [ -n "$ATHENA_PRIVATE_REPO" ] && [ ! -d "$ATHENA_PRIVATE_DIR/.git" ]; then
    run "git clone '$ATHENA_PRIVATE_REPO' '$ATHENA_PRIVATE_DIR'"
  fi

  # Сборка merged-source: generic база (--delete = чистый старт) ⊕ приватный overlay.
  run "mkdir -p '$MERGED'"
  run "rsync -a --delete --exclude '.git' '$HERE/chezmoi/' '$MERGED/'"
  if [ -d "$ATHENA_PRIVATE_DIR/chezmoi" ]; then
    run "rsync -a --exclude '.git' '$ATHENA_PRIVATE_DIR/chezmoi/' '$MERGED/'"
    ok "приватный overlay наложен ($ATHENA_PRIVATE_DIR)"
  else
    warn "приватный overlay не найден ($ATHENA_PRIVATE_DIR/chezmoi) — generic-only"
  fi
  # chezmoi-данные: если в merged нет .chezmoidata.yaml — поднять из generic-.example.
  [ "$DRY" = 1 ] || [ -f "$MERGED/.chezmoidata.yaml" ] || cp "$MERGED/.chezmoidata.yaml.example" "$MERGED/.chezmoidata.yaml" 2>/dev/null || true

  run "chezmoi init --apply --source '$MERGED'"
  ok "~/.claude · ~/.codex · ~/.agents разложены (merged-source)"
}

# ───────── Слой 1b: плагины (reinstall из marketplaces) ─────────
layer1b_plugins() {
  phase 1 || return 0; say "Слой 1b — плагины"
  command -v claude >/dev/null || { warn "claude CLI нет — плагины пропущены"; return 0; }
  MAN="$HERE/plugins.manifest"
  [ -f "$MAN" ] || { warn "нет plugins.manifest — пропуск"; return 0; }
  while read -r kind arg _; do
    [ -z "${kind:-}" ] && continue; case "$kind" in \#*) continue ;; esac
    case "$kind" in
      marketplace) run "claude plugin marketplace add '$arg' || true"; ok "marketplace $arg" ;;
      plugin)      run "claude plugin install '$arg' || true";        ok "plugin $arg" ;;
    esac
  done < "$MAN"
}

# ───────── Слой 2: реестр SSOT ─────────
layer2_registry() {
  phase 2 || return 0; say "Слой 2 — реестр способностей"
  R="$HOME/.agents/registry/scripts"
  [ -d "$R" ] && run "cd '$R' && (python3 build_registry.py; python3 build_views.py; python3 validate.py) || true" \
    && ok "registry пересобран" || warn "нет ~/.agents/registry — придёт с дотфайлами"
}

# ───────── Слой 3: проекты (Работа) ─────────
layer3_projects() {
  phase 3 || return 0; say "Слой 3 — проекты"
  # Приватный манифест (athena-private) перекрывает дефолт, если есть.
  [ -f "$ATHENA_PRIVATE_DIR/projects.manifest" ] && ATHENA_PROJECTS_MANIFEST="$ATHENA_PRIVATE_DIR/projects.manifest"
  [ -f "$ATHENA_PROJECTS_MANIFEST" ] || { warn "нет манифеста проектов — пропуск"; return 0; }
  mkdir -p "$HOME/Проекты"
  # формат строки манифеста: <git-url> <относительный путь под ~/Проекты> [install-команда]
  while read -r url path cmd; do
    [ -z "${url:-}" ] && continue; case "$url" in \#*) continue ;; esac
    dest="$HOME/Проекты/$path"
    [ -d "$dest/.git" ] || run "git clone '$url' '$dest'"
    [ -n "${cmd:-}" ] && run "cd '$dest' && $cmd" || true
    ok "проект $path"
  done < "$ATHENA_PROJECTS_MANIFEST"
}

# ───────── Слой 4: знания (vault) ─────────
layer4_vault() {
  phase 4 || return 0; say "Слой 4 — vault Знаний"
  V="$HOME/Полезные знания"
  if [ -n "$ATHENA_VAULT_REPO" ] && [ ! -d "$V/.git" ]; then run "git clone '$ATHENA_VAULT_REPO' '$V'"; ok "vault склонирован"
  else warn "vault: задай ATHENA_VAULT_REPO или перенеси вручную"; fi
}

# ───────── Слой 5: секреты + MCP + автоматика ─────────
layer5_runtime() {
  phase 5 || return 0; say "Слой 5 — секреты · MCP · launchd"
  mkdir -p "$HOME/.secrets" && chmod 700 "$HOME/.secrets"
  warn "секреты: заполни по secrets-checklist.md (значения из Keychain, НЕ в git)"
  warn "MCP: переавторизуй по mcp-reauth.md"
  [ "$(uname)" = "Darwin" ] || { warn "не macOS — launchd пропущен"; return 0; }

  # launchd: generic (./launchd) + приватные (athena-private/launchd).
  # *.plist.example / *.plist.template не матчат *.plist → пропускаются (генерятся отдельно).
  for dir in "$HERE/launchd" "$ATHENA_PRIVATE_DIR/launchd"; do
    [ -d "$dir" ] || continue
    for p in "$dir"/*.plist; do [ -e "$p" ] || continue
      tgt="$HOME/Library/LaunchAgents/$(basename "$p")"
      run "sed 's#\\\$HOME#$HOME#g' '$p' > '$tgt'"
      run "launchctl unload '$tgt' 2>/dev/null; launchctl load '$tgt'"
    done
  done
  ok "launchd-агенты загружены (generic + приватные)"

  # telegram-бот: плист резолвит install-специфичный poetry-venv (хэш в имени venv).
  GEN="$ATHENA_PRIVATE_DIR/bin/gen-telegram-plist.sh"
  if [ -x "$GEN" ] && [ -d "$HOME/tools/claudecode-telegram" ]; then
    run "'$GEN'"; ok "telegram-плист собран (poetry-venv резолв)"
  elif [ -e "$GEN" ]; then
    warn "telegram: бот не установлен (~/tools/claudecode-telegram) — плист пропущен"
  fi
}

# ───────── Слой 6: smoke ─────────
layer6_smoke() {
  phase 6 || return 0; say "Слой 6 — smoke (паритет + структура)"
  [ -x "$HERE/smoke/smoke.sh" ] && run "'$HERE/smoke/smoke.sh'" && ok "smoke зелёный" || warn "нет smoke.sh"
}

say "Athena OS bootstrap → лог $LOG  (DRY=$DRY ONLY='${ONLY:-все}')"
layer0_base; layer1_brain; layer1b_plugins; layer2_registry; layer3_projects; layer4_vault; layer5_runtime; layer6_smoke
say "Готово. Проверь лог: $LOG"
