# Project 2026 - Master TODO Checklist

This document tracks the implementation status of all major gameplay systems and technical foundations.

## [x] Physical Inventory System (Phase 1-5)
- [x] ItemDefinition / ItemInstance architecture
- [x] Attachment-driven occupancy graph with nested container support
- [x] Weight and load factor calculation
- [x] World pickup with auto-stow logic
- [x] `ItemDefinitionRegistry` (static lookup)
- [x] Serialization (Save/Load Dictionary support)
- [x] Equipment-contributed attachment nodes (belt / vest)
- [x] Size-based container capacity rules

## [x] Diegetic Inventory UI
- [x] Independent Inventory Camera (Orbit View)
- [x] Attachment-node dots with selected connector line
- [x] Selected-item panel with principal item actions
- [x] Item Tooltips (Hover details)
- [x] 3D Item Inspection Viewport
- [ ] Category filtering (Hotkey 1-4)
- [x] Debug Inventory Inspector (Raw state table)

## [/] Movement & Interaction
- [x] Advanced Player Controller (Stamina, Acceleration)
- [x] Interaction System (Raycast, Prompt, Global Focus)
- [x] Crosshair UI (Dynamic states, Dot modes)
- [ ] Jump/Crouch integration with stamina
- [ ] Vaulting / Mantling system

## [ ] Survival Systems (Priority Next)
- [ ] Health, Wounds, and Pain state
- [ ] Medical Item usage (Treatment time & animations)
- [ ] Weapon firing and reload state (Ammunition tracking)
- [ ] Item condition and durability
- [ ] Maintenance & Repair flow

## [ ] World & Scavenging
- [ ] Searchable loot containers
- [ ] Locked doors and access gating
- [ ] Scavenging "Stations" (e.g., workbench, medical station)
- [ ] Persistence of world item drops across save/load

## [x] Tools & Utilities
- [x] Character Visuals Tuner (Phase 1-2)
    - [x] Standalone preview scene
    - [x] Orbit camera & Inspection controls
    - [x] Real-time transform sliders
    - [x] Locomotion & Clipping preview
    - [x] Runtime Resource Saving support

## [ ] Technical Debt & Refactoring
- [x] Move hardcoded slot definitions to Data-Driven Resources
- [x] Promote slot truth into shared attachment layout resources
- [ ] Implement Drag-and-Drop for accordion item movement
- [ ] Stack Split/Merge UI
- [x] Scenario-based Smoke Tests for complex loops
- [ ] Full Godot 4.6 Feature Audit (Rendering/Physics)
- [ ] Normalize legacy weapon / marker forward axes so authored weapon assets, `SIGHT`, and `MUZZLE` all use Godot `-Z` forward consistently
- [ ] Audit remaining scenes / imported assets that still behave like `+Z` forward and document migration steps


## [/] Weapon Orientation Fix
- [x] Phase 1: Bone chain diagnostic tool (F5 debug menu → "Print Bone Chain")
- [ ] Phase 2A: Local rest-pose counter-rotation in `VisualsComponent._apply_visual_profile()`
- [ ] Phase 2B (fallback): Spine-parent + dual IK if twist comes from parent chain
- [ ] Detection of `MUZZLE` markers on weapon scenes
- [x] Doc 18 deleted — superseded by `project-docs/plan/02 - IK SkeletonModifier3D Refactor.md` (current IK architecture)

## [x] Weapon Position Anchoring (Phase XI)
- [x] Two-modifier chain: WeaponOffsetCache captures `spine_02⁻¹ * ik_hand_gun` before spine correction
- [x] WeaponPositionController re-applies offset after spine correction + camera pitch when aiming
- [x] `FullBodyIKController.gd`: removed `vertical_aim_influence`, `_apply_weapon_pitch()`, `_get_camera_pitch()`
- [x] Scene modifier order: WeaponOffsetCache → SpineController → WeaponPositionController → FullBodyIKController
- [x] Smoke test passes (modifier order assertion green)
- [x] Pre-existing issues confirmed: 2 known failures (Backpack/Belt in CharacterTuner) — unaffected by IK changes
- [x] Bug fix v2: coordinate-space mismatch in `_set_gun_pose` (world-space × skeleton-local) caused weapon at wrong position — fixed with `parent_pose⁻¹ * desired_global` conversion
- [ ] **Open:** Pitch inversion — camera-up causes weapon+torso to pitch down. Sign convention or coordinate frame issue in `WeaponPositionController` camera pitch and/or `SpineController` pitch

## [x] Pitch Inversion (Fixed 2026-06-04)
- [x] Diagnosed: camera convention (+pitch=up) opposed bone rotation convention (+X=tilt down)
- [x] Fixed: `CAMERA_PITCH_TO_BONE_PITCH_SIGN = -1.0` in both SpineController and WeaponPositionController
- [x] Twist formula fixed: `atan2(x, -z)` replaces `-atan2(x, z)` (Godot -Z forward convention)
- [x] STANCE_BIAS zeroed: was contaminating weapon aim alignment (+5° constant twist, 4× amplified at aiming influence)
