---
title: Cambios — Ownership de IK y Contrato GripTarget
type: changelog
status: aplicado
date: 2026-10-01
engine: Godot 4.7.2
scope: Parte A (ownership/resolución de dependencias de FullBodyIKController) + Parte B (validez por-mano de GripTarget)
tags:
  - changelog
  - ik
  - ownership
  - godot
---

# Cambios — Ownership de IK y Contrato GripTarget

> [!info] Dirección aprobada
> Implementa la recomendación del "Análisis Arquitectónico" en **dos pasos separados**: Parte A (ownership) y Parte B (contrato), más un fix de datos del Tuner. Todo verificado en runtime.

## Resultado

| Verificación | Antes | Después |
|---|---|---|
| Errores `FullBodyIKController could not resolve …` (Tuner) | 3 | **0** |
| Warnings `skeleton_path could not be resolved` (Tuner) | 2 | **0** |
| Smoke test | EXIT 0 | **EXIT 0** |
| Errores de sesión en `testing_world` | 0 | **0** |
| Contrato `GripTarget` con 1 marcador | brazo a target obsoleto | **por-mano (brazo relajado)** |

---

## Parte A — Ownership y resolución de dependencias

**Problema:** el rig (`CharacterRigAssembly`) creaba los controladores IK y resolvía por sí mismo dependencias del jugador con `NodePath` de profundidad fija. En el Tuner (rig sin host de jugador) faltaban `CharacterController`/`AimController`/`VisualsComponent` → 3 `push_error`.

**Cambios (archivos):**

| Paso | Archivo | Cambio |
|---|---|---|
| A-1 | `Player/Scripts/FullBodyIKController.gd` | `_ready` → `_try_initialize()` (idempotente). Nuevo `configure(character, aim, visuals)`. `_resolve_dependencies` separa **internos** (targets, obligatorios → `push_error`) de **externos** (opcionales → `_warn_once` + queda inerte). |
| A-2 | `Player/Scripts/SpineLookAtController.gd` | Nuevo `configure(character, aim)` (ya era inerte sin host). |
| A-3 | `Player/Scripts/CharacterController.gd` | Resuelve `_spine_look_at` (hermano del FBIK) y `_inject_ik_dependencies()` inyecta `(self, _aim_controller, visuals_component)` en ambos controladores tras `_resolve_aim_controller()`. |
| A-4 | `Player/Scripts/CharacterRigAssembly.gd` | `_create_runtime_nodes()` no construye el stack IK ni `WeaponRoot` si no hay ancestro `CharacterBody3D` (Tuner). |

**Contrato resultante:** el rig provee el cableado **interno**; el **composition root** (`CharacterController`) inyecta lo **externo**; sin host, los controladores quedan **inertes sin errores**. Los `*_path` exportados se conservan como fallback.

---

## Parte B — Validez por-mano del `GripTarget`

**Problema:** `GripTarget.is_valid` era global y las manos faltantes quedaban en `Vector3.ZERO` (sentinel frágil). Con un solo marcador, el IK ponía **ambos** brazos a peso 1 y el brazo sin objetivo se estiraba a un target obsoleto.

**Cambios (archivos):**

| Paso | Archivo | Cambio |
|---|---|---|
| B-1 | `Player/Scripts/GripTarget.gd` | `right_hand_valid`/`left_hand_valid`; `is_valid` pasa a **derivado** (`right or left`); `set_right_hand`/`set_left_hand` marcan validez. |
| B-2 | `Player/Scripts/WeaponController.gd` | Flags `_rgrip_found`/`_lgrip_found` por marcador; `_build_grip_target` construye por-mano (sin asignar `is_valid`). |
| B-3 | `Player/Scripts/FullBodyIKController.gd` | Ponderación **por brazo** desde `GripTarget`; se elimina el sentinel `!= Vector3.ZERO` y el helper `_set_target_weight` (quedó sin uso). |

**Contrato resultante:** el IK nunca ve `WeaponRoot`; lee flags por-mano. Un arma de una sola mano o sin manos se expresa sin casos especiales; perder un grip baja ese brazo a influencia 0.

---

## Fix de datos — perfil del Tuner

`Tools/CharacterTuner/Config/HumanTunerRigProfile.tres`: `skeleton_path` corregido de `Armature/Skeleton3D` (obsoleto, faltaba el wrapper `ImportedModel`) a **`ImportedModel/Armature/Skeleton3D`**. Elimina los 2 warnings de `VisualsComponent._resolve_tuner_skeleton` (antes funcionaba por fallback recursivo).

---

## Evidencia de validación

- **Smoke test**: `godot --headless --script res://Tests/Smoke/dependency_smoke_runner.gd` → **EXIT 0**, 0 errores de parse, 0 "could not resolve".
- **Tuner** (`CharacterTuner.tscn`): **sin errores ni warnings**; personaje carga y se anima; rig sin nodos IK de gameplay (esperado en autoría).
- **Player** (`testing_world.tscn`): arranca sin errores; con `primary_action` dispara sin errores; arma visible en FPS.
- **Sondeo runtime del contrato**:
  - `GripTarget` vacío → `is_valid=false`; solo derecha → `right_valid=true`, `left_valid=false`, `is_valid=true`; ambas → `is_valid=true`.
  - Productor: R-only → `right=true/left=false`; R+L → ambos true; sin marcadores → ambos false.
  - Equipar M4 → `rgrip_found=true`, `lgrip_found=true` y `FBIK._current_grip_target` con **ambas** manos válidas.

---

## Rollback

- Todos los archivos están rastreados por git salvo `Player/Scripts/CharacterRigAssembly.gd` (**untracked**). Revertir con `git restore -- <ruta>`; el untracked a mano.
- No se hizo commit.

---

*Registro de la implementación. Refleja el filesystem actual y la evidencia de runtime del 2026-10-01.*

> **Correccion 2026-10-14 (T10).** Este documento es un registro con fecha; se conserva tal cual. A partir de T10 el IK de brazos, `GripTarget` y los objetivos de mano **se borraron por inertes** (medido: 0.000000 m de respuesta). Todo lo que aqui los describe como vivos describe un estado que ya no existe.
