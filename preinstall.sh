#!/usr/bin/env bash
# Athena — Шаг 0 (руками в Терминале). Единственное, что агент не может: brew нужен пароль Mac.
# Ставит: Homebrew + базовые CLI + Claude Code. Дальше всё ведёт Claude (/setup-os).
# Идемпотентно: повторный запуск ничего не ломает.
#   curl -fsSL https://raw.githubusercontent.com/zarubinphil/athena/main/preinstall.sh | bash
set -euo pipefail

say() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }

[ "$(uname)" = "Darwin" ] || { echo "Только macOS"; exit 1; }

# 1. Command Line Tools (компилятор для brew). --install не блокирует —
#    открывает GUI-попап и сразу возвращает. Ждём реального завершения,
#    иначе brew падает без компилятора в середине Шага 0.
if ! xcode-select -p >/dev/null 2>&1; then
  say "Ставлю Command Line Tools — подтверди установку в попапе…"
  xcode-select --install >/dev/null 2>&1 || true
  until xcode-select -p >/dev/null 2>&1; do sleep 5; done
  ok "Command Line Tools готовы"
fi

# 2. Homebrew (спросит пароль Mac — это нормально)
if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
  say "Ставлю Homebrew (введи пароль Mac когда попросит)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || { echo "Ошибка установки Homebrew (сеть?). Перезапусти preinstall.sh."; exit 1; }
fi

# 3. brew в PATH этой сессии + навсегда (~/.zprofile). M-chip → /opt/homebrew, Intel → /usr/local.
BREW_BIN="$(command -v brew || true)"
[ -z "$BREW_BIN" ] && [ -x /opt/homebrew/bin/brew ] && BREW_BIN=/opt/homebrew/bin/brew
[ -z "$BREW_BIN" ] && [ -x /usr/local/bin/brew ]   && BREW_BIN=/usr/local/bin/brew
[ -x "$BREW_BIN" ] || { echo "brew не найден после установки. Перезапусти preinstall.sh."; exit 1; }
eval "$("$BREW_BIN" shellenv)"
if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
  echo "eval \"\$($BREW_BIN shellenv)\"" >> "$HOME/.zprofile"
fi
ok "Homebrew готов"

# 4. Базовые CLI (нужны bootstrap-слоям)
for pkg in chezmoi node git; do command -v "$pkg" >/dev/null || brew install "$pkg"; done
ok "chezmoi · node · git готовы"

# 5. Claude Code CLI (--allow-scripts: postinstall без ручного approve, E5)
# Версия пиновкой (supply-chain): обновляй при апгрейде Claude Code. npm view @anthropic-ai/claude-code version
command -v claude >/dev/null || npm install -g @anthropic-ai/claude-code@2.1.183 --allow-scripts
ok "Claude Code готов"

# 6. Клон репо Athena (нужен для /setup-os). Идемпотентно.
[ -d "$HOME/athena/.git" ] || git clone https://github.com/zarubinphil/athena "$HOME/athena"
ok "репо Athena в ~/athena"

cat <<'DONE'

────────────────────────────────────────────
✓ Шаг 0 завершён. Дальше:

  cd ~/athena
  claude
  В Claude набери:  /setup-os

Отвечай на всплывающие вопросы — остальное само.
────────────────────────────────────────────
DONE
