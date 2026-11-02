import { createServer } from 'node:http'
import { randomBytes, timingSafeEqual } from 'node:crypto'
import { chmodSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir, homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const webDir = join(here, '..', 'web')
const secret = () => randomBytes(32).toString('base64url')
const channel = secret()
const runDir = mkdtempSync(join(tmpdir(), 'sf-'))
const sock = join(runDir, 'mod.sock')
const launchFile = join(runDir, 'launch.html')

const dirInfo = lstatSync(runDir)
if (!dirInfo.isDirectory() || dirInfo.isSymbolicLink() || dirInfo.uid !== process.getuid() || (dirInfo.mode & 0o777) !== 0o700 || sock.length > 100) {
  rmSync(runDir, { recursive: true, force: true })
  process.exit(1)
}

let info = {}
try {
  info = JSON.parse(readFileSync(0, 'utf8') || '{}')
} catch {
  info = {}
}
const sessionId = typeof info.sessionId === 'string' && /^[A-Za-z0-9-]{1,80}$/.test(info.sessionId) ? info.sessionId : ''
const cwd = typeof info.cwd === 'string' ? info.cwd.slice(0, 500) : ''
const title = typeof info.title === 'string' ? info.title.slice(0, 120) : ''

const MAX_EVENTS = 3000
const MAX_BYTES = 5 * 1024 * 1024
const MAX_TEXT = 200000
const MAX_BODY = 65536
const MAX_STREAMS = 2
const CODE_MS = 60000
const IDLE_TOKEN_MS = 15 * 60000
const BEAT_MS = 15000

let seq = 0
let bytes = 0
const events = []
const streams = new Set()
const answers = new Map()
const waiters = new Map()
const open = new Map()
let code = null
let codeFailures = 0
let pageToken = null
let lastStream = Date.now()
let lastBeat = Date.now()
let port = 0

function log(type, fields = {}) {
  try {
    process.stderr.write(JSON.stringify({ ts: new Date().toISOString(), type, ...fields }) + '\n')
  } catch {}
}

function say(obj) {
  const line = JSON.stringify(obj)
  if (line.length > 65536) return
  try {
    process.stdout.write(line + '\n')
  } catch {
    quit()
  }
}

let quitting = false
function quit() {
  if (quitting) return
  quitting = true
  for (const res of streams) res.end()
  try {
    rmSync(runDir, { recursive: true, force: true })
  } catch {}
  process.exit(0)
}
process.stdout.on('error', quit)
process.stdout.on('close', quit)
process.on('SIGTERM', quit)
process.on('SIGINT', quit)
process.on('SIGHUP', quit)
process.on('uncaughtException', () => {
  log('error', { where: 'uncaught' })
  quit()
})
process.on('unhandledRejection', () => {
  log('error', { where: 'unhandled' })
  quit()
})

const parent = process.ppid
let lastTick = Date.now()
setInterval(() => {
  const now = Date.now()
  if (now - lastTick > 5000) lastBeat = now
  lastTick = now
  if (process.ppid !== parent || now - lastBeat > BEAT_MS) quit()
  if (pageToken && streams.size === 0 && Date.now() - lastStream > IDLE_TOKEN_MS) {
    pageToken = null
    log('token-expired')
  }
}, 1000).unref()

function mintCode() {
  code = { value: secret(), until: Date.now() + CODE_MS, used: false }
  codeFailures = 0
  const url = `http://127.0.0.1:${port}/#c=${code.value}`
  writeFileSync(launchFile, `<!doctype html><meta charset="utf-8"><meta name="referrer" content="no-referrer"><meta http-equiv="refresh" content="0;url=${url}"><title>Software factory</title>`, { mode: 0o600 })
  chmodSync(launchFile, 0o600)
  return { code: code.value, launch: launchFile }
}

function revokePage(reason) {
  pageToken = null
  for (const res of streams) res.end()
  streams.clear()
  log('revoked', { reason })
}

function broadcast(ev) {
  const line = JSON.stringify(ev) + '\n'
  for (const res of streams) res.write(line)
}

function size(ev) {
  return JSON.stringify(ev).length
}

function addEvent(ev) {
  if (!ev || typeof ev !== 'object' || typeof ev.type !== 'string') return
  ev.seq = ++seq
  if (typeof ev.ts !== 'number') ev.ts = Date.now()
  const last = events[events.length - 1]
  if (ev.type === 'text' && last && last.type === 'text' && last.turnId === ev.turnId && typeof ev.text === 'string' && last.text.length < MAX_TEXT) {
    last.text += ev.text
    bytes += ev.text.length
  } else {
    events.push({ ...ev })
    bytes += size(ev)
  }
  while (events.length > MAX_EVENTS || bytes > MAX_BYTES) bytes -= size(events.shift())
  if (ev.type === 'resolved') open.delete(ev.id)
  broadcast(ev)
}

function validAnswer(card, value, fromTerminal) {
  if (card.type === 'permission') {
    if (fromTerminal && value === 'terminal') return true
    if (!value || typeof value !== 'object' || Array.isArray(value)) return false
    const keys = Object.keys(value)
    if (value.choice === 'no') return keys.every(k => k === 'choice' || k === 'note') && (value.note === undefined || (typeof value.note === 'string' && value.note.length <= 2000))
    if (keys.length !== 1) return false
    if (value.choice === 'yes') return card.complete !== false
    if (value.choice === 'always') return card.complete !== false && typeof card.always === 'string' && card.always !== ''
    return false
  }
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  const asked = new Set(card.questions.map(q => q.question))
  const keys = Object.keys(value)
  if (keys.length !== asked.size || keys.some(k => !asked.has(k))) return false
  return keys.every(k => typeof value[k] === 'string' && value[k].trim() !== '' && value[k].length <= 2000)
}

function answer(id, value, fromTerminal) {
  const card = open.get(id)
  if (!card) return 409
  if (!validAnswer(card, value, fromTerminal)) return 400
  open.delete(id)
  const list = waiters.get(id)
  if (list && list.length) {
    waiters.delete(id)
    for (const r of list) r(value)
  } else {
    answers.set(id, value)
  }
  addEvent({ type: 'resolved', id })
  if (!fromTerminal) {
    log('answered', { kind: card.type })
    say({ t: 'security', kind: 'answered', card: card.type, tool: card.tool, choice: card.type === 'permission' ? value.choice : undefined })
  }
  return 200
}

function same(given, expected) {
  if (typeof given !== 'string' || typeof expected !== 'string') return false
  const a = Buffer.from(given)
  const b = Buffer.from(expected)
  return a.length === b.length && timingSafeEqual(a, b)
}

const HEADERS = {
  'Content-Security-Policy': "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' blob:; font-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'",
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cache-Control': 'no-store',
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Resource-Policy': 'same-origin',
  'X-Frame-Options': 'DENY',
}

function send(res, status, body, type = 'application/json; charset=utf-8') {
  if (res.headersSent) return res.end()
  res.writeHead(status, { ...HEADERS, 'Content-Type': type })
  res.end(typeof body === 'string' || Buffer.isBuffer(body) ? body : JSON.stringify(body))
}

const TOO_BIG = Symbol('too big')
const MAX_IMAGE = 2.5 * 1024 * 1024
const MAX_IMAGES = 40
const IMAGE_TYPES = { 'image/png': /^\x89PNG\r\n\x1a\n/, 'image/jpeg': /^\xff\xd8\xff/, 'image/gif': /^GIF8[79]a/, 'image/webp': /^RIFF[\s\S]{4}WEBP/ }
const images = new Map()

function readRaw(req, limit) {
  return new Promise(resolve => {
    if (Number(req.headers['content-length'] || 0) > limit) {
      req.resume()
      return resolve(TOO_BIG)
    }
    let total = 0
    let failed = false
    const parts = []
    req.on('data', c => {
      if (failed) return
      total += c.length
      if (total > limit) {
        failed = true
        parts.length = 0
        resolve(TOO_BIG)
      } else parts.push(c)
    })
    req.on('end', () => {
      if (!failed) resolve(total ? Buffer.concat(parts) : undefined)
    })
    req.on('error', () => resolve(undefined))
  })
}

function readJson(req, limit = MAX_BODY) {
  return new Promise(resolve => {
    if (Number(req.headers['content-length'] || 0) > limit) {
      req.resume()
      return resolve(TOO_BIG)
    }
    let total = 0
    let failed = false
    const parts = []
    req.on('data', c => {
      if (failed) return
      total += c.length
      if (total > limit) {
        failed = true
        parts.length = 0
        resolve(TOO_BIG)
      } else parts.push(c)
    })
    req.on('end', () => {
      if (failed) return
      try {
        const value = JSON.parse(Buffer.concat(parts).toString('utf8'))
        resolve(value && typeof value === 'object' ? value : undefined)
      } catch {
        resolve(undefined)
      }
    })
    req.on('error', () => resolve(undefined))
  })
}

const TYPES = { '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8' }
const STATIC = { '/': ['index.html', 'text/html; charset=utf-8'] }
for (const name of readdirSync(webDir)) {
  const ext = (name.match(/^[a-z][a-z0-9-]*(\.js|\.css)$/) || [])[1]
  if (ext && lstatSync(join(webDir, name)).isFile()) STATIC[`/${name}`] = [name, TYPES[ext]]
}
const ROUTES = { '/api/session': 'POST', '/api/events': 'GET', '/api/message': 'POST', '/api/stop': 'POST', '/api/answer': 'POST', '/api/disconnect': 'POST', '/api/prefs': 'POST', '/api/image': 'POST' }

const web = createServer({ headersTimeout: 10000, requestTimeout: 30000 }, async (req, res) => {
  const origin = `http://127.0.0.1:${port}`
  if (req.headers.host !== `127.0.0.1:${port}`) {
    log('reject', { why: 'host' })
    return send(res, 421, { error: 'host' })
  }
  if (req.headers.origin !== undefined && req.headers.origin !== origin) {
    log('reject', { why: 'origin' })
    return send(res, 403, { error: 'origin' })
  }
  const url = new URL(req.url, origin)
  const site = req.headers['sec-fetch-site']
  const pageVisit = req.method === 'GET' && url.pathname === '/' && req.headers['sec-fetch-mode'] === 'navigate' && req.headers['sec-fetch-dest'] === 'document'
  if (site !== undefined && site !== 'same-origin' && !pageVisit) {
    log('reject', { why: 'site' })
    return send(res, 403, { error: 'site' })
  }

  if (STATIC[url.pathname]) {
    if (req.method !== 'GET') return send(res, 405, { error: 'method' })
    const [file, type] = STATIC[url.pathname]
    try {
      if (file === 'index.html') return send(res, 200, page(), type)
      return send(res, 200, readFileSync(join(webDir, file)), type)
    } catch {
      return send(res, 404, { error: 'missing' })
    }
  }

  if (!ROUTES[url.pathname]) return send(res, 404, { error: 'route' })
  if (req.method !== ROUTES[url.pathname]) return send(res, 405, { error: 'method' })
  if (req.method === 'POST') {
    if (req.headers.origin !== origin) return send(res, 403, { error: 'origin' })
    const kind = String(req.headers['content-type'] || '')
    if (url.pathname === '/api/image' ? !Object.hasOwn(IMAGE_TYPES, kind) : !kind.startsWith('application/json')) return send(res, 415, { error: 'type' })
  }

  if (url.pathname === '/api/session') {
    const body = await readJson(req)
    if (body === TOO_BIG) return send(res, 413, { error: 'too big' })
    const given = body && typeof body.code === 'string' ? body.code : ''
    if (!code || codeFailures >= 10) return send(res, 401, { error: 'code' })
    if (!same(given, code.value)) {
      codeFailures += 1
      log('reject', { why: 'code' })
      return send(res, 401, { error: 'code' })
    }
    if (code.used) {
      revokePage('code reused')
      code = null
      say({ t: 'security', kind: 'reused' })
      return send(res, 401, { error: 'code' })
    }
    if (Date.now() > code.until) {
      code = null
      return send(res, 401, { error: 'expired' })
    }
    code.used = true
    if (pageToken) revokePage('new page')
    pageToken = secret()
    lastStream = Date.now()
    say({ t: 'security', kind: 'connected' })
    log('connected')
    return send(res, 200, { token: pageToken })
  }

  const auth = req.headers.authorization || ''
  if (!pageToken || !same(auth.startsWith('Bearer ') ? auth.slice(7) : '', pageToken)) {
    log('reject', { why: 'token', route: url.pathname })
    return send(res, 401, { error: 'token' })
  }

  if (url.pathname === '/api/events') {
    if (streams.size >= MAX_STREAMS) return send(res, 429, { error: 'streams' })
    res.writeHead(200, { ...HEADERS, 'Content-Type': 'application/x-ndjson; charset=utf-8' })
    res.write(JSON.stringify({ type: 'hello', sessionId, title, cwd }) + '\n')
    for (const ev of events) res.write(JSON.stringify(ev) + '\n')
    for (const ev of open.values()) res.write(JSON.stringify({ ...ev, replay: true }) + '\n')
    if (overview) res.write(overview + '\n')
    streams.add(res)
    const keep = setInterval(() => res.write('\n'), 15000)
    req.on('close', () => {
      clearInterval(keep)
      streams.delete(res)
      lastStream = Date.now()
    })
    return
  }

  if (url.pathname === '/api/image') {
    const data = await readRaw(req, MAX_IMAGE)
    if (data === TOO_BIG) return send(res, 413, { error: 'too big' })
    const type = String(req.headers['content-type'])
    if (!data || !IMAGE_TYPES[type].test(data.subarray(0, 12).toString('latin1'))) return send(res, 400, { error: 'image' })
    const unsent = [...images].filter(([, image]) => !image.sent)
    if (unsent.length >= MAX_IMAGES) {
      const [oldest, { path }] = unsent[0]
      rmSync(path, { force: true })
      images.delete(oldest)
    }
    const id = randomBytes(12).toString('hex')
    const dir = join(runDir, 'images')
    try {
      mkdirSync(dir, { mode: 0o700 })
    } catch {}
    const path = join(dir, id)
    try {
      writeFileSync(path, data, { mode: 0o600, flag: 'wx' })
    } catch {
      return send(res, 500, { error: 'save' })
    }
    images.set(id, { path, type, sent: false })
    return send(res, 200, { id })
  }

  const body = await readJson(req)
  if (body === TOO_BIG) return send(res, 413, { error: 'too big' })
  if (!body) return send(res, 400, { error: 'body' })

  if (url.pathname === '/api/message') {
    const text = typeof body.text === 'string' ? body.text.trim() : ''
    const ids = body.images === undefined ? [] : body.images
    if (Object.keys(body).some(k => k !== 'text' && k !== 'images') || text.length > 20000) return send(res, 400, { error: 'text' })
    if (!Array.isArray(ids) || ids.length > 4 || new Set(ids).size !== ids.length || ids.some(id => typeof id !== 'string' || !images.has(id) || images.get(id).sent)) return send(res, 400, { error: 'images' })
    if (!text && !ids.length) return send(res, 400, { error: 'text' })
    if (/^[/!]/.test(text)) return send(res, 400, { error: 'command' })
    for (const id of ids) images.get(id).sent = true
    say(ids.length ? { t: 'message', text, images: ids.map(id => ({ id, type: images.get(id).type })) } : { t: 'message', text })
    return send(res, 202, { ok: true })
  }
  if (url.pathname === '/api/prefs') {
    const keys = Object.keys(body)
    if (!keys.length || keys.some(k => k !== 'theme' && k !== 'scale')) return send(res, 400, { error: 'prefs' })
    const next = cleanPrefs({ ...readPrefs(), ...body })
    if (keys.some(k => next[k] !== body[k])) return send(res, 400, { error: 'prefs' })
    if (!writePrefs(next)) return send(res, 500, { error: 'save' })
    return send(res, 200, { ok: true })
  }
  if (url.pathname === '/api/stop') {
    say({ t: 'stop' })
    return send(res, 202, { ok: true })
  }
  if (url.pathname === '/api/answer') {
    if (typeof body.id !== 'string') return send(res, 400, { error: 'answer' })
    const status = answer(body.id, body.answer, false)
    return send(res, status, status === 200 ? { ok: true } : { error: status === 409 ? 'not open' : 'answer' })
  }
  revokePage('disconnect')
  say({ t: 'security', kind: 'disconnected' })
  return send(res, 200, { ok: true })
})
web.maxConnections = 16

const mod = createServer(async (req, res) => {
  if (!same(req.headers['x-sf-channel'], channel)) return send(res, 401, { error: 'channel' })
  lastBeat = Date.now()
  const url = new URL(req.url, 'http://sf')
  if (req.method === 'GET' && url.pathname === '/status') return send(res, 200, { streams: streams.size })
  if (req.method === 'GET' && url.pathname === '/image') {
    const found = images.get(url.searchParams.get('id') || '')
    if (!found || !found.sent) return send(res, 404, { error: 'image' })
    try {
      return send(res, 200, { type: found.type, path: found.path, base64: readFileSync(found.path).toString('base64') })
    } catch {
      return send(res, 404, { error: 'image' })
    }
  }
  if (req.method === 'GET' && url.pathname === '/wait') {
    const id = url.searchParams.get('id') || ''
    if (answers.has(id)) {
      const value = answers.get(id)
      answers.delete(id)
      return send(res, 200, { answer: value })
    }
    if (!open.has(id)) return send(res, 410, { error: 'gone' })
    let done = false
    const drop = () => waiters.set(id, (waiters.get(id) || []).filter(r => r !== finish))
    const finish = value => {
      if (done) return
      done = true
      clearTimeout(timer)
      if (value === undefined) send(res, 410, { error: 'gone' })
      else send(res, 200, { answer: value })
    }
    const timer = setTimeout(() => {
      drop()
      done = true
      send(res, 204, '')
    }, 5000)
    waiters.set(id, [...(waiters.get(id) || []), finish])
    req.on('close', () => {
      if (!done) {
        done = true
        clearTimeout(timer)
        drop()
      }
    })
    return
  }
  if (req.method !== 'POST') return send(res, 405, { error: 'method' })
  const body = await readJson(req, 4 * 1024 * 1024)
  if (body === TOO_BIG) return send(res, 413, { error: 'too big' })
  if (url.pathname === '/heartbeat') return send(res, 200, { ok: true })
  if (url.pathname === '/code') return send(res, 200, mintCode())
  if (url.pathname === '/event') {
    for (const ev of Array.isArray(body) ? body : [body]) if (ev && ev.type !== 'ask' && ev.type !== 'permission') addEvent(ev)
    return send(res, 200, { ok: true })
  }
  if (url.pathname === '/card') {
    if (!body || (body.type !== 'ask' && body.type !== 'permission')) return send(res, 400, { error: 'card' })
    if (body.type === 'ask' && !Array.isArray(body.questions)) return send(res, 400, { error: 'card' })
    const id = randomBytes(16).toString('hex')
    const card = { ...body, id }
    addEvent(card)
    open.set(id, card)
    return send(res, 200, { id })
  }
  if (url.pathname === '/withdraw') {
    if (body && typeof body.id === 'string' && open.has(body.id)) {
      open.delete(body.id)
      answers.delete(body.id)
      for (const r of waiters.get(body.id) || []) r(undefined)
      waiters.delete(body.id)
      addEvent({ type: 'resolved', id: body.id })
    }
    return send(res, 200, { ok: true })
  }
  if (url.pathname === '/answer') {
    if (!body || typeof body.id !== 'string') return send(res, 400, { error: 'answer' })
    return send(res, 200, { status: answer(body.id, body.answer, true) })
  }
  return send(res, 404, { error: 'route' })
})

function stateBase() {
  return process.env.XDG_STATE_HOME && process.env.XDG_STATE_HOME.startsWith('/') ? process.env.XDG_STATE_HOME : join(homedir(), '.local', 'state')
}

function choices(file, pattern) {
  try {
    return [...readFileSync(join(webDir, file), 'utf8').matchAll(pattern)].map(m => m[1])
  } catch {
    return []
  }
}

function cleanPrefs(p) {
  const out = {}
  if (p && choices('themes.css', /^\[data-theme="([a-z0-9-]+)"\] \{/gm).includes(p.theme)) out.theme = p.theme
  if (p && choices('app.css', /^:root\[data-scale="(\d+)"\]/gm).map(Number).includes(p.scale)) out.scale = p.scale
  return out
}

const prefsDir = () => join(stateBase(), 'software-factory')

function readPrefs() {
  const file = join(prefsDir(), 'prefs.json')
  try {
    if (!own(prefsDir(), true) || !own(file, false) || statSync(file).size > 4096) return {}
    return cleanPrefs(JSON.parse(readFileSync(file, 'utf8')))
  } catch {
    return {}
  }
}

function writePrefs(p) {
  const dir = prefsDir()
  try {
    mkdirSync(dir, { recursive: true, mode: 0o700 })
    if (!own(dir, true)) return false
    chmodSync(dir, 0o700)
    const tmp = join(dir, `.prefs-${process.pid}.json`)
    writeFileSync(tmp, JSON.stringify(p), { mode: 0o600 })
    renameSync(tmp, join(dir, 'prefs.json'))
    return true
  } catch {
    return false
  }
}

function page() {
  const p = { theme: 'solarized-dark', scale: 100, ...readPrefs() }
  return readFileSync(join(webDir, 'index.html'), 'utf8').replace('data-theme="solarized-dark" data-scale="100"', `data-theme="${p.theme}" data-scale="${p.scale}"`)
}

function readIntent() {
  if (!sessionId) return { found: false }
  const root = join(stateBase(), 'knackpack', 'intent')
  const found = []
  try {
    for (const repo of readdirSync(root)) {
      let names = []
      try {
        names = readdirSync(join(root, repo))
      } catch {
        continue
      }
      for (const name of names) {
        const rest = name.startsWith(sessionId) ? name.slice(sessionId.length) : null
        if (rest === '.md' || (rest && /^\.\d+\.md$/.test(rest))) {
          const path = join(root, repo, name)
          found.push({ path, mtime: statSync(path).mtimeMs })
        }
      }
    }
  } catch {
    return { found: false }
  }
  found.sort((a, b) => b.mtime - a.mtime)
  for (const { path } of found) {
    let text = ''
    try {
      text = readFileSync(path, 'utf8').slice(0, 200000)
    } catch {
      continue
    }
    const status = (text.match(/^- Status: ([a-z]+)/m) || [])[1] || ''
    if (status === 'done' && found.length > 1) continue
    const heading = (text.match(/^# Intent record: (.*)$/m) || [])[1] || ''
    const section = name => {
      const m = text.match(new RegExp(`^## ${name}\\n([\\s\\S]*?)(?=^## |$(?![\\s\\S]))`, 'm'))
      return m ? m[1].split('\n').filter(l => l.startsWith('- ')).map(l => l.slice(2, 600)) : []
    }
    return { found: true, title: heading, status, agreed: section('Agreed'), assumed: section('Assumed \\(not confirmed\\)'), open: section('Open questions'), built: section('Built') }
  }
  return { found: false }
}

const MAX_PAGE = 8 * 1024 * 1024
const DATA = /<script id="data" type="application\/json">([\s\S]*?)<\/script>/

function own(path, dir) {
  const info = lstatSync(path)
  return info.uid === process.getuid() && !info.isSymbolicLink() && (dir ? info.isDirectory() : info.isFile())
}

function readOverview() {
  const dir = join(stateBase(), 'knackpack', 'factory')
  try {
    if (!own(dir, true) || !own(join(dir, 'enabled'), false)) return { type: 'overview', enabled: false, sessions: [] }
    const page = join(dir, 'software-factory.html')
    if (!own(page, false) || statSync(page).size > MAX_PAGE) return { type: 'overview', enabled: true, sessions: [] }
    const found = readFileSync(page, 'utf8').match(DATA)
    const data = found ? JSON.parse(found[1]) : {}
    const version = typeof data.version === 'string' && /^[0-9A-Za-z.+-]{1,40}$/.test(data.version) ? data.version : ''
    return { type: 'overview', enabled: true, version, sessions: Array.isArray(data.sessions) ? data.sessions.slice(0, 100) : [] }
  } catch {
    return { type: 'overview', enabled: false, sessions: [] }
  }
}

let overview = ''
function refreshOverview() {
  const next = JSON.stringify({ ...readOverview(), live: sessionId })
  if (next === overview) return
  overview = next
  for (const res of streams) res.write(next + '\n')
}
refreshOverview()
setInterval(refreshOverview, 3000).unref()

let lastIntent = ''
setInterval(() => {
  const rec = JSON.stringify(readIntent())
  if (rec !== lastIntent) {
    lastIntent = rec
    addEvent({ type: 'intent', record: JSON.parse(rec) })
  }
}, 3000).unref()

mod.on('error', quit)
web.on('error', quit)
mod.listen(sock, () => {
  chmodSync(sock, 0o600)
  web.listen(0, '127.0.0.1', () => {
    port = web.address().port
    say({ t: 'ready', port, sock, channel, ...mintCode() })
  })
})
