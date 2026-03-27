---
type: system
status: active
owned_by: gameplay
updated: 2026-03-26
---

# 04 - Interaction System

## Summary
Interaction is raycast-driven and interface-style. The player looks at a target, the target provides prompt/action data, and the interaction component dispatches `interact(actor)` or a named action.

## Main Script
Script: `World/Items/Scripts/InteractionComponent.gd`

## Responsibilities
- find the active camera
- raycast into the world
- resolve an interactable target
- collect prompt payload from that target
- expose current target and current prompt data
- call `interact(actor)` when the player interacts

## Interaction Contract
An interactable target may implement:
- `interact(actor)`
- `get_interaction_prompt_data()`
- `get_interaction_actions(actor)`
- `perform_interaction_action(actor, action_id)`

This is important because it keeps the system flexible:
- `WorldItem` can be interacted with
- mounted body items can be interacted with
- future world objects can use the same contract

## Prompt Payload
Current prompt payload is a dictionary with fields such as:
- `target_id`
- `title`
- `tooltip`
- `interact_label`
- `interact_key_hint`
- `category`
- `actions`

The UI reads this payload directly rather than reconstructing it from type checks.

## Quick Action Flow
Quick actions are coordinated by `CharacterController`.

Flow:
1. A target is focused.
2. The controller asks for available actions.
3. The UI shows the quick action list.
4. The selected action is passed back to the target.

Current action examples:
- `pickup`
- `move_to_hand`
- `unequip`
- `drop`
- `inspect`

## WorldItem Responsibilities
`WorldItem` is the main world-side inventory pickup object.

It:
- ensures a runtime item instance exists
- exposes prompt data based on the item definition
- exposes pickup-oriented actions
- stores a duplicated runtime instance in inventory on pickup

## MountedItemInteractable Responsibilities
`MountedItemInteractable` is the interaction bridge for visible equipped gear on the body.

It:
- points at a specific slot name
- asks `InventoryComponent` which item is in that slot
- exposes prompt data for that slot occupant
- forwards selected quick actions back to the actor/controller

## Current Limitations
- action generation is still fairly generic
- prompt payload is a dictionary instead of a stricter typed data object everywhere
- quick action UX is still minimal
- target resolution is simple and does not yet prioritize among multiple overlapping interactables

## Safe Extension Path
- add new interactions by implementing the existing contract
- avoid adding target-type special cases to `InteractionComponent`
- put item-specific action logic near the item or the controller action router, not in the raycast component
