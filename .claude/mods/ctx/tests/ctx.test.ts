import { describe, expect, test } from 'claude-code/testing'
import type { On, SessionContextUsage, SessionUsage } from 'claude-code'

// 200k window less a 20k output reserve less the CLI's 13k summary buffer
const THRESHOLD = 167_000

function usage(tokens: number | undefined, estimate: number): SessionUsage {
  return {
    startedAt: 0,
    rateLimits: [],
    context: {
      tokens,
      window: 200_000,
      breakdown: {
        categories: [],
        totalTokens: estimate,
        maxTokens: 200_000,
        rawMaxTokens: 200_000,
        autocompactSource: 'auto',
        percentage: 0,
        gridRows: [],
        model: 'test-model',
        memoryFiles: [],
        mcpTools: [],
        agents: [],
        isAutoCompactEnabled: true,
        autoCompactThreshold: THRESHOLD,
        apiUsage: null,
      },
    } as SessionContextUsage,
  } as SessionUsage
}

/** Stands in for the engine beneath the plugin, keeping the last status line. */
function engine(on: On, usageNow: () => SessionUsage) {
  const shown: { text: string | undefined } = { text: undefined }
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: 'box\n', stderr: '' } }))
  on('session.usage', () => ({ value: usageNow() }))
  on('env.get', () => ({ value: undefined }))
  on('ui.status', ($, e) => {
    shown.text = e.text
    return { value: undefined }
  })
  return shown
}

describe('ctx status line', () => {
  test('a new session shows the /context estimate before the first response', async ($, on) => {
    const shown = engine(on, () => usage(undefined, 21_000))
    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

    expect(shown.text).toBe('box · ~21k/200k · cpt 167k')
  })

  test('once a response reports tokens, the API count replaces the estimate', async ($, on) => {
    const shown = engine(on, () => usage(40_000, 38_000))
    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

    expect(shown.text).toBe('box · 40k/200k · cpt 167k')
  })
})
