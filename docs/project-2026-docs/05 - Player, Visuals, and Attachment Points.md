---
type: system
status: active
owned_by: gameplay
updated: 2026-03-28
---

# 05 - Player, Visuals, and Attachment Points

## Summary
The player controller coordinates movement and quick actions, while `VisualsComponent` is responsible for visual body responses and inventory-driven equipment visuals for held and mounted items.

## CharacterController Responsibilities
Script: `Player/Scripts/CharacterController.gd`

Owns:
- movement input
- sprinting and stamina
- load factor usage
- quick action input and routing
- tap-versus-hold interact timing
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
- equipped proxy scene spawning
- placeholder fallback visual creation
- mounted interactable area creation

## Inventory-Driven Visual Flow
1. `InventoryComponent` recalculates state.
2. It emits `equipment_visuals_changed`.
3. `VisualsComponent.bind_inventory(...)` listens to that signal.
4. `get_equipped_visuals()` returns visible slot occupants plus visual metadata.
5. `VisualsComponent` creates, updates, or removes equipped visuals for those slots.

This is the correct dependency direction:
- inventory is the source of truth
- visuals reflect inventory

## Current Attachment Support
Right now there are explicit body attachment roots for:
- `right_hand`
- `left_hand`
- `lower_back`
- reserved support anchor: `gun_support`

Current implementation uses `BoneAttachment3D` roots bound to:
- `hand_r`
- `hand_l`
- `pelvis`
- `ik_hand_gun`

Current anchor lookup is still code-defined in `_get_slot_anchor(slot_name)`.

## Authored Equipment Visuals
Items can now supply an authored equipped proxy scene through `ItemDefinition.equipped_visual_scene`.

This scene is:
- lightweight
- attachment-oriented
- separate from world pickup representation

If no authored proxy exists, visuals fall back to generated placeholder meshes from:
- `placeholder_visual_shape`
- `placeholder_visual_size`
- `placeholder_visual_color`

This gives the system a scalable path where content teams can improve item visuals without changing inventory code.

## Attachment Profiles
Per-slot offsets are now authored through `ItemVisualAttachmentProfile` resources.

Each profile can define:
- `slot_name`
- `visual_state`
- `position`
- `rotation_degrees`
- `scale`
- `secondary_slot_name`

This is the main data hook new developers should use when a held or mounted item looks wrong on the body.

## Mounted Interactables
When a visible mounted slot has an occupant, `VisualsComponent` can create a `MountedItemInteractable` on that anchor so the player can target mounted gear in-world.

Held items intentionally do not get mounted interactables right now.

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

## How To Modify Equipped Visuals
When an item is attaching incorrectly:
1. Check that the item definition has the correct `equipped_visual_scene`
2. Check that the item has an `attachment_profile` for the slot it actually occupies
3. Tune the profile resource before changing code
4. Only change `VisualsComponent` if the anchor itself is missing or wrong

When adding a new visible slot:
1. add slot support in inventory
2. add or reuse an anchor in `VisualsComponent`
3. add profile resources for the items that need that slot
4. test both authored-scene and placeholder fallback paths

## How To Test Visual Changes
Validate:
1. world pickup into right hand spawns a held visual
2. moving the same item to `left_hand` updates the anchor and offsets
3. lower-back items still render and remain interactable
4. items with no equipped proxy still show placeholder visuals
5. stow, drop, and slot moves remove or relocate visuals correctly

## Current Limitations
- slot-to-bone mapping is hardcoded
- placeholder visual mesh generation is primitive
- anchor registry is not yet data-driven
- two-hand support is only reserved in data, not yet enforced visually or by animation

## Future Refactor Targets
- data-driven slot anchor definitions
- per-item proxy scene support for more item families
- better separation between visible proxy and interactable collision shape
