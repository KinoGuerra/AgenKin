---
name: AgenKin
description: Un asistente sereno que lleva fechas del correo a una Agenda confiable.
colors:
  ink: "#142033"
  ink-muted: "#536373"
  canvas: "#e3e9e8"
  surface: "#eff3f1"
  surface-soft: "#d7e1e2"
  signal-blue: "#0a8fdf"
  signal-blue-deep: "#1263d6"
  sky-wash: "#ccefff"
  lime-confirm: "#d8f36a"
  border: "#c4d0d3"
  danger: "#a83232"
  success: "#16845b"
  trust-navy: "#071b2a"
  commercial-blue: "#075a96"
  commercial-blue-hover: "#064b7c"
  white: "#ffffff"
typography:
  display:
    fontFamily: "Bahnschrift, Arial Narrow, Aptos, sans-serif"
    fontSize: "clamp(3.25rem, 6.3vw, 5.45rem)"
    fontWeight: 700
    lineHeight: 1.04
    letterSpacing: "-0.04em"
  headline:
    fontFamily: "Bahnschrift, Arial Narrow, Aptos, sans-serif"
    fontSize: "clamp(2rem, 4vw, 3.3rem)"
    fontWeight: 700
    lineHeight: 1.04
    letterSpacing: "-0.035em"
  title:
    fontFamily: "Bahnschrift, Arial Narrow, Aptos, sans-serif"
    fontSize: "1.2rem"
    fontWeight: 700
    lineHeight: 1.04
    letterSpacing: "-0.035em"
  body:
    fontFamily: "Aptos, Segoe UI, ui-sans-serif, system-ui, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  label:
    fontFamily: "ui-monospace, Cascadia Code, Consolas, monospace"
    fontSize: "0.76rem"
    fontWeight: 800
    lineHeight: 1.5
    letterSpacing: "0.13em"
rounded:
  input: "9px"
  control: "10px"
  inset: "11px"
  card: "14px"
  surface: "16px"
  pill: "100px"
spacing:
  xs: "0.35rem"
  sm: "0.7rem"
  md: "1rem"
  lg: "1.5rem"
  xl: "2rem"
components:
  button-primary:
    backgroundColor: "{colors.commercial-blue}"
    textColor: "{colors.white}"
    rounded: "{rounded.control}"
    padding: "0.7rem 1.1rem"
    height: "42px"
  button-primary-hover:
    backgroundColor: "{colors.commercial-blue-hover}"
    textColor: "{colors.white}"
    rounded: "{rounded.control}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "0.7rem 1.1rem"
    height: "42px"
  button-light:
    backgroundColor: "{colors.lime-confirm}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "0.7rem 1.1rem"
    height: "42px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.input}"
    padding: "0.72rem 0.8rem"
  plan-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
    padding: "1.65rem"
  trust-panel:
    backgroundColor: "{colors.trust-navy}"
    textColor: "{colors.white}"
    rounded: "{rounded.surface}"
    padding: "clamp(1.7rem, 4vw, 2.5rem)"
---

# Design System: AgenKin

## Overview

**Creative North Star: "Confianza primero"**

AgenKin se presenta como un asistente sereno, confiable, comercial y no invasivo. La interfaz hace visible un recorrido delicado —del correo a una fecha accionable— con superficies claras, tinta azul profunda y señales verdes que confirman sin convertir la experiencia en una alarma permanente.

El mundo visual ya está establecido y se extiende desde la landing persuasiva hasta el portal operativo. La jerarquía es editorial y compacta; la geometría toma de bandejas, fechas y recorridos sus marcos, filas y secuencias. La profundidad es ambiental: ayuda a separar capas y estados, pero nunca se vuelve ornamento.

**Key Characteristics:**

- Asistente sereno y directo, con confianza visible antes que grandilocuencia.
- Superficies claras y azul profundo, con verde reservado para progreso y confirmación.
- Titulares condensados, texto de lectura amplio y etiquetas técnicas discretas.
- Geometría contenida de bandejas, calendarios, filas y recorridos.
- Profundidad difusa y puntual, reforzada por tono, borde y desenfoque.

## Colors

La paleta combina neutrales fríos de baja saturación con azules de acción y señales verdes o lima usadas con intención.

### Primary

