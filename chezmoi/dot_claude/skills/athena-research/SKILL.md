---
name: athena-research
description: Thin-session capability router. Given a task description OR an explicit skill id, finds the single best local skill via GraphiFy (route-skills.mjs) and Reads only that one SKILL.md to follow it. Most of the ~1450 local skills are hidden from the skill listing (skillOverrides=user-invocable-only) to keep sessions lean — their names/descriptions are NOT in context. Use this whenever you need a capability you don't currently see, or to run a named hidden skill.
---

# athena-research — capability router

Most of the ~1450 local skills are hidden from your skill listing
(`skillOverrides: user-invocable-only`) so the session starts lean. Their bodies
still live in `~/.claude/skills/<id>/SKILL.md` and work fully — you just have to
find and Read the right one on demand. That is this skill's only job.

## Input — one of

- **A task** ("scrape this site to markdown", "review this Go diff", "harvest a
  YouTube transcript into the vault"): you don't know the skill name. → *find then load.*
- **An explicit skill id** ("run `firecrawl-scrape`"): you already know it. → *load directly.*

## Protocol

### Task → find then load

1. Run the local router (pure node, ~0 model tokens):
   ```bash
   node ~/.agents/registry/scripts/route-skills.mjs "<task text>" --limit 5 --json
   ```
2. Look at the 5 results (each has `name`, `route_score`, `path`). Pick the best
   fit. If the top score is weak or nothing fits the actual task, say so and
   proceed WITHOUT a skill — do not force a bad match.
3. **Read only that one `SKILL.md`** (its `path`) and follow it. Do not load the
   other four.
4. If the chosen skill is heavy (large body, many reads, multi-step) or the work
   is parallelizable, spawn a subagent with the task + the skill path instead of
   running it inline — keep this context lean.

### Explicit id → load directly

1. Read `~/.claude/skills/<id>/SKILL.md`. Some skills are nested
   (e.g. `~/.claude/skills/ecc/<id>/SKILL.md`); if the direct path is missing,
   run the router with the id as the query to resolve the real `path`, then Read it.
2. Follow it (or hand it to a subagent, same heavy/parallel rule as above).

## Notes

- The `UserPromptSubmit` hook (`~/.claude/hooks/skill-router.mjs`) already runs
  this router on every substantive prompt and injects the top 5 — so usually the
  candidates are already in front of you. Invoke this skill explicitly mainly for
  a **named** skill, or to re-search mid-task with a sharper query.
- **Reading a `SKILL.md` works regardless of `skillOverrides`** (the Read tool
  ignores skill visibility). You never need to re-enable a skill to use its body
  this way.
- `/name` still works for the user on every `user-invocable-only` skill. Only
  `off` skills need re-enabling first.
- The allowlist kept visible (model-auto-invocable) is small and lives in
  `~/.claude/settings.local.json` under `skillOverrides`. Everything not listed
  there is reached through this router.
