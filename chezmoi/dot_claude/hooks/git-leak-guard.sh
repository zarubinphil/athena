#!/usr/bin/env bash
# Athena — git-leak-guard (PreToolUse: Bash). РЕАЛЬНЫЙ щит git-границы.
# Закрывает катастрофу «ключ → git → public»: ДЕТЕРМИНИРОВАННО сканит реальные
# байты staged-diff на сигнатуры ключей ПЕРЕД git commit/push. Не эвристика на текст
# команды (это bash-guard), а проверка фактического содержимого индекса.
#   exit 2 + stderr = БЛОК. exit 0 = пропуск.
# Архитектура щита (3 слоя): permissions.deny (Read/Write/Edit, kernel) + bash-guard
#   (Bash, эвристика, обходима) + ЭТОТ (git-граница, детерминированно на байтах).
# Bash-ЧТЕНИЕ ключа закрыть pattern-матчингом нельзя (33 вектора) — реальный щит там
#   = отсутствие ключа в зоне кода (Keychain / ~/.secrets / .env gitignored).
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0
cmd="$(printf '%s' "$INPUT" | tr '\n' ' ' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)/\1/p')"
cmd="${cmd%\"*}"
[ -z "$cmd" ] && exit 0

# Действуем ТОЛЬКО на git commit/push — иначе ноль накладных.
printf '%s' "$cmd" | grep -qE 'git([[:space:]]+-[^[:space:]]+)*[[:space:]]+(commit|push)' || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Сигнатуры РЕАЛЬНЫХ ключей (не упоминаний): AWS/GitHub/Slack/OpenAI-токены, private-key PEM.
LEAK_RE='(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{24,}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----)'

scan="$(git diff --cached 2>/dev/null || true)"
# commit -a / -am стейджит tracked-правки в момент коммита → доскан unstaged tracked.
if printf '%s' "$cmd" | grep -qE 'commit[^|;&]*[[:space:]]-[a-zA-Z]*a'; then
  scan="$scan
$(git diff 2>/dev/null || true)"
fi

if printf '%s' "$scan" | grep -qE "$LEAK_RE"; then
  printf '[git-leak-guard] BLOCKED: сигнатура ключа в коммите.\n  Ключ НЕ в git: Keychain / ~/.secrets (chmod 700) / .env (gitignored).\n  Если ключ реальный и попал в индекс — убери из staged + РОТИРУЙ его.\n' >&2
  exit 2
fi
exit 0
