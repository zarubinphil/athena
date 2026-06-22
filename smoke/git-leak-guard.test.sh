#!/usr/bin/env bash
# Smoke-тест git-leak-guard: реальный ключ в staged → БЛОК (exit 2); чистый коммит → пропуск (0).
# Изолированный temp-репо (никакой реальный git не трогается). Gate: все кейсы PASS.
set -uo pipefail
GUARD="${1:-$(cd "$(dirname "$0")/.." && pwd)/chezmoi/dot_claude/hooks/git-leak-guard.sh}"
[ -f "$GUARD" ] || { echo "guard not found: $GUARD" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init -q
git -C "$TMP" config user.email t@t; git -C "$TMP" config user.name t

run(){ # $1=command-строка → exit code guard, запуск из TMP-репо
  ( cd "$TMP" && printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | bash "$GUARD" >/dev/null 2>&1; echo $? )
}
fail=0
check(){ got=$(run "$2"); if [ "$got" = "$1" ]; then printf 'PASS  %s\n' "$3"
  else printf 'FAIL  %s (want %s got %s)\n' "$3" "$1" "$got"; fail=1; fi; }

# Реальный AWS-ключ в staged → блок. (ключ собран из кусков — не триггерит сам сканер на этом файле)
AK="AKIA"; printf 'token=%sIOSFODNN7EXAMPLE\n' "$AK" > "$TMP/leak.txt"; git -C "$TMP" add leak.txt
check 2 "git commit -m x"                "staged AWS key -> блок"
check 2 "git push origin main"           "push с ключом в индексе -> блок"
check 0 "ls -la"                         "не-git команда -> пропуск"
# Чистый файл вместо ключа
git -C "$TMP" reset -q; printf 'just config text\n' > "$TMP/leak.txt"; git -C "$TMP" add leak.txt
check 0 "git commit -m clean"            "чистый staged -> пропуск"
# Упоминание слова AKIA без валидного ключа (не 16 alnum) → пропуск (не FP)
printf 'see AKIA format in docs\n' > "$TMP/doc.txt"; git -C "$TMP" add doc.txt
check 0 "git commit -m docs"             "упоминание AKIA-формата -> пропуск"

[ "$fail" = 0 ] && echo "--- git-leak-guard: ALL PASS ---" || { echo "--- git-leak-guard: FAILURES ---"; exit 1; }
