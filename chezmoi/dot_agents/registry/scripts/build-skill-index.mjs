#!/usr/bin/env node
import { promises as fs } from "node:fs";
import path from "node:path";

const HOME = process.env.HOME;
const roots = [
  path.join(HOME, ".agents/skills"),
  path.join(HOME, ".codex/skills"),
  path.join(HOME, ".codex/plugins/cache"),
];
const codexConfigPath = path.join(HOME, ".codex/config.toml");
const claudeMcpPath = path.join(HOME, ".claude/mcp.json");
const outDir = path.join(HOME, ".agents/registry");
const outJson = path.join(outDir, "skill-index.json");
const outMd = path.join(outDir, "skill-index.md");
const legacyOutDir = path.join(HOME, ".codex/agent-system-ops/routing");
const legacyOutJson = path.join(legacyOutDir, "skill-index.json");
const legacyOutMd = path.join(legacyOutDir, "skill-index.md");

const skipDirs = new Set([
  ".git",
  "node_modules",
  "__pycache__",
  ".venv",
  "venv",
  ".cache",
  "dist",
  "build",
]);

const capabilityDescriptions = {
  "capability-planning-gate": {
    type: "workflow",
    name: "Capability Planning Gate",
    description: "Mandatory graph-first planning workflow before using Skills, plugins, MCP servers, agents, or workflows. It inspects the repository, queries Graphify, routes capabilities, and explains the selected plan.",
    domains: ["agentops", "planning"],
    cost_tier: "light",
  },
  "cheap-skill-router": {
    type: "workflow",
    name: "Cheap Capability Router",
    description: "Shared Claude/Codex capability routing workflow using build-skill-index, route-skills, and canonical registry quality signals.",
    domains: ["agentops", "planning"],
    cost_tier: "light",
  },
  "capability-system-graph": {
    type: "workflow",
    name: "Capability System Graph",
    description: "Focused Graphify map of the Claude/Codex capability-selection system. Use before broad reads to find exact rules, scripts, and relationships cheaply.",
    domains: ["agentops", "graph"],
    cost_tier: "light",
  },
  github: {
    type: "mcp",
    name: "GitHub MCP",
    description: "Read GitHub repositories, issues, pull requests, files, commits, and reviews. Use for repo inspection, PR review, issue triage, and GitHub evidence.",
    domains: ["code", "agentops"],
    cost_tier: "medium",
  },
  context7: {
    type: "mcp",
    name: "Context7 MCP",
    description: "Fetch up-to-date official library documentation and code examples. Use before implementing against current APIs, SDKs, and framework versions.",
    domains: ["docs", "code"],
    cost_tier: "medium",
  },
  exa: {
    type: "mcp",
    name: "Exa MCP",
    description: "Neural web search and page fetch. Use for current web research, source discovery, company/person lookup, and fresh external evidence.",
    domains: ["research", "web"],
    cost_tier: "medium",
  },
  memory: {
    type: "mcp",
    name: "Memory MCP",
    description: "Local cross-session memory. Use to recall past decisions, previous project context, known bugs, and durable preferences.",
    domains: ["agentops", "memory"],
    cost_tier: "light",
  },
  agentmemory: {
    type: "mcp",
    name: "Agent Memory MCP",
    description: "Semantic memory across sessions. Use to find prior observations, decisions, and patterns without loading old chats.",
    domains: ["agentops", "memory"],
    cost_tier: "light",
  },
  playwright: {
    type: "mcp",
    name: "Playwright MCP",
    description: "Browser automation with DOM snapshots, clicks, forms, screenshots, console, and network inspection. Use for E2E, QA, and local web app verification.",
    domains: ["web", "testing"],
    cost_tier: "medium",
  },
  "sequential-thinking": {
    type: "mcp",
    name: "Sequential Thinking MCP",
    description: "Structured step-by-step reasoning support. Use for complex planning, decomposition, and decision audits when the plan itself is risky.",
    domains: ["planning", "agentops"],
    cost_tier: "medium",
  },
  codegraph: {
    type: "mcp",
    name: "Codegraph MCP",
    description: "Code relationship graph and dependency navigation. Use after repository scan for cross-file impact tracing, call graphs, and architecture mapping.",
    domains: ["code", "graph"],
    cost_tier: "medium",
  },
  node_repl: {
    type: "mcp",
    name: "Node REPL MCP",
    description: "Persistent JavaScript execution. Use for quick JS probes, data transforms, package inspection, and small generated artifacts.",
    domains: ["code", "data"],
    cost_tier: "light",
  },
  "firecrawl-mcp": {
    type: "mcp",
    name: "Firecrawl MCP",
    description: "Web search, scrape, map, crawl, and clean markdown extraction. Use for multi-page research and structured web evidence collection.",
    domains: ["research", "web"],
    cost_tier: "medium",
  },
  "scrapegraph-mcp": {
    type: "mcp",
    name: "ScrapeGraph MCP",
    description: "Prompt-driven structured extraction from web pages. Use when the desired output is JSON fields from messy pages.",
    domains: ["research", "data", "web"],
    cost_tier: "medium",
  },
  documents: {
    type: "plugin",
    name: "Documents Plugin",
    description: "Create and edit document artifacts, Word files, and Google Docs-ready material.",
    domains: ["docs"],
    cost_tier: "medium",
  },
  spreadsheets: {
    type: "plugin",
    name: "Spreadsheets Plugin",
    description: "Create, edit, analyze, visualize, render, and export spreadsheets or Google Sheets-ready workbooks.",
    domains: ["data", "finance"],
    cost_tier: "medium",
  },
  presentations: {
    type: "plugin",
    name: "Presentations Plugin",
    description: "Create, edit, render, verify, and export presentation decks and PowerPoint files.",
    domains: ["slides", "docs"],
    cost_tier: "medium",
  },
  browser: {
    type: "plugin",
    name: "Browser Plugin",
    description: "Codex in-app browser for opening, inspecting, navigating, testing, clicking, typing, and screenshots.",
    domains: ["web", "testing"],
    cost_tier: "medium",
  },
  caveman: {
    type: "plugin",
    name: "Caveman Plugin",
    description: "Terse agent-to-user communication style. Use to keep replies short, accurate, and low-filler.",
    domains: ["comms"],
    cost_tier: "light",
  },
};

