# ADR-0004: Ecosystem Simulation Tick Architecture & Testable-RNG Injection

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (pure GDScript state simulation — no rendering, no physics, no engine-specific subsystem) |
| **Knowledge Risk** | LOW — `RandomNumberGenerator`, `Dictionary`, and plain arithmetic are all stable pre-cutoff Godot 4.0 APIs; no post-cutoff API is touched anywhere in this decision. |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` (no `RandomNumberGenerator`/RNG-related entries in either — confirms no version risk); `design/gdd/ecosystem-simulation.md` Formulas section (the authoritative source for every formula this ADR implements, not re-derived here) |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | None. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data — `PlantTypeDef`/`CreatureTypeDef` fields read via `get_definition()`), ADR-0002 (direct-call convention; `advance_tick()` called only by Time & Drift, `SessionBootstrap` sequences restore before the catch-up batch), ADR-0003 (establishes the two conventions this ADR reuses directly: autoload + `Dictionary` registry of `RefCounted` values, and pure formulas in a separate non-autoload script) |
| **Enables** | Ecosystem Simulation implementation stories; unblocks Time & Drift (calls `advance_tick()` in the catch-up loop), Creature Behavior (reads PRESENT/ABSENT, calls `set_last_known_position()`), Tending Input (`apply_watering()`), Discovery Surfacing/Diorama Rendering (read growth/light/creature state) |
| **Blocks** | All Ecosystem Simulation implementation stories, and any story in a dependent system that reads simulation state |
| **Ordering Note** | Should be Accepted after ADR-0001–0003, since it reuses their conventions directly rather than re-deciding them. |

## Context

### Problem Statement
`ecosystem-simulation.md` is the project's highest-risk, most-depended-on
system, and its Formulas section already fully specifies every piece of
math: jar moisture (live watering + tick decay), a deterministic
triangle-wave `light_level`, a three-state (GROWING/STALLED/DECAYING)
per-plant growth delta gated on two independent tolerance bands, a
sequential creature spawn/departure debounce
(`condition_streak_ticks`/`N_spawn_ticks`/`N_departure_ticks`), and a
rare-detail-event gate that the GDD's own `/design-review` history (round
12, `qa-lead` finding) explicitly split into a pure, injectable
`should_trigger_detail(roll: float, p_detail: float) -> bool` specifically
so it satisfies `coding-standards.md`'s "no random seeds" testing rule.
What's left undecided — and genuinely architectural, not a design
question — is: (1) the internal module shape (how per-plant/per-creature
state is stored and iterated), and (2) **who generates the real random
`roll` in production**. The GDD's own Formulas table describes `roll` as
"externally-supplied... injected rather than read from engine RNG," which
resolves the *testability* question (the gate function must take `roll`
as a parameter) but not the *production* question of which system's code
actually calls a `RandomNumberGenerator` each tick.

### Constraints
- `advance_tick() -> void` is already sketched in `architecture.md`'s API
  Boundaries with no arguments — changing its signature to accept an
  external roll would require reworking that boundary and coupling
  whichever caller supplies it (Time & Drift) to a mechanic it has no
  other reason to know about.
- `coding-standards.md`: all public methods unit-testable (DI over
  singletons); tests must not rely on random seeds.
- `ecosystem-simulation.md` Interactions table: "Ecosystem Simulation
  exposes state to five downstream systems but calls into none of them —
  pure state owner with a query/command interface, never reaching
  outward." Any RNG solution must not violate this (e.g., must not call
  out to a hypothetical RNG-provider system).
- Must reuse ADR-0003's already-registered `small_shared_state_module_shape`
  and `testable_pure_formula_placement` conventions rather than
  reinventing a third pattern for the third system that needs one.
- Per-tick evaluation order matters: Core Rule 11 (already in the GDD)
  fixes plants-then-creatures ordering within a single `advance_tick()`
  call — this ADR must preserve it, not re-decide it.

### Requirements
- `advance_tick()` must apply exactly one tick's worth of state change
  (moisture decay, light drift, per-plant growth, per-creature
  spawn/departure debounce) and be safe to call N times in a row (Time &
  Drift's catch-up batch, up to `max_catchup_ticks=84`).
- `apply_watering(amount)` must remain live/synchronous, decoupled from
  ticks (Core Rule 5's correction — already locked).
- The detail-event gate must be testable with a fixed `roll` and no
  engine RNG involvement in the test.
- Must never call outward to another system (Ecosystem Simulation stays a
  pure state owner, per its own Interactions table).

## Decision

### 1. Module shape: autoload + two `Dictionary` registries (reuses ADR-0003's convention)

`EcosystemSimulation` (autoload, Core) holds:
- Jar-wide scalars as plain fields: `_jar_moisture: int`, `_light_level:
  int`, `_light_direction: int`.
- `_plants: Dictionary` — `String` (plant_id) → `PlantState` (`RefCounted`
  subclass, own file `plant_state.gd`): `growth_stage: int`,
  `optimal_hold_ticks: int`.
- `_creatures: Dictionary` — `String` (creature_id) → `CreatureState`
  (`RefCounted` subclass, own file `creature_state.gd`): `state:
  CreatureState.Presence` (a real GDScript `enum Presence {PRESENT,
  ABSENT}` declared on `CreatureState` — not an `int` with a comment;
  GDScript enums compile to `int` anyway, so the typed form is free —
  `godot-specialist` review, 2026-08-10), `condition_streak_ticks: int`,
  `last_known_position: Vector2`, `was_present_during_batch: bool`.

Both registries are populated at `SessionBootstrap`'s restore step (ADR-0002
step 3) from Content Data's registered plant/creature ids, defaulted or
restored from Persistence/Save.

### 2. Pure formulas: `EcosystemFormulas` script (reuses ADR-0003's convention)

A separate, non-autoload script, `ecosystem_formulas.gd` (`class_name
EcosystemFormulas`, `extends RefCounted`), holds every formula from
`ecosystem-simulation.md`'s Formulas section as a `static func`, taking
all inputs as parameters — no reads of `EcosystemSimulation`'s internal
state, no engine RNG calls:

```gdscript
static func moisture_after_watering(jar_moisture: int, watering_amount: int) -> int
static func moisture_after_tick_decay(jar_moisture: int, moisture_decay_rate: int) -> int
static func light_level_tick(light_level: int, light_direction: int, step: int) -> Vector2i  # (level, direction) — not an ad-hoc Dictionary bag (godot-specialist review, 2026-08-10)
static func plant_growth_outcome(jar_moisture: int, light_level: int, moisture_range: Vector2, light_range: Vector2) -> GrowthOutcome  # enum {GROWING, STALLED, DECAYING}
static func should_trigger_detail(roll: float, p_detail: float) -> bool  # roll < p_detail, exclusive high boundary (AC13b)
static func spawn_departure_debounce(...) -> DebounceResult  # small RefCounted result type (own file), not a Dictionary bag — holds condition_streak_ticks/state per Core Rules 6/7
```

Each is directly unit-testable with literal inputs, matching
`ecosystem-simulation.md`'s own worked examples and boundary ACs (13a/13b,
21, 22, etc.) one-to-one.

### 3. RNG ownership: Ecosystem Simulation generates the roll internally, then delegates the gate decision to the pure function

`EcosystemSimulation` owns a private `_rng: RandomNumberGenerator`,
`randomize()`'d once at `_ready()` (real, non-deterministic production
randomness — `randomize()` seeds from OS entropy, distinct from a fixed
test seed). Inside `advance_tick()`'s per-plant loop, for any plant whose
`optimal_hold_ticks` meets the threshold, `EcosystemSimulation` calls
`_rng.randf()` to produce `roll`, then calls
`EcosystemFormulas.should_trigger_detail(roll, p_detail)` — the impure
roll generation and the pure gate decision are two separate calls, so unit
tests exercise the pure function directly with a literal `roll` and never
touch `_rng`. This satisfies "externally-supplied... injected rather than
read from engine RNG" at the function-signature level (the gate function
itself never calls RNG) without requiring any other system to own or
supply randomness — `EcosystemSimulation` still never calls outward,
preserving its Interactions table guarantee.

`advance_tick()`'s public signature stays exactly as `architecture.md`
already sketched it — `func advance_tick() -> void`, no arguments — no
rework needed there.

### 4. `advance_tick()` orchestration order (single tick per call)

```gdscript
func advance_tick() -> void:
    # 1. Jar moisture tick decay
    _jar_moisture = EcosystemFormulas.moisture_after_tick_decay(_jar_moisture, MOISTURE_DECAY_RATE)
    # 2. Light level tick
    var light := EcosystemFormulas.light_level_tick(_light_level, _light_direction, LIGHT_STEP_PER_TICK)
    _light_level = light.x
    _light_direction = light.y
    # 3. Plants (Core Rule 11: plants before creatures)
    for plant_id in _plants:
        var outcome := EcosystemFormulas.plant_growth_outcome(_jar_moisture, _light_level, ...)
        # apply growth_stage delta per outcome; update optimal_hold_ticks
        # (increments only on GROWING, resets on STALLED or DECAYING)
        if outcome == GrowthOutcome.GROWING and _plants[plant_id].optimal_hold_ticks >= HOLD_THRESHOLD:
            var roll := _rng.randf()
            if EcosystemFormulas.should_trigger_detail(roll, P_DETAIL):
                # "not persisted" (ecosystem-simulation.md's round-13 ruling) means
                # never written to the save blob — it still lives in memory for the
                # duration of the current batch, same lifetime as was_present_during_batch,
                # so Discovery Surfacing's post-batch compute_delta() (SessionBootstrap
                # step 9) can read it. OR-accumulated, never overwritten to false mid-batch,
                # in the (currently unreachable at tuned values, defensive) case a plant
                # could clear HOLD_THRESHOLD more than once in one catch-up batch.
                _plants[plant_id].detail_event_fired_this_batch = true
    # 4. Creatures (after plants)
    for creature_id in _creatures:
        # spawn_conditions/departure debounce via EcosystemFormulas.spawn_departure_debounce()
        # updates condition_streak_ticks, state, was_present_during_batch (Core Rules 6/7/13)
        pass
