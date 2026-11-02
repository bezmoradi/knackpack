import { el } from './dom.js'
import { ago, dotClass, intentRecord, project, verdictClass } from './format.js'
import './intent.js'

function section(title, items) {
  if (!items.length) return []
  const ul = el('ul', 'list')
  ul.append(...items)
  return [el('h2', 'label', title), ul]
}

function duration(a) {
  if (!a.start || !a.end) return ''
  const s = a.end - a.start
  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`
}

class SfSession extends HTMLElement {
  #session = null
  #intent = null

  get session() {
    return this.#session
  }

  set session(s) {
    this.#session = s
    if (!s) return this.replaceChildren(el('p', 'muted', 'This session is not in knackpack’s overview any more.'))
    const head = el('div', 'session-head')
    const title = el('h1', '', project(s.cwd))
    title.prepend(el('span', dotClass(s.state)), ' ')
    head.append(title, el('span', `tag ${s.state === 'waiting' ? 'req' : ''}`, s.detail || s.state))
    const meta = el('p', 'small muted', [s.cwd, `session ${String(s.id).slice(0, 8)}`, s.last ? `last activity ${ago(s.last)}` : ''].filter(Boolean).join(' · '))
    const parts = [head, meta]
    if (s.state !== 'ended') parts.push(el('p', 'small note', 'Read-only. To answer or send messages from the browser, run /factory in that session.'))
    parts.push(...section('Waiting on you', (s.pending || []).map(p => {
      const li = el('li')
      li.append(el('div', '', p.q))
      if (p.options) li.append(el('div', 'small muted', p.options))
      return li
    })))
    parts.push(...section('Questions and answers', (s.questions || []).slice().reverse().map(q => {
      const li = el('li')
      li.append(el('div', '', q.q), el('div', 'small ok', q.a))
      return li
    })))
    parts.push(...section('Agents', (s.agents || []).slice().reverse().map(a => {
      const li = el('li')
      const row = el('div', 'row')
      row.append(el('span', '', String(a.type).replace(/^knackpack:/, '')), el('span', 'spacer'), el('span', 'small muted', duration(a)), el('span', `tag ${a.state === 'failed' ? 'bad' : a.state === 'done' ? 'ok' : ''}`, a.state))
      li.append(row)
      if (a.verdict) li.append(el('div', `small ${verdictClass(a.verdict)}`, a.verdict))
      if (a.error) li.append(el('div', 'small bad', a.error))
      return li
    })))
    parts.push(...section('Tasks', (s.tasks || []).map(t => el('li', t.done ? 'muted' : '', `${t.done ? '✓ ' : ''}${t.subject}`))))
    if (!this.#intent) this.#intent = el('sf-intent')
    this.#intent.record = intentRecord(s.records)
    parts.push(this.#intent)
    this.replaceChildren(...parts)
  }
}

customElements.define('sf-session', SfSession)
