# Перенос идей Mnemazine в локальную AthenaOS

Athena в этом репозитории - не dashboard-first продукт и не VPS-панель.
Это переносимая локальная агентная ОС: одна команда разворачивает на Mac
инструменты, правила, проекты, knowledge vault, registry, runtime helpers и checks.

Значит идеи Mnemazine надо сначала переносить в локальную структуру Athena:
`bootstrap.sh`, `chezmoi`, `~/.claude`, `~/.codex`, `~/.agents`, `~/Мозг`,
skills, workflows, smoke/release gates. Dashboard и VPS-контур идут позже,
когда локальный контракт уже стабилен.

Источник идей: Mnemazine run `kb-20260622-full-inbox`, visual knowledge report
от 2026-06-23, протокол Мнемозина, agent role passports, handoff graph и gates.

## Проверка охвата

Перед этим выводом проверен весь прямой корпус Agentic OS знаний:

- 285 прямых совпадений по `Agent OS`, `AgenticOS`, `AthenaOS`, handoff, gates,
  provider adapter, cockpit, eval loop и role passports;
- 32 старых AthenaOS-ноты в vault;
- 10 системных контрактов и логов;
- 7 runtime-паспортов Mnemazine agents;
- 10 Mnemazine reports;
- 133 свежие AI/agent notes;
- широкий контрольный хвост 1104 совпадения использован только для отсечения шума
  вроде одиночных упоминаний `Claude Code`/`Codex`.

## Что важно

Mnemazine показал не "ещё один пайплайн", а рабочую форму agent.os:

```text
inbox -> census -> extraction -> understanding -> research -> verification
  -> atomization -> vault -> reconcile -> Graphify -> brief -> visual report
```

Для AthenaOS это значит: job не завершён, пока есть только текстовый ответ агента.
Job завершён, когда есть учёт входов, артефакты, проверка, роль исполнителя,
краткий отчёт, durable knowledge и следующие действия.

## Что конкретно меняется в структуре AthenaOS локально

### Было

```text
bootstrap.sh
  -> Base tools
  -> Consciousness (~/.claude ~/.codex ~/.agents)
  -> Registry
  -> Work projects
  -> Knowledge vault
  -> Runtime helpers
  -> Smoke checks
```

Это уже правильный local-first skeleton. Но после уроков Mnemazine ему не хватает
производственного агентного контура внутри локальных слоёв:

- в `Consciousness` есть правила, но нет обязательных role passports для runtime agents;
- в `Registry` есть routing, но нет деления capabilities на дивизионы с owner/test/gate;
- в `Knowledge` есть vault, но нет единого post-run report contract для каждой сессии;
- в `Runtime helpers` есть launchd/hooks, но нет локального session/job ledger как first-class слой;
- в `Smoke checks` есть структура/security/parity, но нет contract smoke для handoff graph,
  passports, report quality и eval records.

### Станет

```text
Layer 1 · Consciousness
  -> role passports
  -> directed handoff graph
  -> Claude/Codex parity contracts

Layer 2 · Registry
  -> capability divisions
  -> owner/test/gate per capability
  -> usage/eval feedback

Layer 4 · Knowledge
  -> durable notes only
  -> post-run knowledge reports
  -> graph refresh + action brief

Layer 5 · Runtime
  -> local session/job ledger
  -> rescue handoff pack
  -> local-first extraction/cache/quarantine

Layer 6 · Checks
  -> passport smoke
  -> handoff graph smoke
  -> report quality gate
  -> eval/release gate
```

### Почему это лучше

1. **Локальная ОС становится самопроверяемой.** Сейчас smoke проверяет установку.
   Новый слой проверяет поведение агентного workflow: роли, handoffs, отчёты,
   eval records.
2. **`CLAUDE.md`/`AGENTS.md` остаются короткими.** Тяжёлые инструкции уходят в skills,
   passports и workflows. Startup context не пухнет.
3. **Claude и Codex получают один контракт.** Не "скопировали текст правил", а smoke
   доказывает: оба видят одинаковые роли, gates и report contract.
4. **Knowledge vault не превращается в свалку.** Raw OCR, screenshots, logs и tool output
   остаются в cache/quarantine; в `~/Мозг` попадает только синтез.
5. **Каждая локальная сессия оставляет полезный хвост.** Вместо "чат закончился" остаются
   `brief_md`, `agent_trace`, `self_reflection`, top actions и при необходимости vault note.
6. **Capability registry становится управляемым.** Навыки группируются по дивизионам:
   research/design/legal/ops/release/growth/knowledge/security. У каждого есть owner,
   test, trust/risk и usage signal.
7. **Rescue между Claude и Codex становится безопасным.** Второй проход получает короткий
   handoff pack без secrets, cache, sessions и raw uploads.
8. **Graphify работает до dashboard.** Сначала локальная карта repo/vault/skills/agents,
   потом UI поверх неё.
9. **Release gate смотрит на агентную зрелость.** Проверка валит не только shell syntax,
   но и потерю паспортов, broken handoff graph, грязный report, отсутствие action brief.
10. **Dashboard потом станет тонкой оболочкой.** Он будет нажимать уже проверенные local
    workflows, а не изобретать agent.os заново в веб-интерфейсе.

## Лучшие переносимые паттерны

### 1. Role passports

В Mnemazine каждый runtime-agent имеет паспорт: роль, обязанности, инструменты,
границу провала и одинаковый контракт для Claude Code и Codex.

