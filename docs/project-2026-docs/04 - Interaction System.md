---
type: system
status: active
owned_by: gameplay
updated: 2026-03-28
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
- `quick_action_label`
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

## Tap vs Hold Interact
The `interact` input now has two meanings:
- tap `F`: perform the default `interact(actor)` action
- hold `F`: open quick actions for the focused target

Implementation notes:
- hold timing is owned by `CharacterController`
- `InteractionComponent` still only owns targeting and dispatch
- the existing `quick_actions` input remains valid as an alternate way to open the menu

This keeps the interaction contract stable while allowing richer input behavior.

## WorldItem Responsibilities
`WorldItem` is the main world-side inventory pickup object.

It:
- ensures a runtime item instance exists
- exposes prompt data based on the item definition
- exposes pickup-oriented actions
- stores a duplicated runtime instance in inventory on pickup
- lets inventory decide whether pickup should equip to hand or fall back to storage

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

## How To Modify This System Safely
When adding new interactable objects:
1. Implement the existing interaction contract
2. Put object-specific action generation on the target, not in `InteractionComponent`
3. Only change `CharacterController` if the input semantics themselves are changing

When changing prompt data:
1. Update producers such as `WorldItem` and `MountedItemInteractable`
2. Update `InteractionPromptData` if the field should be standardized
3. Update `UIRoot` so the field is actually surfaced to developers and players

## How To Test Interaction Changes
Validate:
1. Focus prompt appears on world items
2. Tap `F` still performs immediate pickup
3. Hold `F` opens quick actions without also triggering pickup
4. `Q` still opens quick actions
5. Mounted item actions still work after visual changes

## Safe Extension Path
- add new interactions by implementing the existing contract
- avoid adding target-type special cases to `InteractionComponent`
- put item-specific action logic near the item or the controller action router, not in the raycast component
