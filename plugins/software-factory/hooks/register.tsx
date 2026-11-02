import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { SoftwareFactoryPending } from '../types'

type Helper = { port: number; sock: string; channel: string; launch: string }
type Ev = Record<string, unknown> & { type: string }
type Question = { question: string; header?: string; multiSelect?: boolean; options?: { label: string; description?: string }[] }

const pending = atom({ plugin: 'software-factory', key: 'pending' } as const, null as SoftwareFactoryPending, { shape: 'pending-2' })

const PERSON_ONLY = new Set(['AskUserQuestion', 'ExitPlanMode'])
const SAFE_ENV = { NODE_OPTIONS: '', NODE_PATH: '', ANTHROPIC_API_KEY: '', ANTHROPIC_AUTH_TOKEN: '', CLAUDE_CODE_OAUTH_TOKEN: '' }

let helper: Helper | null = null
let starting: Promise<{ helper: Helper; code: string }> | null = null
let child: { return?: () => unknown } | null = null
let stopping = false
let turnId: string | undefined
let queue: Ev[] = []
let flushing = false
let ticker: { cancel: () => void } | null = null
let lastAgents = ''
let logBudget = { at: 0, left: 30 }
const cards = new Map<string, string>()
let holding: string | null = null
let imageTool = ''
let lastCatalog = ''
const offered = new Map<string, string>()

const INVISIBLE = /[\u0000-\u0008\u000b-\u001f\u007f-\u009f\u200b-\u200f\u2028-\u202e\u2060-\u2069\ufeff]/g

function visible(text: string): string {
  return text.replace(INVISIBLE, c => `\\u{${c.codePointAt(0)!.toString(16).padStart(4, '0')}}`)
}

function clip(s: unknown, n: number): string {
  const t = typeof s === 'string' ? s : s === undefined || s === null ? '' : JSON.stringify(s)
  return t.length > n ? `${t.slice(0, n)}…` : t
}

function summarize(tool: string, input: Record<string, unknown>): string {
  const pick = (...keys: string[]) => keys.map(k => input[k]).find(v => typeof v === 'string' && v) as string | undefined
  if (tool === 'Bash') return clip(pick('command') ?? '', 300)
  if (tool === 'Agent' || tool === 'Task') return clip(`${pick('subagent_type') ?? 'agent'}: ${pick('description') ?? ''}`, 200)
  if (tool === 'Skill') return clip(pick('skill', 'command') ?? '', 200)
  return clip(pick('file_path', 'path', 'pattern', 'url', 'query', 'notebook_path') ?? '', 200)
}

