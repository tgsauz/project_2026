# Antigravity Weapon System — Diagnostic Context

> **Scope:** Read-only diagnostic reference. Use this to analyze weapon, aiming, and IK code
> for bugs, convention violations, and architectural issues. Do NOT implement fixes from this file.
> 
> **Engine:** Godot 4.6.1 | **Language:** GDScript | **Branch:** `weapon_system`
> **Last updated:** 2026-07-22

---

## 1. Coordinate System (Canonical)

**Strictly enforced — see `project-docs/docs/17 - Engine Coordinate Standards.md`.**

| Direction | Axis | Constant |
|-----------|------|----------|
| Forward | `-Z` | `Vector3.FORWARD` = `(0, 0, -1)` |
| Right | `+X` | `Vector3.RIGHT` = `(1, 0, 0)` |
| Up | `+Y` | `Vector3.UP` = `(0, 1, 0)` |

**Yaw formula (correct for -Z forward):**
```gdscript
target_yaw = atan2(-intent_direction.x, -intent_direction.z)
```
- `CharacterController.gd:272`

**Camera forward extraction (everywhere):**
```gdscript
var camera_forward := -aim_pivot.global_transform.basis.z.normalized()
```
- `AimController.gd:97`, `SpineLookAtController.gd:208`, `WeaponPositionController.gd:224,314,553,654`

---

## 2. Model Orientation Conventions

### Character Model
- `mastercharacter.glb` imported with **no axis conversion override** (default Godot import settings)
- `CharacterRig.tscn` — the `Rig` root node has **no Y-rotation applied** in the scene file
- Per Doc 17: if model faces +Z in DCC, rotate `Rig` node 180° on Y inside `CharacterRig.tscn`
- **Current state:** model is assumed to face `-Z` natively (no override needed)

### Weapon Models
- `M4RIFLE.glb` — uncommitted changes on `weapon_system` branch fix forward orientation to `-Z`
- Marker positions (current uncommitted state): MUZZLE at Z≈0.746, SIGHT_FRONT at Z≈0.497, SIGHT_BACK at Z≈0
- `weaponSceneEquipped.tscn:10-16` — markers are children of M4RIFLE with rotation transforms compensating for GLB orientation
- Per Doc 17: weapon mesh must have muzzle facing `-Z`; if not, rotate MeshInstance 180° on Y (NOT the root)

### Attachment Point Rotation Offsets
From `DefaultPlayerAttachmentLayout.tres`:
| Slot | Bone | Local Rotation |
|------|------|----------------|
| `right_hand` | `ik_hand_gun` | `Vector3.ZERO` |
| `left_hand` | `hand_l` | `Vector3.ZERO` |
| `back_mount` | `spine_02` | `Vector3(0, PI, 0)` — 180° Y |
| `lower_back` | `spine_01` | `Vector3(0, PI, 0)` — 180° Y |

---

## 3. Bone Hierarchy & Naming

### Spine Chain
```
root → pelvis → spine_01 → spine_02 → neck → head
```

### Right Arm
```
clavicle_r → arm_r → forearm_r → hand_r
```

### Left Arm
```
clavicle_l → arm_l → forearm_l → hand_l
```

### Weapon Bone
```
ik_hand_root → ik_hand_gun
```
- `ik_hand_root` is a **sibling of `pelvis`** at the skeleton root (NOT a child of the spine chain).
- `ik_hand_gun` is a child of `ik_hand_root`.
- Spine rotation (`spine_01`, `spine_02`) **cannot propagate hierarchically** to `ik_hand_gun`.
- The only writer of `ik_hand_gun` at runtime is `AnimationTree` (AnimationNodeStateMachine).

### Legs (reference)
```
thigh_r → calf_r → foot_r → toe_r
thigh_l → calf_l → foot_l → toe_l
```

### Bone Index Caching
All bones are cached by `find_bone()` at init time:
- `FullBodyIKController.gd:159-170` — caches `ik_hand_gun`, `arm_r`, `arm_l`, `clavicle_r`, `forearm_r`, `hand_r`
- `WeaponLayerBase.gd:21` — caches `ik_hand_gun`
- `SpineLookAtController.gd` — caches `spine_01`, `spine_02`, `pelvis`, `ik_hand_gun`

---

