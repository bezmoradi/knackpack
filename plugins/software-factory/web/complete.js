import { el } from './dom.js'

const SHOWN = 30

function rank(name, query) {
  const n = name.toLowerCase()
  if (!query || n.startsWith(query)) return 0
  if (n.slice(n.indexOf(':') + 1).startsWith(query)) return 1
  if (n.includes(query)) return 2
  let i = 0
  for (const c of n) if (c === query[i]) i++
  return i === query.length ? 3 : -1
}

function pick(list, query) {
  const q = query.toLowerCase()
  return list
    .map((item, i) => [rank(item.name, q), i, item])
    .filter(r => r[0] >= 0)
    .sort((a, b) => a[0] - b[0] || a[1] - b[1])
    .map(r => r[2])
}

export function complete(text, menu, { catalog, files }) {
  let items = []
  let active = 0
  let range = null
  let ask = 0
  let timer = 0

  const close = () => {
    items = []
    range = null
    menu.hidden = true
    menu.replaceChildren()
    text.setAttribute('aria-expanded', 'false')
    text.removeAttribute('aria-activedescendant')
  }

  const reveal = () => {
    const node = menu.children[active]
    if (!node) return
    if (node.offsetTop < menu.scrollTop) menu.scrollTop = node.offsetTop
    else if (node.offsetTop + node.offsetHeight > menu.scrollTop + menu.clientHeight) menu.scrollTop = node.offsetTop + node.offsetHeight - menu.clientHeight
  }

  const paint = () => {
    if (!items.length) {
      menu.hidden = true
      menu.replaceChildren()
      text.setAttribute('aria-expanded', 'false')
      text.removeAttribute('aria-activedescendant')
      return
    }
    menu.replaceChildren(
      ...items.map((item, i) => {
        const li = el('li', i === active ? 'active' : '')
        li.id = `complete-${i}`
        li.setAttribute('role', 'option')
        li.setAttribute('aria-selected', String(i === active))
        li.append(el('span', 'name', item.label))
        if (item.detail) li.append(el('span', 'detail', item.detail))
        li.addEventListener('mousedown', e => {
          e.preventDefault()
          accept(i)
        })
        return li
      }),
    )
    menu.hidden = false
    text.setAttribute('aria-expanded', 'true')
    text.setAttribute('aria-activedescendant', `complete-${active}`)
    reveal()
  }

  const accept = i => {
    const item = items[i]
    if (!item || !range) return
    text.setRangeText(item.insert, range[0], range[1], 'end')
    close()
    text.focus()
    text.dispatchEvent(new Event('input', { bubbles: true }))
  }

  const update = () => {
    const ticket = ++ask
    clearTimeout(timer)
    const caret = text.selectionStart
    if (caret !== text.selectionEnd) return close()
    const before = text.value.slice(0, caret)
    const { commands = [], agents = [] } = catalog() || {}
    const slash = /^\/(\S*)$/.exec(before)
    if (slash) {
      range = [0, caret]
      items = pick(commands, slash[1])
        .slice(0, SHOWN)
        .map(c => ({ label: `/${c.name}`, detail: c.description, insert: `/${c.name} ` }))
      active = 0
      return paint()
    }
    const at = /(^|\s)@([^\s@]*)$/.exec(before)
    if (!at) return close()
    const query = at[2]
    range = [caret - query.length - 1, caret]
    const agentItems = pick(agents, query.replace(/^agent-/, ''))
      .slice(0, SHOWN)
      .map(a => ({ label: `${a.name} (agent)`, detail: a.description, insert: `@agent-${a.name} ` }))
    items = agentItems
    active = 0
    paint()
    timer = setTimeout(async () => {
      const found = await files(query).catch(() => [])
      if (ticket !== ask || !range) return
      items = [...found.map(f => ({ label: f, detail: '', insert: `@${f} ` })), ...agentItems].slice(0, SHOWN)
      active = 0
      paint()
    }, 120)
  }

  text.setAttribute('aria-autocomplete', 'list')
  text.setAttribute('aria-controls', menu.id)
  text.setAttribute('aria-expanded', 'false')
  text.addEventListener('input', update)
  text.addEventListener('click', update)
  text.addEventListener('blur', () => {
    ask++
    clearTimeout(timer)
    close()
  })
  text.addEventListener('keydown', e => {
    if (menu.hidden || !items.length || e.isComposing) return
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      active = (active + (e.key === 'ArrowDown' ? 1 : items.length - 1)) % items.length
      paint()
    } else if (e.key === 'Tab' || (e.key === 'Enter' && !e.shiftKey)) {
      if (e.key === 'Enter' && text.value.trim() === items[active].insert.trim()) {
        close()
        return
      }
      accept(active)
    } else if (e.key === 'Escape') close()
    else return
    e.preventDefault()
    e.stopImmediatePropagation()
  })
  return { close }
}
