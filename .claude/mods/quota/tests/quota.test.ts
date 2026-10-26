import { describe, expect, test } from 'claude-code/testing'

import { bar, pace, parseUsage, reportText, sparkline, statusText, warnLevel } from '../hooks/register'

const H = 3_600_000
const NOW = Date.UTC(2026, 9, 5, 15, 0, 0)

// A five-hour window that resets `left` hours from NOW with `used` percent spent.
function fiveHour(used: number, hoursToReset: number) {
  return pace({ kind: 'five_hour', percentUsed: used, resetsAt: new Date(NOW + hoursToReset * H).toISOString() }, NOW)
}

describe('pace against the clock', () => {
  test('matches the CodexBar reading: 38% used with 2h35m to go is 10% in reserve and lasts', () => {
    const p = fiveHour(38, 2 + 35 / 60)!
    expect(Math.round(p.reserve)).toBe(10)
    expect(p.runsOutAt).toBeNull()
  })

  test('spending faster than the clock projects past 100% and names when it runs out', () => {
    // half the window gone, 75% used: 150% projected, runs out at 2/3 of the window
    const p = fiveHour(75, 2.5)!
    expect(Math.round(p.projected!)).toBe(150)
    expect(p.runsOutAt).toBe(NOW - 2.5 * H + (5 * H * 2) / 3)
  })

  test('the first minutes of a window give no projection, so one early burst cannot warn', () => {
    expect(fiveHour(5, 4.99)!.projected).toBeNull()
  })

  test('the seven-day window uses a seven-day clock', () => {
    const p = pace({ kind: 'seven_day', percentUsed: 21, resetsAt: new Date(NOW + 128 * H).toISOString() }, NOW)!
    expect(Math.round(p.expectedUsed)).toBe(24)
  })

  test('a window kind it does not know, or no reset time, is left out', () => {
    expect(pace({ kind: 'spend_limit', percentUsed: 50, resetsAt: new Date(NOW + H).toISOString() }, NOW)).toBeNull()
    expect(pace({ kind: 'five_hour', percentUsed: 50 }, NOW)).toBeNull()
  })
})

describe('when to warn', () => {
  test('never while more than 80% is left, however steep the start', () => {
    expect(warnLevel(fiveHour(19, 4.5)!)).toBe(0)
  })

  test('not while the projection stays within 120% of the window', () => {
    expect(warnLevel(fiveHour(55, 2.5)!)).toBe(0)
  })

  test('warns past 120%, and again at a higher level past 150% and 200%', () => {
    expect(warnLevel(fiveHour(65, 2.5)!)).toBe(1)
    expect(warnLevel(fiveHour(80, 2.5)!)).toBe(2)
    expect(warnLevel(fiveHour(63, 3.5)!)).toBe(3)
  })
})

describe('drawing', () => {
  test('the bar fills what is left and marks where an even pace would be', () => {
    expect(bar(60, 50, 10)).toBe('█████│░░░░')
  })

  test('the sparkline spans low to high and is empty with no readings', () => {
    expect(sparkline([])).toBe('')
    expect(sparkline([0, 50, 100])).toBe('▁▅█')
  })
})

describe('the /quota report', () => {
  const week = () => pace({ kind: 'seven_day', percentUsed: 8, resetsAt: new Date(NOW + 143 * H).toISOString() }, NOW)!
  const text = () => reportText([{ p: fiveHour(5, 4.67)! }, { p: week() }], NOW)

  test('has no code fence, which breaks on the phone where the reply follows "quota: " on the same line', () => {
    expect(text()).not.toContain('```')
  })

  test('bar lines fit a phone screen', () => {
    const bars = text().split('\n').filter(l => l.includes('│'))
    expect(bars.length).toBe(2)
    for (const l of bars) expect(l.length).toBeLessThanOrEqual(24)
  })

  test('leaves out the five-hour window count and the bar legend', () => {
    expect(text()).not.toContain('five-hour windows')
    expect(text()).not.toContain('marks where')
  })

  test('still shows what is left, the reset and the pace for each window', () => {
    expect(text()).toMatch(/^5h {2}95% left · resets in 4h 40m \(\d\d:\d\d\)$/m)
    expect(text()).toMatch(/^7d {2}92% left · resets in 5d 23h/m)
    expect(text()).toContain('under pace, lasts until reset')
  })
})

describe('status line', () => {
  test('the five-hour window shows its reset time; the seven-day window shows only what is left', () => {
    const week = pace({ kind: 'seven_day', percentUsed: 21, resetsAt: new Date(NOW + 128 * H).toISOString() }, NOW)!
    const text = statusText([fiveHour(38, 2 + 35 / 60)!, week])!
    expect(text).toMatch(/^5h 62% left - \d\d:\d\d · 7d 79% left$/)
  })

  test('a seven-day window on track to run out still shows no run-out time', () => {
    const week = pace({ kind: 'seven_day', percentUsed: 60, resetsAt: new Date(NOW + 100 * H).toISOString() }, NOW)!
    expect(warnLevel(week)).toBeGreaterThan(0)
    expect(statusText([week])).toBe('7d 40% left')
  })
})

describe('reading the usage endpoint', () => {
  test('reads utilization as percent used for the five-hour and seven-day windows', () => {
    const text = '{"five_hour":{"utilization":81.0,"resets_at":"2026-10-05T18:00:00.142569+00:00"},"seven_day":{"utilization":23.0,"resets_at":"2026-10-11T00:00:00+00:00"},"seven_day_opus":null}'
    expect(parseUsage(text)).toEqual([
      { kind: 'five_hour', percentUsed: 81, resetsAt: '2026-10-05T18:00:00.142569+00:00' },
      { kind: 'seven_day', percentUsed: 23, resetsAt: '2026-10-11T00:00:00+00:00' },
    ])
  })

  test('a reply it cannot read gives no windows, so the session reading is used instead', () => {
    expect(parseUsage('not json')).toEqual([])
    expect(parseUsage('{"five_hour":null}')).toEqual([])
  })
})
