---
type: system
status: active
owned_by: gameplay
updated: 2026-03-26
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

## InventoryComponent Responsibilities
Script: `World/Items/Scripts/InventoryComponent.gd`

`InventoryComponent` is the authority for physical storage state.

It owns:
- root slot configuration
- slot occupancy
- runtime item registry
- total carried weight
- load factor
- visible equipped items query

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
- `get_total_weight()`
- `get_load_factor()`

## Placement Rules
When an item is introduced into inventory:
1. The inventory checks allowed body slots.
2. It tries preferred and allowed slots first.
3. If no slot works, it tries existing containers.
4. Containers validate category, capacity, and weight constraints.

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

## Categories
Current categories:
- `weapon`
- `ammo`
- `medical`
- `equipment`
- `clothing`

Right now categories mostly drive slot/container acceptance and future intent. They are not yet full gameplay behavior systems.

## World Flow
Ground items are represented by `WorldItem`.

A `WorldItem`:
- references an `ItemDefinition`
- owns or generates a runtime `ItemInstance`
- provides prompt data
- duplicates and stores its instance on pickup

See also: [[04 - Interaction System]]

## Current Limitations
- slot list is hardcoded
- slot acceptance rules are hardcoded
- `get_item_actions()` is still generic and simple
- stack handling exists structurally but is not yet a full UX system
- item behavior is not yet profile-driven by category/type

## Future Refactor Targets
- data-driven slot definitions
- data-driven action providers
- serialization helpers for save/load
- richer runtime item state per item family
- cleaner typing restoration after parser stability work
