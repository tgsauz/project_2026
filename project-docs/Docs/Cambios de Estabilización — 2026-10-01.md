---
title: Cambios de Estabilización — Primera Pasada
type: changelog
status: aplicado
date: 2026-10-01
engine: Godot 4.7.2
scope: primera pasada de estabilización controlada (post-auditoría)
tags:
  - changelog
  - stabilization
  - godot
  - ik
  - smoke-test
---

# Cambios de Estabilización — Primera Pasada

> [!info] Alcance
> Resumen de todos los cambios aplicados **desde la directiva de "estabilización controlada"**. Es un registro factual; no incluye recomendaciones ni rediseños.
> Fuente de verdad: el filesystem actual. Todos los cambios se validaron ejecutando el smoke test real en headless.

## Resultado global

| Métrica | Antes | Después |
|---|---|---|
| Smoke test (`dependency_smoke_runner.gd`) | ❌ 4 fallos (EXIT 1) | ✅ 0 fallos (EXIT 0) |
| `SCRIPT ERROR` por frame | 3 | **0** |
| `Node not found` / `CharacterBody3D not found` | 2 | **0** |
| Referencias colgantes tras limpieza | — | **0** |
| Errores de parse/script tras eliminaciones | — | **0** |
| Errores de reload del editor (ternarios 4.7) | 4 | **0** |

Comando de verificación:

```bash
godot --headless --path . --script res://Tests/Smoke/dependency_smoke_runner.gd
# → "Dependency smoke tests passed."  (exit 0)
```

---

## U1 — P0: endurecer el stack IK/rig ante dependencias no resueltas

**Archivos:** `Player/Scripts/FullBodyIKController.gd`, `Player/Scripts/CharacterRigAssembly.gd` *(untracked en git)*

**Síntoma:** cada frame, 3× `SCRIPT ERROR: Nonexistent function 'has_main_hand_weapon' in base 'Nil'`; en el CharacterTuner además `Node not found: "../../../../../../AimController"` y `CharacterRigAssembly: CharacterBody3D not found`.

**Causa raíz:**
1. `FullBodyIKController._ready()` llamaba `_resolve_dependencies()`; al fallar, hacía `return` temprano (nunca cacheaba estado), **pero** el motor seguía invocando `_process_modification_with_delta()`, que desreferenciaba `_character_controller` (null) en `_compute_weight_targets()`.
2. `_resolve_dependencies()` usaba `get_node()` (emite error duro si la ruta no existe).
3. `CharacterRigAssembly` trataba la ausencia de un ancestro `CharacterBody3D` como error, aunque el Tuner reusa el rig legítimamente (sin host de jugador).

**Cambio:**
- `FullBodyIKController`: nuevo flag `_initialized` (false por defecto). El tick es **no-op** mientras `not _initialized`; se marca `true` solo al final de un `_ready()` exitoso. `get_node` → `get_node_or_null` en las 6 resoluciones.
- `CharacterRigAssembly._create_weapon_root()`: si no hay `CharacterBody3D`, retorna en silencio (contexto no-jugador esperado).

**Invariante establecido:** *un `SkeletonModifier3D` que no resolvió sus dependencias nunca modifica el esqueleto.*

**Comportamiento del Player:** sin cambios (en el Player las rutas resuelven igual).

**Riesgo:** Nivel 2 (corrección local, ownership claro). **Validado:** SCRIPT ERROR 3→0; errores de arranque 2→0.

---

## U2 — Smoke test: contrato de layout IK actualizado al comportamiento real

**Archivo:** `Tests/Smoke/dependency_smoke_runner.gd` → `_test_player_ik_layout_contract()`

**Motivo:** el test verificaba una estructura y un orden que ya no existen (rutas `Rig/Armature`, targets bajo el armature, y una lista de modificadores que incluía nodos legacy `WeaponOffsetCache`/`WeaponPositionController`).

**Verdad de runtime confirmada** (sondeo headless, no inferida):
- Skeleton en `Rig/ImportedModel/Armature/Skeleton3D`.
- Targets `AimIKTarget`/`RightHandIKTarget`/`LeftHandIKTarget` son hijos directos de `Rig`.
- Orden de `SkeletonModifier3D`: `[CCDIK, FullBodyIKController, RightArmIK, LeftArmIK, HeadCCDIK, SpineLookAtController]`.

**Cambio:** el test ahora valida esa estructura y el invariante load-bearing real (que `FullBodyIKController` se ejecute **antes** de `RightArmIK`, para escribir los hand targets primero), en vez de una lista exacta acoplada a la implementación.

**Validado:** los 2 asserts de IK dejan de fallar.

---

## U3 — Datos de items (según decisión de diseño del owner)

| Archivo | Cambio | Motivo |
|---|---|---|
| `World/Items/simpleBackpack/simpleBackpack.tres` | `container_allowed_categories` y `storage_allowed_categories` ahora incluyen `"weapon"` | La mochila **sí** debe aceptar armas |
| `World/Items/simpleBelt.tres` | `visible_when_equipped = true` | El cinturón **debe** crear visual runtime |

**Efecto:** `store_item_in_container(arma, mochila)` ahora es `true` (capacity 8 ≥ item size 3). El cinturón entra en `get_equipped_visuals()` y crea su entrada de visual (placeholder, no hay malla de cinturón).

**Riesgo:** Nivel 2 (datos, sin código de gameplay). **Validado:** los 2 asserts de inventario pasan.