function uniq(values) {
  return [...new Set(values.filter(Boolean))];
}

function stripYamlQuotes(value) {
  return value.replace(/^['"]|['"]$/g, "").trim();
}

function parseFrontmatter(text) {
  if (!text.startsWith("---\n")) return {};
  const end = text.indexOf("\n---", 4);
  if (end === -1) return {};
  const fm = {};
  for (const line of text.slice(4, end).split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) continue;
    fm[m[1]] = stripYamlQuotes(m[2] || "");
  }
  return fm;
}

function firstParagraph(text) {
  const body = text.replace(/^---[\s\S]*?---\s*/m, "");
  for (const block of body.split(/\n\s*\n/)) {
    const s = block
      .split(/\r?\n/)
      .filter((line) => !line.trim().startsWith("#"))
      .join(" ")
      .replace(/\s+/g, " ")
      .trim();
    if (s.length > 25) return s.slice(0, 360);
  }
  return "";
}

function headings(text) {
  return text
    .split(/\r?\n/)
    .filter((line) => /^#{1,3}\s+\S/.test(line))
    .slice(0, 8)
    .map((line) => line.replace(/^#{1,3}\s+/, "").trim());
}

function keywordsFor(record) {
  const source = [
    record.id,
    record.name,
    record.description,
    record.path,
    ...record.headings,
  ]
    .join(" ")
    .toLowerCase();
  const words = source.match(/[a-zа-я0-9][a-zа-я0-9_.-]{2,}/giu) || [];
  const stop = new Set([
    "the",
    "and",
    "for",
    "with",
    "from",
    "что",
    "как",
    "для",
    "или",
    "это",
    "при",
    "над",
    "через",
    "skill",
    "skills",
    "агент",
    "скилл",
  ]);
  return uniq(words.filter((w) => !stop.has(w))).slice(0, 40);
}

async function walk(dir, files = []) {
  let entries;
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch {
    return files;
  }
  for (const entry of entries) {
    if (entry.name.startsWith(".") && entry.name !== ".system") continue;
    if (entry.isDirectory()) {
      if (skipDirs.has(entry.name)) continue;
      await walk(path.join(dir, entry.name), files);
    } else if (entry.name === "SKILL.md") {
      files.push(path.join(dir, entry.name));
    }
  }
  return files;
}

function capabilityRecord(id, source, configPath) {
  const meta = capabilityDescriptions[id] || capabilityDescriptions[id.replace(/@.*$/, "")] || {};
  const record = {
    id,
    type: meta.type || source,
    name: meta.name || id,
    description: meta.description || `${source.toUpperCase()} capability from local configuration.`,
    path: configPath,
    root: source,
    model: "",
    cost_tier: meta.cost_tier || "",
    allowed_tools: "",
    domains: meta.domains || [],
    headings: [source.toUpperCase(), "Local capability"],
    updated_at: new Date().toISOString(),
  };
  record.keywords = keywordsFor(record);
  return record;
}

async function configuredCapabilities() {
  const records = [];

  try {
    const config = await fs.readFile(codexConfigPath, "utf8");
    for (const match of config.matchAll(/^\[mcp_servers\.([^\]]+)\]/gm)) {
      records.push(capabilityRecord(match[1].replace(/^"|"$/g, ""), "mcp", codexConfigPath));
    }
    for (const match of config.matchAll(/^\[plugins\."([^"]+)"\]/gm)) {
      const pluginId = match[1].split("@")[0];
      records.push(capabilityRecord(pluginId, "plugin", codexConfigPath));
    }
  } catch {
    // Optional config.
  }

  try {
    const data = JSON.parse(await fs.readFile(claudeMcpPath, "utf8"));
    for (const id of Object.keys(data.mcpServers || {})) {
      records.push(capabilityRecord(id, "mcp", claudeMcpPath));
    }
  } catch {
    // Optional config.
  }

  return records;
}

async function workflowCapabilities() {
  const specs = [
    ["capability-planning-gate", path.join(HOME, ".agents/registry/CAPABILITY-PLANNING.md")],
    ["cheap-skill-router", path.join(HOME, ".agents/registry/scripts/route-skills.mjs")],
    ["capability-system-graph", path.join(HOME, ".agents/registry/capability-system-graph/graphify-out/graph.json")],
  ];
  const records = [];
  for (const [id, file] of specs) {
    if (await fs.access(file).then(() => true).catch(() => false)) {
      records.push(capabilityRecord(id, "workflow", file));
    }
  }
  return records;
}

const skillFiles = uniq((await Promise.all(roots.map((root) => walk(root)))).flat()).sort();
const records = [];

for (const file of skillFiles) {
  let text;
  try {
    text = await fs.readFile(file, "utf8");
  } catch {
    continue;
  }
  const fm = parseFrontmatter(text);
  const dir = path.dirname(file);
  const id = path.basename(dir);
  const record = {
    id,
    type: "skill",
    name: fm.name || id,
    description: fm.description || firstParagraph(text),
    path: file,
    root: roots.find((root) => file.startsWith(root)) || "",
    model: fm.model || "",
    cost_tier: fm.cost_tier || fm.weight || "",
    allowed_tools: fm["allowed-tools"] || fm.allowed_tools || "",
    headings: headings(text),
    updated_at: new Date().toISOString(),
  };
  record.keywords = keywordsFor(record);
  records.push(record);
}

for (const record of await configuredCapabilities()) {
  records.push(record);
}

for (const record of await workflowCapabilities()) {
  records.push(record);
}

const dedupedRecords = [];
const seenRecords = new Set();
for (const record of records) {
  const key = `${record.type}:${record.id}:${record.path}`;
  if (seenRecords.has(key)) continue;
  seenRecords.add(key);
  dedupedRecords.push(record);
}
records.length = 0;
records.push(...dedupedRecords);

await fs.mkdir(outDir, { recursive: true });
await fs.mkdir(legacyOutDir, { recursive: true }).catch(() => {});
const jsonPayload = JSON.stringify(
  {
    generated_at: new Date().toISOString(),
      count: records.length,
      skill_count: records.filter((record) => record.type === "skill").length,
      mcp_count: records.filter((record) => record.type === "mcp").length,
      plugin_count: records.filter((record) => record.type === "plugin").length,
      roots,
    records,
  },
  null,
  2,
);
await fs.writeFile(outJson, jsonPayload);
await fs.writeFile(legacyOutJson, jsonPayload).catch(() => {});

const byRoot = new Map();
for (const record of records) {
  byRoot.set(record.root, (byRoot.get(record.root) || 0) + 1);
}
const md = [
  "# Cheap Skill Index",
  "",
  `Generated: ${new Date().toISOString()}`,
  `Capabilities: ${records.length}`,
  `Skills: ${records.filter((record) => record.type === "skill").length}`,
  `MCP: ${records.filter((record) => record.type === "mcp").length}`,
  `Plugins: ${records.filter((record) => record.type === "plugin").length}`,
  "",
  "## Roots",
  ...[...byRoot.entries()].map(([root, count]) => `- ${root}: ${count}`),
  "",
  "## Use",
  "",
  "Run:",
  "",
  "```bash",
  `node ${HOME}/.agents/registry/scripts/route-skills.mjs "task text" --limit 7`,
  "```",
  "",
  "Read full SKILL.md only for selected candidates.",
  "",
].join("\n");
await fs.writeFile(outMd, md);
await fs.writeFile(legacyOutMd, md).catch(() => {});

console.log(`indexed ${records.length} capabilities`);
console.log(outJson);
