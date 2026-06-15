#!/usr/bin/env node
import { promises as fs } from "node:fs";
import path from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const HOME = process.env.HOME;
const graphPath = path.join(HOME, ".agents/registry/capability-system-graph/graphify-out/graph.json");
const routerPath = path.join(HOME, ".agents/registry/scripts/route-skills.mjs");

// Local-first cascade gate. Top finalist must clear this route_score floor to count
// as a "strong" local hit; below it, --external-fallback emits a discovery step so the
// arsenal can grow instead of recycling the same skills.
// Calibrated 2026-06-13: HAVE matches scored 148-351, MISS 77-130 -> floor 140.
// Override per-run via env CAP_FALLBACK_FLOOR.
const FALLBACK_FLOOR = Number(process.env.CAP_FALLBACK_FLOOR || 140);

function usage() {
  console.error('Usage: capability-plan.mjs "task text" [--cwd PATH] [--limit N] [--json] [--external-fallback] [--log]');
  process.exit(2);
}

const args = process.argv.slice(2);
if (!args.length) usage();

let task = "";
let cwd = process.cwd();
let limit = 10;
let jsonOut = false;
let externalFallback = false;
let logWeak = false;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === "--cwd") {
    cwd = args[++i] || cwd;
  } else if (arg === "--limit") {
    limit = Number(args[++i] || "10");
  } else if (arg === "--json") {
    jsonOut = true;
  } else if (arg === "--external-fallback") {
    externalFallback = true;
  } else if (arg === "--log") {
    logWeak = true;
  } else if (!task) {
    task = arg;
  } else {
    task += ` ${arg}`;
  }
}
task = task.trim();
if (!task) usage();

async function exists(file) {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
}

async function run(command, args, options = {}) {
  try {
    const result = await execFileAsync(command, args, {
      cwd,
      timeout: options.timeout || 15000,
      maxBuffer: options.maxBuffer || 1024 * 1024,
    });
    return { ok: true, stdout: result.stdout.trim(), stderr: result.stderr.trim() };
  } catch (error) {
    return {
      ok: false,
      stdout: String(error.stdout || "").trim(),
      stderr: String(error.stderr || error.message || "").trim(),
    };
  }
}

async function findUp(names, start) {
  const found = [];
  let current = path.resolve(start);
  for (;;) {
    for (const name of names) {
      const file = path.join(current, name);
      if (await exists(file)) found.push(file);
    }
    const parent = path.dirname(current);
    if (parent === current || current === HOME) break;
    current = parent;
  }
  return found;
}

async function scanFilesNative(root, maxDepth = 3, maxFiles = 3000) {
  const skip = new Set([
    ".git",
    "node_modules",
    "Library",
    "session-env",
    "sessions",
    "cache",
    ".cache",
    "Caches",
  ]);
  const files = [];
  async function visit(dir, depth) {
    if (files.length >= maxFiles || depth > maxDepth) return;
    let entries = [];
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (files.length >= maxFiles) break;
      if (entry.isDirectory()) {
        if (skip.has(entry.name)) continue;
        await visit(path.join(dir, entry.name), depth + 1);
      } else if (entry.isFile()) {
        files.push(path.relative(root, path.join(dir, entry.name)) || entry.name);
      }
    }
  }
  await visit(path.resolve(root), 0);
  return files;
}

async function listProjectSignals() {
  const rules = await findUp(["AGENTS.md", "CLAUDE.md", "claud.md"], cwd);
  const rg = await run("rg", [
    "--files",
    "--hidden",
    "-g", "!**/.git/**",
    "-g", "!**/node_modules/**",
    "-g", "!**/Library/**",
    "-g", "!**/session-env/**",
    "-g", "!**/sessions/**",
    "-g", "!**/cache/**",
    "-g", "!**/.cache/**",
  ], { timeout: 10000, maxBuffer: 2 * 1024 * 1024 });
  let files = rg.ok ? rg.stdout.split(/\r?\n/).filter(Boolean) : [];
  if (!files.length) files = await scanFilesNative(cwd);
  const configPatterns = /(^|\/)(package\.json|pnpm-lock\.yaml|yarn\.lock|requirements\.txt|pyproject\.toml|Cargo\.toml|go\.mod|deno\.json|vite\.config\.[jt]s|next\.config\.[jm]s|tsconfig\.json|README\.md)$/;
  const configs = files
    .filter((file) => configPatterns.test(file))
    .filter((file) => !/\.agents\/skills\/[^/]+\/README\.md$/.test(file))
    .slice(0, 18);
  const tests = files.filter((file) => /(^|\/)(test|tests|spec|__tests__)\/|(\.test|\.spec)\.[jt]sx?$/.test(file)).slice(0, 12);
  const graph = await findUp(["graphify-out/graph.json"], cwd);
  return {
    cwd,
    rules: rules.slice(0, 8),
    file_count: files.length,
    configs,
    tests,
    local_graphs: graph.slice(0, 5),
  };
}

