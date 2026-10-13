# Reparto del apuntado: torso, cabeza y cuerpo

## Estado

Aceptado — 2026-10-13. Define el comportamiento objetivo; la implementación
se ejecuta por tickets.

## Contexto

El sector de apuntado tiene hoy tres candidatos a producir rotación y ninguno
coordina con los otros:

- **Cuerpo** (`CharacterController`): lleva el yaw completo. Es el único que
  gira hoy.
- **Torso** (`SpineLookAtController`, CCDIK `spine_01 → spine_02`): influence
  discreta por estado (0 / 0.15 / 1.0). Con su target mal apuntado no
  converge: medido, la columna se queda clavada en 17.79° sin responder al
  ratón.
- **Cabeza** (`FullBodyIKController`, `HeadCCDIK`): influence por tabla de
  estado (0 / 0.25 / 0.35), y además se atenúa con `ads_weight`.

## Decisión

Reparto por estado, con una sola autoridad por eje:

| Estado | Yaw | Pitch |
|---|---|---|
| **Unarmed** | cuerpo | ninguno |
| **Armed** | cuerpo (completo) | torso parcial, sin cámara |
| **Aiming** | cuerpo | torso completo |

La cabeza queda **sin pitch ni yaw en los tres estados**. No recibe influence
en ningún estado. Es una posición temporal, no el estado final.

## Por qué el cuerpo conserva el yaw ahora

El reparto de yaw entre cuerpo y torso (torso twist hasta un límite, luego el
cuerpo completa, como en shooters AAA) es el comportamiento objetivo, pero
**no en este incremento**. Cambiarlo requiere:

1. Medir cuánto yaw puede absorber el torso antes de que la Pose de locomoción
   deje de tener sentido (caminar de lado con torso girado 40° se ve roto).
2. Definir el límite y la transición entre torso y cuerpo sin solape — dos
  Sumiders sobre el mismo yaw se transparentan y ambos se sienten mal.
3. El torso twist necesita el mismo overhaul que el pitch (target correcto,
   influence por eje, curva de respuesta).

Hacerlo sin esas tres cosas produce un torso que gira de más y un cuerpo que no
compensa. Ver ADR-0006.

## El 180° del rig

`VisualsComponent/Rig` lleva rotación de 180° en Y (ADR-0002). Los objetivos de
IK que cuelgan **dentro** del rig (el de cabeza, el de la columna) heredan esa
rotación. Cualquier objetivo construido en espacio mundo y escrito en un nodo
del rig queda doblemente invertido.

Corolario práctico: con la cabeza en influence 0 el tema es inofensivo, pero
al reintroducir influence hay que construir el objetivo **en espacio del
hueso** o proyectarlo explícitamente, no escribir mundo en un nodo del rig.

## Consecuencias

- `HeadCCDIK.influence = 0` siempre, hasta que exista el modelo de cabeza.
- El único consumidor de `ads_weight` desaparece con ello. Ver ADR-0007.
- El torso pasa a ser el único consumidor de mirada aparte del cuerpo, lo que
  elimina la ambigüedad de "quién lleva el pitch".

## Estado transitorio

Durante el incremento del torso, la cabeza se deja en influence 0 **de forma
deliberada** para aislar el efecto de la columna. No es un descuido: es lo que
permite atribuir cualquier cambio visible a una sola causa.

## Evidencia

`Docs/Diagnóstico — Desacoplamiento del arma.md`,
`Docs/Causa raíz — distorsión al cambiar a Aiming.md`,
`Docs/Especificación — Estado del sistema de arma.md`