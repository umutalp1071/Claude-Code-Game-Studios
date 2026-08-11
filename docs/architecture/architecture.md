# Terrarium — Master Architecture

## Document Status
- Version: 0.2 (refreshed — see note below)
- Last Updated: 2026-08-11
- Engine: Godot 4.7.1 (Web export, Compatibility/OpenGL ES3/WebGL2 renderer)
- GDDs Covered: content-data, input-abstraction, object-placement, ecosystem-simulation, tending-input, time-drift, creature-behavior, persistence-save, discovery-surfacing, diorama-rendering, ambient-audio (all 11 MVP systems, all Approved)
- ADRs Referenced: **12 ADRs exist** (ADR-0001 through ADR-0012) — **11 Accepted** (2026-08-11, Technical Setup → Pre-Production gate re-check), **1 Proposed**: ADR-0009 (Diorama Rendering) held pending Gate C4's still-missing frame-budget measurements (0 data points on any device, mobile included) — see `docs/technical-setup/web-export-verification-plan.md`. Full detail: `docs/architecture/architecture-traceability-index.md`.
- Technical Director Sign-Off: 2026-08-09 — APPROVED WITH CONDITIONS (sound architecture; the 3
  Foundation-layer ADRs — Content Data authoring format, cross-cutting signal/init-order/snapshot
  architecture, Input Abstraction Web-export strategy — must be written before implementation begins).
  **All 3 since written and Accepted** (ADR-0001, ADR-0002, ADR-0008).
- Lead Programmer Feasibility: LP-FEASIBILITY skipped — Lean mode (not a PHASE-GATE)
- **Refresh note (2026-08-11)**: this section and the ADR Audit section below were severely stale
  across 4 consecutive `/architecture-review` passes — still claiming "no ADRs yet" / 0% coverage
  against ~240 baseline requirements after 10, then 12, real ADRs existed. Refreshed as part of the
  Technical Setup → Pre-Production gate-check's mechanical-fixes pass. The rest of this document
  (System Layer Map, Module Ownership, Data Flow, API Boundaries) was kept current throughout by
  individual ADR authors cross-referencing it directly — only this status/audit framing had rotted.

## Engine Knowledge Gap Summary

Engine is Godot 4.7.1, ~2 years past the LLM's training cutoff (~4.3). Three
domains are HIGH RISK and already carry unresolved, project-flagged
verification gates (see `docs/technical-setup/web-export-verification-plan.md`):

- **Input** (Web export `focus_exited`/`visibilitychange` reliability, touch/
  mouse-emulation dedup) — affects Input Abstraction, Time & Drift, Discovery
  Surfacing.
- **Save/Load** — **resolved for Chromium by ADR-0005** (Web Export Spike Gate B,
  desktop Chrome only): `IndexedDB`/`FileAccess` dropped for Web in favor of
  `localStorage` via `JavaScriptBridge`. WebKit/iOS Safari remains an unverified,
  named residual risk — affects Persistence/Save.
- **Rendering** (`Light2D`/2D glow support under the Compatibility/WebGL2
  renderer, possibly contradicted by general Godot docs) — affects Diorama
  Rendering.

User decision (2026-08-09): proceed with architecture for all systems now;
the three affected systems' ADRs will be written as provisional/gated pending
the verification spike, not blocked entirely.

## System Layer Map

```
┌─────────────────────────────────────────────────────────────┐
│ PRESENTATION  Discovery Surfacing · Diorama Rendering ⚠️     │
│               · Ambient Audio                                │
├─────────────────────────────────────────────────────────────┤
│ FEATURE       Tending Input · Time & Drift ⚠️ · Creature     │
│               Behavior · Persistence/Save ⚠️                 │
├─────────────────────────────────────────────────────────────┤
│ CORE          Object Placement · Ecosystem Simulation        │
├─────────────────────────────────────────────────────────────┤
│ FOUNDATION    Content Data · Input Abstraction ⚠️            │
├─────────────────────────────────────────────────────────────┤
│ PLATFORM      Godot 4.7.1 · Web export (Compatibility/WebGL2 │
│               renderer, JavaScriptBridge, IndexedDB user://) │
└─────────────────────────────────────────────────────────────┘
```
⚠️ = touches a HIGH RISK engine domain (see Engine Knowledge Gap Summary)

