import { describe, expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'
import type { ContextCategory, SessionUsage } from 'claude-code'

import { cellWidths, compactThreshold, formatTokens } from '../hooks/register'

const SURFACES = ['terminal', 'desktop'] as const

// 200k window less a 20k output reserve less the CLI's 13k summary buffer
const THRESHOLD = 167_000

function usage(
  categories: ContextCategory[],
  used: number,
  { window = 200_000, autoCompact = true }: { window?: number; autoCompact?: boolean } = {},
): SessionUsage {
  const percentage = Math.round((used / window) * 100)
  return {
    startedAt: 0,
    rateLimits: [],
    context: {
      tokens: used,
      window,
      percent: percentage,
      breakdown: {
        categories,
        totalTokens: used,
        maxTokens: window,
        rawMaxTokens: window,
        autocompactSource: 'auto',
        percentage,
        gridRows: [],
        model: 'test-model',
        memoryFiles: [],
        mcpTools: [],
        agents: [],
        isAutoCompactEnabled: autoCompact,
        ...(autoCompact ? { autoCompactThreshold: THRESHOLD } : {}),
        apiUsage: null,
      },
    },
  } as SessionUsage
}

function row(name: string, tokens: number, color: string, kind: ContextCategory['kind']): ContextCategory {
  return { name, tokens, color, kind, isDeferred: kind === 'deferred' }
}

// System prompt shares Free space's colour, as it does in a real session, and is
// the largest System row, so the colour rule has to skip it
function rows(messages: number): ContextCategory[] {
  return [
    row('System prompt', 12_000, 'inactive', 'used'),
    row('System tools', 3_000, 'subtle', 'used'),
    row('MCP tools', 4_000, 'success', 'used'),
    row('MCP server instructions', 1_000, 'mcpInstructions', 'used'),
    row('Custom agents', 1_000, 'suggestion', 'used'),
    row('Memory files', 2_000, 'remember', 'used'),
    row('Skills', 2_000, 'skill', 'used'),
    row('Messages', messages, 'permission', 'used'),
    row('MCP tools (deferred)', 9_000, 'suggestion', 'deferred'),
    row('Free space', 170_000 - messages, 'inactive', 'free'),
    row('Autocompact buffer', 33_000, 'warning', 'buffer'),
  ]
}

const BEFORE = usage(rows(15_000), 40_000)
const AFTER = usage(rows(45_000), 70_000)
const NO_AUTOCOMPACT = usage(rows(15_000), 40_000, { autoCompact: false })

function bandProps(bodyColumns = 100) {
  return {
    hasSurvey: false,
    isWorking: false,
    maxRows: 10,
    bodyColumns,
    scroll: { offset: 0, bodyRows: 9 },
    view: {},
  }
}

function mountBand($: Engine, surface: (typeof SURFACES)[number], props = bandProps()) {
  return $.ui.mount({ plugin: 'context-bar', surface, component: 'AbovePrompt', props })
}

/** Stands in for the engine beneath the plugin: start, command registry, turn end, usage, env, and its own drawing. */
function engine(on: On, usageNow: () => SessionUsage, env: Record<string, string> = {}) {
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('turn.complete', () => ({ text: '' }))
  on('session.usage', () => ({ value: usageNow() }))
  on('env.get', ($, e) => ({ value: env[e.name] }))
  on('ui.render', () => ({ type: 'engine', ref: 0 }))
}

const COMMAND = {
  command: 'context-bar',
  args: '',
  origin: { kind: 'composer' },
  presentation: { isFullscreen: false, columns: 100 },
} as const

describe('formatTokens', () => {
  test('rounds to the k/M labels the bar prints', () => {
    expect(formatTokens(0)).toBe('0')
    expect(formatTokens(999)).toBe('999')
    expect(formatTokens(3_100)).toBe('3.1k')
    expect(formatTokens(30_000)).toBe('30k')
    expect(formatTokens(200_000)).toBe('200k')
    expect(formatTokens(1_000_000)).toBe('1M')
  })
})

describe('compactThreshold', () => {
  test('no override keeps the reported threshold', () => {
    expect(compactThreshold(967_000, undefined)).toBe(967_000)
    expect(compactThreshold(967_000, '')).toBe(967_000)
  })

  test('a percent override applies to the window less its output reserve', () => {
    // 1M window: reported 967k, so 980k effective; 40% of it is 392k
    expect(compactThreshold(967_000, '40')).toBe(392_000)
  })

  test('an override never raises the threshold past the reported one', () => {
    expect(compactThreshold(967_000, '100')).toBe(967_000)
  })

  test('a malformed or out-of-range override is ignored', () => {
    expect(compactThreshold(967_000, 'abc')).toBe(967_000)
    expect(compactThreshold(967_000, '0')).toBe(967_000)
    expect(compactThreshold(967_000, '150')).toBe(967_000)
  })
})

describe('cellWidths', () => {
  test('fills exactly the bar width', () => {
    const rows = [
      { name: 'a', tokens: 1, color: 'x' },
      { name: 'b', tokens: 1, color: 'x' },
      { name: 'c', tokens: 1, color: 'x' },
    ]
    expect(cellWidths(rows, 10).reduce((a, b) => a + b, 0)).toBe(10)
  })

  test('a tiny category still gets one cell', () => {
    const rows = [
      { name: 'tiny', tokens: 10, color: 'x' },
      { name: 'huge', tokens: 199_990, color: 'x' },
    ]
    expect(cellWidths(rows, 20)).toEqual([1, 19])
  })

  test('zero tokens or zero width draws nothing', () => {
    expect(cellWidths([{ name: 'a', tokens: 0, color: 'x' }], 10)).toEqual([0])
    expect(cellWidths([{ name: 'a', tokens: 5, color: 'x' }], 0)).toEqual([0])
  })
})

for (const surface of SURFACES) {
  describe(`band on ${surface}`, () => {
    test('label measures used tokens against the auto-compact point', async ($, on) => {
      engine(on, () => BEFORE)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      expect(await band.find({ type: 'Text', text: ' 40k of 167k (24%) ' })).toBeDefined()
    })

    test('a percent override moves the auto-compact point', async ($, on) => {
      engine(on, () => BEFORE, { CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: '40' })
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      // 40% of (167k + 13k) is 72k
      expect(await band.find({ type: 'Text', text: ' 40k of 72k (56%) ' })).toBeDefined()
      expect(await band.find({ type: 'Text', text: /Free 32k/ })).toBeDefined()
    })

    test('with auto-compact off the bar measures against the whole window', async ($, on) => {
      engine(on, () => NO_AUTOCOMPACT)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      expect(await band.find({ type: 'Text', text: ' 40k of 200k (20%) ' })).toBeDefined()
      expect(await band.find({ type: 'Text', text: /Free 160k/ })).toBeDefined()
    })

    test('legend groups /context rows into System, MCP, Memory, Skills, Messages and Free', async ($, on) => {
      engine(on, () => BEFORE)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      const legend = (await band.findAll({ type: 'Text', text: /^ [A-Za-z]+ [\d.]+k?$/ })).map(t => t.text)
      expect(legend).toEqual([' System 16k', ' MCP 5k', ' Memory 2k', ' Skills 2k', ' Messages 15k', ' Free 127k'])
      for (const gone of [/System prompt/, /System tools/, /deferred/, /Autocompact buffer/, /Free space/]) {
        expect(await band.find({ type: 'Text', text: gone })).toBeUndefined()
      }
    })

    test('a group with no tokens is left out', async ($, on) => {
      const noMcp = usage(
        rows(15_000).filter(r => !r.name.startsWith('MCP ')),
        35_000,
      )
      engine(on, () => noMcp)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      expect(await band.find({ type: 'Text', text: /MCP/ })).toBeUndefined()
      expect(await band.find({ type: 'Text', text: /System 16k/ })).toBeDefined()
    })

    test('a category the mod does not know joins System', async ($, on) => {
      const extra = usage([...rows(15_000), row('Plugin widgets', 3_000, 'widget', 'used')], 43_000)
      engine(on, () => extra)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      expect(await band.find({ type: 'Text', text: /System 19k/ })).toBeDefined()
    })

    test('System is drawn in the claude colour, not grey like Free', async ($, on) => {
      engine(on, () => BEFORE)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      const swatches = (await band.findAll({ type: 'Text', text: /^■$/ })).map(t => t.props.color)
      expect(swatches).toEqual(['claude', 'success', 'remember', 'skill', 'permission', 'inactive'])
    })

    if (surface === 'terminal') {
      test('bar blocks, label and the blank cells under [-] fill the band width', async ($, on) => {
        engine(on, () => BEFORE)
        await $.session.start({ cwd: '/', surface, isInteractive: true })
        const band = await mountBand($, surface, bandProps(80))

        const blocks = (await band.findAll({ type: 'Text', text: /^█+$/ })).filter(
          b => b.props.color !== undefined,
        )
        const cells = blocks.reduce((sum, b) => sum + String(b.text).length, 0)
        expect(blocks).toHaveLength(6)
        expect(cells + ' 40k of 167k (24%) '.length + 4).toBe(80)
      })
    } else {
      test('bar segments grow by share so the label never wraps off the row', async ($, on) => {
        engine(on, () => BEFORE)
        await $.session.start({ cwd: '/', surface, isInteractive: true })
        const band = await mountBand($, surface, bandProps(80))

        const boxes = await band.findAll({ type: 'Box' })
        const segments = boxes.filter(b => b.props.backgroundColor !== undefined)
        // thousandths of 167k: 16k, 5k, 2k, 2k, 15k, 127k
        expect(segments.map(b => [b.props.backgroundColor, b.props.flexGrow])).toEqual([
          ['claude', 96],
          ['success', 30],
          ['remember', 12],
          ['skill', 12],
          ['permission', 90],
          ['inactive', 760],
        ])
        expect(await band.find({ type: 'Text', text: /^█/ })).toBeUndefined()
        const labelBox = boxes.find(b => b.props.flexShrink === 0)
        expect(labelBox?.text).toBe(' 40k of 167k (24%) ')
      })
    }

    test('turn.complete brings the bar up to date', async ($, on) => {
      let current = BEFORE
      engine(on, () => current)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      current = AFTER
      await $.turn.complete({ answer: '', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })

      expect(await band.find({ type: 'Text', text: ' 70k of 167k (42%) ' })).toBeDefined()
    })

    test('/context-bar hides the bar, and again shows it', async ($, on) => {
      engine(on, () => BEFORE)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface)

      expect((await $.command.run(COMMAND)).text).toBe('Context bar hidden.')
      expect(await band.find({ type: 'Text', text: /of 167k/ })).toBeUndefined()

      expect((await $.command.run(COMMAND)).text).toBe('Context bar shown.')
      expect(await band.find({ type: 'Text', text: /of 167k/ })).toBeDefined()
    })

    test('yields the band to a survey', async ($, on) => {
      engine(on, () => BEFORE)
      await $.session.start({ cwd: '/', surface, isInteractive: true })
      const band = await mountBand($, surface, { ...bandProps(), hasSurvey: true })

      expect(await band.find({ type: 'Text', text: /of 167k/ })).toBeUndefined()
    })
  })
}
