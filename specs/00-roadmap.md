# Athena — дорожная карта

Регламент: grill-me → план → утверждение → реализация. Грилл и утверждение пройдены 2026-06-15.

## Фаза 1 — чистый каркас (текущая)
Generic-репо под открытый GitHub, clean-room (боевой `~/.claude` НЕ трогаем).
- [x] Скаффолд из claude-starter + структура athena
- [x] `rules/structure.md` — конституция раскладки
- [x] `bootstrap.sh` — оркестратор слоёв 0–6
- [x] `Brewfile`, `README.md`, `CLAUDE.md`, `LICENSE`
- [x] `projects.manifest.example`, `secrets-checklist.md`, `mcp-reauth.md`, `athena.config.example.sh`
- [x] `skills/organize/SKILL.md` (новый), копии `setup-os` + `bootstrap-project`
- [x] `smoke/smoke.sh` — зелёный
- [x] git init + commit (48 файлов)
- [x] `launchd/*.plist` шаблоны → сделано в Фазе 2 (health + session-reaper.example)
**DoD:** ✓ репо самодостаточно, `./bootstrap.sh --dry-run` проходит, 0 личных данных. (shellcheck — в Brewfile, ставится на bootstrap.)

## Фаза 2 — курирование канона Сознания (chezmoi-source) ✓
Generic chezmoi-source собран (чистая пересборка, НЕ дамп 1.2 ГБ):
- [x] `dot_claude`: `CLAUDE.md` (лин-роутер) · `AGENTS.md.tmpl` (VPS-IP вычищен, пути templated) · `settings.json.tmpl` (deny-щит 20 паттернов) · `hooks/security-guard.sh` (детерминированный, behavior-tested) · `rules/` (structure + ECC 19 наборов: common/web + 17 языков) · 30 generic ECC-агентов · `scripts/health-check.sh`
- [x] `dot_codex`: symlink-паритет → claude-канон
- [x] `dot_agents`: registry SSOT (12 скриптов HOME-генерик + REGISTRY/CAPABILITY-PLANNING/SHARED docs)
- [x] плагины: `plugins.manifest` + bootstrap Слой 1b (marketplace add + install)
- [x] launchd: `health.plist`+скрипт (PATH-фикс 127); `session-reaper.plist.example` (скрипт → Ф4)
- [x] smoke++ (secret-токен guard + канон) ЗЕЛЁНЫЙ; шаблоны render-validated (homeDir → валидный JSON)
- [x] 0 hard личных данных в source; soft: «Мнемозина» (богиня памяти) / «Mnemazine» (имя проекта) — РЕШЕНО оба канон, НЕ санитайзятся (KGB-19 accepted с14); «owner» в шаблонах — generic-плейсхолдер
**DoD:** source render-validated + smoke зелёный. Живой `chezmoi apply` — ТОЛЬКО на чистом таргете (на боевом юзере перетёр бы рабочий `~/.claude` — clean-room), переносится в Ф5 e2e.

## Фаза 3 — аккуратный рефактор реальной структуры (частично, 2026-06-15)
Бэкап-first. Бэкап: `~/.athena-backups/phase3-20260615-200700` (claude-config 4M + agents 34M + плисты).

**Сделано (бэкап → правка → верификация каждого шага):**
- [x] live `com.fil.mnemosyne-health` — 127-баг (claude не в PATH: login-shell `-lc` читает `.zprofile`, не `.zshrc`). Фикс: префикс `export PATH` с `$HOME/.local/bin` в `-lc`. Заодно экранированы сырые `&&`/`2>&1` → XML стал валиден (plutil OK). Агент перезагружен. Откат: `…plist.bak-phase3`.
- [x] repo `launchd/com.athena.health.plist` — латентный 127 (PATH без `~/.local/bin`, куда ставится claude). Добавлен `$HOME/.local/bin`. smoke зелёный.

**Разворот — НЕ де-хардкодить `kb-pipeline.js`:** Workflow-скрипт в sandbox БЕЗ Node API (`process` защищён `typeof!==undefined`, Date запрещён) → `os.homedir()`/`process.env.HOME` сломали бы старт; литерал `$HOME` ломает JS-сравнения путей (`indexOf(INBOX)`); файл ЛИЧНЫЙ → Ф4 overlay. Портативность личных Workflow = chezmoi-`.tmpl` `{{ .chezmoi.homeDir }}` (рендер в литерал при apply), Ф4.

