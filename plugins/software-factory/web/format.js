export const VERDICTS = [['No blocking issues found', 'ok'], ['Changes required', 'bad'], ['Needs verification', 'warn']]

export function verdictClass(text) {
  const found = VERDICTS.find(([word]) => String(text || '').includes(word))
  return found ? found[1] : 'muted'
}

export function project(cwd) {
  return String(cwd || '').replace(/\/+$/, '').split('/').pop() || 'session'
}

export function ago(seconds) {
  if (!seconds) return ''
  const s = Math.max(0, Math.round(Date.now() / 1000 - seconds))
  if (s < 60) return 'just now'
  if (s < 3600) return `${Math.floor(s / 60)}m ago`
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`
  return `${Math.floor(s / 86400)}d ago`
}

export function dotClass(state) {
  return state === 'waiting' ? 'dot need' : state === 'working' ? 'dot busy' : state === 'failed' ? 'dot off' : 'dot'
}

export function intentRecord(records) {
  const rec = (records || []).find(r => r.current) || (records || [])[0]
  if (!rec) return { found: false }
  const lines = list => (list || []).map(e => `${e.id}: ${e.text}`)
  return { found: true, title: rec.title, open: lines(rec.open), agreed: lines(rec.agreed), assumed: lines(rec.assumed), built: [] }
}
