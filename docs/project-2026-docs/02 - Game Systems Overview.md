---
type: overview
status: active
owned_by: gameplay
updated: 2026-03-26
---

# 02 - Game Systems Overview

## Summary
The current playable stack is centered on a modular player character with movement, interaction, physical inventory, debug UI, and inventory-driven placeholder visuals.

## Main Runtime Pieces
### Player root
- Scene: `Player/PlayerCharacter.tscn`
- Root script: `Player/Scripts/CharacterController.gd`
- Child gameplay components include `InventoryComponent`, `InteractionComponent`, and `Visuals`

### CharacterController
- Handles movement, sprinting, load penalties, and quick action input
- Resolves component dependencies in one place
- Routes physical item actions like drop, stow, and move-to-hand

### InventoryComponent
- Stores physical items on body slots and within containers
- Recalculates total weight and load factor
- Emits visual-state updates for mounted items

### InteractionComponent
- Performs a raycast from the active camera
- Identifies a focus target
- Pulls prompt data from the target
- Calls `interact(actor)` when the player interacts

### VisualsComponent
- Applies upper-body tilt based on movement acceleration
- Creates placeholder attachment visuals for visible equipped items
- Creates mounted interactable areas for visible mounted gear

### UIRoot
- Central orchestrator for all gameplay UI components
- Shows focus prompt text, quick action menu entries
- Applies dynamic styling via `UIStyleProfile` resource
- Supports **UI fade animations** (fade-in on value change, fade-out after stability threshold)
- Manages **responsive layout** (4 breakpoints: mobile/tablet/desktop/ultrawide with dynamic margin scaling)
- Displays **diegetic bounding box highlighting** for focused interactables (3D→2D projection, tier-gated)
- Keeps debug UI separate from core gameplay logic

## Current Player Data Flow
1. The player looks at a target.
2. `InteractionComponent` resolves prompt data from that target.
3. `UIRoot` displays prompt information.
4. On interaction, the target processes the action.
5. If an item moves into or out of inventory, `InventoryComponent` recalculates weight and visible equipment.
6. `VisualsComponent` updates mounted placeholder visuals from inventory state.

## Why This Matters
This architecture already supports several future-friendly behaviors:
- ground pickups
- body-mounted gear
- nested containers
- load-based movement penalties
- interaction-driven quick actions

The system is still early, but its boundaries are useful enough that future features should build through them rather than bypass them.

## Notes To Read Next
- [[03 - Inventory and Item System]]
- [[04 - Interaction System]]
- [[05 - Player, Visuals, and Attachment Points]]
