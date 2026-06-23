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

# 7. agent-session-review skill exists and carries all four required blocks.
SKILL_FILE="$ROOT/chezmoi/dot_claude/skills/agent-session-review/SKILL.md"
if [ ! -f "$SKILL_FILE" ]; then
  bad "agent-session-review SKILL.md missing"
else
  for block in brief_md agent_trace self_reflection most_important; do
    grep -q "$block" "$SKILL_FILE" || bad "agent-session-review SKILL.md: missing block '$block'"
  done
fi

# 8-10. Script smoke (requires node — skipped gracefully if absent).
REPORT_SCRIPT="$ROOT/chezmoi/dot_agents/registry/scripts/athena-postrun-report.mjs"
GATE_SCRIPT="$ROOT/chezmoi/dot_agents/registry/scripts/athena-report-quality-gate.mjs"

if command -v node >/dev/null 2>&1 && [ -f "$REPORT_SCRIPT" ] && [ -f "$GATE_SCRIPT" ]; then
  SMOKE_TMP="$(mktemp -d /tmp/athena-smoke-XXXXXX)"
  trap 'rm -rf "$SMOKE_TMP"' EXIT

  # 8. Synthetic postrun-report run — valid input → exit 0 + produces .md file.
  printf '[{"group_id":"g1","outcome":"done","helps":"helped with X","next_action":"do Y"}]' \
    > "$SMOKE_TMP/results.json"
  ATHENA_REPORTS="$SMOKE_TMP/reports" node "$REPORT_SCRIPT" \
    --results-json "$SMOKE_TMP/results.json" --run-id smoke --quiet \
    && true || bad "postrun-report: exit non-zero on valid input"

  GOOD_REPORT=$(ls "$SMOKE_TMP/reports/"*.md 2>/dev/null | head -1)
  if [ -n "$GOOD_REPORT" ]; then
    # 9. Quality gate on good report → must PASS (exit 0).
    node "$GATE_SCRIPT" --report "$GOOD_REPORT" >/dev/null 2>&1 \
      || bad "quality-gate: good report should PASS"
  else
    bad "postrun-report: no .md file produced"
  fi

  # 10. Quality gate on bad report (raw OCR marker, no outcome/next_action) → must FAIL (exit 1).
  printf 'temp_image_20240101.HEIC dummy content no outcome here' \
    > "$SMOKE_TMP/bad-report.md"
  node "$GATE_SCRIPT" --report "$SMOKE_TMP/bad-report.md" >/dev/null 2>&1 \
    && bad "quality-gate: bad report should FAIL" \
    || true
else
  [ ! -f "$REPORT_SCRIPT" ] && bad "athena-postrun-report.mjs missing"
  [ ! -f "$GATE_SCRIPT" ] && bad "athena-report-quality-gate.mjs missing"
  command -v node >/dev/null 2>&1 || echo "  → node not found; skipping report+gate smoke"
fi

# 11. job-lifecycle.yaml exists and carries required FSM keys.
LIFECYCLE="$ROOT/chezmoi/dot_agents/job-lifecycle.yaml"
if [ ! -f "$LIFECYCLE" ]; then
  bad "job-lifecycle.yaml missing"
else
  for key in initial_state states terminal_states invariants; do
    grep -q "^$key:" "$LIFECYCLE" || bad "job-lifecycle.yaml missing top-level key: $key"
  done
  REQUIRED_STATES="Draft Staging ProjectDetection RouteProposed Approved Queued Running NeedsInput ReviewReady Delivered Archived Failed Retry"
  for s in $REQUIRED_STATES; do
    grep -q "^  $s:" "$LIFECYCLE" || bad "job-lifecycle.yaml missing state: $s"
  done
fi

# 12. project.yaml template exists in claude-starter with required fields.
PROJECT_YAML="$ROOT/claude-starter/project.yaml"
if [ ! -f "$PROJECT_YAML" ]; then
  bad "claude-starter/project.yaml missing"
else
  for field in data_policy capabilities agents steward sensitivity allow_cloud retention_days preferred_pair max_proposals_per_week; do
    grep -q "$field" "$PROJECT_YAML" || bad "project.yaml missing field: $field"
  done
fi

# 13. routing-evals.example.jsonl exists in claude-starter.
EVALS_EXAMPLE="$ROOT/claude-starter/routing-evals.example.jsonl"
[ -f "$EVALS_EXAMPLE" ] || bad "claude-starter/routing-evals.example.jsonl missing"

# 14. athena-router passport carries start matrix (10 classes).
ROUTER_PASSPORT="$ROOT/chezmoi/dot_agents/role-passports/athena-router.md"
MATRIX_CLASSES="code-edit debug arch docs legal obsidian deploy ui security steward"
if [ -f "$ROUTER_PASSPORT" ]; then
  for cls in $MATRIX_CLASSES; do
    grep -q "$cls" "$ROUTER_PASSPORT" || bad "athena-router.md start matrix missing class: $cls"
  done
fi

# 15. parity-smoke.sh exists and passes.
PARITY="$ROOT/smoke/parity-smoke.sh"
if [ ! -f "$PARITY" ]; then
  bad "smoke/parity-smoke.sh missing"
elif [ -x "$PARITY" ]; then
  "$PARITY" "$ROOT" >/dev/null 2>&1 || bad "parity-smoke.sh failed"
fi

if [ "$fail" -ne 0 ]; then
  echo "AGENT-CONTRACT FAIL" >&2
  exit 1
fi
echo "  ✓ 7 passports · graph integrity · learning-tail · session-review skill · report+gate"
echo "  ✓ job-lifecycle FSM · project.yaml template · routing-evals format · start matrix · parity-smoke"
echo "agent-contract OK"
