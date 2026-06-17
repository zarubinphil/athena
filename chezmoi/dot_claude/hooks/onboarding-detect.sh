#!/usr/bin/env bash
# onboarding-detect.sh — SessionStart-детектор первого запуска Athena.
# НЕ интервьюирует (shell неинтерактивен) — детектит «не персонализировано»
# и инжектит additionalContext-nudge: запусти setup-os. Молчит когда настроено/snooze.
# Идемпотентно. Без хардкода путей ($HOME). Спец: specs/onboarding-grill.md §9.
set -euo pipefail

CLAUDE_DIR="${HOME}/.claude"
DONE_MARKER="${CLAUDE_DIR}/.athena-onboarded"
SNOOZE_MARKER="${CLAUDE_DIR}/.athena-onboarding-snooze"
OWNER_FILE="${CLAUDE_DIR}/references/owner.md"

emit_nudge() {
  # SessionStart additionalContext через JSON-выход (надёжнее чистого stdout).
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"⚙️ Athena не персонализирована (нет ~/.claude/.athena-onboarded). Запусти грилл первого запуска: вызови skill setup-os (Этап A — полный грилл P1–P5). Он соберёт owner.md/CLAUDE.md/манифесты/references по методу Карпаты. Если позже — скажи «пропустить онбординг» (поставлю snooze, не буду долбить)."}}
JSON
}

# 1. Уже настроено → молчим.
[ -f "$DONE_MARKER" ] && exit 0
# 2. Snooze (юзер сказал «позже») → молчим.
[ -f "$SNOOZE_MARKER" ] && exit 0

# 3. Fresh по маркеру. Доп-эвристика: owner.md с {{ placeholder → точно не заполнен.
if [ ! -f "$OWNER_FILE" ]; then
  emit_nudge
  exit 0
fi
if grep -q '{{' "$OWNER_FILE" 2>/dev/null; then
  emit_nudge
  exit 0
fi

# owner.md есть и без placeholder, но маркера нет — ставим его (онбординг де-факто пройден),
# чтобы не нудеть в дальнейшем. Тихо.
: > "$DONE_MARKER" 2>/dev/null || true
exit 0
