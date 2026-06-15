#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const DEFAULT_LIMIT = 200;
const TARGET_NAMES = new Set(["AGENTS.md", "CLAUDE.md"]);
const SKIP_DIRS = new Set([
  ".git",
  "node_modules",
  ".next",
  "dist",
  "build",
  ".venv",
  "venv",
  "__pycache__",
  ".pytest_cache",
  ".mypy_cache",
  ".ruff_cache",
  ".cache",
  "sessions",
  "file-history",
  "backups",
  "archive",
  "skills",
  "plugins",
  "cache",
  "marketplaces",
  "capability-system-graph",
  "graphify-out",
]);

function argValue(name, fallback = null) {
  const i = process.argv.indexOf(name);
  if (i === -1 || i + 1 >= process.argv.length) return fallback;
  return process.argv[i + 1];
}

function hasFlag(name) {
  return process.argv.includes(name);
}

function real(p) {
  return path.resolve(p.replace(/^~(?=$|\/)/, os.homedir()));
}

function countLines(file) {
  const text = fs.readFileSync(file, "utf8");
  if (!text) return 0;
  return text.endsWith("\n") ? text.split("\n").length - 1 : text.split("\n").length;
}

function shouldSkipDir(dir) {
  const base = path.basename(dir);
  if (SKIP_DIRS.has(base)) return true;
  if (dir.includes(`${path.sep}.codex${path.sep}sessions${path.sep}`)) return true;
  if (dir.includes(`${path.sep}.claude${path.sep}projects${path.sep}`)) return true;
  if (dir.includes(`${path.sep}.agents${path.sep}skills${path.sep}`)) return true;
  if (dir.includes(`${path.sep}.codex${path.sep}skills${path.sep}`)) return true;
  if (dir.includes(`${path.sep}.claude${path.sep}skills${path.sep}`)) return true;
  if (dir.includes(`${path.sep}.codex${path.sep}plugins${path.sep}`)) return true;
  if (dir.includes(`${path.sep}.claude${path.sep}plugins${path.sep}`)) return true;
  return false;
}

function walk(root, out) {
  let entries = [];
  try {
    entries = fs.readdirSync(root, { withFileTypes: true });
  } catch {
    return;
  }
  for (const ent of entries) {
    const p = path.join(root, ent.name);
    if (ent.isDirectory()) {
      if (!shouldSkipDir(p)) walk(p, out);
    } else if (ent.isFile() && TARGET_NAMES.has(ent.name)) {
      out.add(p);
    }
  }
}

function collectFiles(roots, includeGlobal) {
  const out = new Set();
  for (const root of roots) {
    const p = real(root);
    if (!fs.existsSync(p)) continue;
    const stat = fs.statSync(p);
    if (stat.isFile() && TARGET_NAMES.has(path.basename(p))) out.add(p);
    if (stat.isDirectory()) walk(p, out);
  }
  if (includeGlobal) {
    for (const p of [
      "~/AGENTS.md",
      "~/.codex/AGENTS.md",
      "~/.claude/AGENTS.md",
      "~/.claude/CLAUDE.md",
    ]) {
      const rp = real(p);
      if (fs.existsSync(rp)) out.add(rp);
    }
  }
  return [...out].sort();
}

const limit = Number(argValue("--limit", String(DEFAULT_LIMIT)));
const roots = [];
for (let i = 2; i < process.argv.length; i += 1) {
  if (process.argv[i] === "--root" && process.argv[i + 1]) {
    roots.push(process.argv[i + 1]);
    i += 1;
  }
}
if (!roots.length) roots.push(process.cwd());

const includeGlobal = !hasFlag("--no-global");
const files = collectFiles(roots, includeGlobal);
const rows = files.map((file) => ({ file, lines: countLines(file) }));
const failures = rows.filter((r) => r.lines > limit);

for (const r of rows) {
  const mark = r.lines > limit ? "FAIL" : "OK";
  console.log(`${mark}\t${r.lines}\t${r.file}`);
}

if (failures.length) {
  console.error(`\nInstruction budget failed: ${failures.length} file(s) over ${limit} lines.`);
  process.exit(1);
}

console.log(`\nInstruction budget ok: ${rows.length} file(s), limit ${limit}.`);
