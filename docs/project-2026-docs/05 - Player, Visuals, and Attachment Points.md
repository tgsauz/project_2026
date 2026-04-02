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
- `back_mount` (backpacks)
- `torso` (clothing/vests)
- `head` (helmets/glasses)
- `belt` (pouches/tools)
- reserved support anchor: `gun_support`

Current implementation uses `BoneAttachment3D` roots bound to:
- `hand_r`
- `hand_l`
- `spine_01` (lower_back / belt)
- `spine_02` (back_mount / torso)
- `head` (head)
- `ik_hand_gun`

Current anchor lookup is still code-defined in `_get_slot_anchor(slot_name)`.

## Recursive Skeleton Resolution
The `VisualsComponent` no longer requires a hardcoded path to the skeleton. On `_ready()`, it performs a recursive search starting from the `Rig` node to find the first `Skeleton3D`. This allows for flexible rig naming (e.g., "GeneralSkeleton", "Skeleton3D", or "Armature") without breaking the attachment system.

## Clothing and Skinned Meshes
For items that need to deform with the character's body (like Vests or Shirts), `ItemDefinition` provides an `is_skinned_mesh` toggle.

When enabled:
1. the item is parented directly to the `Skeleton3D` instead of a `BoneAttachment3D`.
2. its internal `MeshInstance3D` has its `skeleton` path automatically redirected to the character's skeleton.

This ensures that the clothing mesh stays perfectly aligned with the character's limbs during animation.

## Attachment Profiles and Scene Offsets
The system provides two ways to control the placement of an equipped item:

1. **Scene-Local (Direct)**: If no `attachment_profile` is provided for a slot, the `VisualsComponent` will **respect the internal transform** of the `equipped_visual_scene`. This allows you to position a mesh root in the Godot Editor and have it "just work."
2. **Profile Override (Data-Driven)**: If an `ItemVisualAttachmentProfile` is provided, its `position`, `rotation_degrees`, and `scale` will overwrite the scene's defaults. This is ideal for fixing clipping on specific character models without changing the 3D file itself.

**Note**: All items now default to a **1.0 scale compensation**. Legacy 0.01x scaling has been removed to match modern GLB/FBX export standards.

## Mounted Interactables
When a visible mounted slot has an occupant, `VisualsComponent` can create a `MountedItemInteractable` on that anchor so the player can target mounted gear in-world.

Held items intentionally do not get mounted interactables right now.

## How To Add A New Visible Attachment Point
### Logical side
- add the new slot to the `ItemDefinition` enumeration in `ItemDefinition.gd`
- add the new slot to the `InventoryComponent` `slot_names` in the inspector (if it should be a base character slot)
- let item definitions opt into that slot through `allowed_slots`

### Visual side
- register the new attachment root in `VisualsComponent._ensure_attachment_roots()`
- bind it to the desired bone name
- ensure it is returned correctly from the internal anchor dictionary

See also: [[09 - How To Add New Attachment Points]]

## How To Modify Equipped Visuals
When an item is attaching incorrectly:
1. Check that the item definition has the correct `equipped_visual_scene`
2. Check that the item has an `attachment_profile` for the slot it actually occupies
3. Tune the profile resource before changing code
4. If no profile exists, open the `equipped_visual_scene` in the editor and adjust the mesh root position directly.
5. Only change `VisualsComponent` if the anchor itself is missing or wrong

## How To Test Visual Changes
Validate:
1. world pickup into right hand spawns a held visual
2. moving the same item to `left_hand` updates the anchor and offsets
3. lower-back and torso items render correctly and remain interactable
4. items with no equipped proxy still show placeholder visuals
5. stow, drop, and slot moves remove or relocate visuals correctly
6. **Skinned Meshes**: Verify the vest moves with the spine during breath/idle animations.

## Current Limitations
- slot-to-bone mapping is still defined in code, though bone names are exported
- placeholder visual mesh generation is primitive
- two-hand support is only reserved in data, not yet enforced visually or by animation

## Future Refactor Targets
- data-driven slot anchor definitions
- per-item proxy scene support for more item families
- better separation between visible proxy and interactable collision shape