const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`

function size(bytes: number): string {
  return bytes < 1024 ? `${bytes} B` : bytes < 1048576 ? `${(bytes / 1024).toFixed(1)}KB` : `${(bytes / 1048576).toFixed(1)}MB`
}

function changes(hunks: unknown): string {
  const lines = Array.isArray(hunks) ? hunks.flatMap(h => (Array.isArray((h as { lines?: unknown }).lines) ? ((h as { lines: unknown[] }).lines as string[]) : [])) : []
  const added = lines.filter(l => typeof l === 'string' && l.startsWith('+')).length
  const removed = lines.filter(l => typeof l === 'string' && l.startsWith('-')).length
  return `Added ${plural(added, 'line')}, removed ${plural(removed, 'line')}`
}

function outcome(tool: string, ran: { deny?: string; isError?: boolean; text?: string; result?: unknown }): string {
  const first = (t: unknown) => clip(String(t ?? '').trim().split('\n')[0], 200)
  if (ran.deny !== undefined) return first(ran.deny) || 'Denied'
  if (ran.isError) return first(ran.text) || 'Failed'
  const r = (ran.result ?? {}) as Record<string, any>
  try {
    if (tool === 'Bash') {
      if (r.backgroundTaskId) return 'Running in the background'
      if (r.interrupted) return 'Interrupted'
      const lines = String(r.stdout || r.stderr || '').trimEnd().split('\n').filter((l, i, a) => a.length > 1 || l)
      if (!lines.length) return 'No output'
      const shown = lines.slice(0, 3).map(l => clip(l, 200)).join('\n')
      return lines.length > 3 ? `${shown}\n… +${plural(lines.length - 3, 'line')}` : shown
    }
    if (tool === 'Read') return r.type === 'text' && r.file ? `Read ${plural(r.file.numLines, 'line')}` : r.type === 'image' ? 'Read an image' : ''
    if (tool === 'Edit') return changes(r.structuredPatch)
    if (tool === 'Write') return r.type === 'create' ? `Wrote ${plural(String(r.content ?? '').split('\n').length, 'line')}` : changes(r.structuredPatch)
    if (tool === 'WebFetch' && typeof r.bytes === 'number') return `Received ${size(r.bytes)} (${r.code} ${r.codeText})`
  } catch {
    return ''
  }
  return ''
}

function detail(tool: string, input: Record<string, unknown>): string {
  if (tool === 'Bash' && typeof input.command === 'string') return clip(input.command, 20000)
  return clip(JSON.stringify(input, null, 2), 20000)
}

const WHERE: Record<string, string> = { session: 'during this session', localSettings: 'in this project', projectSettings: 'in this project, for everyone', userSettings: 'in every project', cliArg: 'during this session' }

const RULE_VERB: Record<string, [string, string]> = { allow: ["don't ask again for", 'allow'], deny: ['always deny', 'deny'], ask: ['always ask before', 'ask'] }

function describe(u: { type: string; destination?: string; rules?: { toolName: string; ruleContent?: string }[]; mode?: string; directories?: string[]; behavior?: string }): string {
  const where = WHERE[u.destination ?? ''] ?? ''
  const verb = RULE_VERB[u.behavior ?? '']
  const what = (u.rules ?? []).map(r => (r.toolName === 'Bash' && r.ruleContent ? `${r.ruleContent.replace(/:\*$|\s\*$/, '')} commands` : r.ruleContent ? `${r.toolName}(${r.ruleContent})` : r.toolName)).join(', ')
  const dirs = (u.directories ?? []).join(', ')
  let text = ''
  if (u.type === 'addRules' && verb && what) text = `${verb[0]} ${what}`
  else if (u.type === 'replaceRules' && verb && what) text = `replace the ${verb[1]} rules with ${what}`
  else if (u.type === 'removeRules' && verb && what) text = `remove the ${verb[1]} rules for ${what}`
  else if (u.type === 'setMode' && u.mode === 'acceptEdits') text = 'allow all edits'
  else if (u.type === 'setMode' && u.mode) text = `switch to ${u.mode} mode`
  else if (u.type === 'addDirectories' && dirs) text = `allow access to ${dirs}`
  else if (u.type === 'removeDirectories' && dirs) text = `remove access to ${dirs}`
  return text ? clip(`${text} ${where}`.trim(), 300) : ''
}

let registering: Promise<string> | null = null
let sending: Promise<void> = Promise.resolve()

function registerImageTool($: EngineInterface): Promise<string> {
  if (imageTool) return Promise.resolve(imageTool)
  registering ??= $.tool
    .register({ name: 'pasted_image', description: 'Shows an image the user pasted or dropped on the software factory page. Call it with the id their message gives, once per image, when the message mentions one.', inputSchema: { type: 'object', properties: { id: { type: 'string', description: 'The image id from the message' } }, required: ['id'] }, isDeferred: false })
    .then(r => (imageTool = r.tool))
    .catch(() => '')
    .finally(() => {
      registering = null
    })
  return registering
}

function inside(path: string, dir: string): boolean {
  return !!dir && (path === dir || path.startsWith(dir.endsWith('/') ? dir : `${dir}/`))
}

async function call($: EngineInterface, path: string, body?: unknown) {
  const h = helper
  if (!h) throw new Error('software-factory: the page is not running')
  return $.http.fetch(`http://sf${path}`, {
    method: body === undefined ? 'GET' : 'POST',
    socketPath: h.sock,
    headers: { 'x-sf-channel': h.channel, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  })
}

