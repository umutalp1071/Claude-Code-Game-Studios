# ADR-0002: Cross-Cutting Signal, Initialization-Order, and Snapshot Architecture

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (Autoload/singleton architecture, signals, scene tree init order) |
| **Knowledge Risk** | LOW — Callable-based `signal.connect()`, autoload singletons, and `_ready()` ordering are all stable pre-cutoff Godot 4.0 concepts; nothing in this decision touches a post-cutoff API. |
| **References Consulted** | `docs/engine-reference/godot/deprecated-apis.md` (confirmed `connect("signal", obj, "method")` → `signal.connect(callable)`, string-based connect → typed signal connections — both already assumed throughout `docs/architecture/architecture.md`'s API Boundaries), `docs/engine-reference/godot/breaking-changes.md` (no autoload/init-order changes found in any 4.3→4.7 entry) |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | None. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (independent of ADR-0001; both are Foundation-layer ADRs that happen not to constrain each other) |
| **Enables** | Every other Required ADR that involves cross-system communication — Object Placement, Ecosystem Simulation, Time & Drift, Creature Behavior, Persistence/Save, Discovery Surfacing all currently assume the direct-call convention this ADR formalizes |
| **Blocks** | All implementation stories for any of the 11 MVP systems that call into another system's public API (i.e., nearly all of them) |
| **Ordering Note** | Should be Accepted early — every subsequent Core/Feature/Presentation ADR's Key Interfaces section will cite this ADR's convention rather than re-deciding it. |

## Context

### Problem Statement
`architecture.md`'s Data Flow section documented two real gaps that no GDD
resolves and that `architecture.md` itself flagged as requiring this ADR:

1. **No formal inter-system communication convention.** Every GDD's own
   Interactions table implicitly assumes direct method calls (e.g. Tending
   Input calls `EcosystemSimulation.apply_watering()`), and Input
   Abstraction already emits Godot signals for gesture events — but no
   document ever *decided* this split; it's what happened to get written.
   Left undecided, a future system (or a future contributor) could just as
   easily reach for a central event bus, producing an inconsistent codebase
   where some systems can be traced by reading call sites and others can't.
2. **No owner for Discovery Surfacing's pre-batch snapshot**, or for the
   11-step session-start/save-load sequence itself. `architecture.md`'s
   Data Flow §3 (Save/load path) numbers 11 explicit steps — including a
   `⚠️ SNAPSHOT POINT` at step 5 that must run after Ecosystem
   Simulation/Object Placement restore (steps 3–4) but before Time &
   Drift's catch-up batch (step 6) — and Data Flow §4 numbers 10
   initialization-order steps with real ordering dependencies (e.g. Time &
   Drift needs Ecosystem Simulation ready; Creature Behavior needs Time &
   Drift `ACTIVE`). Godot's own autoload `_ready()` load-order guarantee is
   necessary but not sufficient here: it can guarantee *which order
   `_ready()` fires in*, but this sequence has steps that must happen
   *between* two systems' `_ready()` calls (the snapshot at step 5) and
   steps gated on a runtime state transition, not just load order (step 6
   only starts once steps 1–5 are done; step 9 only runs once steps 5 and 7
   both hold) — nothing today owns *driving* that sequence.

### Constraints
- This project has exactly one jar, one session, no multiplayer, no
  save-file switching — the communication and sequencing patterns should
  match that scale, not a hypothetical larger one (`architecture.md`'s own
  "every autoload is a singleton, no multi-jar support" invariant).
- 11 MVP systems, mostly pairwise dependencies per `systems-index.md`, not
  a many-to-many mesh — no system currently needs to broadcast to more than
  a handful of named consumers.
- `coding-standards.md` requires all public methods be unit-testable
  (dependency injection over singletons) — whatever owns the init sequence
  must not make the individual systems harder to test in isolation.
- The save/load sequence (`architecture.md` Data Flow §3) and init order
  (§4) are two views of largely the same sequence and must not diverge.

### Requirements
- Must give every future ADR a citable, already-decided answer to "signal
  or direct call?" so this doesn't get re-litigated per-system.
- Must name a concrete owner for the 11-step session-start sequence,
  including the snapshot point, that can be pointed to in code review.
- Must not introduce a new indirection layer (event bus/mediator) that no
  current GDD requirement justifies.
- Must keep Discovery Surfacing's snapshot data private to the system that
  needs it (Discovery Surfacing), not leak Presentation-layer bookkeeping
  into a Core-layer system like Ecosystem Simulation.

## Decision

### 1. Communication convention: direct calls for commands/queries, signals for notification

Formalizing the pattern `architecture.md`'s Data Flow §2 already found in
every GDD's Interactions table:

- **Commands and queries** (a caller needs a specific system to *do*
  something, or needs a specific answer *now*) use **direct typed method
  calls** on the owning system's public API. Example: `TendingInput` calls
  `EcosystemSimulation.apply_watering(amount)`; anything needing a type
  definition calls `ContentData.get_definition(id)` (ADR-0001).
- **Notifications** (a system needs to tell an unknown/variable number of
  interested parties that something happened, without needing to know who's
  listening) use **Godot signals**. Example: Input Abstraction's
  `tap`/`drag_start`/`drag_move`/`drag_end` signals, consumed by Object
  Placement and Tending Input without Input Abstraction knowing either
  exists.
- **No central event bus or mediator autoload.** Every producer/consumer
  pair in the 11 MVP GDDs is already a named, pairwise relationship (see
  `systems-index.md`'s dependency table) — routing all of it through one
  dispatcher would add a layer of indirection with no current multi-consumer
  fan-out need to justify it.
- **Rule of thumb for future systems**: if the caller needs a return value
  or must guarantee the callee ran before the next line executes, it's a
  direct call. If the caller doesn't know or care who (if anyone) is
  listening, it's a signal.

This registers as a forbidden-pattern entry (event-bus/mediator routing)
and an interface-contract default (direct_call for commands/queries,
signal for notifications) in the architecture registry — see Step 6 below.

### 2. Initialization/save-load sequencing owner: `SessionBootstrap` autoload

A new, minimal Foundation-layer autoload, **`SessionBootstrap`**, owns
*driving* — not mediating — the exact 11-step sequence already documented
in `architecture.md` Data Flow §3/§4. It is the **last** autoload in
project load order. Godot adds autoloads to the tree — and calls their
`_ready()` — in Project Settings list order; `SessionBootstrap` calls
directly into `ContentData`, `PersistenceSave`, `EcosystemSimulation`,
`ObjectPlacement`, `DiscoverySurfacing`, `TimeDrift`, and
`CreatureBehavior`, so every one of those autoloads' own `_ready()` must
already have run before `SessionBootstrap._ready()` fires — placing it
last guarantees that (`godot-specialist` review, 2026-08-10 — the initial
draft had this backwards, listing `SessionBootstrap` first, which would
have called into every other system before its own `_ready()` had
initialized it). Its entire job is to call the already-decided direct-call
APIs of each system, in the already-decided order, once, at session start:

```gdscript
# SessionBootstrap (autoload) — Foundation, LAST in load order
# (must be last: it calls into every other autoload listed below, all of
# which must have already run their own _ready() first)
func _ready() -> void:
    # Step 1 — no call here. ContentData's own _ready() has already
    # populated its registry by the time this fires: SessionBootstrap loads
    # LAST (Decision §2 / registry api_decision
    # session_init_and_save_load_sequencing), so ContentData's _ready() is
    # guaranteed complete first. Listed only to preserve Data Flow §3's
    # canonical step numbering — there is no ContentData.load_registry()
    # method (ADR-0001 exposes get_definition(id) only; registry population
    # is internal to ContentData._ready()).
    # Step 2 — get_restored_blob() returns {} when load() is false: ADR-0005's
    # _restored_blob is a typed `Dictionary` field, which GDScript defaults to
    # {} (not null) until load() assigns it on a successful restore path.
    # The explicit `if loaded else {}` below is redundant with that default,
    # kept for readability rather than relying on an unstated field default.
    var loaded := PersistenceSave.load()
    var restored: Dictionary = PersistenceSave.get_restored_blob() if loaded else {}
    # Steps 3-4 — restored is {} on a fresh/failed load; both restore()
    # methods default every id from Content Data's registry in that case
    # (see ADR-0004 Decision §5 / ADR-0003 Decision §3, companion edits below).
    EcosystemSimulation.restore(restored)
    ObjectPlacement.restore(restored)
    # Step 5 — SNAPSHOT POINT
    DiscoverySurfacing.capture_pre_batch_snapshot()
    # Steps 6-7 — one atomic call spans both: catch-up (6) then the
    # CATCHING_UP -> ACTIVE transition (7). See ADR-0006 Decision.
    TimeDrift.run_catchup_and_activate()
    # Step 8
    CreatureBehavior.resolve_session_start()
    # Step 9
    DiscoverySurfacing.compute_delta()
    # Steps 10-11 happen implicitly: Diorama Rendering/Ambient Audio read
    # already-settled state from their own _process(); Persistence/Save's
    # confirmation cue fires from within load() at step 2, not here.
```

`SessionBootstrap` is **not** a mediator for ongoing runtime communication
— after `_ready()` completes, it does nothing else and is never called by
another system. It exists solely because the 11-step sequence has real
ordering dependencies (a snapshot that must be taken between two other
systems' initialization, a batch that must complete before a state
transition) that Godot's own autoload load-order guarantee cannot express
by itself. This is the minimum concrete owner the already-documented
sequence needs — not a new architectural pattern.

Session end (backgrounding/close) is **not** owned by `SessionBootstrap`
— per `architecture.md` Data Flow §3, that path is triggered by
Persistence/Save's own `visibilitychange`/close-detection handlers, which
call `EcosystemSimulation`/`ObjectPlacement` getters directly. No
sequencing owner is needed there; it's a single system gathering state it
already has direct-call access to.

### 3. Discovery Surfacing owns its own pre-batch snapshot

`DiscoverySurfacing` gains two new public methods and one private field:

```gdscript
# Discovery Surfacing — Presentation
func capture_pre_batch_snapshot() -> void
# Called once by SessionBootstrap, after Ecosystem Simulation/Object
# Placement restore (step 5), before Time & Drift's catch-up batch (step 6).
# Internally deep-copies the handful of primitives Discovery Surfacing's own
# delta computation needs — jar_moisture, per-plant growth_stage, per-creature
# PRESENT/ABSENT + last_known_position — via direct calls to Ecosystem
# Simulation's existing getters. Stored in a private _pre_batch_snapshot: Dictionary.

func compute_delta() -> void
# Called once by SessionBootstrap at step 9 (after Creature Behavior settles).
# Diffs current/settled state (read via the same direct-call getters) against
# _pre_batch_snapshot, populating the Array[DiscoveryItem] that get_active_items()
# already returns per architecture.md's existing API Boundary. _pre_batch_snapshot
# is discarded after this call — never persisted, never read again this session.
```

A **deep-copy snapshot of primitives**, not a replay log: `jar_moisture`
(float), `light_level` (float), a `Dictionary[String, int]` of per-plant
`growth_stage`, and a `Dictionary[String, Variant]` of per-creature
PRESENT/ABSENT + `last_known_position` — all cheap value types, no nested
Resources, so `.duplicate(true)` (recursive copy, available since Godot 3
— not the same as `duplicate_deep()`, which is Resource-specific and
unneeded here since nothing snapshotted is itself a Resource) is required
on the outer Dictionary. Plain `.duplicate()` (no args, the initial draft's
mistake — `godot-specialist` review, 2026-08-10) is a **shallow** copy: the
nested per-plant/per-creature dictionaries would stay shared by reference
with live Ecosystem Simulation state and silently mutate during the
catch-up batch, defeating the snapshot's entire purpose. Ecosystem Simulation is not modified to
support this — Discovery Surfacing reads it through the direct-call
getters it would need anyway.

### Architecture Diagram
```
SessionBootstrap._ready()  (Foundation, LAST autoload to load, session start only)
  │
  ├─ 1. (no call — ContentData._ready() already ran, guaranteed by load order)
  ├─ 2. PersistenceSave.load() / get_restored_blob()
  ├─ 3-4. EcosystemSimulation.restore(restored) / ObjectPlacement.restore(restored)
  ├─ 5. DiscoverySurfacing.capture_pre_batch_snapshot() ──┐
  ├─ 6-7. TimeDrift.run_catchup_and_activate()            │ (deep-copy,
  ├─ 8. CreatureBehavior.resolve_session_start()           │  held privately)
  └─ 9. DiscoverySurfacing.compute_delta() <───────────────┘
           │
           ▼
   get_active_items() -> Array[DiscoveryItem]   (existing API, unchanged)

Ongoing runtime (post-session-start):
  TendingInput ──direct call──> EcosystemSimulation.apply_watering()
  InputAbstraction ──signal(tap/drag_*)──> ObjectPlacement, TendingInput
  (no event bus; every producer/consumer pair is a named, pairwise relationship)
```

### Key Interfaces
```gdscript
# SessionBootstrap (autoload) — Foundation, loads LAST (must come after
# every autoload it calls into, so their own _ready() has already run)
# No public API beyond _ready() — nothing calls into SessionBootstrap after
# session start; it only calls out, once, in the documented order.

# Discovery Surfacing — Presentation (additions to the existing API)
func capture_pre_batch_snapshot() -> void
func compute_delta() -> void
# Both idempotent-by-convention-only (not guarded) — SessionBootstrap calls
# each exactly once per session, per architecture.md's existing invariant
# "computed exactly once per session (at CATCHING_UP→ACTIVE), immutable afterward."
```

**Revision note (2026-08-10)**: the `_ready()` pseudocode above originally
called methods that did not match any downstream ADR's actual Key
Interfaces (`ContentData.load_registry()`, `PersistenceSave.load_blob()`,
`EcosystemSimulation.restore()`, `ObjectPlacement.restore()`,
`TimeDrift.run_catchup_and_activate()`, `CreatureBehavior.settle_from_ecosystem_state()`)
— flagged three consecutive times as TR-crosscutting-003 in
`docs/consistency-failures.md`. This revision reconciles all six:

| Original call | Resolution | Where decided |
|---|---|---|
| `ContentData.load_registry()` | Removed — no such method exists; registry population is internal to `ContentData._ready()`, already complete by construction before this fires. | This ADR, Decision §2 (SessionBootstrap loads LAST). |
| `PersistenceSave.load_blob()` | Replaced with `load()` + `get_restored_blob()`, ADR-0005's actual pull-based pair. | ADR-0005 Key Interfaces (unchanged by this revision). |
| `EcosystemSimulation.restore(restored)` | Kept, but the method didn't exist on ADR-0004's Key Interfaces — added as a companion edit. | ADR-0004 Decision §5 (new, this revision). |
| `ObjectPlacement.restore(restored)` | Kept, but ADR-0003 declared "No public write API" — added as a companion edit, with that guarantee's scope clarified to mean no public *runtime* write API. | ADR-0003 Decision §3 (new, this revision). |
| `TimeDrift.run_catchup_and_activate()` | Kept — ADR-0006 described this sequence narratively but never named a callable; formalized as a companion edit. | ADR-0006 Key Interfaces (new, this revision). |
| `CreatureBehavior.settle_from_ecosystem_state()` | Renamed to `resolve_session_start()`, ADR-0007's actual method — no interface change needed there, just the caller. | ADR-0007 Key Interfaces (unchanged by this revision). |

None of these are renames-only where the target ADR already had a matching
method under a different name (except CreatureBehavior, which was a true
rename). The other three required an explicit new-method decision, made in
the companion-edited ADR itself, not invented silently in this pseudocode.

## Alternatives Considered

### Alternative 1: Central event bus / mediator autoload
- **Description**: One autoload (`EventBus`) that every system publishes
  to and subscribes through, replacing direct calls entirely.
- **Pros**: Maximum decoupling — producers never reference consumers by
  name; easy to add a new consumer without touching the producer.
- **Cons**: Every one of the 11 MVP GDDs already documents a small,
  specific, pairwise dependency list (per `systems-index.md`) — there is
  no many-to-many fan-out need today. An event bus also loses call-site
  traceability (you can't `grep` for who calls `apply_watering()` if it's
  routed through a generic `EventBus.emit("watering_applied", amount)`)
  and loses return values for anything that needs one (`get_definition()`,
  `get_position()`).
- **Rejection Reason**: Solves a fan-out problem this project doesn't have
  yet, at the cost of traceability and typed return values this project
  needs today. Revisit only if a system genuinely needs to notify an
  unbounded/unknown set of consumers — none does at MVP scope.

### Alternative 2: All-signal pub/sub (no direct calls)
- **Description**: Replace every direct method call, including
  synchronous queries like `get_definition()`, with signals.
- **Pros**: One uniform communication mechanism everywhere.
- **Cons**: Godot signals cannot synchronously return a value to the
  caller — `get_definition(id) -> Resource` and `get_position(object_id)
  -> Vector2` are inherently request/response, not fire-and-forget.
  Forcing these through signals would require an async
  emit-then-await-a-response-signal dance for what is a single
  synchronous lookup today.
- **Rejection Reason**: Actively worse for the operations that are
  inherently synchronous request/response, with no compensating benefit —
  uniformity for its own sake, not a real requirement.

### Alternative 3: Snapshot as a replay log of per-tick deltas
- **Description**: During Time & Drift's catch-up batch, log each
  individual tick's state change; Discovery Surfacing aggregates the log
  afterward instead of diffing two snapshots.
- **Pros**: Could in principle support a richer "here's what happened, in
  order" narrative rather than only a before/after diff.
- **Cons**: No GDD asks for tick-by-tick history — `discovery-surfacing.md`
  only ever needs a single before/after delta (Core Rule 7). A replay log
  is strictly more data, more code (a log structure, an aggregation pass),
  and more memory for a session that can batch up to
  `max_catchup_ticks=84` ticks, for a feature nothing consumes.
- **Rejection Reason**: Speculative complexity — building for a
  requirement ("what happened at tick 43 specifically") that doesn't
  exist in any of the 11 approved GDDs.

### Alternative 4: Ecosystem Simulation owns the snapshot
- **Description**: `EcosystemSimulation` exposes `get_state_snapshot()`
  and holds the captured Dictionary itself until Discovery Surfacing asks
  for it.
- **Pros**: One fewer method on Discovery Surfacing's API.
- **Cons**: Makes a Core-layer system (Ecosystem Simulation, the "central
  state owner" per `architecture.md`'s Module Ownership) respons­ible for
  Presentation-layer bookkeeping — deciding when to hold, serve, and clear
  data only Discovery Surfacing cares about. Couples Ecosystem
  Simulation's lifecycle to a concern it shouldn't need to know exists.
- **Rejection Reason**: Ownership belongs with the consumer that has the
  requirement, not the producer being queried — Ecosystem Simulation
  already exposes the getters Discovery Surfacing needs; making it also
  manage snapshot lifecycle state is an unrequested responsibility.

## Consequences

### Positive
- Every future ADR can cite this one instead of re-deciding
  signal-vs-direct-call per system — already true of Object Placement,
  Ecosystem Simulation, Time & Drift, Creature Behavior, Persistence/Save,
  Discovery Surfacing, whose GDDs all implicitly assumed this pattern
  already.
- The 11-step session-start sequence now has one file (`SessionBootstrap`)
  a developer can read top-to-bottom to understand session start, instead
  of reverse-engineering it from `architecture.md`'s prose.
- Discovery Surfacing's snapshot bookkeeping stays private to Discovery
  Surfacing — no other system's public API grows a
  Presentation-layer-specific method.

### Negative
- `SessionBootstrap` is a new file/autoload that didn't exist as a named
  concept before this ADR — one more thing to know about, even though its
  job is small and fixed.
- The direct-call convention means adding a new consumer of an existing
  system still requires that system's producer code to be aware of
  nothing (good), but any *new command* a consumer needs requires adding a
  method to the producer's public API rather than just subscribing to an
  existing signal — a deliberate trade-off, not a defect.

### Risks
- **Risk**: `SessionBootstrap`'s `_ready()` could silently become a
  dumping ground for unrelated startup logic over time, drifting from "one
  documented sequence" into a general-purpose init grab-bag.
  **Mitigation**: Its only job is executing the numbered sequence in
  `architecture.md` Data Flow §3/§4 — any code review adding logic to
  `SessionBootstrap` that isn't one of those 11 steps should ask whether
  it belongs to the system it concerns instead.
- **Risk**: `capture_pre_batch_snapshot()`/`compute_delta()` being called
  more than once per session (e.g. a future refactor accidentally calls
  `SessionBootstrap._ready()` logic twice) would corrupt the delta.
  **Mitigation**: Both methods are documented as "called exactly once per
  session" per the existing `get_active_items()` invariant already in
  `architecture.md`; not runtime-guarded (matches this project's existing
  by-convention-not-by-guard pattern, e.g. content-data.md Core Rule 2) —
  acceptable at MVP scope, same reasoning as that precedent.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| discovery-surfacing.md | Departure/delta computation needs a pre-batch reference state (Core Rule 7 sourcing, `architecture.md` Data Flow §3 step 5's flagged gap) | `capture_pre_batch_snapshot()`/`compute_delta()`, owned by Discovery Surfacing itself. |
| ecosystem-simulation.md | Exposes state via direct-call getters/commands (`apply_watering()`, `advance_tick()`, `set_last_known_position()`) | Confirmed as the project-wide convention (Decision §1); no change needed to this GDD's already-assumed API shape. |
| time-drift.md | Catch-up batch (steps 6-7) must run only after restore + snapshot are complete | `SessionBootstrap` sequences this explicitly; Time & Drift's own `run_catchup_and_activate()` is unchanged, just called at the right point. |
| input-abstraction.md | Gesture signals (`tap`, `drag_start`, etc.) consumed by multiple systems without Input Abstraction knowing who | Confirmed as the notification half of Decision §1 — no change, formalized as the intended pattern. |
| architecture.md | Data Flow §2 "this absence is itself a decision that needs an ADR"; Data Flow §3 step 5 "flagged as a Required ADR"; Data Flow §4 init order | Resolves all three flagged gaps in one ADR, per this document's own Required ADRs list. |

## Performance Implications
- **CPU**: Negligible — `SessionBootstrap._ready()` runs once per session;
  `capture_pre_batch_snapshot()`/`compute_delta()` copy a handful of
  primitives (single digits of plants/creatures at MVP scope).
- **Memory**: `_pre_batch_snapshot` holds a small Dictionary for the
  duration of one session-start sequence, discarded immediately after
  `compute_delta()` — not retained for the session's lifetime.
- **Load Time**: Adds one autoload's `_ready()` call to the existing
  session-start critical path; the work it drives (steps 1-9) was always
  going to happen — this ADR only names who calls it in what order.
- **Network**: N/A.

## Migration Plan
N/A — no existing implementation of session-start sequencing or Discovery
Surfacing's delta computation exists yet. This is the initial decision.

## Validation Criteria
- A unit test constructs `DiscoverySurfacing` with injected/mocked
  Ecosystem Simulation state (per `coding-standards.md`'s DI requirement),
  calls `capture_pre_batch_snapshot()`, mutates the mocked state, calls
  `compute_delta()`, and confirms the resulting `Array[DiscoveryItem]`
  matches the expected diff for each of `discovery-surfacing.md`'s
  documented delta categories (Growth/Arrival/Departure/Detail Event).
- An integration or smoke test runs `SessionBootstrap._ready()` against a
  fresh (no save data) and a restored (mocked blob) session and confirms
  all 11 Data Flow §3 steps execute in the documented order with no step
  reading state a prior step hasn't yet written.

## Related Decisions
- `docs/architecture/adr-0001-content-data-format.md` — establishes the
  `content_data_query` interface as `direct_call`, consistent precedent
  for this ADR's Decision §1 (no conflict; ADR-0001 predates this ADR's
  formal codification of the convention).
- `docs/architecture/architecture.md` — Data Flow §2/§3/§4, the source of
  all three gaps this ADR resolves; API Boundaries section, extended by
  Discovery Surfacing's two new methods, and (this revision) by
  `EcosystemSimulation.restore()`, `ObjectPlacement.restore()`, and
  `TimeDrift.run_catchup_and_activate()`. Data Flow §4 (init order) is also
  renumbered by this revision to stop diverging from §3 (see that
  document's own history for the prior 6-vs-7-step mismatch this caused in
  ADR-0007's citation).
- **Companion-edits this revision (2026-08-10)**: `docs/architecture/adr-0003-object-placement-collision-approach.md`
  (adds `restore()`), `docs/architecture/adr-0004-ecosystem-simulation-tick-architecture.md`
  (adds `restore()`), `docs/architecture/adr-0006-time-drift-session-lifecycle.md`
  (adds `run_catchup_and_activate()` to Key Interfaces). `docs/architecture/adr-0007-creature-behavior-wander-state-machine.md`
  is corrected for a step-number citation only (7 → 8), no interface change.
- `docs/consistency-failures.md` — TR-crosscutting-003, the conflict this
  revision resolves (flagged three times across three `/architecture-review`
  passes before being executed here).
