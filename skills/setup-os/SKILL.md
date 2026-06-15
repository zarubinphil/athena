---
name: setup-os
description: Интерактивный пошаговый онбординг Claude Code OS с нуля. Запускать когда человек впервые ставит Claude Code, хочет идеальную структуру папок, глобальный CLAUDE.md, базу знаний по методу Карпаты (LLM-wiki в Obsidian), template-repo и per-project scaffolder. Триггеры: "настрой claude", "setup os", "первый запуск", "создай структуру с нуля", "идеальная структура папок", "база знаний карпаты".
---

# setup-os — рождение Claude Code OS за один разговор

> Основан на vault-ресёрче: Claude Code OS, Karpathy LLM-wiki, GSD, token-economy.

## Принцип
Веди человека ПО ЭТАПАМ. Каждый этап: (1) объясни одной фразой зачем, (2) спроси нужное через AskUserQuestion, (3) **создай файлы сам** (не предлагай — делай), (4) покажи что создано, (5) «дальше?». Строй один раз — потом не повторять.

Всё на caveman+humanizer. Структура каждого шага: что сделано · что нужно · следующий шаг.

## Карта этапов
```
0 Разведка     → есть ли уже ~/.claude, vault? первый запуск?
A Глобал OS    → ~/.claude/{CLAUDE.md, settings.json, references/, rules/, agents/}
B База знаний  → Obsidian vault по Карпаты (raw/ wiki/ outputs/ + конституция + AGENTS.md рой)
C Template+боты→ claude-starter repo + skill bootstrap-project
D Проект       → per-project структура (code/ agents/ specs/ ...) + gsd-new-project
E Автоматизация→ ingest-hook, weekly health-check cron, parity Claude↔Codex
```
Можно начать с любого этапа (спроси с какого), но дефолт — по порядку.

---

## Этап 0 — Разведка (молча, до вопросов)
```bash
ls -la ~/.claude/ 2>/dev/null; ls ~/.claude/CLAUDE.md 2>/dev/null
ls "$HOME"/* knlow* "$HOME/Полезные знания" 2>/dev/null   # vault?
which gh claude gsd 2>/dev/null
```
Реши: чистая установка или дооформление. Не перезаписывай существующее без бэкапа (`cp X X.bak`).

AskUserQuestion: «С чего начинаем?» → [Полный setup с нуля] [Только база знаний] [Только проектный scaffolder] [Дооформить существующее].

---

## Этап A — Глобальный OS (`~/.claude/`)
Спроси (AskUserQuestion, один экран): имя · язык · 3-5 текущих проектов · стек · сервер для деплоя (да/нет).

Создай (РАЗДЕЛЕНИЕ: личное и секреты — вне главного CLAUDE.md, только указатели):
1. **`~/.claude/CLAUDE.md`** — ЛИН-конституция ≤200 строк (`assets/CLAUDE.template.md`). Только hot-факты + указатели. НЕ инлайнить личное/секреты.
2. **`~/.claude/references/owner.md`** — все личные данные (`assets/owner.template.md`). В CLAUDE.md строка `@references/owner.md`.
3. **`~/.claude/references/secrets-map.md`** — карта секретов (`assets/secrets-map.template.md`): ТОЛЬКО где лежит, не значения. В CLAUDE.md указатель для быстрого перехода. Файл в `.gitignore`.
4. **`~/.claude/settings.json`** — `permissions.deny` на `**/.env`, `**/*secret*`, `**/.ssh/**`, secrets-map.md (`assets/settings.template.json`). После — smoke-test: Read .env должен блокнуть.
5. **`~/.claude/references/`** — deploy.md, scrapegraph.md.
6. **`~/.claude/rules/`** + **`agents/`** — если ecc/ уже есть, не трогать.

**ЖЁСТКОЕ правило модели** (вшито в CLAUDE.template): перед каждой задачей выверять оптимальную модель; даже в дешёвом tier — если Opus 4.8 (или иная) лучше качество-на-токен для задачи, использовать ЕЁ. Убедись что этот блок в записанном CLAUDE.md.

Покажи дерево. Подтверди.

---

## Этап B — База знаний по Карпаты (LLM-wiki в Obsidian)
Спроси: путь к vault (дефолт `~/Полезные знания` или `~/Knowledge`). Существует Obsidian vault — подключаем, нет — создаём.

