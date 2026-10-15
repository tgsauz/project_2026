# Project 2026

Vocabulario del dominio del juego third-person de shooter. Define **qué significa cada concepto** en este proyecto, no cómo se implementa. Cuando el código y este glosario discrepan, el código tiene un error o el glosario está desactualizado; nunca se ignora la discrepancia.

## Personaje y esqueleto

**Hueso de soporte del arma**:
Hueso que define la pose del arma respecto al torso. En el rig actual es `ik_hand_gun` y pertenece a la cadena de la columna, **no** a la del brazo.
_Evitar_: hueso de mano, socket de mano, hueso del agarre, hueso del arma.

**Cadena del brazo**:
Secuencia `clavicle_* → arm_* → forearm_* → hand_*`. No contiene el hueso de soporte del arma: modificar el brazo no mueve el arma.
_Evitar_: brazo, cadena de mano.

**Raíces IK de manos**:
Grupo de huesos `ik_hand_root`, `ik_hand_r`, `ik_hand_l`, colgando directamente de la raíz del esqueleto. Son independientes de la columna y de los brazos, y no participan en la colocación del arma.
_Evitar_: huesos de agarre, manos IK.

**Forward del arma**:
Eje longitudinal del cañón, definido por el asset. No puede inferirse del eje local `-Z` de ningún hueso ni de ningún nodo de montaje.
*Medido 2026-10-14 (ADR-0009):* en el rig actual, el forward del arma **es el `-Y` del hueso `ik_hand_gun`** — coincide con el marcador `MUZZLE` del asset a 0.00°, mientras el `-Z` queda a 90.00°, en los estados armado y apuntado. La regla de no inferir se confirma; lo que cambia es que ahora sí hay un eje conocido.
_Evitar_: eje Z, forward local, -Z.

**Convención de orientación del rig**:
Rotación de 180° en Y aplicada a `VisualsComponent/Rig`. Es una rotación rígida válida (determinante +1), no una reflexión. Obliga a componer cualquier pose de hueso al espacio mundo mediante la transformación global del esqueleto, y prohíbe aplicar correcciones de eje separadas en el jugador, el esqueleto, la cámara o el arma.
_Evitar_: rig volteado, espejo del rig.

**Escritor del esqueleto**:
Nodo que escribe rotaciones de hueso en runtime por encima de la animación. El rig tiene **uno solo**: `SpineLookAtController`, que escribe `spine_02` de forma procedural desde `_process` (ADR-0008). Los huesos del esqueleto tienen dos autores vivos: la animación y ese controlador.
*Estado 2026-10-14 (T10, T12):* los otros candidatos se retiraron **medidos inertes**, no por decisión de diseño: el IK de brazos (`RightArmIK`, `LeftArmIK`, `GripTarget`) en T10, y el sector de cabeza (`FullBodyIKController`, `HeadCCDIK`, `AimIKTarget`) en T12. La causa es la misma en todos los casos: en esta versión del motor **ningún `SkeletonModifier3D` escribe huesos**. El escritor que sobrevive sobrevive precisamente porque escribe desde `_process` y no desde su callback de modificador.
_Evitar_: pipeline de IK, cadena de IK, modificador de IK, pila de IK.

## Marcadores del asset del arma

**Marcador de agarre**:
Nodo dentro del asset del arma que indica dónde debe quedar la mano. Existen `RGRIP` (derecha) y `LGRIP` (izquierda).
*Estado 2026-10-14 (T10):* el nodo sigue existiendo en el asset, pero **nada
lo lee**. El IK de brazos se borró al medirse inerte. Se conservan en el asset
porque son la referencia de la re-autoría en Blender y de un futuro IK.
_Evitar_: socket, anclaje, punto de anclaje, ancla.

**Marcador de mira**:
Nodo dentro del asset del arma que define la línea de sight: `SIGHT_BACK` y `SIGHT_FRONT`.
_Evitar_: mira, retícula.

**Marcador de boca**:
Nodo dentro del asset del arma en la salida del cañón: `MUZZLE`.
_Evitar_: boca del cañón, muzzle, salida.