function push($: EngineInterface, ev: Ev) {
  if (!helper) return
  queue.push({ ...ev, ts: Date.now() })
  if (flushing) return
  flushing = true
  void (async () => {
    try {
      while (queue.length && helper) {
        const batch = queue
        queue = []
        await call($, '/event', batch).catch(() => undefined)
      }
    } finally {
      flushing = false
      if (!helper) queue = []
    }
  })()
}

async function connected($: EngineInterface): Promise<boolean> {
  try {
    const r = await call($, '/status')
    return r.ok && (JSON.parse(r.text) as { streams: number }).streams > 0
  } catch {
    return false
  }
}

async function card($: EngineInterface, body: Ev, agentId = ''): Promise<string | null> {
  try {
    const r = await call($, '/card', body)
    if (!r.ok) return null
    const id = (JSON.parse(r.text) as { id: string }).id
    cards.set(id, agentId)
    return id
  } catch {
    return null
  }
}

async function waitFor($: EngineInterface, id: string, signal?: { aborted: boolean }): Promise<unknown> {
  while (!signal?.aborted) {
    const r = await call($, `/wait?id=${encodeURIComponent(id)}`)
    if (r.status === 200) return (JSON.parse(r.text) as { answer: unknown }).answer
    if (r.status !== 204) return undefined
  }
  return undefined
}

function withdraw($: EngineInterface, id: string) {
  void call($, '/withdraw', { id }).then(r => r.ok && cards.delete(id)).catch(() => undefined)
}

function validAnswers(questions: Question[], value: unknown): value is Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  const v = value as Record<string, unknown>
  const keys = Object.keys(v)
  return keys.length === questions.length && questions.every(q => typeof v[q.question] === 'string' && (v[q.question] as string).trim() !== '' && (v[q.question] as string).length <= 2000)
}

function tick($: EngineInterface) {
  ticker?.cancel()
  ticker = $.clock.every(3000, () => {
    if (!helper) return
    void call($, '/heartbeat', {}).catch(() => undefined)
    void $.agent.list().then(list => {
      const agents = list.map(a => ({ id: a.id, type: a.type, description: clip(a.description, 160), status: a.status }))
      const key = JSON.stringify(agents)
      if (key !== lastAgents) {
        lastAgents = key
        push($, { type: 'agents', agents })
      }
    }).catch(() => undefined)
    void catalog($)
  })
}

async function catalog($: EngineInterface) {
  const commands = await $.command.list().then(list => list.slice(0, 400).map(c => ({ name: clip(c.name, 120), description: clip(c.description, 240) }))).catch(() => null)
  if (!commands || !helper) return
  const agents = [...offered].slice(0, 200).map(([name, description]) => ({ name: clip(name, 120), description: clip(description, 240) }))
  const key = JSON.stringify([commands, agents])
  if (key === lastCatalog) return
  lastCatalog = key
  push($, { type: 'catalog', commands, agents })
}

async function runCommand($: EngineInterface, text: string) {
  const [, name, args] = /^\/(\S+)\s*([\s\S]*)$/.exec(text) ?? []
  if (!name) return
  try {
    const result = await $.command.run({ command: name, args: args.trim() })
    if (result.text) push($, { type: 'command', name: clip(name, 120), text: clip(result.text, 20000) })
  } catch (err) {
    push($, { type: 'command', name: clip(name, 120), text: clip(err instanceof Error ? err.message : String(err), 2000), failed: true })
  }
}

async function backfill($: EngineInterface) {
  try {
    const messages = await $.session.messages()
    for (const m of messages.slice(-60)) {
      if (m.role === 'user' && m.text && !/^\s*<(command-|local-command)/.test(m.text)) push($, { type: 'prompt', text: clip(m.text, 20000), from: 'history' })
      if (m.role === 'assistant' && m.text) push($, { type: 'text', text: clip(m.text, 50000), turnId: `history-${Math.random()}` })
    }
  } catch {
    return
  }
}