**Инсайт:** clean-room НЕ накрывает боевую машину `chezmoi apply` → де-хардкод live-файлов = НОЛЬ портативности (она в repo-каноне для чистых машин). Ценность live-правок = только (1) живые баги, (2) точность repo-канона. Live registry де-хардкод → отложен до Ф5 (если/когда live станет chezmoi-managed).

**Отложено — отдельной сессией под явную отмашку (высокий риск, личные файлы/секреты):**
- FS-реорг: проекты→`~/Проекты`, единый интейк (сейчас `~/Desktop/_ВХОДЯЩИЕ`), `~/.secrets`. Блок-радиус: пути в launchd/kb-pipeline/конфигах. План-first до любых `mv`.
- `мнемозина-pipeline.js` stale-дубль (claude+codex) vs канон `kb-pipeline.js` — гигиена Мнемозина-проекта (хук `kb-archive-guard.sh` ещё знает имя в allowlist). Флаг отдельной задачей.

**DoD (для отложенной FS-части):** mnemosyne/femida/coffee работают после переезда; 0 битых ссылок.

## Фаза 4 — приватные репо + Keychain + launchd (автор+dry готовы, 2026-06-15)
`vault-znaniya` + `athena-private` (overlay) приватные/pushed (private-account). Merged-source,
секреты Keychain+app-`.env`, личные launchd-агенты. Live e2e → Ф5 (clean-room).

**Сделано (план-first каждый блок, бэкап-first, верификация):**
- [x] **STEP1 секрет-фикс:** tg-токен убран из `com.private-account.claudetelegrambot.plist` (был 644 world-readable) → читается из app-`.env` (600, pydantic). Бэкап `~/.athena-backups/phase4-20260615-222008`.
- [x] **Личный launchd → athena-private:** 4 агента. session-reaper.sh = generic-инфра (чистый `$HOME`) → едет из athena; активный плист владельца + weekly-update + idea-plans + telegram → athena-private. VPS-IP в скриптах templated (`.athena.vps_host`). Telegram: `.template` + `gen-telegram-plist.sh` (резолв poetry-venv хэша при install). PATH-env добавлен (латентный 127 в weekly/idea — скрипты зовут npm/node).
- [x] **Keychain (тулинг, 0 live-записи):** `bin/migrate-secrets.sh` (live `.env`→Keychain) + chezmoi `run_once_after_30-telegram-env.sh.tmpl` (Keychain→`.env` 600, self-contained, в git только `security find`). keenetic уже Keychain-backed. Live-миграция → владелец после ротации tg-токена.
- [x] **Манифест проектов → athena-private:** `projects.manifest` (private-account/Mnemazine→mnemazine, private-account/themis→themis). Живые разбросанные копии не трогаются (FS-реорг отдельно).
- [x] **bootstrap merged-source:** layer1 собирает generic⊕private overlay (rsync) → один `chezmoi init --apply`. layer3 берёт приватный манифест, layer5 грузит оба launchd-дира + telegram-ген. Новые vars `ATHENA_PRIVATE_REPO`/`_DIR`/`MERGED`.
- [x] **dry-validate (эмуляция, без chezmoi):** `smoke/dry-validate.sh` — merge→temp, рендер известных vars, plutil/json/bash-n + лов неизвестных `{{ }}`. Включён в `smoke.sh`. Зелёный.
- [x] **commit+push:** athena `b22056f` (0 remote) · athena-private `eef1d60` (pushed private-account).
- [x] **Слой 0b (tools):** `tools.manifest` (+`.example`) → клон `~/tools/*` ДО Сознания (run_once_ найдёт бота). tg-бот автоматизирован (public `RichardAtCT/claude-code-telegram` + `poetry install`); `poetry` в Brewfile.

**Остаток до полного DoD (владелец/Ф5):** live Keychain-миграция (`migrate-secrets.sh`, после ротации tg) · истинный `chezmoi execute-template` на dest + e2e от git clone → Ф5.
**DoD:** на чистом таргете личная инстанция поднимается из приватных репо. (Автор+dry ✓; live e2e → Ф5.)