Los tres son datos del asset, inmutables en runtime. Son cosas distintas de los puntos de anclaje, que pertenecen al personaje.

## Personaje: colocación de objetos

**Punto de anclaje**:
Posición del personaje donde puede equiparse un objeto. Se declara en el layout de anclajes: `right_hand`, `left_hand`, `back_mount`, `lower_back`, y los derivados de clothing.
_Evitar_: marcador, socket, hueso de soporte.

**Layout de anclajes**:
Conjunto de puntos de anclaje que define qué se puede equipar y dónde. El layout del jugador declara `right_hand` sobre el hueso de soporte del arma y `left_hand` sobre la mano izquierda.
_Evitar_: configuración de slots, catálogo de slots.

**Slot de mano**:
Punto de anclaje `right_hand` o `left_hand`. Es el que dispara el flujo de agarre.
_Evitar_: ranura de mano, hueco.

## Apuntado

**Estado de apuntado** (`AimState`):
Datos de intención de apuntado de un fotograma: origen, dirección, pitches, pesos y FOV objetivo. Lo produce el controlador de apuntado y lo consumen cámara, columna, brazo y arma. Nadie lo escribe salvo su productor.
*Estado 2026-10-14 (T09, T10, T12):* sus consumidores vivos son la cámara, la columna y el arma. Ya no el brazo, porque el IK de brazos se borró por inerte (T10). Los dos campos continuos que este mismo documento definía abajo (`ads_weight` y `aim_orientation_weight`) ya no existen: se retiraron por ADR-0007 y T09, respectivamente, ambos medidos sin consumidores útiles.
_Evitar_: datos de apuntado, estado de cámara.

**Peso de orientación de apuntado**:
*Retirado 2026-10-14 (T09).* Era la mezcla continua entre la pose del hueso de soporte del arma (0) y la pose derivada de la cámara (1). El campo `aim_orientation_weight` se eliminó al medirse que ningún sistema lo leía. La pose del arma la decide hoy el hueso de soporte, sin mezcla con la cámara.
_Evitar_: peso de ADS, peso de apuntado.

**Peso ADS**:
*Retirado 2026-10-14 (ADR-0007).* Era la mezcla continua de 0 a 1 que indicaba cuánto estaba el personaje en postura de apuntado, y que alimentaba FOV y capas de animación. El campo `ads_weight` no existe. El estado de apuntado es **discreto** (`Unarmed`, `Armed`, `Aiming`) y la continuidad la aporta la amortiguación de cada sistema que reacciona al cambio, no un peso compartido.
No confundir con la **influencia discreta de la columna**, que sí existe y vive en `SpineLookAtController`.
_Evitar_: peso de orientación de apuntado, stance.

**Stance del personaje**:
Uno de tres estados discretos que selecciona el animation tree: `Unarmed`, `Armed`, `Aiming`. Es distinto de los pesos continuos.
_Evitar_: pose, estado de apuntado, postura de apuntado.

## Contratos entre sistemas

**Nodo objetivo de IK**:
*Retirado 2026-10-14 (T10, T12).* Era un nodo de escena al que se escribía un objetivo para que lo consumiera un modificador de IK; era un nodo de presentación, no un contrato. **Ya no queda ninguno**: `RightHandIKTarget` y `LeftHandIKTarget` se borraron con la cadena de agarre (T10), y `AimIKTarget` con el sector de cabeza (T12). El único punto de mira que sobrevive es `LookAtTarget`, y lo usa solo el visualizador de depuración — no es un nodo objetivo de IK.
_Evitar_: objetivo de agarre, GripTarget.

**Capa de arma** (`WeaponLayer`):
Unidad transformacional que toma la pose del arma y devuelve otra. Se componen por prioridad para producir la pose final.
_Evitar_: modificador, capa de presentación.

**Pila de capas de arma** (`WeaponLayerStack`):
Compositor ordenado por prioridad que encadena capas de arma.
_Evitar_: stack de armas, cadena de capas.