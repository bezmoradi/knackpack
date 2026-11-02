import { el } from './dom.js'

const NOTES = {
  none: ['Not run on this commit', 'muted'],
  running: ['Reviewing…', 'muted'],
  stale: ['Reviewed an earlier commit: run it again', 'warn'],
}

class SfCheck extends HTMLElement {
  #check = null
  #run = null
  #override = null
  #note = null
  #status = {}
  #sentAt = 0
  #armedAt = 0

  get check() {
    return this.#check
  }

  set check(value) {
    this.#check = value
    const row = el('div', 'row')
    row.append(el('span', '', value.name))
    row.append(el('span', 'spacer'))
    this.#run = el('button', 'ghost small', 'Run')
    this.#run.type = 'button'
    this.#run.addEventListener('click', () => {
      if (this.#run.getAttribute('aria-disabled') === 'true') return
      this.#sentAt = Date.now()
      this.status = this.#status
      setTimeout(() => (this.status = this.#status), 30000)
      this.dispatchEvent(new CustomEvent('sf-run', { bubbles: true, detail: { prompt: value.prompt } }))
    })
    this.#override = el('button', 'ghost small', 'Override')
    this.#override.type = 'button'
    this.#override.hidden = true
    this.#override.addEventListener('click', () => {
      if (this.#override.getAttribute('aria-disabled') === 'true') return
      if (Date.now() - this.#armedAt > 5000) {
        this.#armedAt = Date.now()
        this.status = this.#status
        setTimeout(() => (this.status = this.#status), 5000)
        return
      }
      this.#armedAt = 0
      this.status = this.#status
      this.dispatchEvent(new CustomEvent('sf-override', { bubbles: true, detail: { type: value.type } }))
    })
    row.append(this.#override, this.#run)
    this.#note = el('div', 'small muted', NOTES.none[0])
    this.replaceChildren(row, this.#note)
  }

  set status(value = {}) {
    this.#status = value
    const { running = false, ran = false, disabled = false, gate = null, error = '' } = value
    if (!this.#run) return
    if (running) this.#sentAt = 0
    const sent = Date.now() - this.#sentAt < 30000
    const state = gate?.state ?? (running ? 'running' : 'none')
    this.#run.textContent = running ? 'Running…' : sent ? 'Asked…' : ran ? 'Run again' : 'Run'
    this.#run.setAttribute('aria-disabled', String(running || sent || disabled))
    this.#override.hidden = state !== 'block'
    this.#override.textContent = Date.now() - this.#armedAt < 5000 ? 'Confirm override' : 'Override'
    this.#override.setAttribute('aria-disabled', String(disabled))
    const [text, tone] = error
      ? [error, 'bad']
      : state === 'pass'
        ? [gate.verdict, 'ok']
        : state === 'block'
          ? [gate.verdict, 'bad']
          : state === 'overridden'
            ? [`Overridden: ${gate.verdict}`, 'warn']
            : NOTES[state] ?? NOTES.none
    this.#note.className = `small ${tone}`
    this.#note.textContent = text
  }
}

customElements.define('sf-check', SfCheck)
