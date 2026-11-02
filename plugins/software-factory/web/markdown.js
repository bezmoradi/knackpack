import { el } from './dom.js'

function inline(parent, text) {
  for (const part of text.split(/(`[^`\n]+`|\*\*[^*\n]+\*\*)/)) {
    if (!part) continue
    if (part.startsWith('`') && part.endsWith('`') && part.length > 1) parent.append(el('code', '', part.slice(1, -1)))
    else if (part.startsWith('**') && part.endsWith('**') && part.length > 4) parent.append(el('strong', '', part.slice(2, -2)))
    else parent.append(part)
  }
}

function paint(node, text) {
  node.replaceChildren()
  text.split('```').forEach((chunk, i) => {
    if (i % 2) {
      const lines = chunk.split('\n')
      if (lines.length > 1 && /^[\w+-]*$/.test(lines[0])) lines.shift()
      const pre = el('pre')
      pre.append(el('code', '', lines.join('\n').replace(/\n$/, '')))
      node.append(pre)
      return
    }
    for (const para of chunk.split(/\n{2,}/)) {
      if (!para.trim()) continue
      const p = el('p')
      inline(p, para.replace(/^\n+|\n+$/g, ''))
      node.append(p)
    }
  })
}

class SfMarkdown extends HTMLElement {
  #text = ''
  #frame = 0

  get text() {
    return this.#text
  }

  set text(value) {
    this.#text = String(value ?? '')
    if (!this.#frame) this.#frame = requestAnimationFrame(() => this.#paint())
  }

  #paint() {
    this.#frame = 0
    paint(this, this.#text)
    this.dispatchEvent(new Event('sf-paint', { bubbles: true }))
  }
}

customElements.define('sf-markdown', SfMarkdown)