## 4. Forward Extraction Convention

**Every code path extracts bone/world forward as `-basis.z`.** This is the single invariant.

| File | Line | Expression |
|------|------|------------|
| `WeaponController.gd` | 237 | `var fwd_bone: Vector3 = -bone_world_basis.z` |
| `WeaponController.gd` | 238 | `var fwd_weapon: Vector3 = -weapon_xform.basis.z` |
| `WeaponController.gd` | 303 | `var rest_fwd: Vector3 = -rest_pose.basis.z` |
| `WeaponController.gd` | 307 | `var global_fwd: Vector3 = -(skel.global_transform.basis * global_pose.basis).z` |
| `WeaponController.gd` | 315 | `visual_fwd = -visual.global_transform.basis.z` |
| `WeaponController.gd` | 333 | `prints("[Skel fwd] %s" % _v3(-skel_global_basis.z))` |
| `SpineLookAtController.gd` | 188 | `var spine_fwd: Vector3 = -spine_gpose.basis.z.normalized()` |
| `SpineLookAtController.gd` | 192 | `var gun_fwd: Vector3 = -gun_gpose.basis.z.normalized()` |
| `SpineLookAtController.gd` | 208 | `var cam_fwd: Vector3 = -cam.global_transform.basis.z.normalized()` |
| `SpineLookAtController.gd` | 267 | Default fallback: `Vector3(0.0, 0.0, -1.0)` |
| `AimController.gd` | 97 | `var camera_forward := -aim_pivot.global_transform.basis.z.normalized()` |
| `AimController.gd` | 168 | `state.aim_direction = (yaw_basis * pitch_basis * Vector3.FORWARD).normalized()` |

### WeaponLayerAim Basis Construction (`WeaponLayerAim.gd:42-62`)
```gdscript
var weapon_forward := flat_forward        # normalized -Z direction
var weapon_right := weapon_forward.cross(Vector3.UP).normalized()
var weapon_up := weapon_right.cross(weapon_forward).normalized()
var orientation := Basis(weapon_right, weapon_up, -weapon_forward)
```
The Basis columns are `(weapon_right, weapon_up, -weapon_forward)`, which maps:
- Column 0 (local X) = `weapon_right`
- Column 1 (local Y) = `weapon_up`
- Column 2 (local Z) = `-weapon_forward` (because Godot -Z = forward)

**If the weapon mesh does NOT face -Z, this Basis will point the weapon the wrong way.**

---

## 5. Weapon System Architecture

### WeaponLayerStack (Composable Transform Pipeline)
```
WeaponLayerStack.compose(state, delta):
    current = Transform3D.IDENTITY
    for layer in _layers (sorted by priority):
        current = layer.apply(current, state, delta)
    return current
```
- `WeaponLayerStack.gd:25-30`

### Active Layers (Priority Order)
| Priority | Layer | File | Role |
|----------|-------|------|------|
| 0 | `WeaponLayerBase` | `WeaponLayerBase.gd` | Reads `ik_hand_gun` bone global pose → world-space Transform3D |
| 5 | `WeaponLayerAim` | `WeaponLayerAim.gd` | Slerps bone orientation toward camera-directed orientation |
| 10 | `WeaponLayerADS` | `WeaponLayerADS.gd` | Applies per-weapon ADS pose offset (static + dynamic interpolation) |
| 20-40 | (reserved) | — | Recoil, sway, inertia, breath, bob |
| 90 | (reserved) | — | Constraint |

### WeaponController (Orchestrator)
- **NOT a SkeletonModifier3D** — runs in `_process(delta)` (presentation, not skeleton pipeline)
- `WeaponController.gd:75-105` — main loop
- Composes weapon transform via layer stack, assigns to `weapon_root.global_transform`
- Builds `GripTarget` from cached RGRIP/LGRIP markers, sends to `FullBodyIKController`

### WeaponRoot
- Independent `Node3D` child of `CharacterBody3D` (NOT under skeleton)
- Created by `CharacterRigAssembly.gd` (deferred)
- Weapon visual is reparented under `WeaponRoot` at equip time (`WeaponController.gd:153-175`)
- `visual.transform = Transform3D.IDENTITY` after reparent — WeaponRoot is sole position authority

