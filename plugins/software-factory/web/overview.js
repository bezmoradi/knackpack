import { el } from './dom.js'
import { ago, dotClass, project, verdictClass } from './format.js'

const ENDED = ['ended']

class SfOverview extends HTMLElement {
  #data = { enabled: true, sessions: [], live: '' }
  #live = { id: '', cwd: '', busy: false, needs: 0 }
  #endedOpen = false
  #timer = 0

  connectedCallback() {
    this.#timer = setInterval(() => this.#render(), 30000)
    this.#render()
  }

  disconnectedCallback() {
    clearInterval(this.#timer)
  }

  get data() {
    return this.#data
  }

  set data(value) {
    this.#data = value || { enabled: false, sessions: [] }
    this.#render()
  }

  set live(value) {
    this.#live = { ...this.#live, ...value }
    this.#render()
  }

  #sessions() {
    const live = this.#live
    const list = (this.#data.sessions || []).map(s => (s.id === live.id ? { ...s, live: true, cwd: s.cwd || live.cwd } : s))
    if (live.id && !list.some(s => s.live)) list.unshift({ id: live.id, cwd: live.cwd, state: 'ready', detail: '', agents: [], pending: [], live: true })
    for (const s of list) if (s.live) {
      if (live.needs) Object.assign(s, { state: 'waiting', detail: 'needs you on this page' })
      else if (live.busy) Object.assign(s, { state: 'working', detail: '' })
    }
    return list
  }

  #row(s) {
    const a = el('a')
    a.href = '/'
    a.dataset.view = s.live ? 'live' : `s/${s.id}`
    a.title = s.cwd || ''
    const name = el('span', 'name', project(s.cwd))
    if (s.live) name.append(' ', el('span', 'tag live', 'this session'))
    const knack = (s.agents || []).filter(x => x.verdict).at(-1)
    const what = el('span', 'what', s.pending?.length ? s.pending[0].q : s.detail || s.state)
    if (knack) what.append(' · ', el('span', verdictClass(knack.verdict), knack.verdict))
    a.append(el('span', dotClass(s.state)), name, what, el('span', 'when', s.live && !s.last ? 'live' : ago(s.last)))
    const li = el('li')
    li.append(a)
    return li
  }

  #list(items) {
    const ul = el('ul', 'sessions')
    for (const s of items) ul.append(this.#row(s))
    return ul
  }

  #render() {
    if (!this.isConnected) return
    const focused = this.contains(document.activeElement) ? document.activeElement.dataset.view : null
    const all = this.#sessions()
    const active = all.filter(s => !ENDED.includes(s.state))
    const ended = all.filter(s => ENDED.includes(s.state))
    const waiting = active.filter(s => s.state === 'waiting')
    const rest = active.filter(s => s.state !== 'waiting')
    const parts = []
    if (!this.#data.enabled) parts.push(el('p', 'small muted', 'knackpack is not recording sessions, so only this one shows. Run /knackpack:software-factory on in any session to list them all here.'))
    if (waiting.length) parts.push(el('h2', 'label', `Needs you (${waiting.length})`), this.#list(waiting))
    parts.push(el('h2', 'label', rest.length ? `Sessions (${rest.length})` : 'Sessions'), rest.length ? this.#list(rest) : el('p', 'small muted', 'No other open sessions.'))
    if (ended.length) {
      const d = el('details', 'ended')
      d.open = this.#endedOpen
      d.addEventListener('toggle', () => (this.#endedOpen = d.open))
      d.append(el('summary', 'label', `Ended (${ended.length})`), this.#list(ended))
      parts.push(d)
    }
    this.replaceChildren(...parts)
    this.dispatchEvent(new CustomEvent('sf-counts', { bubbles: true, detail: { waiting: waiting.length, working: active.filter(s => s.state === 'working').length } }))
    if (focused) [...this.querySelectorAll('a')].find(a => a.dataset.view === focused)?.focus()
  }
}

customElements.define('sf-overview', SfOverview)
