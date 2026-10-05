import type { EngineInterface, Register, SessionRateLimit } from 'claude-code'

const H = 3_600_000

// The windows this mod reads, with their length and the short label it prints.
const WINDOWS: Record<string, { label: string; ms: number; recentMs: number; recentLabel: string }> = {
  five_hour: { label: '5h', ms: 5 * H, recentMs: H / 2, recentLabel: 'last 30 min' },
  seven_day: { label: '7d', ms: 168 * H, recentMs: 24 * H, recentLabel: 'last 24h' },
}

// Below this share of the window gone, a projection is noise.
const MIN_ELAPSED = 0.02
// No warning while more than this much is left.
const QUIET_ABOVE_LEFT = 80
// Projected use at reset (% of the window) at which each warning level starts.
const WARN_AT = [120, 150, 200]
// Readings kept per window, for the trend and the recent rate.
const MAX_SAMPLES = 400

export type Pace = {
  kind: string
  label: string
  used: number
  left: number
  resetsAt: number
  windowStart: number
  // Share of the window that has passed, 0 to 1.
  elapsed: number
  // Use an even pace would have reached by now, in percent.
  expectedUsed: number
  // expectedUsed - used: positive is under pace, negative is over.
  reserve: number
  // Use at reset if the window's average rate holds; null in the first minutes.
  projected: number | null
  // When the average rate reaches 100%, if before reset.
  runsOutAt: number | null
}

export function pace(limit: SessionRateLimit, now: number): Pace | null {
  const w = WINDOWS[limit.kind]
  if (!w || !limit.resetsAt) return null
  const resetsAt = Date.parse(limit.resetsAt)
  const windowStart = resetsAt - w.ms
  const elapsed = Math.min(1, Math.max(0, (now - windowStart) / w.ms))
  const used = limit.percentUsed
  const projected = elapsed >= MIN_ELAPSED ? used / elapsed : null
  const runsOutAt =
    projected !== null && projected > 100 && used > 0 ? windowStart + ((now - windowStart) * 100) / used : null
  return {
    kind: limit.kind,
    label: w.label,
    used,
    left: Math.max(0, 100 - used),
    resetsAt,
    windowStart,
    elapsed,
    expectedUsed: elapsed * 100,
    reserve: elapsed * 100 - used,
    projected,
    runsOutAt,
  }
}

// 0 = no warning; 1, 2, 3 = projected past 120%, 150%, 200% of the window.
export function warnLevel(p: Pace): number {
  if (p.left > QUIET_ABOVE_LEFT || p.projected === null) return 0
  return WARN_AT.filter(at => p.projected! > at).length
}

// What is left as a filled bar, with a mark where an even pace would leave it.
export function bar(left: number, paceLeft: number, width: number): string {
  const filled = Math.round((left / 100) * width)
  const mark = Math.min(width - 1, Math.max(0, Math.round((paceLeft / 100) * width)))
  let out = ''
  for (let i = 0; i < width; i++) out += i === mark ? '│' : i < filled ? '█' : '░'
  return out
}

const SPARKS = '▁▂▃▄▅▆▇█'

export function sparkline(values: readonly number[]): string {
  if (values.length === 0) return ''
  const lo = Math.min(...values)
  const span = Math.max(...values) - lo || 1
  return values.map(v => SPARKS[Math.round(((v - lo) / span) * (SPARKS.length - 1))]).join('')
}

export function duration(ms: number): string {
  const m = Math.max(0, Math.round(ms / 60_000))
  if (m < 60) return `${m}m`
  const h = Math.floor(m / 60)
  if (h < 48) return `${h}h ${m % 60}m`
  return `${Math.floor(h / 24)}d ${h % 24}h`
}

