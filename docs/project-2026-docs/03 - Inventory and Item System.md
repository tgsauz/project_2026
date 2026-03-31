---
type: system
status: active
owned_by: gameplay
updated: 2026-03-28
---

# 03 - Inventory and Item System

## Summary
The inventory system is a physical storage graph built from body slots, mounted containers, and runtime item instances. It replaces the old flat inventory list with a structure that can represent where an item physically exists on the character.

## Core Types
### ItemDefinition
Script: `World/Items/Scripts/ItemDefinition.gd`

Purpose:
- design-time item metadata
- shared by many runtime instances

Key fields:
- `id`
- `display_name`
- `tooltip_text`
- `category`
- `weight`
- `interaction_verb`
- `interaction_key_hint`
- `allowed_slots`
- `preferred_slot`
- `visible_when_equipped`
- `equipped_visual_scene`
- `visual_profile_id`
- `attachment_profiles`
- `reserve_secondary_hand`
- `secondary_hand_slot`
- container-related fields
- placeholder visual fields

### ItemInstance
Script: `World/Items/Scripts/ItemInstance.gd`

Purpose:
- runtime identity and mutable state

Key fields:
- `instance_id`
- `definition`
- `stack_count`
- `condition`
- `custom_state`
- `owning_slot`
- `parent_instance_id`
- `contained_item_ids`

### ItemDefinitionRegistry
Script: `World/Items/Scripts/ItemDefinitionRegistry.gd`

Purpose:
- static preloaded lookup for item definitions by string ID
- enables efficient serialization and deserialization
- optimized for low-end hardware (O(1) lookups after initial scan)

## InventoryComponent Responsibilities
Script: `World/Items/Scripts/InventoryComponent.gd`

`InventoryComponent` is the authority for physical storage state.

It owns:
- root slot configuration
- slot occupancy
- runtime item registry
- total carried weight
- load factor
- equipment pickup routing
- visible equipped items query
- equipment visual payload generation

It does not own:
- weapon firing logic
- medical use logic
- UI rendering
- final mesh asset spawning

## Root Body Slots
Current slots:
- `left_hand`
- `right_hand`
- `torso`
- `lower_back`
- `belt`
- `left_pocket`
- `right_pocket`
- `back_mount`
- `shoulder_mount`

Each slot has:
- a display name
- accepted categories
- a `visible` flag used by visuals

Current slot definitions are hardcoded in `_build_slot_configs()`.

## Storage Graph Model
The system is not a simple array.

Storage layers:
- root body slots hold direct item occupants
- some occupants are containers
- containers hold child item instance ids
- nested items can themselves contain more items later

This means a secured container on lower back can carry medical or ammo items while still being itself mounted on the character.

## Main Inventory APIs
### Placement and movement
- `can_store_item(item, target_slot)`
- `store_item_in_slot(item, target_slot)`
- `store_item_in_container(item, target_container_id)`
- `store_item_instance_best_effort(item)`
- `pickup_item_instance(item, prefer_equipment, allow_fallback_storage)`
- `move_item(item_id, target_slot, target_container_id)`
- `equip_item(item_id, target_slot)`
- `unequip_item(item_id)`
- `move_item_to_hand(item_id)`

### Removal and drop
- `drop_item(item_id)`

### Queries
- `get_item_instance(item_id)`
- `get_slot_state(target_slot)`
- `get_visible_equipment()`
- `get_equipped_visuals()`
- `get_main_hand_item()`
- `get_total_weight()`
- `get_load_factor()`

### Persistence (Phase 5)
- `serialize() -> Dictionary`
- `deserialize(data: Dictionary) -> void`

The serialization model flattens the nested storage graph into a serializable Dictionary containing item instances, their state, and slot occupancy. It uses `ItemDefinitionRegistry` to restore design-time references.

## Placement Rules
When an item is introduced into inventory:
1. The inventory checks allowed body slots.
2. It tries preferred and allowed slots first.
3. If no slot works, it tries existing containers.
4. Containers validate category, capacity, and weight constraints.

## Hand Pickup Rules
Direct world pickup can now prefer equipment placement instead of generic storage.

