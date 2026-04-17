---
type: system
status: active
owned_by: gameplay
updated: 2026-04-16
---

# 15 - Aiming and Weapon States

## Summary
Weapon stance is now driven from authoritative inventory state instead of ad-hoc visual checks.

`CharacterController` resolves the main-hand occupant through `InventoryComponent`. If that item exists and its `ItemDefinition.category` is `weapon`, the player is considered armed. If aim input is held at the same time, the player enters the aiming state.

## Ownership
- `InventoryComponent` remains source of truth for what item occupies `right_hand`
- `CharacterController` consumes that state to pick locomotion speed and animation state
- `AnimationTree` stays a presentation layer driven through `parameters/playback`
- `VisualsComponent` still only reflects inventory state and does not decide weapon stance

## Runtime Rules
1. `InventoryComponent.get_main_hand_item()` resolves current main-hand item.
2. `CharacterController` checks that item definition category against `ItemDefinition.CATEGORY_WEAPON`.
3. If no weapon is in main hand, animation state is `Unarmed`.
4. If a weapon is in main hand, animation state is `Armed`.
5. If a weapon is in main hand and aim input is active, animation state is `Aiming`.

## Movement and Rotation
- Aiming applies `aim_speed_multiplier` to movement speed.
- Sprint is suppressed while actively aiming so state and locomotion remain consistent.
- In third-person, aiming rotates the character toward camera yaw instead of travel direction. This preserves left/right strafe behavior for aiming blendspaces.

## First-Person Visibility Rule
- gameplay first-person mode hides the player head on the runtime rig to prevent face clipping into the camera
- inventory mode and third-person restore full head visibility

## AnimationTree Contract
The player rig now expects these state-machine nodes:
- `Unarmed`
- `Armed`
- `Aiming`

Each state owns its own `BlendSpace2D`. Controller code writes the same locomotion blend position to all three states, then calls `travel()` on `parameters/playback` to choose the active state.

This avoids hidden dependence on a single legacy `Locomotion` path and keeps state ownership explicit.

## Input Contract
Project input map includes:
- `aim` mapped to right mouse button

If aim is held without a weapon in main hand, the system degrades gracefully by staying in `Unarmed`.

## Character Tuner Support
`CharacterTuner` now mirrors the same state-machine contract:
- locomotion preview updates `Unarmed`, `Armed`, and `Aiming` blendspaces
- `Aim Preview` forces `Aiming` only when a preview weapon is present in either hand
- without a preview weapon, tuner falls back to `Unarmed`

## Validation
Smoke coverage now verifies:
- default player boot reaches `Unarmed`
- right-hand weapon switches playback to `Armed`
- aim input plus right-hand weapon switches playback to `Aiming`

Recommended manual pass:
1. Boot `res://World/testing_world.tscn`
2. Pick up `TestWeaponItem`
3. Confirm idle enters armed pose
4. Hold right mouse button
5. Confirm aiming pose and slower movement
6. In third-person, confirm sideways movement uses strafe aiming animation instead of rotating into a forward walk
