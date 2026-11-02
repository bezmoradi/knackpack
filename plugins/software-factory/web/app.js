import { api, events, exchange, forget, signedIn, upload } from './api.js'
import { el } from './dom.js'
import { initPrefs } from './prefs.js'
import { VERDICTS, project } from './format.js'
import './markdown.js'
import './cards.js'
import './check.js'
import './intent.js'
import './overview.js'
import './session.js'

const CHECKS = [{ type: 'knackpack:adversarial-reviewer', name: 'Adversarial reviewer', required: true, prompt: 'Use the knackpack:adversarial-reviewer agent to review the current change against the requirements agreed in this session.' }]
const CARD_TAGS = { permission: 'sf-permission', ask: 'sf-ask', plan: 'sf-plan' }
const CARD_ORDER = Object.keys(CARD_TAGS)
const ACTIVE = ['pending', 'running', 'waiting']

const byId = id => document.getElementById(id)
const state = { connected: false, note: '', busy: false, title: '', sessionId: '', cwd: '', usage: '', agents: [], verdicts: new Map(), overview: null }
const cards = new Map()
const tools = new Map()
let reply = null
let following = false
let retry = 1000
let liveKey = ''
let sending = false

const checks = CHECKS.map(check => {
  const node = el('sf-check')
  node.check = check
  const li = el('li')
  li.append(node)
  byId('checks').append(li)
  return [check, node]
})

function nearBottom() {
  return window.innerHeight + window.scrollY >= document.body.scrollHeight - 160
}

function follow(wasNear) {
  if (wasNear) window.scrollTo(0, document.body.scrollHeight)
}

function entry(cls, who) {
  const li = el('li', cls)
  if (who) li.append(el('span', 'who', who))
  byId('timeline').append(li)
  byId('empty').hidden = true
  return li
}

function addPrompt(ev) {
  const wasNear = nearBottom()
  reply = null
  const who = ev.from === 'page' ? 'You, from this page' : ev.from === 'history' ? 'You, earlier' : 'You, in the terminal'
  const item = entry('prompt', who)
  if (ev.text) item.append(el('div', 'body', ev.text))
  if (ev.images) item.append(el('span', 'who', ev.images === 1 ? '1 image' : `${ev.images} images`))
  follow(wasNear)
}

function addText(ev) {
  following ||= nearBottom()
  if (!reply || reply.turnId !== ev.turnId) reply = { turnId: ev.turnId, body: entry('reply', 'Claude').appendChild(el('sf-markdown', 'body')) }
  reply.body.text += ev.text
}

function addTool(ev) {
  const wasNear = nearBottom()
  reply = null
  const li = entry(`tool${ev.agentId ? ' sub' : ''}`)
  li.append(el('span', 'name', ev.tool), el('span', 'sum', ev.summary || ''))
  li.title = ev.summary || ev.tool
  if (ev.id) tools.set(ev.id, li)
  follow(wasNear)
}

function verdict(ev) {
  if (!ev.agentType || !ev.text) return
  const found = VERDICTS.find(([word]) => ev.text.includes(word))
  if (found) state.verdicts.set(ev.agentType, found)
  paintChecks()
}

function toolDone(ev) {
  const li = tools.get(ev.id)
  if (li && !ev.ok) li.classList.add('fail')
  verdict(ev)
  dropCard(ev.id)
}

function showCard(ev) {
  if (cards.has(ev.id)) return
  const node = el(CARD_TAGS[ev.type])
  node.dataset.kind = ev.type
  node.card = ev
  const rank = CARD_ORDER.indexOf(ev.type)
  const before = [...cards.values()].find(n => CARD_ORDER.indexOf(n.dataset.kind) > rank)
  byId('needs').insertBefore(node, before || null)
  cards.set(ev.id, node)
}

function dropCard(id) {
  const node = cards.get(id)
  if (!node) return
  node.remove()
  cards.delete(id)
}

