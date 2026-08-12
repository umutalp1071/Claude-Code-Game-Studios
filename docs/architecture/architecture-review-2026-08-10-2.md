# Architecture Review Report

Date: 2026-08-10 (second pass — see `architecture-review-2026-08-10.md` for the first pass)
Engine: Godot 4.7.1 (Web export, Compatibility/OpenGL ES3/WebGL2 renderer)
GDDs Reviewed: 11 MVP systems (Content Data, Input Abstraction, Object Placement, Ecosystem Simulation, Tending Input, Time & Drift, Creature Behavior, Persistence/Save, Discovery Surfacing, Diorama Rendering, Ambient Audio)
ADRs Reviewed: 7 (ADR-0001 through ADR-0007, all `Status: Proposed`)

This is the second `/architecture-review` pass. Since the first pass (also 2026-08-10, ADR-0001–0004 only), three more ADRs were written (0005 Persistence/Save, 0006 Time & Drift, 0007 Creature Behavior). This pass also performed, for the first time, a **real per-requirement extraction** across all 11 GDDs — the first pass explicitly deferred this and inherited a rough estimate (~262 TRs) from `architecture.md`'s own Phase-0b accounting. That estimate turns out to have counted raw GDD Acceptance-Criteria/Core-Rule lines rather than architecturally-distinct decisions; the real, grouped baseline is **80 requirements**.

---

## Traceability Summary

| Status | Count | % |
|---|---|---|
| ✅ Covered | 36 | 45% |
| ⚠️ Partial | 6 | 7.5% |
| ❌ Gap | 38 | 47.5% |
| **Total** | **80** | 100% |

| System | TRs | Covered | Partial | Gap | ADR Coverage |
|---|---|---|---|---|---|
| Content Data | 5 | 5 | 0 | 0 | ADR-0001 |
| Cross-cutting | 3 | 2 | 0 | 1 | ADR-0002 (partial — see Conflict 1) |
| Object Placement | 6 | 6 | 0 | 0 | ADR-0003 |
| Ecosystem Simulation | 5 | 5 | 0 | 0 | ADR-0004 |
| Persistence/Save | 8 | 5 | 3 | 0 | ADR-0005 |
| Time & Drift | 7 | 6 | 1 | 0 | ADR-0006 |
| Creature Behavior | 7 | 6 | 1 | 0 | ADR-0007 |
| Input Abstraction | 8 | 0 | 0 | 8 | — |
| Tending Input | 6 | 0 | 0 | 6 | — |
| Discovery Surfacing | 8 | 1 | 0 | 7 | ADR-0002 (snapshot half only) |
| Diorama Rendering | 10 | 0 | 0 | 10 | — |
| Ambient Audio | 7 | 0 | 0 | 7 | — |

Object Placement and Ecosystem Simulation's own item-level requirements are now fully covered by ADR-0003/ADR-0004 respectively; the "Partial" rating either system carried in the first-pass review was solely the restore-contract issue, which this pass tracks as its own cross-cutting requirement (TR-crosscutting-003) rather than charging it against either system, since it is not owned by either GDD.

### Full Requirement Tables — Newly ADR'd Systems

**Persistence/Save** (ADR-0005)

| TR-ID | Requirement | Status |
|---|---|---|
| TR-persistence-save-001 | Save blob schema — full field list (Core Rule 1) | ⚠️ Partial — ADR references `_serialize()` generically, never enumerates the field list; not a row in ADR's own GDD Requirements table |
| TR-persistence-save-002 | `save_blob_validity` gate — all-or-nothing validation, evaluation order, two-tier fallback | ⚠️ Partial — Core Rule 7 (promotion) addressed; `save_blob_validity` not isolated as its own testable pure-formula script per project convention |
| TR-persistence-save-003 | Web storage backend & write reliability at session end/backgrounding (Core Rule 5) | ✅ Covered — `localStorage` + pure-JS `HideBridge` decision; former BLOCKING Open Question resolved |
| TR-persistence-save-004 | Cross-system restore sequencing/API | ⚠️ Partial — `get_restored_blob()` declared, consuming side is not; see Conflict 1 |
| TR-persistence-save-005 | No periodic autosave / gesture-triggered mirror refresh (AC11) | ✅ Covered |
| TR-persistence-save-006 | Save-confirmation cue signal to Diorama Rendering (Core Rule 8) | ✅ Covered |
| TR-persistence-save-007 | Non-Web/editor dev fallback persistence path | ✅ Covered |
| TR-persistence-save-008 | Storage size/performance budget | ✅ Covered |

