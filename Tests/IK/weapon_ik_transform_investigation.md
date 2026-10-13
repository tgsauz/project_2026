# Investigación del acople arma–IK: registro de sesión

**Estado:** investigación abierta; sin cambio de producción aprobado.  
**Proyecto:** Project2026, Godot 4.7.2.  
**Banco principal:** `res://Tests/IK/weapon_ik_test.tscn`  
**Banco experimental:** `res://Tests/IK/weapon_ik_test_experimental.tscn`  
**Arma:** `res://World/Items/M4RIFLE/weaponSceneEquipped.tscn` → `M4RIFLE.glb`

## 1. Objetivo

Investigar por qué la mano izquierda no alcanza `LGRIP` en reposo y distinguir entre:

- posición/orientación local de `RGRIP` o `LGRIP` en el modelo;
- pose animada y alcance del brazo izquierdo;
- convención de forward (`-Z` frente a `+Z`);
- composición espacial del arma entre `ik_hand_gun`, `WeaponRoot`, el marcador `RGRIP` y `GripTarget`;
- configuración o evaluación efectiva de `TwoBoneIK3D`.

El objetivo de este documento es registrar evidencia y experimentos, no declarar una causa final antes de probarla.

## 2. Resumen ejecutivo

1. La transferencia de posición de `LGRIP` al target izquierdo se comprobó correcta en la medición previa: el target mundial coincidía con el marcador dentro de precisión numérica.
2. En reposo, el target queda fuera del alcance estimado de la cadena izquierda. En la variante experimental se midieron aproximadamente **84,3 cm entre `arm_l` y target**, frente a **50,4 cm de longitud combinada estimada**; la mano estaba a unos **59,9 cm** del target. El hombro estaba a unos **84,3 cm**.
3. `RGRIP → LGRIP` mide aproximadamente **38,19 cm** en el transform local cacheado del arma. La variante socket-driven probada previamente no mejoró el alcance: dejó `LGRIP` más lejos de la mano en esa muestra.
4. En la última auditoría automatizada del banco, la línea `SIGHT_BACK → SIGHT_FRONT` se alineó a **0°** con `-WeaponRoot.basis.z`, y el vector `RGRIP → MUZZLE` a **6,83°**. Esto no respalda invertir indiscriminadamente el forward del arma.
5. Hay una discrepancia de responsabilidad/posición que requiere medición adicional: el banco puede obtener orientación desde `ik_hand_gun`, mientras la capa base calcula la posición colocando `RGRIP` en una posición natural estimada de mano. Esos son dos marcos distintos; no se ha validado el offset relativo Blender↔Godot.
6. Al iniciar la escena experimental se observó `LeftArmIK.influence = 1.0`; la medición previa temporariamente a `0/1` casi no movió el brazo. Esto sigue sin ser una prueba válida del solver ante un objetivo alcanzable, y falta aislarlo correctamente.
7. **No se modificaron el GLB, los marcadores del arma ni código de producción.** Se agregó una auditoría opcional al harness y se activó en la escena experimental.

## 3. Arquitectura observada

### 3.1 Flujo actual en código

`AimController → AimState → WeaponController → WeaponLayerStack → WeaponRoot/markers → GripTarget → FullBodyIKController → TwoBoneIK3D`

- `WeaponController._process()` compone el transform de arma, escribe `WeaponRoot.global_transform` y construye los targets de agarre.
- `_build_grip_target()` multiplica el transform mundial del arma por cada transform local cacheado:
  - `weapon_xform * _cached_rgrip_local`
  - `weapon_xform * _cached_lgrip_local`
- `_cache_marker_locals_from_weapon()` calcula transforms relativos a la raíz visual del arma antes/reparent durante equipamiento.
- En producción, `WeaponLayerBase` toma orientación del bone `ik_hand_gun`, pero calcula posición mediante `RGRIP` alineado a una posición natural aproximada derivada de clavícula derecha y `IDLE_DIRECTION`.
- `WeaponLayerAim` interpola orientación hacia cámara y conserva la posición recibida.
- El banco experimental reemplaza la capa base por `WeaponLayerSocketPositionTest`, que deriva posición/orientación del socket, elimina roll respecto a `Vector3.UP` y conserva la capa de aim.
- `FullBodyIKController` usa `TwoBoneIK3D` para `arm_l → forearm_l → hand_l`; el target es `LeftHandIKTarget`.

### 3.2 Flujo Blender descrito por el usuario

