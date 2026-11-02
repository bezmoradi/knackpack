export type SoftwareFactoryPending = {
  id: string
  kind: 'permission'
  tool: string
  summary: string
} | null

declare module 'claude-code' {
  interface PluginState {
    'software-factory': { pending: SoftwareFactoryPending }
  }
}
