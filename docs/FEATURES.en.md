# Athena — Feature Reference (EN)

> Russian version: [FEATURES.ru.md](FEATURES.ru.md) · Back to [README](../README.md)

<p align="center">
  <img src="assets/six-layers.png" alt="Athena layered deployment" width="85%">
</p>

Athena is a portable agentic OS: one command stands up an entire personal agent
environment on a fresh Mac. This document describes every function in detail.

---

## 1. Layered bootstrap (`bootstrap.sh`)
**What:** A single orchestrator that builds the system in ordered layers (0, 0b, 1, 1b, 2–6).
**How:** Each layer is an idempotent shell function; `--only=<N>` runs one slice, `--dry-run`
prints actions without executing. All paths derive from `$HOME` — no hardcoded `/Users/...`.
**Why:** Reproducibility. Re-running never double-applies; a clean Mac reaches a live system
in one pass.

## 2. Merged-source (`generic ⊕ private overlay`)
**What:** The dotfiles source is assembled from the public generic canon (`./chezmoi`) plus an
optional private overlay (`athena-private`).
**How:** Layer 1 rsyncs generic (`--delete` for a clean base) then overlays private (overlay
wins on conflict), then a single `chezmoi init --apply`. Without the overlay it runs generic-only.
**Why:** One public skeleton + one private layer = no secrets in the public repo, full system for the owner.

## 3. Idempotency & portability
**What:** Every operation is safe to repeat and contains no machine-specific values.
**How:** Guarded clones (`[ -d .git ]`), `$HOME`-relative paths, personal values isolated in
`athena.config.sh` (gitignored) / Keychain / chezmoi data.
**Why:** The same repo deploys on any Mac and any user account.

## 4. Layer 0 — base
**What:** Homebrew + CLI baseline.
**How:** Installs Xcode CLT, Homebrew, then `brew bundle` from the `Brewfile`.
**Why:** Guarantees the toolchain the rest of the layers assume.

## 5. Layer 0b — tools (`~/tools`)
**What:** External tools (e.g. bots) cloned **before** the brain.
**How:** Reads `tools.manifest` (`<git-url> <path> [install-cmd]`), clones into `~/tools/*`.
**Why:** Runs before Layer 1 so chezmoi `run_once_` scripts can wire a bot's `.env` at apply time.

## 6. Layer 1 — Сознание (dotfiles / agent-OS canon)
**What:** The agent-OS configuration plane: `~/.claude`, `~/.codex`, `~/.agents`.
**How:** Renders the merged chezmoi source — constitution (`CLAUDE.md`), rules, hooks, agents,
skills canon, registry SSOT.
**Why:** A consistent, version-controlled agent brain that travels with you.

## 7. Layer 1b — plugins
**What:** Reinstall of marketplaces and plugins.
**How:** Reads `plugins.manifest`; `claude plugin marketplace add` / `plugin install`.
**Why:** Plugins are declarative, not hand-installed per machine.

## 8. Layer 2 — registry SSOT
**What:** The capability registry (skills/MCP/agents single source of truth).
**How:** Rebuilds via `build_registry.py` / `build_views.py` / `validate.py` under `~/.agents/registry`.
**Why:** Graph-first capability routing relies on a fresh, validated registry.

## 9. Layer 3 — projects (`~/Проекты`)
**What:** Clones working projects.
**How:** Reads `projects.manifest` (private overrides default); guarded clones + optional install.
**Why:** A new machine has all working repos in their canonical home.

## 10. Layer 4 — Мозг (knowledge vault, `~/Мозг`)
**What:** The durable-knowledge vault (Karpathy "second brain" method).
**How:** Clones `ATHENA_VAULT_REPO` into `~/Мозг`; synthesis-on-write, hot/cold sections.
**Why:** Knowledge compounds instead of being re-derived each session.

## 11. Layer 5 — secrets · MCP · launchd (fail-closed)
**What:** Runtime: `~/.secrets` (700), MCP re-auth reminder, launchd agent registration.
**How:** launchd uses `launchctl bootout` → `bootstrap gui/$UID` (not the deprecated load/unload),
counts `loaded/errs`, reports `ok` **only** when `errs==0`, and aggregates a non-zero bootstrap exit.
**Why:** No silent "green but dead" agents — the run signal is honest.

## 12. Layer 6 — smoke
**What:** End-of-run invariant checks.
**How:** Runs `smoke/smoke.sh` (see #13).
**Why:** Fast confidence that structure and parity hold.

## 13. Smoke gates (`smoke/smoke.sh`)
**What:** Six invariant families: structure, path-cleanliness, secret-shaped tokens,
**personal-data**, canon presence, self-learning presence, and Claude↔Codex parity.
**How:** `grep`-based gates are the source of truth; the personal-data gate goes **RED** on any
owner name / username / private identifier (proven by injection test).
**Why:** Regressions (a leaked name, a missing canon file) fail loudly, automatically.

## 14. Clean-room dry-validate (`smoke/dry-validate.sh`)
**What:** Emulates the chezmoi render without installing chezmoi.
**How:** Builds the merged source in a temp dir, substitutes known template vars, validates plists
(`plutil`), JSON (settings), script syntax, and catches unknown `{{ }}` tokens. Generic-only is a
GREEN pass; a missing-but-**expected** overlay (`ATHENA_EXPECT_OVERLAY=1`) is RED.
**Why:** Template type-safety on every run; green never lies about the public-clone path.

## 15. Security guard (deny-shield)
**What:** A deterministic hook layer plus `settings.json` `permissions.deny`.
**How:** `hooks/security-guard.sh` blocks writes to sensitive paths; the deny list covers
dangerous patterns — enforced by code, not prose.
**Why:** A single defensive layer travels with the dotfiles.

## 16. Self-learning subsystem (`skills/self-learning`)
**What:** A portable learning loop that runs at session checkpoints / end.
**How:** The `self-learning` skill drives four steps — (1) error → root cause → fix → **system rule**;
(2) token audit → next-time savings; (3) owner facts + repeating patterns → memory/automation;
(4) routing outcome. Append-only logs (`~/.claude/self-learning/`, created once, never clobbered)
plus a retro template. Built on the Karpathy method: synthesis-on-write, "one metric makes the loop
smart", keep-or-revert for autonomous loops.
**Why:** Each session compounds into durable knowledge that travels with the OS.

## 17. Session lifecycle
**What:** Checkpoint-based closing with continuity through memory.
**How:** At CTX ≥ 80% or a logical checkpoint: run self-learning → write a compact handoff →
close the session. A session reaper reclaims stalled sessions.
**Why:** Bloated context is the main token leak; continuity lives in memory, not long context.

## 18. CI (`.github/workflows/smoke.yml`)
**What:** Continuous verification on push/PR.
**How:** macOS runner installs shellcheck, runs `smoke.sh` and a clean-room generic-only dry-validate.
**Why:** The honesty gates run on every change, not just locally.