---

## U4 — Limpieza de código muerto (confirmado sin consumidores)

### Ediciones de desacoplamiento (antes de borrar)
| Archivo | Cambio |
|---|---|
| `Player/Scripts/CharacterRigAssembly.gd` | Eliminadas las funciones **no llamadas** `_create_weapon_offset_cache()` y `_create_weapon_position_controller()` y sus comentarios |
| `Player/Debug/UIRoot.gd` | Eliminado el campo `var inventory_action_menu: InventoryItemActionMenu` (declarado, nunca instanciado) |

### Archivos eliminados (14; todos rastreados por git → recuperables)
| Grupo | Archivos |
|---|---|
| Scratch / roto | `check_glb.gd`, `Player/list_anims.gd` |
| Sueltos sin uso | `World/Items/Scripts/InventoryConstants.gd`, `World/Items/Scripts/InteractionPromptData.gd`, `World/Items/simpleRifle.tres` |
| TerrainGen (par cerrado) | `Procedural Generation/TerrainGen.gd`, `TerrainGen.tscn` |
| Catálogo de slots legacy (cluster cerrado) | `EquipmentSlotCatalog.gd`, `EquipmentSlotDefinition.gd`, `EquipmentSlotLibrary.gd`, `Config/DefaultEquipmentSlotCatalog.tres` |
| **IK heredado** | `Player/Scripts/WeaponOffsetCache.gd`, `Player/Scripts/WeaponPositionController.gd` |
| UI sin uso | `Player/Scripts/InventoryItemActionMenu.gd` |

Los sidecars `.gd.uid` fueron limpiados automáticamente por el editor (no quedan huérfanos).

**NO eliminado (verificado que SÍ se usa):** `World/Items/Scripts/InteractableEntity.gd` (`class_name WorldInteractable`) — referenciado por `InteractionComponent.gd` (`is WorldInteractable`).

**Riesgo:** Nivel 2. **Validado:** grep sin referencias colgantes (fuera de `.godot/`), smoke EXIT 0, 0 errores de parse.

---

## U5 — Compatibilidad GDScript 4.7: ternarios con tipos incompatibles

**Archivo:** `Player/Scripts/WeaponDiagnosticLogger.gd` (líneas 98, 122, 172, 183)

**Síntoma:** al correr la escena en el editor aparecían 4× `GDScript::reload: Values of the ternary operator are not mutually compatible.`

**Causa raíz:** en Godot **4.7** un ternario exige ramas de tipo compatible. `Node.name` es `StringName`, mientras que el literal `"null"` es `String`; por tanto `nodo.name if cond else "null"` mezcla `StringName` con `String`. Es una **incompatibilidad introducida por la migración 4.6 → 4.7** (el código se escribió para 4.6.1).

**Cambio:** envolver la rama del nombre en `String(...)` para que ambas ramas sean `String`. Sin cambio de comportamiento (solo texto que se vuelca a un `.log`).

> [!note] Detectabilidad
> Ni `godot --check-only` en headless ni el runtime lo señalan (el juego arranca igual); solo lo reporta el **analizador estricto del editor** al recargar el script. Se corrige igualmente por ser un error objetivo de migración.

**Riesgo:** Nivel 2. **Validado:** la corrida de `testing_world.tscn` ya no reporta errores de sesión.

---

## Validado en runtime (esta pasada)

- **Arranque:** `World/testing_world.tscn` abre, instancia el jugador, carga 9 definiciones de items y renderiza (horizonte, suelo, retícula) **sin errores de sesión**.
- **Disparo / R4:** con un arma equipada en `right_hand`, `WeaponActionController._request_fire()` se ejecuta **sin error** (sondeo headless determinista). `rpc_id` sin peer **no** falla; en single-player el nodo actúa como autoridad/servidor local. → **R4 reclasificado:** **NO** es un bug de runtime; es una decisión de arquitectura (round-trip a un servidor que no existe) = deuda técnica **P3**, no un P1.

---

## Pendiente (clasificado, NO aplicado)

| ID | Hallazgo | Clase | Nota |
|---|---|---|---|
| **R3** | 3× `ERROR: FullBodyIKController could not resolve …` **solo** en el CharacterTuner | RISK (boundary, Nivel 3) | No es crash; el rig se crea en un contexto donde sus dependencias de jugador no existen. Requiere decisión de ownership. |

---

## Rollback

- **Archivos eliminados** (rastreados): `git restore -- <ruta>` (o `git checkout -- <ruta>`).
- **Ediciones** sobre archivos rastreados: revisar con `git diff`; revertir con `git restore -- <ruta>`.
- **`Player/Scripts/CharacterRigAssembly.gd`**: es **untracked** en git → no tiene base para `git restore`; sus cambios deben revertirse a mano si fuera necesario.
- No se hizo commit de ninguno de estos cambios.

---

*Documento generado como registro de la primera pasada de estabilización. No representa funcionalidad nueva; son correcciones P0, sincronización de un test obsoleto, ajustes de datos y limpieza de código muerto confirmado.*

> **Correccion 2026-10-14 (T10).** Este documento es un registro con fecha; se conserva tal cual. A partir de T10 el IK de brazos, `GripTarget` y los objetivos de mano **se borraron por inertes** (medido: 0.000000 m de respuesta). Todo lo que aqui los describe como vivos describe un estado que ya no existe.
