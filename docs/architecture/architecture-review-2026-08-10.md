# Architecture Review Report

Date: 2026-08-10
Engine: Godot 4.7.1 (Web export, Compatibility/OpenGL ES3/WebGL2 renderer)
GDDs Reviewed: 11 (Content Data, Input Abstraction, Object Placement, Ecosystem Simulation, Tending Input, Time & Drift, Creature Behavior, Persistence/Save, Discovery Surfacing, Diorama Rendering, Ambient Audio)
ADRs Reviewed: 4 (ADR-0001 through ADR-0004, all `Status: Proposed`)

This is the first `/architecture-review` pass for this project. `tr-registry.yaml` was an empty scaffold before this run.

---

## Traceability Summary

Baseline requirement counts are drawn from `architecture.md`'s own Phase-0b extraction (~240–260 TRs across 11 systems + 2 cross-cutting items), since a full per-requirement re-extraction across all 11 GDDs was out of scope for this pass — see "Scoping Note" below.

Total requirements: ~262 (per-system sum below)
✅ Covered: ~22 (Content Data, cross-cutting)
⚠️ Partial: ~78 (Object Placement, Ecosystem Simulation, Discovery Surfacing)
❌ Gaps: ~162 (Input Abstraction, Tending Input, Time & Drift, Creature Behavior, Persistence/Save, Diorama Rendering, Ambient Audio)

| System | ~TRs | ADR Coverage | Status |
|---|---|---|---|
| Content Data | 20 | ADR-0001 | ✅ Covered |
| Input Abstraction | 17 | — | ❌ GAP — Foundation layer |
| Object Placement | 14 | ADR-0003 | ⚠️ Partial — `restore()` not in Key Interfaces |
| Ecosystem Simulation | 32 | ADR-0004 | ⚠️ Partial — same `restore()` gap |
| Tending Input | 16 | — | ❌ GAP |
| Time & Drift | 24 | — | ❌ GAP |
| Creature Behavior | 22 | — | ❌ GAP |
| Persistence/Save | 21 | — | ❌ GAP — self-flagged BLOCKING Web-export gates |
| Discovery Surfacing | 32 | ADR-0002 (partial) | ⚠️ Partial — snapshot mechanism resolved; reveal-queue architecture still open |
| Diorama Rendering | 36 | — | ❌ GAP — escalated BLOCKING gate (Light2D/Compatibility renderer) |
| Ambient Audio | 26 | — | ❌ GAP |
| *(cross-cutting)* | 2 | ADR-0002 | ✅ Covered |

**`architecture.md`'s own 5 Open Questions**: QQ-01 (event/signal architecture), QQ-02 (snapshot mechanism), and QQ-04 (content authoring format) are now **resolved** by ADR-0002/ADR-0001. QQ-03 (3 Web-export verification gates) remains unresolved — tracked in `docs/technical-setup/web-export-verification-plan.md`, not an ADR gap. QQ-05 (multi-jar) is out of MVP scope.

### Coverage Gaps (no ADR exists)

❌ **Input Abstraction** (17 TRs) → design/gdd/input-abstraction.md → Input Abstraction
   Suggested ADR: `/architecture-decision Input gesture abstraction & Web export touch/focus handling strategy`
   Domain: Input / Foundation
   Engine Risk: HIGH — gated on an unrun Web-export verification spike (pointer interruption, touch/mouse-emulation dedup)

❌ **Persistence/Save** (21 TRs) → design/gdd/persistence-save.md → Persistence/Save
   Suggested ADR: `/architecture-decision Save blob schema, validity gating, and Web export persistence strategy`
   Domain: Persistence
   Engine Risk: HIGH — self-flagged BLOCKING (IndexedDB write reliability, `visibilitychange`/`pagehide` reachability)

❌ **Diorama Rendering** (36 TRs) → design/gdd/diorama-rendering.md → Diorama Rendering
   Suggested ADR: `/architecture-decision Diorama Rendering technique under Compatibility/WebGL2 renderer`
   Domain: Rendering
   Engine Risk: HIGH — escalated BLOCKING gate, widest blast radius per that GDD's own Open Question 1

❌ **Time & Drift** (24 TRs) → design/gdd/time-drift.md → Time & Drift
   Suggested ADR: `/architecture-decision Session lifecycle & tick-batching model`
   Domain: Gameplay / Session
   Engine Risk: MEDIUM — shares Persistence/Save's `visibilitychange` verification gate

❌ **Creature Behavior** (22 TRs) → design/gdd/creature-behavior.md → Creature Behavior
   Suggested ADR: `/architecture-decision Creature AI/movement architecture`
   Domain: Gameplay
   Engine Risk: LOW

❌ **Discovery Surfacing** (32 TRs, partial) → design/gdd/discovery-surfacing.md → Discovery Surfacing
   Suggested ADR: `/architecture-decision Discovery Surfacing reveal-queue & pacing architecture`
   Domain: Presentation
   Engine Risk: LOW — snapshot half already resolved by ADR-0002

