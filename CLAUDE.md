# athena — проектная конституция

Athena — переносимая агентная ОС: разворот всей системы владельца на новом Mac одной командой. Этот репо — generic/public каркас (без личных данных).

## Карта
- `preinstall.sh` — Шаг 0 руками в Терминале (brew+CLI+claude, нужен пароль Mac; `curl|bash`). Единственное вне Claude. Дальше: `claude` → `/setup-os` (дирижёр установки + опрос интеграций попапами).
- `bootstrap.sh` — оркестратор слоёв 0–6 (+0b tools, idempotent, `$HOME`, читает `athena.config.sh`). Слой 1 = merged-source: generic `chezmoi/` ⊕ приватный overlay (`ATHENA_PRIVATE_REPO`, Ф4) → один `chezmoi apply`.
- `projects.manifest` / `tools.manifest` (+`.example`) — клон проектов (`~/Проекты`) и инструментов (`~/tools`, Слой 0b ДО Сознания). Реальные — в приватном overlay.
- `rules/structure.md` — **конституция раскладки** (источник истины организации ФС). Менять осознанно.
- `chezmoi/` — шаблоны дотфайлов Сознания (улучшенный канон из best-practices vault).
- `skills/{setup-os,bootstrap-project,organize,athena-update}` — рождение ОС, каркас проекта, авто-раскладка, безопасное обновление живой системы (анализ→план→согласование→действие, бэкап+откат, `.athena-version`-стамп).
- `claude-starter/` — эталон проекта, который Athena ставит конечному юзеру.
- `projects.manifest` (+`.example`) · `secrets-checklist.md` · `mcp-reauth.md` · `launchd/` · `smoke/`.
- `specs/` — фазовый план (читать первым). `docs/decisions/` — ADR.

## Команды
- Линт: `shellcheck bootstrap.sh smoke/*.sh`
- Сухой прогон: `./bootstrap.sh --dry-run`
- Slice: `./bootstrap.sh --only=<0|0b|1..6>` (`0`=база, `0b`=инструменты ~/tools — раздельно)
- Smoke: `smoke/smoke.sh`
- Dry-validate шаблонов (без chezmoi): `smoke/dry-validate.sh` (merge → рендер → plist/json/bash-n + лов неизвестных `{{ }}`)

## Конвенции
- Всё идемпотентно, на `$HOME`, без хардкода `/Users/...`. Личное — только в gitignored `athena.config.sh` / Keychain.
- Деструктив и внешние действия — за подтверждением; в публичном репо личных данных нет.
- specs первыми. Изменил раскладку → синхронь `rules/structure.md` + `organize` + bootstrap-project в локстеп.
- Проектный CLAUDE.md ≤150 строк; детали — в `rules/`, `skills/`, `specs/`.

## Не делать
- Не зеркалить секреты/сессии/кеши в git (правило parity).
- Не трогать боевой `~/.claude` из этого репо без бэкапа — Фаза 1 clean-room.
