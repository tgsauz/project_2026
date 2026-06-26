---
type: plan
status: active
owned_by: gameplay
updated: 2026-04-03
---

# 14 - UI + Inventory System Branch Refactor Plan

## Summary
This plan is the execution brief for the `feature/ui+inventory_system` branch. The branch is currently behind the newer shared slot-truth work and still carries older inventory UI wiring, hardcoded slot metadata, and docs that partially overstate current behavior.

The goal of this pass is to standardize the inventory and inventory-adjacent UI architecture so it matches the project's documented ownership rules while improving styling consistency, modularity, robustness, scalability, and efficiency.

This pass intentionally does **not** include the larger UI layout redesign. Layout redesign should happen after the architecture and styling foundations are stabilized, so we do not redesign on top of weak contracts.

## Current Branch Gaps
Current issues to resolve on this branch:
- root slot definitions are still hardcoded in `InventoryComponent`
- visual attachment anchors are still hardcoded in `VisualsComponent`
- `CharacterTuner` still owns a separate slot list and only scans top-level item resources
- runtime inventory UI is still heavily created and wired from `UIRoot`
- some inventory UI paths still rely on scene-tree lookup instead of explicit references
- docs still describe category filtering as complete, but the runtime flow is not aligned enough to treat it as done
- smoke coverage still focuses on dependency checks and does not cover the newer architecture expectations

## Primary Objectives
This branch should end with:
- one shared source of truth for gameplay equipment slots and visual anchors
- inventory, visuals, testing scene, and tuner all consuming the same slot definitions
- runtime inventory UI using cleaner boundaries and less scene-tree guesswork
- styling paths normalized so dynamically-created inventory UI matches the documented style system
- docs updated to reflect the real architecture on this branch after the refactor
- stronger smoke coverage for the inventory loop and shared slot-truth behavior

## Architecture Direction
### Why architecture should change here
This branch already shows drift between inventory, visuals, tuner, docs, and the testing scene. That drift will grow every time a slot or anchor changes unless slot metadata becomes shared. The right fix is to centralize repeated slot knowledge into a shared data layer and make UI components consume explicit dependencies instead of discovering them ad hoc.

These are targeted architecture changes, not a rewrite:
- inventory remains the authority for storage truth
- visuals remain a consumer of equipped visual payloads
- tuner remains an authoring tool
- UI remains a view/controller layer
- shared slot metadata becomes a data contract, not a new gameplay authority

## Implementation Phases
### Phase 1: Shared Slot Truth
Add a shared resource-based slot catalog and make it the authoritative source for gameplay equipment slots and visual attachment metadata.

Required additions:
- `EquipmentSlotDefinition` resource
- `EquipmentSlotCatalog` resource
- `EquipmentSlotLibrary` or equivalent shared loader/helper
- one default catalog resource under a shared gameplay path

Catalog fields:
- `slot_name`
- `display_name`
- `accepted_categories`
- `visible`
- `anchor_bone_name`
- `anchor_local_position`
- `anchor_local_rotation`
- `debug_color`
- `is_hand_slot`
- `tuner_enabled`

Default gameplay slots to preserve:
- `left_hand`
- `right_hand`
- `torso`
- `lower_back`
- `belt`
- `left_pocket`
- `right_pocket`
- `back_mount`
- `shoulder_mount`

Rules:
- keep current slot string ids unchanged
- do not include `head` unless it becomes a real gameplay slot across the stack
- keep `gun_support` outside the gameplay slot catalog as a visuals-only helper anchor
- keep the catalog helper read-only and cached

### Phase 2: Migrate Inventory, Visuals, and Scene Configuration
Move existing systems to consume the shared slot catalog with minimal behavior change.

Inventory work:
- replace hardcoded `_build_slot_configs()` behavior with catalog-driven slot config generation
- default `slot_names` to the shared catalog order
- preserve storage rules, pickup flow, auto-stow, visibility queries, and serialization shape
- add startup warnings when a scene overrides `slot_names` with unknown slot ids

Visuals work:
- replace hardcoded `_ensure_attachment_roots()` slot setup with catalog iteration
- use catalog-provided anchor bone names and transforms
- use catalog `debug_color` where available
- keep skinned visual behavior unchanged
- keep `gun_support` as a non-catalog visuals helper anchor

Testing scene work:
- align `World/testing_world.tscn` slot override with the shared catalog or an explicit documented subset
- remove silent slot drift between the testing scene and the rest of the stack

Compatibility work:
- keep `ItemDefinition.allowed_slots`, `preferred_slot`, and profile slot binding string-based for this phase
- validate item slot references against the shared catalog and warn on invalid slot names

### Phase 3: Runtime Inventory UI Standardization
Refactor the inventory UI architecture to be more modular and less coupled while preserving the current interaction model.

