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
# shellcheck disable=SC2034  # используется через eval в chk (строка 22)
SECRET_RE='(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{24,}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----|root@[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})'
chk "нет ключей/private-key/root@ip" "! grep -rInE --exclude-dir=.git --exclude='smoke.sh' --exclude='*.log' \"\$SECRET_RE\" '$HERE' >/dev/null 2>&1"

echo "[личное] нет имён/usernames/приватных идентификаторов владельца"
# Источник истины P0.2: grep, не ручной список. RED при срабатывании.
# Только git-TRACKED файлы (= что реально пушится). gitignored личное (athena.config.sh,
# *.log) и untracked (audit-2026-06-16/) в публичный каркас не попадают — git grep их не видит.
# Исключения-pathspec: smoke.sh (сам содержит паттерн).
# PCRE: Zarubin(?!phil) банит фамилию, но НЕ публичный GitHub-хэндл zarubinphil (clone/curl URL — публичен, не PII).
# shellcheck disable=SC2034  # используется через eval в chk (строка 31)
PERSONAL_RE='(Philipp|Filipp|Zarubin(?!phil)|Филипп|Кирилов|Ломоносов|Менделеев|Калачов|com\.zarubin|7teenno1)'
chk "нет личных данных в публичных tracked-файлах" "! git -C '$HERE' grep -IPni -e \"\$PERSONAL_RE\" -- ':!smoke/smoke.sh' ':!docs/audit-2026-06-16/**' >/dev/null 2>&1"
# Email автора в истории = PII вне file-grep. Разрешён только GitHub noreply.
chk "нет личных email в авторах коммитов" "! git -C '$HERE' log --format='%ae %ce' | tr ' ' '\n' | grep -vE '(noreply|^\$)' | grep -q ."

echo "[канон] chezmoi-source Сознания на месте"
for f in chezmoi/dot_claude/CLAUDE.md chezmoi/dot_claude/settings.json.tmpl chezmoi/dot_claude/AGENTS.md.tmpl chezmoi/dot_claude/hooks/security-guard.sh chezmoi/dot_claude/rules/structure.md; do
  chk "$f" "[ -f '$HERE/$f' ]"
done
chk "settings.json deny-щит присутствует" "grep -q '\"deny\"' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"
# CIA-3: source реестра пишет tilde, НЕ hardcode /Users/ (иначе портативность мертва;
# bootstrap нормализует live-дрейф, но source обязан стартовать чистым).
chk "SHARED-SKILLS source без hardcode /Users/" "! grep -q '/Users/' '$HERE/chezmoi/dot_agents/SHARED-SKILLS-WORKFLOWS.md'"
echo "[самообучение] переносимая self-learning подсистема в каноне"
chk "skill self-learning" "[ -f '$HERE/chezmoi/dot_claude/skills/self-learning/SKILL.md' ]"
chk "create_-логи (создаются раз, не затираются)" "ls '$HERE'/chezmoi/dot_claude/self-learning/create_*.md >/dev/null 2>&1"
chk "ретро-шаблон" "[ -f '$HERE/chezmoi/dot_claude/self-learning/session-review-template.md' ]"
chk "security-guard синтаксис" "bash -n '$HERE/chezmoi/dot_claude/hooks/security-guard.sh'"
chk "health-check синтаксис" "bash -n '$HERE/chezmoi/dot_claude/scripts/health-check.sh'"
chk "launchd-127-guard синтаксис" "bash -n '$HERE/chezmoi/dot_claude/scripts/launchd-127-guard.sh'"
chk "session-reaper синтаксис" "bash -n '$HERE/chezmoi/dot_claude/scripts/executable_session-reaper.sh'"

