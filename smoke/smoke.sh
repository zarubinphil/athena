#!/usr/bin/env bash
# Athena smoke — инварианты структуры + паритет. Exit!=0 при провале.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
chk() { if eval "$2"; then printf '  ✓ %s\n' "$1"; else printf '  ✗ %s\n' "$1"; fail=1; fi; }

echo "── Athena smoke ──"

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

echo "[личное] нет имён/usernames/приватных идентификаторов владельца"
# Источник истины P0.2: grep, не ручной список. RED при срабатывании.
# Исключения: smoke.sh (сам содержит паттерн), docs/audit-2026-06-16/ (внутр. акт-запись,
#   git-rm/не-публикуется до P0.5 — НЕ часть публичного каркаса).
PERSONAL_RE='(Philipp|Zarubin|Филипп|zarubinphil|Кирилов|Ломоносов|Менделеев|Калачов|com\.zarubin)'
chk "нет личных данных в публичных tracked-файлах" "! grep -rIniE --exclude-dir=.git --exclude-dir=audit-2026-06-16 --exclude='smoke.sh' --exclude='*.log' \"\$PERSONAL_RE\" '$HERE' >/dev/null 2>&1"

echo "[канон] chezmoi-source Мозга на месте"
for f in chezmoi/dot_claude/CLAUDE.md chezmoi/dot_claude/settings.json.tmpl chezmoi/dot_claude/AGENTS.md.tmpl chezmoi/dot_claude/hooks/security-guard.sh chezmoi/dot_claude/rules/structure.md; do
  chk "$f" "[ -f '$HERE/$f' ]"
done
chk "settings.json deny-щит присутствует" "grep -q '\"deny\"' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"
echo "[самообучение] переносимая self-learning подсистема в каноне"
chk "skill self-learning" "[ -f '$HERE/chezmoi/dot_claude/skills/self-learning/SKILL.md' ]"
chk "create_-логи (создаются раз, не затираются)" "ls '$HERE'/chezmoi/dot_claude/self-learning/create_*.md >/dev/null 2>&1"
chk "ретро-шаблон" "[ -f '$HERE/chezmoi/dot_claude/self-learning/session-review-template.md' ]"
chk "security-guard синтаксис" "bash -n '$HERE/chezmoi/dot_claude/hooks/security-guard.sh'"
chk "health-check синтаксис" "bash -n '$HERE/chezmoi/dot_claude/scripts/health-check.sh'"

echo "[скрипты] валидны"
chk "bootstrap.sh синтаксис" "bash -n '$HERE/bootstrap.sh'"
chk "bootstrap.sh исполняем" "[ -x '$HERE/bootstrap.sh' ]"
command -v shellcheck >/dev/null && chk "shellcheck bootstrap.sh" "shellcheck -S error '$HERE/bootstrap.sh'" || echo "  · shellcheck не установлен (skip)"

echo "[паритет] Claude и Codex видят одно (если развёрнуто)"
if [ -d "$HOME/.claude" ] && [ -d "$HOME/.codex" ]; then
  # Реальная сверка содержимого, не факт существования папок (KGB-23).
  chk "~/.claude/AGENTS.md есть" "[ -e '$HOME/.claude/AGENTS.md' ]"
  chk "~/.codex/AGENTS.md есть (паритет реестра)" "[ -e '$HOME/.codex/AGENTS.md' ]"
else echo "  · дотфайлы ещё не развёрнуты (skip parity)"; fi

echo "[рендер] dry-validate шаблонов (merged-source, эмуляция)"
if [ -x "$HERE/smoke/dry-validate.sh" ]; then
  chk "dry-validate проходит" "'$HERE/smoke/dry-validate.sh' >/dev/null 2>&1"
else echo "  · dry-validate.sh нет (skip)"; fi

[ "$fail" = 0 ] && echo "SMOKE OK" || echo "SMOKE FAIL"
exit "$fail"
