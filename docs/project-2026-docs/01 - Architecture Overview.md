---
type: overview
status: active
owned_by: gameplay
updated: 2026-04-03
---

# 01 - Architecture Overview

## Summary
Project 2026 is a Godot 4.6 game that should be built with scalability, modularity, efficiency, and robustness in mind. Systems should prefer explicit ownership and predictable data flow over hidden coupling or scene-tree guesswork.

## Architectural Priorities
- Scalability over quick hacks
- Modularity over tightly coupled scene logic
- Deterministic ownership over global discovery
- Local changes over broad unrelated refactors
- Long-term maintainability over short-term convenience

## Current High-Level Gameplay Stack
- `CharacterController` owns player movement, quick actions, and high-level coordination.
- `InventoryComponent` owns physical storage state and weight/load data.
- `InteractionComponent` owns raycast-based focus and interaction dispatch.
- `VisualsComponent` owns body tilt and inventory-driven attachment visuals.
- `UIRoot` is a thin view layer for prompts, inventory overlays, and quick actions.
- `EquipmentSlotCatalog` is the shared data contract for gameplay slot metadata and visual anchors.

See also: [[02 - Game Systems Overview]]

## Ownership Boundaries
### CharacterController
- Coordinates player-facing actions
- Should not become the storage authority for item graphs
- Should not own item rendering decisions directly

### InventoryComponent
- Owns slots, contained items, total weight, and visible equipment queries
- Is the authority for where items are stored
- Should stay focused on storage rules, not weapon firing, medical use, or UI details

### InteractionComponent
- Owns target acquisition and interaction calls
- Works through interface-style methods such as `interact(actor)` and prompt/action accessors
- Should not hardcode behavior for specific item categories

### VisualsComponent
- Owns visual attachment anchors and placeholder mounted visuals
- Reacts to inventory state rather than manually mirroring gameplay decisions

### UI
- Reflects current prompt and quick action state
- Should remain a consumer of gameplay signals, not an authority on item logic

## Design Pattern: Definition vs Runtime Instance
- `ItemDefinition` is static design-time data.
- `ItemInstance` is runtime state for a specific carried or world item.

This split is one of the most important architectural decisions in the current item system because it allows many instances to share the same authored data while keeping per-instance state isolated.

See also: [[03 - Inventory and Item System]]

## Current Hardcoded Areas
- Large inventory UI creation still starts in `UIRoot`
- Quick action list generation is still simple and generic
- Placeholder visuals are shape/color driven rather than asset-driven

## Extension Principles
- Add new behavior by layering on top of current responsibilities, not by collapsing everything into the controller
- Keep storage concerns in inventory
- Keep action dispatch in interactables/controllers
- Keep representation concerns in visuals/UI
- Prefer data-driven definitions when a feature starts repeating patterns

## Shared Slot Truth
Gameplay equipment slots now come from a shared resource catalog rather than separate hardcoded lists.

Current shared pieces:
- `EquipmentSlotDefinition`
- `EquipmentSlotCatalog`
- `EquipmentSlotLibrary`

This catalog is consumed by:
- `InventoryComponent` for slot names, display names, accepted categories, and visible flags
- `VisualsComponent` for attachment roots and debug colors
- `CharacterTuner` for tunable slot discovery
- smoke coverage and item validation
