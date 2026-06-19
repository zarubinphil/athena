#!/usr/bin/env bash
# Athena — детерминированный bash-guard (PreToolUse: Bash).
# Закрывает exec-gap: permissions.deny + security-guard ловят Read/Write/Edit,
# но Bash проходил мимо (echo SK > ~/.env, git push --force main молча).
# Контракт хука: stdin = JSON {tool_name, tool_input{command,...}}.
#   exit 2 + stderr = БЛОК (показывается модели). exit 0 = пропуск.
# Без зависимостей (jq не требуется) — портативно на чистом Mac.
# ВАЖНО: hook = первый слой, НЕ kernel. Bash-анализ обходим (33 вектора, GH#57901);
#   реальный щит секретов — их отсутствие в ФС-зоне кода (Keychain/~/.secrets).
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

# command из tool_input без jq (первое совпадение). Многострочный JSON → tr к одной строке.
cmd="$(printf '%s' "$INPUT" | tr '\n' ' ' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)/\1/p')"
# срезать хвост после закрывающей кавычки значения (грубо, но command обычно последнее поле)
cmd="${cmd%\"*}"
[ -z "$cmd" ] && exit 0

deny() {
  printf '[bash-guard] BLOCKED команда\n  причина: %s\n  секреты: Keychain / ~/.secrets (chmod 700), НЕ в код/git\n' "$1" >&2
  exit 2
}

# 0. Benign-гейт: команды, где секрет-токен живёт лишь в строке-литерале, ничего не исполняя.
#    anti-FP: `echo "git push --force main"`, `git commit -m "...>~/.env..."` (док/сообщения).
#    Условие исполнения = SEP (chaining ;&| или subst $()/backtick) → при нём НЕ benign.
#    echo/printf/: дополнительно требуют отсутствия `>` (иначе `echo x >~/.env` = rule1).
#    `echo $(cat ~/.ssh/id_)` → есть `$(` → НЕ benign → ловится.
first="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*//' | awk '{print $1}')"
second="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]*//' | awk '{print $2}')"
# SEP = реально исполняемое: chaining (;&|) + command-substitution ($()/backtick).
# Любая ветка с SEP → НЕ benign (второй command/subst исполнит деструктив).
SEP='[;&|]|\$\(|`'
if ! printf '%s' "$cmd" | grep -qE "$SEP"; then
  # git commit/tag — токены живут в -m/-F тексте, сам коммит деструктив не исполняет; `>` (redirect/в msg) безвреден.
  if [ "$first" = git ] && { [ "$second" = commit ] || [ "$second" = tag ]; }; then exit 0; fi
  # echo/printf/: — чистый print; но `>` мог бы писать в секрет (rule1) → требуем его отсутствие.
  case "$first" in echo|printf|:)
    printf '%s' "$cmd" | grep -qE '>' || exit 0 ;;
  esac
fi

# 1. Запись в секрет-пути через redirect/tee/cp/mv/dd → блок.
if printf '%s' "$cmd" | grep -qE '(>>?|tee|cp|mv|dd|install)[^|;&]*(\.env([^.a-zA-Z]|$)|\.ssh/|\.secrets/|mcp\.json|\.git-credentials|\.pem|\.ovpn|\.key([^a-zA-Z]|$))'; then
  deny "запись в секрет-путь/файл через shell"
fi

# 2. Force-push в защищённые ветки → безусловный блок (необратимо для общей истории).
if printf '%s' "$cmd" | grep -qE 'git[[:space:]].*push[[:space:]].*(--force([^-]|$)|-f([^a-zA-Z]|$)|--force-with-lease)' \
   && printf '%s' "$cmd" | grep -qE '\b(main|master)\b'; then
  deny "force-push в main/master — необратимо для общей истории, делай через PR"
fi

# 3. Чтение секретов наружу (cat/less секрет → возможна эксфильтрация в вывод/сеть).
if printf '%s' "$cmd" | grep -qE '(cat|less|more|head|tail|strings|xxd)[^|;&]*(\.ssh/id_|\.secrets/|\.git-credentials|server\.env|/secrets/)'; then
  deny "чтение секрета в shell-вывод"
fi

exit 0
