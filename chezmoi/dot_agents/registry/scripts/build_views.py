#!/usr/bin/env python3
"""registry.jsonl -> INDEX.md + domains/<dom>.md shards + both REGISTRY.md (Tier-1).
Run after build_registry.py. Usage columns reflect registry (0 now)."""
import json, os
from collections import defaultdict

HOME = os.path.expanduser("~")
REG = f"{HOME}/.agents/registry"
DOMDIR = f"{REG}/domains"
CLA_OUT = f"{HOME}/.claude/capabilities/REGISTRY.md"
COD_OUT = f"{HOME}/.codex/capabilities/REGISTRY.md"

recs = [json.loads(l) for l in open(f"{REG}/registry.jsonl", encoding="utf-8") if l.strip()]
by_id = {r["id"]: r for r in recs}

PINNED = ["frontend-design","performance-optimization","accessibility","nothing-design",
          "threejs-animation","caveman","firecrawl-search","deep-research",
          "agent-capability-installer","dcf-model"]

def star(s):
    if not s: return "—"
    return f"{s/1000:.1f}k" if s >= 1000 else str(s)

def parity(r):
    m = {"installed":"✅","partial":"⚠","missing":"❌"}
    h = r.get("harness", {})
    return f'{m.get(h.get("claude"),"❓")}·{m.get(h.get("codex"),"❓")}'

# ---------- domain index ----------
dom = defaultdict(list)
for r in recs:
    for d in r["domains"]:
        dom[d].append(r)
dom_sorted = sorted(dom.items(), key=lambda kv: -len(kv[1]))

def domain_map_md():
    out = ["| domain | n | top by score | shard |", "|---|--:|---|---|"]
    for d, rs in dom_sorted:
        top = sorted(rs, key=lambda x: -x["score"])[:3]
        tops = " · ".join(f"{t['id']}({t['score']})" for t in top)
        out.append(f"| {d} | {len(rs)} | {tops} | `domains/{d}.md` |")
    return "\n".join(out)

# ---------- shards ----------
os.makedirs(DOMDIR, exist_ok=True)
for d, rs in dom.items():
    rows = ["# domain: " + d + f"  ({len(rs)} capabilities)",
            "", "> Tier-2 shard. Canonical: `../registry.jsonl`. Sorted by score.", "",
            "| id | type | purpose | model | wt | ★ | score | parity | ⟳C | ⟳X |",
            "|---|---|---|:--:|:--:|--:|--:|:--:|--:|--:|"]
    for r in sorted(rs, key=lambda x: (-x["score"], x["id"])):
        pur = (r["purpose"] or "").replace("|", "/")[:80]
        rows.append(f'| {r["id"]} | {r["type"]} | {pur} | {r.get("model","S")} | '
                    f'{r.get("cost_tier","medium")[0].upper()} | '
                    f'{star(r["stars"])} | {r["score"]} | {parity(r)} | '
                    f'{r["usage_count"]} | {r["usage_count"]} |')
    open(f"{DOMDIR}/{d}.md", "w", encoding="utf-8").write("\n".join(rows) + "\n")

# ---------- INDEX.md ----------
total = len(recs)
idx = f"""# Capability Index — domain map (Tier-1)

> Canonical DB: `registry.jsonl` ({total} capabilities). Per-domain detail: `domains/<dom>.md`.
> Selection: match task → domain here → open that shard → trigger/disambiguation → top score.

## Domains

{domain_map_md()}

## How to pick
1. Map task to domain(s) above.
2. Open `domains/<dom>.md` (Tier-2) — full list sorted by score.
3. Cross-cutting overlap? See REGISTRY.md §Disambiguation.
4. Open SKILL.md only for the 1-2 finalists (Tier-3).
"""
open(f"{REG}/INDEX.md", "w", encoding="utf-8").write(idx)

# ---------- shared static sections ----------
DISAMBIG = """## Disambiguation (overlap → pick this, not that)  [SHARED]

#1 selection error = wrong one of N similar. Resolve here first.

| task signal | PICK | NOT | why |
|---|---|---|---|
| find page/fact, pull content, one-shot | `firecrawl-search` | deep-research | search ≠ multi-source synthesis |
| investigate topic, compare options, cited report | `deep-research` | firecrawl-search | needs cross-source synth (firecrawl-search = sub-fetch) |
| build any distinctive UI | `frontend-design` | nothing-design | nothing-design = ONE brand aesthetic |
| explicitly want Nothing look (mono/industrial) | `nothing-design` | frontend-design | brand-specific override |
| page slow / CWV / bundle | `performance-optimization` | accessibility | perf axis ≠ a11y axis |
| keyboard/contrast/WCAG | `accessibility` | performance-optimization | different axis — often run BOTH |
| 3d motion in scene | `threejs-animation` | frontend-design | DOM build ≠ WebGL anim |

**skip-when:** `nothing-design` unless Nothing brand asked. `deep-research` for single-fact lookup (opus overkill)."""

