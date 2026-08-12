# Architecture Traceability Index

Last Updated: 2026-08-11 (fifth review pass)
Engine: Godot 4.7.1

## Coverage Summary

- Total requirements (real per-requirement extraction): 96
- Covered: 68 (70.8%)
- Partial: 13 (13.5%)
- Gaps: 15 (15.6%)

Up from pass 4's 57/68.7%, 11/13.3%, 15/18.1% (out of 83). ADR-0011
(Tending Input) and ADR-0012 (Ambient Audio) now exist, closing the last
two un-ADR'd MVP systems and adding 13 newly ID-registered requirements
(6 for Tending Input, all Covered; 7 for Ambient Audio, 5 Covered/2
Partial). See `docs/architecture/architecture-review-2026-08-11-2.md` for
the full report, cross-ADR conflict detail (including verification of all
5 companion-edit claims these two ADRs make), dependency ordering, and
engine audit.

**All 11 MVP systems now have architectural coverage** — for the first
time in this project's 5-pass review history, no system remains fully
un-ADR'd.

## Full Matrix (system level)

| Requirement ID | GDD | System | ADR Coverage | Status |
|---|---|---|---|---|
| TR-content-data-001..005 | content-data.md | Content Data | ADR-0001 | ✅ Covered |
| TR-input-abstraction-001..007 | input-abstraction.md | Input Abstraction | ADR-0008 | ⚠️ Partial (5 covered / 2 partial) |
| TR-object-placement-001..006 | object-placement.md | Object Placement | ADR-0003 | ✅ Covered |
| TR-ecosystem-simulation-001..005 | ecosystem-simulation.md | Ecosystem Simulation | ADR-0004 | ✅ Covered |
| TR-persistence-save-001..008 | persistence-save.md | Persistence/Save | ADR-0005 | ⚠️ Partial (5 covered / 3 partial) |
| TR-time-drift-001..007 | time-drift.md | Time & Drift | ADR-0006 | ⚠️ Partial (6 covered / 1 partial) |
| TR-creature-behavior-001..007 | creature-behavior.md | Creature Behavior | ADR-0007 | ⚠️ Partial (6 covered / 1 partial) |
| — | tending-input.md | Tending Input | — | ❌ GAP (6 TRs, no ADR) |
| TR-discovery-surfacing-001..010 + TR-crosscutting-002 | discovery-surfacing.md | Discovery Surfacing | ADR-0002 (snapshot) + ADR-0010 (reveal-queue) | ⚠️ Partial (8 covered / 2 partial / 1 gap) |
| TR-diorama-rendering-001..012 | diorama-rendering.md | Diorama Rendering | ADR-0009 | ⚠️ Partial (8 covered / 4 partial) |
| TR-tending-input-001..006 | tending-input.md | Tending Input | ADR-0011 | ✅ Covered (6/6) |
| TR-ambient-audio-001..007 | ambient-audio.md | Ambient Audio | ADR-0012 | ⚠️ Partial (5 covered / 2 partial) |
| TR-crosscutting-001..003 | (cross-cutting) | Event/signal + snapshot + restore-write-path | ADR-0002 | ✅ Covered (all 3 — restore write-path resolved pass 4, see Conflict 1 resolution) |

## Registered Requirement Detail (ID-stable, matches `tr-registry.yaml`)

### Content Data — ADR-0001

| ID | Requirement | ADR Coverage |
|---|---|---|
| TR-content-data-001 | Authoring format decision — `.tres` vs JSON/CSV | ADR-0001 §Decision |
| TR-content-data-002 | Core Rule 1 — unique string `id`, never referenced by file path from gameplay code | ADR-0001 §Decision, registry keyed by `id` |
| TR-content-data-003 | Core Rule 2 — `visual_stages`/`required_ids` as `Array[String]`, not `PackedStringArray` | ADR-0001 Key Interfaces |
| TR-content-data-004 | `definition_validity` must run before a definition is admitted to the registry | ADR-0001 load sequence step 3 |
| TR-content-data-005 | Deterministic, ordinally-sorted `res://` path collection; never resolve via `uid://` | ADR-0001 load sequence step 1 |

