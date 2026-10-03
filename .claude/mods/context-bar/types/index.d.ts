/** One /context category, as the bar draws it. */
export type ContextBarRow = {
  name: string
  tokens: number
  /** Theme colour key, as /context reports it. */
  color: string
}

/** The last /context breakdown the bar took. */
export type ContextBarSnapshot = {
  rows: ContextBarRow[]
  /** Tokens in use. */
  used: number
  /** The compaction window measured against. */
  window: number
  /** used over window, whole percent. */
  percent: number
}

declare module 'claude-code' {
  interface PluginState {
    'context-bar': { snapshot: ContextBarSnapshot | null; isHidden: boolean }
  }
}
