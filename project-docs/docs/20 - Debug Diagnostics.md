---
type: reference
status: active
owned_by: gameplay
updated: 2026-06-25
---

# 20 - Debug Diagnostics

## Summary
Runtime debug tools for diagnosing IK, weapon alignment, spine tracking, and state issues. All toggles are input-action-bound (no hardcoded keys).

## Keybind Reference

| Group | Action | Key | Handler | What it does |
|---|---|---|---|---|
| **IK** | `debug_ik_reach` | `J` | `FullBodyIKController` | Prints hand bone chain positions, RGRIP→target distances, arm reach margin to console. |
| **IK** | `debug_weapon_pose` | `K` | `WeaponPositionController` | Prints full weapon pose pipeline: shoulder delta, spine correction, fixed offset, spine→weapon forward dot product, desired vs actual bone pose. |
| **IK** | `debug_sight_screen` | `L` | `WeaponPositionController` | Spine pitch tracking: prints bone orientations (spine_01/02, neck, weapon), camera-bone pitch deltas, and alignment dot products. Header output says `SPINE TRACK DIAGNOSTIC (F7)`. |
| **IK** | `debug_sight_detail` | `I` | `WeaponPositionController` | Prints SIGHT_BACK + SIGHT_FRONT world positions, `sight_dir`, `camera_forward`, `angle_deg = acos(sight·cam)`, screen-space projections, and screen offset from viewport center. |
| **Weapon** | `debug_spine_track` | `P` | `SpineLookAtController` | Prints CCDIK context (pitch, yaw, influence, target pos), pre-CCDIK spine bone eulers, CCDIK node diagnostics, and tip→target distance. |
| **Other** | `debug_ik` | `F4` | `CharacterController` | Toggles `DebugIKVisualizer` node — 3D gizmos showing IK chain bones and targets in the viewport. |
| **Other** | `toggle_mesh_visibility` | `F2` | `CharacterController` → `VisualsComponent` | Toggles x-ray mode: hides character body MeshInstance3D children while keeping weapons visible. |
| **Other** | `toggle_camera` | `F3` | `CameraController` | Switches between first-person and third-person camera mode. |
| **Other** | `toggle_debug` | `F5` | `CameraController` + `UIRoot` | Toggles debug free-camera (fly mode with WASD, independent of character). While active, pressing aim (RMB) toggles ADS debug forcing `is_aiming` on/off. Also toggles `debug_layer` UI visibility. |

## Scope of Each Diagnostic

### IK — `debug_ik_reach` (J, `FullBodyIKController`)
- **RGRIP** world position, **RHandTarget** position, **RHandBone** world position
- `RGRIP→Target` and `RHandBone→Target` distances
- Arm reach chain length vs actual distance — `margin_cm` (negative = overstretch)
- Chain bone world positions: clavicle → arm_r → forearm → hand_r

### IK — `debug_weapon_pose` (K, `WeaponPositionController`)
- **ShoulderDelta**: arm_r bone displacement from animation pose after spine modifiers
- **ShoulderDist**: arm_r→gun and arm_r→RGRIP distances
- **SpineCorrected** eulers, **SpineDelta** (corrected vs anim), **FixedOffset** with capture timer
- **SpineTrack**: spine forward vs weapon forward dot product
- **Desired** vs **BonePose** vs **MarkerPose** with position/basis deltas

### IK — `debug_sight_screen` (L, `WeaponPositionController`)
- `[CamPitch]` — camera pitch angle
- `[Spine01]`, `[Spine02]`, `[Neck]` — each bone's world forward + pitch
- `[Weapon]` — weapon world forward + pitch
- `[Spine02·Camera]`, `[Weapon·Camera]` — alignment dot products and degrees from camera
- `[ΔSpine01]`, `[ΔSpine02]`, `[ΔNeck]`, `[ΔWeapon]` — pitch deltas between camera and each bone/weapon
- `[CamMode]` — FPS or TPS
- `[Cam→WeaponDist]` — distance from camera to weapon origin
- `[FixedOffset]` — current capture state of the weapon offset

### IK — `debug_sight_detail` (I, `WeaponPositionController`)
- `[State]` — current weapon anim state (ARMED / AIMING / etc.)
- `[SIGHT_BACK]` world position + screen coords
- `[SIGHT_FRONT]` world position + screen coords
- `[sight_dir]` = `(SIGHT_FRONT - SIGHT_BACK).normalized()`
- `[camera_forward]` = active camera -Z basis vector
- `[angle_deg]` = `acos(sight_dir · camera_forward)` — direct sight-to-camera alignment
- `[screen_offset]` pixel offset from viewport center for both sights
- `[spine_02]` + `[CamPitch]` for reference
- **Roll Decomposition** — world-space YXZ euler angles for: `spine_02 anim`, `spine_02 corrected`, `fixed_offset` (local), `desired gun`, `actual gun`, `camera`
- `[ΔRoll]` — desired gun vs camera roll delta, spine02 vs camera roll delta

### Weapon — `debug_spine_track` (P, `SpineLookAtController`)
- CCDIK context: camera pitch/yaw, influence, target position
- Pre-CCDIK spine_01 and spine_02 quaternion + euler angles
- CCDIK node diagnostics: influence, active, process_mode
- Tip (spine_02) → target world distance

### Other — `debug_ik` (F4, `CharacterController`)
- Spawns `DebugIKVisualizer` as a child — 3D scene gizmos showing IK target positions and bone chain lines.
- Press F4 again to destroy the visualizer.

### Other — `toggle_debug` (F5, `CameraController` + `UIRoot`)
- **CameraController**: Detaches camera from character, enables WASD fly movement.
  - While in free-cam, RMB (aim) toggles `is_aiming` without weapon interaction — useful to isolate ADS alignment from input state machines.
- **UIRoot** (separate handler): Toggles `debug_layer` visibility (DebugStatsUI, DebugInventoryInspector).
  - Only active when `UIRoot.debug_enabled` is true.

## Adding a New Debug Action

1. Add the action entry in `project.godot` under `[input]` with desired key.
2. Handle it with `event.is_action_pressed("your_action")` in the relevant script's `_input()`.
3. Document it here.
