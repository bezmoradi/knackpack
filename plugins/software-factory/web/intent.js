import { el } from './dom.js'

const GROUPS = [['Open questions', 'open', true], ['Agreed', 'agreed', false], ['Assumed', 'assumed', false], ['Built', 'built', false]]

class SfIntent extends HTMLElement {
  #record = null
  #open = new Map()

  connectedCallback() {
    if (!this.#record) this.hidden = true
  }

  get record() {
    return this.#record
  }

  set record(rec) {
    for (const d of this.querySelectorAll('details')) this.#open.set(d.dataset.group, d.open)
    this.#record = rec && rec.found ? rec : null
    this.hidden = !this.#record
    if (!this.#record) return this.replaceChildren()
    this.replaceChildren(el('h2', 'label', 'Intent'), el('p', 'small', rec.title || 'Intent record'))
    for (const [name, key, openByDefault] of GROUPS) {
      const lines = rec[key] || []
      if (!lines.length) continue
      const d = el('details')
      d.dataset.group = key
      d.open = this.#open.has(key) ? this.#open.get(key) : openByDefault
      d.append(el('summary', '', `${name} (${lines.length})`))
      const ul = el('ul')
      for (const line of lines) ul.append(el('li', '', line.replace(/\s+Said: ".*$/, '')))
      d.append(ul)
      this.append(d)
    }
  }
}

customElements.define('sf-intent', SfIntent)