Reused from `design/gdd/systems-index.md`'s own dependency-consistent layer
assignment (validated against the actual dependency graph during design)
rather than re-derived, with a Platform layer added beneath it.

**Module boundaries per layer:**
- **Foundation** — Content Data owns the read-only type registry (plants/
  creatures/objects); Input Abstraction owns raw-input→gesture translation.
  Neither depends on anything.
- **Core** — Object Placement owns object position/HELD-state; Ecosystem
  Simulation owns `jar_moisture`/`light_level`/per-plant `growth_stage`/
  per-creature PRESENT-ABSENT state — the layer everything gameplay-facing
  is built on.
- **Feature** — Tending Input is a stateless router into Ecosystem
  Simulation; Time & Drift owns session lifecycle and the tick/catch-up-batch
  clock; Creature Behavior owns live creature instances/movement;
  Persistence/Save owns the save blob and cross-session continuity.
- **Presentation** — Discovery Surfacing computes the "what changed" delta
  and reveal queue; Diorama Rendering is the pure read-only visual layer;
  Ambient Audio is the pure read-only audio layer. None of the three has
  downstream dependents.

## Module Ownership

**Foundation**

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Content Data | In-memory type registry (Plant/Creature/ObjectTypeDef), keyed by `id` | `get_definition(id)` query, `null` on miss | — | `Resource`/`.tres` load, `ResourceLoader.load(..., CACHE_MODE_IGNORE)` / `duplicate_deep()` (4.5+, low risk), `Array[String]` — not `PackedStringArray` (4.7 packed-array setter change), `push_warning()` |
| Input Abstraction | Per-`device_id` pointer state machine (IDLE/PRESSED/DRAGGING) | `tap`/`drag_start`/`drag_move`/`drag_end` events (`position`, `delta`, `device_id`, `canceled`) | — | `InputEvent.DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD` (4.7, confirmed) · ⚠️ `Window.focus_exited`/`focus_entered` on Web export (unverified) · `to_local()` jar-space conversion |

**Core**

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Object Placement | Object position, HELD state, `grab_offset` | Live/committed position for rendering; footprint query | Input Abstraction, Content Data | Pure `Vector2` math — deliberately no `Area2D`/`CollisionShape2D`, no physics engine |
| Ecosystem Simulation | `jar_moisture`, `light_level`/`light_direction`, per-plant `growth_stage`/`optimal_hold_ticks`, per-creature PRESENT/ABSENT/`condition_streak_ticks`/`last_known_position`/`was_present_during_batch` | `apply_watering()`, `advance_tick()`, `set_last_known_position()`, state queries | Content Data | Pure GDScript; RNG injected as a parameter (`should_trigger_detail(roll,...)`), never read from engine RNG directly — keeps it unit-testable per `coding-standards.md` |

**Feature**

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Tending Input | Nothing (fully stateless) | Watering-trigger event (for soft consumers) | Input Abstraction, Object Placement → calls Ecosystem Simulation | None — synchronous calls only, no `call_deferred`/`await` in the tap→water→cue path |
| Time & Drift | Session state machine (INACTIVE/CATCHING_UP/ACTIVE), `day_night_phase` | State query, `day_night_phase` | Calls Ecosystem Simulation; delegates `last_visit_timestamp` storage to Persistence/Save | `Time.get_unix_time_from_system()` · ⚠️ `JavaScriptBridge` for `visibilitychange`/unload (unverified) |
| Creature Behavior | Live creature instance position + sub-state (transient only — never persisted) | Live position/state per instance | Ecosystem Simulation (read + `set_last_known_position` call-in), Content Data, Object Placement (soft), Time & Drift | `Node2D`, `_process(delta)` frame movement, `RandomNumberGenerator` |
| Persistence/Save | Save blob (`current` + `last-known-good`), `schema_version` | Read/write API, restore-on-load | Content Data (validation), reads/writes every Feature+Core system's persisted fields | `localStorage` via `JavaScriptBridge.eval()` — sole Web-export storage backend per ADR-0005 (Web Export Spike Gate B, Chrome desktop). Verified reliable on Chromium; ⚠️ WebKit/iOS Safari unverified (named residual risk, see ADR-0005 Consequences). `FileAccess`/`user://` retained only for non-Web/editor dev, never shipped on Web. |

