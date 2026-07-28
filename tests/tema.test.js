import { describe, expect, it } from 'vitest'
import '../src/components/theme.js'

const { resolverTema } = globalThis.AgenKinTheme

describe('resolverTema', () => {
  it('respeta una preferencia guardada', () => {
    expect(resolverTema('dark', false)).toBe('dark')
    expect(resolverTema('light', true)).toBe('light')
  })

  it('usa la preferencia del sistema cuando no hay elección guardada', () => {
    expect(resolverTema(null, true)).toBe('dark')
    expect(resolverTema(null, false)).toBe('light')
  })
})
