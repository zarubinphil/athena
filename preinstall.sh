#!/usr/bin/env bash
# Athena — Шаг 0 (руками в Терминале). Единственное, что агент не может: brew нужен пароль Mac.
# Ставит: Homebrew + базовые CLI + Claude Code. Дальше всё ведёт Claude (/setup-os).
# Идемпотентно: повторный запуск ничего не ломает.
#   curl -fsSL https://raw.githubusercontent.com/zarubinphil/athena/main/preinstall.sh | bash
set -euo pipefail

say() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }
ok()  { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }

[ "$(uname)" = "Darwin" ] || { echo "Только macOS"; exit 1; }

# 1. Command Line Tools (компилятор для brew)
xcode-select -p >/dev/null 2>&1 || { say "Ставлю Command Line Tools…"; xcode-select --install || true; }

# 2. Homebrew (спросит пароль Mac — это нормально)
if ! command -v brew >/dev/null && [ ! -x /opt/homebrew/bin/brew ]; then
  say "Ставлю Homebrew (введи пароль Mac когда попросит)…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 3. brew в PATH этой сессии + навсегда (~/.zprofile)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
if [ -x /opt/homebrew/bin/brew ] && ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
fi
ok "Homebrew готов"

# 4. Базовые CLI (нужны bootstrap-слоям)
for pkg in chezmoi node git; do command -v "$pkg" >/dev/null || brew install "$pkg"; done
ok "chezmoi · node · git готовы"

# 5. Claude Code CLI (--allow-scripts: postinstall без ручного approve, E5)
command -v claude >/dev/null || npm install -g @anthropic-ai/claude-code --allow-scripts
ok "Claude Code готов"

cat <<'DONE'

────────────────────────────────────────────
✓ Шаг 0 завершён. Дальше:

  cd ~/athena        (или куда склонил репо)
  claude
  В Claude набери:  /setup-os

Отвечай на всплывающие вопросы — остальное само.
────────────────────────────────────────────
DONE
