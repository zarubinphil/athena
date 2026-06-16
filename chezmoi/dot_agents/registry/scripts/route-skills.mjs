#!/usr/bin/env node
import { promises as fs } from "node:fs";
import path from "node:path";

const HOME = process.env.HOME;
const indexPath = `${HOME}/.agents/registry/skill-index.json`;
const legacyIndexPath = `${HOME}/.codex/agent-system-ops/routing/skill-index.json`;
const registryPath = `${HOME}/.agents/registry/registry.jsonl`;

function usage() {
  console.error('Usage: route-skills.mjs "task text" [--limit N] [--json]');
  process.exit(2);
}

const args = process.argv.slice(2);
if (!args.length) usage();

let query = "";
let limit = 7;
let jsonOut = false;
for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === "--limit") {
    limit = Number(args[++i] || "7");
  } else if (arg === "--json") {
    jsonOut = true;
  } else if (!query) {
    query = arg;
  } else {
    query += ` ${arg}`;
  }
}
if (!query.trim()) usage();

function terms(text) {
  return (text.toLowerCase().match(/[a-zа-я0-9][a-zа-я0-9_.-]{2,}/giu) || [])
    .map((w) => w.trim())
    .filter(Boolean);
}

function score(record, qTerms) {
  const reg = record.registry || {};
  const fields = {
    id: record.id || "",
    name: record.name || "",
    description: `${record.description || ""} ${reg.purpose || ""} ${reg.use_when || ""}`,
    headings: (record.headings || []).join(" "),
    keywords: (record.keywords || []).join(" "),
    path: `${record.path || ""} ${(reg.domains || record.domains || []).join(" ")}`,
  };
  let s = 0;
  for (const t of qTerms) {
    const esc = t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const re = new RegExp(`(^|[^a-zа-я0-9])${esc}($|[^a-zа-я0-9])`, "iu");
    if (re.test(fields.id.toLowerCase())) s += 18;
    if (re.test(fields.name.toLowerCase())) s += 16;
    if (re.test(fields.keywords.toLowerCase())) s += 8;
    if (re.test(fields.description.toLowerCase())) s += 6;
    if (re.test(fields.headings.toLowerCase())) s += 4;
    if (re.test(fields.path.toLowerCase())) s += 3;
  }
  const phrase = query.toLowerCase();
  if (`${fields.name} ${fields.description}`.toLowerCase().includes(phrase)) s += 20;
  return s;
}

let activeIndexPath = indexPath;
let index;
try {
  index = JSON.parse(await fs.readFile(indexPath, "utf8"));
} catch {
  activeIndexPath = legacyIndexPath;
  index = JSON.parse(await fs.readFile(legacyIndexPath, "utf8"));
}
let registry = new Map();
try {
  const lines = (await fs.readFile(registryPath, "utf8")).split(/\r?\n/).filter(Boolean);
  registry = new Map(lines.map((line) => {
    const record = JSON.parse(line);
    return [record.id, record];
  }));
} catch {
  registry = new Map();
}
const qTerms = [...new Set(terms(query))];

