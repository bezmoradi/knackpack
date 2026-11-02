const root = document.documentElement

function rules(pattern) {
  const found = []
  for (const sheet of document.styleSheets) {
    let list = []
    try {
      list = sheet.cssRules
    } catch {
      continue
    }
    for (const rule of list) {
      const m = pattern.exec(rule.selectorText || '')
      if (m) found.push({ value: m[1], style: rule.style })
    }
  }
  return found
}

export function themes() {
  return rules(/^\[data-theme="([a-z0-9-]+)"\]$/).map(({ value, style }) => ({
    value,
    label: style.getPropertyValue('--label').trim().replace(/^"(.*)"$/, '$1') || value,
    dark: style.getPropertyValue('color-scheme').trim() === 'dark',
  }))
}

export function scales() {
  return rules(/^:root\[data-scale="(\d+)"\]$/).map(({ value }) => value)
}

function row(theme) {
  const label = document.createElement('label')
  label.className = 'theme'
  const input = document.createElement('input')
  input.type = 'radio'
  input.name = 'theme'
  input.value = theme.value
  const swatch = document.createElement('span')
  swatch.className = 'swatch'
  swatch.dataset.theme = theme.value
  swatch.setAttribute('aria-hidden', 'true')
  const name = document.createElement('span')
  name.textContent = theme.label
  label.append(input, swatch, name)
  return label
}

export function initPrefs(save) {
  const box = document.getElementById('theme')
  const scale = document.getElementById('scale')
  const shown = document.getElementById('scale-value')
  const list = themes()
  for (const [heading, dark] of [['Dark', true], ['Light', false]]) {
    const group = list.filter(t => t.dark === dark)
    if (!group.length) continue
    const title = document.createElement('p')
    title.className = 'group'
    title.textContent = heading
    box.append(title, ...group.map(row))
  }
  const sizes = scales()
  scale.max = String(sizes.length - 1)
  const paint = () => {
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) meta.content = getComputedStyle(root).getPropertyValue('--paper').trim()
    for (const input of box.querySelectorAll('input')) input.checked = input.value === root.dataset.theme
    scale.value = String(Math.max(0, sizes.indexOf(root.dataset.scale)))
    shown.textContent = `${root.dataset.scale}%`
    scale.setAttribute('aria-valuetext', `${root.dataset.scale}%`)
  }
  paint()
  box.addEventListener('change', e => {
    root.dataset.theme = e.target.value
    paint()
    save({ theme: e.target.value })
  })
  scale.addEventListener('input', () => {
    root.dataset.scale = sizes[Number(scale.value)]
    paint()
  })
  scale.addEventListener('change', () => save({ scale: Number(root.dataset.scale) }))
}
