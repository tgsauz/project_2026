---
type: ai-context
status: active
owned_by: gameplay
updated: 2026-04-30
---

# 19 - AI Agent Handbook

> This document is the **single source of truth for AI agents** (Antigravity, CODEX, and any future tools) working on Project 2026.
> It merges the old `07 - Developer + AI Workflow` and adds current project state, architecture constraints, and tool-specific guidance.
> Update this file at the end of every major work session.

---

## 🧠 What You Must Know First

### Game Identity
Project 2026 is a **grim, dystopic, single-player-to-multiplayer survival game** built in **Godot 4.6** using **GDScript**.

Tone keywords: **Scarcity · Exposure · Fragility · Consequence · Uncomfortable tradeoffs.**
No power-fantasy escalation. Realistic, physical, deliberate gameplay. Think Tarkov/Insurgency, not Call of Duty.

### Engine / Language Rules
- Language: **GDScript only**. No C#, no plugins unless already in the project.
- Coordinate system: **-Z forward** (strictly enforced — see Doc 17).
- Godot version: **4.6.1** (editor) / **4.6** (project target). Use Godot 4.x APIs, not 3.x.
- Prefer `SkeletonModifier3D` over deprecated `SkeletonIK3D`.

---

## 🏗️ Architecture — Non-Negotiable Rules

### Ownership Boundaries
| System | Owns | Does NOT Own |
|---|---|---|
| `CharacterController` | Input, movement, stance, animation state, quick actions | Item logic, slot rules, visual decisions |
| `InventoryComponent` | Storage truth, weight, equipped queries | Rendering, UI, weapon firing |
| `InteractionComponent` | Raycast focus, interaction dispatch | Item-specific behavior |
| `VisualsComponent` | Attachment roots, equipped visuals, IK registry, head suppression | Storage decisions |
| `UIRoot` | Displays signals | Never holds gameplay state |

### Dependency Resolution Priority (ALWAYS in this order)
1. Explicit injection (preferred)
2. Exported `NodePath` (composition root)
3. Local parent traversal (bounded)
4. Group lookup (last resort only — must degrade gracefully)

### Critical Constraints
- ❌ Never assume fixed scene tree depth
- ❌ Never hardcode cross-boundary paths without justification
- ❌ Never scan the tree every frame — cache references, re-resolve on invalidation
- ✅ Treat packed sub-scenes as reusable modules
- ✅ All signal payloads must be serializable (multiplayer-minded)
- ✅ Use explicit static types everywhere; treat "inferred from Variant" warnings as design bugs

### Multiplayer Mindset
**Multiplayer is not implemented yet, but every design decision must remain sync-ready.**
- Gameplay state (stance, health, inventory) → must be syncable via enums/flags
- Visual-only state (camera displacement, IK weight) → local only, no sync needed
- Bone scaling for visibility → **do not use** (sync-unsafe). Use camera layer culling instead.

---

## 📁 Key Files & Their Roles

```
Player/Scripts/
├── CharacterController.gd      # Movement, stance, animation state, input coordinator
├── CameraController.gd         # FPS/TPS look, camera mode switching, debug fly
├── VisualsComponent.gd         # Attachment roots, equipped visuals, IK registry, head suppression
├── FullBodyIKController.gd     # IK orchestrator — computes targets + modifier weights
├── WeaponOffsetCache.gd        # Caches spine_02⁻¹ * ik_hand_gun before spine correction
├── WeaponPositionController.gd # Repositions ik_hand_gun from cached offset + corrected spine
├── SpineLookAtController.gd    # Per-axis constrained spine IK (replaced SpineController)

├── DebugIKVisualizer.gd        # IK modifier/target visualization
```

### Weapon Scene Convention (per Doc 17)
Every weapon equipped scene must have:
- `RGRIP` — right-hand grip marker (IK target)
- `LGRIP` — left-hand grip marker (LeftHandIK target)
- `SIGHT_BACK` — rear sight anchor used to place the weapon against the eye line
- `SIGHT_FRONT` — front sight anchor used to define the sight line
- `MUZZLE` — barrel exit marker used for bore-axis diagnostics and firing authority

---

## 🎯 Current ADS System State (as of 2026-04-30)

### What Is Working
- ✅ `CombatStance` enum: `LOWERED`, `COMBAT`, `ADS` (in `CharacterController`)
- ✅ Right-hand ADS corrector resolves `SIGHT` and optional `MUZZLE`
- ✅ Right-hand IK now applies a bounded ADS correction against the camera ray
- ✅ Left Hand IK: ON in COMBAT and ADS
- ✅ Camera displacement and right-hand correction both use explicit weapon markers
- ✅ Camera layer convention established (Track C of ADS plan)

### Known Bugs (as of 2026-04-30) — CONFIRMED
- ❌ **Entire weapon (stock to sight) can still phase through head in ADS** — camera displacement still operates while the new right-hand corrector is active, so final camera-vs-weapon balance must be validated per weapon
- ❌ **Per-weapon marker authoring remains critical** — incorrect `SIGHT`, `MUZZLE`, or mesh forward authoring will still produce visible cant or bore drift
- ❌ **ADS target drifts from eye when animations play** — FPSPIVOT is floating (not bone-attached), does not follow the `head` bone
- ❌ **Camera-to-head anchoring still pending** — body visibility now uses render layers, but the FPS camera pivot is still not derived from a head-bone-backed eye anchor

