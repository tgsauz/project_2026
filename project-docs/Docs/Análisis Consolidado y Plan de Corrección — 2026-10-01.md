---
title: Análisis Consolidado y Plan de Corrección
type: analysis
status: parcial-aplicado
date: 2026-10-01
engine: Godot 4.7.2
scope: consolidación de auditoría + errores nuevos; corrección por riesgo
tags:
  - analysis
  - risk-matrix
  - godot
  - stabilization
---

# Análisis Consolidado y Plan de Corrección

> [!info] Objetivo
> Comparar **todo lo observado** (auditoría + errores descubiertos en runtime) en una sola matriz, marcar el **estado real** de cada hallazgo, mapear **dependencias entre errores** (crítico → bajo/medio) y ejecutar las correcciones de **bajo/medio riesgo que son seguras e independientes**. Los que dependen de una decisión crítica quedan **explícitamente diferidos** con su razón.

## Leyenda

- **Sev (severidad):** `P0` roto · `P1` comportamiento incorrecto · `P2` código muerto · `P3` inconsistencia arquitectónica · `P4` feature futura.
- **Nivel (riesgo del cambio):** `1` trivial · `2` local/seguro · `3` toca contrato entre sistemas (requiere decisión) · `4` crítico (requiere aprobación).
- **Estado:** ✅ hecho · 🟡 parcial · ⏸️ diferido (decisión) · ⚪ sin acción justificada.

---

## 1. Matriz maestra de hallazgos

| ID | Hallazgo | Tipo | Sev | Nivel | Estado |
|---|---|---|---|---|---|
| **B1** | Null-ref en `FullBodyIKController` (tick sin deps resueltas) | bug | P0 | 2 | ✅ U1 |
| **B2** | `CharacterRigAssembly` asumía `CharacterBody3D`/`AimController` | bug | P0 | 2 | ✅ U1 |
| **B3** | Smoke test con contrato IK obsoleto | test | P1 | 2 | ✅ U2 |
| **B4** | `WeaponActionController` usa `rpc_id`/`@rpc` sin peer | falso-positivo | — | — | ✅ reclasificado (R4) |
| **B5** | ADS **nunca se conecta**: `weapon_ads_profile` sin lector; `set_ads_profile`/`get_ads_blend_state` sin **ningún** caller; `TestWeaponADSProfile.tres` vacío | incompleto | P4 | 3 | ⏸️ |
| **B6** | `StatusClusterUI` resolvía `"/root/UIRoot"` (UIRoot no es autoload) | bug | P1 | 2 | ✅ F3 |
| **B7** | `InventoryComponent` divide por `base_capacity` sin guardar | bug | P1 | 1 | ✅ F1 |
| **B8** | `GripTarget.is_valid=true` sin posiciones (`_marker_cache_valid` incondicional) | bug | P1 | 2 | 🟡 F6 |
| **B9** | `allowed_slots` vacío con semántica contradictoria (`can_fit_in_slot` vs resto) | inconsistencia | P3 | 1 | ✅ F5 |
| **PB1** | `InteractionPromptData` (Resource) nunca instanciado | código muerto | P2 | 2 | ✅ R5 |
| **PB2** | Doble `CollisionShape3D` en items soltados | bug | P1 | 2 | ✅ F4 |
| **PB3** | `ItemInstance` desechable por nodo en `_get_attachment_candidate_order` | perf | P3 | 1 | ✅ F2 |
| **PB4** | Parámetros de API pública sin tipar | estilo | P3 | 2 | ⏸️ (opcional) |
| **PB5** | Posible jitter del pivote FPS (ojo anclado al hueso de cabeza cada frame) | game-feel | P1 | 3 | ⏸️ |
| **PB6** | `affine_inverse()` riesgo degenerado | riesgo | P3 | 1 | ⚪ sin evidencia |
| **AR1** | Dos generaciones de posicionamiento de arma coexistían | arq. | P3 | 3 | ✅ R5 |
| **AR2** | Tres fuentes de verdad para la ocupación de inventario | arq. | P3 | 3 | ⏸️ |
| **AR4** | Dependencias por **nombre de nodo hijo** (no inyección) | arq. | P3 | 3 | ⏸️ (raíz de R3) |
| **AR5** | Andamiaje multiplayer sin peer | arq. | P4 | — | ⏸️ |
| **AR6** | `CharacterController` parcialmente God-object (614 líneas) | arq. | P3 | 3 | ⏸️ |
| **AR7** | `CameraController` búsqueda global `find_child("InventoryViewController")` | arq. | P3 | 1 | ⏸️ (impacto bajo) |
| **R3** | 3× `FullBodyIKController could not resolve …` solo en el Tuner | riesgo (boundary) | P1 | 3 | ⏸️ |
| **U5** | Ternarios 4.7 (`StringName` vs `String`) en `WeaponDiagnosticLogger` | migración | P1 | 2 | ✅ U5 |