**Presentation**

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| Discovery Surfacing | Per-session discovery item queue (transient) | Active item(s) | Ecosystem Simulation, Time & Drift (transition + ⚠️ focus-paused clock) | Per-frame timer evaluation against `activation_time`/`fade_end_time`; shares the Input focus-event risk |
| Diorama Rendering | Nothing persisted; per-frame tween references | Nothing (leaf) | Content Data, Object Placement, Ecosystem Simulation, Creature Behavior, Time & Drift, Discovery Surfacing, Tending Input | `Tween`, `CanvasModulate`, `Gradient`, `Node2D.scale` (safe) · ⚠️ `Light2D` + normal maps under Compatibility renderer (unverified) |
| Ambient Audio | `ambient_volume`/`muted` (persisted, outside the strict save-validity gate) | Nothing (leaf) | Tending Input, Discovery Surfacing, Time & Drift, Persistence/Save (all soft) | `AudioStreamPlayer`, `AudioStreamOggVorbis`, `AudioServer.set_bus_mute()` — browser gesture-unlock race is generic, not a Godot-version risk |

**Dependency diagram** (arrows = "depends on / calls into"):

```
Presentation:  DiscoverySurfacing  DioramaRendering  AmbientAudio
                      │                  │  ▲             │
                      ▼                  ▼  │             ▼
Feature:       TendingInput   TimeAndDrift  CreatureBehavior  PersistenceSave
                    │              │              │                │
                    ▼              ▼              ▼                ▼
Core:          ObjectPlacement ◄──────── EcosystemSimulation ──────┘
                    │                          │
                    ▼                          ▼
Foundation:    InputAbstraction           ContentData
```

Note: Diorama Rendering reads Creature Behavior's live position every frame
(upward-looking arrow shown), but Creature Behavior never calls into Diorama
Rendering — this is a one-way read, not a violation of layering.

## Data Flow

**1. Frame update path** (steady-state, during ACTIVE):

```
OS input event
  → Input Abstraction: raw event → gesture (tap / drag_start / drag_move / drag_end)
       → Object Placement: drag_* on a footprint → HELD position update / commit / snap-back
       → Tending Input: tap off any footprint → EcosystemSimulation.apply_watering()  [sync call, live]
Creature Behavior._process(delta): move each live instance
       → EcosystemSimulation.set_last_known_position(id, pos)  [sync call-in, every live frame]
Diorama Rendering._process: read ObjectPlacement.position, EcosystemSimulation.{growth_stage,
       light_level, jar_moisture}, CreatureBehavior.{position,state}, TimeAndDrift.day_night_phase,
       DiscoverySurfacing.active_item → render (no writes back)
Ambient Audio._process: read TendingInput's watering-trigger event / DiscoverySurfacing's active
       cue set → adjust volume_db (no writes back)
```
All of this is synchronous, same-frame — no `call_deferred`/`await` anywhere in the tap→water→cue
chain (explicit GDD requirement).

**2. Event/signal path** — this project uses **direct typed calls, not a generic event bus**:
Ecosystem Simulation exposes command methods (`apply_watering()`, `advance_tick()`,
`set_last_known_position()`) that Feature-layer systems call directly; Input Abstraction emits
Godot signals for gestures, consumed directly by Object Placement/Tending Input. No central
event-bus/mediator exists anywhere in the 11 GDDs. **This absence is itself a decision that needs
an ADR** — flagged in Required ADRs below, since every future system will otherwise default to
whatever pattern gets implemented first.

