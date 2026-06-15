# Capability Planning Gate

Applies to: Claude, Codex

Use before applying any non-trivial Skill, plugin, MCP server, agent, or workflow.

Default automation:

`node ~/.agents/registry/scripts/capability-plan.mjs "<task>" --cwd "$PWD" --limit 10 --external-fallback --log`

This command performs the graph-first preflight, repository scan, capability routing, and draft plan. Agents should run it themselves; the user should not have to ask Graphify questions manually.

Treat the output as a required draft, not blind autopilot. Refine it with repository evidence before calling tools or reading large skill bodies.

## Goal

Pick the best capability set for the actual repository and task before spending context on full skill bodies or tool calls.

Quality comes first. Token cost only breaks ties after fit and expected output quality are effectively equal.

## Procedure

1. Read `~/.agents/SHARED-SKILLS-WORKFLOWS.md`.
2. Run the default automation above.
3. Inspect the repository lightly when the automation shows missing or ambiguous repo signals:
   - project rules: `AGENTS.md`, `CLAUDE.md`, `claud.md`
   - structure: `rg --files`, package/config files, docs, tests
   - current state: relevant git status/diff when editing code
4. If a relevant `graphify-out/graph.json` exists, query it before broad file reads:
   - capability system graph:
     `graphify query "<question>" --graph ~/.agents/registry/capability-system-graph/graphify-out/graph.json --budget 1200`
   - use graph answers to pick exact files/nodes to inspect
5. Build or reuse the shared capability index:
   - rebuild after installs or config changes:
     `node ~/.agents/registry/scripts/build-skill-index.mjs`
   - route:
     `node ~/.agents/registry/scripts/route-skills.mjs "<task>" --limit 10`
6. Select capabilities across all types:
   - Skills: task methods and domain workflows
   - Plugins: artifact surfaces such as browser, documents, spreadsheets, presentations
   - MCP: external/local tools such as Context7, Exa, GitHub, Memory, Playwright, Codegraph
7. State the plan briefly before use:
   - selected capability
   - why it fits this repo/task
   - what it will read or do
   - why rejected close alternatives are not first choice
8. Read full `SKILL.md` only for selected Skill finalists.
9. Use MCP/plugins only when their capability is directly needed.
10. Log meaningful usage in `~/.agents/SKILL-USAGE-LEDGER.md`.
11. Apply the **Local-First Cascade** below when the preflight reports `local_match: weak` or `none`.
12. After the task, append one outcome line to the **Self-Learning Loop** log.

## Selection Order

1. Required by user or project rule.
2. Repository fit.
3. Expected quality and completeness.
4. Proven local usage and registry score.
5. Public signal: stars, freshness, community proof.
6. Token/runtime cost as tie-breaker.

## Local-First Cascade (grow the arsenal, never recycle blindly)

`capability-plan.mjs --external-fallback` adds a `local_match` verdict and, when local is too weak, an `external_fallback` recipe. Honor it as a cascade:

- **Tier 0 — local:** `local_match: strong` → use the local finalist. Stop. Do not search externally.
- **Tier 1 — external discovery (only on `weak`/`none`):** run the emitted `npx skills find "<terms>"`. READ-ONLY. It lists external skills.sh candidates — treat them as UNVETTED.
- **Tier 2 — gate (mandatory before any install):** read the candidate `SKILL.md`; check author (anthropics / vercel-labs / microsoft = trusted; unknown = full scrutiny or skip); run `uvx mcp-scan@latest --skills`; present what it does + scan verdict to the user.
- **Tier 3 — install (explicit approval only):** `npx skills add <owner/repo@skill>` — never `-y`, never blind `-g`. Re-scan after.

Strong-hit gate: top finalist `route_score >= FALLBACK_FLOOR` (140, calibrated 2026-06-13) and `lexical_score > 0`. Tune via env `CAP_FALLBACK_FLOOR`. Above the floor but semantically wrong? That is still a weak hit — fall back and log the false match.

Invariant: external = untrusted until gated. No install without SKILL.md read + clean mcp-scan + explicit user yes. ToxicSkills (Snyk 2026): 13.4% of ecosystem skills carry CRITICAL flaws.

## Self-Learning Loop (each task better than the last)

The cascade only makes the arsenal grow if outcomes feed back. Two mechanical steps:

**Before** a non-trivial task — scan `~/.claude/references/agents-routing-log.md` for the task class. If past runs fell back or failed, start from the capability that worked / the external skill already identified. Do not re-derive.

**After** the task — append one line to that log, in its existing format:

```text
DATE | <task class> | <capability used> | <✅|⚠️|❌> | local=<strong|weak|none> fell_back=<yes|no> adopted=<skill|–>
```

**On adopt** (Tier 3 install passed): register in `SHARED-SKILLS-WORKFLOWS.md`, run `build-skill-index.mjs`, refresh the graph (capability-system-graph / `/graphify`). The new skill becomes a Tier-0 local hit next time — fallback frequency for that task class decays to zero. That decay IS the growth.

Repeated `fell_back=yes` for one task class = a standing gap: fill it proactively (find + vet + adopt) instead of falling back every run.

**Auto-capture (no discipline required):** the preflight runs with `--log`, so every `weak`/`none` match is appended to `~/.claude/references/routing-auto.log` (TSV) automatically. Surface standing gaps anytime — `node ~/.agents/registry/scripts/routing-gaps.mjs` (prints nothing when there are none; safe to wire into a session-start hook once the log has data).

**Recalibrate `FALLBACK_FLOOR`** when the arsenal changes materially: rerun a labeled HAVE/MISS probe through `route-skills.mjs --json` and set the floor in the valley between their `route_score` ranges.

## Output Template

Keep it terse:

```text
Capability plan:
- repo signal: <what was found>
- graph signal: <graphify node/file/path if used>
- use: <skill/plugin/MCP> — <reason>
- skip: <near alternative> — <reason>
- next: <first action>
```

For tiny tasks, one sentence is enough. For risky or broad tasks, use a short bullet plan.
