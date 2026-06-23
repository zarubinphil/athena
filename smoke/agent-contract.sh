#!/usr/bin/env bash
# Phase 7 — Local Agent Contract smoke.
# Validates role passports + the directed handoff graph. Zero deps (grep/awk).
# A pipeline without a valid passport+graph contract is a draft, not production.
# Usage: smoke/agent-contract.sh [REPO_ROOT]   (default: repo root from script path)

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PASS_DIR="$ROOT/chezmoi/dot_agents/role-passports"
GRAPH="$ROOT/chezmoi/dot_agents/handoff-graph.yaml"

AGENTS="athena-router athena-guard athena-runner athena-reconciler athena-reviewer athena-librarian athena-steward"
fail=0
bad() { echo "  ✗ $1" >&2; fail=1; }

echo "[agent-contract] passports + handoff graph"

# 1. Passports exist and carry the canon fields.
for a in $AGENTS; do
  f="$PASS_DIR/$a.md"
  if [ ! -f "$f" ]; then bad "passport missing: $a"; continue; fi
  for field in 'Soul' 'Does:' 'Tools:' 'Model:' 'Contract:' "Won't:" 'Parity:'; do
    grep -q "$field" "$f" || bad "$a: missing field '$field'"
  done
done

# 2. Graph exists with the required top-level keys.
if [ ! -f "$GRAPH" ]; then
  bad "handoff-graph.yaml missing"
else
  for key in entry agents handoffs forbidden gates; do
    grep -q "^$key:" "$GRAPH" || bad "graph missing key: $key"
  done

  # 3. Each agent is declared and appears in handoffs (no orphan).
  handoff_block=$(awk '/^handoffs:/{f=1;next} /^[a-z]/{f=0} f' "$GRAPH")
  for a in $AGENTS; do
    grep -q "id: $a" "$GRAPH" || bad "agent not declared: $a"
    printf '%s\n' "$handoff_block" | grep -q "$a" || bad "orphan agent (absent from handoffs): $a"
  done

  # 4. Every handoff edge carries a `when` (each edge is one inline line).
  n_edge=$(printf '%s\n' "$handoff_block" | grep -c 'from:')
  n_when=$(printf '%s\n' "$handoff_block" | grep -c 'when:')
  [ "$n_edge" = "$n_when" ] || bad "handoffs: $n_edge edges but $n_when 'when:' (every edge needs a when)"

  # 5. Every forbidden entry carries a `why`.
  forbid_block=$(awk '/^forbidden:/{f=1;next} /^[a-z]/{f=0} f' "$GRAPH")
  n_forbid=$(printf '%s\n' "$forbid_block" | grep -c 'from:')
  n_why=$(printf '%s\n' "$forbid_block" | grep -c 'why:')
  [ "$n_forbid" = "$n_why" ] || bad "forbidden: $n_forbid entries but $n_why 'why:'"

  # 6. The final-learning-tail gate names all four mandatory tail outputs.
  for t in brief_md agent_trace self_reflection most_important; do
    grep -q "$t" "$GRAPH" || bad "final-learning-tail missing output: $t"
  done
fi

if [ "$fail" -ne 0 ]; then
  echo "AGENT-CONTRACT FAIL" >&2
  exit 1
fi
echo "  ✓ 7 passports · graph integrity · learning-tail"
echo "agent-contract OK"
