# launchd — агенты автоматики Athena OS

Слой 5 `bootstrap.sh` берёт каждый `*.plist` здесь, подставляет `$HOME` (sed) →
`~/Library/LaunchAgents/`, `launchctl load`. Файлы `*.plist.example` **пропускаются**.

| Файл | Что | Статус |
|---|---|---|
| `com.athena.health.plist` | daily health-check Мозга (бинари+канон) → `~/.claude/health.log` | активен, generic |
| `com.athena.session-reaper.plist.example` | жнец зависших сессий (1800s) | шаблон — скрипт в Фазе 4 |

Конвенции:
- Пути только через `$HOME` (Слой 5 sed-ит). Без хардкода `/Users/...`.
- `EnvironmentVariables.PATH` задавать явно — launchd иначе не видит `claude`/`chezmoi` (баг status=127).
- Личные агенты (интейк, briefing, боты) — приватный слой/проектные install.sh, НЕ сюда.