async function findNode($: EngineInterface): Promise<string | null> {
  const [cwd, root] = await Promise.all([$.session.cwd(), $.session.root().catch(() => '')])
  const env = await $.process.run(['/usr/bin/printenv', 'PATH']).catch(() => null)
  for (const dir of (env?.stdout.trim() ?? '').split(':')) {
    if (!dir.startsWith('/')) continue
    const found = await $.fs.stat(`${dir}/node`, { resolve: true }).catch(() => null)
    const real = found?.realPath
    if (!found || found.kind !== 'file' || !real || inside(real, cwd) || inside(real, root) || inside(dir, cwd) || inside(dir, root)) continue
    const probe = await $.process.run([real, '-p', 'process.execPath + "\\n" + process.versions.node'], { env: SAFE_ENV, cwd: `${$.plugin.root}/helper` }).catch(() => null)
    if (!probe || probe.exitCode !== 0) continue
    const [execPath, version] = probe.stdout.trim().split('\n')
    if (!execPath?.startsWith('/') || inside(execPath, cwd) || inside(execPath, root)) continue
    if (Number(version?.split('.')[0]) >= 18) return execPath
  }
  return null
}

function notice($: EngineInterface, msg: { kind?: string; card?: string; tool?: string; choice?: string }) {
  const text =
    msg.kind === 'connected' ? 'A browser page connected to this session.'
    : msg.kind === 'reused' ? 'The page link was used twice, so the page was disconnected. Run /factory to open it again.'
    : msg.kind === 'disconnected' ? 'The page disconnected.'
    : msg.kind === 'answered' && msg.card === 'permission' ? `${msg.choice === 'no' ? 'Denied' : 'Allowed'} ${msg.tool ?? 'a tool'} from the page.`
    : msg.kind === 'answered' ? 'A question was answered from the page.'
    : ''
  if (text) $.ui.toast(text, { timeoutMs: 6000 })
}

function relayLog($: EngineInterface, line: string) {
  const now = Date.now()
  if (now - logBudget.at > 60000) logBudget = { at: now, left: 30 }
  if (logBudget.left-- > 0) $.ui.log(`software-factory helper: ${clip(line, 400)}`, { to: 'debug' })
}

function handle($: EngineInterface, line: string, resolve: (v: { helper: Helper; code: string }) => void) {
  if (line.length > 65536) return
  let msg: Record<string, unknown>
  try {
    msg = JSON.parse(line)
  } catch {
    return
  }
  if (!msg || typeof msg !== 'object') return
  if (msg.t === 'ready' && typeof msg.port === 'number' && typeof msg.sock === 'string' && typeof msg.channel === 'string' && typeof msg.code === 'string' && typeof msg.launch === 'string') {
    helper = { port: msg.port, sock: msg.sock, channel: msg.channel, launch: msg.launch }
    resolve({ helper, code: msg.code })
    tick($)
    void backfill($)
  } else if (msg.t === 'message' && typeof msg.text === 'string' && msg.text.length <= 20000 && /^\//.test(msg.text) && !msg.images) {
    const text = msg.text
    sending = sending.then(async () => {
      push($, { type: 'prompt', text: clip(text, 20000), from: 'page' })
      await runCommand($, text)
    }).catch(() => {})
  } else if (msg.t === 'message' && typeof msg.text === 'string' && msg.text.length <= 20000 && !/^\s*[/!]/.test(msg.text)) {
    const ids = Array.isArray(msg.images) ? (msg.images as { id?: unknown }[]).map(i => i?.id).filter((id): id is string => typeof id === 'string' && /^[0-9a-f]{24}$/.test(id)).slice(0, 4) : []
    const text = msg.text
    if (!text.trim() && !ids.length) return
    sending = sending.then(async () => {
      const tool = ids.length ? await registerImageTool($) : ''
      const lost = ids.length && !tool ? ids.length : 0
      const pictures = (n: number) => (n === 1 ? 'an image' : `${n} images`)
      push($, { type: 'prompt', text: clip(text, 20000), from: 'page', images: ids.length - lost, lost })
      if (!text.trim() && lost) return
      const note = !ids.length ? '' : lost ? `I pasted ${pictures(lost)} on the software factory page, but ${lost === 1 ? 'it' : 'they'} couldn't be passed on to you.` : `I pasted ${pictures(ids.length)} on the software factory page. To see ${ids.length === 1 ? 'it' : 'them'}, call ${tool} with ${ids.map(id => `id "${id}"`).join(', then ')}.`
      void $.prompt.submit({ text: [note, text.trim()].filter(Boolean).join('\n\n'), asUser: true })
    }).catch(() => {})
  } else if (msg.t === 'stop' && turnId) {
    void $.turn.abort({ turnId })
  } else if (msg.t === 'security') {
    notice($, msg as { kind?: string })
  }
}

