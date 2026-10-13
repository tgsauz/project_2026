---
title: Causa raíz — el arma se distorsiona al pasar de Armed a Aiming
date: 2026-10-13
engine: Godot 4.7.2
estado: vigente
---

# El arma se distorsiona al entrar en Aiming

## Resumen

No es el código del arma. El código cumple: el criterio de aceptación mide
**0.0000 m y 0.00° en los 450 fotogramas** grabados, sin una excepción. El arma
está exactamente en el hueso siempre.

La causa está en los datos de animación importados: **los tres clips de
apuntado no tienen pose de arma propia para `ik_hand_gun`.** Usan la rotación
del hueso en reposo, que es la misma que usan los clips desarmados.

## La medición

Rotación relativa a la pelvis al pasar de `Armed` a `Aiming`:

| Hueso | Giro |
|---|---|
| `spine_02` | 32.93° |
| **`ik_hand_gun`** | **116.51°** |
| `hand_r` | 72.12° |
| `hand_l` | 72.12° |

El hueso de soporte del arma gira 116°, pero la columna solo gira 33°. El arma
no puede girar así por sí sola: ese exceso viene de un cambio de datos, no de
la cadena de huesos.

Desplazamiento relativo a la pelvis:

| Hueso | Desplazamiento |
|---|---|
| `ik_hand_gun` | 0.3514 m |
| `hand_r` | 0.2895 m |
| `hand_l` | 0.6304 m |

La animación mueve el arma y los brazos **juntos**. Por eso la distancia
mano↔hueso se conserva: 9.28 cm a la derecha y 30.55 cm a la izquierda,
idéntica en ambos estados. La posición es correcta. Lo que está mal es la
rotación.

## La causa: los clips de apuntado no tienen rotación de arma

Rotación de `ik_hand_gun` por clip, leída del recurso importado:

| Clip | Rotación del hueso |
|---|---|
| `idle_holding_gun` | Quaternion(..., **0.614027**) |
| `walking_holding_gun` | Quaternion(..., **0.69781**) |
| `left_strafe_walk_holding_gun` | Quaternion(..., **0.428085**) |
| `right_strafe_walk_holding_gun` | Quaternion(..., **0.913915**) |
| `holding_aim` | Quaternion(-0.650946, 0, 0, **0.759124**) |
| `walking_aiming_gun` | Quaternion(-0.650946, 0, 0, **0.759124**) |
| `strafe_walk_aiming_gun` | Quaternion(-0.650946, 0, 0, **0.759124**) |
| `idle`, `walking`, `running`, `left/right_strafe_walk` | Quaternion(-0.650946, 0, 0, **0.759124**) |

`Quaternion(-0.650946, 0, 0, 0.759124)` es **exactamente la rotación de reposo**
del hueso: convierte a `basis.y = (0, 0.152539, -0.988297)`, que es el valor
rest medido del asset.

Los clips `_holding_gun` tienen cada uno su propia rotación. Los tres clips
`_aiming_gun` comparten, carácter por carácter, la rotación de los clips
**desarmados**.

## Qué significa

Al entrar en `Aiming` se aplican a la vez dos cosas: la posición autorada de
apuntado del hueso (correcta, +35 cm) y una rotación que no fue autorada — la
de reposo. El arma salta 35 cm hacia arriba y gira 116° porque el hueso gira, y
los brazos no pueden seguir esa rotación porque el IK de brazo no actúa.

El resultado visible es un arma que se coloca bien y se orienta mal.

## Dónde está el fallo

En el asset, no en el código. Los clips `holding_aim`, `walking_aiming_gun` y
`strafe_walk_aiming_gun` nunca recibieron la rotación de `ik_hand_gun` en la
posición de apuntado. En Blender esos clips existen y se ven bien; lo que no
llegó al `.glb` es la rotación del hueso de soporte en ellos.

## Observación sobre el import

Al leer el recurso, `ik_hand_gun` tiene dos pistas cuyos **tipos no coinciden con
sus valores**: una pista `TYPE_ROTATION_3D` contiene un `Vector3` de posición, y
una `TYPE_SCALE_3D` contiene un `Quaternion` de rotación. Ambas tienen una sola
clave, constante por clip.

Esto merece atención al reexportar. Si el exportador está escribiendo posición
en la ranura de rotación y rotación en la de escala, el problema persistirá
aunque se autorice la pose en Blender. **Conviene verificar una reexportación
antes de dar por cerrado el arreglo.**

## Lo que este documento no resuelve

- El brazo izquierdo queda a 30.55 cm del hueso en ambos estados. Problema
  anterior, ya aceptado como menor.
- El IK de brazo no produce diferencia medible entre influencia 0 y 1. Es la
  razón de que ningún sistema corrija esta rotación.