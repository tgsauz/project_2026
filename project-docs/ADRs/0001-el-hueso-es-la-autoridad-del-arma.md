# El hueso de soporte del arma es la autoridad de su pose

## Estado

Aceptado — 2026-10-13. Aplicará al rediseño del acoplamiento arma ↔ personaje.

## Contexto

La animación contiene pistas `ik_hand_gun` en los 13 clips, incluido `ik_hand_gun`
como hijo de `spine_02`. El sistema v1 (commit `c444a3c`) leía ese hueso para la
orientación pero **descartaba su posición**, sustituyéndola por la constante
anatómica `IDLE_DIRECTION = Vector3(0, -0.8, 0.3)` medida desde `clavicle_r`. Una
segunda capa, `WeaponLayerAim`, interpolaba además la orientación hacia la cámara
hasta 104.65° fuera del hueso. El IK de brazo obedecía al resultado.

El comentario del código justificaba esa sustitución por un ciclo
`WeaponRoot → GripTarget → arm IK → ik_hand_gun → WeaponRoot`. Ese ciclo no
existe: `ik_hand_gun` es hijo de `spine_02` y la cadena del brazo cuelga de
`clavicle_r`, su hermana. El IK de brazo no puede mover `ik_hand_gun`.

Medición: colocando el arma rígidamente en el hueso, `RGRIP` cae a 5.8 mm de
`hand_r` y `LGRIP` a 3.6 mm de `hand_l`. El rig está cocinado correctamente.
Con la heurística, el arma queda 25.1 cm desplazada y `RGRIP` a 25.3 cm de la
mano animada.

## Decisión

`ik_hand_gun` es la autoridad única de la pose del arma:

```
weapon_root.global_transform = skeleton.global_transform × skeleton.get_bone_global_pose(ik_hand_gun)
```

Sin constantes anatológicas, sin fallback de columna, sin ajuste de posición en
runtime. Los marcadores `RGRIP` y `LGRIP` sobre ese transform producen el
objetivo de agarre; el IK de brazo converge **hacia** la animación.

## Por qué

- Es la única opción que no requiere reanimar: el asset ya soporta el modelo.
- Elimina la necesidad de la heurística, que existía para un ciclo inexistente.
- Hace imposible el conflicto de dos escritores sobre la misma pose.
- El IK de brazo deja de arrastrar al cuerpo y pasa a converger, que es lo que
  el IK debe hacer.

## Alternativas descartadas

- **El runtime como autoridad.** Requiere reanimar a mano todo lo que hoy da la
  animación. El autor del proyecto no se considera animador y el número de
  clips es deliberadamente pequeño; esta opción escala mal con esa restricción.
- **Híbrido (torso del hueso, orientación del runtime).** Mantiene dos
  escritores sobre la orientación. Es exactamente el conflicto que este ADR
  elimina.

## Consecuencias

- `IDLE_DIRECTION`, `_compute_grip_marker_position` y
  `_compute_spine_coupled_position` se eliminan.
- El ajuste de puntería debe aplicarse **una vez y en un sitio**. Hoy se aplica
  en la columna (CCDIK `spine_01 → spine_02`, del que `ik_hand_gun` es hijo) **y**
  en la capa de apuntado; ese solapamiento está sin medir y es el siguiente
  bloqueante medible.
- Si en el futuro se necesita una pose de arma independiente de la animación
  (recoil, sway), debe ser una capa que componga **sobre** la pose del hueso, no
  una sustituta de su posición.

## Evidencia

`Docs/Diagnóstico — Desacoplamiento del arma.md`