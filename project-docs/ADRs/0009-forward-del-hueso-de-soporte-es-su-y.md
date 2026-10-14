# El forward del hueso de soporte es su -Y, validado contra el marcador del asset

## Estado

Aceptado — 2026-10-14. Complementa ADR-0002, que sigue vigente.

## Contexto

El torso se veía doblado ~90° hacia atrás mientras apuntaba. Los clips de
animación estaban bien: el defecto era del escritor procedural
(`Player/SpineLookAtController.gd`, `_write_spine_pose`), que leía
`-gun_pose.basis.z` como sensor del forward del hueso `ik_hand_gun`.

Ese `-Z` apunta al piso. El escritor calculaba un error de 90° que no existía
y rotaba `spine_02` -90° en cada fotograma.

Medido, apuntando en horizontal, AIMING, espacio global:

| | con el escritor | con el escritor apagado (clip) |
|---|---|---|
| `pitch_delta` que calcula el escritor | **-90.00°** | — (no escribe) |
| boca real (`MUZZLE`) vs dirección de apuntado | **+90.00°** | +0.00° |
| boca real vs `-Y` del hueso `ik_hand_gun` | **+0.00°** | +0.00° |
| boca real vs `-Z` del hueso `ik_hand_gun` | +90.00° | +90.00° |
| pliegue de spine_02 (eje de spine_01 vs eje de spine_02) | **+63.55°** | +16.99° |

La fila que decide el ADR es la tercera: **la boca es el `-Y` del hueso, a
0.00°, en los dos estados**. No es una convención del código, es una
propiedad medida del asset, repetida en ARMED y en AIMING.

El arrastre se medió hueso a hueso (no con el segmento pelvis → spine_02, que
es invariante por construcción a la rotación de spine_02 y por eso no sirve
como medida):

```
             spine_02   clavicle_r   neck    head
OFF (clip)    16.99      16.99      32.09   31.91   <- pliegue de spine_02
ON  (+bug)    63.55      63.55      57.90   58.08
```

`clavicle_r` es hijo directo de `spine_02`, no se escribe y hereda su
rotación exacta. De ahí los hombros, los brazos, el cuello y la cabeza.

Dos suites estaban en verde con el torso doblado 90°, y por eso el defecto
sobrevivió:

- `spine_pitch_response.gd` comparaba el `-Z` del hueso contra la dirección de
  apuntado, que es exactamente la magnitud que el escritor optimiza.
  Verificaba la premisa del escritor con la premisa del escritor.
- `weapon_coupling_acceptance.gd` comparaba el `WeaponRoot` contra la pose del
  mismo hueso, así que el error de convención de eje se cancelaba en los dos
  lados de la comparación.

## Decisión

1. El forward del hueso `ik_hand_gun` es su **`-Y`**. El escritor procedural lo
   lee así y lo anula contra la dirección de apuntado.
2. El `-Z` del hueso del arma no es un forward. No se usa como sensor, ni
   para diagnosticar, ni para afirmar que el arma apunta a algún sitio.
3. El forward del arma se define en el **asset**, por el marcador `MUZZLE`
   (`World/Items/M4RIFLE/weaponSceneEquipped.tscn`), y se valida por
   medición contra el hueso. No se infiere de la convención de ejes de ningún
   nodo. Es la regla 3 de ADR-0002, que ya advertía que el `-Z` de
   `ik_hand_gun` "apunta casi hacia arriba": el escritor la incumplía.
4. Cualquier aserción sobre hacia dónde apunta el arma se mide con el
   marcador `MUZZLE` **en espacio global**, nunca con el eje del sensor.
5. La rotación de 180° en Y del nodo `Rig` (ADR-0002) y la rotación de 180°
   horneada en el asset del arma **se conservan**. El cambio de eje no las
   compensa y no las necesita: solo cambia qué eje del hueso se lee.

## Validación

Después del cambio, mismo barrido, espacio global:

```
  cam_pitch | pitch_delta | boca vs apuntado | boca vs hueso -Y | pliegue s02
     -30.0  |    +0.00    |      +0.00       |     +0.00        |   +32.05
     -15.0  |    -0.00    |      +0.00       |     +0.00        |   +23.03
      +0.0  |    +0.00    |      +0.00       |     +0.00        |   +16.99
     +15.0  |    -0.00    |      +0.00       |     +0.00        |   +17.59
     +30.0  |    +0.00    |      +0.00       |     +0.00        |   +24.33
```

`pitch_delta` cae de -90.00° a 0.00°: el clip ya apuntaba bien y el escritor
dejó de inventar error. La tolerancia de convergencia es 2°, criterio de
cadera ya acordado en `weapon_coupling_acceptance`.

## Consecuencias

- `spine_pitch_response.gd` tuvo que cambiar su eje de `-Z` a `-Y`. Con el
  arreglo quedó en rojo: su barrido pasó a ser `pitch de cámara − 90°`
  (-60 / -75 / -90 / -75 / -60), la firma de que el `-Z` quedó perpendicular al
  apuntado. Estaba verde por el bug, no a pesar de él. Conserva su valor
  conductual (monotonicidad con el pitch y deriva con el ratón quieto); la
  convergencia con la boca real vive ahora en `spine_muzzle_convergence.gd`,
  que no es circular.
- Queda un Open Question medido, **fuera de este ADR**: con el escritor
  corregido, en horizontal, el cuello queda a +32.09° y la cabeza a +31.91°
  de pitch. Es aporte del clip, no del escritor (con el escritor apagado da
  exactamente los mismos +32.09° / +31.91°). Si el cuello sigue doblado en
  pantalla, la reautoría de los clips es un ticket aparte.

## Por qué es un ADR

`-Z` es la convención de forward de Godot y de la mayoría de los motores. El
código que estaba mal se lee perfectamente normal. Sin este registro, el
próximo que lea `-gun_pose.basis.z` en este archivo lo va a "arreglar" de
vuelta, y esta vez en un archivo cuyo comentario dice que el `-Z` apunta al
piso.

## Evidencia

`Tests/Acceptance/spine_muzzle_convergence.gd` (medición no circular, marcada
ROJO antes del arreglo de código y verde después),
`Tests/Acceptance/spine_pitch_response.gd` (eje corregido),
`.scratch/columna-apuntado/issues/06-test-no-circular.md` y
`07-eje-sensor-del-hueso.md`.
