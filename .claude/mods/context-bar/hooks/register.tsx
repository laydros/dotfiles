import { atom, read, update } from 'claude-code'
import type { ContextCategory, EngineInterface, Register, SessionContextBreakdown } from 'claude-code'

import type { ContextBarRow, ContextBarSnapshot } from '../types'

const snapshot = atom({ plugin: 'context-bar', key: 'snapshot' } as const, null)
const isHidden = atom({ plugin: 'context-bar', key: 'isHidden' } as const, false)

const BLOCK = '█'
const SWATCH = '■'

/** 30000 -> "30k", 3100 -> "3.1k", 1000000 -> "1M". */
export function formatTokens(n: number): string {
  if (n >= 1_000_000) {
    const m = n / 1_000_000
    return `${m >= 10 ? Math.round(m) : Math.round(m * 10) / 10}M`
  }
  if (n >= 1000) {
    const k = n / 1000
    return `${k >= 10 ? Math.round(k) : Math.round(k * 10) / 10}k`
  }
  return String(Math.round(n))
}

/**
 * Splits `width` cells across rows in proportion to their tokens (largest
 * remainder). A row with any tokens gets at least one cell, taken from the
 * widest row, so a small category never disappears from the bar.
 */
export function cellWidths(rows: readonly ContextBarRow[], width: number): number[] {
  const total = rows.reduce((sum, row) => sum + Math.max(0, row.tokens), 0)
  if (total === 0 || width <= 0) return rows.map(() => 0)

  const exact = rows.map(row => (Math.max(0, row.tokens) / total) * width)
  const cells = exact.map(Math.floor)
  let left = width - cells.reduce((a, b) => a + b, 0)
  const byRemainder = exact
    .map((x, i) => ({ i, rem: x - Math.floor(x) }))
    .sort((a, b) => b.rem - a.rem)
  for (const { i } of byRemainder) {
    if (left <= 0) break
    cells[i] += 1
    left -= 1
  }

  for (let i = 0; i < rows.length; i++) {
    if (rows[i].tokens > 0 && cells[i] === 0) {
      const widest = cells.indexOf(Math.max(...cells))
      if (cells[widest] > 1) {
        cells[widest] -= 1
        cells[i] = 1
      }
    }
  }
  return cells
}

// The CLI's compaction buffer: with no override, auto-compact fires this many
// tokens below the window less its output reserve.
const SUMMARY_BUFFER = 13_000

/**
 * The token count auto-compact fires at. The breakdown's autoCompactThreshold
 * ignores CLAUDE_AUTOCOMPACT_PCT_OVERRIDE; the CLI computes the real one as
 * min(floor(E * pct / 100), E - 13000), E being the window less its output
 * reserve, and the reported threshold is E - 13000. Same rule as the ctx mod.
 */
export function compactThreshold(reported: number, pctOverride: string | undefined): number {
  const pct = parseFloat(pctOverride ?? '')
  if (!(pct > 0 && pct <= 100)) return reported
  const effective = reported + SUMMARY_BUFFER

  return Math.min(Math.floor(effective * (pct / 100)), reported)
}

/**
 * The groups the bar folds /context's `used` rows into, in drawing order, each
 * matched by row name (the breakdown's `kind` only says used, free, buffer or
 * deferred). A row no group matches joins System.
 */
const GROUPS: { name: string; matches: (row: string) => boolean }[] = [
  { name: 'System', matches: () => false },
  { name: 'MCP', matches: row => row.startsWith('MCP ') },
  { name: 'Memory', matches: row => row === 'Memory files' },
  { name: 'Skills', matches: row => row === 'Skills' },
  { name: 'Messages', matches: row => row === 'Messages' },
]

/**
 * Folds the /context categories into the GROUPS plus Free, measured against
 * the auto-compact point (the whole window when auto-compact is off). Groups
 * with no tokens are left out.
 *
 * Each group takes the colour of its largest row that is not Free's colour,
 * since System prompt and Free space share one.
 */
