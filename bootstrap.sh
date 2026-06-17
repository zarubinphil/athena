#!/usr/bin/env bash
# Athena — оркестратор полного разворота на чистом Mac.
# Один прогон: база → Сознание(дотфайлы) → реестр → проекты → знания → секреты+MCP+launchd → smoke.
# Идемпотентно. Личные значения — в athena.config.sh (gitignored, из athena.config.example.sh).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${TMPDIR:-/tmp}/athena-bootstrap-$(date +%Y%m%d-%H%M%S).log"
DRY=0; ONLY=""; BOOT_ERRS=0   # агрегат сбоев (launchd и пр.) → ненулевой exit
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
: "${ATHENA_TOOLS_MANIFEST:=$ATHENA_PRIVATE_DIR/tools.manifest}"   # внешние инструменты → ~/tools (Слой 0b)

# Клон приватного overlay (idempotent) — нужен Слоям 0b/1/3/5.
ensure_private() {
  [ -n "$ATHENA_PRIVATE_REPO" ] && [ ! -d "$ATHENA_PRIVATE_DIR/.git" ] \
    && run "git clone '$ATHENA_PRIVATE_REPO' '$ATHENA_PRIVATE_DIR'" || true
}

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

# ───────── Слой 0b: инструменты (~/tools — боты и т.п., ДО Сознания) ─────────
# Клонится ДО Слоя 1: chezmoi run_once_ генерит .env бота при apply, если бот уже на месте.
layer_tools() {
  phase 0b || return 0; say "Слой 0b — инструменты (~/tools)"
  ensure_private
  [ -f "$ATHENA_TOOLS_MANIFEST" ] || { warn "нет tools.manifest — пропуск"; return 0; }
  mkdir -p "$HOME/tools"
  # формат строки: <git-url> <относительный путь под ~/tools> [install-команда]
  while read -r url path cmd; do
    [ -z "${url:-}" ] && continue; case "$url" in \#*) continue ;; esac
    dest="$HOME/tools/$path"
    [ -d "$dest/.git" ] || run "git clone '$url' '$dest'"
    [ -n "${cmd:-}" ] && run "cd '$dest' && $cmd" || true
    ok "инструмент $path"
  done < "$ATHENA_TOOLS_MANIFEST"
}