### WeaponLayerBase Details (`WeaponLayerBase.gd:24-41`)
```gdscript
var bone_global: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
var skel_rot: Quaternion = _skeleton.global_transform.basis.get_rotation_quaternion()
var bone_rot: Quaternion = bone_global.basis.get_rotation_quaternion()
var combined_basis := Basis(skel_rot * bone_rot)  # rotation-only (no scale)
var world_position: Vector3 = _skeleton.global_transform * bone_global.origin
return Transform3D(combined_basis, world_position)
```
- Position uses scaled skeleton transform (correct for world placement)
- Rotation discards scale (correct for downstream slerp)

### WeaponLayerAim Details (`WeaponLayerAim.gd:31-40`)
```gdscript
var bone_orientation: Basis = current.basis
var camera_orientation: Basis = _build_camera_orientation(state)
var final_orientation: Basis = bone_orientation.slerp(camera_orientation, weight)
return Transform3D(final_orientation, current.origin)  # position preserved
```
- `weight = state.aim_orientation_weight` (0 = holster, 1 = full aim)
- Early-out at `weight < 0.001`

### WeaponLayerADS Details (`WeaponLayerADS.gd:31-49`)
```gdscript
var target := Transform3D(current.basis * ads_rotation, ads_position)
return current.interpolate_with(target, weight)
```
- `ads_rotation` from `WeaponADSProfile.ads_pose.basis` (relative offset)
- Position: eye-relative rotation around pitch axis
- Uses `interpolate_with()` (not lerp) for correct Transform3D interpolation

---

## 6. Aim Data Flow (Frame Pipeline)

### Frame N Execution Order
```
1. INPUT (CharacterController._unhandled_input)
   └── is_aiming = true/false (right mouse button)

2. PHYSICS (CharacterController._physics_process)
   ├── _update_body_yaw()       — reads AimState.intended_yaw
   ├── _collect_input()         — WASD → intent_direction
   ├── _compute_motor()         — velocity, aim speed multiplier
   └── _update_animation()      — writes AnimationTree BlendSpace2D + travel()

3. PROCESS (per-frame pipeline)
   a. AimController._process(delta)
   │  ├── _update_aim_basis()           — aim_origin, aim_direction
   │  ├── _update_aim_orientation_weight — lerps 0→1
   │  ├── _update_ads_weight            — lerps 0→1
   │  ├── _update_fov                   — lerps toward target FOV
   │  ├── _build_aim_state()            — assembles AimState
   │  └── _push_state_to_camera()       — camera_controller.apply_aim_state(state)
   │
   b. WeaponController._process(delta)
   │  ├── Reads AimState from AimController
   │  ├── sync ADSBlendState from AimState
   │  ├── WeaponLayerStack.compose(state, delta)
   │  ├── weapon_root.global_transform = composed result
   │  └── _build_grip_target() → fullbody_ik.apply_grip_target(grip)
   │
   c. SkeletonModifier3D pipeline (automatic, tree order)
      ├── WeaponOffsetCache (output unused by active system)
      ├── CCDIK (spine look-at)
      ├── SpineLookAtController (positions LookAtTarget)
      ├── WeaponPositionController (DISABLED)
      ├── RightArmIK (TwoBoneIK3D)
      ├── LeftArmIK (TwoBoneIK3D)
      ├── HeadCCDIK (CCDIK3D)
      └── FullBodyIKController (orchestrates modifier weights)
```

### Key Invariant: Dual-Path Weapon Positioning
1. **Active path:** Layer stack → `WeaponRoot.global_transform` → visual reparented under WeaponRoot
2. **Disabled path:** `WeaponOffsetCache` → `WeaponPositionController` → bone pose override
   - Disabled via `_disabled = true; set_process(false)` since Step 8.5.4

### AimState (`AimState.gd`)
Immutable data struct, produced once per frame, consumed by 7+ systems:
```gdscript
var look_pitch: float         # camera pitch (radians)
var look_yaw: float           # camera yaw (radians)
var intended_yaw: float       # feed-forward for body yaw
var aim_origin: Vector3       # character eye position
var eye_position: Vector3     # same as aim_origin (for ADS pivot)
var aim_direction: Vector3    # normalized -Z-based direction vector
var aim_target_point: Vector3 # origin + direction * 1000
var ads_weight: float         # 0 = hip, 1 = full ADS
var aim_orientation_weight: float  # 0 = bone orientation, 1 = camera orientation
var fov_target: float         # target FOV
var camera_mode: bool         # true = FPS, false = TPS
var timestamp: int            # for networking
var sequence: int             # monotonically increasing
var is_valid: bool            # false if dependencies missing
```