function apply(ev) {
  switch (ev.type) {
    case 'hello':
      state.title = ev.title || ''
      state.sessionId = ev.sessionId || ''
      state.cwd = ev.cwd || ''
      break
    case 'prompt':
      addPrompt(ev)
      break
    case 'text':
      addText(ev)
      break
    case 'tool':
      addTool(ev)
      break
    case 'tool_done':
      toolDone(ev)
      break
    case 'verdict':
      verdict(ev)
      break
    case 'busy':
      state.busy = true
      break
    case 'idle':
      state.busy = false
      reply = null
      if (ev.tokens !== undefined || ev.usd !== undefined) {
        const parts = []
        if (ev.tokens) parts.push(`${ev.tokens.toLocaleString()} tokens last turn`)
        if (typeof ev.usd === 'number') parts.push(`$${ev.usd.toFixed(2)} so far`)
        state.usage = parts.join(' · ')
      }
      break
    case 'ask':
    case 'permission':
    case 'plan':
      showCard(ev)
      break
    case 'resolved':
      dropCard(ev.id)
      break
    case 'intent':
      byId('intent').record = ev.record
      break
    case 'agents':
      state.agents = ev.agents || []
      paintAgents()
      paintChecks()
      break
    case 'overview':
      state.overview = ev
      byId('overview').data = ev
      showView()
      break
  }
  paintBar()
}

function route() {
  const hash = decodeURIComponent(location.hash.slice(1))
  if (hash === 'live' || (hash.startsWith('s/') && hash.slice(2) === state.sessionId)) return { view: 'live' }
  if (hash.startsWith('s/')) return { view: 'session', id: hash.slice(2) }
  return { view: 'overview' }
}

function otherSession(id) {
  return (state.overview?.sessions || []).find(s => s.id === id) || null
}

function showView() {
  const { view, id } = route()
  byId('overview').hidden = view !== 'overview'
  byId('live-view').hidden = view !== 'live'
  byId('composer').hidden = view !== 'live'
  byId('session-view').hidden = view !== 'session'
  document.body.classList.toggle('live', view === 'live')
  if (view === 'session') {
    const s = otherSession(id)
    if (byId('session').session !== s) byId('session').session = s
  }
  paintBar()
}

function paintBar() {
  const { view, id } = route()
  const live = cards.size > 0
  const waiting = (state.overview?.sessions || []).some(s => s.state === 'waiting' && s.id !== state.sessionId)
  const key = JSON.stringify([state.sessionId, state.cwd, state.busy, cards.size])
  if (key !== liveKey) {
    liveKey = key
    byId('overview').live = { id: state.sessionId, cwd: state.cwd, busy: state.busy, needs: cards.size }
  }
  byId('dot').className = `dot${!state.connected ? ' off' : live || waiting ? ' need' : state.busy ? ' busy' : ' on'}`
  let label = 'All sessions'
  let detail = ''
  if (view === 'live') {
    label = live ? 'Needs you' : state.busy ? 'Working' : 'Idle'
    detail = [state.title || project(state.cwd), state.sessionId.slice(0, 8)].filter(Boolean).join(' · ')
  } else if (view === 'session') {
    const s = otherSession(id)
    label = s ? project(s.cwd) : 'Session'
    detail = 'read-only'
  }
  byId('state').textContent = state.connected ? label : 'Disconnected'
  byId('title').textContent = state.connected ? detail : state.note
  byId('title').title = state.connected && view === 'live' ? state.cwd : ''
  byId('disconnect').hidden = !state.connected
  byId('usage').textContent = view === 'live' ? state.usage : ''
  byId('stop').hidden = !(state.connected && state.busy && view === 'live')
  byId('hint').textContent = 'Enter sends, Shift+Enter adds a line.'
  byId('hint').classList.toggle('quiet', state.busy)
  byId('working').hidden = !state.busy
  document.title = live || waiting ? 'Needs you · Software factory' : 'Software factory'
}

