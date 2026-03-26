# 🧠 Project 2026 — AI Agent Engineering Guidelines

## 1) Project Context

Project 2026 is a **Godot 4.6** game with a long-term product roadmap (single-player to multiplayer).  
Engineering decisions must optimize for:

- **Scalability**
- **Modularity**
- **Efficiency**
- **Robustness**
- **Long-term maintainability over short-term speed**

---

## 2) Technical Baseline

- **Engine:** Godot 4.6
- **Language:** GDScript
- **Animation:** AnimationTree + BlendSpace2D
- **Current architecture (high-level):**
  - CharacterController / motor logic
  - CameraController (FPS/TPS camera + input coupling)
  - InteractionComponent + world interactables

> Rule: Prefer explicit dependencies and deterministic ownership over implicit global lookups.

---

## 3) Non-Negotiable Engineering Principles

1. **No quick fixes as final solutions.**
2. **No hidden coupling.** Avoid brittle scene-depth assumptions and global dependency lookup where explicit wiring is possible.
3. **Locality of change.** Touch the smallest safe scope.
4. **Backward safety.** Changes must preserve existing behavior unless explicitly approved.
5. **Multiplayer readiness mindset.** Assume many instances of scenes/scripts will coexist.

---

## 4) Architecture Rules

### 4.1 Dependency Resolution

- Prefer this order:
  1. **Explicit injection** (best)
  2. Explicit exported NodePath configured at composition root
  3. Local parent traversal (well-bounded fallback)
  4. Global group lookup (last resort only)

- If fallback logic is used, it must:
  - Be deterministic
  - Be validated (`has_method`, type checks)
  - Degrade gracefully (warning + retry), not hard-crash, unless crash is intentional and approved.

### 4.2 Scene Ownership Boundaries

- Treat packed sub-scenes as reusable modules.
- Do not assume fixed hierarchy depth across all contexts.
- Avoid hardcoding cross-boundary relative paths unless justified and documented.

### 4.3 Interaction System

- Interactions should be interface-style (`interact(actor)`), not type-hardcoded behavior calls.
- Prompt data should come from interaction targets through clear API contracts (e.g., `get_prompt_text`).
- Focus/update signals should carry explicit payloads suitable for UI and networking adaptation.

---

## 5) Code Style and Structure

- Keep existing section format:

```gdscript
# ============================================================
# SECTION NAME
# ============================================================
```

- Keep functions small, single-purpose, and readable.
- Do **not** rename existing variables unless there is a correctness reason.
- Avoid clever abstractions; prefer transparent, debuggable code.
- Do not refactor unrelated systems in the same change.

---

## 6) Change Control Rules

Every proposed change must state:

1. **Problem statement**
2. **Root cause** (confirmed vs hypothesis)
3. **Why this fix is robust/scalable**
4. **Potential side effects**
5. **Rollback approach**

If these are missing, the change is incomplete.

---

## 7) Analysis-First Protocol

Before implementing:

1. Analyze symptom(s)
2. Confirm root cause with evidence
3. Distinguish facts from assumptions
4. Present implementation plan
5. Execute after confirmation (unless user explicitly requested immediate fix)

---

## 8) Debugging Protocol

- Prefer reproducible diagnostics over guesswork.
- Use targeted logs/debug prints sparingly and remove noisy instrumentation after validation.
- Validate assumptions at runtime (`assert` for invariants, warnings for recoverable states).

---

## 9) Reliability & Performance Guardrails

- Prefer deterministic logic over “magic” heuristics.
- Document any constant/threshold and its rationale.
- For per-frame systems, avoid repeated expensive scene-tree searches.
- Cache references where safe; re-resolve only when invalidated.

---

## 10) Multiplayer-Readiness Checklist (Design-Time)

When introducing/changing a system, verify:

- Works with multiple concurrent player instances
- No global singleton assumptions unless intended
- Clear ownership of authority-sensitive logic
- Signal/event payloads can be serialized or mirrored if needed

---

## 11) Response/Delivery Protocol for AI Contributions

### If user asks for analysis only
- Provide root-cause analysis only
- Do **not** provide or apply fixes
- Ask for confirmation before patching

### If user asks for implementation
Provide, in order:
1. Problem + root cause
2. Robust solution rationale
3. Minimal scoped change list
4. Validation steps
5. Optional improvements (clearly marked optional)

---

## 12) Anti-Patterns (Disallowed by Default)

- Blind global node lookup as primary dependency strategy
- Unbounded tree scanning every frame
- Hardcoded hierarchy assumptions without validation
- Mixing architecture refactors with unrelated bug fixes
- Large rewrites when localized patch is sufficient

---

## 13) Definition of Done (for AI-driven changes)

A task is only complete when:

- Root cause is addressed (not masked)
- Solution is modular, deterministic, and scalable
- Affected systems are validated with clear checks
- Change scope is minimal and documented
- Known tradeoffs are explicitly listed

---

## 14) Project Priority Reminder

Project 2026 prioritizes:

- **Game feel over realism**
- **Control clarity over complexity**
- **Iterative improvement over overengineering**
- **Robust systems over temporary convenience**