Структура (метод Карпаты, синтез-на-записи, без vector DB):
```
<vault>/
  raw/                 # источники, immutable, НЕ редактировать
  wiki/                # LLM владеет, синтезирует, перезаписывает (= тематические разделы)
  outputs/             # ответы/отчёты
  _МАСТЕР-ИНДЕКС.md    # index: страница → 1 строка summary. Читать ПЕРВЫМ
  _ROUTING.md          # триггер → раздел, совпадение ≥70%
  Лог обработки.md     # append-only журнал ingest
  CLAUDE.md            # конституция вики (шаблон assets/vault-CLAUDE.template.md)
  AGENTS.md            # реестр вики-роя (шаблон assets/AGENTS.template.md)
```
В корне vault `CLAUDE.md` импортит `@AGENTS.md`. AGENTS.md = таблица роя:

| Агент | Роль | Модель | Когда |
|---|---|---|---|
| kb-ingest | raw → wiki-страницы + кросс-ссылки [[]] + индекс + лог | Haiku/Sonnet | новый файл в raw/ |
| kb-router | триггер → раздел по _ROUTING.md | Haiku | классификация |
| kb-synth | свод/переписать концепт-страницу | Opus | спорный синтез |
| kb-health | противоречия/сироты/пробелы | Sonnet | weekly |

Если vault уже = Мнемозина — НЕ дублировать, формализовать существующее (index/routing/рой уже есть).

Объясни человеку workflow: кинул в `raw/` → `/kb-ingest` → знание рябью идёт по страницам. RAG не используем — синтез на записи.

---

## Этап C — Template-repo + bootstrap-бот (строй один раз)
1. Создай **`~/claude-starter/`** — эталон `.claude/` (CLAUDE.md проектный + settings.json + rules/ + agents/ + .mcp.json пустой). `gh repo create claude-starter --template` опционально.
2. Создай skill **`bootstrap-project`** (`~/.claude/skills/bootstrap-project/SKILL.md`) — один вызов строит дерево проекта + копирует конфиги. Шаблон assets/bootstrap-project.template.md.

Дальше новый проект = `gh repo --template claude-starter` → `/bootstrap-project` → `gsd-new-project`.

---

## Этап D — Создание конкретного проекта
Спроси: имя · тип (web/RN/python/lib) · нужна ли база знаний внутри.

Создай per-project:
```
<project>/
  CLAUDE.md            # проектная конституция (стек, команды, gotchas, "@AGENTS.md")
  .claude/{settings.json, rules/, agents/, skills/, commands/}
  specs/               # цели, DoD, ограничения (specs ПЕРВЫМИ)
  src/  (или code/)    # код
  agents/              # проектные субагенты
  evals/               # тесты/трейсы (гейт)
  docs/
  .gitignore           # .env, runs/, secrets
```
Затем `gsd-new-project` для фазового плана. Проектный CLAUDE.md ≤150 строк, специфика → rules/skills.

---

## Этап E — Автоматизация (освобождает время)
- **Ingest-hook:** новый файл в `<vault>/raw/` → авто-`kb-ingest`. (settings.json hook или watcher.)
- **Weekly health-check:** cron-агент Вс — ищет противоречия/сироты в vault, шлёт отчёт (`/schedule` или CronCreate).
- **Parity Claude↔Codex:** `bash ~/.agents/registry/scripts/propagate_skills.sh` — зеркалить новый skill на оба харнесса + VPS.
- Предложи каждое, ставь по согласию.

---

## Финал
Покажи итоговое дерево (`~/.claude/` + vault + claude-starter). Чек-лист:
- [ ] CLAUDE.md ≤200 стр, секреты в deny
- [ ] vault: raw/wiki/outputs + index + routing + конституция + AGENTS рой
- [ ] claude-starter + bootstrap-project работают
- [ ] автоматизация (ingest/health/parity) поставлена

Предложи что улучшить дальше. Залогируй setup в vault `Лог обработки.md`.

## Файлы-шаблоны (создать рядом со SKILL.md)
- `assets/CLAUDE.template.md` — лин глобальный (= наш черновик CLAUDE.md.ЧЕРНОВИК)
- `assets/vault-CLAUDE.template.md` — конституция вики Карпаты
- `assets/AGENTS.template.md` — реестр вики-роя
- `assets/settings.template.json` — deny секретов
- `assets/bootstrap-project.template.md` — тело bootstrap-скилла
- `references/karpathy-method.md` — метод подробно (из vault-нот)
