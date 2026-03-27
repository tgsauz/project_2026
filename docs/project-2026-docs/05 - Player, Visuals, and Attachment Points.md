---
type: system
status: active
owned_by: gameplay
updated: 2026-03-26
---

# 05 - Player, Visuals, and Attachment Points

## Summary
The player controller coordinates movement and quick actions, while `VisualsComponent` is responsible for visual body responses and inventory-driven mounted item visuals.

## CharacterController Responsibilities
Script: `Player/Scripts/CharacterController.gd`

Owns:
- movement input
- sprinting and stamina
- load factor usage
- quick action input and routing
- spawning dropped world items
- dependency resolution for inventory, interaction, visuals, camera, and animation

Should not own:
- detailed slot rules
- item container logic
- visual attachment decisions

## VisualsComponent Responsibilities
Script: `Player/Scripts/VisualsComponent.gd`

Owns:
- body tilt
- attachment root creation
- inventory-to-visual binding
- placeholder mounted visual creation
- mounted interactable area creation

## Inventory-Driven Visual Flow
1. `InventoryComponent` recalculates state.
2. It emits `item_visuals_changed`.
3. `VisualsComponent.bind_inventory(...)` listens to that signal.
4. `get_visible_equipment()` returns visible slot occupants.
5. `VisualsComponent` creates/removes placeholder visuals for those slots.

This is the correct dependency direction:
- inventory is the source of truth
- visuals reflect inventory

## Current Attachment Support
Right now there is one explicit body attachment root:
- `lower_back`

It is created as a `BoneAttachment3D` attached to the configured lower-back bone.

Current anchor lookup is hardcoded in `_get_slot_anchor(slot_name)`.

## Placeholder Visuals
Placeholder visuals are currently generated from `ItemDefinition` fields:
- `placeholder_visual_shape`
- `placeholder_visual_size`
- `placeholder_visual_color`

This is intentionally temporary. The architecture matters more than final art at this stage.

## Mounted Interactables
When a visible slot has an occupant, `VisualsComponent` can also create a `MountedItemInteractable` on that anchor so the player can target mounted gear in-world.

## How To Add A New Visible Attachment Point
### Logical side
- add the new slot to inventory slot names
- add slot config in inventory
- let item definitions opt into that slot through `allowed_slots`

### Visual side
- add a new attachment root in `VisualsComponent`
- bind it to the desired bone or local anchor
- return it from `_get_slot_anchor(slot_name)`
- ensure mounted interactable creation can use it

See also: [[09 - How To Add New Attachment Points]]

## Current Limitations
- slot-to-bone mapping is hardcoded
- only one explicit visible anchor path exists right now
- placeholder visual mesh generation is primitive
- visual offsets are embedded in code rather than authored as data

## Future Refactor Targets
- data-driven slot anchor definitions
- authored attachment scene resources
- per-item placeholder or proxy scene support
- better separation between visible proxy and interactable collision shape