```

`advance_tick()` is called exactly once per tick; Time & Drift is
responsible for calling it N times in a loop during the catch-up batch
(`SessionBootstrap` step 6) — no internal batching inside
`EcosystemSimulation` itself.

`set_last_known_position(creature_id, pos)` (Core Rule 12) is a separate
public method, called by Creature Behavior every live frame — not part of
`advance_tick()`'s per-tick orchestration, since it fires on frames, not
ticks. `was_present_during_batch` and `detail_event_fired_this_batch` both
reset to `false` only at catch-up-batch start, not inside every
`advance_tick()`. **Clarified (companion edit, added for Discovery
Surfacing's ADR)**: "catch-up-batch start" is `restore()` itself (`SessionBootstrap`
step 3) — there is exactly one catch-up batch per session, so restore-time
initialization of `_plants`/`_creatures` IS the batch-start reset; no
separate reset method exists or is needed.

### 5. `restore()` — SessionBootstrap's population entry point (companion edit, ADR-0002 revision, 2026-08-10)

`EcosystemSimulation` gains one new public method, called exactly once,
only by `SessionBootstrap`, at Data Flow §3 step 3:

```gdscript
func restore(restored_blob: Dictionary) -> void
```

Populates `_jar_moisture`/`_light_level`/`_light_direction` and the
`_plants`/`_creatures` registries from `restored_blob`'s typed fields
(per `persistence-save.md`'s blob schema) when `restored_blob` is
non-empty (a validated save existed); otherwise defaults every plant/
creature id from Content Data's registry to its GDD-specified initial
state (`ecosystem-simulation.md`'s own default-state specification, not
re-derived here). This is the concrete callable this ADR's Decision §1
already described in prose ("Both registries are populated at
SessionBootstrap's restore step") but never named — closing the gap
`docs/consistency-failures.md`'s TR-crosscutting-003 flagged against
ADR-0002's pseudocode.

This does not weaken this system's "never calls outward" guarantee
(Interactions table, restated in Requirements above) — `restore()` is an
inbound call *into* `EcosystemSimulation`, the same direction as
`apply_watering()`/`advance_tick()`, not an outbound one.

**Companion edit (added for Discovery Surfacing's ADR)**: four getters were
missing from Key Interfaces below. Two expose state this system already
tracked internally — `was_present_during_batch` (a field that existed in
`CreatureState` with no public accessor) and the transient per-tick
detail-event flag (previously an unimplemented `pass` in the orchestration
above, now `PlantState.detail_event_fired_this_batch`). The other two
(`get_plant_ids()`/`get_creature_ids()`) close a real gap no prior ADR
noticed: nothing exposed *which* plants/creatures exist to iterate over —
every existing getter above is per-id (`get_growth_stage(plant_id)`), so a
caller needed the id list from somewhere first. `capture_pre_batch_snapshot()`
(`docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md`
step 5) has this same latent need. Both new getters return ids in `_plants`/
`_creatures` insertion order, which doubles as Discovery Surfacing's Core
Rule 8 tie-break "registration order" — one mechanism serving both the
enumeration need and the ordering need, rather than two separate ones. All
four are read-only, follow the existing query-getter pattern, and change
nothing about this ADR's Decision.

### `get_watering_amount()` — Tending Input's tuning-knob read (companion edit, ADR-0011, 2026-08-11)

`apply_watering(amount: int) -> void`'s signature (unchanged, already
locked by `architecture.md`) requires the caller to supply the amount, but
no prior ADR draft actually declared `watering_amount` as a stored
constant anywhere in this system — `ecosystem-simulation.md`'s own Tuning
Knobs table names it as owned here ("registered and owned there," per
`tending-input.md`), but nothing named the callable. `EcosystemSimulation`
gains:

```gdscript
const WATERING_AMOUNT: int = 25   # ecosystem-simulation.md Tuning Knobs
func get_watering_amount() -> int:
    return WATERING_AMOUNT