function clock(ms: number, withDay: boolean): string {
  return new Date(ms).toLocaleString('en-US', {
    weekday: withDay ? 'short' : undefined,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
}

// "13% under pace, lasts until reset" or "12% over pace, runs out 12:40 (1h 20m before reset)".
export function verdict(p: Pace): string {
  const gap = Math.round(Math.abs(p.reserve))
  const side = p.reserve >= 0 ? `${gap}% under pace` : `${gap}% over pace`
  if (p.runsOutAt === null) return `${side}, lasts until reset`
  const day = p.kind === 'seven_day'
  return `${side}, runs out ${clock(p.runsOutAt, day)} (${duration(p.resetsAt - p.runsOutAt)} before reset)`
}

type Sample = { t: number; used: number }

const sampleKey = (p: Pace) => `samples:${p.kind}:${p.resetsAt}`

// Keys end in the window's reset time; drop those whose window has reset.
async function prune($: EngineInterface, prefix: string, now: number): Promise<void> {
  for (const key of await $.store.keys()) {
    if (key.startsWith(prefix) && Number(key.split(':')[2]) < now) await $.store.delete(key)
  }
}

async function record($: EngineInterface, paces: readonly Pace[], now: number): Promise<void> {
  for (const p of paces) {
    const key = sampleKey(p)
    const list = ((await $.store.get(key)) as Sample[] | undefined) ?? []
    const last = list[list.length - 1]
    if (last && last.used === p.used && now - last.t < 5 * 60_000) continue
    await $.store.set(key, [...list, { t: now, used: p.used }].slice(-MAX_SAMPLES))
  }
  await prune($, 'samples:', now)
}

async function current($: EngineInterface): Promise<Pace[]> {
  const now = Date.now()
  return (await $.session.usage()).rateLimits.map(l => pace(l, now)).filter((p): p is Pace => p !== null)
}

// The five-hour window and when it resets; the seven-day window only while it warns.
export function statusText(paces: readonly Pace[]): string | undefined {
  const parts = paces
    .filter(p => p.kind === 'five_hour' || warnLevel(p) > 0)
    .map(p => {
      const day = p.kind === 'seven_day'
      const out = warnLevel(p) > 0 && p.runsOutAt !== null ? ` ! out ${clock(p.runsOutAt, day)}` : ''
      return `${p.label} ${Math.round(p.left)}% left${day ? '' : `, resets ${clock(p.resetsAt, false)}`}${out}`
    })
  return parts.length ? parts.join(' · ') : undefined
}

// Toasts once per window per level, so a warning repeats only when it gets worse.
async function warn($: EngineInterface, paces: readonly Pace[], now: number): Promise<void> {
  for (const p of paces) {
    const level = warnLevel(p)
    const key = `warned:${p.kind}:${p.resetsAt}`
    const before = Number((await $.store.get(key)) ?? 0)
    if (level <= before) continue
    await $.store.set(key, level)
    $.ui.toast(`${p.label} usage: ${Math.round(p.projected!)}% of the window at this pace. ${verdict(p)}.`, {
      timeoutMs: 15_000,
    })
  }
  await prune($, 'warned:', now)
}

async function refresh($: EngineInterface): Promise<Pace[]> {
  const now = Date.now()
  const paces = await current($)
  $.ui.status(statusText(paces))
  await record($, paces, now)
  await warn($, paces, now)
  return paces
}

async function report($: EngineInterface): Promise<string> {
  const now = Date.now()
  const paces = await current($)
  if (paces.length === 0) return 'No usage windows reported yet. They arrive with the first response of a session.'
  const blocks: string[] = []
  for (const p of paces) {
    const w = WINDOWS[p.kind]
    const day = p.kind === 'seven_day'
    const samples = ((await $.store.get(sampleKey(p))) as Sample[] | undefined) ?? []
    const recentFrom = samples.find(s => s.t >= now - w.recentMs)
    const lines = [
      `${p.label}  ${Math.round(p.left)}% left · resets in ${duration(p.resetsAt - now)} (${clock(p.resetsAt, day)})`,
      `    ${bar(p.left, 100 - p.expectedUsed, 40)}`,
      `    ${verdict(p)}`,
    ]
    if (recentFrom && recentFrom.t < now - 60_000) {
      const spent = p.used - recentFrom.used
      const even = ((now - recentFrom.t) / w.ms) * 100
      lines.push(`    ${w.recentLabel}: ${spent.toFixed(1)}% spent (even pace ${even.toFixed(1)}%)`)
    }
    if (day) lines.push(`    ${Math.floor((p.resetsAt - now) / (5 * H))} five-hour windows until reset`)
    if (samples.length > 1) {
      const shown = samples.slice(-40)
      lines.push(`    trend ${sparkline(shown.map(s => s.used))}  (used, last ${shown.length} readings)`)
    }
    blocks.push(lines.join('\n'))
  }
  return '```\n' + blocks.join('\n\n') + '\n```\nThe bar fills what is left; │ marks where an even pace would be.'
}

// One line for Claude beside every prompt: what is left of each window, and the pace.
export function contextLine(paces: readonly Pace[], now: number): string | undefined {
  if (paces.length === 0) return undefined
  const parts = paces.map(
    p =>
      `${p.label} ${Math.round(p.left)}% left, resets in ${duration(p.resetsAt - now)}; ${verdict(p)}${warnLevel(p) ? ' [WARN]' : ''}`,
  )
  return `Claude usage remaining, not used (account-wide): ${parts.join(' | ')}`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await $.command.register({
      name: 'quota',
      description: 'Show what is left of the usage windows, the pace and the trend',
    })
    await refresh($)
    return result
  })

  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('rateLimits')) await refresh($)
    return next(e)
  })

  on('command.run', { command: 'quota' }, async $ => ({ text: await report($) }))

  // Hands Claude the same figures beside every prompt, unseen by the user.
  on('prompt.submit', async ($, e, next) => {
    const line = contextLine(await refresh($), Date.now())
    if (!line) return next(e)
    return next({ ...e, context: [...(e.context ?? []), line] })
  })
}
