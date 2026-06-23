# Role Passports — index

Engine-agnostic agent contracts read by **both Claude Code and Codex**. One file per agent; format `Soul · Does · Tools · Model · Contract · Won't · Parity`. The directed handoff graph (`../handoff-graph.yaml`) wires them; `smoke/agent-contract.sh` enforces passport + graph integrity.

| Agent | Role | Model | Gate it owns |
|---|---|---|---|
| [athena-router](athena-router.md) | route officer | Sonnet | route card + stage-preflight |
| [athena-guard](athena-guard.md) | intake census | Haiku | inputs accounted, secret-path blocked |
| [athena-runner](athena-runner.md) | provider adapter | Haiku→Opus | sandboxed run, outbox-only |
| [athena-reconciler](athena-reconciler.md) | coverage ledger | Sonnet | `unaccounted == 0` |
| [athena-reviewer](athena-reviewer.md) | eval / release gate | Sonnet→Opus | verdict before deliver |
| [athena-librarian](athena-librarian.md) | knowledge curator | Haiku→Sonnet | synthesis-only vault |
| [athena-steward](athena-steward.md) | weekly governance | Sonnet | budgeted proposals |

`reconciler` and `reviewer` are **separate gates** — accounting inputs ≠ judging quality. Never merge.
