#!/usr/bin/env node
// Athena report quality gate. Adapted from mnemazine-report-quality-gate.mjs.
// Input:  --report <file> | --reports <dir>   accepts .html and .md
// Output: JSON stdout  { ok, checked, failures[] }   exit 0 = pass, 1 = fail
// Rules:  no-raw-ocr | no-local-paths | no-secrets | has-outcome | has-next-action
import { promises as fs } from 'node:fs'
import path from 'node:path'

const argv = process.argv.slice(2)

function arg(name, fallback = '') {
  const hit = argv.find(a => a === `--${name}` || a.startsWith(`--${name}=`))
  if (!hit) return fallback
  return hit.includes('=') ? hit.split('=').slice(1).join('=') : argv[argv.indexOf(hit) + 1] || fallback
}

const HOME = process.env.HOME || ''
const ROOT = process.env.ATHENA_ROOT || path.resolve(process.cwd())
const REPORT = arg('report', '')
const REPORTS_DIR = path.resolve(
  arg('reports', process.env.ATHENA_REPORTS || path.join(HOME, '.agents', 'reports'))
)

// Rule 1: raw OCR / media file artifacts
const rawMarkers = [
  /\btemp_image[_-]/i,
  /\bIMG_\d+/,
  /\bscreenshot\d+/i,
  /\bpaste-[a-zA-Z0-9]{4,}/i,
  /\b\w+\.(?:WEBP|PNG|JPE?G|HEIC|TIFF|MOV|MP4)\b/i,
  /raw\s+ocr/i,
  /No extractable text/i,
  /intake-draft/i,
]

// Rule 2: hardcoded local filesystem paths
const localPathMarkers = [
  /\/Users\/[a-zA-Z]/,
  /\\Users\\[a-zA-Z]/,
  /C:\\[Uu]sers\\/,
]

// Rule 3: secrets / credentials
const secretMarkers = [
  /\bsk-[A-Za-z0-9]{20,}/,
  /\bAKIA[A-Z0-9]{16}/,
  /\bBearer\s+[A-Za-z0-9_.-]{20,}/i,
  /password\s*=\s*\S{8,}/i,
  /api[_-]?key\s*[=:]\s*\S{8,}/i,
  /secret\s*[=:]\s*["']?\S{16,}/i,
]

function stripHtml(htmlContent) {
  return htmlContent
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim()
}

function toText(content, filename) {
  return filename.endsWith('.html') ? stripHtml(content) : content
}

async function listReports() {
  if (REPORT) return [path.resolve(REPORT)]
  const files = await fs.readdir(REPORTS_DIR, { withFileTypes: true }).catch(() => [])
  return files
    .filter(e => e.isFile() && (e.name.endsWith('.html') || e.name.endsWith('.md')))
    .map(e => path.join(REPORTS_DIR, e.name))
}

function checkReport(file, text) {
  const failures = []

  // 1. No raw OCR / media artifacts
  const rawHits = rawMarkers.filter(re => re.test(text)).map(re => String(re))
  if (rawHits.length) failures.push({ rule: 'no-raw-ocr', details: rawHits })

  // 2. No hardcoded local paths
  const pathHits = localPathMarkers.filter(re => re.test(text)).map(re => String(re))
  if (pathHits.length) failures.push({ rule: 'no-local-paths', details: pathHits })

  // 3. No secrets / credentials
  const secretHits = secretMarkers.filter(re => re.test(text)).map(re => String(re))
  if (secretHits.length) failures.push({ rule: 'no-secrets', details: secretHits })

  // 4. Must contain an outcome / result signal
  if (!/\boutcome\b|\bresult\b/i.test(text)) {
    failures.push({ rule: 'has-outcome', details: 'no "outcome" or "result" found in report' })
  }

  // 5. Must contain a next-action signal
  if (!/next[_\s-]action|next\s+step|следующ/i.test(text)) {
    failures.push({ rule: 'has-next-action', details: 'no "next_action" or "next step" found in report' })
  }

  return failures.length ? { file: path.relative(ROOT, file), failures } : null
}

const reports = await listReports()
if (!reports.length) {
  process.stdout.write(JSON.stringify({ ok: true, checked: 0, note: 'no reports found' }, null, 2) + '\n')
  process.exit(0)
}

const allFailures = []
for (const file of reports) {
  const content = await fs.readFile(file, 'utf8')
  const text = toText(content, file)
  const failure = checkReport(file, text)
  if (failure) allFailures.push(failure)
}

if (allFailures.length) {
  process.stderr.write(JSON.stringify({ ok: false, checked: reports.length, failures: allFailures }, null, 2) + '\n')
  process.exit(1)
}

process.stdout.write(JSON.stringify({ ok: true, checked: reports.length }, null, 2) + '\n')
