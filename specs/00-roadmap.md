# Athena OS — дорожная карта

Регламент: grill-me → план → утверждение → реализация. Грилл и утверждение пройдены 2026-06-15.

## Фаза 1 — чистый каркас (текущая)
Generic-репо под открытый GitHub, clean-room (боевой `~/.claude` НЕ трогаем).
- [x] Скаффолд из claude-starter + структура athena-os
- [x] `rules/structure.md` — конституция раскладки
- [x] `bootstrap.sh` — оркестратор слоёв 0–6
- [x] `Brewfile`, `README.md`, `CLAUDE.md`, `LICENSE`
- [x] `projects.manifest.example`, `secrets-checklist.md`, `mcp-reauth.md`, `athena.config.example.sh`
- [x] `skills/organize/SKILL.md` (новый), копии `setup-os` + `bootstrap-project`
- [x] `smoke/smoke.sh` — зелёный
- [x] git init + commit (48 файлов)
- [x] `launchd/*.plist` шаблоны → сделано в Фазе 2 (health + session-reaper.example)
**DoD:** ✓ репо самодостаточно, `./bootstrap.sh --dry-run` проходит, 0 личных данных. (shellcheck — в Brewfile, ставится на bootstrap.)

## Фаза 2 — курирование канона Мозга (chezmoi-source) ✓
Generic chezmoi-source собран (чистая пересборка, НЕ дамп 1.2 ГБ):
- [x] `dot_claude`: `CLAUDE.md` (лин-роутер) · `AGENTS.md.tmpl` (VPS-IP вычищен, пути templated) · `settings.json.tmpl` (deny-щит 20 паттернов) · `hooks/security-guard.sh` (детерминированный, behavior-tested) · `rules/` (structure + ECC 21 язык) · 30 generic ECC-агентов · `scripts/health-check.sh`
- [x] `dot_codex`: symlink-паритет → claude-канон
- [x] `dot_agents`: registry SSOT (13 скриптов HOME-генерик + REGISTRY/CAPABILITY-PLANNING/SHARED docs)
- [x] плагины: `plugins.manifest` + bootstrap Слой 1b (marketplace add + install)
- [x] launchd: `health.plist`+скрипт (PATH-фикс 127); `session-reaper.plist.example` (скрипт → Ф4)
- [x] smoke++ (secret-токен guard + канон) ЗЕЛЁНЫЙ; шаблоны render-validated (homeDir → валидный JSON)
- [x] 0 hard личных данных в source; soft (Мнемозина/owner в structure.md + setup-os шаблонах) → publication-sanitize Ф5
**DoD:** source render-validated + smoke зелёный. Живой `chezmoi apply` — ТОЛЬКО на чистом таргете (на боевом юзере перетёр бы рабочий `~/.claude` — clean-room), переносится в Ф5 e2e.

## Фаза 3 — аккуратный рефактор реальной структуры
По карте связей (хэндофф `~/.claude/handoff/athena-os.md`). Бэкап → правки в локстеп: vault-константы в `kb-pipeline.js`, проекты в `~/Проекты`, единый интейк, `~/.secrets`, починка флагов (`mnemosyne-health` PATH). Каждый шаг → smoke.
**DoD:** mnemosyne/femida/coffee работают после переезда; 0 битых ссылок.

## Фаза 4 — приватные репо + Keychain + launchd
`vault-znaniya` (приватный), приватный chezmoi-source (личные значения), секреты в Keychain, launchd-агенты.
**DoD:** на чистом таргете личная инстанция поднимается из приватных репо.

## Фаза 5 — e2e + публикация
Прогон на чистом таргете/sandbox от нуля до зелёного smoke. Публикация generic-репо (MIT).
**DoD:** `git clone + ./bootstrap.sh` на чистом Mac = живая система; паритет Claude=Codex зелёный.
