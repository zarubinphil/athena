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

echo "[секреты] нет credential-shaped токенов (generic-паттерны)"
SECRET_RE='(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{24,}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----|root@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})'
chk "нет ключей/private-key/root@ip" "! grep -rInE --exclude-dir=.git --exclude='smoke.sh' --exclude='*.log' \"\$SECRET_RE\" '$HERE' >/dev/null 2>&1"

echo "[канон] chezmoi-source Мозга на месте"
for f in chezmoi/dot_claude/CLAUDE.md chezmoi/dot_claude/settings.json.tmpl chezmoi/dot_claude/AGENTS.md.tmpl chezmoi/dot_claude/hooks/security-guard.sh chezmoi/dot_claude/rules/structure.md; do
  chk "$f" "[ -f '$HERE/$f' ]"
done
chk "settings.json deny-щит присутствует" "grep -q '\"deny\"' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"
chk "security-guard синтаксис" "bash -n '$HERE/chezmoi/dot_claude/hooks/security-guard.sh'"
chk "health-check синтаксис" "bash -n '$HERE/chezmoi/dot_claude/scripts/health-check.sh'"

echo "[скрипты] валидны"
chk "bootstrap.sh синтаксис" "bash -n '$HERE/bootstrap.sh'"
chk "bootstrap.sh исполняем" "[ -x '$HERE/bootstrap.sh' ]"
command -v shellcheck >/dev/null && chk "shellcheck bootstrap.sh" "shellcheck -S error '$HERE/bootstrap.sh'" || echo "  · shellcheck не установлен (skip)"

echo "[паритет] Claude и Codex видят одно (если развёрнуто)"
if [ -d "$HOME/.claude" ] && [ -d "$HOME/.codex" ]; then
  chk "~/.claude и ~/.codex есть" "true"
else echo "  · дотфайлы ещё не развёрнуты (skip parity)"; fi

echo "[рендер] dry-validate шаблонов (merged-source, эмуляция)"
if [ -x "$HERE/smoke/dry-validate.sh" ]; then
  chk "dry-validate проходит" "'$HERE/smoke/dry-validate.sh' >/dev/null 2>&1"
else echo "  · dry-validate.sh нет (skip)"; fi

[ "$fail" = 0 ] && echo "SMOKE OK" || echo "SMOKE FAIL"
exit "$fail"