function paintAgents() {
  const list = byId('agents')
  list.replaceChildren()
  if (!state.agents.length) return list.append(el('li', 'muted', 'None yet.'))
  for (const a of state.agents.slice(-12).reverse()) {
    const li = el('li')
    const row = el('div', 'row')
    row.append(el('span', '', a.type.replace(/^knackpack:/, '')), el('span', 'spacer'), el('span', `tag${a.status === 'failed' || a.status === 'killed' ? ' bad' : a.status === 'completed' ? ' ok' : ''}`, a.status))
    li.append(row)
    if (a.description) li.append(el('div', 'small muted', a.description))
    list.append(li)
  }
}

function paintChecks() {
  for (const [check, node] of checks) {
    const last = state.agents.filter(a => a.type === check.type).at(-1)
    node.status = { running: !!last && ACTIVE.includes(last.status), ran: !!last, finished: last ? last.status : '', verdict: state.verdicts.get(check.type), disabled: !state.connected }
  }
}

function say(message) {
  byId('hint').textContent = message
  byId('hint').classList.remove('quiet')
}

async function send(text, images = []) {
  if (/^[/!]/.test(text)) {
    say('Slash commands and shell lines can only be typed in the terminal.')
    return false
  }
  const res = await api('/api/message', images.length ? { text, images } : { text }).catch(() => null)
  if (!res || !res.ok) {
    say('The message did not go through. Check that the session is still running.')
    return false
  }
  return true
}

const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/gif', 'image/webp']
const MAX_SIDE = 1568
const MAX_IMAGE = 2.5 * 1024 * 1024
const attached = []

async function shrink(file) {
  if (file.type === 'image/gif') return file
  const bitmap = await createImageBitmap(file).catch(() => null)
  if (!bitmap) return null
  const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
  if (scale === 1 && file.size <= MAX_IMAGE) {
    bitmap.close()
    return file
  }
  const canvas = document.createElement('canvas')
  canvas.width = Math.max(1, Math.round(bitmap.width * scale))
  canvas.height = Math.max(1, Math.round(bitmap.height * scale))
  canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height)
  bitmap.close()
  const encode = (type, quality) => new Promise(resolve => canvas.toBlob(resolve, type, quality))
  const blob = await encode(file.type === 'image/jpeg' ? 'image/jpeg' : 'image/png', 0.9)
  return blob && blob.size > MAX_IMAGE ? encode('image/jpeg', 0.85) : blob
}

function paintAttached() {
  const box = byId('attachments')
  box.replaceChildren()
  attached.forEach((item, i) => {
    const figure = el('figure', 'thumb')
    const img = el('img')
    img.src = item.url
    img.alt = `Pasted image ${i + 1}`
    const remove = el('button', 'ghost', '×')
    remove.type = 'button'
    remove.setAttribute('aria-label', `Remove image ${i + 1}`)
    remove.addEventListener('click', () => {
      URL.revokeObjectURL(item.url)
      attached.splice(i, 1)
      paintAttached()
      text.focus()
    })
    figure.append(img, remove)
    box.append(figure)
  })
  box.hidden = attached.length === 0
}

async function attach(files) {
  for (const file of files) {
    if (!IMAGE_TYPES.includes(file.type)) continue
    if (attached.length >= 4) {
      say('You can attach up to 4 images to a message.')
      break
    }
    const blob = await shrink(file)
    if (!blob || blob.size > MAX_IMAGE || !IMAGE_TYPES.includes(blob.type)) {
      say('That image is too large to send, or not one the page can read.')
      continue
    }
    attached.push({ blob, url: URL.createObjectURL(blob) })
  }
  paintAttached()
}

function clearAttached() {
  for (const item of attached) URL.revokeObjectURL(item.url)
  attached.length = 0
  paintAttached()
}

function reset() {
  byId('timeline').replaceChildren()
  byId('empty').hidden = false
  tools.clear()
  reply = null
  for (const id of [...cards.keys()]) dropCard(id)
  state.busy = false
  paintBar()
}

