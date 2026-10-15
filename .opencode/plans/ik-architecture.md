# IK Architecture (2026-06-04)

> # ⚠️ DOCUMENTO HISTÓRICO — LEER ANTES DE NADA
>
> **Fecha del contenido:** 2026-06-04. **Estado real del código:** 2026-10-14.
> Este archivo se escribía como arquitectura vigente y un agente lo leía
> **antes** que el código. Ya no lo es: describe un estado anterior. Se conserva
> sin reescribir porque es el registro de por qué se decidió así.
>
> ## De los 7 sistemas listados abajo, solo sobrevive UNO
>
> | # | Sistema de la lista | Estado real a 2026-10-14 |
> |---|---|---|
> | 1 | `WeaponOffsetCache` | ❌ borrado — commit `abae6cc` |
> | 2 | `SpineController` | ⚠️ **no existe con ese nombre**; el nodo vivo es `SpineLookAtController`, y escribe desde `_process`, no como `SkeletonModifier3D` (ADR-0008) |
> | 3 | `WeaponPositionController` | ❌ borrado — commit `abae6cc` |
> | 4 | `FullBodyIKController` | ❌ borrado — T12, commit `83d5c86` |
> | 5 | `RightArmIK` | ❌ borrado — T10, commit `7961fd3` |
> | 6 | `LeftArmIK` | ❌ borrado — T10, commit `7961fd3` |
> | 7 | `HeadLook` (el sector de cabeza, sobre `AimIKTarget`) | ❌ borrado — T12, commit `83d5c86` |
>
> **Motivo de las bajas, medido y no supuesto:** en esta versión del motor
> **ningún `SkeletonModifier3D` escribe huesos** —ni `CCDIK3D`, ni `TwoBoneIK3D`,
> ni `LookAtModifier3D`—, por la misma razón que hace que `AnimationTree` sí
> escriba con normalidad. ADR-0008 lo midió; T10 y T12 lo confirmó antes de borrar.
>
> **Sobrevive exactamente un escritor sobre el esqueleto:** `SpineLookAtController`,
> y solo porque escribe desde `_process`. El orden de modificadores que describe
> este documento ya **no importa**: con un único escritor no hay orden que
> afirmar.
>
> ## Cómo usar este archivo
>
> Sirve como **registro histórico** y como explicación del diseño original. No
> lo trates como especificación. Para el estado vigente, lee en este orden:
> `project-docs/GLOSSARY.md` → `project-docs/ADRs/` → el código.

## Modifier Execution Order

> ⚠️ **Caducado.** Esta lista de 7 modificadores ya no describe nada que exista;
> ver la nota de cabecera. Hoy queda un solo escritor, `SpineLookAtController`,
> y el orden entre modificadores es irrelevante.

1. `WeaponOffsetCache` — captures spine_02 + ik_hand_gun + arm_r animation poses
2. `SpineController` — spine IK bend for aiming pitch/twist/tilt
3. `WeaponPositionController` — chest-corrected weapon pose (no independent rotation)
4. `FullBodyIKController` — drives right/left hand targets from weapon markers, manages TwoBoneIK3D
5. `RightArmIK` (TwoBoneIK3D) — right arm reaches RGRIP
6. `LeftArmIK` (TwoBoneIK3D) — left arm reaches LGRIP
7. `HeadLook` (LookAtModifier3D) — head aims at AimIKTarget

## Key Systems

### WeaponPositionController
- **Chest offset** (L74-76): `desired_global.basis = spine_corrected.basis * offset.basis`
- **No independent weapon pitch** — weapon rotation is purely `spine_corrected.basis * offset.basis`
- The weapon follows the chest rigidly. No independent rotation means no hand clipping.
- Exports: `offset_cache_path`, `character_controller_path`, `aim_controller_path`, `chest_bone_name`, `gun_bone_name`