echo "[onboarding-grill] assets грилла первого запуска на месте"
SOS="$HERE/skills/setup-os"
chk "interview-rubric.md" "[ -f '$SOS/assets/interview-rubric.md' ]"
chk "composition-principles.md" "[ -f '$SOS/assets/composition-principles.md' ]"
chk "karpathy-method.md" "[ -f '$SOS/references/karpathy-method.md' ]"
chk "owner.template.md" "[ -f '$SOS/assets/owner.template.md' ]"
chk "CLAUDE.template ≤200 строк" "[ \"\$(wc -l < '$SOS/assets/CLAUDE.template.md')\" -le 200 ]"
chk "CLAUDE.template несёт P3-слоты {{ }}" "grep -q '{{' '$SOS/assets/CLAUDE.template.md'"
DETECT="$HERE/chezmoi/dot_claude/hooks/onboarding-detect.sh"
chk "детектор-хук onboarding-detect.sh" "[ -f '$DETECT' ]"
chk "onboarding-detect синтаксис" "bash -n '$DETECT'"
chk "SessionStart зарегистрирован в settings.tmpl" "grep -q 'SessionStart' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"
chk "settings.tmpl ссылается на onboarding-detect" "grep -q 'onboarding-detect.sh' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"

echo "[токен-учёт] паритет канона (скрипты + SessionEnd-wiring)"
chk "session-token-log.sh в каноне" "[ -f '$HERE/chezmoi/dot_claude/scripts/executable_session-token-log.sh' ]"
chk "token-spend.sh в каноне" "[ -f '$HERE/chezmoi/dot_claude/scripts/executable_token-spend.sh' ]"
chk "SessionEnd зарегистрирован в settings.tmpl" "grep -q 'SessionEnd' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"
chk "settings.tmpl проводит session-token-log на SessionEnd" "grep -q 'session-token-log.sh' '$HERE/chezmoi/dot_claude/settings.json.tmpl'"

echo "[onboarding-detect] поведение (functional, fake-HOME)"
OD_TMP="$(mktemp -d)"
od() { HOME="$1" bash "$DETECT" 2>/dev/null; }   # stdout: nudge-JSON или пусто
mkdir -p "$OD_TMP/h1/.claude/references"; printf '{{ИМЯ}}\n' > "$OD_TMP/h1/.claude/references/owner.md"
chk "owner.md с {{ → nudge" "od '$OD_TMP/h1' | grep -q 'setup-os'"
mkdir -p "$OD_TMP/h2/.claude/references"; printf '{{ИМЯ}}\n' > "$OD_TMP/h2/.claude/references/owner.md"; : > "$OD_TMP/h2/.claude/.athena-onboarded"
chk "маркер onboarded → молчит" "[ -z \"\$(od '$OD_TMP/h2')\" ]"
mkdir -p "$OD_TMP/h3/.claude/references"; printf '{{ИМЯ}}\n' > "$OD_TMP/h3/.claude/references/owner.md"; : > "$OD_TMP/h3/.claude/.athena-onboarding-snooze"
chk "snooze → молчит" "[ -z \"\$(od '$OD_TMP/h3')\" ]"
mkdir -p "$OD_TMP/h4/.claude/references"; printf 'Имя: кто-то\n' > "$OD_TMP/h4/.claude/references/owner.md"
chk "owner.md заполнен → молчит" "[ -z \"\$(od '$OD_TMP/h4')\" ]"
chk "owner.md заполнен → авто-ставит маркер" "[ -f '$OD_TMP/h4/.claude/.athena-onboarded' ]"
rm -rf "$OD_TMP"

echo "[security-guard] поведение (functional, не только синтаксис)"
GUARD="$HERE/chezmoi/dot_claude/hooks/security-guard.sh"
# mock-JSON на stdin → сверяем exit (2=блок, 0=пропуск)
ge() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$GUARD" >/dev/null 2>&1; echo $?; }
chk ".env → блок (exit 2)"                  '[ "$(ge /proj/.env)" = 2 ]'
chk ".env.example → пропуск (exit 0)"       '[ "$(ge /proj/.env.example)" = 0 ]'
# shellcheck disable=SC2088  # ~ в метке теста, путь реальный в кавычках
chk "~/.secrets/* → блок"                   '[ "$(ge /Users/u/.secrets/db)" = 2 ]'
chk "secret-shaped имя (db.key) → блок"     '[ "$(ge /proj/db.key)" = 2 ]'
chk ".env.production → блок"                '[ "$(ge /proj/.env.production)" = 2 ]'
chk "secrets/db.key (в подпапке) → блок"    '[ "$(ge /proj/secrets/db.key)" = 2 ]'
chk "id_ed25519 → блок"                     '[ "$(ge /Users/u/.ssh/id_ed25519)" = 2 ]'
chk "обычный .md → пропуск"                 '[ "$(ge /proj/readme.md)" = 0 ]'
chk "кириллический путь .env → блок (unicode-safe)" '[ "$(ge /Пользователь/проект/.env)" = 2 ]'