### GripTarget (`GripTarget.gd`)
```gdscript
var right_hand_position: Vector3
var right_hand_rotation: Quaternion
var left_hand_position: Vector3
var left_hand_rotation: Quaternion
var is_valid: bool
```
- Produced by `WeaponController._build_grip_target()` from `weapon_xform * cached_rgrip_local`
- Consumed by `FullBodyIKController.apply_grip_target()` — never references WeaponRoot directly

---

## 7. IK Modifier Pipeline (Execution Order)

Skeleton3D children execute in tree order. `CharacterRigAssembly.gd` creates them in this exact sequence:

| # | Node | Type | Role |
|---|------|------|------|
| 1 | `WeaponOffsetCache` | SkeletonModifier3D | DISABLED (`process_mode = PROCESS_MODE_DISABLED`); captures offset but output unused by active pipeline |
| 2 | `CCDIK` | CCDIK3D | Spine look-at: `spine_01 → spine_02 → LookAtTarget` |
| 3 | `SpineLookAtController` | SkeletonModifier3D | Positions LookAtTarget + manages CCDIK iterations |
| 4 | `WeaponPositionController` | SkeletonModifier3D | **DISABLED** — legacy bone override |
| 5 | `RightArmIK` | TwoBoneIK3D | `arm_r → forearm_r → hand_r → RightHandIKTarget` |
| 6 | `LeftArmIK` | TwoBoneIK3D | `arm_l → forearm_l → hand_l → LeftHandIKTarget` |
| 7 | `HeadCCDIK` | CCDIK3D | `neck → head → AimIKTarget` |
| 8 | `FullBodyIKController` | SkeletonModifier3D | Orchestrates modifier weights based on stance |

### IK Target Nodes (in CharacterRig.tscn)
- `AimIKTarget`: position `(0, 1.3, 1.004)` — forward of character
- `RightHandIKTarget`: `Transform3D.IDENTITY`
- `LeftHandIKTarget`: `Transform3D.IDENTITY`
- `LookAtTarget`: Node3D with sphere mesh (positioned by SpineLookAtController)

---

## 8. IK Weight State Machine

### Weight Tables (`FullBodyIKController.gd:62-86`)
```gdscript
const IK_GRIP_WEIGHT: float = 1.0

const WEIGHTS_UNARMED = { "RightArmIK": 0.0, "LeftArmIK": 0.0, "HeadCCDIK": 0.0 }
const WEIGHTS_ARMED   = { "RightArmIK": 0.3, "LeftArmIK": 0.35, "HeadCCDIK": 0.25 }
const WEIGHTS_AIMING  = { "RightArmIK": 0.5, "LeftArmIK": 0.55, "HeadCCDIK": 0.35 }
```

### Weight Selection Logic (`FullBodyIKController.gd:278-298`)
```gdscript
if not has_main_hand_weapon():
    targets = WEIGHTS_UNARMED
elif is_effectively_aiming():
    targets = WEIGHTS_AIMING
    targets["HeadCCDIK"] = lerpf(0.35, 0.0, ads_weight)  # → 0 as ADS increases
else:
    targets = WEIGHTS_ARMED

# Grip IK decoupled from combat state — always 1.0 when weapon equipped
targets["RightArmIK"] = IK_GRIP_WEIGHT
targets["LeftArmIK"] = IK_GRIP_WEIGHT

# Zero out if no valid grip target
if not grip_target_valid:
    targets["RightArmIK"] = 0.0
    targets["LeftArmIK"] = 0.0
```

### Stance Detection
```gdscript
# CharacterController.gd:585-590
func _get_target_animation_state() -> String:
    if _is_effectively_aiming(): return "Aiming"
    if _has_main_hand_weapon(): return "Armed"
    return "Unarmed"

# CharacterController.gd:570-571
func is_effectively_aiming() -> bool:
    return is_aiming and not is_in_inventory and not quick_action_menu_open and has_main_hand_weapon()
```

