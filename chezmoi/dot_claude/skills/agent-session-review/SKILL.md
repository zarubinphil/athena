---
name: agent-session-review
description: Local session learning tail — capture brief_md / agent_trace / self_reflection / most_important at the final edge of a job. Mandatory gate before deliver. Triggers: "session tail", "job done", "end of run", "learning tail", /agent-session-review.
metadata:
  model: Sonnet
---

# Agent Session Review (learning tail)

The final edge of every job. A job is not done with a text answer — it is done when the tail is written.  
Karpathy method: synthesize on write, not store raw. Short, precise, survives context compression.

Runs at the end of every meaningful agent session **before** handoff / deliver gate.  
Mandated by the `final-learning-tail` gate in `handoff-graph.yaml`.

---

## Trigger

- After completing a multi-step job (any provider: Claude Code, Codex).
- Before writing to vault, before handoff, before the deliver gate fires.
- Gate edge `final-learning-tail` checks all four blocks are present.

---

## Four required blocks

All four **must** be present. Missing any block → gate fails.

---

### brief_md

3–5 bullets. What was actually done — artifacts produced, decisions made.  
Describe what changed, not what was asked.

```
## Session Brief
- [artifact]: [one concrete line]
- [decision]: [one concrete line]
```

---

### agent_trace

Chronology of key tool calls and decision points.  
Not every tool — only inflection points where direction was chosen or changed.

```
## Agent Trace
1. [tool / action] → [outcome or decision]
2. ...
```

---

### self_reflection

One short paragraph each.

```
## Self-Reflection
**Went well:** ...
**Went wrong / could be better:** ...
**Next time:** ...
```

---

### most_important

Single most important thing not to lose: a constraint, a lesson, a warning, a pattern.  
Must fit in **one sentence** — this is what survives context compression.

```
## Most Important
[one sentence]
```

---

## Output

Write the tail to `~/.agents/reports/<run-id>-session-tail.md`  
or append to the job outbox note.

Optionally pass to the postrun report:

```bash
node ~/.agents/registry/scripts/athena-postrun-report.mjs \
  --results-json <results.json> \
  --run-id <run-id>
```

---

## Gate check (smoke/agent-contract.sh)

Smoke verifies this file exists and contains all four block names:  
`brief_md`, `agent_trace`, `self_reflection`, `most_important`.
