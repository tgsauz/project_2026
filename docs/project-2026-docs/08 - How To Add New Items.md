---
type: guide
status: active
owned_by: gameplay
updated: 2026-04-22
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
3. **Add a `Handle` node inside the scene at the grip position.** Name it `Handle` (or set `handle_node_name` on the `ItemDefinition` if you prefer a different name). The system will automatically align this node to the bone attachment point. This eliminates the need to re-export the GLB to fix grip position.
   - > [!TIP]
   - > **Use the Handle Grip Preview!** Add a new `Node3D` as a child of your `Handle` node and attach `res://Tools/Helpers/HandleGripPreview.gd`. This `@tool` script safely generates a "Ghost Hand" in the editor viewport so you can visually confirm exactly how the grip lands without running the game. If your rig's arm bone naturally rotates 90 degrees, use the `preview_rotation_offset` in the inspector to turn the ghost hand until it reflects your character's true grasp.
   - > [!TIP]
   - > **Live runtime tuning:** In `res://World/testing_world.tscn`, editing the remote `Handle` transform on an equipped visual now re-applies handle alignment every frame. Weapon root and left-hand IK update immediately, so you can tune grip position/rotation while game runs and see result live.
4. If it looks wrong on the body after Handle alignment, choose one of two paths:
   - **Profile Path (preferred):** Create an `ItemVisualAttachmentProfile` for that slot and set fine-tuning offsets. Profile offsets compose on top of the Handle alignment.
   - **Scene Path (fallback):** If no Handle node is used, open the `equipped_visual_scene` and adjust the mesh root position/rotation/scale directly.
5. Assign any profiles in `attachment_profiles`.
6. Test the actual occupied slots, not just the preferred one.

### Recommended Grip Tuning Order
When a held weapon still looks wrong:
1. Tune the `Handle` in the equipped scene until the grip point itself is correct
2. Use `HandleGripPreview.gd` in editor to verify the authored grip against the rig
3. Use remote-scene live tuning in `testing_world` when you need to see the actual runtime left-hand IK result
4. Only after the grip point is correct, tune `attachment_profiles` for slot-specific offsets

If Y and Z rotations feel too similar while editing the single `Handle`, prefer the rotate gizmo in local mode instead of relying only on Euler fields in the inspector.

## Checklist: Spawn It In The World
1. Drag the canonical `WorldItem.tscn` prefab into your scene. Do not create a basic `RigidBody3D` from scratch.
2. In the inspector, assign the `ItemDefinition` resource to the `WorldItem` node.
3. The system will **automatically** instantiate the visuals (from `world_visual_scene`) and generate a collision shape based on the `world_collision_mode` defined in the resource.
4. **(Optional)** If you want custom physics, adjust the `weight` and `world_collision_mode` inside the `ItemDefinition` itself. This ensures consistency globally.
5. Place it in the world.

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
6. correct `Handle` alignment if the item uses an equipped proxy scene
7. stow and drop behavior
8. re-pickup after drop

## Current Limitations
- there is no deep category-specific action generation yet
- stack behavior is structurally present but not a full player UX system
- placeholder visuals are simplistic
