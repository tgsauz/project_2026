# Project 2026 - Master TODO Checklist

This document tracks the implementation status of all major gameplay systems and technical foundations.

## [x] Physical Inventory System (Phase 1-5)
- [x] ItemDefinition / ItemInstance architecture
- [x] Slot-based occupancy with nested container support
- [x] Weight and load factor calculation
- [x] World pickup with auto-stow logic
- [x] `ItemDefinitionRegistry` (static lookup)
- [x] Serialization (Save/Load Dictionary support)

## [x] Diegetic Inventory UI
- [x] Independent Inventory Camera (Orbit View)
- [x] Accordion Sidebar with dynamic leader lines
- [x] Slot status indicators (Inline item names)
- [x] Item Tooltips (Hover details)
- [x] 3D Item Inspection Viewport
- [x] Category filtering (Hotkey 1-4)
- [x] Debug Inventory Inspector (Raw state table)

## [/] Movement & Interaction
- [x] Advanced Player Controller (Stamina, Acceleration)
- [x] Interaction System (Raycast, Prompt, Global Focus)
- [x] Crosshair UI (Dynamic states, Dot modes)
- [ ] Jump/Crouch integration with stamina
- [ ] Vaulting / Mantling system

## [ ] Survival Systems (Priority Next)
- [ ] Health, Wounds, and Pain state
- [ ] Medical Item usage (Treatment time & animations)
- [ ] Weapon firing and reload state (Ammunition tracking)
- [ ] Item condition and durability
- [ ] Maintenance & Repair flow

## [ ] World & Scavenging
- [ ] Searchable loot containers
- [ ] Locked doors and access gating
- [ ] Scavenging "Stations" (e.g., workbench, medical station)
- [ ] Persistence of world item drops across save/load

## [x] Tools & Utilities
- [x] Character Visuals Tuner (Phase 1-2)
    - [x] Standalone preview scene
    - [x] Orbit camera & Inspection controls
    - [x] Real-time transform sliders
    - [x] Locomotion & Clipping preview
    - [x] Runtime Resource Saving support

## [ ] Technical Debt & Refactoring
- [ ] Move hardcoded slot definitions to Data-Driven Resources
- [ ] Implement Drag-and-Drop for accordion item movement
- [ ] Stack Split/Merge UI
- [ ] Scenario-based Smoke Tests for complex loops
- [ ] Full Godot 4.6 Feature Audit (Rendering/Physics)
