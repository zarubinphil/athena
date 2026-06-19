#!/usr/bin/env bash
# Smoke-тест bash-guard: реальный деструктив = БЛОК (exit 2), echo-литерал = ПРОПУСК (exit 0).
# Запуск: smoke/bash-guard.test.sh  (gate: все 8 кейсов PASS).
set -uo pipefail
GUARD="${1:-$(cd "$(dirname "$0")/.." && pwd)/chezmoi/dot_claude/hooks/bash-guard.sh}"
[ -f "$GUARD" ] || { echo "guard not found: $GUARD" >&2; exit 1; }

# токены из переменных — иначе живой guard на этом же файле словит литералы
P=push; F=--force; M=main; ID=.ssh/id_rsa; ENV=server.env
run(){ printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" | bash "$GUARD" >/dev/null 2>&1; echo $?; }

fail=0
check(){ # want_exit cmd label
  got=$(run "$2")
  if [ "$got" = "$1" ]; then printf 'PASS  %s\n' "$3"
  else printf 'FAIL  %s (want exit %s, got %s)\n' "$3" "$1" "$got"; fail=1; fi
}

# Реальный деструктив → блок (exit 2)
check 2 "git $P $F $M"                 "real force-push main"
check 2 "cat ~/$ID"                    "real read ssh key"
check 2 "echo sk > ~/.env"             "redirect into .env (rule1)"
check 2 "echo hi && cat ~/$ID"         "chained real read after echo"
# Безопасные echo-литералы → пропуск (exit 0)
check 0 "echo \\\"git $P $F $M\\\""    "echo mention force-push"
check 0 "echo \\\"cat ~/$ID\\\""       "echo mention ssh read"
check 0 "printf '%s' '$ENV here'"      "printf mention secret"
check 0 "echo hi"                      "plain echo"
check 0 "git commit -m 'fix $P $F $M in guard'" "git commit msg mentions force-push"
check 0 "git commit -m 'echo > ~/.env note'"    "git commit msg mentions redirect"
check 2 "git commit -m x && cat ~/$ID"  "git commit chained real read"

[ "$fail" = 0 ] && echo "--- bash-guard: ALL PASS ---" || { echo "--- bash-guard: FAILURES ---"; exit 1; }