---

## 2. Mapa de dependencias (crítico ↔ bajo/medio)

> [!warning] Regla clave
> Hay hallazgos de bajo/medio impacto que **no deben parchearse individualmente**: son *síntomas* de una causa estructural. Parchear el síntoma hace que el problema **reaparezca** por otra vía.

**Clúster A — Resolución de dependencias / ownership** (raíz: **AR4**)
- `AR4` (deps por nombre de nodo hijo) → causa **R3** (el Tuner no puede resolver `CharacterController`/`AimController`/`VisualsComponent`) y comparte forma con **B2** y **B6** (rutas/nombres asumidos).
- **Consecuencia:** `B6` se corrigió con un *ancestor-walk local* (seguro, contenido), pero si algún día se adopta **inyección explícita** (AGENTS prioridad 1–2), `B6`, `R3` y las rutas por nombre deberían resolverse por inyección y el parche local de `B6` se revisaría.
- **R3 NO se parchea como síntoma.** Bajar `push_error`→`push_warning` ocultaría un problema de contrato. La solución correcta es decidir el modelo de ownership.

**Clúster B — Pipeline arma/IK** (raíz: **AR1**, ya resuelto)
- `AR1` (dos generaciones) → resuelto al eliminar la legacy (`WeaponOffsetCache`/`WeaponPositionController`).
- `B8` **núcleo** corregido; queda la **validez por mano** (si solo resuelve `RGRIP`, `is_valid=true` con la mano izquierda en un target obsoleto). Es la cara "parcial" que sobrevive al fix.

**Clúster C — Cámara**: `PB5` (jitter del ojo FPS) es de *diseño* (suavizado), no un bug de una línea.

**Clúster D — Inventario**: `AR2` (3 fuentes de verdad) es estructural; `B7`/`B9`/`PB3` eran locales y ya están resueltos sin tocar `AR2`.

**Clúster E — UI/presentación**: `B6` (resuelto) y `PB1` (muerto, eliminado).

---

## 3. Aplicado en esta pasada (bajo/medio, seguro e independiente)

| Fix | Archivo | Cambio | Verificación |
|---|---|---|---|
| **F1 · B7** | `World/Items/Scripts/InventoryComponent.gd:475` | `load_factor = max(total/base,0) if base_capacity > 0.0 else 0.0` | `base_capacity=0` → `load_factor=0.0`, `is_finite=true` |
| **F2 · PB3** | `InventoryComponent.gd` (`_get_attachment_candidate_order`) | Un único `ItemInstance` probe reutilizado en el bucle (antes: 1 por nodo) | Sin cambio de salida; sin allocs por nodo |
| **F3 · B6** | `Player/Debug/Scripts/StatusClusterUI.gd` | Ancestor-walk **acotado** hasta `UIRoot` en vez de `"/root/UIRoot"` | `UIRoot.get_layout_manager()` ahora sí se resuelve |
| **F4 · PB2** | `Player/Scripts/CharacterController.gd` (`_spawn_dropped_world_item`) | Collider de respaldo solo si la definición **no** tiene `world_visual_scene` | Soltar arma: **1** colisión (antes 2) |
| **F5 · B9** | `World/Items/Scripts/ItemDefinition.gd` | Eliminado `can_fit_in_slot` (helper duplicado, semántica opuesta, **0** callers) | Sin referencias en `.gd/.tscn/.tres` |
| **F6 · B8** | `Player/Scripts/WeaponController.gd:249` | `_marker_cache_valid = rgrip != null or lgrip != null` (antes: `true` incondicional) | `GripTarget` ya no es `valid` sin marcadores |

**Evidencia de validación:** smoke test `EXIT 0` (verde) · arranque de `testing_world.tscn` sin errores de sesión · sondeo runtime de B7 y PB2.

### Crítica de las soluciones (¿robusta / modular / óptima?)