CHAINS = """## Chains (pairs-with → pipeline)  [SHARED]

```
build web surface  : frontend-design → accessibility → performance-optimization
research → deliver : deep-research → firecrawl-search (gap-fill) → frontend-design
3d landing         : frontend-design + threejs-animation
any task (style)   : caveman wraps comms layer, orthogonal
```"""

TRIGGERS = """## Trigger index (keyword → skill)  [SHARED]

| keyword / phrase | → skill |
|---|---|
| search web · scrape · fetch page · crawl | firecrawl-search |
| deep research · investigate · compare options | deep-research |
| a11y · WCAG · contrast · screen reader | accessibility |
| CWV · LCP · slow · bundle size | performance-optimization |
| build UI · component · landing · page | frontend-design |
| Nothing · monochrome · industrial | nothing-design |
| 3d · GLTF · animate mesh · scene | threejs-animation |
| DCF · valuation · intrinsic value | dcf-model |
| install skill · mirror codex · catalog | agent-capability-installer |
| be brief · save tokens · caveman | caveman |"""

POLICY = """## 0 · Selection Policy — effectiveness per token for THIS project  [SHARED]

Goal: the **best product outcome per token**, not the cheapest pick. Choose what makes the product amazing — but right-sized, never more than the task actually needs.

**Decision (apply per candidate at selection time):**
```
value(skill | project, task) = eff × fit × right_size − switch_cost
pick = argmax value ; tie-break → lower cost_tier (more quality per token)
```
- **eff** = `score`/100 (quality-led effectiveness).
- **fit** ∈ 0..1 — project match: stack + domain + quality-bar alignment (read project CLAUDE.md/AGENTS.md). Wrong stack ≈ 0.2; exact stack+domain = 1.0.
- **right_size** — match skill `wt` (cost_tier) to task need:

  | task need ↓ \\ skill wt → | L light | M medium | H heavy |
  |---|:--:|:--:|:--:|
  | trivial / one-shot | 1.0 | 0.6 | 0.2 ⟵ overkill |
  | standard | 0.7 | 1.0 | 0.8 |
  | product-critical / hero | 0.5 | 0.9 | 1.0 |

- **switch_cost** — small penalty for adding a new tool when an in-flight one already suffices.

**Token-efficiency clause:** equal `eff×fit` → take lower `wt` (more quality per token). UNequal → **quality wins**: a 2× token skill that yields a materially better product beats the cheap one. Never sacrifice the product to save tokens.

**Anti-overkill clause:** don't escalate past the task. Single fact → `firecrawl-search`, not `deep-research`. One component tweak → not a whole design-system skill. Lightest capability that still clears the quality bar.

**Model tier by effectiveness-per-token** (replaces "always minimal-sufficient"):

| work | model | why |
|---|:--:|---|
| product-critical surface · hard synthesis · architecture · final pass | **Opus** | quality dominates; tokens cheap vs a worse product |
| standard build / analysis / code | **Sonnet** | best quality-per-token for most work |
| bulk / mechanical: grep, classify, format, sort, leaf-workers | **Haiku** | quality saturates → throughput & tokens dominate |"""

def provenance_md():
    out = ["## Provenance appendix (for UPDATE, not selection)  [SHARED]", "",
           "| id | source | repo | local upd | upstream push |", "|---|---|---|---|---|"]
    for pid in PINNED:
        r = by_id.get(pid, {})
        repo = f'[link]({r["repo_url"]})' if r.get("repo_url") else "—"
        out.append(f'| {pid} | {r.get("source") or "—"} | {repo} | '
                   f'{r.get("updated_at_local") or "—"} | — *(pending sync-stars)* |')
    return "\n".join(out)

# ---------- pinned selection table ----------
def pinned_table(primary):  # primary = 'C' or 'X'
    cu = "**⟳C**" if primary == "C" else "*⟳C*"
    xu = "*⟳X*" if primary == "C" else "**⟳X**"
    head = (f"| id | type | purpose · *use-when* | dom | model | wt | ★ | score | ✓% | parity | {cu} | {xu} |\n"
            "|---|---|---|---|:--:|:--:|--:|--:|:--:|:--:|--:|--:|")
    rows = []
    for pid in PINNED:
        r = by_id.get(pid)
        if not r: continue
        cw = f'**{r["usage_count"]}**' if primary == "C" else f'*{r["usage_count"]}*'
        xw = f'*{r["usage_count"]}*' if primary == "C" else f'**{r["usage_count"]}**'
        rows.append(f'| {pid} | {r["type"]} | {r["purpose"]} · *{r["use_when"]}* | '
                    f'{"·".join(r["domains"])} | {r.get("model","S")} | {r.get("cost_tier","medium")[0].upper()} | '
                    f'{star(r["stars"])} | {r["score"]} | — | {parity(r)} | {cw} | {xw} |')
    return head + "\n" + "\n".join(rows)

