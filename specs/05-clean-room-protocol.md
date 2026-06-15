# Спец: clean-room протокол (Ф5 акт-верификации)

> Назначение: запротоколировать честный прогон generic-каркаса на чистом таргете —
> недостающий акт верификации DoD Ф5. Источник: IMPLEMENTATION-PLAN P0.4 (KGB-15/20/21, CIA-1/8).
> Public-safe: личных значений нет.

## Что доказывали
На чистом таргете (без приватного `athena-private` overlay) generic-путь
`git clone <generic> && ./bootstrap.sh` валиден, а сигнал прогона **не лжёт**.

## Прогон 2026-06-16 (эмуляция clean-room, dry-validate)

| Сценарий | Команда | Ожидание | Факт |
|---|---|---|---|
| A. generic-only (чистый таргет, overlay отсутствует) | `ATHENA_PRIVATE_DIR=<empty> dry-validate.sh` | GREEN, 0 нерендеренных `{{ }}` | **GREEN**, 0 неизвестных токенов ✓ |
| B. overlay ожидался, но отсутствует | `ATHENA_EXPECT_OVERLAY=1 dry-validate.sh` (без overlay) | RED (неполнота честно видна) | **RED** ✓ |
| C. launchd dry-ветка | `./bootstrap.sh --dry-run --only=5` | счётчик loaded/errs, честный rapport | **«загружены: 5»**, bootout/bootstrap ✓ |

## Что сделано для честности сигнала (предусловия)
- **launchd fail-closed** (`bootstrap.sh` Слой 5): убран безусловный `ok`; теперь
  счётчик `loaded/errs`, `ok` только при `errs==0`, иначе `warn` + инкремент `BOOT_ERRS`.
- **deprecated API заменён:** `launchctl load/unload` → `bootout gui/$UID/<label>` (игнор) →
  `bootstrap gui/$UID <tgt>` (ненулевой exit при провале регистрации).
- **агрегат-exit:** `BOOT_ERRS>0` → `bootstrap.sh` завершается `exit 1` (не плоская `;`-цепочка).
- **smoke не врёт зелёным:** generic-only = честный GREEN (валидная конфигурация публичного
  клона), overlay-missing-при-ожидании = RED через `ATHENA_EXPECT_OVERLAY` (флаг в owner-конфиге).
- **parity-чек реальный:** smoke сверяет наличие `AGENTS.md` в `~/.claude` И `~/.codex`
  (не вакуумный `chk 'true'`).

## Решение по «smoke RED без overlay» (оспорено и уточнено)
План формулировал «smoke RED при отсутствии overlay». Буквальная трактовка ломала бы
generic-публичного юзера, для которого generic-only — **валидная полная** конфигурация
(DoD требует «git clone generic → живая система»). Принято честнее: RED только когда
overlay **ожидался** (`ATHENA_EXPECT_OVERLAY=1`, выставляется в `athena.config.sh` владельца).
Так «зелень = готовность» соблюдается без лжи И без поломки публичного клона.

## Остаток (открыто, не закрыто этим прогоном)
- **Истинный `chezmoi execute-template`** на живом dest НЕ прогонялся: `chezmoi` не установлен
  на dev-машине, установка пакета — за явным добром владельца (правило НИКОГДА). dry-validate —
  это эмуляция рендера (известные vars), не настоящий chezmoi. **Действие владельцу:** на чистом
  таргете/VM с установленным chezmoi прогнать `chezmoi init --apply --source <merged>` generic-only
  и зафиксировать: (а) не осталось ли неизвестных `{{ }}`; (б) что молча скипнулось.
- **Реальная регистрация launchd** (bootout/bootstrap) на чистом таргете не выполнялась
  (dev-машина — боевая, не трогаем live launchd). Ветка проверена в `--dry-run`.

## Вывод
Generic clean-room путь **доказан в эмуляции** (GREEN, 0 неизвестных токенов); сигнал прогона
сделан честным (launchd fail-closed, агрегат-exit, smoke не врёт). Остаётся один владельческий
прогон с живым chezmoi на VM — это последний штрих DoD Ф5 перед публикацией.