echo "[скрипты] валидны"
chk "bootstrap.sh синтаксис" "bash -n '$HERE/bootstrap.sh'"
chk "bootstrap.sh исполняем" "[ -x '$HERE/bootstrap.sh' ]"
command -v shellcheck >/dev/null && chk "shellcheck bootstrap.sh" "shellcheck -S error '$HERE/bootstrap.sh'" || echo "  · shellcheck не установлен (skip)"

echo "[launchd] plist валидны + PATH-консистентность"
if command -v plutil >/dev/null; then
  for p in "$HERE"/launchd/*.plist "$HERE"/launchd/*.plist.example; do
    [ -e "$p" ] || continue; b="$(basename "$p")"
    t="$(mktemp)"; sed "s#\$HOME#$HOME#g" "$p" > "$t"
    chk "plist валиден: $b" "plutil -lint '$t' >/dev/null 2>&1"; rm -f "$t"
    # Агенты с EnvironmentVariables.PATH обязаны включать $HOME/.local/bin (claude/node там; KGB-29).
    if grep -q '<key>PATH</key>' "$p"; then
      chk "PATH содержит \$HOME/.local/bin: $b" "grep -A1 '<key>PATH</key>' '$p' | grep -q '\$HOME/.local/bin'"
    fi
  done
else echo "  · plutil нет (skip — не macOS)"; fi

echo "[манифесты] синтаксис директив"
# plugins.manifest: каждая значимая строка = marketplace|plugin (Слой 1b парсит по 1-му полю; KGB-22).
chk "plugins.manifest без битых директив" "! grep -vE '^[[:space:]]*(#|\$|marketplace |plugin )' '$HERE/plugins.manifest'"

echo "[skills] root → deployed chezmoi (дрейф = юзер получит старый/ноль скилл)"
# Каждый root-скилл athena обязан иметь идентичную копию в chezmoi/dot_claude/skills/,
# иначе фиксы/новые скиллы не доезжают до юзера (E10). chezmoi может нести БОЛЬШЕ
# (deploy-only, напр. self-learning) — это норма, проверяем только root ⊆ chezmoi.
for d in "$HERE"/skills/*/; do
  n="$(basename "$d")"; cz="$HERE/chezmoi/dot_claude/skills/$n"
  chk "skills/$n → chezmoi идентичен" "[ -d '$cz' ] && diff -rq '$d' '$cz' >/dev/null 2>&1"
done

echo "[паритет] Claude и Codex видят одно (если развёрнуто)"
if [ -d "$HOME/.claude" ] && [ -d "$HOME/.codex" ]; then
  # Реальная сверка содержимого, не факт существования папок (KGB-23).
  # shellcheck disable=SC2088  # ~ в метках тестов, пути через $HOME в кавычках
  chk "~/.claude/AGENTS.md есть" "[ -e '$HOME/.claude/AGENTS.md' ]"
  # shellcheck disable=SC2088
  chk "~/.codex/AGENTS.md есть (паритет реестра)" "[ -e '$HOME/.codex/AGENTS.md' ]"
else echo "  · дотфайлы ещё не развёрнуты (skip parity)"; fi

echo "[рендер] dry-validate шаблонов (merged-source, эмуляция)"
if [ -x "$HERE/smoke/dry-validate.sh" ]; then
  chk "dry-validate проходит" "'$HERE/smoke/dry-validate.sh' >/dev/null 2>&1"
else echo "  · dry-validate.sh нет (skip)"; fi

[ "$fail" = 0 ] && echo "SMOKE OK" || echo "SMOKE FAIL"
exit "$fail"