# ───────── Слой 1: Сознание (дотфайлы через chezmoi merged-source) ─────────
# Источник = generic-канон (./chezmoi) ⊕ приватный overlay (athena-private/chezmoi).
# Overlay побеждает на конфликте; добавляет личное (references, launchd-скрипты, run_once_).
layer1_brain() {
  phase 1 || return 0; say "Слой 1 — Сознание (дотфайлы, merged-source)"
  command -v chezmoi >/dev/null || run "brew install chezmoi"

  # Продвинутый escape-hatch: готовый внешний source целиком, без merge.
  if [ -n "$ATHENA_DOTFILES_REPO" ]; then
    run "chezmoi init --apply '$ATHENA_DOTFILES_REPO'"
    ok "дотфайлы из внешнего source ($ATHENA_DOTFILES_REPO)"; return 0
  fi

  ensure_private   # клон overlay, если ещё нет (idempotent; обычно сделан Слоем 0b)

  # Сборка merged-source: generic база (--delete = чистый старт) ⊕ приватный overlay.
  run "mkdir -p '$MERGED'"
  run "rsync -a --delete --exclude '.git' '$HERE/chezmoi/' '$MERGED/'"
  if [ -d "$ATHENA_PRIVATE_DIR/chezmoi" ]; then
    run "rsync -a --exclude '.git' '$ATHENA_PRIVATE_DIR/chezmoi/' '$MERGED/'"
    ok "приватный overlay наложен ($ATHENA_PRIVATE_DIR)"
    # Дедуп target-конфликтов: реальный файл из overlay затеняет generic-symlink того же
    # target (иначе chezmoi: duplicate target). Напр. overlay dot_codex/AGENTS.md побеждает
    # generic dot_codex/symlink_AGENTS.md.tmpl.
    if [ "$DRY" != 1 ]; then
      while IFS= read -r -d '' sl; do
        d="$(dirname "$sl")"; b="$(basename "$sl")"; t="${b#symlink_}"; t="${t%.tmpl}"
        if [ -e "$d/$t" ] || [ -e "$d/$t.tmpl" ]; then rm -f "$sl"; fi
      done < <(find "$MERGED" -name 'symlink_*' -print0)
    fi
  else
    warn "приватный overlay не найден ($ATHENA_PRIVATE_DIR/chezmoi) — generic-only"
  fi
  # chezmoi-данные: если в merged нет .chezmoidata.yaml — поднять из generic-.example.
  [ "$DRY" = 1 ] || [ -f "$MERGED/.chezmoidata.yaml" ] || cp "$MERGED/.chezmoidata.yaml.example" "$MERGED/.chezmoidata.yaml" 2>/dev/null || true

  run "chezmoi init --apply --source '$MERGED'"
  ok "~/.claude · ~/.codex · ~/.agents разложены (merged-source)"

  # CIA-3: нормализация абс.путей в live-реестре. Source пишет `~/.agents/...` (tilde),
  # но агенты со временем вписывают `$HOME/.agents/...` (реверт-мутация) — шаблон это не
  # лечит, апплай чистый только в момент apply. Чиним каждый прогон. Scope СТРОГО реестр-доки
  # (риск: sed зацепил бы легитимный homeDir-литерал в AGENTS.md, который chezmoi рендерит
  # из `{{ .chezmoi.homeDir }}` ПО ДИЗАЙНУ). На чистой машине это no-op (live == чистый шаблон).
  if [ "$DRY" != 1 ]; then
    local rfiles=("$HOME/.agents/SHARED-SKILLS-WORKFLOWS.md")
    for rf in "${rfiles[@]}"; do
      [ -f "$rf" ] && sed -i '' "s#$HOME/#~/#g" "$rf"
    done
    ok "абс.пути live-реестра нормализованы → ~ (анти-дрейф)"
  else
    echo "  [dry] нормализация абс.путей реестра → ~" | tee -a "$LOG"
  fi
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
  V="$HOME/Мозг"
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
  # Fail-closed: считаем loaded/errs, ok ТОЛЬКО при errs==0; bootout/bootstrap (не deprecated load).
  local loaded=0 errs=0 uid; uid="$(id -u)"
  for dir in "$HERE/launchd" "$ATHENA_PRIVATE_DIR/launchd"; do
    [ -d "$dir" ] || continue
    for p in "$dir"/*.plist; do [ -e "$p" ] || continue
      local label tgt; label="$(basename "$p" .plist)"
      tgt="$HOME/Library/LaunchAgents/$(basename "$p")"
      run "sed 's#\\\$HOME#$HOME#g' '$p' > '$tgt'"
      if [ "$DRY" = 1 ]; then echo "  [dry] launchctl bootout/bootstrap gui/$uid $label" | tee -a "$LOG"; loaded=$((loaded+1)); continue; fi
      launchctl bootout "gui/$uid/$label" >>"$LOG" 2>&1 || true   # выгрузка, если был
      if launchctl bootstrap "gui/$uid" "$tgt" >>"$LOG" 2>&1; then
        loaded=$((loaded+1))
      else
        errs=$((errs+1)); warn "launchd $label НЕ загрузился (см. $LOG)"
      fi
    done
  done
  if [ "$errs" -eq 0 ]; then ok "launchd-агенты загружены: $loaded"; else warn "launchd: $loaded ок, $errs с ошибкой"; BOOT_ERRS=$((BOOT_ERRS+errs)); fi

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

say "Athena bootstrap → лог $LOG  (DRY=$DRY ONLY='${ONLY:-все}')"
layer0_base; layer_tools; layer1_brain; layer1b_plugins; layer2_registry; layer3_projects; layer4_vault; layer5_runtime; layer6_smoke
if [ "$BOOT_ERRS" -eq 0 ]; then
  say "Готово. Проверь лог: $LOG"
else
  warn "Готово с ошибками ($BOOT_ERRS) — НЕ всё поднялось. Лог: $LOG"
  exit 1
fi
