# Convención de orientación del rig: rotación de 180° en Y

## Estado

Aceptado — 2026-10-12 como convención de trabajo.
Ratificado — 2026-10-13 como registro de decisión.

## Contexto

`VisualsComponent/Rig` lleva una rotación de 180° alrededor de Y:
`Basis = diag(-1, 1, -1)`, determinante +1. Es una rotación rígida válida, no
una reflexión ni una escala negativa, y el asset está construido para
funcionar así.

El riesgo es que un lector asumiera que el `-Z` local de cualquier hueso o
socket es el forward del arma. No lo es. Medido sobre `ik_hand_gun` en pose
rest: su base es `Z ≈ (0, 0.988, 0.152)`, es decir su `-Z` local apunta casi
hacia arriba.

## Decisión

1. `VisualsComponent/Rig` mantiene la rotación de 180° en Y. No se modifica sin
   una migración y una validación explícitas.
2. Toda pose de hueso que se convierta al espacio mundo incluye la
   transformación global del esqueleto:
   `skeleton.global_transform * skeleton.get_bone_global_pose(idx)`.
3. El forward del arma se define en el asset. No se infiere del `-Z` de ningún
   hueso ni de ningún nodo de montaje.
4. No se añaden correcciones de eje separadas en el jugador, el esqueleto, la
   cámara o el arma sin identificar antes el espacio y la autoridad de cada
   transform.

## Validación obligatoria antes de tocar la convención

1. Forward mundo de `CharacterBody3D`, del rig y de la cámara.
2. Pose mundo de `pelvis`, `spine_01`, `spine_02` e `ik_hand_gun`.
3. Transiciones de locomoción, yaw y animación.
4. Torso procedural + ambos objetivos de mano + agarre del arma.
5. Alineación de boca y mira **medida con transformaciones y ejes**, no
   aparentemente desde una cámara.

## Por qué es un ADR

Es contraintuitivo: una rotación de 180° en la raíz del personaje es exactamente el tipo de cosa que un lector corrige "sin querer", porque la rotación de 180° en la capa superior se lee como un error. Sin este registro, el próximo que lo encuentre va a "arreglarlo" y va a romper el rig entero.

## Nota

Este ADR no crea la convención; la absorbe. El texto original es
`Docs/Convención de Orientación del Rig.md` (2026-10-12). Este archivo le da
numeración, estado y criterios de validación para que sea citable.

## Evidencia

`Docs/Diagnóstico — Desacoplamiento del arma.md` §2, `Docs/Convención de Orientación del Rig.md`