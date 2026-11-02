import { el } from './dom.js'

const OK = ['pass', 'overridden']

function stages(gate) {
  if (!gate) {
    return {
      define: [false, 'Waiting for the session'],
      plan: [false, ''],
      implement: [false, ''],
      verify: [false, ''],
      deliver: [false, ''],
    }
  }
  const reviewers = gate.reviewers || []
  const verified = reviewers.length > 0 && reviewers.every(r => OK.includes(r.state))
  const name = path => path.split('/').pop()
  return {
    define: [!!gate.define, gate.define ? 'Requirements agreed' : 'No agreed requirements yet'],
    plan: [!!gate.plan, gate.plan ? `${name(gate.plan)} · research ${gate.research ? 'done' : 'skipped'}` : 'Needs a plan: /knackpack:plan-implementation'],
    implement: [!!gate.head && !!gate.plan && reviewers.some(r => r.state !== 'none' && r.state !== 'stale'), gate.head ? `${gate.branch ? `On ${gate.branch} at` : 'At'} ${gate.head.slice(0, 7)}` : "Couldn't read the current commit"],
    verify: [verified, !verified ? 'Both reviews must pass on this commit' : reviewers.some(r => r.state === 'overridden') ? 'Reviews done on this commit, with an override' : 'Both reviews pass on this commit'],
    deliver: [!!gate.allowed, gate.allowed ? 'Claude can push this commit' : 'Push held until it has:'],
  }
}

export function paintPath(root, gate) {
  const all = stages(gate)
  let current = false
  for (const li of root.children) {
    const [done, detail] = all[li.dataset.stage] ?? [false, '']
    const now = !done && !current && !!gate
    if (now) current = true
    li.className = done ? 'done' : now ? 'current' : ''
    li.querySelector('.detail').textContent = detail
  }
  const missing = root.querySelector('.missing')
  missing.replaceChildren(...(gate && !gate.allowed ? (gate.missing || []).map(m => el('li', '', m)) : []))
}