function trimGraphOutput(text) {
  return text
    .split(/\r?\n/)
    .filter((line) => /^(NODE|EDGE|Traversal|Start:|NODE |EDGE )/.test(line) || line.includes("src="))
    .slice(0, 36)
    .join("\n")
    .slice(0, 3600);
}

async function graphQueries() {
  if (!(await exists(graphPath))) return [];
  const questions = [
    `For this task, what capability planning rules and files should be consulted first? Task: ${task}`,
    `Which Skill plugin MCP capability families are relevant to this task? Task: ${task}`,
    `What is the fastest cheap path from root contract to route-skills and selected capabilities? Task: ${task}`,
  ];
  const outputs = [];
  for (const question of questions) {
    const res = await run("graphify", ["query", question, "--graph", graphPath, "--budget", "900"], {
      timeout: 12000,
      maxBuffer: 512 * 1024,
    });
    outputs.push({
      question,
      ok: res.ok,
      excerpt: trimGraphOutput(res.stdout || res.stderr),
    });
  }
  return outputs;
}

async function routeCapabilities() {
  const res = await run("node", [routerPath, task, "--limit", String(limit), "--json"], {
    timeout: 15000,
    maxBuffer: 2 * 1024 * 1024,
  });
  if (!res.ok) return { ok: false, error: res.stderr || res.stdout };
  try {
    return { ok: true, ...JSON.parse(res.stdout) };
  } catch {
    return { ok: false, error: "router returned invalid JSON", raw: res.stdout };
  }
}

function choose(results = []) {
  const selected = [];
  const byType = new Map();
  for (const result of results) {
    const type = result.type || "skill";
    if (!byType.has(type)) byType.set(type, result);
  }
  for (const type of ["skill", "mcp", "plugin", "agent"]) {
    if (byType.has(type)) selected.push(byType.get(type));
  }
  for (const result of results) {
    if (selected.length >= 5) break;
    if (!selected.some((item) => item.id === result.id && item.type === result.type)) selected.push(result);
  }
  return selected;
}

function reasonFor(record) {
  const parts = [];
  if (record.domains?.length) parts.push(`domains=${record.domains.join("/")}`);
  if (record.registry_score) parts.push(`registry=${record.registry_score}`);
  if (record.usage_count) parts.push(`usage=${record.usage_count}`);
  if (record.stars) parts.push(`stars=${record.stars}`);
  if (record.cost_tier) parts.push(`cost=${record.cost_tier}`);
  return parts.length ? parts.join(", ") : "direct route fit";
}

// Decide whether the best local finalist is a strong enough hit to stop here, or
// whether the cascade should widen to the external ecosystem (gated discovery).
function assessLocal(items = []) {
  const top = items[0];
  if (!top) {
    return { level: "none", floor: FALLBACK_FLOOR, reason: "no local candidate with route_score>0" };
  }
  const route = Number(top.route_score || 0);
  const lex = Number(top.lexical_score || 0);
  if (route < FALLBACK_FLOOR) {
    return { level: "weak", floor: FALLBACK_FLOOR, top: top.name, route_score: route,
      reason: `top "${top.name}" route_score=${route} < floor ${FALLBACK_FLOOR}` };
  }
  if (lex <= 0) {
    return { level: "weak", floor: FALLBACK_FLOOR, top: top.name, route_score: route,
      reason: `top "${top.name}" is popularity-only (lexical_score=0, no term overlap)` };
  }
  return { level: "strong", floor: FALLBACK_FLOOR, top: top.name, route_score: route,
    reason: `top "${top.name}" route_score=${route} lexical=${lex}` };
}

