---
type: guardrails
status: active
owned_by: gameplay
updated: 2026-03-29
---

# 11 - Tone and Design Guardrails

## Summary
Project 2026 should feel grim, dystopic, and materially hostile. The tone should not live only in art direction or writing. It should emerge from systems that make the world feel depleted, unreliable, exposed, and full of uncomfortable tradeoffs.

This note exists to keep future gameplay work aligned with that identity while still respecting the current architecture.

## Core Tone Pillars
### Scarcity
Useful items should matter because they are limited, degraded, or difficult to replace.

Implications for systems:
- ammunition should feel finite
- treatment resources should be consumed deliberately
- storage space and carried weight should stay meaningful
- convenience should be expensive rather than assumed

### Exposure
The player should feel vulnerable in motion, in treatment, and during interaction with the world.

Implications for systems:
- healing should cost time or create temporary vulnerability
- scavenging and access actions should expose the player to risk or delay
- recovery should rarely be instant and frictionless

### Fragility
Bodies, gear, and plans should all be interruptible, degradable, and imperfect.

Implications for systems:
- wounds should have lingering consequences
- equipment should degrade or fail
- ammo, condition, and storage mistakes should create meaningful downstream problems

### Degraded Infrastructure
The world should feel worn down, improvised, and partially broken rather than clean and game-ready.

Implications for systems:
- stations should be limited, unreliable, or conditional
- access points should require effort, tools, or planning
- scavenging should feel like recovering value from decay, not collecting polished rewards

### Uncomfortable Tradeoffs
Good choices should often solve one problem by creating another.

Implications for systems:
- better preparedness should often cost weight, speed, or noise
- treatment should trade resources for stability, not erase consequences
- carrying more gear should improve options while increasing burden

## What To Avoid
Avoid feature directions that undermine the tone:
- power-fantasy pacing where the player escalates too quickly into dominance
- clean abundance of ammo, medicine, and safe storage
- frictionless healing or repair loops
- inventory behaviors that feel abstractly gamey instead of physical and constrained
- progression driven mainly by loot inflation instead of survival competence
- world interactions that feel like convenience menus instead of risky physical actions

## System-Level Guardrails
### Inventory and equipment
- physical storage should remain a source of tradeoff, not background bookkeeping
- visible equipment should communicate burden, readiness, and exposure
- adding slots should require a strong gameplay reason, not just content convenience

### Interaction
- interactions should reuse explicit action contracts
- world targets should create context-sensitive decisions, not generic use prompts only
- mounted gear, scavenging, treatment, and access points should feel like part of one interaction language

### Health and treatment
- treatment should stabilize, mitigate, or buy time before it fully restores
- wounds should have state, not just a flat health subtraction
- medical items should differ by role, cost, and context rather than all acting as simple healing buttons

### Weapons and gear
- weapon usefulness should depend on maintenance, condition, and ammo state
- tools and gear should feel serviceable, worn, and fallible
- upgrades should improve survivability or reliability more often than raw dominance

### Progression
- progression should come from improved planning, route knowledge, preparedness, and system mastery
- objective loops should reinforce survival pressure and access management
- stronger gear should widen options while preserving tension

## Feature Filter
Run future feature ideas through this checklist:
- does it increase tension instead of flattening it
- does it reinforce scarcity, fragility, exposure, or tradeoff
- does it fit the current ownership boundaries cleanly
- does it create meaningful decisions rather than passive stat growth
- can it be validated through repeatable gameplay and testing flows

If the answer is mostly no, the feature likely needs redesign before implementation.

## Architecture Guardrail
Tone should be implemented through systems that already have clear responsibilities:
- inventory owns storage truth and burden
- interaction owns targeting and action dispatch
- visuals communicate authoritative state
- UI reflects state and options without becoming gameplay authority

If a feature only works by bypassing those boundaries, it is probably solving the problem in the wrong layer.