Current behavior:
1. `WorldItem` duplicates its runtime instance.
2. Inventory calls `pickup_item_instance(...)`.
3. If the item supports hand slots, inventory tries its preferred hand first.
4. If that hand is occupied, inventory attempts to auto-stow the current occupant into another valid slot or container.
5. If hand equip still fails, inventory falls back to normal best-effort storage.

This keeps hand pickup policy in `InventoryComponent` rather than scattering it across world objects or controller code.

## Equipment Visual Payload
`InventoryComponent` now exposes a richer visual payload through `get_equipped_visuals()`.

Each visible entry can include:
- `slot_name`
- `item_id`
- `definition`
- `display_name`
- `attachment_profile`
- `visual_state`
- `secondary_slot_name`
- `equipped_visual_scene`
- `visual_profile_id`

This is important because inventory still owns gameplay truth, while `VisualsComponent` only reflects these entries visually.

## Weight and Load
Weight is recalculated in `_recalculate()`.

Current behavior:
- every live instance in the registry contributes weight
- nested container contents contribute through the same instance registry
- load factor is derived from `total_weight / base_capacity`
- movement systems consume that load factor in the player controller

## Containers
A container is just an item whose definition has:
- `is_container = true`

Container behavior is still generic, which is good:
- a secured container
- an ammo box
- a med pouch
- a backpack

all fit the same structural model.

## UI Presentation (Phase 4 & 5)
The inventory UI is diegetic and uses a Camera-based orbit view.

### InventoryOverlayUI
- Accordion-style sidebar menu
- Dynamic leader lines projecting 3D attachment points to 2D screen space
- **Slot Status Indicators**: Buttons show inline occupant names and container counts (e.g., `Lower Back — Med Pouch (2/4)`)
- Category filters (Hotkey 1-4)

### ItemSlotPanelUI
- Expandable list of items within a slot or container
- **Item Tooltips**: Hovering an item shows name, category, weight, condition, and description.

### ItemInspectUI
- 3D viewport for inspecting selected items with rotation support.

### Debug Inventory Inspector
- Raw state viewer for developers (toggled with Debug hotkey)
- Provides quick actions: `Clear All`, `Add Test Item`, `Serialize`, `Deserialize`

## Categories
Current categories:
- `weapon`
- `ammo`
- `medical`
- `equipment`
- `clothing`

Right now categories mostly drive slot/container acceptance, UI filtering, and future intent. They are not yet full gameplay behavior systems.

## World Flow
Ground items are represented by `WorldItem`.

A `WorldItem`:
- references an `ItemDefinition`
- owns or generates a runtime `ItemInstance`
- provides prompt data
- duplicates and stores its instance on pickup
- asks inventory to resolve preferred hand pickup before generic storage

See also: [[04 - Interaction System]]

## How To Modify This System Safely
When changing pickup or storage behavior:
1. Start in `InventoryComponent`, not in `WorldItem` or `CharacterController`
2. Keep slot legality in `can_store_item(...)`
3. Keep auto-stow and pickup policy near `pickup_item_instance(...)`
4. Avoid adding item-family special cases here unless they are purely storage-related

When adding new equipment metadata:
1. Add the field to `ItemDefinition`
2. Decide whether it changes gameplay truth or only visual projection
3. If it is visual-only, prefer emitting it through `get_equipped_visuals()` instead of making visuals query inventory internals directly

## How To Test Inventory + Equipment Changes
After changes in this layer, validate:
1. Pickup into empty right hand
2. Pickup into occupied right hand with a legal stow target
3. Pickup of an item that cannot go into hands
4. Move-to-hand from an existing inventory item
5. Stow and drop flows
6. Container contents surviving drop and re-store

## Current Limitations
- slot list is hardcoded
- slot acceptance rules are hardcoded
- `get_item_actions()` is still generic and simple
- stack handling exists structurally but is not yet a full UX system
- item behavior is not yet profile-driven by category/type
- auto-stow is still heuristic rather than fully policy-driven

## Future Refactor Targets
- data-driven slot definitions (move out of hardcoded dictionary)
- data-driven action providers (item-specific actions like "Unload" or "Use")
- richer runtime item state per item family
- cleaner typing restoration after parser stability work
- drag-and-drop item movement between slots
- stack split/merge UI systems
