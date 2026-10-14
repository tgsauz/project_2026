# 10: Borrar la cadena de IK de brazos (inerte y medida)

**What to build:** borrar la maquinaria de IK de brazos. No esta a medias: esta
**medida como inerte**. Se borra, no se documenta, para que ningun agente ni
ningun documento futuro lo lea como funcionalidad viva.

## La medicion que justifica el borrado

Medido en el motor, con el arma equipada y apuntando:

```
mano derecha al objetivo RightHandIKTarget:   0.0956 m de error
mano izquierda al objetivo LeftHandIKTarget:  0.5585 m de error
mano se movio al desplazar el objetivo 1 m:    0.000000 m   <- NO responde
RightArmIK: active=true  influence=1.00                       <- dice que vive
```

Mover el objetivo un metro produce **cero** movimiento de la mano. Los solvers
estan configurados, con peso, y activos, y no hacen nada. Es el mismo fenomeno
que ADR-0008 midio para la columna: **ningun `SkeletonModifier3D` escribe huesos
en esta version del motor**.

El error de agarre resultante (9.56 cm y 55.85 cm) viene del clip de animacion,
no de esta cadena.

## Que borrar

Investiga y borra el camino completo, no solo los nodos:

1. Los nodos `RightArmIK` y `LeftArmIK` (`TwoBoneIK3D`) y su creacion en
   `Player/Scripts/CharacterRigAssembly.gd`.
2. Su configuracion en `Player/Scripts/FullBodyIKController.gd`: cadenas de
   huesos, `set_target_node`, y el constante `IK_GRIP_WEIGHT`.
3. Las entradas de brazos en las tablas `WEIGHTS_UNARMED` / `WEIGHTS_ARMED` /
   `WEIGHTS_AIMING`.
4. El camino de agarre: `GripTarget`, `FullBodyIKController.apply_grip_target()`
   y su consumidor en `Player/Scripts/WeaponController.gd` (los marcadores
   `RGRIP` y `LGRIP` y sus locales).
5. `RightHandIKTarget` y `LeftHandIKTarget` si, tras el borrado, no los consume
   nadie vivo. **El visualizador de depuracion los dibuja**: antes de borrarlos
   decide si se quita tambien esa parte del visualizador o se deja el nodo. Si
   quedan huerfanos, `push_error` los va a delatar en el log; corre el juego en
   headless y lee el log.

## Ojo, el smoke test afirma el orden de modificadores

`Tests/Smoke/dependency_smoke_runner.gd` tiene una lista de modificadores
esperados y una asercion de orden. Al borrar los nodos del IK de brazos hay que
actualizar esa lista. Si la asercion de orden queda sin objeto porque ya no hay
solvers vivos, **no la borres por tu cuenta**: reportalo y decides.

## Ojo, que NO se va en este ticket

- **`HeadCCDIK` y `AimIKTarget` quedan fuera.** Son el sector de cabeza, con su
  propio ticket (T11). No los toques.
- **La columna procedural (`SpineLookAtController`) queda fuera.** Es el
  sistema vivo: boca real contra apuntado 0.00 grados, medido.
- **Los clips no se tocan.** El desalineamiento de manos se arregla en Blender,
  en otro ticket.

## How to verify

1. `grep -rn "RightArmIK\|LeftArmIK\|IK_GRIP_WEIGHT\|GripTarget\|RGRIP\|LGRIP"`
   devuelve vacio en codigo de juego (los tests de T10 pueden mencionarlos si
   los usas como evidencia; decidilo).
2. **Sin errores ni warnings nuevos en runtime.** Corre el juego en headless y
   lee el log completo. `push_error` es la senal de que dejaste algo huerfano.
3. **Comportamiento del arma intacto:** las seis suites en verde. En particular
   `weapon_coupling_acceptance` (20/20) y `spine_muzzle_convergence`
   (boca contra apuntado 0.00 grados). Si el arma se mueve al borrar esto, es
   que la cadena si sostenia algo: **para y repporta, no lo "arregles".**
4. La boca sigue colineal con el apuntado en los cinco pitches del barrido.

**Blocked by:** nada. Archivos disjuntos con T09.

**Status:** ready-for-agent

- [ ] Nodos `RightArmIK` / `LeftArmIK` fuera de la escena y del ensamblaje
- [ ] Configuracion de cadenas, `IK_GRIP_WEIGHT` y pesos de brazo fuera
- [ ] Camino `GripTarget` / `RGRIP` / `LGRIP` fuera de codigo de juego
- [ ] Nodos objetivo de mano: borrados, o decision reportada de por que quedan
- [ ] Lista de modificadores del smoke test actualizada
- [ ] Log en headless sin `push_error` nuevos
- [ ] 6/6 suites en verde
- [ ] Commit que documente la medicion 0.000000 m como justificacion del borrado