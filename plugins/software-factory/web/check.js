import { el } from './dom.js'

class SfCheck extends HTMLElement {
  #check = null
  #run = null
  #note = null
  #status = {}
  #sentAt = 0

  get check() {
    return this.#check
  }

  set check(value) {
    this.#check = value
    const row = el('div', 'row')
    row.append(el('span', '', value.name))
    if (value.required) row.append(el('span', 'tag req', 'Required'))
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
    row.append(this.#run)
    this.#note = el('div', 'small muted', 'Not run in this session')
    this.replaceChildren(row, this.#note)
  }

  set status(value = {}) {
    this.#status = value
    const { running = false, ran = false, finished = '', verdict = null, disabled = false } = value
    if (!this.#run) return
    if (running) this.#sentAt = 0
    const sent = Date.now() - this.#sentAt < 30000
    this.#run.textContent = running ? 'Running…' : sent ? 'Asked…' : ran || verdict ? 'Run again' : 'Run'
    this.#run.setAttribute('aria-disabled', String(running || sent || disabled))
    this.#note.className = `small ${verdict ? verdict[1] : 'muted'}`
    this.#note.textContent = verdict ? verdict[0] : running ? 'Reviewing…' : finished ? `Finished: ${finished}` : 'Not run in this session'
  }
}

customElements.define('sf-check', SfCheck)