Для AthenaOS нужны паспорта минимум для:

- `athena-router` - выбирает проект, workflow, риск, исполнителя и reviewer;
- `athena-guard` - считает входы, секреты, approvals, риск и completeness;
- `athena-runner` - запускает provider adapter: Claude, Codex, позже другие;
- `athena-reviewer` - проверяет результат по eval spec и release gate;
- `athena-librarian` - пишет outbox, vault note, graph links и indexes;
- `athena-steward` - weekly improvement loop по eval records и failures.

### 2. Directed handoff graph

Нельзя считать рой production-системой без разрешённых переходов.

AthenaOS graph:

```text
intake -> guard -> router -> runner -> reviewer -> librarian -> visual report
                              \-> rescue runner -> reviewer
```

Forbidden transitions:

- `runner -> deliver` без reviewer для medium/high risk;
- `router -> external action` без approval;
- `runner -> vault` напрямую без librarian;
- `rescue runner -> rescue runner` без лимита попыток;
- любой agent -> secret/auth/session/cache path.

### 3. Visual post-run knowledge report

Mnemazine сделал отчёт visual-first: карта, кластеры, ноты, атомы, дубли,
top actions. AthenaOS job result должен иметь такой же слой.

Минимальный набор артефактов:

- `result.md` - короткий ответ исполнителя;
- `report.md` - человекочитаемый разбор прохода;
- `report.html` - visual-first карта для review;
- `knowledge-report.json` - machine-readable summary;
- `eval.json` - проверки, reviewer verdict, risk, next gate;
- `top-actions.json` - следующие действия с owner/risk/order.

### 4. Durable knowledge вместо raw dump

Raw uploads, OCR, logs и tool output не должны попадать в финальный vault/report.
Mnemazine держит сырьё в cache/quarantine, а в vault пускает только синтез.

Для AthenaOS:

- raw входы живут в job workspace/cache;
- outbox хранит очищенные артефакты;
- vault получает только atomized knowledge;
- report quality gate валит `IMG_`, `temp_image`, raw OCR, local paths, secrets.

### 5. Completion gates

Mnemazine release gate проверяет синтаксис, demo smoke, quality, report quality,
search eval и metadata parity.

AthenaOS release gate должен проверять:

- syntax/tests panel;
- synthetic validation;
- secret scanner;
- role passport schema;
- directed handoff graph;
- reviewer gate for medium/high risk;
- report quality;
- Graphify freshness;
- Claude/Codex parity of workflow contracts.

### 6. Capability divisions

Новые Mnemazine-ноты говорят: skills лучше промптов, но ставить всё подряд нельзя.
AthenaOS registry надо видеть как дивизионы, а не как список инструментов:

- `research`;
- `design`;
- `legal`;
- `ops`;
- `release`;
- `growth`;
- `knowledge`;
- `security`.

Каждый дивизион имеет skills, agents, tools, gates, evals и owner.

### 7. Engine-agnostic runner

Mnemazine закрепил правило: dashboard не должен знать `claude -p` напрямую.
Нужен один `run_job` contract:

```json
{
  "job_id": "...",
  "provider": "claude|codex",
  "workspace": "...",
  "prompt": "...",
  "constraints": [],
  "expected_artifacts": [],
  "eval_spec": {}
}
```

Provider может меняться, артефакты и eval остаются одинаковыми.

### 8. Rescue pass

Codex как второй проход для stuck Claude Code полезен только как controlled rescue:

- вход - короткий handoff JSON;
- exclude secrets/cache/session/raw uploads;
- есть failing command или explicit stuck reason;
- максимум одна rescue-попытка до human review;
- итог читает reviewer.

### 9. Graphify as runtime map

Graphify нужен не только для vault. AthenaOS должна иметь scoped graph:

- public repo architecture;
- `athena-panel`;
- agents/passports;
- workflows/gates;
- project contracts;
- vault Athena atoms.

Граф строится с exclude-list для `.env`, auth, sessions, caches, raw uploads.

### 10. Operator cockpit

Свежие Mnemazine-ноты про Obsidian terminal и command center дают форму:
панель AthenaOS - не чат и не витрина, а набор проверенных кнопок-workflows:

- inbox triage;
- repo audit;
- contract smoke;
- release check;
- weekly steward;
- graph refresh;
- vault cleanup;
- VPS health.

## Первый порядок внедрения: local-first

1. Добавить локальный `agents/role-passports/` в public skeleton.
2. Добавить локальный `agents/handoff-graph.yaml`.
3. Добавить `smoke/agent-contract.sh`: проверка passports + handoff graph.
4. Добавить `skills/agent-session-review` или workflow для локального session tail.
5. Добавить `scripts/athena-postrun-report.*`: Markdown/HTML/JSON отчёт после важного run.
6. Добавить `scripts/athena-report-quality-gate.*`: no raw OCR, no local filenames, no secrets.
7. Расширить `smoke/smoke.sh`: agent contract + report quality synthetic.
8. Расширить `docs/FEATURES.ru.md`: local agent.os maturity layers.
9. Расширить `specs/00-roadmap.md`: этап F7 Local Agent Contract.
10. Только после этого проектировать dashboard как thin UI поверх local workflows.

## Ожидаемый эффект

- меньше дрейфа ролей;
- меньше "агент сказал done, но система не знает что случилось";
- безопаснее VPS runtime;
- дешевле review;
- лучше перенос между Claude и Codex;
- AthenaOS начинает учиться из job history, а не только хранить логи.