**3. Save/load path** (mechanism decided by ADR-0005 — Chromium-verified, WebKit unverified):
```
Session start:
  1. Content Data loads registry (no deps)
  2. Persistence/Save.load(): localStorage 'save_current' → validate → (fail) 'save_last_known_good'
     → validate → (fail) defaults [validates type_ids against Content Data's registry from step 1].
     get_restored_blob() exposes the result for steps 3/4 to pull from (ADR-0005 Key Interfaces).
  3. Ecosystem Simulation restores: jar_moisture, light_level/direction, per-plant growth_stage/
     optimal_hold_ticks, per-creature state/condition_streak_ticks/last_known_position
  4. Object Placement restores: object position
  5. ⚠️ SNAPSHOT POINT: Discovery Surfacing needs a pre-batch snapshot of step 3's state — must be
     captured here, before step 6 runs. No GDD specifies the snapshot mechanism (deep copy vs.
     replay log) — flagged as a Required ADR below.
  6. Time & Drift: fetch last_visit_timestamp via Persistence → compute ticks_to_apply →
     EcosystemSimulation.advance_tick() × N as one atomic batch (state: CATCHING_UP)
     [Creature Behavior suppressed — no live instances, no SPAWNING/DEPARTING animation]
  7. Time & Drift → ACTIVE
  8. Creature Behavior queries settled PRESENT/ABSENT once, spawns live instances for PRESENT
     (skips SPAWNING animation for anything resolved during the batch)
  9. Discovery Surfacing computes delta = post-batch state (step 8's result) vs. step 5's snapshot
  10. First frame renders fully-resolved state — no loading frame, no placeholder data
  11. Persistence/Save's save-confirmation cue fires (only if a blob was actually restored in step 2)

Session end / backgrounding (mechanism split by trigger, per ADR-0005 — NOT symmetric):
  - True close/unload: Persistence/Save.save() gathers current state from Ecosystem Simulation +
    Object Placement + Time & Drift's last_visit_timestamp, writes to localStorage 'save_current'
    via JavaScriptBridge.eval(), promotes the outgoing blob to 'save_last_known_good' first if it
    was itself known-valid. GDScript-executed, foregrounded — no reachability risk.
  - visibilitychange→hidden OR pagehide: handled ENTIRELY by a pure-JS listener (HideBridge),
    zero GDScript execution — writes the JS-side mirror (kept current via the tap/drag_end hook
    below, not just at session end) to 'save_current', same promotion logic in plain JS. This is
    the ADR-0005 design point: the backgrounding write no longer depends on the WASM main loop
    getting a frame while hidden, which Web Export Spike Gate A/B evidence never established either
    way for WebKit (Chromium only).
  - Input Abstraction's tap/drag_end signals (existing contract, no new signal) also trigger a
    cheap JS-side mirror refresh — NOT a storage write — so the backgrounding write above reflects
    the current visit's state, not stale data from the last true session end (ADR-0005 Decision).
```

**4. Initialization order**:

