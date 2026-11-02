import { el, visible } from './dom.js'
import './markdown.js'

function start(host, meta, title) {
  host.classList.add('card')
  host.replaceChildren(el('div', 'meta', meta))
  if (title) host.append(el('h3', '', title))
}

function lock(host, locked) {
  for (const control of host.querySelectorAll('button, input')) control.disabled = locked
}

function reply(host, id, answer) {
  lock(host, true)
  host.dispatchEvent(new CustomEvent('sf-answer', { bubbles: true, detail: { id, answer } }))
}

function fail(host, message) {
  lock(host, false)
  let note = host.querySelector('.failed')
  if (!note) note = host.appendChild(el('p', 'small bad failed'))
  note.textContent = message
}

function button(text, cls = '') {
  const b = el('button', cls, text)
  b.type = 'button'
  return b
}

class SfAsk extends HTMLElement {
  #card = null
  #picks = {}

  get card() {
    return this.#card
  }

  set card(value) {
    this.#card = value
    this.#picks = {}
    this.#render()
  }

  set error(message) {
    fail(this, message)
  }

  #render() {
    const { id, questions } = this.#card
    start(this, 'Claude asks')
    const picks = this.#picks
    const single = questions.length === 1 && !questions[0].multiSelect
    const submit = button('Send answers', 'primary')
    const refresh = () => (submit.disabled = !questions.every(q => picks[q.question]?.length))
    for (const q of questions) {
      const box = el('div', 'q')
      box.append(el('h3', '', q.question))
      const opts = el('div', 'options')
      const mark = () => [...opts.children].forEach((b, i) => b.classList.toggle('on', (picks[q.question] || []).includes(q.options[i].label)))
      for (const o of q.options) {
        const b = button(o.label)
        if (o.description) b.append(el('small', '', o.description))
        b.addEventListener('click', () => {
          if (single) return reply(this, id, { [q.question]: o.label })
          const now = picks[q.question] || []
          picks[q.question] = q.multiSelect ? (now.includes(o.label) ? now.filter(l => l !== o.label) : [...now, o.label]) : [o.label]
          mark()
          refresh()
        })
        opts.append(b)
      }
      const other = el('form', 'other')
      const input = el('input')
      input.placeholder = 'Or type your own answer'
      input.setAttribute('aria-label', `Your own answer to: ${q.question}`)
      const go = el('button', '', single ? 'Send' : 'Use')
      go.type = 'submit'
      other.append(input, go)
      other.addEventListener('submit', e => {
        e.preventDefault()
        const text = input.value.trim()
        if (!text) return
        if (single) return reply(this, id, { [q.question]: text })
        picks[q.question] = [text]
        mark()
        refresh()
      })
      box.append(opts, other)
      this.append(box)
    }
    if (single) return this.append(el('p', 'small muted', 'You can also answer in the terminal.'))
    const actions = el('div', 'actions')
    submit.addEventListener('click', () => reply(this, id, Object.fromEntries(questions.map(q => [q.question, picks[q.question].join(', ')]))))
    actions.append(submit, el('span', 'small muted', 'You can also answer in the terminal.'))
    this.append(actions)
    refresh()
  }
}

class SfPermission extends HTMLElement {
  #card = null

  get card() {
    return this.#card
  }

  set card(value) {
    this.#card = value
    this.#render()
  }

  set error(message) {
    fail(this, message)
  }

  #render() {
    const { id, tool, detail, summary, reason, agentId, complete } = this.#card
    start(this, agentId ? 'A subagent wants to run a tool' : 'Claude wants to run a tool', `Allow ${visible(tool)}?`)
    if (detail || summary) this.append(el('pre', 'sum', visible(detail || summary)))
    if (reason) this.append(el('p', 'small muted', visible(reason)))
    const deny = button('Deny')
    deny.addEventListener('click', () => reply(this, id, 'deny'))
    const actions = el('div', 'actions')
    if (complete === false) {
      actions.append(deny, el('span', 'small muted', 'Too long to show in full here, so allow it in the terminal.'))
    } else {
      const allow = button('Allow once', 'primary')
      allow.addEventListener('click', () => reply(this, id, 'allow'))
      actions.append(allow, deny, el('span', 'small muted', 'Or answer in the terminal.'))
    }
    this.append(actions)
  }
}

class SfPlan extends HTMLElement {
  #card = null

  get card() {
    return this.#card
  }

  set card(value) {
    this.#card = value
    start(this, 'Plan ready', 'Claude is waiting for you to approve its plan in the terminal.')
    if (!value.plan) return
    const details = el('details')
    const body = el('div', 'reply')
    const text = el('sf-markdown', 'body')
    text.text = value.plan
    body.append(text)
    details.append(el('summary', 'small', 'Read the plan'), body)
    this.append(details)
  }
}

customElements.define('sf-ask', SfAsk)
customElements.define('sf-permission', SfPermission)
customElements.define('sf-plan', SfPlan)
