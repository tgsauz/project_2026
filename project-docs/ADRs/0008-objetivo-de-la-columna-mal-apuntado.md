# El objetivo de la columna se apunta mal

## Estado

Aceptado — 2026-10-13.

## Contexto

Medido: la columna **no responde al ratón**. `spine_01 → spine_02` da
17.79° idénticos con pitch 0, +30° y −30°. Sin arma es 1.20°. El torso no
responde al puntero en ningún caso.

El CCDIK de la columna declara:

```
root = spine_01, end = spine_02
target_node = ../LookAtTarget
influencia = 1.0
```

Resuelto desde el esqueleto, `../LookAtTarget` **no resuelve**: el nodo
`LookAtTarget` es hijo **directo** del esqueleto, no hermano de él. El
ensamblador del rig lo añade con `_skeleton.add_child(target)` y a la vez le
pasa la ruta `../LookAtTarget`.

Consecuencia observable: el punto objetivo se aleja eternamente —medido en
`y = −194 m` con el personaje en caída— y el solver no converge a nada. Los
17.79° son la pose del clip de apuntado, no un giro calculado.

Es la **misma clase de error** que el del IK de brazo: un `NodePath` escrito
con un nivel de más. Se detectaron por medición, no por lectura; ninguno de los
dos producía error en consola.

## Decisión

La ruta del objetivo es `LookAtTarget`, relativo al esqueleto. Y se deja de
componer la ruta a mano: el nodo objetivo y su ruta se resuelven en un solo
sitio, que es quien configura el solver.

## Por qué no basta con corregir la ruta

Corregir la ruta **empeora** la situación visible, porque destapa un segundo
defecto que estaba enmascarado. El objetivo, cuando influence < 1, se interpola
hacia un neutral que es "un punto por encima de la pelvis" (`SpineLookAt-
Controller.gd:108`). Es decir: con influence 0.15 (armed) el torso se interpola
hacia **mirar al techo**. Hoy eso no se ve porque el solver no converge.

Neutral correcto: **la dirección en la que el torso ya mira** (forward del
tórax). Interpolar hacia ahí significa "no hagas nada", que es lo que un
neutral debe significar.

Ambos cambios van juntos. Corregir solo la ruta convierte un bug silencioso en
un bug visible.

## Consecuencias

- La columna pasa a responder al puntero. Eso es el objetivo.
- Aparece la necesidad de influence **por eje**: `CCDIK3D` resuelve una cadena
  completa con una sola influencia, y el reparto pitch/yaw que describe
  ADR-0005 no cabe ahí. Es trabajo del ticket siguiente, no de este.
- Los dos caminos de fallo se documentan como una clase: "`NodePath` con
  niveles equivocados". La costura de test debe cubrir cualquier ruta de nodo
  que se configure en runtime, no solo estas dos.

## Relación con ADR-0001 y ADR-0005

ADR-0001 establece que el arma hereda del hueso, y que la columna es el canal
del apuntado (ADR-0005). Con la columna clavada, ese canal no transmite nada:
el arma se mueve 90-120° respecto a la cámara sin que el torso participe. Por
eso el arma "se va" al mover el ratón aunque el hueso esté correctamente
autorizado en Blender.

## Evidencia

Medido antes y después de corregir: el ángulo del torso debe variar de forma
monótona con el pitch del ratón. Hoy es constante. Ese es el test de
regresión del ticket.