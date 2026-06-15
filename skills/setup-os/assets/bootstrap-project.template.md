---
name: bootstrap-project
description: Создать структуру нового проекта одним вызовом. Триггеры: "новый проект", "bootstrap project", "создай структуру проекта", "scaffold".
---

# bootstrap-project — каркас проекта за один вызов

Спроси (AskUserQuestion, один экран): имя · тип (web/RN/python/lib) · база знаний внутри (да/нет) · git init (да/нет).

Создай дерево:
```
<project>/
  CLAUDE.md            # проектная конституция ≤150 строк: стек, команды build/test, gotchas, "@AGENTS.md"
  .claude/
    settings.json      # deny секретов (копия из ~/.claude/skills/setup-os/assets/settings.template.json)
    rules/             # path-gated правила
    agents/            # проектные субагенты
    skills/  commands/
  specs/               # цели, DoD, ограничения — specs ПЕРВЫМИ
  src/                 # (или code/) код
  evals/               # тесты/трейсы — гейт
  docs/
  .gitignore           # .env, runs/, secrets, references/secrets-map.md
```
Если «база знаний внутри» = да — добавь `knowledge/{raw,wiki,outputs}` + мини-конституцию Карпаты.

Шаги:
1. `mkdir -p` дерева.
2. Запиши CLAUDE.md из шаблона (подставь стек/команды по типу проекта).
3. Скопируй settings.json (deny секретов).
4. `.gitignore` с секретами.
5. Если git — `git init`.
6. Покажи дерево. Предложи `gsd-new-project` для фазового плана.

Проектный CLAUDE.md держать ≤150 строк — специфика в rules/skills. Личное не дублировать (оно глобально).