**Corrected 2026-08-10** (part of ADR-0002's revision, TR-crosscutting-003):
this list previously numbered Time & Drift as one step, while §3 above
numbers it as two (catch-up, then the `CATCHING_UP → ACTIVE` transition) —
that mismatch is exactly why ADR-0007 once cited "step 7" for Creature
Behavior while §3 and ADR-0002's `SessionBootstrap` pseudocode both say
step 8. Split to match §3 step-for-step; ADR-0002's own Constraints
section already requires these two sections "must not diverge."
```
1. Content Data           (no deps)
2. Persistence/Save       (needs Content Data, for type_id validation)
3. Ecosystem Simulation   (needs Content Data; restores from Persistence or defaults)
4. Object Placement       (needs Content Data; restores from Persistence or defaults)
5. [snapshot for Discovery Surfacing — see Data Flow §3]
6. Time & Drift catch-up  (needs Ecosystem Simulation ready before calling advance_tick())
7. Time & Drift → ACTIVE  (transition only, same call as step 6 — ADR-0006's
                           run_catchup_and_activate() performs both atomically)
8. Creature Behavior      (needs Time & Drift = ACTIVE, Ecosystem Simulation settled state)
9. Input Abstraction      (independent, but Tending Input/Object Placement must not process
                           input until steps 1–4 complete)
10. Discovery Surfacing    (needs steps 5 + 8 both complete)
11. Diorama Rendering / Ambient Audio (need everything above resolved — first frame is fully caught up)
```

## API Boundaries

Public contracts, in GDScript-style signatures (per `technical-preferences.md`). `Vector2`/
`Resource`/`Signal` are all stable pre-cutoff Godot types — no version risk to flag on any of them.

```gdscript
# Content Data (autoload) — Foundation
func get_definition(id: String) -> Resource  # PlantTypeDef/CreatureTypeDef/ObjectTypeDef, or null
# Invariant: registry fully loaded before any other system initializes.
# Guarantee: returned Resource is read-only by convention (not enforced — see content-data.md Core Rule 2).

# Input Abstraction (autoload) — Foundation
signal tap(position: Vector2, device_id: int)
signal drag_start(position: Vector2, device_id: int)
signal drag_move(position: Vector2, delta: Vector2, device_id: int)
signal drag_end(position: Vector2, canceled: bool, device_id: int)
# Invariant: position is always already jar-local (converted internally via to_local()).
# Guarantee: exactly one active device_id at a time; a second device_id is silently ignored.

# Object Placement — Core
func get_position(object_id: String) -> Vector2
func is_held(object_id: String) -> bool
func restore(restored_blob: Dictionary) -> void   # ADR-0002 companion edit (2026-08-10) — called ONLY by SessionBootstrap, step 4
# Consumes Input Abstraction's signals directly; no public RUNTIME write API beyond
# restore() (one-time bootstrap population, never overlaps the signal-driven path) — see ADR-0003.

# Ecosystem Simulation (autoload) — Core, the central state owner
func apply_watering(amount: int) -> void          # called by Tending Input, live/synchronous
func advance_tick() -> void                       # called ONLY by Time & Drift
func restore(restored_blob: Dictionary) -> void   # ADR-0002 companion edit (2026-08-10) — called ONLY by SessionBootstrap, step 3
func set_last_known_position(creature_id: String, pos: Vector2) -> void  # called by Creature Behavior
func get_jar_moisture() -> int
func get_light_level() -> int
func get_growth_stage(plant_id: String) -> int
func get_creature_state(creature_id: String) -> CreatureState.Presence  # enum {PRESENT, ABSENT}, per ADR-0004 — CreatureState itself is the RefCounted registry-value class (state/condition_streak_ticks/last_known_position/was_present_during_batch), not the enum
func get_last_known_position(creature_id: String) -> Vector2
# Invariants: jar_moisture/light_level always clamped [0,100]; growth_stage always clamped [0,max_stage].
# Guarantee: NEVER calls outward to any other system — pure command/query state owner (per every GDD's
# "Ecosystem Simulation exposes state to N downstream systems but calls into none" statement).

# Time & Drift (autoload) — Feature
func get_state() -> SessionState  # enum {INACTIVE, CATCHING_UP, ACTIVE}
func get_day_night_phase() -> float  # 0.0–1.0
func run_catchup_and_activate() -> void  # ADR-0002 companion edit (2026-08-10) — called ONLY by SessionBootstrap, steps 6-7
# Invariant: strictly INACTIVE→CATCHING_UP→ACTIVE→INACTIVE, no skipped or reordered transitions.
# Guarantee: the advance_tick() batch fully completes before ACTIVE is ever observable to a consumer.

# Creature Behavior — Feature
func get_position(creature_id: String) -> Vector2
func get_state(creature_id: String) -> WanderState  # {SPAWNING, WANDERING, PAUSING, DEPARTING}
# Invariant: only meaningful for a creature Ecosystem Simulation currently reports PRESENT — no live
# instance, and therefore no valid position/state, exists for an ABSENT creature.

# Persistence/Save (autoload) — Feature
func save() -> void          # ADR-0005: triggered ONLY by true session end — NOT by visibilitychange/
                              # pagehide, which is handled entirely by a pure-JS listener instead (see
                              # Data Flow §3). Public signature unchanged from the pre-ADR sketch.
func load() -> bool          # true iff a validated blob was restored
func get_restored_blob() -> Dictionary  # ADR-0005, new — SessionBootstrap pulls typed fields from
                                          # this at Data Flow §3/§4 steps 3/4, per ADR-0004's already-
                                          # established bootstrap-populates-registries pattern
func get_last_visit_timestamp() -> int
func set_last_visit_timestamp(ts: int) -> void   # called ONLY by Time & Drift, only on true session end
# Guarantee: load() either fully restores a validated blob, or returns false and leaves every system
# at its authored default — partial restore is structurally disallowed.

# Discovery Surfacing — Presentation
func get_active_items() -> Array[DiscoveryItem]
# Invariant: computed exactly once per session (at CATCHING_UP→ACTIVE), immutable afterward.
# Guarantee: never blocks, delays, or alters gameplay input handling.

# Diorama Rendering, Ambient Audio — Presentation
# No public API — pure leaf consumers. Nothing in the project calls into either;
# they only read the interfaces above from their own _process()/_draw().
```

**Cross-cutting invariant worth naming explicitly**: every autoload above is a singleton with
exactly one instance — nothing in any GDD models multiple jars or multiple creature instances of
the same type (flagged as a real Alpha-tier assumption in `content-data.md`'s own Open Questions).
The architecture as designed does **not** support that yet; scaling to multi-jar is out of scope
for this document.

## ADR Audit

**Refreshed 2026-08-11** — this section previously read "contains no ADRs yet... Nothing to audit"
against a 0-of-~240 baseline, unchanged and increasingly wrong across 4 consecutive
`/architecture-review` passes while 12 real ADRs were written. Current state, per the 5th
`/architecture-review` pass (`docs/architecture/architecture-review-2026-08-11-2.md`) and the
traceability index (`docs/architecture/architecture-traceability-index.md`), both authoritative —
this table is a summary, not the source of truth.

**ADR Quality Check**: 12 ADRs exist. All 12 have Engine Compatibility sections stamped with the
pinned engine version, GDD Requirements Addressed tables, and ADR Dependencies sections. No
deprecated API usage, no stale version references, no dependency cycles (full topological order in
the architecture-review report). 11 are `Accepted`; ADR-0009 (Diorama Rendering) remains `Proposed`,
held pending Gate C4's still-unmeasured frame budget.

**Traceability Coverage Check**: 96 real per-requirement TRs extracted (up from the ~240 rough
estimate at this document's original authoring, before per-requirement extraction methodology
existed) — 68 Covered (70.8%), 13 Partial (13.5%), 15 Gap (15.6%). Zero Foundation-layer Gap-status
requirements.

| System | TRs | ADR Coverage | Status |
|---|---|---|---|
| Content Data | 5 | ADR-0001 | ✅ Covered |
| Input Abstraction | 7 | ADR-0008 | ⚠️ Partial (5 covered / 2 partial) |
| Object Placement | 6 | ADR-0003 | ✅ Covered |
| Ecosystem Simulation | 5 | ADR-0004 | ✅ Covered |
| Tending Input | 6 | ADR-0011 | ✅ Covered |
| Time & Drift | 7 | ADR-0006 | ⚠️ Partial (6 covered / 1 partial) |
| Creature Behavior | 7 | ADR-0007 | ⚠️ Partial (6 covered / 1 partial) |
| Persistence/Save | 8 | ADR-0005 | ⚠️ Partial (5 covered / 3 partial) |
| Discovery Surfacing | 11 | ADR-0002 (snapshot) + ADR-0010 (reveal-queue) | ⚠️ Partial (8 covered / 2 partial / 1 gap) |
| Diorama Rendering | 12 | ADR-0009 (**still Proposed**) | ⚠️ Partial (8 covered / 4 partial) |
| Ambient Audio | 7 | ADR-0012 | ⚠️ Partial (5 covered / 2 partial) |
| *(cross-cutting)* | 3 | ADR-0002 | ✅ Covered — event/signal architecture, snapshot mechanism, and the `SessionBootstrap` restore-write-path gap (resolved pass 4, verified pass 5) |

Remaining gaps and partials are itemized in the traceability index, not re-derived here — this table
is a summary snapshot, and re-deriving per-requirement detail in two places is exactly the kind of
duplication that let this section rot the first time.

## Required ADRs

**Refreshed 2026-08-11 — all 11 systems this section originally required now have a written ADR.**
This section is retained for its historical layer-by-layer structure, not because anything below is
still outstanding. The single remaining item is a status question, not a missing decision.

**Foundation & cross-cutting** — all written, all Accepted:
- Content type-definition authoring format & runtime registry — **ADR-0001**
- Autoload/singleton architecture, initialization order, signal-vs-direct-call convention — **ADR-0002**
- Input gesture abstraction & Web export touch/focus handling strategy — **ADR-0008**

**Core Layer** — all written, all Accepted:
- 2D placement/collision approach — **ADR-0003**
- Ecosystem simulation tick architecture & testable-RNG injection pattern — **ADR-0004**

**Feature** — all written, all Accepted:
- Session lifecycle & tick-batching model (Time & Drift) — **ADR-0006**
- Creature AI/movement architecture (Creature Behavior) — **ADR-0007**
- Save blob schema, validity gating, Web export persistence strategy (Persistence/Save) — **ADR-0005**.
  WebKit/iOS Safari remains an explicit, unmitigated-by-testing residual risk (architecturally
  hedged, not closed — see ADR-0005 Consequences).
- Tending Input's synchronous command-routing pattern — **ADR-0011** (did not fold into ADR-0002;
  stood alone as originally flagged as a possibility, not a requirement)

**Presentation** — 2 of 3 Accepted, 1 remains Proposed by design:
- Discovery Surfacing state-delta & reveal-queue architecture (includes the pre-batch snapshot
  mechanism) — **ADR-0010**, Accepted
- Ambient Audio bus/volume architecture — **ADR-0012**, Accepted
- Diorama Rendering technique under the Compatibility/WebGL2 renderer — **ADR-0009**, still
  **Proposed**, deliberately held: Gate C1 (Light2D/normal-map response) is only provisionally
  verified on placeholder art, and Gate C4 (frame budget under the 8-concurrent-Light2D worst case)
  has zero measurements on any device, mobile included. Do not promote until real numbers exist —
  see `docs/technical-setup/web-export-verification-plan.md` Gate C.

**Can defer to implementation** (unchanged):
- Specific tween/easing parameters for wobble/snap-back (low-stakes, tunable, not architecturally binding)
- Save schema migration strategy for post-launch changes (explicitly out of MVP scope per
  `persistence-save.md`)

## Architecture Principles

1. **Pure state owners, no outward calls from Core.** Ecosystem Simulation (and systems shaped
   like it) expose command/query interfaces but never call into their own consumers — keeps the
   simulation testable in isolation and prevents circular runtime coupling. Already locked in by
   every GDD; this document names it as binding.
2. **Synchronous, same-frame causality for direct player feedback.** Any player action (watering,
   dragging) resolves synchronously in the same frame — no deferred calls/`await` in that path.
   Tick-driven change (growth) is the only thing allowed to lag, and only until the next session's
   catch-up batch.
3. **No physics engine for 2D interaction.** Placement/collision math is hand-rolled `Vector2`
   arithmetic, not `Area2D`/`CollisionShape2D`/Jolt — the entire play surface is a handful of
   static circles/ellipses. Simpler, and removes an entire engine-version-risk surface.
4. **Never punish, never lose data.** Every fallback (save corruption, missing content, invalid
   data) degrades gracefully — exclude-and-warn, last-known-good, default-init — never crashes,
   never discards more than the minimum necessary. Mirrors the game's own Anti-Pillar (NOT
   punishing) at the engineering layer.
