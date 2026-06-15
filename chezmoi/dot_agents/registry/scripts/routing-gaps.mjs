#!/usr/bin/env node
// Surface standing capability gaps from the auto-captured routing log.
//
// Reads ~/.claude/references/routing-auto.log (TSV: date, cwd, level, top, route_score, task)
// written by capability-plan.mjs --log on weak/none matches. Buckets rows by task signature;
// a signature seen >= MIN times is a STANDING GAP worth filling proactively (find + vet + adopt)
// instead of falling back to the external ecosystem every single time.
//
// Silent (no output, exit 0) when there are no standing gaps — safe to wire into a
// SessionStart hook once the log has accumulated data.
//
// Usage: node routing-gaps.mjs            (GAP_MIN env overrides the >=2 threshold)

import { promises as fs } from "node:fs";
import path from "node:path";

const HOME = process.env.HOME;
const LOG = path.join(HOME, ".claude/references/routing-auto.log");
const MIN = Number(process.env.GAP_MIN || 2);
const STOP = new Set([
  "the","a","an","for","with","and","to","of","in","on","my","me","that","this",
  "is","be","it","how","do","i","using","use","from","new","app","code","please",
]);

function signature(task) {
  return [...new Set(
    task.toLowerCase()
      .replace(/[^0-9a-zа-яё\s-]/gi, " ")
      .split(/\s+/)
      .filter((w) => w.length > 3 && !STOP.has(w)),
  )].sort().slice(0, 6).join(" ");
}

let raw = "";
try {
  raw = await fs.readFile(LOG, "utf8");
} catch {
  process.exit(0); // no log yet -> nothing to report
}

const groups = new Map();
for (const line of raw.split("\n")) {
  if (!line.trim()) continue;
  const [date, , level, , , ...rest] = line.split("\t");
  const task = rest.join("\t");
  const sig = signature(task || "");
  if (!sig) continue;
  if (!groups.has(sig)) groups.set(sig, { n: 0, last: "", sample: task, levels: {} });
  const g = groups.get(sig);
  g.n += 1;
  if ((date || "") > g.last) g.last = date || "";
  g.levels[level] = (g.levels[level] || 0) + 1;
}

const gaps = [...groups.values()]
  .filter((g) => g.n >= MIN)
  .sort((a, b) => b.n - a.n);

if (!gaps.length) process.exit(0); // silent when nothing actionable

console.log(`Standing capability gaps (weak/none local matches seen >= ${MIN}x):`);
for (const g of gaps.slice(0, 15)) {
  const lv = Object.entries(g.levels).map(([k, v]) => `${k}:${v}`).join(",");
  console.log(`- ${g.n}x  [${lv}]  "${(g.sample || "").slice(0, 60)}"  (last ${g.last})`);
}
console.log("Fill these: find + vet (mcp-scan) + adopt -> they become Tier-0 local hits, gap closes.");
