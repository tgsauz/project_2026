---
type: guide
status: active
owned_by: gameplay
updated: 2026-03-26
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
8. Set `allowed_slots`
9. Set `preferred_slot`
10. Set `visible_when_equipped` if it should appear on the body
11. Set placeholder visual fields if it should be visible

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
- Good for wearable items and future clothing systems
- Currently mostly acts as a storage-policy category

## Checklist: Add A Physical Container
1. Create the item definition
2. Set `is_container = true`
3. Set `container_capacity`
4. Set `container_max_weight` if needed
5. Set `container_allowed_categories`
6. Set `allowed_slots` for where the container itself can mount or be stored
7. Set `visible_when_equipped` if it should appear on the body

## Checklist: Spawn It In The World
1. Add or instantiate a `WorldItem`
2. Assign `item_definition`
3. Add a collision shape
4. Place it in the world

On pickup, the `WorldItem` duplicates its runtime instance into inventory.

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

## Current Limitations
- there is no deep category-specific action generation yet
- stack behavior is structurally present but not a full player UX system
- placeholder visuals are simplistic
