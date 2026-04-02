---
type: guide
status: active
owned_by: gameplay
updated: 2026-03-28
---

# 08 - How To Add New Items

## Summary
New items are added by authoring an `ItemDefinition` resource and then deciding how that definition enters the world or inventory. The current system is definition-driven, so most new content should start with a `.tres`, not with new branching code.

## Checklist: Add A New Item Definition
1. Create a new resource using `ItemResource` / `ItemDefinition`
2. Set `id`
3. Set `display_name`
4. Set `tooltip_text`
5. Set `category`
6. Set `weight`
7. Set `interaction_verb` and `interaction_key_hint`
8. Set `allowed_slots` (e.g., `back_mount`, `torso`, `head`, `belt`)
9. Set `preferred_slot`
10. Set `visible_when_equipped` if it should appear on the body
11. If it should appear while equipped, decide whether to assign:
    - `equipped_visual_scene`
    - `attachment_profiles`
    - **`is_skinned_mesh`**: IMPORTANT for clothing (Vests, Shirts) that needs to move with the character bones.
12. Set placeholder visual fields as fallback even if an equipped proxy scene exists

## Category Guidance
### Weapon
- Usually valid for hands, back mount, shoulder mount, or lower back
- Good for rifles, pistols, melee proxies, large carried gear

### Ammo
- Currently best used for ammo boxes or ammo carriers
- Usually valid for belt, pockets, and containers

### Medical
- Usually valid for belt, pockets, torso, and containers
- Good for consumables and treatment items

### Equipment
- Best for pouches, secured containers, radios, tools, and mounted utility gear
- Often the category used for visible mounted body items

### Clothing
- Good for wearable items like Vests, Helmets, or Backpacks.
- **Vests/Shirts**: Usually require `is_skinned_mesh = true` to prevent clipping during animation.
- **Helmets**: Mount to the `head` slot.

## Checklist: Add A Physical Container
1. Create the item definition
2. Set `is_container = true`
3. Set `container_capacity`
4. Set `container_max_weight` if needed
5. Set `container_allowed_categories`
6. Set `allowed_slots` for where the container itself can mount or be stored
7. Set `visible_when_equipped` if it should appear on the body

## Checklist: Add A Hand-Held Item
1. Make sure `allowed_slots` includes `right_hand`, `left_hand`, or both
2. Set `preferred_slot`
3. Decide whether pickup should usually land in hand
   - if yes, make sure the item supports hand slots
4. Create an `equipped_visual_scene` if you want authored hand visuals
5. Create `ItemVisualAttachmentProfile` resources for any visible slots the item uses
6. Keep placeholder visual fields configured so the item still renders if the proxy scene is missing
7. If the item may become two-handed later, set:
   - `reserve_secondary_hand = true`
   - `secondary_hand_slot`

## Checklist: Add Equipped Visual Authoring
For a visible item:
1. Create or choose a lightweight equipped proxy scene.
2. If it is clothing that deforms, set `is_skinned_mesh = true`.
3. If it looks wrong on the body, choose one of two paths:
   - **Scene Path**: Open the `equipped_visual_scene` and adjust the mesh root position/rotation/scale.
   - **Profile Path**: Create an `ItemVisualAttachmentProfile` for that slot and set specific offsets there.
4. Assign any profiles in `attachment_profiles`.
5. Test the actual occupied slots, not just the preferred one.

## Checklist: Spawn It In The World
1. Add or instantiate a `WorldItem`
2. Assign `item_definition`
3. Add a collision shape
4. Place it in the world

On pickup, the `WorldItem` duplicates its runtime instance into inventory and lets inventory decide whether it should enter a hand slot first.

## Checklist: Add A New Item Category Instance
If the category already exists and you only want a new item within it:
- no code change is required
- create a new definition resource
- configure its slot rules
- configure its visual/container settings if needed

## When A New Item Needs Code
Only add code if the item needs behavior beyond storage and interaction metadata, such as:
- weapon firing
- healing
- reloading
- special context actions
- custom runtime state transitions

When that happens, keep the behavior layered on top of the current item/inventory structure rather than embedding it into inventory itself.

## How To Test A New Item
At minimum, validate:
1. prompt text when looking at the world item
2. tap pickup behavior
3. hold `F` quick actions
4. correct slot placement
5. correct equipped visual or placeholder fallback
6. stow and drop behavior
7. re-pickup after drop

## Current Limitations
- there is no deep category-specific action generation yet
- stack behavior is structurally present but not a full player UX system
- placeholder visuals are simplistic