---

## 9. Weapon Scene Conventions (Required Markers)

Every weapon equipped scene must have these Node3D markers:

| Marker | Purpose | Example Position (M4RIFLE) |
|--------|---------|---------------------------|
| `RGRIP` | Right-hand grip marker → IK target for `RightArmIK` | Per-weapon |
| `LGRIP` | Left-hand grip marker → IK target for `LeftArmIK` | Per-weapon |
| `SIGHT_BACK` | Rear sight anchor — eye-side ADS positioning | `(0, 0.202, ~0)` |
| `SIGHT_FRONT` | Front sight post — defines sight line with SIGHT_BACK | `(0, 0.206, 0.497)` |
| `MUZZLE` | Barrel exit — bore-axis diagnostics and firing | `(0, 0.124, 0.746)` |

### ADS Profile (`WeaponADSProfile.gd`)
```gdscript
@export var ads_pose: Transform3D = Transform3D.IDENTITY  # relative offset from base pose
@export var ads_fov: float = 55.0
@export var enter_speed: float = 8.0
@export var exit_speed: float = 10.0
```
- Composition: `T_final = T_base * ads_pose`, then `interpolate_with(target, weight)`
- Per-weapon design-time configuration; referenced by `ItemDefinition`

### Visual Attachment Flow
1. `VisualsComponent` creates `BoneAttachment3D` for slot `right_hand` → bone `ik_hand_gun`
2. Instantiates `equipped_visual_scene` (weaponSceneEquipped.tscn)
3. Applies `ItemVisualAttachmentProfile` offsets (position/rotation/scale)
4. Signals `equipped_visual_attached` → `WeaponController._on_visual_attached()`
5. WeaponController caches RGRIP/LGRIP local transforms
6. Reparents weapon visual under `WeaponRoot` with `transform = IDENTITY`

---

## 10. Debug Tools

### Runtime Debug Actions (Input Map)
| Action | Key | Script | Purpose |
|--------|-----|--------|---------|
| `debug_ik` | F4 | `CharacterController` | Toggle `DebugIKVisualizer` |
| `debug_weapon_authority` | M | `WeaponController` | Full weapon authority diagnostic: bone vs weapon vs visual euler, forward vectors, position deltas |
| `debug_bone_rest` | N | `WeaponController` | Bone rest pose vs global pose vs visual forward alignment |
| `debug_force_holster` | O | `WeaponController` | Toggle `aim_orientation_weight` forced to 0 |
| `debug_ik_reach` | J | `FullBodyIKController` | Arm chain positions, reach distances |
| `debug_weapon_pose` | K | `WeaponPositionController` | Full weapon pose pipeline (DISABLED system) |
| `debug_sight_detail` | I | `WeaponPositionController` | SIGHT_BACK + SIGHT_FRONT world positions, sight-to-camera angle |
| `debug_sight_screen` | L | `WeaponPositionController` | Screen-space sight alignment |
| `debug_free_cam` | F1 | `CameraController` | Detach camera, fly around |

### Key Diagnostic Methods
- `WeaponController._debug_print_weapon_authority(state, weapon_xform)` — `WeaponController.gd:~200`
- `WeaponController._debug_print_bone_rest()` — `WeaponController.gd:284-344`
- `FullBodyIKController.get_modifier_debug_info()` — returns weight states
- `FullBodyIKController.get_ik_target_positions()` — returns IK target world positions
- `VisualsComponent._print_bone_chain_diagnostics()` — walks `ik_hand_gun` parent chain

### What Each Diagnostic Prints
- **`debug_bone_rest` (N):** rest pose forward, global pose forward, visual forward, rest·visual dot product and angle
- **`debug_weapon_authority` (M):** bone vs weapon vs visual euler angles, forward vectors, position deltas, camera alignment, full transform chain
- **`debug_sight_detail` (I):** SIGHT_BACK/SIGHT_FRONT world positions, sight_dir, camera_forward, angle between them

---

## 11. Known Issues & Open Tasks

