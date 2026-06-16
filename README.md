# Athena

Переносимая агентная ОС. Чистый Mac → **одна команда** → вся система: от каскада `CLAUDE.md` до боевого рантайма.

```bash
git clone <repo> ~/Проекты/athena && cd ~/Проекты/athena
cp athena.config.example.sh athena.config.sh   # заполни свои репо/значения
./bootstrap.sh                                   # или --dry-run
```

## Три плоскости — не смешивать

| Плоскость | Дом | Что |
|---|---|---|
| **Сознание** (агент-ОС) | `~/.claude` · `~/.codex` · `~/.agents` | конституция, rules, hooks, agents, реестр SSOT — через chezmoi |
| **Знания** | `~/Мозг` | durable-знание по методу Карпаты, приватный репо |
| **Работа** | `~/Проекты` · `~/Хранилище` · `~/Архив` | проекты, документы, медиа |

Правила раскладки живут ВНУТРИ системы: [`rules/structure.md`](rules/structure.md) (декларатив) + skill `organize` (процедура) + PreToolUse-hook (инвариант). Рост системы идёт по ним.

## Шесть слоёв разворота (`bootstrap.sh`)

```
0  База        Homebrew + CLI (claude, codex, gh, node, python, uv, ffmpeg) — Brewfile
1  Сознание        chezmoi разворачивает ~/.claude · ~/.codex · ~/.agents
2  Реестр      build_registry → capability-plan SSOT
3  Работа      clone + install.sh проектов по projects.manifest
4  Знания      clone приватного vault-репо
5  Рантайм     ~/.secrets (Keychain) · MCP reauth · launchd
6  Smoke       паритет Claude=Codex + линт структуры
```

Запуск по слоям: `./bootstrap.sh --only=1`. Сухой прогон: `--dry-run`.

## Generic vs личное

- **В репо (publishable):** `bootstrap.sh`, `Brewfile`, `rules/structure.md`, skills, `claude-starter/`, шаблоны `chezmoi/`, `launchd/`, `smoke/`. Без `/Users/...`, без личных данных.
- **НЕ в репо:** значения секретов (Keychain / `~/.secrets`), контент vault (свой приватный репо), `athena.config.sh`, `projects.manifest`.

Личная инстанция = заполненный `athena.config.sh` + приватный chezmoi-source поверх этого generic-каркаса.

## Лицензия

MIT — см. [LICENSE](LICENSE).
