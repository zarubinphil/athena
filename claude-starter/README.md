# claude-starter

Эталон структуры проекта Claude Code. Не клонировать вручную — звать `/bootstrap-project`.

```
CLAUDE.md          # проектная конституция ≤150 строк (шаблон, подставить {{...}})
.claude/           # settings.json (deny секретов), rules/ agents/ skills/ commands/
specs/             # цели, DoD, ограничения — ПЕРВЫМИ
src/               # код
evals/             # тесты/трейсы — гейт
docs/
.gitignore         # секреты, артефакты
```

Новый проект: `/bootstrap-project` → заполнит {{...}} → `gsd-new-project` для фазового плана.
