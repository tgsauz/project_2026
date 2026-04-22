---
type: workflow
status: active
owned_by: gameplay
updated: 2026-04-22
---

# 06 - Testing and Debugging

## Summary
The current project includes a smoke-style test runner plus runtime debug UI. This is enough for validating dependency wiring, basic interaction flows, and inventory-driven weight updates while the systems are still early.

## Smoke Test Entry
Script: `Tests/Smoke/dependency_smoke_runner.gd`

Current smoke coverage includes:
- shared slot catalog contract
- player scene boot
- world scene boot
- world interaction pickup flow
- weapon-driven animation-state transitions
- left-hand IK grip-target resolution for equipped weapons
- attachment-modifier flow
- inventory-domain behavior
- visual attachment behavior
- serialization / deserialization flow
- tuner recursive item discovery

## What The Smoke Tests Are Good For
- shared slot-truth regressions
- missing component dependencies
- broken scene wiring
- interaction regressions
- body-mounted visual regressions
- major inventory storage regressions

## What They Do Not Yet Cover Well
- exhaustive invalid item movement cases
- deep nested container behavior
- broad quick action edge cases
- serialization/save-load
- final animation/visual correctness

## Debug UI
Scripts and scenes:
- `Player/Debug/UIRoot.gd`
- `Player/Debug/Scripts/DebugStatsUI.gd`

Current debug outputs include:
- interaction prompt
- quick action menu
- speed
- velocity
- load factor
- total weight

## Left-Hand IK Diagnostics
Scripts:
- `Player/Scripts/LeftHandIKComponent.gd`
- `Player/Scripts/LeftHandModifier3D.gd`
- `Player/Scripts/LeftHandIKDebugGizmo3D.gd`

The left-hand IK system now supports a modular diagnostics workflow with:
- `debug_mode`: `off`, `basic`, `full`
- `debug_draw_gizmos`
- `debug_log_snapshots`
- `debug_compare_tag`
- `capture_debug_snapshot()`

### What The IK Diagnostics Show
- target-space resolution from `LGRIP` to the resolved target transform
- attachment-space transforms for weapon root, `Handle`, `LGRIP`, and the right-hand attachment root
- solver-stage data for shoulder, elbow, wrist, solved elbow, and final wrist
- wrist error distance/vector plus elbow solved-versus-actual delta
- optional runtime gizmos for the actual arm chain, target chain, solved elbow, and wrist error line

### Repeatable IK Debug Pass
Use this exact workflow when the left hand grips correctly in one pose and fails in another:
1. Set `LeftHandIK.debug_mode` to `basic`
2. Set `LeftHandIK.debug_log_snapshots` to `true`
3. Set `LeftHandIK.debug_draw_gizmos` to `true` when you need spatial confirmation
4. Capture one tagged snapshot during a known-good pose such as `idle`
5. Capture one tagged snapshot during the failing pose such as `strafe_d`
6. Compare:
   - `target_space`
   - `attachment_space`
   - `solver_stages`
   - `error_metrics`
7. Use the diff summary to decide which subsystem owns the bug before patching

### Live Handle Tuning Pass
Use this when the weapon grip point is wrong but you need immediate visual feedback:
1. Boot `res://World/testing_world.tscn`
2. Equip the weapon into `right_hand`
3. In the remote scene tree, find the equipped visual's `Handle`
4. Move or rotate the `Handle` and watch the weapon pose plus left-hand IK update live
5. If inspector Euler fields feel misleading, use the rotate gizmo in local mode and compare against the `HandleGripPreview` helper in the equipped scene
6. Save the equipped scene only after the grip point itself looks correct, then tune per-slot profile offsets if still needed

### Interpreting The Output
- **Target-space problem**: resolved target or virtual target jumps unexpectedly while the weapon and grip markers look stable
- **Attachment / Handle basis problem**: `Handle`, `LGRIP`, or attachment-root transforms diverge significantly between good and bad poses
- **Solver-stage problem**: resolved target stays stable, but wrist error grows and elbow solved-versus-actual delta grows
- **Offset / composition problem**: attachment transforms stay stable, but offset application or composition order causes the resolved target frame to drift

## Recommended Validation Flow After System Changes
1. Reload the project
2. Check for parser or warning-as-error issues
3. Boot the player scene
4. Boot the test world
5. Validate focus prompt, pickup, slot placement, weight changes, and mounted visuals
6. Validate tap `F` versus hold `F`
7. Validate hand swap and fallback storage behavior
8. Equip a weapon in `right_hand` and confirm `Armed` state engages
9. Confirm left-hand IK resolves a grip target on the equipped weapon
10. Hold aim and confirm `Aiming` state plus slower movement engages

## Recommended Manual Test Pass For Equipment Changes
Run this exact pass after touching inventory, interaction, or visuals:
1. Pick up a hand-capable item with empty right hand
2. Pick up another hand-capable item while right hand is occupied
3. Confirm the first item is stowed legally and the new one becomes visible in hand
4. Pick up an item that cannot go in hand and confirm normal inventory storage
5. Open quick actions by holding `F`
6. Open quick actions with `Q` and compare behavior
7. Move an item to hand from inventory actions
8. Stow it
9. Drop it
10. Re-pick it up and confirm visuals reconstruct cleanly

## Debugging Rules
- Prefer reproducing the issue before patching
- Distinguish parser failures from logic failures
- Treat hardcoded dependencies as likely first suspects
- Keep logging targeted and remove noisy temporary diagnostics

## Where To Look First For Equipment Bugs
- pickup went to wrong slot: `InventoryComponent`
- hold or tap input feels wrong: `CharacterController`
- prompt text is wrong: `WorldItem`, `MountedItemInteractable`, `UIRoot`
- item is in inventory but not visible: `get_equipped_visuals()` and `VisualsComponent`
- item is visible but misplaced: `Handle` in equipped scene first, attachment profile resource second, then `VisualsComponent`

## Current Testing Gaps Worth Filling Later
- explicit tests for container rejection rules
- tests for additional visible attachment anchors
- tests for action list generation per item family
- fuller end-to-end scenario loops such as pickup -> stow -> inspect -> serialize -> restore