// Read-only external discovery recipe (no execution here — the agent runs it visibly).
function externalDiscovery(taskText) {
  const terms = taskText.toLowerCase().split(/\s+/).filter((t) => t.length > 2).slice(0, 6).join(" ");
  return {
    trigger: "local match below floor — widen to external skills ecosystem",
    search_command: `npx skills find "${terms}"`,
    safety: "READ-ONLY discovery. Before install: read SKILL.md + run `uvx mcp-scan@latest --skills` + explicit user approval. Never `add -y` or blind `-g`.",
    after_adopt: "register in SHARED-SKILLS-WORKFLOWS.md + rebuild index (build-skill-index.mjs) + /graphify, so next run resolves it locally (Tier-0). This is the growth loop.",
  };
}

const [repo, graph, routed] = await Promise.all([
  listProjectSignals(),
  graphQueries(),
  routeCapabilities(),
]);

const results = routed.ok ? routed.results || [] : [];
const selected = choose(results);
const skipped = results
  .filter((record) => !selected.some((item) => item.id === record.id && item.type === record.type))
  .slice(0, 4);

const localMatch = assessLocal(selected);

const report = {
  task,
  repo,
  graph,
  routed,
  selected,
  skipped,
  local_match: localMatch,
};

if (externalFallback && localMatch.level !== "strong") {
  report.external_fallback = externalDiscovery(task);
}

// Auto-capture weak/none matches so the self-learning loop needs no discipline.
if (logWeak && localMatch.level !== "strong") {
  try {
    const stamp = new Date().toISOString().slice(0, 10);
    const row = [stamp, cwd, localMatch.level, localMatch.top || "-", localMatch.route_score || 0, task]
      .join("\t") + "\n";
    await fs.appendFile(path.join(HOME, ".claude/references/routing-auto.log"), row);
  } catch {}
}

if (jsonOut) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log("Capability preflight");
  console.log(`Task: ${task}`);
  console.log("");
  console.log("Repo signal:");
  console.log(`- cwd: ${repo.cwd}`);
  console.log(`- files: ${repo.file_count}`);
  if (repo.rules.length) console.log(`- rules: ${repo.rules.map((file) => path.basename(file)).join(", ")}`);
  if (repo.configs.length) console.log(`- configs: ${repo.configs.slice(0, 8).join(", ")}`);
  if (repo.tests.length) console.log(`- tests: ${repo.tests.slice(0, 5).join(", ")}`);
  if (repo.local_graphs.length) console.log(`- local graphs: ${repo.local_graphs.join(", ")}`);
  console.log("");
  console.log("Graph signal:");
  if (!graph.length) {
    console.log("- no capability graph found");
  } else {
    for (const item of graph) {
      const firstNode = (item.excerpt.match(/^NODE .+$/m) || [""])[0].replace(/^NODE /, "");
      console.log(`- ${item.ok ? "ok" : "miss"}: ${firstNode || item.question.slice(0, 96)}`);
    }
  }
  console.log("");
  console.log("Capability plan:");
  console.log("- note: draft from graph + router; agent must refine before action");
  for (const item of selected) {
    console.log(`- use: ${item.name} [${item.type || "skill"}] — ${reasonFor(item)}`);
    if (item.path) console.log(`  source: ${item.path}`);
  }
  for (const item of skipped) {
    console.log(`- skip: ${item.name} [${item.type || "skill"}] — lower priority after selected finalists`);
  }
  console.log("");
  console.log(`Local match: ${localMatch.level} — ${localMatch.reason}`);
  if (report.external_fallback) {
    console.log("External fallback (local below floor):");
    console.log(`- search: ${report.external_fallback.search_command}`);
    console.log(`- safety: ${report.external_fallback.safety}`);
    console.log(`- after adopt: ${report.external_fallback.after_adopt}`);
  }
  console.log("- next: read/call only selected finalists, then execute task");
}
