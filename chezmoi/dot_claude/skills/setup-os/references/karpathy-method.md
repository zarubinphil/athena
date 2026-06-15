# Метод Карпаты — LLM-wiki (подробно)

> Источник: vault-ноты `02 Знания/Build Your Second Brain`, `08 AI и Инструменты/Claude Code + Obsidian`, `04 Образование/AI Knowledge Base Architecture`.

## Ядро
- **3 папки + конституция:** `raw/` (immutable) · `wiki/` (LLM владеет) · `outputs/`. Плюс `CLAUDE.md` = как LLM думает.
- **Против RAG:** RAG «переоткрывает знание каждый вопрос с нуля». Тут — синтез на записи, знание скомпилировано в персистентную вики.
- **Без vector DB:** `index.md` (страница → 1 строка summary). LLM читает индекс → находит страницы. Дёшево.

## Ingest-workflow
Источник в `raw/` → промпт «ingest» → LLM: парсит сущности/концепты → обновляет несколько wiki-страниц → создаёт новые entity-страницы → ставит 12+ кросс-ссылок `[[]]` → обновляет `index.md` → дописывает `log.md`. Один ingest рябью идёт по всем страницам.

## Hot/Cold память
- **Hot** = CLAUDE.md/конституция: правила, conventions — каждую сессию.
- **Cold** = durable-знание в нотах: on-demand через индекс.

## Obsidian-интеграция
- Vault = рабочая папка Claude: `cd ~/Vault && claude` → нативный доступ ко всем нотам. Корневой `CLAUDE.md` авто-читается.
- Obsidian = human-слой (graph view, линки, редактор). Markdown = LLM-native. Local-first = суверенитет данных.
- Референс: `AgriciDaniel/claude-obsidian` (MIT).

## Health-check (weekly)
LLM ищет: противоречия между страницами, страницы-сироты (без ссылок), недостающие концепт-страницы. → отчёт в `outputs/`.
