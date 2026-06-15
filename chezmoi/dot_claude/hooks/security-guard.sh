#!/usr/bin/env bash
# Athena OS — детерминированный security-guard (PreToolUse: Write|Edit|MultiEdit).
# Инвариант "куда НЕЛЬЗЯ писать" (rules/structure.md §8). Дополняет settings.json
# permissions.deny: deny ловит чтение, этот хук — запись + secret-shaped имена.
# Контракт хука: stdin = JSON {tool_name, tool_input{file_path,...}}.
#   exit 2 + stderr = БЛОК (показывается модели). exit 0 = пропуск.
# Без зависимостей (jq не требуется) — портативно на чистом Mac.
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

# file_path из tool_input без jq (берём первое совпадение)
fp="$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$fp" ] && exit 0

base="$(basename "$fp")"
deny() {
  printf '[security-guard] BLOCKED write → %s\n  причина: %s\n  секреты: Keychain / ~/.secrets (chmod 700), НЕ в код/git\n' \
    "$fp" "$1" >&2
  exit 2
}

# .env-шаблоны разрешены (пример/семпл), боевой .env — нет
case "$fp" in
  *.env.example|*.env.sample|*.env.template|*.env.dist|*.env.local.example) : ;;
  *.env|*.env.*) deny ".env — секреты не в трекаемых файлах" ;;
esac

case "$fp" in
  */.ssh/*|*id_rsa*|*id_dsa*|*id_ecdsa*|*id_ed25519*) deny "SSH-ключи" ;;
  */.secrets/*|*/.claude/secrets/*)                   deny "хранилище секретов" ;;
  */server.env|*/.claude/mcp.json)                     deny "рантайм secret/auth" ;;
  */.git-credentials|*/.config/gh/*)                   deny "git/gh credentials" ;;
esac

case "$base" in
  *secret*|*credential*|*.pem|*.key|*.ovpn|*.p12|*.keystore) deny "secret-shaped имя" ;;
esac

exit 0
