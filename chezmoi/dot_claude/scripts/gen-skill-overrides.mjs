#!/usr/bin/env node
// Thin-session: regenerate `skillOverrides` in ~/.claude/settings.local.json.
//
// Every personal skill under ~/.claude/skills EXCEPT the allowlist is set to
// "user-invocable-only" — hidden from the model's skill listing (≈0 injected
// tokens) but still invocable by the user via /name, and still Read-able by the
// athena-research router. Allowlist skills are OMITTED from the map, so they
// fall through to the default "on" (model-auto-invocable) — a typo here can
// never force a needed skill off.
//
// Idempotent + machine-portable: it derives the set from THIS machine's FS, so
// it is safe to ship via chezmoi and re-run anywhere. Re-run after adding skills.
//
//   node ~/.claude/scripts/gen-skill-overrides.mjs
//
import { promises as fs } from "node:fs";
import path from "node:path";

const HOME = process.env.HOME;
const SKILLS = path.join(HOME, ".claude/skills");
const SETTINGS = path.join(HOME, ".claude/settings.local.json");

// Kept model-auto-invocable (constitution lifecycle + cross-referenced + router).
// caveman/ponytail are PLUGINS (separate visibility) — not listed here.
const ALLOWLIST = new Set([
  "athena-research",   // the router itself — entry point, must stay visible
  "mnemazina",         // daily knowledge pipeline, model-invoked by name
  "self-learning",     // constitution checkpoint
  "handoff",           // constitution checkpoint
  "organize",          // constitution structure workflow
  "grill-me",          // constitution new-work workflow
  "codex",             // cross-harness handoff, referenced
  "humanizer",         // constitution: apply every response (UI strings)
  "humanizer-ru",      // constitution: apply to RU text
  "humanizer-en",      // constitution: apply to EN text
  "skill-creator",     // model creates skills on request
  "bootstrap-project", // constitution new-project workflow
]);

// Collect skill ids = basename of any dir (<=2 deep under SKILLS) holding SKILL.md.
// Depth 2 covers top-level skills/<id> and one grouping level skills/<grp>/<id>.
async function findSkillIds(root, depth, ids) {
  let entries;
  try {
    entries = await fs.readdir(root, { withFileTypes: true });
  } catch {
    return ids;
  }
  if (entries.some((e) => e.isFile() && e.name === "SKILL.md")) ids.add(path.basename(root));
  if (depth > 0) {
    for (const e of entries) {
      if (e.isDirectory() && !e.name.startsWith(".") && e.name !== "node_modules") {
        await findSkillIds(path.join(root, e.name), depth - 1, ids);
      }
    }
  }
  return ids;
}

const ids = [...(await findSkillIds(SKILLS, 2, new Set()))].sort();
const overrides = {};
for (const id of ids) {
  if (!ALLOWLIST.has(id)) overrides[id] = "user-invocable-only";
}

let settings = {};
try {
  settings = JSON.parse(await fs.readFile(SETTINGS, "utf8"));
} catch {
  /* fresh file */
}
settings.skillOverrides = overrides;
await fs.writeFile(SETTINGS, JSON.stringify(settings, null, 2) + "\n");

const present = [...ALLOWLIST].filter((i) => ids.includes(i));
const missing = [...ALLOWLIST].filter((i) => !ids.includes(i));
console.log(`skills on disk: ${ids.length}`);
console.log(`hidden (user-invocable-only): ${Object.keys(overrides).length}`);
console.log(`allowlist present (stays on): ${present.length} -> ${present.join(", ")}`);
console.log(`allowlist MISSING on disk: ${missing.join(", ") || "(none)"}`);
console.log(`wrote ${SETTINGS}`);
