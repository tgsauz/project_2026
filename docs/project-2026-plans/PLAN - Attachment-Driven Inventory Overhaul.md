---
type: plan
status: active
owned_by: gameplay
updated: 2026-04-03
plan_syntax: dedicated_plan_doc
---

# Attachment-Driven Inventory Overhaul

## Intent
Replace the flat slot-plus-container inventory model with a graph-driven attachment system where:
- every character has a default authored body layout
- equipped clothing/equipment can contribute additional attachment nodes
- storage capacity is handled separately from attachment compatibility
- runtime inventory remains the sole authority for carried state

## Key Design Points
- Default body nodes stay compatible with current roots where possible: `left_hand`, `right_hand`, `torso`, `belt`, `back_mount`, `shoulder_mount`
- Equipment-contributed nodes are authored as data modifiers, not scene-owned gameplay nodes
- Storage uses 1D capacity units only in this phase
- Dynamic nodes must remain consumable by visuals, UI, smoke tests, and tuner
- Compatibility wrappers stay in place until all current callers can move to node-based APIs

## Implementation Track
1. Add authored resources for attachment points, layouts, and equipment modifiers.
2. Introduce runtime attachment graph types.
3. Migrate `InventoryComponent` to own graph state, node occupancy, and size-based storage rules.
4. Keep legacy APIs working through compatibility wrappers.
5. Add at least one belt modifier, one vest modifier, one pouch storage flow, and one backpack storage flow.
6. Update visuals, UI, debug UI, tuner, tests, and docs to consume active attachment nodes.

## Guardrails
- Inventory owns truth; visuals/UI/tuner only consume emitted state.
- No 2D grid inventory in this pass.
- No save-breaking rename of current root node ids in this pass.
- Dynamic node definitions must remain data-driven and reusable.