const overlays = [
  {
    when: /(front.?end|ui|ux|dashboard|responsive|layout|landing|component|accessibility|a11y|wcag|визуал|интерфейс|лендинг|адаптив)/iu,
    ids: ["frontend-builder", "frontend-design", "frontend-designer", "accessibility", "frontend-design-audit", "impeccable", "playwright", "browser"],
    domains: ["web", "design"],
    boost: 180,
  },
  {
    when: /(graphify|graph|knowledge graph|граф|графиф|obsidian|vault|knowledge base|база знаний)/iu,
    ids: ["capability-system-graph", "graphify", "gsd-graphify", "obsidian-vault", "knowledge-ops"],
    domains: ["agentops", "docs", "research"],
    boost: 180,
  },
  {
    when: /(capabilit|skill|plugin|mcp|router|routing|planning|preflight|selection|select|выбор|подбор|скилл|плагин|планирован|маршрут)/iu,
    ids: ["capability-planning-gate", "cheap-skill-router", "capability-system-graph", "graphify", "context7", "exa", "github", "memory", "agentmemory"],
    domains: ["agentops", "planning", "graph"],
    boost: 190,
  },
  {
    when: /(skill.?optimizer|skill.?miner|mine.*skill|skill candidate|candidate.*skill|repeated workflow|recurring workflow|session history|scan sessions|weekly skill|skill.?personalizer|personaliz.*skill|audit.*skill|skill audit|trigger.*skill|skill.?generalizer|generaliz.*skill|publish.*skill|скилл.?оптим|кандидат.*скилл|скилл.*кандидат|повторя.*воркфлоу|повторя.*workflow|аудит.*скилл|персонализ.*скилл)/iu,
    ids: ["skill-miner", "skill-personalizer", "skill-generalizer"],
    domains: ["skills"],
    boost: 360,
  },
  {
    when: /(research|compare|sources|reddit|hacker news|github|deep|исслед|сравн|источник)/iu,
    ids: ["deep-research", "firecrawl-deep-research", "firecrawl-search", "browse", "exa", "firecrawl-mcp", "scrapegraph-mcp", "github"],
    domains: ["research", "osint", "docs"],
    boost: 120,
  },
  {
    when: /(brief|terse|short|caveman|коротко|кратко|сжато)/iu,
    ids: ["caveman"],
    domains: ["comms"],
    boost: 160,
  },
  {
    when: /(dcf|valuation|intrinsic value|wacc|lbo|3-statement|financial model|sensitivity|оценк|финансов.*модел|дисконт)/iu,
    ids: ["dcf-model", "3-statement-model", "lbo-model", "merger-model", "returns-analysis"],
    domains: ["finance"],
    boost: 180,
  },
  {
    when: /(debug|bug|failing|error|broken|diagnos|fix|test|tdd|regression|trace|падает|ошибка|сломал|тест)/iu,
    ids: ["systematic-debugging", "diagnose", "tdd", "test-driven-development", "receiving-code-review", "verification-before-completion", "playwright", "codegraph", "github"],
    domains: ["devops", "testing"],
    boost: 170,
  },
  {
    when: /(docs|documentation|api|sdk|library|framework|version|release|next.js|react|supabase|документац|библиотек|фреймворк)/iu,
    ids: ["context7", "openai-docs", "docs-lookup", "firecrawl-search", "exa"],
    domains: ["docs", "code"],
    boost: 150,
  },
  {
    when: /(spreadsheet|excel|xls|google sheets|table|csv|таблиц|эксель|финанс)/iu,
    ids: ["spreadsheets", "audit-xls", "clean-data-xls", "dcf-model", "3-statement-model"],
    domains: ["data", "finance"],
    boost: 150,
  },
  {
    when: /(slides|presentation|deck|powerpoint|ppt|презентац|слайды)/iu,
    ids: ["presentations", "ckm:slides", "client-report"],
    domains: ["slides", "docs"],
    boost: 150,
  },
];

// Опциональный личный/проектный routing-overlay. Generic-канон публичен; доменные правила
// (напр. юрпрактика, клиентские проекты) живут в приватном слое — внешним JSON-файлом, НЕ в коде.
// Формат: [{ "when": "regex-строка", "flags": "iu", "ids": [...], "pathIncludes": [...], "domains": [...], "boost": 180 }]
try {
  const overlayTxt = await fs.readFile(`${HOME}/.agents/registry/route-overlay.json`, "utf8");
  for (const rule of JSON.parse(overlayTxt)) {
    overlays.push({ ...rule, when: new RegExp(rule.when, rule.flags || "iu") });
  }
} catch { /* overlay опционален — отсутствие/ошибка чтения не критичны */ }

