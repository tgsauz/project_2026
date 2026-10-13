# Convención de orientación del rig visual

**Estado:** convención vigente; no modificar sin una migración y validación explícitas.  
**Ámbito:** `res://Player/PlayerCharacter.tscn` y la instancia `VisualsComponent/Rig`.

## Convención

`VisualsComponent/Rig` mantiene una rotación de **180° alrededor de Y**:

```text
Basis = diag(-1, 1, -1)
Determinante = +1
```

Es una rotación rígida válida, no una reflexión ni una escala negativa. Se aplica al rig visual, no a `CharacterBody3D`: la orientación/yaw del cuerpo y la convención de movimiento del juego permanecen en el marco del jugador, mientras que el esqueleto, sus animaciones y sus sockets heredan la conversión del nodo `Rig`.

La conversión forma parte del contrato del personaje importado. No debe eliminarse ni cambiarse en Blender, en el GLB o en la escena sin verificar y migrar de manera coordinada la orientación del modelo, la jerarquía/rest pose del esqueleto, las animaciones y los sistemas que consumen sus transforms.

## Reglas para código y assets dependientes

- Al convertir una pose de hueso del espacio del esqueleto a mundo, incluir el transform mundial del esqueleto. Por ejemplo, el transform mundial del socket es `skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)`.
- No inferir que el eje local `-Z` de cada socket es el forward del arma. La base local de `ik_hand_gun` y el marco del asset deben compararse explícitamente; el eje de montaje puede ser distinto.
- Mantener las correcciones específicas de orientación de un arma en su marco de montaje/asset. No usarlas como motivo para quitar la conversión global del rig.
- El giro de `Rig` no autoriza a añadir flips por separado en el jugador, el esqueleto, la cámara o el arma sin identificar primero el espacio y la autoridad de cada transform.

## Validación obligatoria antes de cambiar esta convención

Probar en una escena de jugador aislada y comparar antes/después:

1. Forward mundial del `CharacterBody3D`, del rig visual y de la cámara.
2. Pose mundial de `pelvis`, `spine_01`, `spine_02` e `ik_hand_gun`.
3. Locomoción, yaw y transiciones entre animaciones armadas/desarmadas.
4. Orientación del torso procedural, targets de ambas manos y agarre del arma.
5. Alineación de cañón/miras con el socket, usando transforms y ejes medidos, no solo Euler o apariencia desde una cámara.

Un cambio que quite o reubique la rotación solo se considera aceptado cuando esas comprobaciones confirmen que las features conservan su comportamiento.
