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

# Rate-карта за Mtok [in, out, cache-write, cache-read]; ключ — подстрока model id.
RATES = {
    "opus":   [15.0, 75.0, 18.75, 1.50],
    "sonnet": [ 3.0, 15.0,  3.75, 0.30],
    "haiku":  [ 1.0,  5.0,  1.25, 0.10],
}
def rate_for(model):
    ml = (model or "").lower()
    for k, r in RATES.items():
        if k in ml: return r
    return RATES["opus"]  # неизвестная → Opus-rate (консервативно)

def short(model):
    ml = (model or "?").lower()
    for k in RATES:
        if k in ml: return k
    return model or "?"

# Агрегация по модели: {model: [in, out, cw, cr, calls]}
per = {}
n = 0
for line in open(f):
    try: d = json.loads(line)
    except Exception: continue
    m = d.get("message", {})
    u = m.get("usage") or {}
    if not u: continue
    mid = m.get("model") or "?"
    if mid == "<synthetic>": continue   # синтетические сообщения — без реальных токенов
    n += 1
    a = per.setdefault(mid, [0, 0, 0, 0, 0])
    a[0] += u.get("input_tokens", 0);              a[1] += u.get("output_tokens", 0)
    a[2] += u.get("cache_creation_input_tokens", 0); a[3] += u.get("cache_read_input_tokens", 0)
    a[4] += 1

def cost_of(it, ot, cc, cr, model):
    r = rate_for(model)
    return it/1e6*r[0] + ot/1e6*r[1] + cc/1e6*r[2] + cr/1e6*r[3]

T_it = T_ot = T_cc = T_cr = T_cost = 0
print(f"сессия: {f.split('/')[-1]}")
print(f"вызовов с usage: {n} | моделей: {len(per)}")
# Блок на модель (сортировка по убыванию $)
rows = sorted(per.items(), key=lambda kv: -cost_of(kv[1][0], kv[1][1], kv[1][2], kv[1][3], kv[0]))
for mid, (it, ot, cc, cr, calls) in rows:
    c = cost_of(it, ot, cc, cr, mid)
    tot = it + ot + cc + cr
    T_it += it; T_ot += ot; T_cc += cc; T_cr += cr; T_cost += c
    print(f"\n── {short(mid)} ({mid}) · {calls} выз. ──")
    print(f"  input(uncached): {it:>13,}")
    print(f"  output:          {ot:>13,}")
    print(f"  cache-write:     {cc:>13,}")
    print(f"  cache-read:      {cr:>13,}")
    print(f"  всего:           {tot:>13,}   ≈ ${c:,.2f}")

T_tot = T_it + T_ot + T_cc + T_cr
print(f"\n═══ ИТОГО ({len(per)} модел.) ═══")
print(f"input(uncached): {T_it:>13,}")
print(f"output:          {T_ot:>13,}")
print(f"cache-write:     {T_cc:>13,}")
print(f"cache-read:      {T_cr:>13,}")
print(f"ВСЕГО:           {T_tot:>13,}")
print(f"≈ стоимость:     ${T_cost:,.2f}  (per-model rates)")
if T_tot:
    parts = {"input": T_it, "output": T_ot, "cache-write": T_cc, "cache-read": T_cr}
    dom = max(parts, key=parts.get)
    print(f"доминанта: {dom} ({parts[dom]/T_tot*100:.0f}%)")
PY