En Blender, `ik_hand_gun` determina el arma; `LGRIP` determina el objetivo del brazo/mano izquierda. El origen del arma se describió como coincidente con `RGRIP`. Este flujo es conceptualmente viable siempre que el orden sea acíclico: animación/socket → arma y grips → IK izquierdo. Si el IK derecho también devuelve influencia al mismo socket, habría que evitar el bucle.

## 4. Hechos medidos

### 4.1 Alcance izquierdo en reposo

La medición de la sesión previa en el banco experimental informó:

| Medida | Resultado aproximado |
|---|---:|
| `hand_l` → target `LGRIP` | 59,9 cm |
| `arm_l` → target `LGRIP` | 88,5 cm en una muestra; 88,5–92,6 cm según banco/pose anterior |
| longitud de segmentos combinada estimada | 50,2–50,4 cm |
| hombro (`clavicle_l`) → target | ~84,3 cm en prueba posterior |
| `RGRIP` → `LGRIP` local | 38,19 cm |

Variación entre ejecuciones se debe a pose/frame y a dónde se tomó la referencia (`arm_l` vs clavícula); no se debe tratar como una única medición anatómica exacta. Todas apuntan a una incompatibilidad de alcance en esa postura.

La comparación temporal `influence=0` frente a `influence=1` que se hizo antes dejó posiciones óseas prácticamente iguales. No concluye que el solver falle en objetivos alcanzables: el target ensayado estaba muy fuera del alcance y la temporización/configuración del experimento requiere aislamiento.

### 4.2 Auditoría de ejes y marcadores (ejecución reciente)

**Importante:** la primera ejecución de la auditoría ocurrió demasiado pronto, antes de que quedara estabilizada la pose de reposo; sus valores iniciales de socket no deben mezclarse con la captura estable. Se añadió una espera de 0,3 s al harness y se repitió. La captura estable reportó socket `(-0.0, 1.389028, -0.119967)`, weapon root `(0.122385, 1.300718, -0.148584)`, y `RGRIP` mundial exactamente en socket. Esta coincidencia corresponde al banco experimental socket-driven, no prueba que producción coloque el origen del arma allí.

La auditoría estable imprimió estos valores (captura concreta, no constantes universales):

- `RGRIP` local: `(0.027967, 0.028840, 0.083699)`
- `LGRIP` local: `(-0.051078, 0.106556, -0.281710)`
- separación local R–L: `0.381853 m`
- `SIGHT_BACK → SIGHT_FRONT`: ángulo con `-WeaponRoot.basis.z = 0°`
- `RGRIP → MUZZLE`: ángulo con `-WeaponRoot.basis.z ≈ 6.827°`
- distancia de `RGRIP` al muzzle en el modelo: aproximadamente 0,75 m
- distancia `ik_hand_gun`→RGRIP reportada por auditoría: 0 en el frame estable de la captura (la coincidencia se obtiene con la variante socket-driven; no asumir que aplica al base layer de producción).
- targets `LeftArmIK`: root `arm_l`, middle `forearm_l`, end `hand_l`, target path `../../../../LeftHandIKTarget`; pole no asignado.

Las bases locales de RGRIP/LGRIP tienen rotaciones distintas. Eso puede ser intencional si se usan para orientar cada mano. El código actualmente pasa la rotación de los marcadores a `GripTarget`, no solo sus posiciones.

### 4.3 Convenciones de ejes

Godot interpreta el forward típico de un `Node3D`/cámara como `-basis.z`. `basis.z` es el vector opuesto. Que un objeto apunte hacia abajo en pose segura no demuestra una inversión: puede ser la orientación intencional del arma en esa pose.

La evidencia muzzle/miras de la captura apoya `-Z` como forward longitudinal del arma. Invertir todos los `basis.z` no está justificado y puede cambiar el eje 180° y descomponer las demás poses.

## 5. Intentos realizados y resultados

### A. Banco original y experimental

- **Hecho:** se mantuvieron bancos persistentes separados para no alterar producción.
- **Resultado:** la variante experimental no resolvió el alcance izquierdo.
- **Estado:** conservar ambos como comparadores.

### B. Target `LGRIP` y alcance

- **Prueba:** comparar marcador mundial, `GripTarget`, target IK, mano y longitudes de la cadena.
- **Resultado:** marcador y target transferido coinciden; target fuera del alcance estimado.
- **Conclusión acotada:** descarta un error grande en esa transferencia de coordenadas, no descarta mala colocación del marcador ni postura incompatible.