# ---------- assemble REGISTRY.md ----------
def registry_md(view):  # view = 'CLAUDE' or 'CODEX'
    me, sib = ("CLAUDE","Codex") if view=="CLAUDE" else ("CODEX","Claude")
    sibpath = (COD_OUT if view=="CLAUDE" else CLA_OUT)
    primary = "C" if view=="CLAUDE" else "X"
    auth = ("`⟳ Claude` = source of truth. `⟳ Codex` = mirror." if view=="CLAUDE"
            else "`⟳ Codex` = source of truth. `⟳ Claude` = mirror.")
    if view=="CLAUDE":
        split = ("  ├─ Claude step → bump ⟳C HERE\n  ├─ Codex step  → bump ⟳X in SIBLING")
    else:
        split = ("  ├─ Codex step  → bump ⟳X HERE\n  ├─ Claude step → bump ⟳C in SIBLING")
    return f"""# Capability Registry — {me} view  ⟢ you are here

> **Sibling ({sib}):** `{sibpath}`
> **Canonical DB:** `{REG}/registry.jsonl` ({total} capabilities) · **Domain map:** `{REG}/INDEX.md`

Selection order: **trigger-index → disambiguation → domain shard score**. This file = Tier-1 (pinned + maps); full lists in `domains/<dom>.md`.

---

## Interdependence rules (why two files)

1. **Install = shared** (one `.agents/.skill-lock.json` + mirrored skill dirs) → `parity C·X` identical both files.
2. **Usage = local.** Each harness counts own `⟳`. Edit **bold** column here; *italic* = mirror (edit in sibling).
3. **Split work → touch both.** Each harness logs its run in ITS OWN `⟳`. Shared field change (★/repo/purpose/parity/score/new skill) → SAME row to BOTH files, one commit.
4. **Parity guard.** `⚠`/`❌` on YOUR harness → install or route step to sibling.

**Authority here:** {auth}

---

## Legend
- **type** — skill · plugin · mcp · agent · command · rule · bundle
- **model** — tier by effectiveness-per-token: `O` opus (product-critical / hard synth) · `S` sonnet (standard build/analysis) · `H` haiku (bulk/mechanical). See Selection Policy.
- **wt** — cost_tier (run footprint): `L` light · `M` medium · `H` heavy → drives right-sizing
- **score** — EFFECTIVENESS 0-100, quality-led: `0.42·rating + 0.25·proven + 0.18·stars + 0.10·usage + 0.05·fresh` − penalty(parity⚠ −10, archived −30). NOT popularity. Final pick = score × project-fit × right-size (Selection Policy). Sort desc WITHIN domain.
- **★** stars = weak community-proof only · **✓%** success rate (n runs), empty until usage accrues
- **parity C·X** — ✅installed · ⚠partial · ❌missing (C=Claude, X=Codex)

---

{POLICY}

---

## 1 · Domain map ({total} total)  [SHARED]

Pick domain → open shard `{REG}/domains/<dom>.md` → score-sorted full list.

{domain_map_md()}

---

## 2 · Pinned selection table (curated examples, usage baseline 0)

{pinned_table(primary)}

---

{DISAMBIG}

---

{CHAINS}

---

{TRIGGERS}

---

{provenance_md()}

---

## Split-work protocol
```
task splits Claude ⇄ Codex
{split}
  └─ shared field (★/repo/purpose/parity/score/disambig/new skill) → BOTH files, one commit
```

## Auto-fill sources
| field | source | trigger |
|---|---|---|
| id,type,repo,path,installed,parity | `.agents/.skill-lock.json` + skill dirs | install → `build_registry.py` |
| ★, upstream push | `gh api` → `stars-cache.json` | weekly → `sync_stars.py` (needs gh) |
| ⟳, ✓%, last_used | `usage.log` (Skill hook) | per use → `build_registry.py` |
| purpose, use-when | `SKILL.md` frontmatter | build_registry |
| model, score | computed (legend formula) | build_registry |
| domains, rating, disambig | `overrides.jsonl` (manual) | by hand |

## Status / Pending
- [x] Domains refined: 29 precise domains, misc≈5
- [x] Usage hooks LIVE both harnesses (Claude + Codex PostToolUse `Skill` → usage.log)
- [x] Effectiveness scoring (quality-led) + §0 Selection Policy + cost_tier right-sizing
- [ ] Rate `effectiveness` on more skills (most default 3/5 — quality signal grows as you rate via overrides.jsonl)
- [ ] Outcome logging (success/fail) → real ✓% (hook logs invocation only now)
"""

os.makedirs(os.path.dirname(CLA_OUT), exist_ok=True)
os.makedirs(os.path.dirname(COD_OUT), exist_ok=True)
open(CLA_OUT, "w", encoding="utf-8").write(registry_md("CLAUDE"))
open(COD_OUT, "w", encoding="utf-8").write(registry_md("CODEX"))
print(f"INDEX.md + {len(dom)} shards + 2 REGISTRY.md written")
print("domains:", ", ".join(f"{d}({len(rs)})" for d,rs in dom_sorted[:14]))