function collapse(b: SessionContextBreakdown, pctOverride: string | undefined): ContextBarSnapshot {
  const window =
    b.isAutoCompactEnabled && b.autoCompactThreshold !== undefined
      ? compactThreshold(b.autoCompactThreshold, pctOverride)
      : b.rawMaxTokens
  const freeColor = b.categories.find(c => c.kind === 'free')?.color ?? 'inactive'
  const members = new Map(GROUPS.map(g => [g.name, [] as ContextCategory[]]))
  for (const c of b.categories) {
    if (c.kind !== 'used') continue
    const group = GROUPS.find(g => g.matches(c.name)) ?? GROUPS[0]
    members.get(group.name)!.push(c)
  }

  const rows: ContextBarRow[] = []
  for (const g of GROUPS) {
    const list = members.get(g.name)!
    const tokens = list.reduce((sum, c) => sum + c.tokens, 0)
    if (tokens <= 0) continue
    const byTokens = [...list].sort((a, z) => z.tokens - a.tokens)
    const color = (byTokens.find(c => c.color !== freeColor) ?? byTokens[0]).color
    rows.push({ name: g.name, tokens, color })
  }
  rows.push({ name: 'Free', tokens: Math.max(0, window - b.totalTokens), color: freeColor })

  return {
    rows,
    used: b.totalTokens,
    window,
    percent: Math.round((b.totalTokens / window) * 100),
  }
}

async function refresh($: EngineInterface): Promise<void> {
  try {
    const usage = await $.session.usage({ breakdown: 'summary' })
    const b = usage.context.breakdown
    if (!b) return
    const next = collapse(b, await $.env.get('CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'))
    await update($, snapshot, () => next)
  } catch (err) {
    $.ui.log(`context-bar: could not read context usage: ${String(err)}`, { to: 'debug' })
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'context-bar',
      description: 'Show or hide the context window bar above the prompt',
    })
    const result = await next(e)
    await refresh($)

    return result
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($)

    return result
  })

  on('session.compact', async ($, e, next) => {
    const result = await next(e)
    await refresh($)

    return result
  })

  on('command.run', { command: 'context-bar' }, async $ => {
    let hidden = false
    await update($, isHidden, was => {
      hidden = !was
      return hidden
    })
    if (!hidden) await refresh($)

    return { text: hidden ? 'Context bar hidden.' : 'Context bar shown.' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (e.props.hasSurvey || (await read($, isHidden))) return next(e)
    const snap = await read($, snapshot)
    if (snap === null || snap.rows.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const label = ` ${formatTokens(snap.used)} of ${formatTokens(snap.window)} (${snap.percent}%) `

    // The label leads the row: the engine draws the band's [-] collapse button
    // over its right end.
    // The terminal draws a block per cell, so the bar is sized in cells. Other
    // surfaces draw text in a proportional font, where a cell count overflows
    // the band; there each segment is a coloured Box grown by its tokens.
    let segments
    if (e.surface === 'terminal') {
      const cells = cellWidths(snap.rows, Math.max(10, e.props.bodyColumns - label.length))
      segments = (
        <Text wrap="truncate">
          {snap.rows.map((row, i) => (
            <Text color={row.color}>{BLOCK.repeat(cells[i])}</Text>
          ))}
        </Text>
      )
    } else {
      // flexGrow is capped at 10000, so each row grows by its share in thousandths.
      const total = snap.rows.reduce((sum, row) => sum + Math.max(0, row.tokens), 0)
      segments = snap.rows
        .filter(row => row.tokens > 0)
        .map(row => (
          <Box
            width={0}
            minWidth={1}
            flexGrow={Math.max(1, Math.round((row.tokens / total) * 1000))}
            backgroundColor={row.color}
          >
            <Text> </Text>
          </Box>
        ))
    }

    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Box flexShrink={0}>
            <Text bold>{label}</Text>
          </Box>
          <Box flexDirection="row" flexGrow={1} flexShrink={1} overflow="hidden">
            {segments}
          </Box>
        </Box>
        <Text wrap="truncate">
          {snap.rows.map((row, i) => (
            <Text>
              {i > 0 ? '  ' : ''}
              <Text color={row.color}>{SWATCH}</Text>
              <Text dimColor>
                {' '}
                {row.name} {formatTokens(row.tokens)}
              </Text>
            </Text>
          ))}
        </Text>
      </Box>
    )
  })
}