```

so Tending Input (ADR-0011) can read the configured value instead of
hardcoding or re-deriving it (GDD AC1's explicit requirement). Follows the
same read-only query-getter pattern as `get_plant_ids()`/`get_creature_ids()`
above; changes nothing about `apply_watering()`'s own signature or
behavior.

### `watering_applied` — notification signal (companion edit, ADR-0012, 2026-08-11)

`apply_watering(amount: int)` is, and remains, a direct command call
(ADR-0002 convention) — but two downstream systems, Ambient Audio's
Reactive Layer (`ambient-audio.md` Core Rule 3) and Diorama Rendering's
Watering Substrate Sheen (`adr-0009-diorama-rendering-light2d-web-strategy.md`
Core Rule 11), both need a *notification* that watering just occurred,
and no prior ADR gave them one — `apply_watering()`'s command shape has
no return value or observable side-channel a listener could react to.
Per the registered `api_decision` (`inter_system_communication_pattern`:
direct calls for commands, signals for notifications — the caller doesn't
know or care who's listening), `EcosystemSimulation` gains one new
signal:

```gdscript
signal watering_applied
```

emitted at the end of `apply_watering()`, after `_jar_moisture` is
written. `apply_watering()`'s own signature and calling convention are
otherwise unchanged — Tending Input (ADR-0011) still calls it exactly the
same way; the signal is purely additive, for listeners that don't
themselves call `apply_watering()`.

### Architecture Diagram
```
TimeDrift ──advance_tick() × N (catch-up loop)──> EcosystemSimulation
                                                       │
                                                       ├─ _jar_moisture, _light_level/_direction (scalars)
                                                       ├─ _plants: Dictionary[String, PlantState]
                                                       ├─ _creatures: Dictionary[String, CreatureState]
                                                       ├─ _rng: RandomNumberGenerator (private, real randomness)
                                                       │
                                                       └─ calls EcosystemFormulas.* (separate script,
                                                          static/pure, unit-testable without the autoload
                                                          or without touching _rng)

