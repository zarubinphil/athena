# Phase 7 — Local Agent Contract (Hire Agents, local-first)

> Project artifacts are English-first. Communication language is asked at install; if the operator chooses Russian it becomes an inviolable rule. This spec is an artifact → English.

Athena today checks the **install** (structure, secrets, parity render). Phase 7 adds a layer that checks the **behavior** of the agent workflow: roles, transitions, reports, eval records. A job is not done when there is only a text answer — a job is done when there is an accounting of inputs, artifacts, a check, the executor role, a short report, durable knowledge, and next actions.

The layer is engine-agnostic: one contract for Claude Code and Codex. Dashboard / VPS come later, as a thin shell over verified local workflows.

## Sources (provenance, reconciled)

- Skeleton: `docs/MNEMAZINE-AGENTOS-TRANSFER.ru.md` (23 Jun, local-first, two-engine rescue).
- Canon detail (grafted below): `~/Мозг/03 Проекты/AthenaOS/Atoms/2026-05-27 — {Agent Registry, Agent Router, Athena Steward, Eval feedback loop, Capability Registry, Job envelope, Job lifecycle, Inbox Outbox contract, Project contract, Security & governance, Codex/Claude start matrix}.md`.
- Runtime-proven passport + handoff format: `~/Мозг/99 Система/{Паспорта_агентов_Мнемозины, Agent_Handoff_Graph}.md`.

> Reconciliation (step B) found the transfer doc compressed the master document to the loss of 6 load-bearing contracts. They are grafted below. The VPS↔local-first conflict is resolved in favor of local-first (paths `/srv`→`$HOME`; the substance is engine-neutral).

## Roles (7 passports)

A name is part of the interface; an agent without a name is a faceless task-runner. Passport format: `Does · Tools · Model · Contract(invariant) · Won't · Parity`. Model by the quality-per-token rule. Files: `chezmoi/dot_agents/role-passports/<id>.md` (English).

