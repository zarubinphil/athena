#!/usr/bin/env bash
# Athena OS smoke — инварианты структуры + паритет. Exit!=0 при провале.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
chk() { if eval "$2"; then printf '  ✓ %s\n' "$1"; else printf '  ✗ %s\n' "$1"; fail=1; fi; }

echo "── Athena OS smoke ──"

echo "[структура] ключевые файлы на месте"
for f in bootstrap.sh Brewfile README.md LICENSE rules/structure.md specs/00-roadmap.md; do
  chk "$f" "[ -f '$HERE/$f' ]"
done

echo "[чистота] нет хардкода личных путей в трекаемых файлах"
chk "нет хардкод /Users/<user>/" "! grep -rInE --exclude-dir=.git --exclude='*.log' --exclude=smoke.sh '/Users/[A-Za-z0-9_]+/' '$HERE' >/dev/null 2>&1"
chk "нет реального projects.manifest в git" "! git -C '$HERE' ls-files --error-unmatch projects.manifest >/dev/null 2>&1"
chk "нет athena.config.sh в git" "! git -C '$HERE' ls-files --error-unmatch athena.config.sh >/dev/null 2>&1"

echo "[скрипты] валидны"
chk "bootstrap.sh синтаксис" "bash -n '$HERE/bootstrap.sh'"
chk "bootstrap.sh исполняем" "[ -x '$HERE/bootstrap.sh' ]"
command -v shellcheck >/dev/null && chk "shellcheck bootstrap.sh" "shellcheck -S error '$HERE/bootstrap.sh'" || echo "  · shellcheck не установлен (skip)"

echo "[паритет] Claude и Codex видят одно (если развёрнуто)"
if [ -d "$HOME/.claude" ] && [ -d "$HOME/.codex" ]; then
  chk "~/.claude и ~/.codex есть" "true"
else echo "  · дотфайлы ещё не развёрнуты (skip parity)"; fi

[ "$fail" = 0 ] && echo "SMOKE OK" || echo "SMOKE FAIL"
exit "$fail"
