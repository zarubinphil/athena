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
0  Разведка    → есть ли уже ~/.claude, vault? первый запуск? preinstall прошёл?
A0 Установка   → прогон слоёв bootstrap.sh + ОПРОС ИНТЕГРАЦИЙ (попапы: GitHub/Firecrawl/...) [нуб-путь]
A  Глобал OS    → ПОЛНЫЙ ГРИЛЛ P1–P5 → ~/.claude/{CLAUDE.md, settings.json, references/, manifests}
B База знаний  → Obsidian vault по Карпаты (raw/ wiki/ outputs/ + конституция + AGENTS.md рой) [ОБЯЗАТ]
C Template+боты→ claude-starter repo + skill bootstrap-project
D Проект       → per-project структура (code/ agents/ specs/ ...) + gsd-new-project
E Автоматизация→ ingest-hook, weekly health-check cron, parity Claude↔Codex
```
Можно начать с любого этапа (спроси с какого), но дефолт — по порядку. A+B — ядро онбординга (B обязателен, на нём P5).
Грилл драйвит `assets/interview-rubric.md` (банк вопросов P1–P5); пишет по `assets/composition-principles.md` (Карпаты). Триггер: ручной `/setup-os` ИЛИ nudge от SessionStart-хука `onboarding-detect.sh` на свежей машине.

---

## Этап 0 — Разведка (молча, до вопросов)
```bash
ls -la ~/.claude/ 2>/dev/null; ls ~/.claude/CLAUDE.md 2>/dev/null
ls "$HOME"/* knlow* "$HOME/Мозг" 2>/dev/null   # vault?
which gh claude gsd 2>/dev/null
```
Реши: чистая установка или дооформление. Не перезаписывай существующее без бэкапа (`cp X X.bak`).

Проверь шаг 0: `which claude chezmoi brew`. Чего-то нет → попап «Сначала запусти `preinstall.sh` в Терминале (нужен пароль Mac)» + стоп (шаг 0 руками — sudo, агент не может).

AskUserQuestion: «С чего начинаем?» → [Полный setup с нуля] [Только база знаний] [Только проектный scaffolder] [Дооформить существующее].
Полный setup → Этап A0 (установка) перед гриллом.

---

## Этап A0 — Установка системы (нуб-путь: движок + опрос интеграций)

> Дирижируешь установкой ТЫ. `bootstrap.sh` — детерминированный движок (идемпотентный, `--only`), ты гонишь его слои по порядку и между ними спрашиваешь попапами. Цель: чистый Mac → рабочая система, юзер только отвечает на вопросы.

**1. Разрешение (снимает E1 — классификатор External Code).**
AskUserQuestion: «Разрешаешь прогнать установочные скрипты Athena?» → [Да, доверяю] [Нет]. «Нет» → стоп.

**2. Прогон слоёв** (каждый — 1 фраза зачем, затем `run`):

| Слой | Команда | Зачем (юзеру) |
|---|---|---|
| 0 | `./bootstrap.sh --only=0` | база (идемпотентно — частью сделал preinstall) |
| 1 | `./bootstrap.sh --only=1` | Сознание: дотфайлы агента |
| 1b | `./bootstrap.sh --only=1b` | плагины → **попап подтверждения untrusted** (снимает E6) |
| 2 | `./bootstrap.sh --only=2` | реестр способностей |
| 3–6 | `--only=3..6` | проекты · знания · секреты/MCP · smoke |

После каждого слоя — стамп в `~/.claude/.athena-onboarding-progress` (резюм с места обрыва).
Если chezmoi спросит overwrite (E7, runtime-дрейф settings.json) — попап «отвечай `overwrite`».

**3. ОПРОС ИНТЕГРАЦИЙ** (ядро нуб-пути — ставить-или-skip, никаких тихих дыр).

Один AskUserQuestion **multiSelect** «Что подключаем? (что не выберешь — пропустим, добавишь позже)». По каждой выбранной — мини-поток. Словарь (вопрос → ставлю → fallback при skip):

| Интеграция | Если «да» | Если skip |
|---|---|---|
| **GitHub** | `gh auth login` (откроет браузер) | проекты работают локально |
| **Firecrawl** | спроси ключ → Keychain/`~/.secrets`/`.env` (**НЕ git**) | веб-каскад падает на WebSearch |
| **Supabase** | MCP-reauth по `mcp-reauth.md` | — |
| **Higgsfield** | MCP-reauth | — |
| **Приватный overlay** | спроси git URL → `ATHENA_PRIVATE_REPO` в `athena.config.sh` → пере-прогон слоя 1 | generic-only (дефолт) |
| **Vault знаний** | → Этап B (Карпаты) | skip-с-логом причины |

**Секреты — правило НИКОГДА:** значение пишем в Keychain / `~/.secrets` (chmod 700) / `.env`. В репо/git — никогда. Только карта в `secrets-map.md`.

**Gate полноты:** каждая интеграция = подключена ИЛИ явный skip-с-причиной (стамп). После A0 → Этап A (грилл P1–P5).

---

## Этап A — Глобальный OS через ПОЛНЫЙ ГРИЛЛ (`~/.claude/`)

Не single-screen — **полный грилл P1–P5** (стиль `/grill-me`). Драйвит банк вопросов `assets/interview-rubric.md`; пишешь по `assets/composition-principles.md` (метод Карпаты, синтез-на-записи). Цель: из ответов **идеально** собрать конфиг, не дамп сырья.

**Поток каждой фазы:** объясни 1 фразой зачем → AskUserQuestion (батч по домену из rubric) → **синтезируй** ответ в атомарный конфиг → запиши в целевой файл → покажи → чекпойнт-стамп → «дальше?».

| Фаза | Собирает | Пишет (target) | Tier |
|---|---|---|---|
| **P1 Идентичность** | роль/занятость, язык, локация+ограничения, домены экспертизы | `references/owner.md` | hot |
| **P2 Проекты+стек** | проекты (имя/статус/критичность), стек, что клонировать/ставить | `owner.md`, `projects.manifest`, `tools.manifest` | hot |
| **P3 Стиль+правила** | model-стенс, коммуникация/caveman, структура ответа, НИКОГДА/ВСЕГДА, gate пакетов | `CLAUDE.md` (слоты `{{ }}`) | hot |
| **P4 Операц-преференсы** | security-постура, design/UX-вкус+анти-паттерны, deploy, swarm, web-каскад | `references/{security,design,deploy,agents,scrapegraph}.md` | cold |
| **P5 Инфра** | vault (Карпаты — Этап B), session-lifecycle, self-learning, **secrets-МАП** | `CLAUDE.md`+`references/`+`secrets-map.md`+vault | cold |

**Запись (РАЗДЕЛЕНИЕ — личное/секреты вне CLAUDE.md, только указатели):**

1. **`~/.claude/CLAUDE.md`** — копия `assets/CLAUDE.template.md` (проверенный скелет) + заполнить hot-слоты `{{ }}` из P3 (язык, model-стенс, доп НИКОГДА/ВСЕГДА). Глубину P4/P5 НЕ инлайнить — указатель `@references/*`. ≤200 строк.
2. **`~/.claude/references/owner.md`** (`assets/owner.template.md`) — P1/P2. В CLAUDE.md строка `@references/owner.md`.
3. **`~/.claude/references/secrets-map.md`** (`assets/secrets-map.template.md`) — P5 МАП: ТОЛЬКО где лежит, не значения. Файл в `.gitignore`. Чеклист на ручное заполнение Keychain/.env.
4. **`~/.claude/settings.json`** (`assets/settings.template.json`) — `permissions.deny` секретов + SessionStart-хук `onboarding-detect.sh`. Smoke: Read .env блокнут.
5. **`~/.claude/references/`** — P4 cold-файлы (deploy/security/design/agents/scrapegraph).
6. **`~/.claude/rules/`** + **`agents/`** — если ecc/ уже есть, не трогать.

**Gate полноты (Карпаты):** каждый домен P1–P5 — заполнен ИЛИ явно пропущен-с-причиной (стамп в `~/.claude/.athena-onboarding-progress`). Нет тихих дыр. **Secrets:** только МАП, значений НЕ спрашивать/НЕ писать в репо (правило НИКОГДА).

**Чекпойнт/резюм:** «полный грилл» = полное покрытие, НЕ один присест. После каждой фазы — стамп; можно паузить, резюмить с последней фазы (это и есть fast-path). По завершении → маркер `~/.claude/.athena-onboarded` (глушит детектор-хук). «Позже» → `~/.claude/.athena-onboarding-snooze`.

**ЖЁСТКОЕ правило модели** (вшито в CLAUDE.template): перед каждой задачей выверять оптимальную модель по качеству-на-токен. Убедись что блок в записанном CLAUDE.md.

Покажи дерево. Подтверди → переходи к Этапу B (Карпаты-vault — **обязателен**, P5 на нём держится).

---

## Этап B — База знаний по Карпаты (LLM-wiki) — ОБЯЗАТЕЛЬНО

> Не опциональный этап: P5-инфра грилла держится на нём. Метод Карпаты — mandatory (детали `references/karpathy-method.md`). Пропустить можно ТОЛЬКО явным «нет vault» с логом причины (gate полноты).

Спроси: путь к vault (дефолт `~/Мозг` или `~/Knowledge`). Существует Obsidian vault — подключаем, нет — создаём.

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

- `assets/interview-rubric.md` — банк вопросов грилла P1–P5 (драйвит Этап A)
- `assets/composition-principles.md` — как идеально писать конфиг (Карпаты, бюджет, hot/cold)
- `assets/CLAUDE.template.md` — лин глобальный скелет + P3-слоты `{{ }}`
- `assets/owner.template.md` — личные данные (P1/P2-слоты)
- `assets/vault-CLAUDE.template.md` — конституция вики Карпаты
- `assets/AGENTS.template.md` — реестр вики-роя
- `assets/secrets-map.template.md` — карта секретов (gitignored, map-only)
- `assets/settings.template.json` — deny секретов
- `assets/bootstrap-project.template.md` — тело bootstrap-скилла
- `references/karpathy-method.md` — метод подробно (из vault-нот)
- `chezmoi/dot_claude/hooks/onboarding-detect.sh` — SessionStart-детектор первого запуска (nudge)
