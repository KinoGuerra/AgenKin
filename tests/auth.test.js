import { describe, expect, it, vi } from 'vitest'
import { entornoWebServido, googleAuthHabilitado } from '../src/services/auth.js'

describe('estado del ingreso con Google', () => {
  it('rechaza la ejecución directa como archivo local', () => {
    expect(entornoWebServido({ protocol: 'file:' })).toBe(false)
    expect(entornoWebServido({ protocol: 'https:' })).toBe(true)
  })

  it('lee el estado público del proveedor en Supabase Auth', async () => {
    const fetcher = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ external: { google: true } }),
    })

    await expect(googleAuthHabilitado(fetcher)).resolves.toBe(true)
    expect(fetcher).toHaveBeenCalledOnce()
  })
})
