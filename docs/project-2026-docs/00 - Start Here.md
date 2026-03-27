---
type: moc
status: active
owned_by: gameplay
updated: 2026-03-26
---

# 00 - Start Here

## Purpose
This vault explains how Project 2026 is structured today so developers and AI agents can extend it without guessing. It is intentionally implementation-oriented and should stay aligned with the real codebase.

## Audience
- Developers onboarding to the project
- Contributors adding gameplay features
- AI agents that need grounded architectural context

## How To Use This Vault
- Start with [[01 - Architecture Overview]] for project principles and ownership boundaries.
- Read [[02 - Game Systems Overview]] for the current gameplay stack.
- Go to the specific system note you are changing.
- Use the extension guides before adding new items, slots, or attachment points.

## Vault Map
- [[01 - Architecture Overview]]
- [[02 - Game Systems Overview]]
- [[03 - Inventory and Item System]]
- [[04 - Interaction System]]
- [[05 - Player, Visuals, and Attachment Points]]
- [[06 - Testing and Debugging]]
- [[07 - Developer + AI Workflow]]
- [[08 - How To Add New Items]]
- [[09 - How To Add New Attachment Points]]

## Recommended Reading Paths
### New developer
1. [[01 - Architecture Overview]]
2. [[02 - Game Systems Overview]]
3. [[06 - Testing and Debugging]]
4. System-specific notes as needed

### Gameplay feature work
1. [[03 - Inventory and Item System]]
2. [[04 - Interaction System]]
3. [[05 - Player, Visuals, and Attachment Points]]

### AI-assisted implementation
1. [[07 - Developer + AI Workflow]]
2. Relevant system note
3. Relevant extension guide

## Documentation Rules
- Prefer documenting current behavior, not aspirational behavior.
- Call out hardcoded areas and limitations directly.
- Keep extension guidance decision-complete where practical.
- Update notes when architecture meaningfully changes.

## Current State
The most detailed system currently documented is the physical inventory and item interaction architecture. Some parts are intentionally placeholder or hardcoded, especially body slot definitions, attachment anchor lookup, and quick action behaviors.
