# ADR-0007: Creature Behavior — Wander State Machine

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core / Gameplay AI (no dedicated engine-reference module — closest touchpoints are frame-loop ordering (`_ready()`/`_process()`) and `RandomNumberGenerator`, both stable pre-cutoff surfaces) |
| **Knowledge Risk** | LOW for this ADR's specific dependencies — unlike Input/Save/Rendering, Creature Behavior is not flagged as a HIGH RISK domain in `architecture.md`'s Engine Knowledge Gap Summary. No Web-export-specific behavior involved; this is pure in-engine simulation. |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `deprecated-apis.md` (no entries touching `RandomNumberGenerator`, `Vector2`, or `_process()`/`_ready()` ordering — confirmed empty, not skipped); `docs/architecture/adr-0003-object-placement-collision-approach.md` (ellipse geometry, module-shape convention), `adr-0004-ecosystem-simulation-tick-architecture.md` (RNG-ownership convention, "never calls outward" guarantee), `adr-0006-time-drift-session-lifecycle.md` (CATCHING_UP/ACTIVE gate this ADR consumes) |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | None new — confirmed by godot-specialist review (see Consequences → Risks) that `_ready()` across all autoloads completes before the engine's first `_process()` frame, which this ADR's Core Rule 8 handling depends on. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (Ecosystem Simulation's PRESENT/ABSENT state and `set_last_known_position()`); ADR-0003 (Object Placement's `get_position()`, ellipse geometry, pure-formula-script and RNG-ownership conventions); ADR-0006 (Time & Drift's `get_state()` — the CATCHING_UP/ACTIVE gate Core Rule 8 depends on). All Proposed, same as this ADR. |
| **Enables** | Diorama Rendering's live-position consumption (soft — that ADR is still gated on the rendering spike evidence); Discovery Surfacing's Departure cue (reads `last_known_position`, already served by ADR-0004's interface, this ADR is what keeps it live-updated). |
| **Blocks** | Creature Behavior implementation — not yet epic'd. |
| **Ordering Note** | None beyond the Depends On list — no BLOCKING gate inherited from this GDD (unlike Time & Drift's). |

## Context

### Problem Statement

`creature-behavior.md` specifies a 4-state wander loop (SPAWNING/WANDERING/PAUSING/DEPARTING) plus a session-start entry rule (Core Rule 8) that must never play a visible SPAWNING/DEPARTING animation for a transition that resolved inside Time & Drift's invisible catch-up batch. The GDD's Interactions table says this system "reads creature PRESENT/ABSENT transitions" from Ecosystem Simulation without specifying the mechanism — that's the concrete decision this ADR makes, along with the module shape and formula placement.

### Constraints

- Ecosystem Simulation has an already-locked guarantee (ADR-0004, `architecture.md` API Boundaries): it **never calls outward to any other system**. This rules out a signal-based push from Ecosystem Simulation to Creature Behavior — the detection mechanism must be pull-based.
- Movement is continuous every frame (Core Rule 3) regardless of tick boundaries — whatever detection mechanism is chosen must not add a second polling cadence alongside the movement `_process()` loop that already needs to run every frame.
- Core Rule 8's "no reaction while CATCHING_UP" requirement must hold with zero risk of a race — silently playing a SPAWNING animation for a batch-resolved transition would violate `time-drift.md` AC11's atomicity guarantee and this GDD's own AC15.

### Requirements

- Detect live (post-ACTIVE) `ABSENT→PRESENT`/`PRESENT→ABSENT` transitions from Ecosystem Simulation without that system calling outward.
- Resolve the session-start entry point (Core Rule 8) exactly once, driven by `SessionBootstrap` (ADR-0002), never by the live per-frame detection path.
- Reuse ADR-0003/0004's established module-shape, pure-formula, and RNG-ownership conventions rather than inventing new ones.

## Decision

**Detection mechanism**: pull-based, not push. `CreatureBehavior` (autoload) polls `EcosystemSimulation.get_creature_state(id)` once per `_process()` frame, for every creature `id` in Content Data's registry, and diffs against its own last-observed value per creature to detect a transition. This is the only mechanism consistent with Ecosystem Simulation's locked "never calls outward" guarantee, and it's free to add — `_process()` already has to run every frame for continuous movement (Core Rule 3), so the diff check rides the same per-frame pass, no second polling cadence.

**Core Rule 8's CATCHING_UP-vs-live split is structurally guaranteed, not runtime-checked**: Godot's autoload `_ready()` calls (including `SessionBootstrap`'s entire 11-step sequence, which runs synchronously inside its own `_ready()`, per ADR-0002) all complete before the engine's first `_process()` frame ever fires. Time & Drift's catch-up batch — and therefore every PRESENT/ABSENT transition it produces — happens entirely within that `_ready()`-time window. `CreatureBehavior`'s `_process()`-based diff-polling described above literally cannot run before the batch completes; there is no risk of the live-detection path double-reacting to a batch-resolved transition, because it has not started polling yet when those transitions occur. **This was verified with godot-specialist, not asserted** — see Consequences → Risks for the one condition it depends on.

**Session-start entry (Core Rule 8's settled-state query)**: a new public method, `func resolve_session_start() -> void`, called directly by `SessionBootstrap` at Data Flow §3 step 8 / §4 step 8 (`architecture.md` — corrected 2026-08-10 as part of ADR-0002's revision; the two sections previously diverged because §4 didn't split Time & Drift's catch-up and ACTIVE-transition into separate steps the way §3 does, which made this citation read "step 7" against §4's now-superseded numbering) — after Time & Drift reaches ACTIVE, before Creature Behavior's `_process()` loop has run even once. It queries each creature's settled state exactly once: `PRESENT` → enter `WANDERING` directly at the settled position with a freshly-sampled destination (never `SPAWNING`); `ABSENT` → no instance created. This also seeds `CreatureBehavior`'s per-creature "last-observed state" cache used by the live diff-poll above, so the live path's very first frame doesn't misread the just-resolved settled state as a fresh transition.

**Module shape**: `CreatureBehavior` (autoload, Feature) holds `_instances: Dictionary` — `String` (creature_id) → `CreatureInstance` (`RefCounted` subclass, own file `creature_instance.gd`): `wander_state: WanderState` (enum `{SPAWNING, WANDERING, PAUSING, DEPARTING}`), `position: Vector2`, `destination: Vector2`, `pause_timer: float`. An entry exists in `_instances` only while a live instance exists (matches the GDD's own "holds a live instance" language) — removed when `DEPARTING`'s exit animation completes. Reuses ADR-0003/0004's convention (autoload + Dictionary registry of `RefCounted` values) directly.

**Pure formulas**: a separate, non-autoload script `creature_behavior_formulas.gd` (`class_name CreatureBehaviorFormulas`, `extends RefCounted`), reusing ADR-0003's `testable_pure_formula_placement` convention — see Key Interfaces.

**RNG ownership**: `CreatureBehavior` owns a private `RandomNumberGenerator` (`randomize()`'d once at `_ready()`, no public setter), generates the destination-sample draw and the pause-duration draw internally, passes them as parameters into the pure formula functions — reuses ADR-0004's registered `production_rng_ownership` convention directly, not a new pattern.

### Architecture Diagram

```
SessionBootstrap step 8 ──resolve_session_start()──▶ CreatureBehavior
   for each creature_id in Content Data's registry:
     state = EcosystemSimulation.get_creature_state(id)
     if state == PRESENT: spawn instance, WANDERING, fresh destination sample
     (seeds _last_observed_state[id] either way)

CreatureBehavior._process(delta) — every frame, post-ACTIVE only (structurally, see Decision):
   for each creature_id in Content Data's registry:
     state = EcosystemSimulation.get_creature_state(id)
     if state != _last_observed_state[id]:
       state == PRESENT  → spawn instance, SPAWNING → (placement) → WANDERING
       state == ABSENT   → existing instance (if any) → DEPARTING from current position
       _last_observed_state[id] = state
   for each live instance:
     advance movement (Formulas), check arrival, tick pause_timer
     EcosystemSimulation.set_last_known_position(id, position)   # every frame, ADR-0004 Core Rule 12
```

### Key Interfaces

`architecture.md`'s existing sketch for Creature Behavior is **confirmed, with one addition**:

```gdscript
# Creature Behavior (autoload) — Feature. get_position()/get_state() unchanged from architecture.md.
func get_position(creature_id: String) -> Vector2
func get_state(creature_id: String) -> WanderState  # {SPAWNING, WANDERING, PAUSING, DEPARTING}
func resolve_session_start() -> void  # NEW — called ONLY by SessionBootstrap, step 8, exactly once
# Invariant: only meaningful for a creature Ecosystem Simulation currently reports PRESENT — no live
# instance, and therefore no valid position/state, exists for an ABSENT creature. (Unchanged.)
```

```gdscript
# creature_behavior_formulas.gd — pure, static, no engine RNG calls (reuses ADR-0003's convention)
static func sample_destination(roll_x: float, roll_y: float, bounds: Rect2, center: Vector2,
    rx: float, ry: float, obstacles: Array[Dictionary], clearance: float) -> Vector2
  # rejection sampling per Formulas; caller (CreatureBehavior) redraws roll_x/roll_y from its own
  # RandomNumberGenerator up to MAX_SAMPLE_ATTEMPTS, dropping the clearance term on exhaustion

static func movement_step(pos: Vector2, dest: Vector2, movement_speed: float, delta_time: float) -> Vector2
  # step = min(movement_speed * delta_time, pos.distance_to(dest)); pos + (dest - pos).normalized() * step

static func has_arrived(pos: Vector2, dest: Vector2, arrival_threshold: float) -> bool
  # pos.distance_to(dest) <= arrival_threshold — checked same-frame against the already-clamped pos

static func sample_pause_duration(roll: float, pause_min: float, pause_max: float) -> float
  # pause_min + roll * (pause_max - pause_min); caller draws roll from its own RandomNumberGenerator
```

## Alternatives Considered

### Alternative: Ecosystem Simulation emits a signal on PRESENT/ABSENT transition
- **Description**: `EcosystemSimulation.creature_state_changed(id, new_state)` signal, `CreatureBehavior` connects to it.
- **Pros**: Push-based, no polling; would also make Core Rule 8's CATCHING_UP suppression a matter of "don't connect the signal handler until ACTIVE" rather than a structural timing argument.
- **Cons**: Directly violates the already-locked, cross-ADR guarantee that Ecosystem Simulation never calls outward (ADR-0004, `architecture.md`) — adopting this would require reopening and amending an already-Proposed ADR's core guarantee for one consumer's convenience.
- **Rejection Reason**: The guarantee exists precisely so Ecosystem Simulation stays a pure state owner other systems can reason about in isolation; this system's `_process()` loop already needs to run every frame regardless (Core Rule 3), so polling costs nothing extra here.

## Consequences

### Positive
- Zero new coupling on Ecosystem Simulation — its "never calls outward" guarantee stays intact.
- Core Rule 8's atomicity requirement is satisfied by Godot's own execution model, not by a runtime flag `CreatureBehavior` has to remember to check — removes an entire class of "forgot to gate on CATCHING_UP" bug.
- Formula/RNG placement reuses two already-registered conventions verbatim — no new architectural surface for `/architecture-review` to reconcile.

### Negative
- Per-frame diff-polling of every creature's state, rather than an event-driven update, is a small constant per-frame cost — negligible at MVP's 2-creature scale (Performance Implications), but would need revisiting if creature count grows substantially in a future tier.
- `resolve_session_start()` and the live `_process()` diff-poll are two separate code paths that both ultimately react to the same underlying signal (a state transition) — a future maintainer could plausibly try to unify them; Decision explicitly documents why they must stay separate (one is a one-time settled-state query, the other a continuous live detector, and conflating them risks reintroducing the exact race Core Rule 8 exists to prevent).

### Risks
- **The "`_ready()` completes before first `_process()`" claim is TRUE-WITH-CAVEATS, verified with godot-specialist, not unconditionally TRUE.** It holds for Godot 4.7.1's core engine behavior (confirmed: no autoload/`_process()`-ordering entries in `breaking-changes.md`/`deprecated-apis.md` across 4.4–4.7, unchanged since 4.0) and identically on Web export (core `SceneTree` code, no WASM-specific divergence) — but it is only as safe as three preconditions holding: no `await` inside any autoload's `_ready()`, no `call_deferred()` in the sequence, no `Thread` spawned during init. `SessionBootstrap` (ADR-0002) satisfies all three today (synchronous direct calls only, placed last in load order). **This is a standing constraint on ADR-0002, not just this ADR** — any future change introducing `await`/`call_deferred()`/threading into `SessionBootstrap`'s sequence invalidates Core Rule 8's structural argument and would require adding the runtime CATCHING_UP-check this ADR currently avoids. Not independently documented in this project's Web-export engine-reference notes (general Godot architecture, not a project-specific citation) — worth a real Web-export smoke test at implementation time as belt-and-suspenders, not as a design blocker.
- **`resolve_session_start()` must be called exactly once, before any `_process()` frame runs** — covered by the precondition above; no separate new risk.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| creature-behavior.md | Core Rules 1–7 (SPAWNING/WANDERING/PAUSING/DEPARTING loop, straight-line movement, interrupt-on-ABSENT) | `CreatureInstance`'s `wander_state` field + the `_process()` loop in Architecture Diagram. |
| creature-behavior.md | Core Rule 8 (session-start entry, no animation for batch-resolved transitions) | `resolve_session_start()`, called once by `SessionBootstrap`, plus the structural `_ready()`-before-`_process()` guarantee — see Decision. |
| creature-behavior.md | Core Rule 9 (`set_last_known_position()` every frame) | Architecture Diagram's `_process()` loop, unchanged from the GDD's own specification. |
| creature-behavior.md | Formulas (destination sampling, movement/arrival, pause duration) | `creature_behavior_formulas.gd`, pure/static, matching each formula's stated expression exactly. |
| creature-behavior.md | Interactions table's "reads creature PRESENT/ABSENT transitions" (previously unspecified mechanism) | Resolved: pull-based diff-polling, not a signal — see Decision and Alternatives Considered. |

## Performance Implications
- **CPU**: Per-frame diff-poll over ≤2 creatures (MVP: Snail, Moth) is O(1) in practice; movement/arrival formulas are simple `Vector2` math, well within the 16.6ms frame budget alongside Ecosystem Simulation's own per-tick cost (ADR-0004).
- **Memory**: `_instances` holds at most 2 `RefCounted` entries at MVP scale — negligible.
- **Load Time**: `resolve_session_start()` runs once during `SessionBootstrap`'s synchronous sequence, O(creature count) — no measurable load-time impact.
- **Network**: N/A.

## Migration Plan
No existing implementation.

## Validation Criteria
- Unit-level: `creature_behavior_formulas.gd`'s four static functions against `creature-behavior.md`'s AC3/AC3a/AC5/AC7/AC8/AC8a (all pure-logic, literal-input testable).
- Integration-level: AC15/AC15a (Core Rule 8's settled-state entry) against a real `SessionBootstrap` sequence with Time & Drift's catch-up batch producing mid-batch transitions.
- The structural `_ready()`-before-`_process()` claim underlying Core Rule 8 is an engine-execution-order guarantee, not something a story-level test needs to re-verify per-story — it's a one-time architectural fact, confirmed here.

## Related Decisions
- Depends on ADR-0003 (Object Placement — geometry/conventions), ADR-0004 (Ecosystem Simulation — state source, RNG convention), ADR-0006 (Time & Drift — CATCHING_UP/ACTIVE gate).
- Updates `docs/registry/architecture.yaml`'s `object_position_held_grab_offset` entry (adds `creature-behavior.md` to `referenced_by` — Object Placement's footprint state is read here as a movement obstacle, per that GDD's own soft Dependencies entry).