### C. Activar/desactivar influencia de IK

- **Prueba:** cambiar temporalmente `LeftArmIK.influence` de 0 a 1.
- **Resultado observado:** desplazamiento mínimo en la medición original.
- **Límite:** target inalcanzable y evaluación temporal no controlada; hace falta probar un target conocido y alcanzable.

### D. Arma derivada del socket

- **Prueba:** usar la pose de `ik_hand_gun` para el arma y alinear la raíz/RGRIP en runtime, sin guardar cambios.
- **Resultado:** una medición anterior dio `LGRIP` aún más lejos de la mano (~64,6 cm vs ~59,9 cm en esa ejecución); otra medición encontró `RGRIP` a ~9,3 cm del origen del socket según el montaje temporal usado.
- **Conclusión acotada:** no valida el flujo exacto de Blender. Revela que es necesario distinguir `socket origin`, `weapon root` y `RGRIP`, y calibrar el transform relativo.

### E. Inversiones iterativas de base

- **Prueba:** en memoria, reflejar X, Y o Z por separado y probar una combinación de dos ejes para recuperar una base propia.
- **Resultado:** una inversión de eje tiene determinante negativo (reflexión, no una rotación rígida); la combinación de dos cambia dónde caen ambos grips. Ninguna variante estableció una solución compatible con montaje, muzzle/miras y alcance.
- **Conclusión:** no aplicar inversión global basada solo en apariencia o en la dirección segura.

### F. Diagnóstico automático del banco experimental

- **Cambio:** `weapon_ik_test.gd` incluye `run_transform_audit`; imprime socket, raíz del arma, transforms de grips, ejes de muzzle/miras y configuración del IK.
- **Configuración:** `run_transform_audit = true` en `weapon_ik_test_experimental.tscn`.
- **Alcance del cambio:** harness de prueba únicamente; no cambia código de producción ni el GLB.
- **Uso:** ejecutar el banco y revisar la consola buscando `WEAPON TRANSFORM AUDIT`.

## 6. Incongruencias que merecen comprobación

1. **Socket no necesariamente es RGRIP.** El código del layer base calcula la posición del arma usando el grip derecho y una posición anatómica aproximada. El socket aporta orientación, no necesariamente origen de montaje.
2. **Espacios y jerarquía del visual.** El cache usa `weapon.global_transform.affine_inverse() * marker.global_transform`. El visual se reparenta bajo `WeaponRoot` y se fuerza a transform local identidad. Esta estrategia es coherente si la raíz usada durante cache representa el frame de arma previsto; confirmar que los markers realmente pertenecen al GLB/escena y no a una escena adjunta con offsets diferentes.
3. **Transform y punto de pivot.** `Transform3D(basis, origin)` establece la posición del nodo raíz. Para hacer coincidir RGRIP con socket se requiere compensar el offset local de RGRIP usando la misma base efectiva: `weapon_origin = socket_position - weapon_basis * rgrip_local.origin`. Alinear el origen del arma con socket sin esa compensación no alinea necesariamente RGRIP.
4. **Rotación local de markers.** El target del IK recibe también la rotación del marcador. Hay que verificar que los ejes locales del marker expresen la orientación esperada de la palma, no solo que su posición esté bien.
5. **Posición natural hard-coded.** `IDLE_DIRECTION = (0, -0.8, 0.3)` y longitud de brazo estimada derivada de clavicle→hand influyen en la posición del arma. Validar la mano resultante contra la animación; el vector no reemplaza una medición del socket/pose.
6. **Estado seguro.** `WeaponLayerAim` conserva orientación del layer base a peso de aim cero. Una orientación descendente puede ser deliberada; verificar signo con los puntos muzzle/sight en esa misma pose antes de invertir.
7. **Orden de actualización.** `WeaponController` corre en `_process`; el solver pertenece al pipeline SkeletonModifier. Capturar datos en fases explícitas (antes/después de modificadores) para evitar comparar transforms de frames diferentes.

## 7. Pendientes de investigación

Prioridad sugerida:

