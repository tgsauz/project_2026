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
  discreta por estado (0 / 0.15 / 1.0). Medido, la columna se queda clavada
  en 17.79° sin responder al ratón.
  *Corrección 2026-10-14 (mecanismo):* el mecanismo vigente **no es el CCDIK** —
  se retiró (ADR-0008) y la columna se escribe proceduralmente desde `_process`.
  La influence discreta por estado sí se mantiene. El resto de este ADR
  (reparto por eje, cabeza a 0, cuerpo dueño del yaw) sigue vigente.
  *Corrección 2026-10-14 (ADR-0008):* una versión anterior atribuía esto al
  «target mal apuntado». Falsado: las cuatro rutas resuelven y ningún
  `SkeletonModifier3D` escribe huesos en esta versión del motor; la vía
  vigente es escritura procedural desde `_process`.
- **Cabeza** (`FullBodyIKController`, `HeadCCDIK`): influence por tabla de
  estado (0 / 0.25 / 0.35), y además se atenúa con `ads_weight`.

> **Corrección 2026-10-14 (T12).** El sector de cabeza **se borró entero**:
> `HeadCCDIK` (un `CCDIK3D`), `AimIKTarget` (su único objetivo) y
> `FullBodyIKController.gd` (305 líneas que ya no tenían ninguna función viva)
> se retiraron tras medirse inertes, por la misma razón de motor que el resto
> (ADR-0008): ningún `SkeletonModifier3D` escribe huesos en esta versión.
> La tabla de influencia de cabeza ya no describe ningún mecanismo.
>
> Lo que sobrevive de este ADR es el reparto de dos actores: **el cuerpo lleva
> el yaw, la columna lleva el pitch**. No hay un tercer competidor por el reparto
> de la mirada, y no lo habrá mientras no exista un modelo de cabeza.

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
3. El torso twist necesita el mismo overhaul que el pitch (offset procedural
   con pesos por eje, curva de respuesta; ver ADR-0008 — no corrección de
   ruta de solver).

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

> **Corrección 2026-10-14 (T12).** La primera consecuencia ya no se sostiene, por
> dos razones que conviene separar porque tienen fecha distinta:
>
> 1. **«Influence 0 siempre» era falso antes de T12.** No era un hecho medido
>    sino una decisión declarada que el código no cumplía: la tabla del propio
>    ADR da **0.25 en armado** y 0.35 en apuntado, y `WEIGHTS_ARMED` en el
>    código asignaba 0.25 al nodo. El sector de cabeza estaba mezclándose con
>    la mirada, solo que sobre un solver que no escribía huesos.
> 2. **Ahora es irrelevante.** Desde T12 el nodo `HeadCCDIK` no existe, así que
>    no hay influence que_valor. La afirmación ya no es falsa: es vacía.
>
> La segunda consecuencia (`ads_weight` se va, ver ADR-0007) no cambió de
> resultado, pero su causa también era inexacta: el consumidor desaparecía, no
> porque la influencia llegara a cero, sino porque lo que se atenúa era un
> solver inerte. La tercera sigue vigente: el torso es el único consumidor de
> mirada aparte del cuerpo.

## Estado transitorio

Durante el incremento del torso, la cabeza se deja en influence 0 **de forma
deliberada** para aislar el efecto de la columna. No es un descuido: es lo que
permite atribuir cualquier cambio visible a una sola causa.

> **Corrección 2026-10-14 (T12).** Esta sección se apoya en una premisa que
> **ya era falsa**: la cabeza no estaba en influence 0 «de forma deliberada»,
> sino que la tabla le daba 0.25 en armado y 0.35 en apuntado. Lo deliberado era
> la decisión escrita, no el comportamiento medido.
> Desde T12, además, no hay cabeza que aislar: el sector se borró por inerte.
> El método —atribuir cada cambio visible a una sola causa— sigue siendo válido
> y se ha seguido aplicando; lo que se queda sin sujeto es este incremento en
> concreto.

## Evidencia

`Docs/Diagnóstico — Desacoplamiento del arma.md`,
`Docs/Causa raíz — distorsión al cambiar a Aiming.md`,
`Docs/Especificación — Estado del sistema de arma.md`