❌ **Ambient Audio** (26 TRs) → design/gdd/ambient-audio.md → Ambient Audio
   Suggested ADR: `/architecture-decision Ambient Audio bus/volume architecture`
   Domain: Audio
   Engine Risk: LOW — browser autoplay-gesture-unlock is a generic Web constraint, not Godot-version-specific

❌ **Tending Input** (16 TRs) → design/gdd/tending-input.md → Tending Input
   Suggested ADR: `/architecture-decision Tending Input command-routing pattern` (likely folds into an ADR-0002 amendment — small, stateless router)
   Domain: Gameplay
   Engine Risk: LOW

### Scoping Note

A full requirement-by-requirement re-extraction across all 11 GDDs (the ~240–260 item baseline `architecture.md` already produced) was not re-derived line-by-line in this pass — the per-system counts and gap list above are inherited from that document's own Phase-0b accounting, cross-checked against which systems the 4 existing ADRs actually cover. `tr-registry.yaml` has been populated with stable TR-IDs only for the requirement statements the 4 existing ADRs *explicitly* enumerate in their own "GDD Requirements Addressed" tables (22 IDs total — see the Traceability Index). Requirements for the 7 gap systems are **not yet ID-registered** — minting IDs for un-ADR'd requirements now risks needing to renumber or redefine them once each system's real ADR is written and the requirement wording gets tightened against an actual decision; the registry format explicitly forbids renumbering. Recommend a full requirement-extraction pass the next time `/architecture-review` runs, once a few more ADRs exist to anchor it.

---

### Cross-ADR Conflicts

**🔴 Conflict 1 — `restore()` integration contract gap**
Type: Integration contract conflict
ADR-0002 claims: `SessionBootstrap._ready()` hardcodes `EcosystemSimulation.restore(restored)` and `ObjectPlacement.restore(restored)` as session-start steps 3–4 — a concrete method call on each autoload.
ADR-0003/ADR-0004 claim: Neither ADR declares a `restore()` method in its own "Key Interfaces" section. ADR-0003's Decision text explicitly defers this ("...or from a restored Persistence/Save blob, **once that ADR exists**").
Impact: Two ADRs written the same session assume a method neither owning ADR actually specifies. `restore()` carries real design surface (partial-blob handling, schema mismatch against Content Data, missing-id behavior) that belongs in the owning system's ADR. Confirmed independently by godot-specialist consultation during this review (rated BLOCKING, not an obvious implementation detail).
Resolution options:
  1. Amend ADR-0003 and ADR-0004 now to add `restore(section: Dictionary) -> void` to their own Key Interfaces.
  2. Defer explicitly to the future Persistence/Save ADR, which would then need to amend ADR-0002/0003/0004's Key Interfaces sections itself when written.