function start($: EngineInterface): Promise<{ helper: Helper; code: string }> {
  if (starting) return starting
  starting = new Promise((resolve, reject) => {
    void (async () => {
      const node = await findNode($)
      if (!node) {
        starting = null
        reject(new Error('software-factory needs Node.js 18 or later on your PATH, outside this project. Install it from https://nodejs.org and run /factory again.'))
        return
      }
      const [sessionId, cwd] = await Promise.all([$.session.id(), $.session.cwd()])
      const title = cwd.split('/').filter(Boolean).pop() ?? ''
      const stream = $.process.spawn({ argv: [node, `${$.plugin.root}/helper/server.mjs`], cwd: `${$.plugin.root}/helper`, env: SAFE_ENV, input: JSON.stringify({ sessionId, cwd, title }) })
      child = stream as unknown as { return?: () => unknown }
      stopping = false
      const bufs = { stdout: '', stderr: '' }
      try {
        for await (const { stream: pipe, text } of stream) {
          bufs[pipe] += text
          for (let i = bufs[pipe].indexOf('\n'); i >= 0; i = bufs[pipe].indexOf('\n')) {
            const line = bufs[pipe].slice(0, i)
            bufs[pipe] = bufs[pipe].slice(i + 1)
            if (pipe === 'stdout') handle($, line, resolve)
            else if (line.trim()) relayLog($, line)
          }
          if (bufs.stdout.length > 65536) bufs.stdout = ''
          if (bufs.stderr.length > 65536) bufs.stderr = ''
        }
      } catch (err) {
        reject(err instanceof Error ? err : new Error(String(err)))
      } finally {
        const wasRunning = helper !== null
        helper = null
        starting = null
        child = null
        ticker?.cancel()
        ticker = null
        lastAgents = ''
        lastCatalog = ''
        queue = []
        void update($, pending, () => null).catch(() => undefined)
        reject(new Error('software-factory: the helper stopped before it was ready.'))
        if (wasRunning && !stopping) $.ui.toast('Stopped. Questions and permission prompts are back in the terminal only.', { timeoutMs: 8000 })
      }
    })()
  })
  return starting
}

async function openPage($: EngineInterface, h: Helper, code: string): Promise<string> {
  const os = await $.process.run(['/usr/bin/uname']).catch(() => null)
  const mac = os?.stdout.trim() === 'Darwin'
  const ran = mac
    ? await $.process.run(['/usr/bin/osascript', '-'], { stdin: `open location "http://127.0.0.1:${h.port}/#c=${code}"` }).catch(() => null)
    : await $.process.run(['xdg-open', h.launch]).catch(() => null)
  const opened = !!ran && ran.exitCode === 0
  return opened
    ? 'Opened this session in your browser. The link works once, within a minute: run /factory again for a new one, or /factory stop to close the page.'
    : "Couldn't open a browser. Run /factory link to copy a one-time link instead."
}