## Фаза 5 — e2e + публикация ✓ (2026-06-16)
**ОПУБЛИКОВАН** public (generic-репо, MIT). Автор/URL — в git-метаданных (контент репо identity-нейтрален).
- [x] **P0.1** gitignore (`athena.config.sh`/`chezmoidata.yaml`).
- [x] **P0.2** sanitize tracked + smoke grep-гейт `[личное]` (доказан RED-инъекцией).
- [x] **P0.3** git identity = канон владельца; история переподписана filter-branch.
- [x] **P0.4** launchd fail-closed (bootout/bootstrap + агрегат-exit) + **истинный `chezmoi apply`** на чистом `$HOME` зелёный (0 нерендеренных токенов). Протокол `05-clean-room-protocol.md`.
- [x] **P0.5** аудит-blob'ы выпилены из истории → repo create + push; clone проверен.
- [x] CI smoke (macos-latest: shellcheck + bootstrap --dry-run + smoke + dry-validate) — зелёный.
- [x] Самообучение вшито в канон; плоскости: дотфайлы=«Сознание», vault=«Мозг».

**Остаток (P1, после публикации):** живой `git clone+./bootstrap.sh` на РЕАЛЬНО чистом Mac/VM (не fake-HOME); launchd-регистрация на чистом таргете. План догона — `~/.claude/handoff/athena-gate-rerun-20260616/IMPLEMENTATION-PLAN.md`.
**DoD:** ✓ опубликовано, clone+smoke зелёный; полный live-bootstrap на чистом Mac → P1.

## Фаза 6 — онбординг-грилл первого запуска (реализовано, 2026-06-17)

Новый юзер на свежей машине проходит полный грилл P1–P5 → идеальный конфиг по методу Карпаты. Спец: `onboarding-grill.md`.

- [x] `references/karpathy-method.md` (gate-полноты, `source:`, лестница зрелости).
- [x] `assets/interview-rubric.md` (банк вопросов P1–P5) + `assets/composition-principles.md` (Карпаты-композиция).
- [x] P3-слоты `{{ }}` в `CLAUDE.template.md` + P1/P2-слоты в `owner.template.md`.
- [x] SessionStart-детектор `chezmoi/dot_claude/hooks/onboarding-detect.sh` + регистрация в `settings.json.tmpl`.
- [x] SKILL.md: Этап A → полный грилл; Этап B → mandatory Карпаты.
- [x] smoke +12 чеков (assets, ≤200, функц-тест хука nudge/silent/marker); dry-validate зелёный.
**DoD:** ✓ smoke OK, assets public-safe (личных значений 0). Push — после P1-live-bootstrap (фича не блокирует гейт).

## Фаза 7 — Local Agent Contract (Hire Agents, local-first) — в работе
Самопроверяемый агентный слой: роли · handoff-граф · post-run · eval-loop · gates. Job завершён не текстом, а контрактом. Спец: `specs/07-local-agent-contract.md`. Источник идей: `docs/MNEMAZINE-AGENTOS-TRANSFER.ru.md` (скелет) ⊕ канон vault (привиты 6 контрактов, сверка 2026-06-23).

- [x] План + сверка (Б) ролей/handoff repo-дока против мастер-дока vault → 6 athena-* → **7** (reviewer ≠ reconciler), привиты job-lifecycle FSM / eval-loop→router / project.yaml / security+emergency / per-class матрица.
- [ ] Шаг 1 — `chezmoi/dot_agents/role-passports/` (7 паспортов, канон-формат).
- [ ] Шаг 2 — `chezmoi/dot_agents/handoff-graph.yaml` (машиночитаемый + forbidden + learning-tail gate).
- [ ] Шаг 3 — `smoke/agent-contract.sh` (passports + handoff integrity).
- [ ] Шаги 4–6 — session-review · postrun-report · report-quality-gate.
- [ ] Шаги 7–8 — job-lifecycle + project.yaml + eval-loop→router + стартовая матрица.
- [ ] Шаг 9 — smoke++ · FEATURES maturity layers. Шаг 10 — dashboard (thin UI) — позже.
**DoD:** agent-contract smoke зелёный · 7 паспортов+handoff проходят integrity · прогон оставляет brief/trace/reflection/most-important · parity-smoke `identical` · 0 хардкода путей.
