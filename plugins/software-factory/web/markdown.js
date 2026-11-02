import { el } from './dom.js'

const FENCE = /^ {0,3}(`{3,}|~{3,})(.*)$/
const HEADING = /^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$/
const RULE = /^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$/
const SETEXT = /^ {0,3}(=+|-+)[ \t]*$/
const QUOTE = /^ {0,3}> ?(.*)$/
const ITEM = /^( {0,3})([-*+]|\d{1,9}[.)])(?:([ \t]+)(.*))?$/
const DELIM = /^ {0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/
const TASK = /^\[([ xX])\][ \t]+/
const PUNCT = /^[!-/:-@[-`{-~]$/
const URL_TEXT = /https?:\/\/[^\s<]+/g
const AUTOLINK = /<(https?:\/\/[^\s<>]+)>/iy

function startsBlock(line) {
  return FENCE.test(line) || HEADING.test(line) || RULE.test(line) || QUOTE.test(line) || ITEM.test(line)
}

function safeUrl(href) {
  try {
    const url = new URL(href)
    return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : ''
  } catch {
    return ''
  }
}

function anchor(href, title) {
  const a = el('a')
  a.href = href
  a.target = '_blank'
  a.rel = 'noopener noreferrer'
  if (title) a.title = title
  return a
}

function trimUrl(url) {
  let end = url.length
  while (end && /[.,:;!?'"*_~]/.test(url[end - 1])) end--
  let cut = url.slice(0, end)
  while (cut.endsWith(')') && (cut.match(/\(/g) || []).length < (cut.match(/\)/g) || []).length) cut = cut.slice(0, -1)
  return cut
}

function plain(parent, text, links) {
  if (!links) return parent.append(text)
  let last = 0
  for (const m of text.matchAll(URL_TEXT)) {
    const url = trimUrl(m[0])
    const href = safeUrl(url)
    if (!href) continue
    if (m.index > last) parent.append(text.slice(last, m.index))
    const a = anchor(href)
    a.textContent = url
    parent.append(a)
    last = m.index + url.length
  }
  if (last < text.length) parent.append(text.slice(last))
}

function closingTicks(text, from, size) {
  for (let j = text.indexOf('`', from); j >= 0; j = text.indexOf('`', j)) {
    let k = j
    while (text[k] === '`') k++
    if (k - j === size) return j
    j = k
  }
  return -1
}

function linkEnd(text, i) {
  let depth = 0
  let j = i
  const limit = Math.min(text.length, i + 2000)
  for (; j < limit; j++) {
    if (text[j] === '\\') j++
    else if (text[j] === '`') {
      let k = j
      while (text[k] === '`') k++
      const close = closingTicks(text, k, k - j)
      j = close < 0 ? k - 1 : close + k - j - 1
    } else if (text[j] === '[') depth++
    else if (text[j] === ']' && --depth === 0) break
  }
  if (j >= limit || text[j + 1] !== '(') return null
  const rest = text.slice(j + 2)
  const m = /^[ \t]*(?:<([^<>\n]*)>|((?:[^\s()\\]|\\.|\((?:[^\s()\\]|\\.)*\))*))(?:[ \t]+("[^"]*"|'[^']*'|\([^)]*\)))?[ \t]*\)/.exec(rest)
  if (!m) return null
  return { label: text.slice(i + 1, j), href: (m[1] ?? m[2]).replace(/\\(.)/g, '$1'), title: m[3] ? m[3].slice(1, -1) : '', end: j + 2 + m[0].length }
}

function emphasis(text, i, c, run, dead) {
  const n = run
  if (n > (c === '~' ? 2 : 3) || dead.get(c + n) <= i) return null
  const after = text[i + run]
  if (!after || /\s/.test(after)) return null
  if (c === '_' && /[\p{L}\p{N}]/u.test(text[i - 1] ?? '')) return null
  for (let j = i + run; j < text.length; ) {
    if (text[j] === '\\') {
      j += 2
      continue
    }
    if (text[j] === '`') {
      let k = j
      while (text[k] === '`') k++
      const close = closingTicks(text, k, k - j)
      j = close < 0 ? k : close + k - j
      continue
    }
    if (text[j] !== c) {
      j++
      continue
    }
    let k = j
    while (text[k] === c) k++
    const fits = k - j === n && !/\s/.test(text[j - 1]) && !(c === '_' && /[\p{L}\p{N}]/u.test(text[k] ?? ''))
    if (fits && j > i + run) return { n, inner: text.slice(i + n, j), end: k }
    j = k
  }
  dead.set(c + n, i)
  return null
}

function wrap(c, n) {
  if (n === 3 && c !== '~') {
    const strong = el('strong')
    const em = el('em')
    strong.append(em)
    return [strong, em]
  }
  const node = el(c === '~' ? 'del' : n === 2 ? 'strong' : 'em')
  return [node, node]
}

function inline(parent, text, links = true) {
  const dead = new Map()
  const noTicks = new Set()
  let buf = ''
  const flush = () => {
    if (buf) plain(parent, buf, links)
    buf = ''
  }
  let i = 0
  let link = null
  while (i < text.length) {
    const c = text[i]
    if (c === '\\' && PUNCT.test(text[i + 1] ?? '')) {
      buf += text[i + 1]
      i += 2
    } else if (c === '\\' && text[i + 1] === '\n') {
      buf += '\n'
      i += 2
    } else if (c === '`') {
      let k = i
      while (text[k] === '`') k++
      const close = noTicks.has(k - i) ? -1 : closingTicks(text, k, k - i)
      if (close < 0) {
        noTicks.add(k - i)
        buf += text.slice(i, k)
        i = k
        continue
      }
      flush()
      let code = text.slice(k, close).replace(/\n/g, ' ')
      if (code.length > 2 && code.startsWith(' ') && code.endsWith(' ') && code.trim()) code = code.slice(1, -1)
      parent.append(el('code', '', code))
      i = close + k - i
    } else if (c === '<' && links && ((AUTOLINK.lastIndex = i), AUTOLINK.test(text))) {
      const url = text.slice(i + 1, AUTOLINK.lastIndex - 1)
      const href = safeUrl(url)
      flush()
      if (href) {
        const a = anchor(href)
        a.textContent = url
        parent.append(a)
      } else parent.append(url)
      i += url.length + 2
    } else if (c === '!' && text[i + 1] === '[' && (link = linkEnd(text, i + 1))) {
      buf += text.slice(i, link.end)
      i = link.end
    } else if (c === '[' && (link = linkEnd(text, i))) {
      const href = links && safeUrl(link.href)
      flush()
      if (href) {
        const a = anchor(href, link.title)
        inline(a, link.label, false)
        parent.append(a)
      } else {
        const span = el('span')
        if (link.href) span.title = link.href
        inline(span, link.label, links)
        parent.append(span)
      }
      i = link.end
    } else if (c === '*' || c === '_' || c === '~') {
      let k = i
      while (text[k] === c) k++
      const hit = emphasis(text, i, c, k - i, dead)
      if (!hit) {
        buf += text.slice(i, k)
        i = k
        continue
      }
      flush()
      const [outer, innermost] = wrap(c, hit.n)
      inline(innermost, hit.inner, links)
      parent.append(outer)
      i = hit.end
    } else {
      buf += c
      i++
    }
  }
  flush()
}

function cells(line) {
  let s = line.trim()
  if (s.startsWith('|')) s = s.slice(1)
  if (s.endsWith('|') && !s.endsWith('\\|')) s = s.slice(0, -1)
  const out = ['']
  for (let k = 0; k < s.length; k++) {
    if (s[k] === '\\' && s[k + 1] === '|') {
      out[out.length - 1] += '|'
      k++
    } else if (s[k] === '|') out.push('')
    else out[out.length - 1] += s[k]
  }
  return out.map(c => c.trim())
}

function table(parent, head, delim, rows) {
  const align = delim.map(d => (d.startsWith(':') && d.endsWith(':') ? 'center' : d.endsWith(':') ? 'right' : ''))
  const row = (values, tag) => {
    const tr = el('tr')
    head.forEach((_, k) => {
      const cell = el(tag, align[k])
      inline(cell, values[k] ?? '')
      tr.append(cell)
    })
    return tr
  }
  const t = el('table')
  const thead = el('thead')
  thead.append(row(head, 'th'))
  t.append(thead)
  if (rows.length) {
    const tbody = el('tbody')
    for (const values of rows) tbody.append(row(values, 'td'))
    t.append(tbody)
  }
  const box = el('div', 'table')
  box.append(t)
  parent.append(box)
}

function item(lines, i, bullet, ordered) {
  const m = ITEM.exec(lines[i])
  const gap = m[3] ? m[3].length : 1
  const pad = m[1].length + m[2].length + (gap > 4 ? 1 : gap)
  const body = [m[4] === undefined ? '' : (gap > 4 ? ' '.repeat(gap - 1) : '') + m[4]]
  i++
  let blank = false
  while (i < lines.length) {
    const line = lines[i]
    if (!line.trim()) {
      blank = true
      body.push('')
      i++
    } else if (line.length - line.trimStart().length >= pad) {
      body.push(line.slice(pad))
      blank = false
      i++
    } else if (!blank && !startsBlock(line) && body[body.length - 1].trim()) {
      body.push(line.trim())
      i++
    } else break
  }
  let trailing = false
  while (body.length > 1 && !body[body.length - 1].trim()) {
    body.pop()
    trailing = true
  }
  const next = i < lines.length ? ITEM.exec(lines[i]) : null
  const same = next && !RULE.test(lines[i]) && (ordered ? /\d/.test(next[2]) && next[2].slice(-1) === bullet : next[2] === bullet)
  const loose = (trailing && same) || body.slice(1).some((l, k) => !l.trim() && body[k].trim() && !FENCE.test(body[k]))
  return { body, end: i, loose, more: Boolean(same) }
}

function list(parent, lines, i) {
  const first = ITEM.exec(lines[i])
  const ordered = /\d/.test(first[2])
  const bullet = ordered ? first[2].slice(-1) : first[2]
  const node = el(ordered ? 'ol' : 'ul')
  if (ordered && parseInt(first[2], 10) !== 1) node.start = parseInt(first[2], 10)
  const items = []
  let loose = false
  for (;;) {
    const it = item(lines, i, bullet, ordered)
    items.push(it.body)
    loose = loose || it.loose
    i = it.end
    if (!it.more) break
  }
  for (const body of items) {
    const li = el('li')
    const task = TASK.exec(body[0])
    if (task) body[0] = body[0].slice(task[0].length)
    render(li, body)
    if (!loose)
      for (const p of [...li.children])
        if (p.tagName === 'P') {
          if (p.previousSibling) p.before('\n')
          p.replaceWith(...p.childNodes)
        }
    if (task) {
      const box = el('input')
      box.type = 'checkbox'
      box.disabled = true
      box.checked = task[1] !== ' '
      li.className = 'task'
      ;(loose && li.firstElementChild?.tagName === 'P' ? li.firstElementChild : li).prepend(box)
    }
    node.append(li)
  }
  parent.append(node)
  return i
}

function render(parent, lines) {
  let para = []
  const flush = () => {
    if (!para.length) return
    const p = el('p')
    inline(p, para.join('\n'))
    parent.append(p)
    para = []
  }
  let i = 0
  while (i < lines.length) {
    const line = lines[i]
    let m
    if (!line.trim()) {
      flush()
      i++
    } else if (para.length && (m = SETEXT.exec(line)) && !(m[1][0] === '-' && ITEM.test(line) && m[1].length === 1)) {
      const h = el(m[1][0] === '=' ? 'h1' : 'h2')
      inline(h, para.join('\n'))
      para = []
      parent.append(h)
      i++
    } else if (para.length && line.includes('|') && DELIM.test(line) && cells(para[para.length - 1]).length === cells(line).length) {
      const head = cells(para.pop())
      const delim = cells(line)
      flush()
      const rows = []
      i++
      while (i < lines.length && lines[i].trim() && !startsBlock(lines[i])) rows.push(cells(lines[i++]))
      table(parent, head, delim, rows)
    } else if ((m = FENCE.exec(line)) && !(m[1][0] === '`' && m[2].includes('`'))) {
      flush()
      const close = new RegExp(`^ {0,3}${m[1][0]}{${m[1].length},}[ \\t]*$`)
      const indent = line.length - line.trimStart().length
      const body = []
      i++
      while (i < lines.length && !close.test(lines[i])) body.push(lines[i++].replace(new RegExp(`^ {0,${indent}}`), ''))
      i++
      const pre = el('pre')
      pre.append(el('code', '', body.join('\n')))
      parent.append(pre)
    } else if ((m = HEADING.exec(line))) {
      flush()
      const h = el(`h${m[1].length}`)
      inline(h, m[2] ?? '')
      parent.append(h)
      i++
    } else if (RULE.test(line)) {
      flush()
      parent.append(el('hr'))
      i++
    } else if (QUOTE.test(line)) {
      flush()
      const inner = []
      while (i < lines.length) {
        const q = QUOTE.exec(lines[i])
        if (q) inner.push(q[1])
        else if (lines[i].trim() && inner.length && inner[inner.length - 1].trim() && !startsBlock(lines[i])) inner.push(lines[i])
        else break
        i++
      }
      const quote = el('blockquote')
      render(quote, inner)
      parent.append(quote)
    } else if ((m = ITEM.exec(line)) && (!para.length || (m[4]?.trim() && (!/\d/.test(m[2]) || parseInt(m[2], 10) === 1)))) {
      flush()
      i = list(parent, lines, i)
    } else {
      para.push(line.trim())
      i++
    }
  }
  flush()
}

function paint(node, text) {
  node.replaceChildren()
  try {
    render(node, text.split(/\r?\n/).map(l => l.replace(/^\t+/, t => '    '.repeat(t.length))))
  } catch {
    node.replaceChildren(el('p', '', text))
  }
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
