import { el } from './dom.js'

class SfTabs extends HTMLElement {
  #tabs = []
  #active = ''
  #key = ''

  connectedCallback() {
    this.setAttribute('role', 'tablist')
    this.setAttribute('aria-label', 'Open views')
    this.addEventListener('click', e => {
      const tab = e.target.closest('.tab')
      if (!tab) return
      if (e.target.closest('.x')) return this.#emit('sf-close', tab.dataset.id)
      this.#emit('sf-open', tab.dataset.id)
    })
    this.addEventListener('mousedown', e => {
      if (e.button === 1 && e.target.closest('.tab')) e.preventDefault()
    })
    this.addEventListener('auxclick', e => {
      const tab = e.target.closest('.tab')
      if (e.button === 1 && tab?.querySelector('.x')) this.#emit('sf-close', tab.dataset.id)
    })
    this.addEventListener('keydown', e => {
      const tab = e.target.closest('.tab')
      if (!tab) return
      const all = [...this.querySelectorAll('.tab')]
      const i = all.indexOf(tab)
      const to = { ArrowLeft: i - 1, ArrowRight: i + 1, Home: 0, End: all.length - 1 }[e.key]
      if (to !== undefined) {
        e.preventDefault()
        const next = all[(to + all.length) % all.length]
        next.focus()
        this.#emit('sf-open', next.dataset.id)
      } else if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        this.#emit('sf-open', tab.dataset.id)
      }
    })
  }

  set state({ tabs, active }) {
    const key = JSON.stringify([tabs, active])
    if (key === this.#key) return
    this.#key = key
    this.#tabs = tabs
    this.#active = active
    this.#render()
  }

  #emit(name, id) {
    this.dispatchEvent(new CustomEvent(name, { bubbles: true, detail: { id } }))
  }

  #render() {
    const focused = this.contains(document.activeElement) ? document.activeElement.closest('.tab')?.dataset.id : null
    this.replaceChildren(...this.#tabs.map(t => this.#tab(t)))
    const active = this.querySelector('.tab.active')
    active?.scrollIntoView({ block: 'nearest', inline: 'nearest' })
    if (focused) (this.querySelector(`.tab[data-id="${CSS.escape(focused)}"]`) || active)?.focus()
  }

  #tab(t) {
    const on = t.id === this.#active
    const tab = el('div', `tab${on ? ' active' : ''}${t.need ? ' need' : ''}${t.closable ? '' : ' pinned'}`)
    tab.dataset.id = t.id
    tab.setAttribute('role', 'tab')
    tab.setAttribute('aria-selected', String(on))
    tab.tabIndex = on ? 0 : -1
    if (t.title) tab.title = t.title
    tab.append(el('span', 'caption', t.label))
    if (t.need) tab.setAttribute('aria-description', 'needs you')
    if (t.closable) {
      const x = el('button', 'x')
      x.type = 'button'
      x.tabIndex = -1
      x.setAttribute('aria-label', `Close ${t.label}`)
      x.title = 'Close the tab. The session keeps running.'
      x.append(el('span', 'close', '×'), el('span', 'flag', '●'))
      tab.append(x)
    } else if (t.need) {
      const flag = el('span', 'flag', '●')
      flag.setAttribute('aria-hidden', 'true')
      tab.append(flag)
    }
    return tab
  }
}

customElements.define('sf-tabs', SfTabs)
