# Phase 8 — Dashboard (thin UI over verified local workflows)

> Artifact language: English. Communication language: per owner profile.

A dashboard must not invent logic. It reads what Phase 7 produces and makes it visible.
No web server. No database. No new contracts — only new readers.

## What Phase 7 produces (inputs for Phase 8)

| Artifact | Location | Content |
|---|---|---|
| Routing evals | `~/.agents/routing-evals.jsonl` | per-job route decisions |
| Job ledger | `~/.agents/job-ledger.jsonl` | per-job state history |
| Postrun reports | `~/.agents/reports/*.md` | per-run Markdown reports |
| Steward proposals | `~/.agents/steward-log.jsonl` | weekly improvement candidates |

> Phase 7 defines the format; Phase 8 reads it. If a file doesn't exist yet, the reader skips gracefully.

## Two deliverables

### 1. `athena-status.mjs` — CLI status snapshot

```
$ node ~/.agents/registry/scripts/athena-status.mjs
```

Output (≤20 lines):

```
Athena status — 2026-06-23 12:00
Jobs (last 7d): 12 total · 10 delivered · 1 retry · 1 failed
Top classes: code-edit ×4  debug ×3  arch ×2  docs ×2  deploy ×1
Primary split: codex 7 (58%) · claude 5 (42%)
Confidence: high ×9  medium ×2  low ×1
Corrections: 0 this week
Pending steward proposals: 0
Reports: ~/.agents/reports/ (3 files)
```

Returns exit 0 if no critical issues; exit 1 if `failed > 0` and no retry.

### 2. `athena-weekly-report.mjs` — HTML/Markdown weekly summary

Extends `athena-postrun-report.mjs` pattern (same --quiet, --run-id flags).
Reads last 7 days from `routing-evals.jsonl` + steward-log.
Produces `~/.agents/reports/weekly-<YYYY-WW>.md` (+ `.html`).
Quality-gate: same `athena-report-quality-gate.mjs` pass required.

## Layout

| Artifact | chezmoi source | Deploy |
|---|---|---|
| Status CLI | `chezmoi/dot_agents/registry/scripts/athena-status.mjs` | `~/.agents/registry/scripts/` |
| Weekly report | `chezmoi/dot_agents/registry/scripts/athena-weekly-report.mjs` | `~/.agents/registry/scripts/` |

## Smoke additions

- `athena-status.mjs` exists + `node --input-type=module --eval 'import("./athena-status.mjs")'` syntax-check.
- Weekly report: synthetic JSONL → produces `.md` → quality-gate pass.

## DoD

- [ ] `athena-status.mjs` exits 0 on empty inputs (no evals yet).
- [ ] `athena-weekly-report.mjs` produces a valid report from synthetic JSONL.
- [ ] Quality gate passes on the weekly report.
- [ ] Smoke green; shellcheck 0 warnings (bash parts only).
- [ ] 0 hardcoded paths.
