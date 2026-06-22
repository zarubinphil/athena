# Thin session — thousands of skills, near-zero startup cost

## The problem

Claude Code injects the **name (and description) of every personal skill** in
`~/.claude/skills` into the system prompt at the **start of every session**. With
~1,400 skills that is **~11k tokens spent before you type a single character** —
every session, paying to advertise tools you mostly will not use this turn.

## What changed

Athena now ships a **thin session**: the bulk of skills are hidden from the
model's listing, and the right ones are surfaced **on demand** instead. Nothing is
moved or deleted — the skills stay exactly where they are and remain fully usable.

Three parts:

1. **Hide the bulk — native, reversible.** `gen-skill-overrides.mjs` writes a
   `skillOverrides` map into `~/.claude/settings.local.json`, setting every skill
   except a small allowlist to **`user-invocable-only`** — Claude Code's built-in
   state meaning *"hidden from the model, but still runnable by you via `/name`."*
   Hidden skills cost **zero** injection tokens.
2. **Surface on demand — always-on.** A `UserPromptSubmit` hook
   (`skill-router.mjs`) runs the local capability router on every substantive
   prompt and injects only the **top-5 relevant** skills (name + score + path). The
   model reads the one that fits and follows it. Pure-local Node — ~0 model tokens
   to produce; only the short ranked list enters context.
3. **A router skill — `athena-research`.** Manual entry point: hand it a task or an
   explicit skill name, it finds and loads the right `SKILL.md`.

## How it saves tokens

| | tokens / session |
|---|---|
| Before | ~11,000 (listing ~1,400 skill names) |
| After | ~150 (a ~12-skill allowlist) + a short per-prompt top-5 |
| **Saved** | **~11k per session, every session** |

The model starts clean and **pulls capability by relevance** instead of carrying
the whole catalog in context. Less overhead, more room for your actual problem.

## Why it is safe

- `user-invocable-only` keeps **`/name` working for every hidden skill** — nothing
  becomes unreachable.
- The hook is **fail-open** (any error/timeout → injects nothing, never blocks your
  prompt) and **guarded** (skips tiny prompts, slash-commands, and plain
  confirmations like "ok"/"да").
- Reading a `SKILL.md` ignores `skillOverrides`, so the router/hook can **always**
  load any skill.
- **Fully reversible**: delete the `skillOverrides` block (or just the entries you
  want back).

## The allowlist

Kept visible (the model can auto-invoke them): the router itself plus
lifecycle / always-on skills. Edit the `ALLOWLIST` set at the top of
`~/.claude/scripts/gen-skill-overrides.mjs` and re-run it.

## Also fixed alongside (routing quality)

- The capability index now scans `~/.claude/skills` too (it did not before) and
  **de-duplicates parity copies** across `.claude` / `.agents` / `.codex`, so the
  router can rank **all** your skills and points at the canonical, `/name`-invocable
  path.
- **Usage/frequency no longer affects ranking.** It is still collected for
  analytics, but a skill you used once is no longer pinned above genuinely better
  matches. Ranking is **quality-led**.

## Use it

- **Fresh install:** `bootstrap.sh` runs the generator in Layer 2 — thin session is
  **on by default**.
- **Existing install:** `node ~/.claude/scripts/gen-skill-overrides.mjs`, then
  restart Claude Code.
- **Revert:** remove `skillOverrides` from `~/.claude/settings.local.json`.

## Files

| File | Role |
|---|---|
| `~/.claude/scripts/gen-skill-overrides.mjs` | generates the hide-map (allowlist editable here) |
| `~/.claude/hooks/skill-router.mjs` | `UserPromptSubmit` hook — per-prompt top-5 |
| `~/.claude/skills/athena-research/SKILL.md` | manual router skill |
| `~/.agents/registry/scripts/build-skill-index.mjs` | index now covers `~/.claude/skills` + dedup |
| `~/.agents/registry/scripts/route-skills.mjs` | ranking (usage removed from ordering) |
| `~/.agents/registry/scripts/build_registry.py` | score is quality-led (usage unweighted) |