**Time & Drift** (ADR-0006)

| TR-ID | Requirement | Status |
|---|---|---|
| TR-time-drift-001 | Tick-batching/catch-up model (Core Rules 2–6) | ✅ Covered |
| TR-time-drift-002 | `last_visit_timestamp` update semantics at session boundaries (Core Rule 8) | ✅ Covered — extends ADR-0005's `HideBridge` |
| TR-time-drift-003 | Cosmetic `day_night_phase` computation (Core Rule 7) | ✅ Covered |
| TR-time-drift-004 | SessionBootstrap integration/init ordering | ✅ Covered |
| TR-time-drift-005 | State machine exposure to dependents | ✅ Covered |
| TR-time-drift-006 | Unix-timestamp float/int type safety | ✅ Covered |
| TR-time-drift-007 | bfcache/`pageshow` reload-guard dependency on ADR-0005's JS layer | ⚠️ Partial — documented as prose constraint only, no enforcement mechanism |

**Creature Behavior** (ADR-0007)

| TR-ID | Requirement | Status |
|---|---|---|
| TR-creature-behavior-001 | Wander state machine & per-instance data structure (Core Rules 1–7) | ✅ Covered |
| TR-creature-behavior-002 | PRESENT/ABSENT transition detection (pull-based, respects ADR-0004's "never calls outward") | ✅ Covered |
| TR-creature-behavior-003 | Session-start entry / Core Rule 8 CATCHING_UP-suppression | ✅ Covered, with documented fragility (contingent on no `await`/`call_deferred`/threading in `SessionBootstrap`) |
| TR-creature-behavior-004 | Movement/destination-sampling/pause-duration pure formulas | ✅ Covered |
| TR-creature-behavior-005 | `set_last_known_position()` write-only call-in (Core Rule 9) | ✅ Covered |
| TR-creature-behavior-006 | Per-frame diff-poll performance budget at MVP scale | ✅ Covered |
| TR-creature-behavior-007 | Object Placement footprint read as movement obstacle (soft dependency) | ⚠️ Partial — formula parameter exists, population path from Object Placement never shown in Key Interfaces |

**Cross-cutting** (ADR-0002)

| TR-ID | Requirement | Status |
|---|---|---|
| TR-crosscutting-001 | No formal inter-system communication convention existed | ✅ Covered |
| TR-crosscutting-002 | No owner for Discovery Surfacing's pre-batch snapshot / 11-step session-start sequence | ✅ Covered |
| TR-crosscutting-003 | `SessionBootstrap` needs a public, ADR-declared write path into every system it restores state into | ❌ Gap — actively conflicting, not merely missing; see Conflict 1 |

### Coverage Gaps (no ADR exists)

| System | Suggested ADR | Domain | Engine Risk |
|---|---|---|---|
| Input Abstraction (8 TRs) | `/architecture-decision Gesture Abstraction Layer: Unified Pointer State Machine for Mouse/Touch` | Input / Foundation | **HIGH** — gated on unrun Web-export Gate A |
| Diorama Rendering (10 TRs) | `/architecture-decision Diorama Rendering Pipeline: Baked-Light Compositing, Tween Vocabulary, Light2D Cue Budget` | Rendering | Downgraded from HIGH — see Engine Specialist Findings; Light2D/normal-maps under Compatibility renderer confirmed supported |
| Discovery Surfacing (7 TRs remaining) | `/architecture-decision Discovery Reveal Queue: Pacing, Categorization, Cue-Ordering` (excludes snapshot mechanism — already ADR-0002 §3) | Presentation | HIGH (Core Rule 4a inherits Gate A; rest LOW) |
| Ambient Audio (7 TRs) | `/architecture-decision Ambient Audio Playback: Loop Lifecycle, Autoplay-Unlock, Reactive Mix Bus` | Audio / Platform | MEDIUM — autoplay-unlock is a real, Godot-version-agnostic Web constraint |
| Tending Input (6 TRs) | `/architecture-decision Tending Input Routing: Tap-to-Watering Direct-Call Contract` | Gameplay / Input | LOW — likely folds into an ADR-0002 amendment |

### Scoping Note

Requirement extraction for Input Abstraction, Tending Input, Discovery Surfacing (reveal-queue half), Diorama Rendering, and Ambient Audio is now real (not estimated) but **not yet ID-registered** in `tr-registry.yaml` — consistent with the first pass's policy of only minting stable IDs once a system's real ADR exists, to avoid renumbering risk.

---

## Cross-ADR Conflicts

### 🔴 Conflict 1 (BLOCKING, ESCALATED) — `SessionBootstrap` calls methods no ADR declares

The first pass flagged 2 undeclared methods (`EcosystemSimulation.restore()`, `ObjectPlacement.restore()`), deferred pending the Persistence/Save ADR. ADR-0005 now exists and does not close this gap — it widens it. Checking all 6 calls in ADR-0002's `SessionBootstrap._ready()` pseudocode against the Key Interfaces actually declared by the owning ADR:

| Call in ADR-0002 | Declared by owning ADR? |
|---|---|
| `ContentData.load_registry()` | ❌ No — ADR-0001 only declares `get_definition()`; loading described as automatic |
| `PersistenceSave.load_blob()` | ❌ No — ADR-0005 declares `load() -> bool` plus a separate `get_restored_blob() -> Dictionary` |
| `EcosystemSimulation.restore(restored)` | ❌ No — ADR-0004 declares no write method |
| `ObjectPlacement.restore(restored)` | ❌ No — **ADR-0003 explicitly states "No public write API"**, a direct contradiction |
| `TimeDrift.run_catchup_and_activate()` | ❌ No — ADR-0006 only declares `get_state()`/`get_day_night_phase()` |
| `CreatureBehavior.settle_from_ecosystem_state()` | ❌ Name mismatch — ADR-0007 declares `resolve_session_start()` |

ADR-0005 replaced the push model ADR-0002 assumed (`load_blob()` → `.restore(blob)`) with a **pull** model (`load()` + `get_restored_blob()`), justified by citing ADR-0004 text ("Both registries are populated at SessionBootstrap's restore step... defaulted or restored from Persistence/Save") that on inspection never actually specifies push vs. pull. No ADR exposes a public write path for the pulled `Dictionary`'s fields — `_plants`/`_creatures`/`_objects` are private with no setters in ADR-0003/0004. **ADR-0002's `SessionBootstrap` pseudocode is, as written, not implementable against any of the 6 ADRs it calls into.**

**Resolution options:**
1. Revise ADR-0002's `SessionBootstrap` pseudocode to match the pull model, and add a public `restore(data: Dictionary) -> void` (or equivalent typed setter) to ADR-0003/0004/0006/0007's own Key Interfaces for `SessionBootstrap` to call into.
2. Grant `SessionBootstrap` a documented, registered convention of privileged internal write access (the way `testable_pure_formula_placement`/`production_rng_ownership` are registered conventions elsewhere) — but this needs to be an explicit, named decision, not an implicit gap.

### ⚠️ Conflict 2 — Step-numbering drift across ADR-0002/0006/0007

ADR-0002 numbers CreatureBehavior's session-start call as step 8; ADR-0007 says step 7; ADR-0006 collapses "steps 6-7" into "step 6." Three documents disagree on the number for one canonical sequence — exactly what ADR-0002's own Context section warned against ("must not diverge"). State-transition semantics (INACTIVE→CATCHING_UP→ACTIVE ordering) remain internally consistent; only the numbering has drifted.

### ⚠️ Conflict 3 — ADR-0003 internal self-contradiction

Key Interfaces: *"No public write API — driven entirely by Input Abstraction's signals (ADR-0002)."* Decision text: *"Object Placement populates its registry from Content Data's `ObjectTypeDef` entries (or from a restored Persistence/Save blob, once that ADR exists)."* That clause is now live (ADR-0005 exists) and unreconciled with the "no write API" claim in the same document.

### ⚠️ Advisory — undocumented upstream dependency

ADR-0007's Core Rule 8 correctness argument depends on `SessionBootstrap._ready()` never containing `await`/`call_deferred()`/`Thread` — stated only in ADR-0007 (downstream), never in ADR-0002 (the actual owner of `SessionBootstrap`). A future edit to ADR-0002 has no forcing function to catch this.

### ⚠️ Advisory — architectural-convention break

ADR-0005 places `save_blob_validity()`/`_serialize()` directly on the `PersistenceSave` autoload, breaking the pure-`*_formulas.gd`-script convention every other ADR (0003, 0004, 0006, 0007) follows. `save_blob_validity` is exactly the kind of pure boolean logic that convention — and the project's own BLOCKING-test-for-Logic-stories rule — exists for.

### ✅ Not a conflict (clarified by engine specialist)

ADR-0001's `Dictionary[String, Resource]` vs. ADR-0003/0004's avoidance of `Dictionary[String, <CustomClass>]` looked like an inconsistency but isn't — different risk categories (builtin engine type vs. custom `class_name` value type; the latter has real, documented rough edges in Inspector/serialization/remote-debugger paths that don't apply to the former). Recommend one clarifying sentence in ADR-0001 rather than a fix.

