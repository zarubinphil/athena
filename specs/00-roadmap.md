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
- [ ] `launchd/*.plist` шаблоны → переносится в Фазу 2 (с курированием chezmoi)
**DoD:** ✓ репо самодостаточно, `./bootstrap.sh --dry-run` проходит, 0 личных данных. (shellcheck — в Brewfile, ставится на bootstrap.)

## Фаза 2 — курирование канона Мозга (chezmoi-source)
Заново собрать лин-канон `~/.claude` по best-practices vault (CLAUDE.md ≤80–120, hot/cold, 4 слоя, deny-безопасность), НЕ дамп текущего 1.2 ГБ. Скиллы: reinstall плагинов из marketplaces + личные в chezmoi.
**DoD:** chezmoi apply на sandbox-юзере даёт рабочий лин `~/.claude`.

## Фаза 3 — аккуратный рефактор реальной структуры
По карте связей (хэндофф `~/.claude/handoff/athena-os.md`). Бэкап → правки в локстеп: vault-константы в `kb-pipeline.js`, проекты в `~/Проекты`, единый интейк, `~/.secrets`, починка флагов (`mnemosyne-health` PATH). Каждый шаг → smoke.
**DoD:** mnemosyne/femida/coffee работают после переезда; 0 битых ссылок.

## Фаза 4 — приватные репо + Keychain + launchd
`vault-znaniya` (приватный), приватный chezmoi-source (личные значения), секреты в Keychain, launchd-агенты.
**DoD:** на чистом таргете личная инстанция поднимается из приватных репо.

## Фаза 5 — e2e + публикация
Прогон на чистом таргете/sandbox от нуля до зелёного smoke. Публикация generic-репо (MIT).
**DoD:** `git clone + ./bootstrap.sh` на чистом Mac = живая система; паритет Claude=Codex зелёный.