### From TODO.md (Still Open)
- `[ ]` Normalize legacy weapon / marker forward axes — all weapon assets, SIGHT, MUZZLE must use -Z consistently (line 60)
- `[ ]` Audit remaining scenes / imported assets that still behave like +Z forward (line 61)
- `[ ]` Phase 2A: Local rest-pose counter-rotation in `VisualsComponent._apply_visual_profile()` (line 66)
- `[ ]` Phase 2B (fallback): Spine-parent + dual IK if twist comes from parent chain (line 67)
- `[ ]` Phase 6 ADS: Step 8.75 re-test, Step 9a/9b (Disable/Delete Old Pipeline) (lines 90-91)
- `[x]` ADS layer registration — `set_ads_profile()` on AimController + `weapon_ads_profile` on ItemDefinition (Phase 1, 2026-07-22)

### From AI Agent Handbook (as of 2026-04-30)
- Weapon can phase through head in ADS — camera displacement + right-hand corrector balance
- Per-weapon marker authoring remains critical — incorrect markers produce visible cant/bore drift
- ADS target drifts from eye when animations play — FPSPIVOT is floating, not bone-attached
- Camera-to-head anchoring still pending

### Architecture Notes
- `WeaponPositionController` is DISABLED but kept for rollback
- `WeaponOffsetCache` still runs but its output is unused by the active system
- Grip markers (RGRIP, LGRIP) may be missing on some weapon scenes — fallback to `Transform3D.IDENTITY`

---

## 12. Diagnostic Checklist

### When Analyzing Weapon Code, Check:

**Forward Convention:**
- [ ] Does the weapon mesh face `-Z`? (rest_fwd dot Vector3.FORWARD should be > 0.9)
- [ ] Does `WeaponLayerAim._build_camera_orientation()` construct the Basis correctly?
- [ ] Is `aim_direction` always a normalized `-Z`-based vector?

**Bone Chain Integrity:**
- [ ] `ik_hand_gun` rest pose — does its -Z align with weapon forward?
- [ ] Spine chain: `spine_01 → spine_02` — no twist contamination from parent?
- [ ] Arm chain: `arm_r → forearm_r → hand_r` — reach distance within limits?

**IK Target Positions:**
- [ ] `RightHandIKTarget` position matches GripTarget right_hand_position?
- [ ] `LeftHandIKTarget` position matches GripTarget left_hand_position?
- [ ] `AimIKTarget` position is along `aim_direction` from skeleton origin?

**Weight State:**
- [ ] UNARMED → all IK weights 0.0?
- [ ] ARMED → partial weights (0.3/0.35/0.25)?
- [ ] AIMING → higher weights, HeadCCDIK lerping to 0 with ADS?
- [ ] Grip weights forced to 1.0 when weapon equipped (decoupled from stance)?

**Weapon Transform Pipeline:**
- [ ] `WeaponLayerStack` layers execute in priority order (0→5→10)?
- [ ] `WeaponRoot.global_transform` = composed result (not bone-attached)?
- [ ] Weapon visual reparented under WeaponRoot with `transform = IDENTITY`?

**Red Flags:**
- `rest_fwd · visual_fwd` dot product < 0.9 → GLB mesh forward misaligned
- `spine_fwd · weapon_fwd` dot product < 0.5 → weapon twisted across body
- IK target unreachable → chain too short or target displaced
- `aim_direction` not normalized → will cause incorrect Basis construction
- `ads_weight` stuck at 0 or 1 → ADS blend not interpolating

---

## 13. File Inventory

### Core Weapon Files
| File | Class | Lines | Role |
|------|-------|-------|------|
| `Player/Scripts/WeaponController.gd` | `WeaponController` | 354 | Orchestrator — layer stack, GripTarget, weapon_root authority |
| `Player/Scripts/WeaponLayer.gd` | `WeaponLayer` | — | Base class for composable transform layers (RefCounted) |
| `Player/Scripts/WeaponLayerBase.gd` | `WeaponLayerBase` | 41 | Priority 0 — reads ik_hand_gun bone global pose |
| `Player/Scripts/WeaponLayerAim.gd` | `WeaponLayerAim` | 62 | Priority 5 — slerps bone→camera orientation |
| `Player/Scripts/WeaponLayerADS.gd` | `WeaponLayerADS` | 49 | Priority 10 — applies per-weapon ADS pose offset |
| `Player/Scripts/WeaponLayerStack.gd` | `WeaponLayerStack` | 36 | Composes all layers in priority order |
| `Player/Scripts/WeaponOffsetCache.gd` | `WeaponOffsetCache` | 59 | SkeletonModifier3D — DISABLED (`process_mode = PROCESS_MODE_DISABLED`); captures offset but output unused by active pipeline |
| `Player/Scripts/WeaponPositionController.gd` | `WeaponPositionController` | — | **DISABLED** — legacy bone override, kept for rollback |
| `Player/Scripts/WeaponADSProfile.gd` | `WeaponADSProfile` | 29 | Resource — per-weapon ADS config |
| `Player/Scripts/WeaponActionController.gd` | `WeaponActionController` | — | Firing, hitreg, recoil |
| `Player/Scripts/GripTarget.gd` | `GripTarget` | 23 | RefCounted data — hand positions for IK |

