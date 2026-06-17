#!/usr/bin/env bash
# token-spend.sh — разбивка токен-расхода сессии из jsonl (для конца сессии / token-аудита самообучения).
# Использование: token-spend.sh [path/to/session.jsonl]
#   без аргумента — берёт самый свежий jsonl проекта текущего cwd.
set -uo pipefail

F="${1:-}"
if [ -z "$F" ]; then
  # имя проекта в ~/.claude/projects кодируется через замену '/' на '-'
  KEY=$(pwd | sed 's#/#-#g')
  DIR="$HOME/.claude/projects/$KEY"
  F=$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1)
fi
[ -n "$F" ] && [ -f "$F" ] || { echo "jsonl не найден ($F). Передай путь явно."; exit 1; }

python3 - "$F" <<'PY'
import json, sys
f = sys.argv[1]
it = ot = cc = cr = n = 0
models = set()
for line in open(f):
    try: d = json.loads(line)
    except Exception: continue
    m = d.get("message", {})
    u = m.get("usage") or {}
    if not u: continue
    n += 1
    it += u.get("input_tokens", 0); ot += u.get("output_tokens", 0)
    cc += u.get("cache_creation_input_tokens", 0); cr += u.get("cache_read_input_tokens", 0)
    if m.get("model"): models.add(m["model"])
# Opus-rate (груб): in $15 / out $75 / cache-write $18.75 / cache-read $1.50 за Mtok
cost = it/1e6*15 + ot/1e6*75 + cc/1e6*18.75 + cr/1e6*1.5
tot = it + ot + cc + cr
print(f"сессия: {f.split('/')[-1]}")
print(f"вызовов с usage: {n} | модели: {', '.join(models) or '—'}")
print(f"input(uncached): {it:>13,}")
print(f"output:          {ot:>13,}")
print(f"cache-write:     {cc:>13,}")
print(f"cache-read:      {cr:>13,}")
print(f"ВСЕГО:           {tot:>13,}")
print(f"≈ стоимость:     ${cost:,.2f}  (груб. Opus-rate)")
# доминанта
parts = {"input": it, "output": ot, "cache-write": cc, "cache-read": cr}
dom = max(parts, key=parts.get)
print(f"доминанта: {dom} ({parts[dom]/tot*100:.0f}%)")
PY