1. **Validar mapa de marcadores en Godot.** Determinar su ruta real en escena, parent del marker y transforms locales acumulados desde raíz de arma hasta marker. Contrastar con Blender.
2. **Comparar Blender/Godot con una única pose congelada.** Registrar matrix 4×4 (o posición + tres ejes ortonormales) de `ik_hand_gun`, weapon origin, RGRIP y LGRIP. Comparar después de conversión de coordenadas/importación.
3. **Probar montaje por transformación relativa calibrada.** Mantener `RGRIP` en el socket mediante compensación del origen y conservar la base del socket. No hacer flip de ejes durante esa prueba.
4. **Target sintético alcanzable para el solver izquierdo.** Situarlo cerca de la posición actual de la mano y, por etapas, moverlo hacia `LGRIP`. Registrar posiciones de shoulder/arm/forearm/hand con influencia 0 y 1 y confirmar si cambia la cadena.
5. **Revisar alcance anatómico real.** Medir longitudes exactas por transforms globales de huesos y calcular límite geométrico desde raíz de TwoBoneIK (no desde clavícula si el modifier arranca en `arm_l`). Incluir extensión/end bone y escala de Skeleton.
6. **Revisar pole/codo.** Solo después de verificar reach: añadir/probar dirección de codo/pole válida y confirmar el plano de flexión deseado. Un pole puede controlar plano, no superar falta de longitud.
7. **Verificar correspondencia visual.** Inspeccionar si LGRIP cae en la zona de guardamanos donde debe apoyarse la palma. Es decisión anatómica/de diseño, no deducible solo del vector.
8. **Comparación de tres posturas:** reposo seguro, pose de hombro relajado/arma ready y aiming. Confirmar si el offset solo falla en una postura.

## 8. Matriz de hipótesis y prueba discriminante

| Hipótesis | Evidencia actual | Prueba discriminante |
|---|---|---|
| Forward de arma está invertido | Muzzle y eje de miras concuerdan con `-WeaponRoot.basis.z` en captura | Probar una sola pose y medir ángulos `±basis.z` contra RGRIP→MUZZLE y sight line |
| Offset entre socket y frame del arma está mal | Root y RGRIP son puntos distintos; montaje directo temporal produjo discrepancia | Montaje compensado por `RGRIP` local, medir socket↔RGRIP en el mismo frame |
| LGRIP mal posicionado en asset | Target remoto; marcador y target coinciden | Inspección visual del marcador sobre guardamanos y comparación Blender/Godot |
| Pose corporal/arma incompatible | Distancia supera alcance estimado | Colocar LGRIP/pose alternativa dentro del alcance; comparar shoulder/elbow/wrist |
| Solver no procesa o está mal configurado | Influencia 0/1 no produjo movimiento apreciable en prueba anterior | Target sintético alcanzable, callback/order confirmados, medir transform antes/después del solver |
| Basis local de grip mal orientada | Bases de RGRIP/LGRIP distintas; se propagan al target | Visualizar ejes locales de marcadores y orientación resultante de mano/palma |

## 9. Criterios antes de cualquier arreglo de producción

No tocar el GLB ni el layer de producción hasta demostrar al menos:

- que los transforms local↔world coinciden con el cálculo esperado;
- que el forward de muzzle/sight tiene una convención definida y consistente;
- que la compensación de `RGRIP` con el socket es correcta;
- que el target izquierdo es anatómicamente correcto y alcanzable en la pose prevista;
- que el solver resuelve un target sintético alcanzable;
- que la solución no rompe aim, reposo seguro ni otra pose.

## 10. Archivos relevantes

- `res://Player/Scripts/WeaponController.gd` — composición en `_process`, cache de grips, `_build_grip_target()`.
- `res://Player/Scripts/WeaponLayerBase.gd` — orientación del socket y posición mediante RGRIP/posición natural.
- `res://Player/Scripts/WeaponLayerAim.gd` — blend de orientación hacia cámara.
- `res://Player/Scripts/FullBodyIKController.gd` — target IK izquierdo y pesos.
- `res://Tests/IK/WeaponLayerSocketPositionTest.gd` — variante socket-only.
- `res://Tests/IK/weapon_ik_test.gd` — harness, diagnóstico J y auditoría transform.
- `res://Tests/IK/weapon_ik_test_experimental.tscn` — escenario experimental.
- `res://World/Items/M4RIFLE/weaponSceneEquipped.tscn` — marcadores MUZZLE/SIGHT añadidos fuera del GLB.
- `res://World/Items/M4RIFLE/M4RIFLE.glb` — geometría/modelo importado; no modificado en esta sesión.

## 11. Resultado de la sesión

Se añadió instrumentación para hacer reproducible la inspección de bases y transformaciones del arma. No se estableció una causa raíz única. La evidencia actual favorece investigar primero la composición posición/socket/RGRIP y la geometría del target izquierdo; no justifica invertir globalmente `-basis.z` ni rotar el modelo completo 180°.
