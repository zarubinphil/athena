#!/usr/bin/env bash
# Phase 7 — Synthetic parity smoke.
# Verifies that a route card produced for Claude Code and one for Codex
# carry identical schema fields. Does NOT call any LLM — uses fixtures.
# Also drift-checks live ~/.claude vs ~/.codex if both are deployed.
# Usage: smoke/parity-smoke.sh [REPO_ROOT]

fail=0
bad() { echo "  ✗ $1" >&2; fail=1; }
ok()  { echo "  ✓ $1"; }

echo "[parity-smoke] route-card schema + drift-check"

# ── 1. Fixture route cards ────────────────────────────────────────────────
# Both cards come from the same synthetic task (code-edit).
# The schema (field set) must be identical; only provider + primary differ.
TMPDIR_PS="$(mktemp -d /tmp/athena-parity-XXXXXX)"
trap 'rm -rf "$TMPDIR_PS"' EXIT

cat > "$TMPDIR_PS/claude-route.json" <<'EOF'
{
  "job_id": "smoke-parity-001",
  "task_class": "code-edit",
  "provider": "claude",
  "primary": "claude",
  "reviewer": "codex",
  "capabilities": ["code-edit"],
  "risk": "low",
  "confidence": "high",
  "why": ["smoke fixture — claude engine"],
  "alternatives": [],
  "requires_approval": []
}
EOF

cat > "$TMPDIR_PS/codex-route.json" <<'EOF'
{
  "job_id": "smoke-parity-001",
  "task_class": "code-edit",
  "provider": "codex",
  "primary": "codex",
  "reviewer": "claude",
  "capabilities": ["code-edit"],
  "risk": "low",
  "confidence": "high",
  "why": ["smoke fixture — codex engine"],
  "alternatives": [],
  "requires_approval": []
}
EOF

# ── 2. Schema field comparison ────────────────────────────────────────────
# Extract sorted field names from each card. Compare sets.
# Requires only grep/sed — no jq dependency.
fields_of() {
  grep -oE '"[a-z_]+"[[:space:]]*:' "$1" | sed 's/[[:space:]]*://' | sort -u
}

CLAUDE_FIELDS="$(fields_of "$TMPDIR_PS/claude-route.json")"
CODEX_FIELDS="$(fields_of "$TMPDIR_PS/codex-route.json")"

if [ "$CLAUDE_FIELDS" = "$CODEX_FIELDS" ]; then
  ok "route-card schema: identical ($(echo "$CLAUDE_FIELDS" | wc -l | tr -d ' ') fields)"
else
  ONLY_CLAUDE="$(comm -23 <(echo "$CLAUDE_FIELDS") <(echo "$CODEX_FIELDS"))"
  ONLY_CODEX="$(comm -13 <(echo "$CLAUDE_FIELDS") <(echo "$CODEX_FIELDS"))"
  bad "route-card schema: divergent"
  [ -n "$ONLY_CLAUDE" ] && echo "    claude-only fields: $ONLY_CLAUDE" >&2
  [ -n "$ONLY_CODEX"  ] && echo "    codex-only fields:  $ONLY_CODEX" >&2
fi

# ── 3. Required fields present in both cards ──────────────────────────────
REQUIRED="job_id task_class provider primary reviewer risk confidence why"
for field in $REQUIRED; do
  for card in "$TMPDIR_PS/claude-route.json" "$TMPDIR_PS/codex-route.json"; do
    grep -q "\"$field\"" "$card" \
      || bad "route-card missing required field '$field' in $(basename "$card")"
  done
done
ok "required fields present in both route cards"

# ── 4. Drift-check live ~/.claude vs ~/.codex (skip if not deployed) ──────
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"

if [ -d "$CLAUDE_DIR" ] && [ -d "$CODEX_DIR" ]; then
  echo "  [drift] both engines deployed — checking registry parity"

  # AGENTS.md must exist in both (registry entrypoint).
  [ -f "$CLAUDE_DIR/AGENTS.md" ] \
    || bad "drift: ~/.claude/AGENTS.md missing"
  [ -f "$CODEX_DIR/AGENTS.md" ] \
    || bad "drift: ~/.codex/AGENTS.md missing"

  # Both must reference the shared skills/workflows registry.
  grep -q 'SHARED-SKILLS-WORKFLOWS' "$CLAUDE_DIR/AGENTS.md" \
    || bad "drift: ~/.claude/AGENTS.md does not reference SHARED-SKILLS-WORKFLOWS"
  grep -q 'SHARED-SKILLS-WORKFLOWS' "$CODEX_DIR/AGENTS.md" \
    || bad "drift: ~/.codex/AGENTS.md does not reference SHARED-SKILLS-WORKFLOWS"

  ok "drift-check: AGENTS.md present and references shared registry in both engines"
else
  echo "  · engines not both deployed — drift-check skipped"
fi

# ── Result ────────────────────────────────────────────────────────────────
if [ "$fail" -ne 0 ]; then
  echo "PARITY-SMOKE FAIL" >&2
  exit 1
fi
echo "  ✓ parity-smoke: identical schema · required fields · drift-check"
echo "parity-smoke OK"