### Aiming Files
| File | Class | Lines | Role |
|------|-------|-------|------|
| `Player/Scripts/AimController.gd` | `AimController` | 184 | Single source of truth for aim intent; `set_ads_profile()` for per-weapon ADS config |
| `Player/Scripts/AimState.gd` | `AimState` | 77 | Immutable data struct consumed by all downstream |
| `Player/Scripts/ADSBlendState.gd` | `ADSBlendState` | 41 | Shared presentation interpolation state |

### IK / Bone Manipulation Files
| File | Class | Lines | Role |
|------|-------|-------|------|
| `Player/Scripts/FullBodyIKController.gd` | `FullBodyIKController` | 463 | Manages modifier weights and grip targets |
| `Player/Scripts/SpineLookAtController.gd` | `SpineLookAtController` | 271 | Drives spine CCDIK toward aim direction |
| `Player/Scripts/DebugIKVisualizer.gd` | `DebugIKVisualizer` | — | Debug overlay — bones, IK targets, aim ray |

### Camera / Controller Files
| File | Class | Lines | Role |
|------|-------|-------|------|
| `Player/Scripts/CameraController.gd` | `CameraController` | 381 | FPS/TPS look, ADS FOV, head-bone anchoring |
| `Player/Scripts/CharacterController.gd` | `CharacterController` | 613 | Movement, input, animation state machine |
| `Player/Scripts/CharacterRigAssembly.gd` | `CharacterRigAssembly` | 114 | Runtime node factory — creates all IK/modifier nodes |
| `Player/Scripts/VisualsComponent.gd` | `VisualsComponent` | — | Equipped visuals, BoneAttachment3D, marker caching |

### Scene Files
| File | Role |
|------|------|
| `Player/PlayerCharacter.tscn` | Root player scene — CharacterBody3D |
| `Player/CharacterRig.tscn` | Rig — imported model + AnimationTree + IK targets |
| `World/Items/M4RIFLE/weaponSceneEquipped.tscn` | Equipped weapon — GLB + MUZZLE/SIGHT markers |
| `World/Items/M4RIFLE/weaponSceneWorld.tscn` | World weapon — simple mesh for pickup |

### Resource Files
| File | Role |
|------|------|
| `World/Items/TestWeaponItem.tres` | Prototype Rifle — category=weapon, 3 attachment profiles |
| `World/Items/Visuals/PrototypeRifleRightHandProfile.tres` | Right-hand held profile |
| `World/Items/Visuals/PrototypeRifleLeftHandProfile.tres` | Left-hand held profile |
| `World/Items/Visuals/PrototypeRifleLowerBackProfile.tres` | Lower-back mount (180° Y rotation) |
| `World/Items/Visuals/TestWeaponADSProfile.tres` | Phase 1 test ADS profile — ads_fov=55, enter=8, exit=10 |
| `World/Items/Config/DefaultPlayerAttachmentLayout.tres` | Slot→bone mapping + default offsets |

### Documentation
| File | Role |
|------|------|
| `project-docs/docs/15 - Aiming and Weapon States.md` | ADR: weapon stance rules, animation contract |
| `project-docs/docs/17 - Engine Coordinate Standards.md` | Canonical -Z forward standard |
| `project-docs/docs/19 - AI Agent Handbook.md` | AI agent context — architecture, rules, debug tools |
| `project-docs/docs/20 - Debug Diagnostics.md` | Debug action reference |
| `project-docs/docs/TODO.md` | Master task list with weapon-related open items |