- **Azul de acción** (`signal-blue`, #0a8fdf): acciones generales, iconos funcionales, etiquetas y selección.
- **Azul comercial profundo** (`commercial-blue`, #075a96): llamadas principales de la landing; oscurece en hover mediante `commercial-blue-hover` (#064b7c).
- **Azul de recorrido** (`signal-blue-deep`, #1263d6): énfasis editorial, fechas y trazos del recorrido.

### Secondary

- **Verde de confirmación** (`success`, #16845b): estados exitosos, checks y conexiones activas.
- **Lima de certeza** (`lime-confirm`, #d8f36a): acento escaso en insignias y llamadas sobre fondos oscuros.

### Neutral

- **Tinta azul** (`ink`, #142033): texto principal y contenido de máxima jerarquía.
- **Tinta serena** (`ink-muted`, #536373): descripción, apoyo y metadatos.
- **Lienzo frío** (`canvas`, #e3e9e8): fondo general de tema claro.
- **Superficie papel** (`surface`, #eff3f1): controles, tarjetas y contenedores.
- **Superficie de apoyo** (`surface-soft`, #d7e1e2): capas secundarias y mezclas tonales.
- **Borde frío** (`border`, #c4d0d3): divisores y contornos de baja presencia.
- **Azul noche de confianza** (`trust-navy`, #071b2a): paneles de privacidad, cierre y pie.
- **Blanco nítido** (`white`, #ffffff): texto sobre acciones y fondos oscuros.

### Tertiary

- **Lavado celeste** (`sky-wash`, #ccefff): ambiente, fondos de iconos y superficies destacadas.
- **Rojo de riesgo** (`danger`, #a83232): errores y acciones peligrosas; nunca se usa como decoración.

### Named Rules

**The Confirmación Escasa Rule.** El verde y el lima señalan progreso, éxito o una decisión segura; no colorean superficies completas sin una función concreta.

**The Agenda Primero Rule.** El azul profundo conduce el recorrido y la Agenda conserva la prioridad visual; Calendar aparece como integración opcional, no como identidad dominante.

## Typography

**Display Font:** Bahnschrift (con Arial Narrow y Aptos como respaldo)

**Body Font:** Aptos (con Segoe UI y sans-serif del sistema como respaldo)

**Label/Mono Font:** ui-monospace (con Cascadia Code y Consolas como respaldo)

**Character:** La combinación contrapone titulares condensados y decisivos con una voz de lectura familiar y tranquila. Las etiquetas monoespaciadas introducen precisión operativa sin convertir la interfaz en una consola.

### Hierarchy

- **Display** (700, `clamp(3.25rem, 6.3vw, 5.45rem)`, 1.04): promesa principal de landing, con hasta 15 caracteres de ancho por línea como referencia visual.
- **Headline** (700, `clamp(2rem, 4vw, 3.3rem)`, 1.04): títulos de sección y llamados de cierre.
- **Title** (700, `1.2rem`, 1.04): títulos de tarjetas, pasos y módulos contenidos.
- **Body** (400, `1rem`, 1.5): lectura general; descripciones extensas se mantienen alrededor de 58–72ch.
- **Label** (800, `0.76rem`, `0.13em`, mayúsculas): categorías, estados y cejas editoriales.

### Named Rules

**The Dos Voces Rule.** Bahnschrift promete y estructura; Aptos explica y acompaña. No intercambiar sus funciones por sección.

**The Compacta, No Apretada Rule.** La jerarquía puede ser densa, pero conserva una altura de lectura de 1.5 y anchos de línea contenidos.

## Layout

La landing alterna contenedores centrados de 1160 px para contenido editorial y 1220 px para navegación, garantías, precios y llamadas amplias, siempre con un margen lateral mínimo de 1rem. El hero usa dos columnas asimétricas y un espacio fluido de 3–8rem; las secciones respiran verticalmente con `clamp(5rem, 9vw, 8rem)`.

La grilla colapsa con intención: a 900 px el hero, la propuesta y los bloques de confianza pasan a una columna; a 720 px aparecen navegación móvil y recorrido vertical; a 520 px se compactan acciones, garantías y paneles sin ocultar la acción primaria. El portal conserva el mismo vocabulario mediante paneles, tarjetas de estado y una grilla operativa que pasa de varias columnas a lectura lineal.

El ritmo base se concentra en 0.35rem, 0.7rem, 1rem, 1.5rem y 2rem. Las separaciones grandes crecen con `clamp()`; los componentes internos se mantienen compactos para que la interfaz siga siendo escaneable.

## Elevation & Depth

El sistema es tonal por defecto y elevado solo cuando la jerarquía lo necesita. Fondo, superficie, superficie suave y borde resuelven la mayoría de las capas; las sombras difusas sostienen navegación flotante, paneles de confianza, menús y tarjetas destacadas. Los gradientes son ambientales y localizados, nunca un relleno ornamental genérico.

### Shadow Vocabulary

- **Ambiente global** (`0 22px 70px rgb(17 26 46 / 14%)`): diálogos, menús móviles y superficies que deben separarse claramente del lienzo.
- **Navegación flotante** (`0 10px 35px rgb(17 26 46 / 7%)`): cabecera pública translúcida.
- **Confianza profunda** (`0 28px 80px rgb(7 27 42 / 24%)`): panel oscuro de privacidad del hero.
- **Selección suave** (`0 20px 55px color-mix(in srgb, var(--verde) 12%, transparent)`): plan destacado y estados equivalentes.

### Named Rules

**The Profundidad Ambiental Rule.** Una sombra debe explicar una capa, una selección o un estado flotante; si solo adorna, se elimina.

## Shapes

La forma base es un rectángulo contenido con esquinas suavemente curvas: 9 px en campos, 10 px en controles, 14 px en tarjetas y 16 px en superficies protagonistas. Los pills de 100 px se reservan para insignias o estados breves. Líneas, divisores y contornos de 1 px evocan bandejas y filas; el recorrido usa nodos redondeados y trazos con extremos circulares.

El logotipo introduce una asimetría puntual (`9px 3px 9px 3px`), pero no convierte esa silueta en un patrón general. Los círculos quedan reservados para indicadores, iconos contenidos y controles de expandir.

## Components

Los componentes se sienten refinados y contenidos: responden con pequeños cambios de tono, desplazamiento o subrayado y mantienen estados de foco inequívocos.

### Buttons

- **Shape:** esquinas controladas (10 px), altura mínima de 42 px y padding de `0.7rem 1.1rem`; la acción del hero alcanza 50 px.
- **Primary:** azul comercial profundo sobre blanco en la landing y azul de acción sobre blanco en superficies operativas.
- **Hover / Focus:** oscurecimiento de tono y elevación de 1 px; foco visible celeste de 3 px con offset de 3 px.
- **Secondary / Ghost / Light:** superficie con borde para secundaria, fondo transparente y azul para texto, lima sobre azul noche para cierres de alta confianza.

### Chips

- **Style:** pills compactos sobre superficie suave o lima, con tipografía entre 0.64rem y 0.68rem y peso alto.
- **State:** color de señal únicamente cuando comunica un estado real; texto y forma sostienen el significado sin depender del color.

### Cards / Containers

- **Corner Style:** 14 px en planes; 16 px en paneles protagonistas y operativos.
- **Background:** superficie papel o mezcla tonal con superficie suave; azul noche para compromisos de confianza.
- **Shadow Strategy:** planas por defecto, con elevación ambiental solo en selección o jerarquía destacada.
- **Border:** contorno frío de 1 px; divisores lineales para listas editoriales.
- **Internal Padding:** entre 1rem y 2rem; las tarjetas de plan usan 1.65rem.

### Inputs / Fields

- **Style:** superficie papel, borde frío de 1 px, esquinas de 9 px y padding de `0.72rem 0.8rem`.
- **Focus:** outline celeste de 3 px separado 3 px del control.
- **Error / Disabled:** rojo de riesgo para error; controles deshabilitados conservan forma y reducen opacidad a 0.55.

### Navigation

La cabecera pública es una superficie translúcida y difusa de 64 px, con enlaces compactos y subrayado azul animado. En móvil se convierte en un menú flotante de una columna; el portal adopta una barra lateral azul noche con estados activos tonales y texto claro.

### Trust Panel

El panel de privacidad combina azul noche, inset tenue de 1 px, radio de 16 px y un único sello lima. En móvil se compacta a una fila de icono y promesa, preservando el mensaje principal y retirando detalle secundario.

### Journey Flow

El recorrido es la firma visual de AgenKin: nodos de bandeja, correo y calendario conectados por una línea azul-verde. En escritorio se lee horizontalmente; debajo de 720 px se reemplaza por una secuencia vertical, no por una miniatura ilegible.

## Do's and Don'ts

### Do:

- **Do** mantener el azul como guía de acción y el verde como confirmación verificable.
- **Do** construir jerarquía con tono, borde, espacio y tipografía antes de sumar sombra.
- **Do** adaptar recorridos y grillas a una secuencia móvil explícita en lugar de comprimirlos.
- **Do** mostrar foco visible, estados textuales y alternativas para movimiento reducido.
- **Do** conservar el mundo establecido entre landing y portal; las variaciones responden al modo de uso, no a un rebrand.

### Don't:

- **Don't** usar verde, lima o rojo como decoración sin significado de estado.
- **Don't** reemplazar la geometría contenida por cápsulas generalizadas o tarjetas excesivamente redondas.
- **Don't** agregar profundidad ornamental, glassmorphism gratuito o gradientes que no expliquen jerarquía.
- **Don't** introducir tipografías, dependencias o iconografías nuevas cuando el sistema existente ya cubre la función.
- **Don't** prometer automatización infalible: la confianza visual siempre acompaña estados honestos y control del usuario.