TendingInput ──apply_watering(amount)──> EcosystemSimulation   (live, no tick)
EcosystemSimulation ──watering_applied (signal, ADR-0012 companion edit)──> {AmbientAudio, DioramaRendering}
CreatureBehavior ──set_last_known_position(id, pos)──> EcosystemSimulation   (every live frame)
{DiscoverySurfacing, DioramaRendering, Persistence/Save} ──query getters──> EcosystemSimulation
```

### Key Interfaces
```gdscript
# EcosystemSimulation (autoload) — Core (public API unchanged from architecture.md,
# except restore(), a companion edit — see Decision §5)
func apply_watering(amount: int) -> void
func get_watering_amount() -> int   # companion edit — ADR-0011 (2026-08-11). Backed by WATERING_AMOUNT const.
signal watering_applied   # companion edit — ADR-0012 (2026-08-11). Emitted at end of apply_watering().
func advance_tick() -> void
func restore(restored_blob: Dictionary) -> void   # companion edit — Decision §5. Called ONLY by SessionBootstrap, step 3.
func set_last_known_position(creature_id: String, pos: Vector2) -> void
func get_jar_moisture() -> int
func get_light_level() -> int
func get_growth_stage(plant_id: String) -> int
func get_creature_state(creature_id: String) -> CreatureState.Presence
func get_last_known_position(creature_id: String) -> Vector2
func get_was_present_during_batch(creature_id: String) -> bool   # companion edit — Discovery Surfacing Core Rule 2a
func get_detail_event_fired(plant_id: String) -> bool            # companion edit — Discovery Surfacing Core Rule 2/AC8
func get_plant_ids() -> Array[String]      # companion edit — registration order (insertion order into _plants); Discovery Surfacing Core Rules 1/8 need both enumeration (what to compare) and ordering (tie-break) from the same source
func get_creature_ids() -> Array[String]   # companion edit — same rationale, for _creatures

