---
type: guide
status: active
owned_by: gameplay
updated: 2026-03-26
---

# 09 - How To Add New Attachment Points

## Summary
Adding a new attachment point requires changes in both the logical inventory layer and the visual attachment layer. A slot is not complete until inventory rules and anchor mapping both exist.

## Step 1: Add The Logical Slot
In `InventoryComponent`:
1. Add the slot name to `slot_names`
2. Add its slot config in `_build_slot_configs()`
3. Decide:
   - display name
   - accepted categories
   - whether it counts as a visible slot

Examples of future slots:
- `left_shoulder`
- `right_shoulder`
- `chest_rig`
- `backpack_mount`
- `holster_left`
- `holster_right`

## Step 2: Let Items Use That Slot
In the item definition:
1. Add the new slot to `allowed_slots`
2. Optionally set it as `preferred_slot`
3. Set `visible_when_equipped = true` if it should appear on the body

## Step 3: Add The Visual Anchor
In `VisualsComponent`:
1. Create a new attachment root for the slot
2. Bind it to the chosen bone or stable node
3. Set local offset and rotation
4. Return it from `_get_slot_anchor(slot_name)`

## Step 4: Enable Interaction If Needed
If the slot is visible and should be physically targetable:
- ensure `_update_slot_interactable(...)` can create a `MountedItemInteractable` on that anchor

## Recommended Implementation Pattern
For each new visible slot, define:
- slot name
- owning bone
- local transform offset
- local rotation
- collision shape size if interactable

Right now these values are code-defined. Later they should move into authored data resources if the number of slots grows.

## Example: Add A Shoulder Radio Slot
### Inventory
- add `left_shoulder`
- accept `equipment`
- mark visible

### Item definition
- create radio item
- `allowed_slots = ["left_shoulder"]`
- `preferred_slot = "left_shoulder"`
- `visible_when_equipped = true`

### Visuals
- create shoulder attachment root
- map `left_shoulder` to that root
- tune offset so the placeholder sits correctly

## Current Limitations
- only lower-back has an explicit anchor path today
- slot-to-anchor mapping is hardcoded
- placeholder visuals are generic meshes
- collision/interactable shapes are not yet data-driven per slot

## Future Refactor Target
When multiple visible body slots are added, move toward a data-driven slot-anchor registry so adding a new slot does not require scattered code edits.