### Approved Fix Plan — ACTIVE
Remaining tracks after current ADS corrector:
- **Track A**: Camera displacement toward head-bone-derived virtual eye during ADS
- **Track B**: Right-hand micro-corrector tuning and per-weapon validation (`ads_corrector_max_delta = 0.25` initially)
- **Track C**: Layer-based head culling validation and camera mask verification

**Current implementation status:** Track B now has an initial live ADS corrector, but Track A camera-to-head anchoring still needs follow-up validation and iteration.

---

## 📐 Coordinate & Math Rules

| Axis | Direction | Notes |
|---|---|---|
| Forward | -Z | `Basis.looking_at` targets -Z |
| Right | +X | Positive X = right of character |
| Up | +Y | Standard Godot Y-up |

**Yaw formula (fixes moonwalk bug):**
```gdscript
target_yaw = atan2(-intent_direction.x, -intent_direction.z)
```

**Weapon alignment formula (Doc 17 "Golden Formula"):**
```gdscript
weapon_desired_basis = Basis.looking_at(crosshair_direction, up)
hand_desired_basis = weapon_desired_basis * handle_local_rotation
```

---

## 🛠️ Debug Tools Available

| Tool | How to Activate | Purpose |
|---|---|---|---|
| **F1 — Free Cam (Noclip)** | Press F1 in-game | Detach camera, fly around character |
| **F2 — X-Ray** | Press F2 in-game | Hide character mesh, see skeleton + IK targets |
| **Remote Scene Tree** | Godot editor while game runs | Live-edit weapon marker transforms |

**Standard debug screenshot checklist (attach to bug reports):**
1. Front-facing TPS view
2. Side-view TPS view  
3. FPS view
4. F2 X-Ray from side

---

## 🤖 AI Agent Behavior Rules

### Default Mode
- **Do NOT explain unless asked.** Answer directly.
- **Do NOT refactor unrelated systems** in the same change.
- **Do NOT rename variables** without a correctness reason.
- Prefer transparent code over clever abstractions.

### Analysis-Only Requests
If the user asks for analysis or investigation:
- Provide root cause analysis ONLY.
- Do NOT propose or apply fixes.
- Ask confirmation before patching.

### Implementation Requests
Provide in this order:
1. Problem statement (1–2 lines)
2. Root cause (confirmed, not hypothesis)
3. Why the solution is robust/scalable
4. Minimal scoped change list
5. Validation steps

### Change Checklist (all required before implementation)
- [ ] Problem statement
- [ ] Root cause confirmed with code evidence
- [ ] Why robust and scalable
- [ ] Potential side effects
- [ ] Rollback approach

### Safe Change Pattern
```
static authored data → definitions / resources
runtime mutable state → instances / components
interactions → explicit contracts (has_method, typed signals)
visuals → driven by authoritative state
UI → consumer only, never state owner
```

---

## 🔑 Using the `/caveman` Skill

> **For CODEX users:** When starting a session on the ADS system or any complex IK work, type `/caveman` to activate the skill.
> This skill instructs the AI to explain its reasoning in plain, step-by-step terms before writing any code — making the logic reviewable before it is applied.
> This is especially useful when debugging math-heavy systems like the IK corrector or coordinate transforms.
>
> **For Antigravity users:** Antigravity does not currently support slash-commands. However, you can achieve the same effect by starting your message with:
> *"Before writing any code, walk me through your reasoning step by step."*
> The AI agent rules above ensure analysis happens before implementation regardless.

---

## 📋 Documentation Maintenance Rule

If a feature changes any of the following, update the matching doc in the same work session:
- Public APIs between systems
- Slot definitions or attachment point contracts
- Interaction contracts (`interact(actor)`, action shapes)
- Visual attachment flow
- Weapon scene node conventions (SIGHT, RGRIP, LGRIP)
- This file (`19 - AI Agent Handbook.md`)

---

## 📚 Quick Reference: Docs by Topic

| Topic | Document |
|---|---|
| Architecture & ownership | `01 - Architecture Overview` |
| Game systems map | `02 - Game Systems Overview` |
| Inventory & items | `03 - Inventory and Item System` |
| Interaction system | `04 - Interaction System` |
| Player, visuals, attachment | `05 - Player, Visuals, and Attachment Points` |
| Debug workflows | `06 - Testing and Debugging` |
| Adding new items | `08 - How To Add New Items` |
| Adding attachment points | `09 - How To Add New Attachment Points` |
| Roadmap & priorities | `10 - Control Point Roadmap` |
| Tone & design guardrails | `11 - Tone and Design Guardrails` |
| Aiming & weapon states | `15 - Aiming and Weapon States` |
| Stance system architecture | `16 - Weapon Stance and Procedural Aiming Refactor` *(deleted — superseded by SkeletonModifier3D-based system)* |
| Coordinate standards | `17 - Engine Coordinate Standards` |
| IK architecture (current) | `project-docs/plan/02 - IK SkeletonModifier3D Refactor` |

---

## 🚀 Current Session State (update each session)

**Last updated:** 2026-06-12  
**Active work:** IK/procedural-motion/weapon-stance cleanup — removed `WeaponStance` enum, `LeftHandIKComponent`, `LeftHandModifier3D`, `LeftHandIKDebugGizmo3D`, `ProceduralMotionComponent`, stance-lock debug feature. Animation state is now purely `is_aiming` + `_has_main_hand_weapon()` → Unarmed/Armed/Aiming.  
**Note:** Doc 18 deleted — its aspirational "Hybrid ADS" architecture was superseded by the current `SkeletonModifier3D`-based system (see `project-docs/plan/02 - IK SkeletonModifier3D Refactor.md`).  
**Priority:** Survival systems (health, wounds — per roadmap Priority 2)
