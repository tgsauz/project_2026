# Graph Report - project-2026  (2026-06-25)

## Corpus Check
- 21 files · ~52,426 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 599 nodes · 580 edges · 41 communities (39 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `ee8d6134`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]

## God Nodes (most connected - your core abstractions)
1. `03 - Inventory and Item System` - 19 edges
2. `IK Refactor - Implementation Tracking` - 19 edges
3. `05 - Player, Visuals, and Attachment Points` - 17 edges
4. `04 - Interaction System` - 15 edges
5. `09 - How To Add New Attachment Points` - 13 edges
6. `19 - AI Agent Handbook` - 13 edges
7. `🧠 Project 2026 — AI Agent Engineering Guidelines` - 12 edges
8. `06 - Testing and Debugging` - 12 edges
9. `08 - How To Add New Items` - 12 edges
10. `Project 2026 - Master TODO Checklist` - 12 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (41 total, 2 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.06
Nodes (33): 19 - AI Agent Handbook, 🤖 AI Agent Behavior Rules, Analysis-Only Requests, Approved Fix Plan — ACTIVE, 🏗️ Architecture — Non-Negotiable Rules, Change Checklist (all required before implementation), code:block1 (Player/Scripts/), code:gdscript (target_yaw = atan2(-intent_direction.x, -intent_direction.z)) (+25 more)

### Community 1 - "Community 1"
Cohesion: 0.06
Nodes (32): Architecture, code:block1 (File: Player/Scripts/PelvisAdjuster.gd), code:block10 ([ext_resource type="Script" path="res://Player/Scripts/FullB), code:block11 ([node name="FullBodyIKController" type="Node" parent="."]), code:gdscript (var aim_direction: Vector3 = Vector3.FORWARD), code:gdscript (func _update_aim_direction() -> void:), code:gdscript (func _process(delta: float):), code:gdscript (var rig := visuals.get_node_or_null("Rig") as Node3D) (+24 more)

### Community 2 - "Community 2"
Cohesion: 0.06
Nodes (31): 12 - How To Modify UI, 1.1 Inventory UI Dependency Rule, 1.2 Current Inventory UI Shape, 1. UI Architecture Overview, 2. Customizing Existing Appearance, 3. Creating a New UI Component, 4. Registering Your Component with UIRoot, 5. UI Fade Animation System (+23 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (30): 03 - Inventory and Item System, Attachment Graph Model, Categories, Containers, Core Types, Current Limitations, Debug Inventory Inspector, Equipment Visual Payload (+22 more)

### Community 4 - "Community 4"
Cohesion: 0.09
Nodes (28): A. Bone-Pose-Based Target Computation (not node transform reads), A. Bone Pose Is Fresh; BoneAttachment Markers May Lag, Architecture, Architecture Change, B. Per-Tick Marker Offset Computation, B. Signal-Based Marker Recache, C. Delta=0 Guard, C. Grip Markers Are Current Contract (+20 more)

### Community 5 - "Community 5"
Cohesion: 0.09
Nodes (21): code:block1 (root (0)), code:gdscript (var aim_local := _character_controller.global_transform.basi), code:gdscript (var spine_current := _skeleton.get_bone_global_pose(_spine_0), code:gdscript (var pitch_rot := Basis(Vector3.RIGHT, pitch)), code:block5 (_cache_weapon_marker_offsets()         ← step 1: grip offset), code:powershell (git checkout -- Player/Scripts/FullBodyIKController.gd), Combined application, Design: Dual-Source Rotation (+13 more)

### Community 6 - "Community 6"
Cohesion: 0.1
Nodes (20): 04 - Interaction System, Current Limitations, How To Modify This System Safely, How To Test Interaction Changes, Implementation, Interaction Contract, Main Script, MountedItemInteractable Responsibilities (+12 more)

### Community 7 - "Community 7"
Cohesion: 0.1
Nodes (20): 05 - Player, Visuals, and Attachment Points, Attachment Profiles and Scene Offsets, CharacterController Responsibilities, Clothing and Skinned Meshes, Current Attachment Support, Current Limitations, FPS Visibility Rule, Future Refactor Targets (+12 more)

### Community 8 - "Community 8"
Cohesion: 0.1
Nodes (20): 18 - Hybrid Weapon Aiming Architecture, 🏗️ Architectural Rules, Cleanup Notice (2026-05-30), code:gdscript (Weapon_Desired_Basis = look_at(Crosshair)), Current State (2026-05-09), Future Architecture: Hybrid ADS Corrector, 🛠️ Implementation Plan (TODO), Overview (+12 more)

### Community 9 - "Community 9"
Cohesion: 0.1
Nodes (19): 14 - UI + Inventory System Branch Refactor Plan, Acceptance Criteria, Architecture Direction, Current Branch Gaps, Execution Order, Follow-Up After This Plan Is Implemented, Implementation Phases, Non-Goals For This Pass (+11 more)

### Community 10 - "Community 10"
Cohesion: 0.11
Nodes (18): AI Agent Behavior, APPENDIX: Reference & Checklists, Architecture Constraints, Before You Code (Decision Tree), Code Style, code:gdscript (# ==========================================================), Core Facts, Definition of Done (AI Changes) (+10 more)

### Community 11 - "Community 11"
Cohesion: 0.11
Nodes (18): 08 - How To Add New Items, Ammo, Category Guidance, Checklist: Add A Hand-Held Item, Checklist: Add A New Item Category Instance, Checklist: Add A New Item Definition, Checklist: Add A Physical Container, Checklist: Add Equipped Visual Authoring (+10 more)

### Community 12 - "Community 12"
Cohesion: 0.11
Nodes (17): 11 - Tone and Design Guardrails, Architecture Guardrail, Core Tone Pillars, Degraded Infrastructure, Exposure, Feature Filter, Fragility, Health and treatment (+9 more)

### Community 13 - "Community 13"
Cohesion: 0.11
Nodes (17): Advantages Over Current Approach, code:block1 (final_pose = q_pitch * q_twist * q_tilt), code:block2 (var q_pitch = Quaternion.from_euler(Vector3(pitch_component,), code:block3 (var camera_pitch = _aim_controller.camera_controller.fps_pit), code:block4 (var aim_dir_xz = Vector3(aim_dir.x, 0.0, aim_dir.z).normaliz), Component Sources, Implementation Status, Influence Per State (+9 more)

### Community 14 - "Community 14"
Cohesion: 0.12
Nodes (16): 06 - Testing and Debugging, Current Testing Gaps Worth Filling Later, Debug UI, Debugging Rules, Interpreting The Output, Left-Hand IK Diagnostics, Live Handle Tuning Pass, Recommended Manual Test Pass For Equipment Changes (+8 more)

### Community 15 - "Community 15"
Cohesion: 0.12
Nodes (16): 09 - How To Add New Attachment Points, Current Implemented Anchors, Current Limitations, Example: Add A Shoulder Radio Slot, Future Refactor Target, How To Test A New Attachment Point, Inventory, Item definition (+8 more)

### Community 16 - "Community 16"
Cohesion: 0.13
Nodes (14): 01 - Architecture Overview, Architectural Priorities, CharacterController, Current Hardcoded Areas, Current High-Level Gameplay Stack, Design Pattern: Definition vs Runtime Instance, Extension Principles, InteractionComponent (+6 more)

### Community 17 - "Community 17"
Cohesion: 0.13
Nodes (14): 16 - Weapon Stance and Procedural Aiming Refactor, 5. Calibration Tools (Noclip & Stance Lock), Archived — Superseded (2026-05-30), 🧠 Brainstormed Solution, Calibration Tools (Preserved), code:gdscript (# CharacterController.gd), Core Rules & Constraints, Current Architecture (replaces this doc) (+6 more)

### Community 18 - "Community 18"
Cohesion: 0.13
Nodes (14): 1. Pre-capture raw parent bases (Approach A), 2. Strip Y-twist from similarity reference frame (Approach B), code:gdscript (var parent_global: Basis = _skeleton.get_bone_global_pose(pa), code:gdscript (var pitch_local: Quaternion = combined_q.inverse() * pitch_q), code:gdscript (var combined_euler: Vector3 = combined.get_euler()), Implemented Fix (Approach A+B Combined), Phase XI — SpineController Similarity Transform: Pitch Axis Orthogonality Fix, Priority (+6 more)

### Community 19 - "Community 19"
Cohesion: 0.14
Nodes (13): 17 - Engine Coordinate Standards & IK Alignment, 1. Sight Markers (Preferred), 1b. The "MUZZLE" Node (Recommended), 1c. The "ADS_UP" Node (Recommended), 2. The Root -Z Fallback (Standard), Character Controller & Input, code:gdscript (target_yaw = atan2(-intent_direction.x, -intent_direction.z)), Core Architecture Decision: The Godot Standard (-Z Forward) (+5 more)

### Community 20 - "Community 20"
Cohesion: 0.14
Nodes (13): 01 - Weapon Orientation Fix, code:block1 (BoneAttachment3D each frame  = anim_pose × rest_pose), Decision, Diagnostic tool added, Fix Paths (Phase 2), How to run the diagnostic, Linked Documents, Output interpretation (+5 more)

### Community 21 - "Community 21"
Cohesion: 0.15
Nodes (12): 00 - Start Here, AI-assisted implementation, Audience, Current State, Documentation Rules, Gameplay feature work, How To Use This Vault, New developer (+4 more)

### Community 22 - "Community 22"
Cohesion: 0.15
Nodes (12): 02 - Game Systems Overview, CharacterController, Current Player Data Flow, InteractionComponent, InventoryComponent, Main Runtime Pieces, Notes To Read Next, Player root (+4 more)

### Community 23 - "Community 23"
Cohesion: 0.15
Nodes (12): 20 - Debug Diagnostics, Adding a New Debug Action, IK — `debug_ik_reach` (J, `FullBodyIKController`), IK — `debug_sight_detail` (I, `WeaponPositionController`), IK — `debug_sight_screen` (L, `WeaponPositionController`), IK — `debug_weapon_pose` (K, `WeaponPositionController`), Keybind Reference, Other — `debug_ik` (F4, `CharacterController`) (+4 more)

### Community 24 - "Community 24"
Cohesion: 0.15
Nodes (12): [/] Movement & Interaction, [ ] Pitch Inversion, Project 2026 - Master TODO Checklist, [ ] Survival Systems (Priority Next), [ ] Technical Debt & Refactoring, [/] Weapon Orientation Fix, [ ] World & Scavenging, [x] Diegetic Inventory UI (+4 more)

### Community 25 - "Community 25"
Cohesion: 0.17
Nodes (11): 10 - Control Point Roadmap, Control Point Rules, Current Baseline, Development Priorities, Development, Testing, and Maintenance Work, Features To Defer, Features To Prioritize Next, Priority 1: Architecture stabilization and data contracts (+3 more)

### Community 26 - "Community 26"
Cohesion: 0.17
Nodes (11): 13 - Character Visuals Tuner Guide, Best Practices for Alignment, Copy and paste a transform, Core Workflow, Examples, Location, Mirror a hand-held transform, Rescan item definitions (+3 more)

### Community 27 - "Community 27"
Cohesion: 0.18
Nodes (11): code:powershell (git checkout -- Player/Scripts/FullBodyIKController.gd Playe), Current Status (2026-06-03), Current Status (2026-06-04), Current Status (2026-06-10), Error Log, IK Refactor - Implementation Tracking, Phase I-III Notes, Phase I: Rewrite as SkeletonModifier3D (+3 more)

### Community 28 - "Community 28"
Cohesion: 0.18
Nodes (10): 15 - Aiming and Weapon States, AnimationTree Contract, Character Tuner Support, First-Person Visibility Rule, Input Contract, Movement and Rotation, Ownership, Runtime Rules (+2 more)

### Community 29 - "Community 29"
Cohesion: 0.2
Nodes (9): 07 - Developer + AI Workflow, AI-Specific Guidance, Developer-Specific Guidance, Documentation Maintenance Rule, How To Use These Docs During Feature Work, Safe Change Pattern, Summary, When To Refactor (+1 more)

### Community 30 - "Community 30"
Cohesion: 0.25
Nodes (8): code:text (WeaponOffsetCache          # captures spine_02⁻¹ * ik_hand_g), code:text (InventoryComponent), Confirmed Architecture, Error Log, NodePath Resolution Map, Phase III: Scene Changes, Processing Order, TODO

### Community 31 - "Community 31"
Cohesion: 0.29
Nodes (7): Approach, Data Flow, Error Log, Files Changed, Phase VIII: Hand Grip Rotation Corrector, Problem, TODO

### Community 32 - "Community 32"
Cohesion: 0.4
Nodes (5): Phase VIII: Hand Grip Fixes, v1-v2: Superseded, v3: Recompute marker offsets per tick, v3 Validation (Current State), v4: Cleanup (Done)

### Community 33 - "Community 33"
Cohesion: 0.4
Nodes (5): Diagnostic Findings, Error Log, Phase VI: Runtime Validation, TODO, Weight Tuning Notes

### Community 34 - "Community 34"
Cohesion: 0.5
Nodes (4): Approach, Phase VII: IK as Corrective Layer, Problem, TODO

### Community 35 - "Community 35"
Cohesion: 0.67
Nodes (3): Phase X — SpineController (deleted 2026-06-12), Phase XI — SpineController Pitch Orthogonality Fix (deleted 2026-06-12), Superseded Phases

### Community 36 - "Community 36"
Cohesion: 0.67
Nodes (3): Error Log, Phase IV: Debug Visualizer Fixes, TODO

### Community 37 - "Community 37"
Cohesion: 0.67
Nodes (3): Error Log, Phase II: Signal-Based Marker Caching, TODO

### Community 38 - "Community 38"
Cohesion: 0.67
Nodes (3): Error Log, Phase V: Test Updates, TODO

## Knowledge Gaps
- **423 isolated node(s):** `📌 TECH STACK: Godot 4.6.1 · GDScript · CharacterBody3D + CameraController + InteractionComponent`, `Core Facts`, `Must-Know Principles`, `Dependency Resolution (Priority Order)`, `Architecture Constraints` (+418 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `IK Refactor - Implementation Tracking` connect `Community 27` to `Community 32`, `Community 33`, `Community 34`, `Community 35`, `Community 36`, `Community 37`, `Community 38`, `Community 30`, `Community 31`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `📌 TECH STACK: Godot 4.6.1 · GDScript · CharacterBody3D + CameraController + InteractionComponent`, `Core Facts`, `Must-Know Principles` to the rest of the system?**
  _423 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.06 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.09 - nodes in this community are weakly interconnected._