### Cross-cutting — ADR-0002

| ID | Requirement | ADR Coverage |
|---|---|---|
| TR-crosscutting-001 | No formal inter-system communication convention existed (event bus vs. direct call vs. signal) | ADR-0002 Decision §1 |
| TR-crosscutting-002 | No owner for Discovery Surfacing's pre-batch snapshot or the 11-step session-start sequence | ADR-0002 Decision §2/§3, `SessionBootstrap` |
| TR-crosscutting-003 | `SessionBootstrap` needs a public, ADR-declared write path into every system it restores state into | ✅ **Covered — resolved pass 4 (2026-08-11).** ADR-0002 was revised (dated 2026-08-10): all 6 `SessionBootstrap._ready()` method calls now match real, declared Key Interfaces — `ContentData.load_registry()` removed (no such method needed), `PersistenceSave.load_blob()`→`load()`+`get_restored_blob()`, `EcosystemSimulation.restore()` and `ObjectPlacement.restore()` added as companion edits to ADR-0004/ADR-0003, `TimeDrift.run_catchup_and_activate()` added to ADR-0006, `CreatureBehavior.settle_from_ecosystem_state()`→`resolve_session_start()` (ADR-0007's real method). Verified directly against each target ADR's own Key Interfaces, not just ADR-0002's claim. |

### Object Placement — ADR-0003

| ID | Requirement | ADR Coverage |
|---|---|---|
| TR-object-placement-001 | Formulas — footprint hit-test, in-bounds ellipse, pairwise overlap, drag-follow position | ADR-0003 `ObjectPlacementMath` |
| TR-object-placement-002 | No `Area2D`/`CollisionShape2D`/physics engine | ADR-0003 Decision, zero scene-tree nodes; re-confirmed physics-free by pass-3 engine specialist |
| TR-object-placement-003 | `grab_offset` preserved for the duration of a drag | ADR-0003 `ObjectState.grab_offset` |
| TR-object-placement-004 | `ObjectTypeDef.footprint_size`/`repositionable` fields consumption | ADR-0003, read via `ContentData.get_definition()` |
| TR-object-placement-005 | `get_position(object_id)`/`is_held(object_id)` API boundaries | ADR-0003 Key Interfaces |
| TR-object-placement-006 | Diorama Rendering reads committed/live `visual_pos`, HELD state, `drag_end` outcome | ADR-0003, no push API needed (poll-based) |

Note: the restore-from-Persistence/Save-blob write path is tracked as
TR-crosscutting-003 (now ✅ Covered, resolved pass 4), not charged against
this system — ADR-0003's own item-level requirements are fully covered.
ADR-0003 now also declares `restore()` in its own Key Interfaces as a
companion edit closing that gap.

### Ecosystem Simulation — ADR-0004

| ID | Requirement | ADR Coverage |
|---|---|---|
| TR-ecosystem-simulation-001 | Formulas — jar moisture (watering + decay), light triangle wave, three-state plant growth, spawn/departure debounce, detail-event gate | ADR-0004 `EcosystemFormulas` |
| TR-ecosystem-simulation-002 | `should_trigger_detail(roll, p_detail)` must be pure/DI'd | ADR-0004 Decision §3, RNG ownership split |
| TR-ecosystem-simulation-003 | Core Rule 11 — plants evaluated before creatures, every tick | ADR-0004 `advance_tick()` orchestration order |
| TR-ecosystem-simulation-004 | Core Rule 12/13 — `last_known_position`/`was_present_during_batch` | ADR-0004 `CreatureState` fields |
| TR-ecosystem-simulation-005 | Pure state owner — exposes state to 5 downstream systems, calls into none | ADR-0004, `EcosystemFormulas`/`_rng` both internal-only |

Note: same as Object Placement — restore write-path tracked separately as
TR-crosscutting-003 (now ✅ Covered, resolved pass 4). ADR-0004 now also
declares `restore()` in its own Key Interfaces as a companion edit.

### Persistence/Save — ADR-0005

| ID | Requirement | Status |
|---|---|---|
| TR-persistence-save-001 | Save blob schema — full field list (Core Rule 1) | ⚠️ Partial — field list never enumerated in ADR's own GDD Requirements table |
| TR-persistence-save-002 | `save_blob_validity` gate — all-or-nothing validation, evaluation order, two-tier fallback | ⚠️ Partial — not isolated as a testable pure-formula script per project convention |
| TR-persistence-save-003 | Web storage backend & write reliability at session end/backgrounding | ✅ Covered — `localStorage` + `HideBridge` |
| TR-persistence-save-004 | Cross-system restore sequencing/API | ✅ Covered — resolved pass 4 alongside TR-crosscutting-003; `get_restored_blob()` is the declared pull point, `EcosystemSimulation.restore()`/`ObjectPlacement.restore()` are the declared write paths |
| TR-persistence-save-005 | No periodic autosave / gesture-triggered mirror refresh | ✅ Covered |
| TR-persistence-save-006 | Save-confirmation cue signal to Diorama Rendering | ✅ Covered |
| TR-persistence-save-007 | Non-Web/editor dev fallback persistence path | ✅ Covered |
| TR-persistence-save-008 | Storage size/performance budget | ✅ Covered |

### Time & Drift — ADR-0006

| ID | Requirement | Status |
|---|---|---|
| TR-time-drift-001 | Tick-batching/catch-up model (Core Rules 2–6) | ✅ Covered |
| TR-time-drift-002 | `last_visit_timestamp` update semantics at session boundaries (Core Rule 8) | ✅ Covered |
| TR-time-drift-003 | Cosmetic `day_night_phase` computation (Core Rule 7) | ✅ Covered |
| TR-time-drift-004 | SessionBootstrap integration/init ordering | ✅ Covered (though the exact step number it cites drifts against ADR-0002/ADR-0007 — see Conflict A) |
| TR-time-drift-005 | State machine exposure to dependents | ✅ Covered |
| TR-time-drift-006 | Unix-timestamp float/int type safety | ✅ Covered |
| TR-time-drift-007 | bfcache/`pageshow` reload-guard dependency on ADR-0005's JS layer | ⚠️ Partial — prose constraint only, no enforcement |

### Creature Behavior — ADR-0007

| ID | Requirement | Status |
|---|---|---|
| TR-creature-behavior-001 | Wander state machine & per-instance data structure | ✅ Covered |
| TR-creature-behavior-002 | PRESENT/ABSENT transition detection (pull-based) | ✅ Covered |
| TR-creature-behavior-003 | Session-start entry / Core Rule 8 CATCHING_UP-suppression | ✅ Covered, documented fragility (relies on `_ready()`-before-first-`_process()` ordering — confirmed correct by pass-3 engine specialist, but breaks if `await`/`call_deferred()`/`Thread` ever enters `SessionBootstrap._ready()`) |
| TR-creature-behavior-004 | Movement/destination-sampling/pause-duration pure formulas | ✅ Covered |
| TR-creature-behavior-005 | `set_last_known_position()` write-only call-in | ✅ Covered |
| TR-creature-behavior-006 | Per-frame diff-poll performance budget at MVP scale | ✅ Covered |
| TR-creature-behavior-007 | Object Placement footprint read as movement obstacle | ⚠️ Partial — population path never shown in Key Interfaces |

### Input Abstraction — ADR-0008 (new this pass)

| ID | Requirement | Status |
|---|---|---|
| TR-input-abstraction-001 | Core Rules 1-3 — raw event capture, 4-gesture translation, tap-vs-drag classification | ✅ Covered — `_unhandled_input()` + per-pointer state machine |
| TR-input-abstraction-002 | Core Rule 4 — true jar-local coordinate conversion | ✅ Covered — `register_jar()` DI + `_to_jar_local()` |
| TR-input-abstraction-003 | Core Rules 5/7 — single-active-pointer arbitration, mouse/touch dedup | ✅ Covered — tagged `(source, id)` internal state |
| TR-input-abstraction-004 | Core Rule 7a — same-`device_id` re-press as implicit release-then-press | ⚠️ Partial — not mentioned anywhere in the ADR; architecturally implied, not called out |
| TR-input-abstraction-005 | Core Rule 8 — pointer interruption forces IDLE, cancels active drag | ✅ Covered — focus signal + stale-pointer watchdog |
| TR-input-abstraction-006 | Open Question [BLOCKING] — empirical Web-export focus/touch-dedup verification | ⚠️ Partial — explicitly not resolved by this ADR; watchdog is a mitigation, not a fix |
| TR-input-abstraction-007 | Signal contract formalization for Object Placement/Tending Input consumers | ✅ Covered — Key Interfaces defines exact signatures |

### Diorama Rendering — ADR-0009 (new this pass)

| ID | Requirement | Status |
|---|---|---|
| TR-diorama-rendering-001 | Core Rule 1 — pure read-only observer | ✅ Covered |
| TR-diorama-rendering-002 | Core Rules 2/2a/10 — discrete stage rendering, Catch-up Growth Reveal, silhouette scaling | ✅ Covered |
| TR-diorama-rendering-003 | Core Rule 3 — per-plant STALLED cue, every frame | ✅ Covered |
| TR-diorama-rendering-004 | Core Rule 4 — repositionable object rendering | ✅ Covered |
| TR-diorama-rendering-005 | Core Rule 5 — live creature position rendering | ⚠️ Partial — only in the Architecture Diagram comment, no Key Interfaces stub, not in the GDD Requirements table |
| TR-diorama-rendering-006 | Core Rule 6 — snap-back/wobble eased tweens, kill-and-restart | ✅ Covered |
| TR-diorama-rendering-007 | Core Rule 7 — Discovery Surfacing cue execution, per-category Light2D lifecycle | ✅ Covered, now ratified against ADR-0010's concrete shape |
| TR-diorama-rendering-008 | Core Rule 8 — day/night CanvasModulate, cosmetic-only | ✅ Covered |
| TR-diorama-rendering-009 | Core Rule 9 — fully-resolved first frame, no loading state | ✅ Covered — resolved pass 4; the session-start ordering guarantee it depends on (TR-crosscutting-003) is now itself resolved |
| TR-diorama-rendering-010 | Core Rule 11 — Watering Substrate Sheen | ⚠️ Partial — only mentioned in passing in a generic tween list, absent from the ADR's own GDD Requirements table |
| TR-diorama-rendering-011 | Open Question 1 [BLOCKING] — Light2D/Compatibility-renderer verification | ⚠️ Partial — feature confirmed to work by engine specialist (twice now, pass 2 and pass 3); asset fidelity/frame-budget empirical verification (Gate C1/C4) still open |
| TR-diorama-rendering-012 | `register_jar()` cross-ADR wiring shared with ADR-0008 | ✅ Covered |

### Discovery Surfacing (reveal-queue half) — ADR-0010 (new this pass)

| ID | Requirement | Status |
|---|---|---|
| TR-discovery-surfacing-001 | Core Rule 1 — delta computed exactly once, at CATCHING_UP→ACTIVE | ✅ Covered |
| TR-discovery-surfacing-002 | Core Rules 2/3 — 4-category classification, first-session empty-delta case | ⚠️ Partial — categorization mechanism implied but not explicit; first-session case undiscussed |
| TR-discovery-surfacing-003 | Core Rule 2a — `full_cycle` exception | ✅ Covered |
| TR-discovery-surfacing-004 | Core Rules 4/4a — staggered/overlapping timing, focus-pause | ✅ Covered |
| TR-discovery-surfacing-005 | Core Rules 5/6 — per-element cue target, fixed fade duration | ✅ Covered |
| TR-discovery-surfacing-006 | Core Rule 7 — Departure position source | ✅ Covered |
| TR-discovery-surfacing-007 | Core Rule 8 — deterministic queue ordering | ✅ Covered |
| TR-discovery-surfacing-008 | Core Rule 9 — never blocks/gates gameplay input | ⚠️ Partial — implied by read-only design, never explicitly asserted |
| TR-discovery-surfacing-009 | `get_active_items()` interface ratification for Diorama Rendering | ✅ Covered |
| TR-discovery-surfacing-010 | Tuning Knobs — `pacing_delay`/`cue_fade_duration` must be data-driven | ❌ **Gap** — not addressed anywhere in the ADR |

(TR-crosscutting-002, the snapshot-ownership half, is registered separately
under Cross-cutting/ADR-0002 above and continues to hold Covered status —
not re-counted here.)

### Tending Input — ADR-0011 (new pass 5)

| ID | Requirement | Status |
|---|---|---|
| TR-tending-input-001 | Core Rule 1 — tap in bounds, not on footprint, triggers watering | ✅ Covered — `_on_tap()`'s two guard checks |
| TR-tending-input-002 | Core Rules 2/3 — exactly-once call, no batching, no deferred/await | ✅ Covered — direct signal connection, single call site |
| TR-tending-input-003 | Core Rule 4 — stateless, no cooldown | ✅ Covered — zero persisted fields |
| TR-tending-input-004 | AC1 — configured `watering_amount`, never hardcoded | ✅ Covered — new `EcosystemSimulation.get_watering_amount()` |
| TR-tending-input-005 | Edge Cases — no-objects/boundary-inclusive exclusion, no error | ✅ Covered — `is_within_any_footprint()` |
| TR-tending-input-006 | Structural init-order guarantee | ✅ Covered — documented as autoload-declaration-order requirement |

### Ambient Audio — ADR-0012 (new pass 5)

| ID | Requirement | Status |
|---|---|---|
| TR-ambient-audio-001 | Core Rule 1/1a — zero-delay `play()`, `PENDING_GESTURE` autoplay handling | ✅ Covered — `_process()` edge-detect + self-disabling `_input()` hook |
| TR-ambient-audio-002 | Core Rules 3/4 — reactive layer triggers | ✅ Covered — new `watering_applied` signal + `get_active_items()` poll |
| TR-ambient-audio-003 | Core Rule 7 — persisted `ambient_volume`/`muted` | ✅ Covered — first-`_process()` poll + new `refresh_mirror()` write path |
| TR-ambient-audio-004 | Formulas — pure functions, `t` as explicit parameter | ✅ Covered — `AmbientAudioMath`, manual accumulation |
| TR-ambient-audio-005 | Core Rule 6 — never blocks gameplay input | ✅ Covered |
| TR-ambient-audio-006 | UI Requirements — locked mute/volume control box | ⚠️ Partial — wiring decided, actual control construction deferred to future `/ux-design` |
| TR-ambient-audio-007 | Recommended Gate D — pre-gesture `play()` catch-up | ⚠️ Partial — recommended, not yet added to `web-export-verification-plan.md` |

## Known Gaps

**RESOLVED pass 5 (2026-08-11)**: Tending Input and Ambient Audio — the
last two fully un-ADR'd systems — are now covered by ADR-0011/ADR-0012.
All 5 companion-edit claims these two ADRs make against ADR-0003/0004/
0005/0009 were independently verified present in each target ADR's own
file (first fully clean companion-edit batch in this project's history).

**RESOLVED pass 4 (2026-08-11)**: TR-crosscutting-003 — `SessionBootstrap`'s
restore write-path, open across 3 consecutive passes, is now declared by
ADR-0002 (revised) and companion edits to ADR-0003/0004/0006/0007. See
Conflict 1 resolution in `architecture-review-2026-08-11.md`.

**Still open, 2 passes running**: ADR-0008 incorrectly states ADR-0003 is
"already Accepted" — every ADR in this project (including ADR-0003) is
still `Status: Proposed`. Text-only fix, recommended pass 4 and pass 5,
still unapplied.

**New minor finding, pass 5**: ADR-0012 recommends a "Gate D" verification
pass but `docs/technical-setup/web-export-verification-plan.md` (which
tracks Gates A/B/C by name) was never updated to include it.

**Remaining Partial/Gap items worth story-writer attention**: Input
Abstraction's Core Rule 7a (TR-input-abstraction-004) and its BLOCKING
empirical-verification Open Question (TR-input-abstraction-006); Diorama
Rendering's creature-rendering Core Rule 5 (TR-diorama-rendering-005),
Watering Sheen (TR-diorama-rendering-010), and its own BLOCKING Light2D
verification Open Question (TR-diorama-rendering-011); Discovery
Surfacing's data-driven Tuning Knobs gap (TR-discovery-surfacing-010);
Ambient Audio's UI control construction (TR-ambient-audio-006) and Gate D
(TR-ambient-audio-007).

## Superseded Requirements

None — no GDD has been revised in a way that supersedes an already-ID-registered
requirement as of this review.

## History

| Date | Full Coverage % | Notes |
|------|-----------------|-------|
| 2026-08-10 (pass 1) | ~8% Covered / ~30% Partial / ~62% Gap (rough estimate) | Initial index — 4 ADRs (all `Proposed`), 1 blocking conflict found (`restore()` contract gap, 2 methods) |
| 2026-08-10 (pass 2) | 45% Covered / 7.5% Partial / 47.5% Gap (real extraction, 80-item baseline) | 7 ADRs (all `Proposed`). First real per-requirement extraction. Conflict 1 escalated (6 methods, 5 ADRs) rather than resolved by ADR-0005. Diorama Rendering's Light2D/Compatibility engine risk resolved favorably per engine specialist consultation. |
| 2026-08-10 (pass 3) | 66.3% Covered / 15.7% Partial / 18.1% Gap (real extraction, 83-item baseline) | 10 ADRs (all still `Proposed`). Input Abstraction, Diorama Rendering, and Discovery Surfacing's reveal-queue half went from pure Gap to mostly Covered. Conflict 1 (TR-crosscutting-003) confirmed still open — 3rd pass in a row, ADR-0002 never revised. New correction: Tending Input and Ambient Audio still lack ADRs — architecture.md's own Required ADRs list was never fully closed out. `architecture.md` itself confirmed severely stale (still claims 0% ADR coverage). Verdict: FAIL. |
| 2026-08-11 (pass 4) | 68.7% Covered / 13.3% Partial / 18.1% Gap (same 83-item baseline, no new ADRs written) | Still 10 ADRs (all still `Proposed` — no ADR has ever reached Accepted). **Conflict 1 (TR-crosscutting-003) resolved** — ADR-0002 was actually revised this pass, verified against every downstream ADR's own Key Interfaces, not just claimed. Conflict D (ADR-0009's stale "provisional" wording) also resolved. New minor finding: ADR-0008 wrongly calls ADR-0003 "Accepted." Tending Input and Ambient Audio still lack ADRs (unchanged, Feature/Presentation tier, non-blocking to verdict). `architecture.md` and `docs/consistency-failures.md` both still stale relative to these resolutions. Verdict: **CONCERNS** — first non-FAIL verdict across 4 passes. |
| 2026-08-11 (pass 5) | 70.8% Covered / 13.5% Partial / 15.6% Gap (96-item baseline, +13 new) | 12 ADRs (all still `Proposed`). ADR-0011 (Tending Input) and ADR-0012 (Ambient Audio) close the last two un-ADR'd systems — **all 11 MVP systems now have architectural coverage**. All 5 companion-edit claims verified actually applied (first fully clean batch in project history). No new conflicts, no dependency cycles. ADR-0008's "already Accepted" claim about ADR-0003 still unfixed (2nd consecutive pass). `architecture.md` now off by 12 ADRs (worse than pass 4's gap of 10). New minor: ADR-0012's recommended Gate D not yet added to the verification plan doc. Verdict: **CONCERNS** — unchanged tier, advanced substance. |
