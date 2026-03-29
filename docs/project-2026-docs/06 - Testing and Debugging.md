---
type: workflow
status: active
owned_by: gameplay
updated: 2026-03-28
---

# 06 - Testing and Debugging

## Summary
The current project includes a smoke-style test runner plus runtime debug UI. This is enough for validating dependency wiring, basic interaction flows, and inventory-driven weight updates while the systems are still early.

## Smoke Test Entry
Script: `Tests/Smoke/dependency_smoke_runner.gd`

Current smoke coverage includes:
- player scene boot
- world scene boot
- world interaction pickup flow
- inventory-domain behavior
- visual attachment behavior
- hand-held pickup and swap behavior if the smoke runner is expanded accordingly

## What The Smoke Tests Are Good For
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

## Recommended Validation Flow After System Changes
1. Reload the project
2. Check for parser or warning-as-error issues
3. Boot the player scene
4. Boot the test world
5. Validate focus prompt, pickup, slot placement, weight changes, and mounted visuals
6. Validate tap `F` versus hold `F`
7. Validate hand swap and fallback storage behavior

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
- item is visible but misplaced: attachment profile resource first, then `VisualsComponent`

## Current Testing Gaps Worth Filling Later
- explicit tests for more slot types
- explicit tests for container rejection rules
- tests for additional visible attachment anchors
- tests for action list generation per item family
