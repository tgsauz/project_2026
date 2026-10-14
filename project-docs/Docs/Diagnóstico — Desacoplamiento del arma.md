---
title: Diagnóstico — Por qué el arma se desacopla del hueso ik_hand_gun
date: 2026-10-13
engine: Godot 4.7.2
branch: weapon_system
baseline: c444a3c
status: vigente
---

# Diagnóstico del acoplamiento arma ↔ personaje

Todas las cifras de este documento están **medidas**, no estimadas. Proceden de
sondeos headless ejecutados contra `Player/PlayerCharacter.tscn` con el M4
equipado en `right_hand`. Los sondos se eliminaron tras la medición; se
reproducen aquí los datos, no las herramientas.

---

## 1. Resumen

El síntoma reportado era "el arma no se mantiene acoplada al hueso
`ik_hand_gun`, siempre se rompe". La causa medida no es un bucle de
retroalimentación: es un **conflicto de dos escritores sobre la misma
información**. La animación coloca el arma; el runtime la coloca en otro sitio.

La posición del arma debe ser la del hueso, sin cálculo intermedio:

```
weapon_root.global_transform = skeleton.global_transform × skeleton.get_bone_global_pose(ik_hand_gun)
```

Con el M4 equipado, distancia entre el arma y la posición del hueso:

| Magnitud | Hip fire | Apuntando |
|---|---|---|
| Distancia entre el arma y donde el hueso dice que está | **25.1 cm** | **46.5 cm** |
| Distancia entre `RGRIP` y la mano animada `hand_r` | **25.3 cm** | **43.5 cm** |
| Ángulo entre el forward del hueso y el del arma | **0.0°** | **106.8°** |
| `RGRIP` vs `hand_r` *si el arma estuviera en el hueso* | **5.9 mm** | 7.5 cm |
| `LGRIP` vs `hand_l` *si el arma estuviera en el hueso* | **3.6 mm** | 25.0 cm |

Las dos últimas filas son la clave: en hip fire la animación ya coloca las
manos donde deben estar, y es el runtime el que las separa del arma.

---

## 2. Hecho 1 — `ik_hand_gun` no es un hueso de mano

Jerarquía extraída del `.glb` importado (49 huesos):

```
root
└── pelvis
    └── spine_01
        └── spine_02
            ├── clavicle_r → arm_r → forearm_r → hand_r    ← cadena del brazo
            ├── clavicle_l → arm_l → forearm_l → hand_l
            └── ik_hand_gun                                ← hueso de soporte
```

`ik_hand_gun` (índice 38) es hijo de **`spine_02`**. `hand_r` (índice 28)
cuelga de `clavicle_r`, que es su **hermano**, no su ancestro.

**Consecuencia:** el IK de brazo escribe `arm_r`, `forearm_r` y `hand_r`.
Ninguno de esos huesos es ancestro de `ik_hand_gun`, por lo que **el IK de
brazo no puede mover `ik_hand_gun`**.

> El comentario de `Player/Scripts/WeaponLayerBase.gd:15-17` describe un ciclo
> `WeaponRoot → GripTarget → arm IK → ik_hand_gun → WeaponRoot` y afirma que la
> heurística de posición lo rompe. **Ese ciclo no existe.** La arista
> "arm IK → `ik_hand_gun`" no está en el árbol.

El hueso de soporte del arma, en pose rest, está en `(0, 1.2, 0.1)` — altura de
pecho. Su base rest es `Z ≈ (0, 0.988, 0.152)`: su eje local `-Z` apunta casi
hacia arriba. El forward del arma **no** puede inferirse del `-Z` del hueso, tal
como ya advierte `Docs/Convención de Orientación del Rig.md`.

---

## 3. Hecho 2 — la animación sí está bien cocida

Los 13 clips animados del GLB contienen pista `ik_hand_gun`
(`holding_aim`, `idle`, `idle_holding_gun`, `walking`, `walking_holding_gun`,
`walking_aiming_gun`, `strafe_walk_aiming_gun`, `left/right_strafe_walk`,
`left/right_strafe_walk_holding_gun`, `running`, `idle`, …).

Medición de consistencia interna — colocar el arma rígidamente en el hueso, sin
ninguna heurística, y comparar los marcadores de agarre con los huesos de mano:

| Estado | `RGRIP` vs `hand_r` | `LGRIP` vs `hand_l` |
|---|---|---|
| Armed (sin apuntar) | **5.8 mm** | **3.6 mm** |
| Aiming (peso de orientación 0.96) | 7.5 cm | 25.0 cm |

**En `Armed` el rig es consistente: los marcadores caen a 4-6 mm de las manos
animadas.** El asset está cocinado correctamente y la relación
hueso → marcadores → manos es utilizable tal cual.

En `Aiming` la mano derecha sigue cerca (7.5 cm) pero **la izquierda se aleja
25 cm**. Ese es un problema de animación, no de marcador: el clip de apuntado no
coloca la mano izquierda en el arma. Es la causa más probable del
"la mano izquierda no llega" registrado en
`Tests/IK/weapon_ik_transform_investigation.md`, y es independiente del
problema de posicionamiento.

---

## 4. Hecho 3 — `WeaponLayerBase` descarta la posición del hueso

`Player/Scripts/WeaponLayerBase.gd:60-109` toma la **orientación** del hueso
(`get_bone_global_pose`) pero **descarta la posición**: en lugar de propagarla,
invoca `_compute_grip_marker_position()`, que fabrica una posición a partir de
otros huesos del personaje.

Esa posición fabricada no debería existir. La posición del arma es la del hueso:

```
weapon_root.global_transform = skeleton.global_transform × skeleton.get_bone_global_pose(ik_hand_gun)
```