5. **Assume nothing about Web export until verified.** Every Compatibility-renderer,
   browser-lifecycle, or IndexedDB claim in this document is a hypothesis until the verification
   spike runs. Provisional ADRs get written rather than blocking work, but nothing gated is
   treated as settled.

## Open Questions

| ID | Summary | Priority | Status (refreshed 2026-08-11) |
|----|---------|----------|-----------------|
| QQ-01 | No event/signal architecture was ever explicitly chosen | High | **Resolved** — ADR-0002 (direct calls for commands/queries, signals for notifications) |
| QQ-02 | Discovery Surfacing's pre-batch snapshot mechanism is unspecified | High | **Resolved** — ADR-0002 (snapshot step) + ADR-0010 (reveal-queue architecture) |
| QQ-03 | 3 Web-export verification gates unresolved (input focus/touch dedup, IndexedDB write-on-close, `Light2D`/Compatibility lighting) | High | **Partially resolved.** Gate A (input): mostly resolved with real evidence. Gate B (persistence): resolved on Chromium via ADR-0005; WebKit/iOS Safari remains an explicit, accepted residual risk. Gate C (rendering): **still genuinely open** — C1 provisional on placeholder art only, C4 (frame budget) has zero measurements on any device — this is why ADR-0009 remains Proposed while all other ADRs are Accepted. |
| QQ-04 | Content authoring format (`.tres` vs JSON) undecided | High | **Resolved** — ADR-0001 (`.tres`) |
| QQ-05 | Multi-jar / multi-instance-per-creature-type architecture not designed | Low (Alpha-tier, not MVP) | Still open, unchanged — revisit when Alpha scope begins |
