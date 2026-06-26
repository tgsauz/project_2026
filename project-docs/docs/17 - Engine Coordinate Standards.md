# 17 - Engine Coordinate Standards & IK Alignment

## Core Architecture Decision: The Godot Standard (-Z Forward)

As of the Weapon Stance and IK Refactor, **Project 2026 strictly adheres to the Godot Engine standard coordinate system**. 
Any deviation from this convention breaks AI-assisted development, core engine helpers (`Basis.looking_at`, `Camera3D` defaults), and procedural IK math.

- **Forward**: `-Z` (Vector3.FORWARD)
- **Right**: `+X` (Vector3.RIGHT)
- **Up**: `+Y` (Vector3.UP)

### Character Controller & Input
The `CharacterController` input mappings are strictly mapped to standard directions. 
When a player presses "Forward" (W), the input vector maps to a negative Y value, translating to a `-Z` intent vector.
The character mathematically moves towards `-Z`.

### Visual Models & Rigs
Because the character logic moves towards `-Z`, the 3D model (the `Rig` or `Visuals` node) **must** face `-Z` in its resting state.
- **Character Rigs:** If importing a model facing +Z (common in Z-up software), rotate the root `Rig` node exactly **180° on the Y-axis** inside `mastercharacter.tscn`.
- **Weapon Meshes:** Every weapon mesh **must** be rotated in its weapon scene so the muzzle faces `-Z`. Do not rotate the weapon root; select the MeshInstance and rotate it 180° on the Y-axis.
- **Do not** write hacky math to flip vectors in the code. Let the code be standard, fix the visual nodes in the editor.

---

## IK Aiming and Weapon Alignment

**Important current-state note (2026-04-30):**
The live ADS implementation does **not yet** rotate the weapon with `Basis.looking_at()`.
Current runtime behavior is:
- ADS camera is displaced toward the weapon `SIGHT` marker
- right-hand pose remains mostly animation-driven
- right-hand rotation micro-corrector is still pending

Because of that, a weapon can show the `SIGHT` near screen center while the actual barrel / muzzle axis is still misaligned. Treat the math below as the **target architecture** for the planned ADS corrector, not the exact behavior of the current shipped code.

When the planned ADS corrector is implemented, the Right Hand IK system will use `Basis.looking_at()` to point the weapon exactly where the camera looks. Godot's `looking_at` aligns the `-Z` axis to the target. Thus, the final aiming system mathematically points the weapon's "Forward" (-Z) at the crosshair.

To accommodate different weapon models, the IK system uses a hierarchy of alignment:

### 1. Sight Markers (Preferred)
Use two `Node3D` or `Marker3D` nodes as children of the weapon root:
- **`SIGHT_BACK`** — rear sight notch / rear aperture position
- **`SIGHT_FRONT`** — front post position

The ADS system uses the line from `SIGHT_BACK` to `SIGHT_FRONT` as the visual sight line.
- `SIGHT_BACK` is the eye-side anchor for ADS positioning
- `SIGHT_BACK → SIGHT_FRONT` defines where the irons should point
- **Benefit**: visual ADS alignment no longer depends on guessing from a single point

### 1b. The "MUZZLE" Node (Recommended)
Add a `Node3D` or `Marker3D` named exactly **`MUZZLE`** at the barrel exit.
- The ADS corrector can use `SIGHT → MUZZLE` as the live bore-axis reference.
- This gives debug tooling and firing code an explicit barrel endpoint instead of inferring it from mesh orientation.
- If `MUZZLE` is missing, the system must fall back to the sight-line or grip-based vectors.

### 2. The Root -Z Fallback (Standard)
If no `SIGHT` node is found, the system **assumes the weapon's root `-Z` axis is the barrel**.

### Debugging IK Offsets
If your character's arms are twisting across their body or pointing at the sky, verify:
1. Is the `shoulder_hand_offset` respecting the standard? (e.g., `+X` should push the right arm to the right side of the body).
2. Is the character's `Rig` node rotated to face `-Z`? (If they face `+Z`, their "Right" is technically `-X`, which will cause the IK solver to break its own spine trying to reach a target on the wrong side of the body).

### Legacy Asset Migration (Fixing "Backwards" Weapons)
If you have weapons that were configured before the `-Z` standard was enforced, they may appear 180 degrees rotated in the character's hands. To fix them, do ONE of the following:
1. **The Fast Way**: Add a `Marker3D` named exactly `SIGHT` to the tip of the barrel.
2. **The Clean Way**: Open the weapon scene, select the root visual mesh, and rotate it 180° around the Y-axis so the barrel points towards `-Z`.

---

## Math & Procedural Rotation (atan2)

When converting a 3D movement vector into a Y-axis rotation (Yaw), GDScript's `atan2(x, z)` function treats the **+Z axis** as the zero-angle direction (`0` radians).

Since Project 2026 uses the Godot Standard (-Z Forward), the character faces **-Z** at `0` radians. If you use the standard `atan2(x, z)` formula, your character will look exactly 180 degrees away from their movement direction (the "Moonwalk" bug).

**The Correct Formula**:
To correctly calculate yaw for a node that faces `-Z` at `0` radians, invert both inputs:
```gdscript
target_yaw = atan2(-intent_direction.x, -intent_direction.z)
```
- Moving Forward (`-Z`) returns `0` radians.
- Moving Right (`+X`) returns `-PI/2` (-90°), which correctly points `-Z` towards `+X`.