### SpineController
- **Bone configs** (3 bones, no pelvis): `spine_01` pitch ±40°, `spine_02` ±30°, `neck` ±25°. Distribution 55/30/15.
- **`INFLUENCE_AIMING = 0.9`**: Spine bends 90% toward camera pitch when aiming.
- Pelvis was explicitly **rejected** for spine IK: `pelvis` is the parent of `thigh_l/r` in the skeleton hierarchy, so rotating pelvis rotates the legs. All bend shifted to `spine_01`.
- At 80° camera pitch: spine_01 = 39.6° (limit 40° ✓), spine_02 = 21.6° (limit 30° ✓), neck = 10.8° (limit 25° ✓) = 72° total. 8° gap remains between weapon and camera at extremes.
- Per-bone pitch limits were raised from 25° to accommodate the full influence range without clamping.

### FullBodyIKController
- Reads weapon grip markers (RGRIP/LGRIP) via signal `equipped_visual_attached` at equip time
- Caches marker **local transforms** relative to weapon root (no per-frame marker read)
- Computes hand target transforms from bone pose + cached local offset (zero-frame lag)
- Drives `RightArmIK` and `LeftArmIK` TwoBoneIK3D modifiers
- Target nodes: `AimIKTarget`, `RightHandIKTarget`, `LeftHandIKTarget` (Node3D children of Armature)

### Weight Visual Attachment
- `BoneAttachment3D` on `ik_hand_gun` (defined in `DefaultPlayerAttachmentLayout.tres:22`)
- One-frame lag between bone pose and weapon scene transform

## Key Exports
| Modifier | Export | Default | Purpose |
|----------|--------|---------|---------|
| FullBodyIKController | `weight_blend_speed` | `8.0` | IK weight smoothing |
| FullBodyIKController | `use_right_grip_snap` | `true` | Snap right hand to exact grip |
| FullBodyIKController | `use_left_grip_snap` | `true` | Snap left hand to exact grip |

## Required Bones
- `spine_02` — chest anchor for weapon offset
- `spine_01` — primary spine bend bone
- `ik_hand_root` — sibling of `pelvis` at skeleton root (NOT child of spine chain)
- `ik_hand_gun` — child of `ik_hand_root`; only written by `AnimationTree` at runtime
- `arm_r` — right shoulder (IK root + distance diagnostic)
- `arm_l` — left shoulder (IK root)
- `clavicle_r`, `forearm_r`, `hand_r` — right arm IK chain
- `clavicle_l`, `forearm_l`, `hand_l` — left arm IK chain

## Diagnostics (F6)
- `WeaponPositionController` prints `[ShoulderDelta] arm_r` — shoulder displacement from anim pose
- `WeaponPositionController` prints `[ShoulderDist] arm_r→gun / arm_r→RGRIP` — validates chest offset invariance
- `FullBodyIKController` prints `[PivotDiag] arm_r→gun` — validates chest offset invariance
- `FullBodyIKController` prints `[RHS] / [LHS]` — grip offset from weapon bone

## Removed / Superseded
- `LeftHandIKComponent.gd` — replaced by TwoBoneIK3D + FullBodyIKController
- `LeftHandModifier3D.gd` — replaced by TwoBoneIK3D
- `LeftHandIKDebugGizmo3D.gd` — obsoleted by F6 diagnostics
- `HandleGripPreview.gd` — obsoleted by scene marker approach
- `buttstock_local_offset` per-gun export — replaced by shoulder-pivot rotation (later itself removed)
- **`vertical_aim_influence`** — removed (no independent weapon pitch)
- **`shoulder_pivot_offset`** — removed (no rotation pivot needed)
- **`_compute_spine_pitch_delta()`** — removed (no weapon pitch to compute)
- **Pelvis from spine IK** — removed (rotated legs with torso)
- `[PitchPivot]`, `[SpineCoup]`, `[PrePitch]`, `[PostPitch]` F6 diagnostics — removed
