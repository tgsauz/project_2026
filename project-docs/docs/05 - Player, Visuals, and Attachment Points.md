---
type: system
status: active
owned_by: gameplay
updated: 2026-04-22
---

# 05 - Player, Visuals, and Attachment Points

## Summary
The player controller coordinates movement and quick actions, while `VisualsComponent` is responsible for visual body responses and inventory-driven equipment visuals for held and mounted items.

## CharacterController Responsibilities
Script: `Player/Scripts/CharacterController.gd`

Owns:
- movement input
- sprinting and stamina
- armed and aiming animation-state selection
- load factor usage
- quick action input and routing
- tap-versus-hold interact timing
- spawning dropped world items
- dependency resolution for inventory, interaction, visuals, camera, and animation

Should not own:
- detailed slot rules
- item container logic
- visual attachment decisions

Current weapon-state rule:
- `CharacterController` reads the main-hand occupant from `InventoryComponent`
- a main-hand item with category `weapon` drives the `Armed` state
- held aim input plus a main-hand weapon drives the `Aiming` state
- while aiming in third-person, facing follows camera yaw so strafe animations stay meaningful

## VisualsComponent Responsibilities
Script: `Player/Scripts/VisualsComponent.gd`

Owns:
- body tilt
- attachment root creation
- inventory-to-visual binding
- equipped proxy scene spawning
- live reapplication of handle/profile transforms for equipped visuals
- placeholder fallback visual creation
- mounted interactable area creation
- first-person head suppression so the camera does not clip through the player face

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
Gameplay attachment roots are now layout-driven for:
- `right_hand`
- `left_hand`
- `torso`
- `belt`
- `back_mount`
- `lower_back`
- `left_pocket`
- `right_pocket`
- `shoulder_mount`

Visual-only helper anchor:
- `gun_support`

Current implementation uses `BoneAttachment3D` roots created from active attachment nodes in the inventory graph plus one helper root for `gun_support`.

Equipment can also contribute dynamic child nodes at runtime:
- belts add belt-slot anchors
- vests add torso child anchors
- visuals consume those nodes exactly like default body nodes once `InventoryComponent` activates them

## Recursive Skeleton Resolution
The `VisualsComponent` no longer requires a hardcoded path to the skeleton. On `_ready()`, it performs a recursive search starting from the `Rig` node to find the first `Skeleton3D`. This allows for flexible rig naming (e.g., "GeneralSkeleton", "Skeleton3D", or "Armature") without breaking the attachment system.

## Clothing and Skinned Meshes
For items that need to deform with the character's body (like Vests or Shirts), `ItemDefinition` provides an `is_skinned_mesh` toggle.

When enabled:
1. the item is parented directly to the `Skeleton3D` instead of a `BoneAttachment3D`.
2. its internal `MeshInstance3D` has its `skeleton` path automatically redirected to the character's skeleton.

This ensures that the clothing mesh stays perfectly aligned with the character's limbs during animation.

## World vs. Equipped Visual Separation

The system now supports two independent scenes per item:

- **`equipped_visual_scene`** — Used by `VisualsComponent` when the item is held or mounted on the character. May contain an armature, IK grip nodes (`LGRIP`, `RGRIP`), weapon sockets, and bone-driven geometry.
- Weapon equipped scenes used for ADS should also expose explicit marker nodes: `SIGHT` and `MUZZLE`.
- **`world_visual_scene`** — Used by `WorldItem` when the item is a physics object on the floor. Should be a lightweight version with a simple mesh and no skeleton. If null, `WorldItem` falls back to its editor-placed child nodes (backward compatible).

This separation means changes to the equipped hand position no longer require editing the floor mesh file, and the physics bounding box of a world pickup is not inflated by an offset skeleton.

## Attachment Profiles and Scene Offsets
The system provides two composable ways to control the placement of an equipped item, applied in this order:

1. **Profile Override (Data-Driven):** If an `ItemVisualAttachmentProfile` is provided in `attachment_profiles`, its `position`, `rotation_degrees`, and `scale` position the visual at the attachment root.
2. **Scene-Local (Direct Fallback):** If no profile is present, `VisualsComponent` respects the internal transform of the `equipped_visual_scene` root.

**Note**: All items default to **1.0 scale compensation**. Legacy 0.01x scaling has been removed to match modern GLB/FBX export standards.

## Mounted Interactables
When a visible mounted slot has an occupant, `VisualsComponent` can create a `MountedItemInteractable` on that anchor so the player can target mounted gear in-world.

Held items intentionally do not get mounted interactables right now.

## How To Add A New Visible Attachment Point
### Logical side
- add the new body node to the shared attachment layout
- or add a child node through an `EquipmentAttachmentModifier`
- let item definitions opt into that node through `allowed_slots` or compatible tags/categories

### Visual side
- set the node's anchor bone and local transform in the layout or modifier
- verify the anchor appears in `VisualsComponent` debug gizmos

Example:
- to add `radio_mount`, create a body-node entry in the default attachment layout with its bone name and offsets
- then assign `radio_mount` inside an item's `allowed_slots`
- run the tuner or testing scene to confirm the new anchor projects correctly

See also: [[09 - How To Add New Attachment Points]]

## How To Modify Equipped Visuals
When an item is attaching incorrectly:
1. Check that the item definition has the correct `equipped_visual_scene`
2. Check that the item has an `attachment_profile` for the slot it actually occupies
3. Open the `equipped_visual_scene` in the editor and adjust the mesh root position directly, or tune the `attachment_profile` for slot-specific offsets
4. Only change `VisualsComponent` if the anchor itself is missing or wrong

## How To Test Visual Changes
Validate:
1. world pickup into right hand spawns a held visual
2. moving the same item to `left_hand` updates the anchor and offsets
3. lower-back and torso items render correctly and remain interactable
4. items with no equipped proxy still show placeholder visuals
5. stow, drop, and slot moves remove or relocate visuals correctly
6. **Skinned Meshes**: Verify the vest moves with the spine during breath/idle animations.

## Current Limitations
- placeholder visual mesh generation is primitive

## FPS Visibility Rule
- during gameplay first-person mode, `VisualsComponent` hides character body meshes by moving them to the FPS-hidden render layer
- this suppression is disabled for third-person and inventory mode so the full body remains visible for inspection and orbit cameras

## Future Refactor Targets
- better separation between visible proxy and interactable collision shape
- per-item LGRIP validation in the CharacterTuner tool
- stronger editor-facing grip authoring UX
