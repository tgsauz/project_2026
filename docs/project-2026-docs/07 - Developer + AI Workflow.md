---
type: workflow
status: active
owned_by: gameplay
updated: 2026-03-26
---

# 07 - Developer + AI Workflow

## Summary
This project benefits most when developers and AI work from the same architectural constraints. The goal is not just to make code compile, but to keep systems modular, scalable, and safe to extend.

## Working Rules
- Analyze before implementing
- Prefer small scoped changes
- Preserve ownership boundaries
- Avoid hidden coupling
- Do not bypass system APIs just because a direct scene hack is faster

## How To Use These Docs During Feature Work
1. Read the relevant system note
2. Identify the ownership boundary of the change
3. Confirm the intended extension point
4. Implement through that extension point
5. Update the docs if the architecture meaningfully changes

## AI-Specific Guidance
- Treat these notes as implementation constraints, not just prose
- Prefer documented APIs over ad-hoc scene traversal
- Call out hardcoded limitations explicitly when proposing changes
- Separate “current behavior” from “future refactor suggestion”
- Avoid making UI the authority for gameplay state

## Developer-Specific Guidance
- When adding content, prefer new definitions/resources over new hardcoded branches
- When adding new slots or visual anchors, update both logic and documentation together
- If a feature repeats patterns, consider a data-driven abstraction before adding more branches

## Safe Change Pattern
- static authored data in definitions/resources
- runtime mutable state in instances/components
- interactions through explicit contracts
- visuals driven by authoritative state
- UI as a consumer, not a state owner

## When To Refactor
Refactor when:
- new slots require repeated hardcoded edits in multiple places
- action generation differs significantly across item families
- placeholder visuals need per-item authored scenes
- save/load or multiplayer requirements demand stricter state structures

Do not refactor when:
- a local change can be handled cleanly inside current ownership boundaries
- the new abstraction would only be used once

## Documentation Maintenance Rule
If a feature changes:
- public APIs
- slot definitions
- interaction contracts
- visual attachment flow

then the matching note in this vault should be updated in the same work cycle.