function overlayBoost(record) {
  let boost = 0;
  const reg = record.registry || {};
  const regDomains = reg.domains || record.domains || [];
  for (const overlay of overlays) {
    if (!overlay.when.test(query)) continue;
    if (overlay.ids?.includes(record.id)) boost += overlay.boost;
    if (overlay.pathIncludes?.some((part) => record.path.includes(part))) boost += overlay.boost;
    if (overlay.domains?.some((domain) => regDomains.includes(domain))) boost += Math.round(overlay.boost * 0.25);
  }
  return boost;
}

function qualityBoost(record, lexicalScore, routeBoost) {
  const reg = record.registry || {};
  const registryScore = Number(reg.score || 0);
  if (!registryScore) return 0;
  if (lexicalScore <= 0 && routeBoost <= 0) return 0;

  const usageAdj = Math.min(18, Number(reg.usage_30d || reg.usage_count || 0) * 3);
  return Math.round(registryScore * 0.9 + usageAdj);
}

function costRank(cost) {
  const normalized = String(cost || "").toLowerCase();
  if (normalized === "light" || normalized === "l") return 0;
  if (normalized === "medium" || normalized === "m") return 1;
  if (normalized === "heavy" || normalized === "h") return 2;
  return 1;
}

const scored = index.records
  .map((record) => {
    const registryRecord = registry.get(record.id) || {};
    const merged = { ...record, registry: registryRecord };
    const lexicalScore = score(merged, qTerms);
    const routeBoost = overlayBoost(merged);
    const finalScore = lexicalScore + routeBoost + qualityBoost(merged, lexicalScore, routeBoost);
    return {
      ...merged,
      route_score: finalScore,
      type: record.type || registryRecord.type || "skill",
      lexical_score: lexicalScore,
      registry_score: registryRecord.score || 0,
      domains: registryRecord.domains || record.domains || [],
      stars: registryRecord.stars || null,
      usage_count: registryRecord.usage_count || 0,
      usage_30d: registryRecord.usage_30d || 0,
      cost_tier: registryRecord.cost_tier || record.cost_tier || "",
      model: registryRecord.model || record.model || "",
    };
  })
  .filter((record) => record.route_score > 0)
  .sort((a, b) =>
    b.route_score - a.route_score ||
    b.registry_score - a.registry_score ||
    b.usage_30d - a.usage_30d ||
    b.usage_count - a.usage_count ||
    costRank(a.cost_tier) - costRank(b.cost_tier) ||
    a.path.localeCompare(b.path)
  );

const seen = new Set();
const results = [];
for (const record of scored) {
  const key = `${record.type}:${record.id}`;
  if (seen.has(key)) continue;
  seen.add(key);
  results.push(record);
  if (results.length >= limit) break;
}

if (jsonOut) {
  console.log(JSON.stringify({ query, limit, count: results.length, results }, null, 2));
} else {
  console.log(`Query: ${query}`);
  console.log(`Index: ${index.count} capabilities · candidates: ${results.length}`);
  for (const [i, r] of results.entries()) {
    const rel = r.path.replace(`${path.dirname(path.dirname(path.dirname(activeIndexPath)))}/`, "");
    console.log("");
    console.log(`${i + 1}. ${r.name}  type=${r.type} route=${r.route_score} registry=${r.registry_score}`);
    console.log(`   path: ${r.path}`);
    if (r.domains?.length) console.log(`   domains: ${r.domains.join(", ")} · cost: ${r.cost_tier || "?"} · model: ${r.model || "?"}`);
    if (r.stars || r.usage_count) console.log(`   signals: stars=${r.stars || 0} · usage=${r.usage_count || 0} · usage30=${r.usage_30d || 0}`);
    if (r.description) console.log(`   desc: ${r.description.slice(0, 220)}`);
    if (r.headings?.length) console.log(`   headings: ${r.headings.slice(0, 4).join(" · ")}`);
    if (rel !== r.path) console.log(`   rel: ${rel}`);
  }
  console.log("");
  console.log("Next: explain selected capabilities, then read/call only the chosen finalists.");
}