- **F1.** Correcta y no destructiva. *Tradeoff:* silencia un mal config en vez de señalarlo. Mejora opcional: un `push_warning` único si `base_capacity <= 0`.
- **F2.** Óptima: elimina *churn* sin cambiar contrato. La versión "pura" sería un `can_attach_definition(def, node)` sin allocación, pero es refactor; el hoist es el mínimo correcto.
- **F3.** Robusta dentro de lo permitido (AGENTS autoriza *parent traversal acotado*). *Deuda:* sigue asumiendo que el componente cuelga de un `UIRoot`. Mejor a largo plazo: que **`UIRoot` inyecte** su `layout_manager` (dueño explícito).
- **F4.** Corrige el **ownership**: ahora `WorldItem` es el dueño de generar el collider del item del mundo y `CharacterController` solo aporta respaldo. *Deuda restante:* el respaldo es una caja mágica fija (`0.35,0.25,0.2`) independiente del tamaño real del item.
- **F5.** Elimina la ambigüedad de raíz. Alternativa si se quiere conservar el helper: alinear su semántica a *"vacío = permisivo"* (la convención dominante del resto del código).
- **F6.** Corrige el **núcleo** del bug con una línea. **No** completa el caso por-mano (ver §4).

---

## 4. Diferido — requiere decisión (con recomendación)

| ID | Por qué se difiere | Recomendación |
|---|---|---|
| **R3** | Es **síntoma** de AR4 (ownership). Parchear el log oculta el contrato. | Decidir el modelo: **inyección explícita** de dependencias del jugador en `FullBodyIKController` (o hacer explícito un modo "sin host"). Nivel 3. |
| **B5 (ADS)** | Feature **incompleta**, no bug: hay setters sin caller y un `.tres` vacío. Cablearla inventa diseño. | Decidir el flujo `ItemDefinition.weapon_ads_profile → WeaponController.set_ads_profile → AimController.set_ads_profile → FOV de cámara`, y **crear datos** de perfil. Nivel 3. |
| **PB5 (jitter ojo FPS)** | Es *game-feel*: exige elegir técnica (damping/offset fijo). | Medir con `run_scene speed` en FPS antes de tocar; luego damped-follow del ojo. Nivel 3. |
| **B8 (parcial)** | Completar la validez **por mano** exige ampliar `GripTarget` + ponderación por mano en FBIK (contrato entre 3 clases). | Añadir flags `right_valid`/`left_valid` a `GripTarget` y que FBIK pondere cada brazo por su flag. Nivel 3. |
| **AR2** | Tres fuentes de verdad (grafo de adjuntos + `slot_state` + `slot_configs`). | Definir **una** fuente autoritativa y derivar el resto. Nivel 3. |
| **AR4** | Raíz de R3; toca el contrato de dependencias de varios sistemas. | Adoptar inyección explícita en los puntos que hoy usan rutas por nombre. Nivel 3. |
| **AR6** | God-object parcial. | Extraer responsabilidades (p.ej. spawn de items, resolución de deps) en componentes. Nivel 3. |
| **AR7** | Impacto real bajo: se resuelve una vez y luego early-return cada frame; solo re-escanea si el nodo se libera. | Inyectar el `InventoryViewController` (p.ej. export o vía `UIRoot`) para eliminar el lookup global. Nivel 1–2. |
| **PB4** | Estilo, sin bug. | Tipar parámetros de las funciones señaladas de forma incremental. Nivel 2. |
| **PB6** | Sin evidencia de fallo (solo importa con escala no uniforme). | Monitorizar; no tocar sin reproducir. |
| **AR5** | Multiplayer no soportado por el tier actual. | Mantener el diseño *multiplayer-aware*, sin escribir networking. |

---

## 5. Observación de runtime (fuera de alcance)

Al arrancar `testing_world.tscn` la vista FPS muestra cielo, una banda oscura de suelo cerca del horizonte y una amplia región azul por debajo, con un objeto vertical al centro. No produce errores, pero conviene revisar aparte si la cámara/pivote FPS o el material del suelo no están como se espera. **No** forma parte de este análisis de errores.

---

## 6. Conclusión

- Se resolvieron **8 hallazgos** adicionales de bajo/medio riesgo, todos **independientes** y **verificados** (smoke verde + arranque limpio + sondeos).
- Se **evitó** parchear el síntoma de **R3** y de **B8-parcial** por estar atados a causas estructurales (AR4 / contrato de `GripTarget`), tal como pediste.
- Los pendientes se agrupan en **4 decisiones de diseño** (ownership de dependencias, ADS, jitter de cámara, validez por mano) + 2 arquitectónicas (`AR2`, `AR6`). Ninguna es un parche trivial; todas requieren elegir el **contrato** antes de tocar código.

---

*Documento de análisis. Refleja el filesystem actual y la evidencia de runtime del 2026-10-01.*

> **Correccion 2026-10-14 (T10).** Este documento es un registro con fecha; se conserva tal cual. A partir de T10 el IK de brazos, `GripTarget` y los objetivos de mano **se borraron por inertes** (medido: 0.000000 m de respuesta). Todo lo que aqui los describe como vivos describe un estado que ya no existe.