Required improvements:
- reduce scene-tree lookups for inventory UI components
- pass inventory/controller dependencies explicitly into overlay, slot panel, action menu, tooltip, and inspect views
- normalize the item payload shape shared between slot panel, action menu, and tooltip
- keep `UIRoot` as coordinator, but reduce its knowledge of low-level item formatting
- preserve current inventory mode toggle flow and inventory camera behavior

Recommended structure:
- `UIRoot` creates and binds inventory UI components once
- components expose focused setup methods like `set_inventory_component(...)`, `set_character(...)`, or `configure(...)`
- tooltip and action menu should not discover inventory by walking the scene tree
- slot panel should work from a normalized UI item payload instead of rebuilding multiple shapes ad hoc

### Phase 4: Styling Hardening
Bring inventory-related UI fully in line with the documented `UIStyleProfile` system.

Required work:
- audit all runtime-created inventory UI controls for style coverage
- ensure buttons, labels, panels, hover states, tooltips, debug widgets, and dynamic containers are styled from `UIStyleProfile`
- remove hidden assumptions that only editor-authored controls receive correct styling
- keep styling APIs local to each component through `apply_style(style: UIStyleProfile)`

Goals:
- styling should remain consistent whether the UI node is scene-authored or created at runtime
- styling should not depend on branch-specific editor overrides
- later layout redesign should be able to reuse the same style foundation without reworking control visuals

### Phase 5: CharacterTuner Standardization
Bring the tuner up to the same shared slot-truth standard so it does not drift again.

Required work:
- replace hardcoded slot list with catalog-driven slot list filtered by `tuner_enabled`
- replace top-level-only item scan with recursive item discovery
- preserve current save ownership inside the tuner controller
- keep tuner UI aligned with the runtime style system

Recommended additions if practical in this pass:
- `Rescan` action
- clearer profile state messaging
- anchor debug toggle tied to `VisualsComponent.show_attachment_debug_gizmos`

### Phase 6: Smoke and Scenario Coverage
Expand tests beyond dependency boot checks so the branch has regression protection around the architecture changes.

Add coverage for:
- default slot catalog loading
- uniqueness of slot ids
- presence of baseline gameplay slots
- inventory initialization from the shared catalog
- visuals creating anchors from the shared catalog
- invalid item slot names warning rather than failing silently
- tuner slot list matching the shared slot catalog subset
- recursive item discovery for tuner data
- pickup, auto-stow, mounted visual, and drop flow still working in the test world
- inventory serialization continuing to work with unchanged slot ids

Test structure:
- keep `dependency_smoke_runner.gd`
- add scenario-style checks there or split into a second runner if clarity suffers
- prefer deterministic scene-based coverage over deep mocking

### Phase 7: Documentation Alignment
After code changes land, update docs so the branch architecture matches the code again.

Docs to update:
- `01 - Architecture Overview.md`
- `02 - Game Systems Overview.md`
- `03 - Inventory and Item System.md`
- `05 - Player, Visuals, and Attachment Points.md`
- `06 - Testing and Debugging.md`
- `12 - How To Modify UI.md`
- `13 - Character Visuals Tuner Guide.md`
- `TODO.md`

Required TODO corrections:
- mark `Move hardcoded slot definitions to Data-Driven Resources` complete once delivered
- revisit `Category filtering (Hotkey 1-4)` and either implement it to match docs or mark it incomplete again
- mark scenario smoke work based on what is actually delivered in this branch

## Acceptance Criteria
This pass is complete when:
- slot definitions are no longer hardcoded separately in inventory, visuals, and tuner
- `testing_world.tscn` no longer drifts silently from the shared slot source
- runtime inventory UI components receive dependencies explicitly enough to remove fragile scene-tree lookup paths
- inventory-related controls all style correctly through `UIStyleProfile`
- docs describe the new architecture accurately
- smoke coverage exercises the shared slot-truth path and core pickup/stow/drop behavior

## Non-Goals For This Pass
Not included in this implementation pass:
- full UI layout redesign
- broad new gameplay features such as medical systems or weapon state
- drag-and-drop and stack split/merge unless they are needed to stabilize an existing broken path
- turning tuner into a bulk content pipeline

## Follow-Up After This Plan Is Implemented
Once this branch completes the architecture and styling work above, the next pass should focus on UI layout redesign.

That redesign should build on these stabilized foundations:
- responsive inventory overlay behavior
- less compressed narrow-viewport layouts
- improved panel hierarchy and information density
- accessibility improvements for smaller resolutions and different aspect ratios

## Execution Order
Recommended order:
1. create shared slot catalog and loader
2. migrate inventory and visuals
3. align testing scene and item validation
4. refactor inventory UI dependencies and payload contracts
5. harden styling coverage
6. standardize `CharacterTuner`
7. expand smoke coverage
8. update docs and TODO state

## Notes For Any Follow-Up Agent
If work is resumed by another agent:
- trust the shared slot catalog as the intended new source of truth
- preserve current slot ids for save and item-definition compatibility
- avoid moving storage authority out of `InventoryComponent`
- avoid redesigning the UI layout until the architecture pass is complete
