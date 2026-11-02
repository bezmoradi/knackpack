const KEY = `sf-token-${location.port}`
const launchCode = new URLSearchParams(location.hash.slice(1)).get('c')
if (launchCode !== null) history.replaceState(null, '', location.pathname)
let token = sessionStorage.getItem(KEY) || ''

export function signedIn() {
  return token !== ''
}

export function forget() {
  token = ''
  sessionStorage.removeItem(KEY)
}

export async function exchange() {
  if (!launchCode) return
  const res = await fetch('/api/session', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ code: launchCode }), cache: 'no-store' }).catch(() => null)
  if (res && res.ok) {
    token = (await res.json()).token
    sessionStorage.setItem(KEY, token)
  }
}

export function events() {
  return fetch('/api/events', { headers: { Authorization: `Bearer ${token}` }, cache: 'no-store' })
}

export function api(path, body) {
  return fetch(path, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body), cache: 'no-store' })
}

export function upload(blob) {
  return fetch('/api/image', { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': blob.type }, body: blob, cache: 'no-store' })
}
