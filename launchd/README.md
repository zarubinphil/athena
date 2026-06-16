# launchd — агенты автоматики Athena

Слой 5 `bootstrap.sh` берёт каждый `*.plist` здесь, подставляет `$HOME` (sed) →
`~/Library/LaunchAgents/`, `launchctl load`. Файлы `*.plist.example` **пропускаются**.

| Файл | Что | Статус |
|---|---|---|
| `com.athena.health.plist` | daily health-check Сознания (бинари+канон) → `~/.claude/health.log` | активен, generic |
| `com.athena.session-reaper.plist.example` | жнец зависших сессий (1800s) | шаблон opt-in — **скрипт уже generic** |

Жнец готов к работе: `chezmoi/dot_claude/scripts/session-reaper.sh` едет с Сознанием
(generic, чистый `$HOME`, 0 секрета). Public-юзер активирует переименованием
`com.athena.session-reaper.plist.example` → `.plist`. У владельца активный плист с
лейблом `com.fil.session-reaper` живёт в приватном слое (athena-private/launchd/).

Конвенции:
- Пути только через `$HOME` (Слой 5 sed-ит). Без хардкода `/Users/...`.
- `EnvironmentVariables.PATH` задавать явно — launchd иначе не видит `claude`/`chezmoi`/`npm`/`node` (баг status=127).
- Личные агенты (интейк, briefing, боты) — приватный слой/проектные install.sh, НЕ сюда.
