# 06: Test no circular (medir la boca real, no el eje del escritor)

**What to build:** un test que mida hacia dónde apunta el arma usando la
**boca real** (marcador `MUZZLE` del visual equipado), no el eje del hueso que
el escritor usa como sensor. Hoy el test es circular y por eso no puede fallar.

Por qué es circular, con evidencia: `Tests/Acceptance/spine_pitch_response.gd`
compara el pitch del **-Z** del hueso `ik_hand_gun` contra la dirección de
apuntado. Pero el escritor de T02 optimiza exactamente esa magnitud: lee el
-Z, calcula el error y rota para anularlo. El test verifica la premisa del
escritor usando la misma premisa, así que pasa por construcción. Pasa con
-0.00° mientras el personaje está visualmente doblado 90°.

Segundo hueco, mismo origen: `weapon_coupling_acceptance.gd` compara el
`WeaponRoot` contra la pose del mismo hueso. Cualquier error de convención de
eje se cancela en los dos lados de la comparación. Por eso sus 20/20 no dicen
nada sobre si el arma apunta a donde el jugador mira.

Medido, AIMING con el escritor apagado (pose pura del clip):

```
spine_02 a reposo     51.0 deg
pitch del -Z del hueso -90.0 deg   (apunta al piso)
pitch de la boca real   -0.0 deg   (horizontal, correcta)
angulo hueso -Z vs boca -Z  90.0 deg
angulo hueso -Z vs boca -Y   0.0 deg   <- la boca es el -Y del hueso
```

Esa última línea, en ARMED y en AIMING, es el hecho quecloses el ticket.

**Alcance del cambio:** solo `Tests/Acceptance/`. Nada de código de juego en
este ticket. La única excepción admitida es tocar el `.uid` si Godot lo regenera.

**Ojo — rotación 180° del Rig.** El nodo `Rig` en `Player/PlayerCharacter.tscn`
tiene `Transform3D(-1, 0, ~0, 0, 1, 0, ~0, 0, -1, 0, 0, 0)`, es decir 180°
sobre Y (ADR-0002, corrección legítima: **no tocar**). El test debe comparar
en espacio global, donde esa rotación ya está aplicada. Si empieza a
comparar en espacio local del esqueleto, el signo del pitch se invierte y el
test dará exactamente el error contrario al real.

**How to verify:**
- El test debe quedar **ROJO** con el código de juego actual. Si queda verde,
  el test sigue siendo circular: está mal escrito.
- Al menos dos aserciones:
  1. La boca apunta a la dirección de apuntado (tolerancia 2°, el criterio de
     cadera ya acordado).
  2. El torso no se dobla: el ángulo de `spine_02` a reposo se mantiene cerca
     del valor que da el clip solo. **No fijar el número todavía** — medirlo
     primero en el paso de T07 y fijar la tolerancia con ese dato. Poner un
     número inventado aquí sería repetir el error que acabamos de encontrar.

**Blocked by:** nada.

**Status:** ready-for-agent

- [ ] El test mide la boca real (`MUZZLE`), no el eje del hueso
- [ ] El test queda ROJO contra el código actual (si queda verde, rehacerlo)
- [ ] La aserción de convergencia usa la dirección de apuntado, 2°
- [ ] La aserción de torso existe con tolerancia medida, no inventada
- [ ] Comparación en espacio global, consciente del 180° del Rig
- [ ] Las otras cuatro suites siguen en verde