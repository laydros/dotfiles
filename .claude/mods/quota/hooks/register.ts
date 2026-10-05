import type { Register, SessionRateLimit } from 'claude-code'

const LABELS: Record<string, string> = { five_hour: '5h', seven_day: '7d' }

// "5h 59% (resets 09:00)" for each window the last API response reported.
function describe(limits: readonly SessionRateLimit[]): string | undefined {
  const parts = limits
    .filter(l => l.kind in LABELS)
    .map(l => {
      const reset = l.resetsAt
        ? new Date(l.resetsAt).toLocaleString('en-US', {
            weekday: l.kind === 'seven_day' ? 'short' : undefined,
            hour: '2-digit',
            minute: '2-digit',
            hour12: false,
          })
        : undefined
      return `${LABELS[l.kind]} ${Math.round(l.percentUsed)}%${reset ? ` (resets ${reset})` : ''}`
    })
  return parts.length ? parts.join(' · ') : undefined
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    $.ui.status(describe((await $.session.usage()).rateLimits))
    return result
  })

  on('session.measure', ($, e, next) => {
    if (e.changed.includes('rateLimits')) $.ui.status(describe(e.rateLimits))
    return next(e)
  })

  // Hands Claude the same figures beside every prompt, unseen by the user.
  on('prompt.submit', async ($, e, next) => {
    const line = describe((await $.session.usage()).rateLimits)
    if (!line) return next(e)
    return next({ ...e, context: [...(e.context ?? []), `Claude usage windows (account-wide): ${line}`] })
  })
}