function signOut(note) {
  forget()
  reset()
  state.agents = []
  state.verdicts.clear()
  paintAgents()
  byId('intent').record = null
  state.overview = null
  state.sessionId = ''
  byId('overview').data = { enabled: true, sessions: [] }
  state.connected = false
  state.usage = ''
  state.note = note
  byId('gone').textContent = note
  document.body.classList.add('out')
  paintBar()
  paintChecks()
}

async function connect() {
  if (!signedIn()) return signOut('This link has been used or has expired. Run /factory in the terminal for a new one.')
  try {
    const res = await events()
    if (res.status === 401) return signOut('This page was disconnected. Run /factory in the terminal to open it again.')
    if (!res.ok || !res.body) throw new Error(String(res.status))
    reset()
    state.connected = true
    retry = 1000
    paintBar()
    paintChecks()
    const reader = res.body.pipeThrough(new TextDecoderStream()).getReader()
    let buf = ''
    for (;;) {
      const { value, done } = await reader.read()
      if (done) break
      buf += value
      for (let i = buf.indexOf('\n'); i >= 0; i = buf.indexOf('\n')) {
        const line = buf.slice(0, i)
        buf = buf.slice(i + 1)
        if (line.trim()) apply(JSON.parse(line))
      }
    }
  } catch {
    state.note = 'The session may have ended. Retrying…'
  }
  state.connected = false
  state.note = state.note || 'Reconnecting…'
  paintBar()
  paintChecks()
  setTimeout(connect, retry)
  retry = Math.min(retry * 2, 10000)
}

byId('timeline').addEventListener('sf-paint', () => {
  follow(following)
  following = false
})
byId('needs').addEventListener('sf-answer', async e => {
  const res = await api('/api/answer', e.detail).catch(() => null)
  if (!res || !res.ok) e.target.error = 'That answer did not go through. It may already have been answered in the terminal.'
})
byId('checks').addEventListener('sf-run', e => send(e.detail.prompt))
window.addEventListener('hashchange', () => {
  showView()
  window.scrollTo(0, 0)
})

const text = byId('text')
const grow = () => {
  text.style.height = 'auto'
  text.style.height = `${text.scrollHeight}px`
}
text.addEventListener('input', grow)
text.addEventListener('paste', e => {
  const files = [...(e.clipboardData?.items || [])].filter(i => i.kind === 'file').map(i => i.getAsFile()).filter(f => f && IMAGE_TYPES.includes(f.type))
  if (!files.length) return
  e.preventDefault()
  void attach(files)
})
byId('composer').addEventListener('dragover', e => {
  if ([...(e.dataTransfer?.items || [])].some(i => i.kind === 'file')) e.preventDefault()
})
byId('composer').addEventListener('drop', e => {
  const files = [...(e.dataTransfer?.files || [])].filter(f => IMAGE_TYPES.includes(f.type))
  if (!files.length) return
  e.preventDefault()
  void attach(files)
})
text.addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
    e.preventDefault()
    byId('composer').requestSubmit()
  }
})
byId('composer').addEventListener('submit', async e => {
  e.preventDefault()
  const value = text.value.trim()
  if ((!value && !attached.length) || !state.connected || sending) return
  sending = true
  const ids = []
  for (const item of attached) {
    const res = await upload(item.blob).catch(() => null)
    const body = res && res.ok ? await res.json().catch(() => null) : null
    if (!body || typeof body.id !== 'string') break
    ids.push(body.id)
  }
  if (ids.length !== attached.length) say('An image did not go through. Try again, or check that the session is still running.')
  else if (await send(value, ids)) {
    text.value = ''
    grow()
    clearAttached()
  }
  sending = false
  text.focus()
})
byId('stop').addEventListener('click', () => api('/api/stop', {}).catch(() => null))
byId('disconnect').addEventListener('click', async () => {
  await api('/api/disconnect', {}).catch(() => null)
  signOut('Disconnected. Run /factory in the terminal to open the page again.')
})
paintChecks()
showView()
initPrefs(body => api('/api/prefs', body).catch(() => null))
exchange().then(connect)