Nada más. No hay longitud de brazo que medir ni constante que calibrar.

Verificación de que el cálculo actual **es** la autoridad: reproducirlo con
los valores reales del runtime da `WeaponRoot.global_transform` con error de
**0.0 m** en hip fire. La posición del hueso no entra en él en absoluto.

Efecto medido: el arma queda **25.1 cm** desplazada respecto a la pose
autorada en hip fire, y **46.5 cm** apuntando. La animación y el runtime
describen posiciones distintas del mismo objeto.

El arreglo no es ajustar la constante ni recalibrar la longitud: es borrar el
cálculo. Ver ADR-0001.

---

## 5. Hecho 4 — el segundo escritor es `WeaponLayerAim`

`WeaponLayerAim` (prioridad 5) interpola la orientación del arma hacia la
dirección de cámara con peso `aim_orientation_weight`. Con el mismo peso 0.96
que produce un apuntado real:

| Magnitud (apuntando, peso 0.96) | Valor |
|---|---|
| Ángulo entre forward del hueso y forward del arma | **106.8°** |
| `RGRIP` vs `hand_r` | 43.7 cm |
| `LGRIP` vs `hand_l` | 91.5 cm |

Con peso 0 el ángulo es **exactamente 0.0°** — la orientación es una copia
exacta del hueso. En cuanto entra la capa de apuntado, el arma gira **más de
90°** fuera de la orientación que el hueso y la animación\Serviceaban. Ese es el
"siempre se rompe" en su forma más visible.

Nótese que 106.8° no es un ajuste fino de puntería: es el arma apuntando
prácticamente al revés respecto al hueso.

---

## 6. Formulación correcta del problema

No es un bucle. Es esto:

```
AnimationTree  ──escribe──►  ik_hand_gun (posición + orientación)
WeaponLayerBase ──ignora──►  posición de ik_hand_gun
              ──sustituye─►  posicion fabricada (_compute_grip_marker_position)
WeaponLayerAim ──escribe──►  orientación de ik_hand_gun (hasta 106.8°)
```

**Dos escritores, tres verdades.** La animación dice una cosa sobre dónde está
el arma; la posición fabricada dice otra; la capa de apuntado dice una tercera.
No hay forma de satisfacer las tres, así que el resultado se ve roto de forma
diferente en cada estado.

El comentario del código atribuye el diseño a un ciclo que no existe. La causa
real es más simple y más fácil de corregir: **falta una autoridad única**.

---

## 7. Implicación para el rediseño

Si el hueso de soporte del arma es la autoridad (medido: coherente a 4-6 mm en
`Armed`), entonces:

- La posición del arma es `skeleton.global_transform × get_bone_global_pose(ik_hand_gun)`.
  No hay constante, ni longitud estimada, ni fallback. No queda nada que ajustar.
- Los marcadores `RGRIP`/`LGRIP` sobre ese transform producen el objetivo de
  agarre, y el IK de brazo converge hacia la animación en lugar de arrastrar
  al cuerpo hacia una pose inventada.
- Cualquier ajuste de puntería debe aplicarse **una sola vez** y en **un solo
  sitio**. Hoy el pitch/yaw se aplica en la columna (CCDIK `spine_01 → spine_02`,
  del que `ik_hand_gun` es hijo) **y** en `WeaponLayerAim`. Eso duplica el
  ajuste; por eso el ángulo medido se dispara a 106.8° en vez de acercarse a 0.

> **Corrección 2026-10-14 (esta página es histórica; no la reescribas).** Los tres
> mecanismos nombrados aquí ya no existen: el `CCDIK` de columna se retiró
> (ADR-0008, sustituido por escritura procedural) y `WeaponLayerAim` se borró
> al reescribirse el controlador del arma. **El yaw tampoco lo aplica la columna**
> (ADR-0005: el cuerpo es su único dueño; el torso es inmune, medido). El
> diagnóstico de fondo —«el ajuste se aplica en más de un sitio y se duplica»—
> sigue siendo la lección válida de esta página.

Pendiente de medición, no de suposición:

- El clip `Aiming` no lleva la mano izquierda al arma (25 cm). Requiere
  reanimación o una decisión explícita sobre en qué estado se usa agarre
  bilateral.
- El ajuste de puntería acumulado entre columna y capa sigue sin medirse.
  Ninguna de las dos cifras anteriores aísla esa contribución.

---

## 8. Reproducción

Las mediciones se obtuvieron con sondos headless temporales sobre
`Tests/Temp/`, ejecutados con:

```
godot --headless --path . --script res://Tests/Temp/<sonda>.gd
```

Carga de `Player/PlayerCharacter.tscn`, `InventoryComponent.attach_item()` del
`TestWeaponItem.tres` en `right_hand`, y lectura directa de
`Skeleton3D.get_bone_global_pose()`, `WeaponRoot.global_transform` y los
marcadores cacheados de `WeaponController`. Los sondos se eliminaron tras la
medición; ninguno forma parte del baseline.

**Ninguna de estas cifras estaba documentada antes.** El documento de
investigación vigente (`Tests/IK/weapon_ik_transform_investigation.md`) medía el
alcance de la mano izquierda pero no el desacoplamiento del arma, y declaraba
explícitamente que no se había establecido causa raíz única. Este documento la
establece para la parte del posicionamiento.

> **Correccion 2026-10-14 (T10).** Este documento es un registro con fecha; se conserva tal cual. A partir de T10 el IK de brazos, `GripTarget` y los objetivos de mano **se borraron por inertes** (medido: 0.000000 m de respuesta). Todo lo que aqui los describe como vivos describe un estado que ya no existe.