No data-ownership, performance-budget, or dependency-cycle conflicts found among the 7 ADRs.

### ADR Dependency Order

```
Foundation (no dependencies):
  1. ADR-0001: Content Data Authoring Format
  2. ADR-0002: Cross-Cutting Signal/Init-Order/Snapshot Architecture

Depends on Foundation:
  3. ADR-0003: 2D Placement/Collision Approach (requires 0001, 0002)
  3. ADR-0005: Persistence/Save Web Storage Strategy (requires 0001, 0002) — interchangeable order with 0003

Depends on Core:
  4. ADR-0004: Ecosystem Simulation Tick Architecture (requires 0001, 0002, 0003)

Feature layer:
  5. ADR-0006: Time & Drift Session Lifecycle (requires 0004, 0005)
  6. ADR-0007: Creature Behavior Wander State Machine (requires 0004, 0003, 0006)
```

Valid linear order: **0001 → 0002 → 0003 → 0005 → 0004 → 0006 → 0007**. No cycles, no unresolved dependency references. **All 7 ADRs remain `Status: Proposed`** — per `docs/CLAUDE.md`'s lifecycle rule, no story can reference any of them until promoted to `Accepted`.

---

## GDD Revision Flags

None. The one candidate for a flag — Diorama Rendering's assumption that Light2D/normal-maps work under the Compatibility renderer — was *confirmed*, not contradicted, by this pass's engine specialist consultation. No GDD requires revision.