**⚠️ Advisory — Risk-rating inconsistency (not a functional conflict)**
ADR-0003 and ADR-0004 both rate `Knowledge Risk: LOW` / `Verification Required: None`, while their own Decision text hedges on unconfirmed typed-`Dictionary[String, CustomClass]` support (this project's engine-reference docs never confirm or deny it), choosing plain untyped `Dictionary` specifically because of that uncertainty. That hedge contradicts the stated "LOW/None" rating — ADR-0001's `MEDIUM` rating is the correctly-calibrated comparison point. Recommend downgrading ADR-0003/0004 to `MEDIUM` and adding an explicit `Verification Required` line for the typed-Dictionary question.

No data-ownership, performance-budget, or dependency-cycle conflicts found among the 4 ADRs.

### ADR Dependency Order

```
Foundation (no dependencies):
  1. ADR-0001: Content Data Authoring Format
  2. ADR-0002: Cross-Cutting Signal/Init-Order/Snapshot Architecture

Depends on Foundation:
  3. ADR-0003: 2D Placement/Collision Approach (requires 0001, 0002)

Depends on Core:
  4. ADR-0004: Ecosystem Simulation Tick Architecture (requires 0001, 0002, 0003)
```

No cycles, no unresolved dependency references between the 4 ADRs. **However: all 4 ADRs are still `Status: Proposed`**, not `Accepted`. Per `docs/CLAUDE.md`'s own convention ("Never skip Accepted — stories referencing a Proposed ADR are auto-blocked"), no story can currently reference any of the 4 written ADRs without being auto-blocked.

---

### GDD Revision Flags

None — no ADR records a verified post-cutoff engine behavior that conflicts with a GDD assumption. (`content-data.md`'s own Core Rule 2 already correctly anticipated the 4.6→4.7 packed-array/setter change before ADR-0001 confirmed it moot for this specific field set.)

---

### Engine Compatibility Issues

- Engine: Godot 4.7.1, consistently referenced across all 4 ADRs and `architecture.md`.
- ADRs with Engine Compatibility section: 4 / 4.
- No deprecated APIs (`docs/engine-reference/godot/deprecated-apis.md`) referenced by any ADR.
- No stale version references.
- No post-cutoff API conflicts between ADRs.

### Engine Specialist Findings (godot-specialist consultation, this pass)

1. **`restore()` contract gap** — confirmed, see Conflict 1 above. Rated BLOCKING: has real design surface, not an obvious implementation detail two ADRs could safely leave implicit.
2. **Untyped-`Dictionary` justification** — the caution is defensible per this project's own "verify before trusting training data" protocol (engine-reference docs never confirm typed-Dictionary-with-custom-class support), but applied inconsistently: typed `Array[CustomClass]`/`Array[String]` is trusted unhedged elsewhere in the same ADRs. Advisory: keep the untyped default, but add an explicit verification task rather than letting the caution become permanent by omission.
3. **Autoload load-order reasoning** (`SessionBootstrap` placed last in ADR-0002) — confirmed correct: Godot instantiates/calls `_ready()` on autoloads in Project Settings list order, unchanged 4.3→4.7. No circularity risk.
4. **`RandomNumberGenerator`/`randomize()` split** (ADR-0004) — confirmed idiomatic; correct impure-roll/pure-gate separation, no deprecation concerns.
5. **`ResourceLoader.load()` caching** (ADR-0001) — `content-data.md`'s own flagged risk (shared-instance mutation via `load()`'s path-based cache; `CACHE_MODE_IGNORE`/`duplicate_deep()` as mitigations) is never actually addressed in ADR-0001's Risks or Validation Criteria — the unit test sidesteps it by constructing Resources directly rather than via `load()`. Advisory: add as a named Risk with mitigation.
6. **Minor/cosmetic**: `EcosystemFormulas.light_level_tick()` (ADR-0004) returns a `Vector2i(level, direction)` — reusing a spatial type for a non-positional pair, inconsistent with the `DebounceResult` RefCounted pattern the same ADR adopts moments later for the identical reason (avoid ad-hoc bags).

---

### Architecture Document Coverage

`architecture.md` covers all 11 systems from `systems-index.md`, with layer assignment (Foundation/Core/Feature/Presentation) matching the systems index's own dependency-consistent layering. Data flow section covers all cross-system communication defined across the 11 GDDs. No orphaned architecture (no system in `architecture.md` lacking a corresponding GDD).

**One staleness item (not blocking)**: `architecture.md`'s own "ADR Audit" section still states *"`docs/architecture/` contains no ADRs yet"* and lists all ~240 baseline TRs as gaps — this predates the 4 ADRs now written. This review read the 4 ADRs directly rather than trusting that stale table, so the finding above isn't affected, but `architecture.md` should be refreshed to reflect current ADR state before it's next used as a reference document.

---

### Verdict: FAIL

Per this skill's rubric — *"FAIL: Critical gaps (Foundation/Core layer requirements uncovered), or blocking cross-ADR conflicts detected"* — both conditions are met: Input Abstraction (Foundation layer, explicitly named "must have before any coding starts" by `architecture.md` itself) has zero ADR coverage, and Conflict 1 is a real integration-contract conflict between two already-written ADRs.

**Context**: this is expected-for-stage, not alarming. GDDs only finished their last cross-GDD review on 2026-08-09; only 4 of the ~11 architecturally-required ADRs exist. This is very likely the first `/architecture-review` pass this project has run. Treat the verdict as "keep writing ADRs, fix one integration gap" rather than "something is broken."

### Blocking Issues (must resolve before PASS)

1. **Input Abstraction has no ADR.** Foundation layer; Object Placement, Tending Input, and Time & Drift all already depend on its `canceled`/interruption contract, itself gated on an unrun Web-export verification spike (Gate A, `web-export-verification-plan.md`).
2. **`restore()` contract gap** (Conflict 1) — resolve via ADR-0003/0004 amendment, or explicit ownership assigned when the Persistence/Save ADR is written.
3. **All 4 ADRs still `Proposed`.** Must be moved to `Accepted` (after fixing #2) before any story can reference them.

### Required ADRs

Prioritized, most foundational first:

1. **Input Abstraction & Web-export touch/focus handling strategy** — ⚠️ gated on Gate A of the verification spike
2. **Persistence/Save blob schema & Web-export persistence strategy** — ⚠️ gated on Gate B, HIGH RISK; should also resolve the `restore()` contract gap as part of its own Key Interfaces
3. **Time & Drift session lifecycle & tick-batching model** — ⚠️ partially gated (shares Gate B's `visibilitychange` dependency)
4. **Creature Behavior AI/movement architecture**
5. **Discovery Surfacing reveal-queue & pacing architecture** — snapshot half already resolved by ADR-0002
6. **Diorama Rendering technique under Compatibility/WebGL2 renderer** — ⚠️ gated on Gate C, escalated BLOCKING, widest blast radius
7. **Ambient Audio bus/volume architecture**
8. **Tending Input command-routing pattern** — small; likely folds into an ADR-0002 amendment