| Agent | Does | Model | Contract invariant | Won't |
|---|---|---|---|---|
| **athena-router** | picks project/workflow/risk/executor+reviewer; **stage-preflight at every stage** | Sonnet | route card with `confidence`+`why[]`; no data → `confidence:low, status:hypothesis` | execute; external action without approval |
| **athena-guard** | census of inputs (sha256+sensitivity), secret scan, approvals, risk, completeness | Haiku | every input accounted or explicit reason; secret-path blocked | edit content; judge quality |
| **athena-runner** | provider adapter: runs `run_job` on Claude/Codex; tier Haiku→Opus inside provider | Haiku→Opus | works in workspace/worktree; output to outbox, not vault | push/publish/delete/spend without approve |
| **athena-reconciler** | coverage ledger: each expected artifact received OR a logged reason | Sonnet | "COVERAGE COMPLETE ✓" only at `unaccounted==0` + balanced ledger | judge quality (reviewer's gate) |
| **athena-reviewer** | eval-spec check + release-gate verdict (pass/needs-revision/reject) | Sonnet→Opus | medium/high risk never delivers without its verdict | count coverage (reconciler's gate) |
| **athena-librarian** | outbox, durable vault note (Karpathy method), graph links, indexes | Haiku→Sonnet | vault gets only synthesis; raw/OCR/logs stay in cache | enrich content; change routing |
| **athena-steward** | weekly improvement loop over eval records + failures; cheap governance | Sonnet | budget (`max_proposals/week`); only passed → approval report | watch everything; auto-apply |

> `reconciler` and `reviewer` are **separate gates** (canon invariant): accounting inputs ≠ judging quality. Never merge. triage — deferred (YAGNI). Coordinator / learning-tail — not a role, a gate edge (below).

## Directed handoff graph (machine-readable)

`~/.agents/handoff-graph.yaml` — `agents[]` (role/input/output/tools), `handoffs[{from,to,when,payload}]`, `forbidden[{from,to,why}]`, `gates[{after,checks}]`. Chain:

```text
intake -> guard -> router -> runner -> reviewer -> librarian -> visual report
                              \-> rescue runner -> reviewer
guard -> reconciler (coverage) ----------------/    (before deliver)
```

Forbidden (canon ⊕ transfer): `runner->deliver` without reviewer for medium/high; `router->external` without approval; `runner->vault` directly without librarian; `rescue->rescue` without a limit (1 attempt); any `agent->secret/auth/session/cache path`; `librarian->enrich` (a storage role does not enrich).

Gates: `handoff-integrity` (all agents exist, every edge has a `when`, forbidden documented) + **`final-learning-tail`** (tail = `brief_md, agent_trace, self_reflection, most_important` — mandatory, formalized as an edge + gate, not optional).

## Parity Claude ↔ Codex

Parity = **enforcement (smoke), not a job title.** Lesson: memory ≠ obedience; checks only through a gate.

- **`run_job`** (engine-agnostic, provenance fields grafted from Job envelope): `{job_id, project_id, provider:claude|codex, workspace, prompt, inputs[{content_hash,sensitivity}], constraints[], expected_artifacts[], route{primary,reviewer,confidence}, eval_spec{}, execution{target:local-first, vps_allowed:false}}`. Provider changes — artifacts and eval stay the same.
- **Per-class start matrix** (router core, grafted): 10 classes (code-edit/debug/arch/docs/legal/obsidian/deploy/ui/security/steward) → primary+reviewer+why. Code/debug/deploy/UI → Codex primary, Claude reviewer; arch/docs/legal/obsidian/security/steward → Claude primary, Codex reviewer. The matrix is a hypothesis; eval logs refine it.
- **Capability divisions** (research/design/legal/ops/release/growth/knowledge/security): per-capability `owner/test/trust/risk/usage-signal/provenance`.
- **parity-smoke**: one task through both clients → compare route card + output (`identical|divergent+why`) + drift-check of live `~/.claude` vs `~/.codex` against the registry.

## Grafted contracts (lost in compression → restored)

1. **Job lifecycle FSM** (`~/.agents/job-lifecycle.yaml`): `Draft→Staging→ProjectDetection→RouteProposed→Approved→Queued→Running→NeedsInput→ReviewReady→Delivered→Archived` (+`Failed→Retry`). The ledger records the current state.
2. **Eval feedback loop closed onto the router**: user-correction → router-update (wrong project → matching penalty; always one provider → project policy; bad artifact → eval label). Without closing the loop, "learn from history" is a slogan.
3. **project.yaml** (project passport, claude-starter): `data_policy{sensitivity,allow_cloud,allow_embeddings,retention_days,require_upload_manifest}`, `capabilities{allowed,blocked}`, `agents.preferred_pair{primary,reviewer}`, `steward.max_proposals_per_week`. Per-project enforcement + smoke validation.
4. **Security governance + Emergency switch**: no auto-upload; per-project memory boundary; audit log per job; retention/deletion pipeline; emergency mode (`disable_new_jobs/pause_uploads/disable_mcp/revoke_tokens/preserve_audit`).

## Dynamic skill selection (stage-preflight loop)

`athena-router` runs `capability-plan.mjs "<stage sub-task>"` **at every stage boundary**, not once per job: name the sub-task → finalists (cheap `route-skills.mjs` for routine, full plan at phase boundaries) → read only the selected SKILL.md → not in skills → vault `~/Мозг` via `_ROUTING.md` → a "why" line → act. Each choice → `routing-evals.jsonl` → eval loop. "One skill set for the whole job" is forbidden.

## Layout (deployed paths, both clients)

| Artifact | chezmoi source | Deploy |
|---|---|---|
| Role passports | `chezmoi/dot_agents/role-passports/<id>.md` | `~/.agents/role-passports/` |
| Handoff graph | `chezmoi/dot_agents/handoff-graph.yaml` | `~/.agents/handoff-graph.yaml` |
| Job lifecycle FSM | `chezmoi/dot_agents/job-lifecycle.yaml` | `~/.agents/` |
| Postrun report | `chezmoi/dot_agents/registry/scripts/athena-postrun-report.mjs` | `~/.agents/registry/scripts/` |
| Report quality gate | `chezmoi/dot_agents/registry/scripts/athena-report-quality-gate.mjs` | `~/.agents/registry/scripts/` |
| Contract smoke | `smoke/agent-contract.sh` (repo) | CI + live smoke |
| project.yaml | `claude-starter/project.yaml` (template) | the user's end project |

All paths on `$HOME` / chezmoi `.tmpl`; zero hardcoded `/Users` or `/srv`.

## Implementation order (10 steps, amended)

1. `role-passports/` — 7 passports (canon format: model/tools/contract/won't). **[done]**
2. `handoff-graph.yaml` — machine-readable (per-edge `when/payload`, forbidden ⊕ rescue/secret, `final-learning-tail` gate). **[done]**
3. `smoke/agent-contract.sh` — passport schema + handoff integrity (orphan/when/forbidden/tail). **[done]**
4. `skills/agent-session-review` (or workflow) — local session tail (brief/trace/reflection/most-important).
5. `scripts/athena-postrun-report.mjs` — Markdown/HTML/JSON report after a meaningful run (`results-json {group_id,outcome,helps,next_action}`).
6. `scripts/athena-report-quality-gate.mjs` — no raw OCR / local filenames / secrets.
7. `job-lifecycle.yaml` + ledger state; `project.yaml` template + validation.
8. eval loop → router (routing-evals.jsonl); start matrix into the router.
9. Extend `smoke/smoke.sh` (agent-contract + report-quality synthetic); `docs/FEATURES.ru.md` (maturity layers); this file in the roadmap.
10. Only then — dashboard as a thin UI over verified local workflows.

## Gates / DoD

The Phase-7 release gate fails not only on shell syntax but on: a lost passport, a broken handoff graph, a dirty report (raw/secrets), a missing action brief, an unclosed eval, divergent parity. **DoD:** `smoke/agent-contract.sh` green · 7 passports + handoff pass integrity · one run leaves `brief_md/agent_trace/self_reflection/most_important` · parity-smoke `identical` on a test task · 0 hardcoded paths.