async function ask($: EngineInterface, e: { questions?: Question[] }, next: (e: never) => Promise<unknown>, input: never) {
  const questions = e.questions ?? []
  const id = await card($, { type: 'ask', questions: questions.map(q => ({ question: q.question, header: q.header ?? '', multiSelect: !!q.multiSelect, options: (q.options ?? []).map(o => ({ label: o.label, description: o.description ?? '' })) })) })
  if (!id) return next(input)
  const native = next(input).then(r => ({ native: r }))
  const fromPage = waitFor($, id).then(answer => ({ page: answer })).catch(() => ({ page: undefined }))
  const first = await Promise.race([native, fromPage.then(r => (validAnswers(questions, r.page) ? r : native))])
  if ('native' in first) {
    withdraw($, id)
    return first.native
  }
  cards.delete(id)
  return { result: { questions, answers: first.page } as never }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const started = await next(e)
    await $.command.register({ name: 'factory', description: 'Continue this session from a page in your browser (/factory link copies a link instead; /factory stop closes it)' })
    return started
  })

  on('command.run', { command: 'factory' }, async ($, e) => {
    if (e.args.trim() === 'stop') {
      if (!child) return { text: 'The software factory page is not running.' }
      stopping = true
      child.return?.()
      return { text: 'Closed the software factory page.' }
    }
    try {
      let h: Helper
      let code: string
      if (helper) {
        h = helper
        code = (JSON.parse((await call($, '/code', {})).text) as { code: string }).code
      } else {
        ;({ helper: h, code } = await start($))
      }
      await registerImageTool($)
      if (e.args.trim() === 'link') {
        const copied = await $.ui.copy({ text: `http://127.0.0.1:${h.port}/#c=${code}` }).then(r => r.isCopied).catch(() => false)
        return { text: copied ? 'A one-time link to this session is on your clipboard. Paste it into a browser within a minute.' : "Couldn't reach the clipboard. Run /factory to open the page instead." }
      }
      return { text: await openPage($, h, code) }
    } catch (err) {
      return { text: err instanceof Error ? err.message : String(err) }
    }
  })

  on('prompt.submit', async ($, e, next) => {
    const o = e.origin as { kind?: string; name?: string } | undefined
    if (helper && !e.isMeta && e.text && !(o?.kind === 'plugin' && o.name === $.plugin.name)) push($, { type: 'prompt', text: clip(e.text, 20000), from: 'terminal' })
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    if (!e.agentId) {
      turnId = e.turnId
      push($, { type: 'busy', turnId: e.turnId })
    }
    return next(e)
  })

  on('turn.step', async function* ($, e, next) {
    for await (const chunk of next(e)) {
      if (helper && !e.agentId && chunk.kind === 'text' && chunk.text) push($, { type: 'text', turnId: e.turnId, text: chunk.text })
      yield chunk
    }
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    const loop = e.agentId ?? ''
    await Promise.all([...cards].filter(([, agent]) => agent === loop).map(([id]) => call($, '/withdraw', { id }).then(r => r.ok && cards.delete(id)).catch(() => undefined)))
    if (e.agentId && helper && e.answer) {
      const agent = await $.agent.list().then(list => list.find(a => a.id === e.agentId)).catch(() => undefined)
      if (agent) push($, { type: 'verdict', agentType: agent.type, text: clip(e.answer, 1500) })
    }
    if (!e.agentId) {
      turnId = undefined
      await update($, pending, () => null)
      if (helper) {
        push($, { type: 'idle', turnId: e.turnId, reason: e.reason, ms: e.durationMs, tokens: e.usage ? e.usage.input_tokens + e.usage.output_tokens : undefined })
      }
    }
    return done
  })

  on('agent.offer', async ($, e, next) => {
    if (e.agent && !offered.has(e.agent)) offered.set(e.agent, e.description ?? '')
    return next(e)
  })

  on('tool.check', async ($, e, next) => (imageTool && e.tool === imageTool ? { decision: 'allow' as const, reason: 'Reads an image pasted on the software factory page' } : next(e)))

  on('tool.call', async ($, e, next) => {
    if (imageTool && e.tool === imageTool) {
      const id = String((e as unknown as { id?: unknown }).id ?? '')
      if (!helper || !/^[0-9a-f]{24}$/.test(id)) return { deny: 'No pasted image has that id. The software factory page may have closed.' }
      try {
        const r = await call($, `/image?id=${id}`)
        if (!r.ok) return { deny: 'No pasted image has that id. The software factory page may have closed.' }
        const image = JSON.parse(r.text) as { type: string; path: string; base64: string }
        return { result: [{ type: 'image', source: { type: 'base64', media_type: image.type, data: image.base64 } }, { type: 'text', text: `The image is also saved at ${image.path}. If it doesn't show above, open that file with Read.` }] as never }
      } catch {
        return { deny: "Couldn't read that image from the software factory page." }
      }
    }
    if (!helper) return next(e)
    const input = e as unknown as Record<string, unknown>
    if (e.tool === 'AskUserQuestion' && (await connected($))) return ask($, input as { questions?: Question[] }, next as never, e as never) as never
    const id = e.tool_use_id ?? `call-${Date.now()}`
    const isAgent = e.tool === 'Agent' || e.tool === 'Task'
    push($, { type: 'tool', id, tool: e.tool, summary: summarize(e.tool, input), agentId: e.agentId })
    if (e.tool === 'ExitPlanMode') push($, { type: 'plan', id, plan: clip(input.plan, 20000) })
    const ran = await next(e)
    push($, { type: 'tool_done', id, ok: !(ran.deny !== undefined || ran.isError === true), outcome: outcome(e.tool, ran as never), text: isAgent ? clip(ran.text, 1500) : undefined, agentType: isAgent ? input.subagent_type : undefined })
    return ran
  })

  on('classic.PermissionRequest', async ($, e, next) => {
    const decided = await next(e)
    const tool = e.tool_name
    const agentId = (e as { agent_id?: string }).agent_id ?? ''
    const signal = (next as { signal?: { aborted: boolean } }).signal
    if (decided.decision || !helper || PERSON_ONLY.has(tool) || holding !== null || !(await connected($))) return decided
    const claim = `claim-${Math.random()}`
    holding = claim
    const input = (e.tool_input ?? {}) as Record<string, unknown>
    const summary = visible(summarize(tool, input))
    const full = tool === 'Bash' && typeof input.command === 'string' ? input.command : JSON.stringify(input, null, 2)
    const updates = e.permission_suggestions ?? []
    const words = updates.map(describe)
    const always = updates.length && words.every(Boolean) ? `Yes, and ${words.join(' and ')}` : ''
    let id: string | null = null
    let answer: unknown
    try {
      id = await card($, { type: 'permission', tool, summary, detail: detail(tool, input), complete: full.length <= 20000, always, agentId }, agentId)
      if (!id) return decided
      const cardId = id
      await update($, pending, () => ({ id: cardId, kind: 'permission' as const, tool, summary }))
      answer = await waitFor($, cardId, signal)
    } catch {
      answer = undefined
    } finally {
      if (holding === claim) holding = null
      if (id) {
        const cardId = id
        await update($, pending, p => (p && p.id === cardId ? null : p))
      }
    }
    if (!id) return decided
    if (signal?.aborted || !answer || typeof answer !== 'object') {
      withdraw($, id)
      return decided
    }
    cards.delete(id)
    const a = answer as { choice?: string; note?: string }
    if (a.choice === 'yes') return { ...decided, decision: { behavior: 'allow' as const } }
    if (a.choice === 'always' && always) return { ...decided, decision: { behavior: 'allow' as const, updatedPermissions: updates } }
    if (a.choice === 'no') {
      const note = typeof a.note === 'string' ? a.note.trim().slice(0, 2000) : ''
      return { ...decided, decision: note ? { behavior: 'deny' as const, message: `The user denied this from the software factory page and said: ${note}` } : { behavior: 'deny' as const, message: 'The user denied this from the software factory page.', interrupt: true as const } }
    }
    return decided
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const p = await read($, pending)
    if (!p) return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    const choose = (answer: unknown) => () => void call($, '/answer', { id: p.id, answer }).catch(() => undefined)
    return (
      <Box flexDirection="column">
        <Text>
          Claude wants to run {p.tool}: <Text dimColor>{p.summary}</Text>
        </Text>
        <Box>
          <Button key="deny" label="Deny" onPress={choose({ choice: 'no' })} />
          <Text> </Text>
          <Button key="terminal" label="Show the usual prompt" onPress={choose('terminal')} />
          <Text dimColor> or answer on the software factory page</Text>
        </Box>
      </Box>
    )
  })

  on('session.end', async ($, e, next) => {
    stopping = true
    child?.return?.()
    return next(e)
  })
}
