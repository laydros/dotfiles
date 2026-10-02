import type { Engine, Register, SessionContextUsage } from 'claude-code'

// The CLI's compaction buffer: with no override, auto-compact fires this many
// tokens below the window less its output reserve
const SUMMARY_BUFFER = 13_000

// 84000 -> 84k, 1000000 -> 1.0M
const fmt = (n: number) => (n >= 1_000_000 ? `${(n / 1_000_000).toFixed(1)}M` : `${Math.round(n / 1000)}k`)

// The breakdown's autoCompactThreshold ignores CLAUDE_AUTOCOMPACT_PCT_OVERRIDE.
// The CLI computes the real one as min(floor(E * pct / 100), E - 13000), E being
// the window less its output reserve, and the reported threshold is E - 13000.
function threshold(reported: number, pctOverride: string | undefined) {
  const pct = parseFloat(pctOverride ?? '')
  if (!(pct > 0 && pct <= 100)) return reported
  const effective = reported + SUMMARY_BUFFER

  return Math.min(Math.floor(effective * (pct / 100)), reported)
}

// tokens is absent before the first response and right after a compaction;
// the compact part is left out when the engine returned no breakdown
function line(host: string, { tokens, window, breakdown }: SessionContextUsage, pctOverride: string | undefined) {
  if (tokens === undefined) return host || undefined
  const parts = [host, `${fmt(tokens)}/${fmt(window)}`].filter(Boolean)
  if (breakdown !== undefined) {
    const { isAutoCompactEnabled, autoCompactThreshold } = breakdown
    parts.push(
      isAutoCompactEnabled && autoCompactThreshold !== undefined
        ? `cpt ${fmt(threshold(autoCompactThreshold, pctOverride))}`
        : 'cpt off',
    )
  }

  return parts.join(' · ')
}

// `summary` estimates locally, so this sends no API request
async function draw($: Engine, host: string) {
  const { context } = await $.session.usage({ breakdown: 'summary' })
  const pctOverride = await $.env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE')
  $.ui.status(line(host, context, pctOverride))
}

export const register: Register = on => {
  let host = ''

  // Draw at once on load or reload instead of waiting for the fill to move
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    const { exitCode, stdout } = await $.process.run(['hostname', '-s'])
    if (exitCode === 0) host = stdout.trim()
    await draw($, host)

    return result
  })

  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('context')) {
      await draw($, host)
    }

    return next(e)
  })
}
