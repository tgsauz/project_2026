---
type: roadmap
status: active
owned_by: gameplay
updated: 2026-03-29
---

# 10 - Control Point Roadmap

## Summary
This note is the current control point for Project 2026 after the first full pass on movement, interaction, physical inventory, equipped visuals, smoke coverage, and onboarding docs.

The project now has enough structure to stop treating every next feature as isolated implementation work. From here forward, the priority should be to strengthen shared gameplay foundations so future content inherits scarcity, fragility, and consequence by default.

This roadmap is architecture-first on purpose:
- strengthen reusable contracts before feature breadth
- keep ownership boundaries explicit
- make grim survival pressure systemic instead of cosmetic

## Current Baseline
The current playable stack already provides:
- player movement, stamina, and load penalties
- raycast-driven interaction and prompt flow
- physical inventory with body slots and nested containers
- equipped item visuals for held and mounted items
- quick actions for item handling
- **serialization contract (save/load Dictionary model)**
- **ItemDefinitionRegistry (O(1) item lookup)**
- **Debug Inventory Inspector (real-time state viewer)**
- smoke-style regression coverage
- project docs grounded in the current codebase

This is a strong base, but several important areas are still intentionally hardcoded or early:
- slot definitions and anchor mapping
- item action generation (item-specific contexts)
- deep validation for scenario-based gameplay flows
- stack management and drag-and-drop UX

## Development Priorities
### Priority 1: Architecture stabilization and data contracts
Before adding broad new feature families, stabilize the contracts that multiple future systems will depend on.

Focus on:
- replacing hardcoded slot and anchor definitions with data-driven slot and anchor resources
- formalizing interaction actions so world targets, mounted gear, and future stations all expose actions through the same shape
- defining item-family behavior hooks for medical, weapon, ammo, container, and utility items
- defining a save snapshot contract for player state, item instances, nested containers, equipped items, and world placements
- preserving the current ownership boundary where inventory owns storage truth, interaction owns targeting, visuals reflect inventory, and UI consumes signals

Success criteria:
- adding a new visible equipment slot no longer requires scattered hardcoded edits
- adding a new action-capable world target reuses the same interaction-action contract
- runtime item state has a documented serialization shape before save/load implementation begins
- `CharacterController` remains a coordinator rather than becoming the authority for storage, actions, or visuals

### Priority 2: Survival pressure systems
Once the contracts are stable, layer in the systems that make the setting feel harsh, constrained, and costly to survive in.

Focus on:
- a health and condition layer with wounds, bleeding, pain, and treatment state
- item condition and maintenance for weapons, tools, and worn gear
- ammunition and reload state as runtime state rather than item presence only
- **full save/load implementation for player inventory and world item state using new serialization logic**

Design intent:
- treatment should consume time, attention, and finite resources
- degraded equipment should create reliability pressure
- ammunition should become a planning problem, not just a content tag
- persistence should make long-term consequences testable and meaningful

Success criteria:
- bandages and medical items have real gameplay value beyond placeholder inventory use
- a weapon can carry runtime state such as ammo count and condition without leaking that logic into inventory ownership
- quitting and reloading preserves player-carried state and world item state consistently
- smoke and manual tests can exercise treatment, reload, stow, drop, and restore flows as one scenario

### Priority 3: World-facing progression loop
After survival pressure systems exist, use them to build a repeatable loop that gives the player reasons to engage with the world.

Focus on:
- scavenging containers and searchable world props
- locked access points and limited-use world stations
- lightweight objective or progression loops driven by shortages, routing, and access gating

Design intent:
- the world should feel degraded, obstructed, and expensive to move through
- interaction should create risk and tradeoff, not just item pickup convenience
- objectives should reward survival competence, not power-fantasy escalation

Success criteria:
- the player can complete a short survival-oriented loop using scavenging, treatment, equipment management, and access gating
- world interactions reuse the same core interaction architecture rather than bypassing it
- the test world can host a repeatable end-to-end scenario instead of isolated system checks only

## Features To Prioritize Next
These features strengthen the base most directly:
- health, wounds, bleeding, pain, and treatment state
- runtime item condition and maintenance
- ammo and reload state
- persistence and save/load
- scavenging containers, locked access points, and limited-use stations
- a lightweight objective loop for repeatable testing and tuning

## Features To Defer
These are not rejected, but they should wait until the base is more stable:
- full combat depth and enemy variety
- large narrative tooling
- broad crafting trees
- many more attachment slots before slot and anchor data becomes more data-driven

## Development, Testing, and Maintenance Work
To make implementation safer and faster, prioritize:
- expanding smoke coverage into scenario-style tests for pickup, swap, stow, treatment, reload, save/load, and interaction regressions
- creating stable debug workflows such as item spawning shortcuts, force-load states, visual anchor toggles, inventory dumps, and target inspection
- adding content validation guidance for new item resources and attachment profiles
- keeping docs opinionated about ownership boundaries so future changes do not collapse into controller-centric logic

## Control Point Rules
Use this note as a check before starting medium or large feature work.

A proposed feature should answer:
- which existing system owns the new behavior
- whether it needs a new contract or can extend an existing one
- how it reinforces scarcity, fragility, or tradeoff
- how it will be validated in smoke tests, debug workflows, or a repeatable world scenario

If a feature cannot answer those questions clearly, it likely needs more design work before implementation.
