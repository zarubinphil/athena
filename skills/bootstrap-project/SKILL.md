---
name: bootstrap-project
description: Создать структуру нового проекта одним вызовом из эталона claude-starter. Триггеры: "новый проект", "bootstrap project", "создай структуру проекта", "scaffold проекта", "начать проект".
---

# bootstrap-project — каркас проекта за один вызов

Эталон: `~/claude-starter/`. Не копировать вслепую — адаптировать под тип проекта.

## Шаги
1. Спроси (AskUserQuestion, один экран): имя · тип (web/RN/python/lib) · база знаний внутри (да/нет) · git init (да/нет).
2. Целевая папка: спроси путь (дефолт `~/Desktop/<имя>` или текущая).
3. Скопируй эталон:
   ```bash
   rsync -a ~/claude-starter/ "<target>/"
   ```
4. Заполни `CLAUDE.md` — подставь `{{ПРОЕКТ}}`, стек, команды build/test по типу:
   - web → vite/next, `npm run dev/build/test`
   - RN → expo/react-native, `npx expo start`
   - python → uv/poetry, `pytest`
   - lib → tsup/build, `vitest`
5. Если «база знаний внутри» = да → добавь `knowledge/{00 Входящие,01 Знания}` + мини-конституцию Карпаты (синтез на записи, index.md).
6. Если git → `git init && git add -A && git commit -m "chore: bootstrap from claude-starter"`.
7. Smoke-test: `Read .env` должен блокнуться (deny из settings.json).
8. Покажи дерево. Предложи `gsd-new-project` для фазового плана.

## Правила
- Проектный CLAUDE.md ≤150 строк — специфика в rules/skills.
- Личное НЕ дублировать (наследуется из ~/.claude).
- specs первыми. Секреты только в .env (в .gitignore).
- Структура «один раз»: дальше каждый проект из этого эталона, setup не повторять.

## После создания
Предложить зеркалить новый проектный skill/agent на Codex+VPS (parity), если он переиспользуемый.