---

## Engine Compatibility Issues

- Engine: Godot 4.7.1, consistently referenced across all 7 ADRs.
- ADRs with Engine Compatibility section: 7 / 7.
- No deprecated APIs referenced by any ADR; ADR-0002 explicitly reasons through the `duplicate()`-for-nested-resources deprecation correctly rather than avoiding or ignoring it blindly.
- No stale version references; no post-cutoff API conflicts between ADRs.
- **Recurring risk-rating miscalibration**: ADR-0003/0004 (flagged in the first pass, still unfixed) and now **ADR-0007** rate `Knowledge Risk: LOW` while resting on a hedged claim (`_ready()`-before-`_process()`, "TRUE-WITH-CAVEATS"). Specialist confirms the underlying engine guarantee is actually solid — LOW is defensible *given* `SessionBootstrap` stays synchronous — but the constraint that makes it true belongs in ADR-0002 (its actual owner), not only asserted downstream.

### Engine Specialist Findings (godot-specialist consultation, this pass)

1. **Typed-Dictionary "conflict" is not a conflict.** `Dictionary[String, Resource]` (builtin value type, ADR-0001) is safe; `Dictionary[String, <CustomClass>]` (custom `class_name` value type, avoided by ADR-0003/0004) has real, documented rough edges (Inspector display, `.tres` serialization, remote-debugger crashes — GitHub issues #98903, #101288, #104932, #108488, #109574, #98140, #105374) that cluster in editor/export paths, not plain private-field runtime read/write. Recommend one clarifying sentence in ADR-0001.
2. **`FileAccess.store_*` → `bool`**: confirmed accurate for 4.7.1; ADR-0005 handles it correctly; low-consequence (dev-only, never-shipped-to-Web path).
3. **`_ready()`-before-`_process()`, including autoloads and Web/WASM export**: confirmed solid, unchanged since Godot 3, no Web-specific divergence — the WASM build runs the same C++ startup sequence, `requestAnimationFrame` scheduling only affects frame-to-frame timing, not startup ordering. ADR-0007's LOW rating is defensible given the precondition holds. Recommend documenting the `await`/`call_deferred`/`Thread` prohibition directly on ADR-0002, plus a cheap enforcement (grep-check or smoke test) on `SessionBootstrap._ready()`.
4. **`visibilitychange`/`pagehide` on iOS Safari**: confirmed limited reliability, matching ADR-0005/0006's own hedged framing (clean pagehide/beforeunload firing is "the exception, not the rule" on iOS backgrounding-via-kill). **New finding not yet distinguished in either ADR**: multiple reports of Godot Web export being broadly unreliable on iOS Safari *independent of backgrounding* (audio-triggered crashes, WASM/WebGL2/SharedArrayBuffer issues). Recommend the verification plan split "WebKit signal-reliability risk" from "WebKit runtime-stability risk" as two distinct residual-risk categories.
5. **Autoload `_ready()` order = Project Settings list order**: confirmed stable across 4.3–4.7. No compile/runtime guardrail exists today — recommend a defensive assertion in `SessionBootstrap._ready()` (e.g., assert Content Data's registry is non-empty before proceeding), converting a silent misordering into a loud one.
6. **Light2D + normal maps under Compatibility/WebGL2**: **CONFIRMED WORKS.** Per official Godot docs, 2D dynamic lighting/normal maps predate Forward+ entirely (GLES2/3-era Godot 3.x feature); Compatibility renderer is explicitly documented as "usually good enough for 2D." What Compatibility *does* lack is VoxelGI/SDFGI-style indirect lighting — irrelevant to point-light/normal-map usage. Recommend **downgrading Diorama Rendering's BLOCKING gate to advisory-pending-a-real-Web-export-smoke-test.**
7. **No Forward+-assumption anti-patterns found** across all 7 ADRs — clean discipline (physics-free placement, pure-simulation Ecosystem Simulation, JS-bridge persistence all renderer-agnostic by construction). Two cosmetic-only nitpicks: `EcosystemFormulas.light_level_tick()` returns a `Vector2i` as a non-positional (level, direction) pair; the four pure-formula scripts declare `extends RefCounted` redundantly despite being static-only.

---

## Architecture Document Coverage

`architecture.md` covers all 11 systems from `systems-index.md`, with layer assignment matching the systems index's dependency-consistent layering; data flow section covers all cross-system communication; no orphaned architecture.

**The document is now internally self-contradictory, not merely stale**:
- Its **Document Status** header still reads *"ADRs Referenced: none yet"* / *"Last Updated: 2026-08-09"* — but its own **Module Ownership** and **Data Flow** sections have been hand-patched to cite ADR-0005/0006 findings (dated 2026-08-10).
- Its **ADR Audit** table near the bottom still lists all 11 systems as "❌ GAP, 0 ADR coverage" — stale now that 6 systems + cross-cutting have ADRs.
- Its **Required ADRs** section strikes through ADR-0005/0006 as written but not ADR-0007, which also now exists.

Recommend a full refresh pass on `architecture.md` before it is next used as a reference — not blocking, but actively misleading in its current half-updated state.

---

## Verdict: FAIL

Per the skill's rubric — both FAIL conditions are met again: **Input Abstraction (Foundation layer) still has zero ADR coverage**, and **Conflict 1 is a blocking cross-ADR integration conflict**, now wider (6 undeclared/mismatched method calls across 5 systems, up from 2 in the first pass) rather than narrower.

**Context**: this is progress, not regression. Real coverage rose from ~8% to 45% covered as 3 more ADRs landed; one major engine risk (Light2D/Compatibility) resolved in the project's favor; the true requirement baseline shrank 3x once measured accurately instead of estimated. The remaining FAIL conditions are concrete and well-scoped, not systemic.

### Blocking Issues (must resolve before PASS)

1. **Input Abstraction has no ADR.** Foundation layer; gates Object Placement/Tending Input/Time & Drift's interruption contract. Diorama Rendering's engine gate is now resolved per the specialist consultation, so Gate A (touch/mouse dedup, focus events) is the one genuinely unverified Web-export question left blocking a Foundation-layer ADR.
2. **`SessionBootstrap` integration contract (Conflict 1).** ADR-0002 needs a revision pass reconciling its pseudocode against the actual Key Interfaces of ADR-0001/0003/0004/0005/0006/0007 — 6 mismatched or undeclared calls.
3. **All 7 ADRs still `Proposed`.** Must move to `Accepted` (after fixing #2) before any story can reference them.

### Required ADRs

Prioritized, most foundational first:

1. **Input Abstraction & Web-export touch/focus handling strategy** — ⚠️ gated on Gate A of the verification spike (Gate C effectively resolved this pass)
2. **Diorama Rendering technique under Compatibility/WebGL2 renderer** — engine risk downgraded; can proceed without waiting on further verification, smoke-test recommended at implementation time
3. **Discovery Surfacing reveal-queue & pacing architecture** — snapshot half already resolved by ADR-0002
4. **Ambient Audio bus/volume architecture**
5. **Tending Input command-routing pattern** — small; likely folds into an ADR-0002 amendment

Plus an **ADR-0002 revision pass** (not a new ADR, but effectively as urgent as one) to resolve Conflict 1.
