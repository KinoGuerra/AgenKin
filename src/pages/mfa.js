import '../components/theme.js'
import { mostrarAviso, setCargando } from '../components/ui.js'
import { cerrarSesion, obtenerContextoSesion } from '../services/auth.js'
import { supabase } from '../services/supabase.js'
import { rutaPermitida } from '../utils/validaciones.js'
import { rutaPublica } from '../config/env.js'

const formulario = document.querySelector('[data-mfa-form]')
const enrolamiento = document.querySelector('[data-mfa-enrolamiento]')
const titulo = document.querySelector('[data-mfa-titulo]')
const descripcion = document.querySelector('[data-mfa-descripcion]')
let factorId

function destinoSeguro() {
  const destino = new URLSearchParams(window.location.search).get('destino')
  return destino === 'admin.html' ? destino : 'admin.html'
}

async function prepararFactor() {
  const contexto = await obtenerContextoSesion()
  if (!contexto) {
    window.location.replace(rutaPublica('index.html'))
    return
  }
  if (!rutaPermitida(contexto.perfil, 'admin')) {
    window.location.replace(rutaPublica('app.html'))
    return
  }

  const { data: nivel, error: errorNivel } = await supabase.auth.mfa
    .getAuthenticatorAssuranceLevel()
  if (errorNivel) throw errorNivel
  if (nivel?.currentLevel === 'aal2') {
    window.location.replace(rutaPublica(destinoSeguro()))
    return
  }

  const { data: factores, error: errorFactores } = await supabase.auth.mfa.listFactors()
  if (errorFactores) throw errorFactores
  const verificado = factores?.totp?.[0]
  if (verificado) {
    factorId = verificado.id
    titulo.textContent = 'Verificá tu identidad'
    descripcion.textContent = 'Ingresá el código vigente de tu aplicación autenticadora.'
    formulario.classList.remove('oculto')
    formulario.codigo.focus()
    return
  }

  const noVerificados = (factores?.all || [])
    .filter((factor) => factor.factor_type === 'totp' && factor.status === 'unverified')
  await Promise.all(noVerificados.map((factor) => supabase.auth.mfa.unenroll({
    factorId: factor.id,
  })))

  const { data: nuevo, error: errorEnrolamiento } = await supabase.auth.mfa.enroll({
    factorType: 'totp',
    friendlyName: 'AgenKin administración',
  })
  if (errorEnrolamiento) throw errorEnrolamiento

  factorId = nuevo.id
  titulo.textContent = 'Protegé la administración'
  descripcion.textContent = 'Configurá un segundo factor antes de ingresar al panel.'
  document.querySelector('[data-mfa-qr]').src = nuevo.totp.qr_code
  document.querySelector('[data-mfa-secreto]').textContent = nuevo.totp.secret
  enrolamiento.classList.remove('oculto')
  formulario.classList.remove('oculto')
  formulario.codigo.focus()
}

formulario.addEventListener('submit', async (evento) => {
  evento.preventDefault()
  const boton = evento.submitter
  const codigo = String(new FormData(formulario).get('codigo') || '').trim()
  if (!/^\d{6}$/.test(codigo)) {
    mostrarAviso('Ingresá los seis dígitos del autenticador.', 'error')
    return
  }

  setCargando(boton, true, 'Verificando…')
  try {
    const { error } = await supabase.auth.mfa.challengeAndVerify({ factorId, code: codigo })
    if (error) throw error
    window.location.replace(rutaPublica(destinoSeguro()))
  } catch {
    mostrarAviso('El código no es válido o venció. Intentá nuevamente.', 'error')
    formulario.codigo.select()
  } finally {
    setCargando(boton, false)
  }
})

document.querySelector('[data-logout]').addEventListener('click', async (evento) => {
  setCargando(evento.currentTarget, true)
  try {
    await cerrarSesion()
  } catch {
    mostrarAviso('No se pudo cerrar la sesión.', 'error')
    setCargando(evento.currentTarget, false)
  }
})

prepararFactor().catch(() => {
  titulo.textContent = 'No pudimos preparar la verificación'
  descripcion.textContent = 'Cerrá sesión e intentá nuevamente.'
  mostrarAviso('No se pudo configurar el segundo factor.', 'error')
})
