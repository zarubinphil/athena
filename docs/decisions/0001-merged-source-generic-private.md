# ADR-0001 — Merged-source: generic ⊕ private overlay

- **Статус:** принято
- **Дата:** 2026-06-16
- **Контекст:** Athena — публичный generic-каркас. Личные данные владельца (references,
  активные launchd-плисты, run_once_ секретов) НЕ должны попадать в публичный git, но
  обязаны разворачиваться на машине владельца тем же `./bootstrap.sh`.

## Решение

Слой 1 (Сознание) собирает **merged-source** перед `chezmoi apply`:
1. generic база (`./chezmoi`, `rsync --delete` = чистый старт),
2. приватный overlay (`$ATHENA_PRIVATE_REPO/chezmoi`) накладывается сверху (побеждает на конфликте).

Один `chezmoi init --apply --source $ATHENA_MERGED_SOURCE`. Пусто `ATHENA_PRIVATE_REPO`
= generic-only (валидный разворот без личного слоя).

## Последствия

- Публичный репо стартует чистым (smoke `PERSONAL_RE` гейтит личные данные в tracked).
- Дедуп target-конфликтов: реальный файл overlay затеняет generic-symlink того же target
  (иначе chezmoi `duplicate target`) — см. `bootstrap.sh` layer1_brain.
- Escape-hatch `ATHENA_DOTFILES_REPO` минует merge (готовый внешний source целиком).

## Альтернативы

- Один приватный репо целиком — отвергнуто: убивает публичность каркаса.
- Ветки/сабмодули — отвергнуто: сложнее идемпотентного rsync-merge.
