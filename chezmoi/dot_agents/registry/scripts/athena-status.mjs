#!/usr/bin/env node
// Athena status snapshot. Reads routing-evals.jsonl → prints ≤20-line summary.
// Usage: node athena-status.mjs [--days=7] [--evals=PATH] [--json]
// Exit 0: no critical issues. Exit 1: failed jobs with no retry.
import { promises as fs } from 'node:fs'
import path from 'node:path'

const argv = process.argv.slice(2)
function arg(name, fallback = '') {
  const hit = argv.find(a => a === `--${name}` || a.startsWith(`--${name}=`))
  if (!hit) return fallback
  return hit.includes('=') ? hit.split('=').slice(1).join('=') : argv[argv.indexOf(hit) + 1] || fallback
}
const flag = name => argv.includes(`--${name}`)

const HOME = process.env.HOME || ''
const EVALS_PATH = arg('evals', path.join(HOME, '.agents', 'routing-evals.jsonl'))
const LEDGER_PATH = arg('ledger', path.join(HOME, '.agents', 'job-ledger.jsonl'))
const REPORTS_DIR = arg('reports', path.join(HOME, '.agents', 'reports'))
const STEWARD_PATH = arg('steward', path.join(HOME, '.agents', 'steward-log.jsonl'))
const DAYS = parseInt(arg('days', '7'), 10)

async function readJsonl(filePath) {
  try {
    const raw = await fs.readFile(filePath, 'utf8')
    return raw.split('\n').filter(l => l.trim()).map(l => JSON.parse(l))
  } catch { return [] }
}

const cutoff = new Date(Date.now() - DAYS * 86400_000).toISOString()
const evals = (await readJsonl(EVALS_PATH)).filter(e => (e.ts || '') >= cutoff)
const steward = (await readJsonl(STEWARD_PATH)).filter(e => (e.ts || '') >= cutoff)

let reportCount = 0
try {
  const files = await fs.readdir(REPORTS_DIR)
  reportCount = files.filter(f => f.endsWith('.md') || f.endsWith('.html')).length
} catch { /* not created yet */ }

// Counts
const byOutcome = {}, byClass = {}, byPrimary = {}
let corrections = 0, highConf = 0, medConf = 0, lowConf = 0
for (const e of evals) {
  byOutcome[e.outcome || 'unknown'] = (byOutcome[e.outcome || 'unknown'] || 0) + 1
  byClass[e.task_class || 'unknown'] = (byClass[e.task_class || 'unknown'] || 0) + 1
  byPrimary[e.primary || 'unknown'] = (byPrimary[e.primary || 'unknown'] || 0) + 1
  if (e.correction) corrections++
  if (e.confidence === 'high') highConf++
  else if (e.confidence === 'medium') medConf++
  else lowConf++
}

const total = evals.length
const delivered = byOutcome['delivered'] || 0
const failed = (byOutcome['failed'] || 0) + (byOutcome['error'] || 0)
const retry = byOutcome['retry'] || 0

const topClasses = Object.entries(byClass).sort((a, b) => b[1] - a[1]).slice(0, 5)
  .map(([k, v]) => `${k} ×${v}`).join('  ') || 'none'
const primarySplit = Object.entries(byPrimary).sort((a, b) => b[1] - a[1])
  .map(([k, v]) => `${k} ${v} (${total ? Math.round(v/total*100) : 0}%)`).join(' · ') || 'none'

const now = new Date().toISOString().slice(0, 16).replace('T', ' ')

if (flag('json')) {
  process.stdout.write(JSON.stringify({ total, delivered, failed, retry, corrections,
    byClass, byPrimary, confidence: { high: highConf, medium: medConf, low: lowConf },
    stewardPending: steward.length, reportCount }, null, 2) + '\n')
} else {
  const lines = [
    `Athena status — ${now} (last ${DAYS}d)`,
    `Jobs: ${total} total · ${delivered} delivered · ${retry} retry · ${failed} failed`,
    `Top classes: ${topClasses}`,
    `Primary split: ${primarySplit}`,
    `Confidence: high ×${highConf}  medium ×${medConf}  low ×${lowConf}`,
    `Corrections: ${corrections}`,
    `Pending steward proposals: ${steward.length}`,
    `Reports: ${REPORTS_DIR} (${reportCount} files)`,
  ]
  process.stdout.write(lines.join('\n') + '\n')
}

// Exit 1 only if failed > 0 and no retry (needs human attention)
if (failed > 0 && retry === 0) process.exit(1)
