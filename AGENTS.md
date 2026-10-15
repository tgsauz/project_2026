# 🧠 Project 2026 — AI Agent Engineering Guidelines

## 📌 TECH STACK: Godot 4.7.2 · GDScript · CharacterBody3D + CameraController + InteractionComponent

## Core Facts

**Engine:** Godot 4.7.2 | **Language:** GDScript | **Architecture:** CharacterController + CameraController + InteractionComponent  
**Roadmap:** Single-player → multiplayer  
**Optimize for:** Scalability · Modularity · Efficiency · Robustness · Long-term maintainability

**Keystone rule:** Prefer explicit dependencies and deterministic ownership over implicit global lookups.

---

## Must-Know Principles

1. No quick fixes as final solutions.
2. No hidden coupling — avoid scene-depth assumptions and implicit global lookup.
3. Locality of change — touch the smallest safe scope.
4. Backward safety — preserve existing behavior unless explicitly approved.
5. Multiplayer mindset — assume many concurrent instances.

---

## Dependency Resolution (Priority Order)

1. **Explicit injection** ← preferred
2. Exported NodePath (configured at composition root)
3. Local parent traversal (well-bounded)
4. Global group lookup (last resort only)

**If using fallback:** must be deterministic, validated (`has_method`, type checks), degrade gracefully (warn + retry).

## Architecture Constraints

- ✓ Treat packed sub-scenes as reusable modules
- ✓ Interface-style interactions: `interact(actor)` not hardcoded calls
- ✓ Signal payloads carry explicit data (serializable, networkable)
- ✗ Do NOT assume fixed hierarchy depth
- ✗ Do NOT hardcode cross-boundary paths without justification
- ✗ Do NOT blind global node lookup as primary strategy
- ✗ Do NOT scan tree every frame; cache references, re-resolve on invalidation

---

## Code Style

```gdscript
# ============================================================
# SECTION NAME
# ============================================================
```

- Small, single-purpose, readable functions
- Don't rename variables without correctness reason
- Transparent code over clever abstractions
- Don't refactor unrelated systems in the same change

### GDScript Typing Guardrail

- Prefer explicit static types for locals, parameters, returns, and member variables whenever practical
- Do NOT rely on inferred typing when the right-hand side may resolve to `Variant` (for example `get()`, `max()`, dictionary access, resource metadata, or generic engine APIs)
- If an engine API returns `Variant`, cast or annotate explicitly at assignment site
- Use `Variant` only when dynamic typing is intentionally required and that choice is justified by the data flow
- Treat "inferred from Variant" warnings as design issues to fix immediately, not cleanup for later

---

## Before You Code (Decision Tree)

**Workflow:**
1. Symptom/Issue → Analyze
2. Root Cause → Confirm with evidence (not hypothesis)
3. Design → Plan minimal change; check dependencies
4. User Intent → Is this analysis-only or implement?
   - **Analysis-only:** Provide root cause, ask confirmation before patching
   - **Implement:** Provide problem + rationale + change list + validation steps
5. Execute → Apply minimal scoped change

**Change Checklist** (all required):
- [ ] Problem statement
- [ ] Root cause (confirmed, not hypothesis)
- [ ] Why robust/scalable
- [ ] Potential side effects
- [ ] Rollback approach

**Debugging & Performance Rules**:
- Reproducible diagnostics over guesswork
- Prefer deterministic logic over heuristics
- Validate assumptions at runtime (`assert` invariants, warn recoverable)
- Cache references; re-resolve only when invalidated
- Document constants/thresholds and their rationale

---

## AI Agent Behavior

### Session Start
At the start of every conversation, output:
> **Project 2026 (Godot 4.7.2, GDScript)** — ready.

**Default mode:** Do NOT explain unless asked. Minimize token waste. Answer directly.

**If user asks for analysis only:**
- Provide root-cause analysis only
- Do NOT provide or apply fixes
- Ask confirmation before patching

**If user asks for implementation:**
- Problem + root cause
- Robust solution rationale
- Minimal scoped change list
- Validation steps
- Clearly mark optional improvements

---

## Project Priorities

- Game feel over realism
- Control clarity over complexity
- Iterative improvement over overengineering
- Robust systems over temporary convenience

---

## APPENDIX: Reference & Checklists

### Multiplayer-Readiness Checklist (Design-Time)

| Requirement | What to Verify |
|---|---|
| **Concurrency** | Works with multiple player instances |
| **Singletons** | No global singletons unless intended |
| **Authority** | Clear ownership of authority-sensitive logic |
| **Networking** | Signal/event payloads serializable or mirrorable |

### Definition of Done (AI Changes)

- [ ] Root cause addressed (not masked)
- [ ] Solution is modular, deterministic, scalable
- [ ] Affected systems validated with clear checks
- [ ] Change scope minimal and documented
- [ ] Known tradeoffs explicitly listed

### Godot 4.7.2 — API Guardrails

| ❌ Wrong (Godot 3 / Godot 4.6 or older) | ✅ Correct (Godot 4.7.2) |
|---|---|
| `export var` | `@export var` |
| `onready var` | `@onready var` |
| `KinematicBody` | `CharacterBody3D` |
| `Spatial` | `Node3D` |
| `is_network_master()` | `is_multiplayer_authority()` |
| `.instance()` | `.instantiate()` |
| `rand_range()` | `randf_range()` |
| `.connect("sig", obj, "method")` | `sig.connect(method)` |
| `randomize()` (unnecessary) | `RandomNumberGenerator` instance |

## graphify

This project has a graphify knowledge graph at graphify-out/.

**Sobre los documentos con fecha.** Cualquier archivo cuyo nombre incluya una
fecha, o que viva bajo `project-docs/Docs/` con nombre de fecha o de "cambio",
es un **registro de lo que se decidio ese dia**, no arquitectura vigente. Antes
de tratarlo como fuente de verdad, comprueba la fecha y busca las notas de
correccion que esos mismos documentos llevan anadidas cuando el codigo cambio
despues. La arquitectura vigente vive en `project-docs/ADRs/` y en el codigo.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- For cross-module "how does X relate to Y" questions, prefer `graphify query "<question>"`, `graphify path "<A>" "<B>"`, or `graphify explain "<concept>"` over grep — these traverse the graph's EXTRACTED + INFERRED edges instead of scanning files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
