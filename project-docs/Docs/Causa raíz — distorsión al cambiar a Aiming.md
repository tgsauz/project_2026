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
`strafe_walk_aiming_gun` no tienen rotación propia para `ik_hand_gun`: usan la
de los clips desarmados. Una reexportación completa ya se ha probado y deja la
rotación intacta, de modo que el ajuste pendiente es de autoría en Blender.

## Reexportación del 2026-10-13: qué cambió y qué no

Se comparó el `.glb` reexportado contra el del repo leyendo el binario
directamente, sin pasar por Godot ni por su importador.

**Corrección de este documento:** una versión anterior de esta sección
afirmaba que las pistas de `ik_hand_gun` tenían el tipo cambiado respecto a su
valor. **Era falso.** El error estaba en la sonda que las leía, que
desaprovechaba el enum `Animation.TrackType` por un índice equivocado. Los
tipos son correctos: rotación `VEC4`, posición `VEC3`. El exportador de Blender
no escribe en la ranura equivocada.

### Lo que la reexportación sí corrigió

| Magnitud | Antes | Ahora |
|---|---|---|
| Posición de `holding_aim` relativa a `idle_holding_gun` | 43.55 cm | **24.53 cm** |
| Posición de `walking_aiming_gun` | 43.55 cm | **24.00 cm** |
| Posición de `strafe_walk_aiming_gun` | 42.30 cm | **25.82 cm** |

La rotación de reposo del hueso se movió de los canales de animación al
transform del nodo: un desplazamiento global de 81.2° en todas las pistas, que
no altera las diferencias entre clips.

### Lo que la reexportación NO corrigió

Rotación de `ik_hand_gun` **relativa a `idle_holding_gun`**:

| Clip | Antes | Ahora |
|---|---|---|
| `holding_aim` | 88.78° | **88.78°** |
| `walking_aiming_gun` | 88.78° | **88.78°** |
| `strafe_walk_aiming_gun` | 88.78° | **88.78°** |
| `idle`, `walking`, `running`, `left/right_strafe_walk` | 88.78° | 88.78° |

**Cero cambios.** Los clips de apuntado siguen compartiendo, con precisión de
0.01°, la misma rotación que los clips desarmados.

La reexportación ajustó la **posición** de apuntado y dejó la **rotación**
exactamente como estaba. Ese es el trabajo pendiente: en Blender, los clips
`holding_aim`, `walking_aiming_gun` y `strafe_walk_aiming_gun` necesitan una
rotación propia para `ik_hand_gun`, distinta de la de los clips desarmados.

## Nota sobre el archivo reexportado

El `.glb` reexportado **no está instalado**. Sustituir el del repo cambia la
pose de reposo del hueso en 81.2°, lo que interactúa con la convención del rig
documentada en ADR-0002. No se cambia sin decisión explícita.

## Lo que este documento no resuelve

- El brazo izquierdo queda a 30.55 cm del hueso en ambos estados. Problema
  anterior, ya aceptado como menor.
- El IK de brazo no produce diferencia medible entre influencia 0 y 1. Es la
  razón de que ningún sistema corrija esta rotación.