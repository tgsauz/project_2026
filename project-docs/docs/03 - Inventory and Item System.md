---
type: system
status: active
owned_by: gameplay
updated: 2026-04-03
---

# 03 - Inventory and Item System

## Summary
The inventory system is now an attachment-driven graph built from default body nodes, equipment-contributed child nodes, mounted containers, and runtime item instances. It replaces the old flat slot list with a runtime topology that can express where an item physically exists, what item created that node, and how much storage capacity each container exposes.

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
- `attachment_tags`
- `preferred_slot`
- `attachment_modifier`
- `visible_when_equipped`
- `equipped_visual_scene`
- `visual_profile_id`
- `attachment_profiles`
- `reserve_secondary_hand`
- `secondary_hand_slot`
- `item_size`
- `storage_capacity_units`
- `storage_allowed_categories`
- `storage_allowed_tags`
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
- default body layout bootstrap
- runtime attachment graph
- node occupancy
- runtime item registry
- equipment-contributed node activation/removal
- container storage contents
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

## Root Body Nodes
Current default body nodes:
- `left_hand`
- `right_hand`
- `torso`
- `belt`
- `back_mount`
- `lower_back`
- `shoulder_mount`
- `left_pocket`
- `right_pocket`

Each node has:
- a display name
- accepted categories
- optional accepted item tags
- a `visible` flag used by visuals
- anchor metadata used by visuals and tooling
- a `tuner_enabled` flag used by `CharacterTuner`

Current default body node definitions live in the shared attachment layout:
- `AttachmentPointDefinition`
- `AttachmentLayoutDefinition`
- `AttachmentLayoutLibrary`

Example:
- if you add a new body node such as `radio_mount`, add it to the default attachment layout first
- if an equipped item should add child nodes, author an `EquipmentAttachmentModifier` instead of hardcoding them in UI or runtime visuals

## Attachment Graph Model
The system is not a simple array.

Runtime layers:
- root body nodes hold direct item occupants
- some equipped occupants contribute new child attachment nodes through `attachment_modifier`
- some items are containers and hold child item instance ids
- attached items and stored items can coexist in the same runtime inventory graph

This means a belt can occupy the `belt` root node, create `belt_slot_01` through `belt_slot_08`, mount a pouch on one child node, and then let that pouch hold medical or ammo items internally.

## Main Inventory APIs
### Placement and movement
- `get_attachment_node(node_id)`
- `get_attachment_children(node_id)`
- `get_available_attachment_nodes(include_hidden := false)`
- `can_attach_item(item, node_id)`
- `attach_item(item, node_id)`
- `detach_item(item_id)`
- `can_store_item(item, target_slot)` (compatibility wrapper)
- `store_item_in_slot(item, target_slot)` (compatibility wrapper)
- `store_item_in_container(item, target_container_id)`
- `can_store_item_in_storage(item, target_container_id)`
- `get_storage_usage(container_id)`
- `get_storage_capacity(container_id)`
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
1. The inventory checks currently active attachment nodes.
2. It tries preferred and allowed root nodes first.
3. If an equipped item contributes child nodes, those become valid attachment targets too.
4. If no node works, it tries existing containers.
5. Containers validate category, size-capacity, and weight constraints.

Examples:
- Equipping `simpleBelt.tres` into `belt` creates `belt_slot_01` through `belt_slot_08`.
- Attaching `simplePouch.tres` to `belt_slot_01` succeeds because the node accepts `pouch` items.
- Storing a weapon of size `3` into a pouch with `storage_capacity_units = 3` works only if the pouch is otherwise empty.

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
- Stylized dots project directly over active attachment nodes
- Hovering a node shows the principal item tooltip
- **Slot Status Indicators**: Buttons show inline occupant names and container counts (e.g., `Lower Back — Med Pouch (2/4)`)
- Clicking a node selects it and extrudes a single connector line
- Category filters (Hotkey 1-4)
- The connector line terminates at the selected panel's accent underline
- Reads node state from the bound `InventoryComponent`

### InventorySlotPanelUI
- Responsive top-left selected-item panel
- Shows the principal item name for the selected node
- Renders direct action buttons and container context without mutating inventory directly

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

When changing slot metadata:
1. Update the shared slot catalog first
2. Only override `InventoryComponent.slot_names` in a scene if you intentionally want a subset
3. Let visuals and tuner inherit the change through `EquipmentSlotLibrary`

Example:
- to change `belt` accepted categories, edit the `belt` entry in `DefaultEquipmentSlotCatalog.tres`
- do not duplicate that rule in `InventoryComponent` and `VisualsComponent`

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
- data-driven action providers (item-specific actions like "Unload" or "Use")
- richer runtime item state per item family
- cleaner typing restoration after parser stability work
- drag-and-drop item movement between slots
- stack split/merge UI systems