# EcosystemFormulas (ecosystem_formulas.gd) — separate script, static, pure
# (signatures per Decision §2 above)

# PlantState (plant_state.gd) — RefCounted
class_name PlantState
extends RefCounted
var growth_stage: int
var optimal_hold_ticks: int
var detail_event_fired_this_batch: bool   # companion edit — see Decision §4

# CreatureState (creature_state.gd) — RefCounted
class_name CreatureState
extends RefCounted
enum Presence { PRESENT, ABSENT }
var state: Presence
var condition_streak_ticks: int
var last_known_position: Vector2
var was_present_during_batch: bool   # now has a public getter — companion edit
```

`get_creature_state()` returns the `CreatureState.Presence` enum value
directly, not the whole `CreatureState` object — the initial draft's
comment describing the return type didn't match its own declared
signature (`godot-specialist` review, 2026-08-10); fixed above.

Also, `DebounceResult` (referenced by `EcosystemFormulas.spawn_departure_debounce()`
in Decision §2) is a small `RefCounted` result type, own file, same
pattern as `PlantState`/`CreatureState` — not shown in full here since its
fields are exactly `condition_streak_ticks`/`state` (`CreatureState.Presence`),
already declared above.

## Alternatives Considered

### Alternative 1: Time & Drift supplies the roll
- **Description**: Time & Drift owns a `RandomNumberGenerator` and passes
  a `roll` parameter into every `advance_tick()` call.
- **Pros**: Keeps `EcosystemSimulation` itself free of any RNG object.
- **Cons**: Couples session-lifecycle/catch-up-batch timing to a
  plant-detail-event mechanic it has no other reason to know about; would
  require reworking `advance_tick()`'s already-sketched no-argument
  signature in `architecture.md`; and every future tick-driven mechanic
  needing randomness would have to route through Time & Drift too, for no
  architectural benefit.
- **Rejection Reason**: Wrong ownership — the roll is consumed entirely
  within Ecosystem Simulation's own per-plant loop; Time & Drift has no
  stake in it.

### Alternative 2: Dedicated RNG-provider autoload
- **Description**: A new autoload whose only job is supplying random
  values to any system that needs them.
- **Pros**: Centralizes all randomness in one place, useful if many
  systems needed injected RNG.
- **Cons**: Exactly one consumer exists across all 11 MVP GDDs
  (Ecosystem Simulation's detail-event roll) — a new permanent autoload
  for a one-consumer need is unrequested infrastructure, and it would
  make `EcosystemSimulation` call outward to get its roll, violating its
  own Interactions table guarantee ("never reaching outward").
- **Rejection Reason**: Speculative; also breaks an existing GDD
  invariant for no compensating benefit.

## Consequences

### Positive
- Every formula in `ecosystem-simulation.md`'s Formulas section maps
  one-to-one to a static function in `EcosystemFormulas`, directly
  testable against the GDD's own worked examples and boundary ACs.
- The RNG question (previously ambiguous between "testable gate function"
  and "who owns production randomness") is resolved without touching
  `advance_tick()`'s already-sketched public signature.
- Reuses both of ADR-0003's registered module-shape conventions —
  consistent with Content Data and Object Placement, no new pattern for a
  future reader to learn.

### Negative
- `EcosystemSimulation` now owns three kinds of internal state (scalars,
  two `Dictionary` registries, one `RandomNumberGenerator`) — more
  surface area than Content Data or Object Placement, proportional to
  being the "central state owner" (`architecture.md`'s own description).
- The transient per-tick detail-event flag (fires, read by Discovery
  Surfacing/Diorama Rendering, then discarded) isn't part of this ADR's
  persisted state — its exact lifetime/read mechanism is Discovery
  Surfacing's concern (`ecosystem-simulation.md` Core Rule 10, already
  resolved in a prior session per `production/session-state/active.md`'s
  history), not re-litigated here.

### Risks
- **Risk**: `_rng.randomize()` at `_ready()` uses OS entropy — fine for
  production, but if a future story accidentally calls `_rng.seed = X`
  for "reproducibility," it would silently make production detail events
  deterministic across restarts (a real gameplay regression, not just a
  test concern).
  **Mitigation**: `_rng` is private (no setter exposed on
  `EcosystemSimulation`'s public API); code review should flag any future
  diff that exposes or seeds it outside `_ready()`.
- **Risk**: The detail-event threshold/probability (`HOLD_THRESHOLD=6`,
  `p_detail=0.05`) already carries a documented, unresolved "statistical
  feel density" tuning item (`ecosystem-simulation.md` Open Questions) —
  this ADR implements the gate mechanism, not the tuning pass.
  **Mitigation**: Out of scope by design — tracked separately in the GDD,
  not blocking this ADR's Acceptance.

**`godot-specialist` review (2026-08-10)**: core Decision confirmed
idiomatic (private `RandomNumberGenerator` + `randomize()` at `_ready()`
+ pure gate function is the standard Godot 4 impure/pure split), no
blocking issues. Three fixes folded in: `CreatureState.state` is now a
real `enum Presence {PRESENT, ABSENT}` rather than `int` with a comment
(free — GDScript enums compile to `int` anyway); the Key Interfaces
draft's `get_creature_state()` comment didn't match its own declared
return type, fixed to consistently return `CreatureState.Presence`;
`EcosystemFormulas.light_level_tick()`/`spawn_departure_debounce()`
changed from ad-hoc `Dictionary` return bags to `Vector2i` and a small
`DebounceResult` RefCounted type, respectively, per this project's own
`deprecated-apis.md` guidance against untyped Dictionary/Array where a
typed alternative exists.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| ecosystem-simulation.md | Formulas: jar moisture (watering + decay), light level triangle wave, three-state plant growth, spawn/departure debounce, detail-event gate | Implemented as `EcosystemFormulas` static functions, one per formula, called from `advance_tick()`'s orchestration. |
| ecosystem-simulation.md | `should_trigger_detail(roll, p_detail) -> bool` must be pure/DI'd (AC13a/13b) | Implemented exactly as specified; `roll` generated internally by `EcosystemSimulation`'s private `_rng`, never by the pure function itself. |
| ecosystem-simulation.md | Core Rule 11: plants evaluated before creatures, every tick | `advance_tick()`'s orchestration order (Decision §4) preserves this explicitly. |
| ecosystem-simulation.md | Core Rule 12/13: `last_known_position`/`was_present_during_batch` | `CreatureState` fields; `set_last_known_position()` remains a separate frame-driven call, not part of per-tick orchestration. |
| ecosystem-simulation.md | "Exposes state to five downstream systems but calls into none" | `EcosystemFormulas` and `_rng` are both internal-only; no new outward call is introduced. |
| architecture.md | `advance_tick() -> void`, `apply_watering(amount) -> void`, etc. API Boundaries | Adopted unchanged — this ADR confirms the shape rather than requiring a rework. |
| tending-input.md | AC1 (`apply_watering` called with the configured `watering_amount` constant, never a redefined literal) | `WATERING_AMOUNT` const + `get_watering_amount()` getter (companion edit, ADR-0011) — see Decision above. |
| ambient-audio.md | Core Rule 3 (watering reactive layer needs a "watering just happened" trigger) | `watering_applied` signal (companion edit, ADR-0012) — see Decision above. |

## Performance Implications
- **CPU**: `advance_tick()` iterates 3 plants + 2 creatures at MVP scale
  (single digits) — negligible per call, even at
  `max_catchup_ticks=84` calls in one batch.
- **Memory**: Two small `Dictionary` registries, trivial at MVP content
  volume.
- **Load Time**: Registry population happens once during `SessionBootstrap`
  step 3 (ADR-0002) — no additional cost beyond what that sequence already
  budgets.
- **Network**: N/A.

## Migration Plan
N/A — no existing Ecosystem Simulation implementation to migrate from.

## Validation Criteria
- Unit tests call each `EcosystemFormulas` function directly with literal
  inputs, reproducing `ecosystem-simulation.md`'s own worked examples
  (e.g. `jar_moisture=50` → tick decay → `47`; `light_level=97,
  direction=+1` → `100`, direction flips; `should_trigger_detail(0.049,
  0.05) == true`, `should_trigger_detail(0.05, 0.05) == false`) and its
  documented boundary ACs (13a/13b, 21, 22, 23, 24).
- An integration test drives `EcosystemSimulation.advance_tick()` N times
  against injected Content Data fixtures and confirms per-plant
  `growth_stage`/`optimal_hold_ticks` and per-creature
  `state`/`condition_streak_ticks` match the GDD's documented state
  machine transitions, without asserting on any specific detail-event
  outcome (which depends on real `_rng` output, not asserted
  deterministically).

## Related Decisions
- `docs/architecture/adr-0001-content-data-format.md` — `PlantTypeDef`/
  `CreatureTypeDef` fields consumed via `get_definition()`.
- `docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md`
  — `SessionBootstrap` sequences registry population and the catch-up
  batch's `advance_tick()` loop; direct-call convention this ADR's Key
  Interfaces follow. **Companion-edited by that ADR's 2026-08-10
  revision** to add `restore()` — see Decision §5.
- `docs/architecture/adr-0003-object-placement-collision-approach.md` —
  source of the two reused conventions (autoload + `Dictionary` registry
  of `RefCounted` values; pure formulas in a separate non-autoload
  script), registered in `docs/registry/architecture.yaml` as
  `small_shared_state_module_shape` and
  `testable_pure_formula_placement`.
- `docs/architecture/adr-0011-tending-input-watering-router.md` —
  companion-edits this ADR to add `WATERING_AMOUNT`/`get_watering_amount()`
  (2026-08-11).
- `docs/architecture/adr-0012-ambient-audio-godot-strategy.md` —
  companion-edits this ADR to add `watering_applied` (2026-08-11); also
  closes the identical latent trigger gap in ADR-0009's Watering
  Substrate Sheen.
