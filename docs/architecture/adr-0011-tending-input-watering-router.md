# ADR-0011: Tending Input — Watering Router Implementation Strategy

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-11

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Input / Core (signal-consuming router; no raw `InputEvent` handling of its own) |
| **Knowledge Risk** | LOW — this ADR introduces no new engine API surface. It consumes an already-formalized signal (ADR-0008) and makes direct method calls (ADR-0002's convention); both patterns are stable well before the LLM's training cutoff. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/modules/input.md` |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | None beyond what ADR-0008 already tracks for the upstream `tap` signal itself (Gate A1/A3/A4) — this ADR adds no new verification surface. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0008 (gesture_input_delivery signal contract — `tap` is this ADR's only trigger), ADR-0003 (Object Placement — footprint exclusion query), ADR-0004 (Ecosystem Simulation — `apply_watering()` target) |
| **Enables** | None — Tending Input is a leaf consumer; no other ADR depends on anything this one produces. |
| **Blocks** | Tending Input implementation stories (already stated as blocked by `design/gdd/tending-input.md` itself) |
| **Ordering Note** | Should be Accepted after ADR-0003, ADR-0004, and ADR-0008, since its Key Interfaces call directly into all three. |

## Context

### Problem Statement

`design/gdd/tending-input.md` is fully approved and deliberately thin: a
stateless router that turns a qualifying `tap` into exactly one
`EcosystemSimulation.apply_watering(watering_amount)` call. What's
undecided is the concrete implementation: what module owns this router,
and — the real gap — how it gets footprint-exclusion data. ADR-0003's
registered interface for Object Placement (`get_position()`/`is_held()`)
exposes neither footprint size nor an enumerable object list, and Tending
Input is not a registered consumer of Content Data's `footprint_size`
field (`docs/registry/architecture.yaml` `content_data_query` contract) —
by design, since Object Placement already owns and caches that data per
ADR-0003. A second, smaller gap exists on the Ecosystem Simulation side:
`apply_watering(amount: int)`'s locked signature requires the caller to
supply the amount, but no interface currently exposes the configured
`watering_amount` value for Tending Input to read — the GDD's own AC1
explicitly forbids hardcoding it.

### Constraints
- No central event-bus/mediator autoload (registry `forbidden_patterns:
  event_bus_mediator`) — must use direct signal connection to
  `InputAbstraction.tap` and direct method calls outward.
- Footprint size must not leak into a second system. `content_data_query`'s
  registered consumer list does not include tending-input, and this ADR
  must not add it — Object Placement already owns and caches
  `footprint_size` (ADR-0003 Decision), so a second read path would be a
  duplicate source of truth for the same field.
- `coding-standards.md`: dependency injection over singletons; static
  typing on all public methods.
- GDD Edge Cases: input handling must not be enabled before Ecosystem
  Simulation has finished initializing — avoided structurally per the GDD,
  not by a runtime guard.

### Requirements
- On a qualifying `tap` (in jar bounds, not on any object footprint), call
  `EcosystemSimulation.apply_watering(watering_amount)` exactly once,
  same-frame, no `call_deferred`/`await`/`CONNECT_DEFERRED` anywhere in the
  chain (GDD Core Rule 3 implementation note).
- A `tap` on an object's footprint, or outside the jar's floor ellipse,
  must not call `apply_watering` and must not error.
- `drag_start`/`drag_move`/`drag_end` events must never be consumed by this
  system (GDD AC9) — only `tap`.

## Decision

**Tending Input is a single stateless autoload, `TendingInput`** — zero
scene-tree nodes, zero persisted fields — matching the project's
established autoload-per-system convention (`InputAbstraction`,
`ObjectPlacement`, `EcosystemSimulation`) even though it owns no state of
its own. It connects to `InputAbstraction.tap` once, in its own
`_ready()`, using a direct (non-deferred) `Callable` connection.

On `tap(position, device_id)`:
1. Reject if `not ObjectPlacementMath.in_bounds(position, jar_center, jar_radii, 0.0)` —
   reusing ADR-0003's existing `in_bounds` formula at its `fp = 0.0`
   degenerate case (a point-in-ellipse check), rather than adding a second
   formula that duplicates the same math. `jar_center`/`jar_radii` are
   read once at `_ready()` from the same source `object-placement.md`'s
   own `in_bounds` calls already use (no new constant is introduced here).
2. Reject if `ObjectPlacement.is_within_any_footprint(position)` returns
   `true`.
3. Otherwise call `EcosystemSimulation.apply_watering(watering_amount)`
   exactly once, where `watering_amount` is read via a new
   `EcosystemSimulation.get_watering_amount() -> int` getter (see
   companion edit below) — never redefined or hardcoded here, per the
   GDD's Formulas section and AC1.

**Companion edit to ADR-0004 (Ecosystem Simulation)**: `apply_watering(amount: int) -> void`'s
locked signature (ADR-0002, ADR-0004, `architecture.md`) requires the
*caller* to supply the amount — but no existing interface exposes the
configured `watering_amount` value for a caller to read. `EcosystemSimulation`
gains one new getter,

```gdscript
func get_watering_amount() -> int
```

backed by a new `const WATERING_AMOUNT: int = 25` (`ecosystem-simulation.md`
Tuning Knobs' recommended value — no prior ADR draft had actually declared
this as a stored constant anywhere; `EcosystemFormulas.moisture_after_watering`
takes `watering_amount` as a caller-supplied parameter, it doesn't read the
constant itself). Follows the exact pattern already established for this
autoload's other companion-edit getters (`get_plant_ids()`, `get_creature_ids()`,
etc., added by Discovery Surfacing's ADR) — a small, precedented addition,
not a new pattern.

**Companion edit to ADR-0003 (Object Placement)**: Object Placement gains
one new public query method,

```gdscript
func is_within_any_footprint(point: Vector2) -> bool
```

which iterates its own `_objects: Dictionary` registry internally,
calling `ObjectPlacementMath.footprint_hit(point, obj.position, obj.footprint_size)`
per entry, and returns `true` on the first hit. This keeps `footprint_size`
private to Object Placement (its existing single-owner cache, per ADR-0003
Decision) — Tending Input never reads Content Data directly and never
enumerates objects itself. `ObjectState` gains a `footprint_size: float`
field (cached once at registry population, same lifecycle as `position`)
so the new method has something to compare against without a second
`ContentData.get_definition()` call.

No new state ownership registry entry is needed: `footprint_size` becomes
part of the existing `object_position_held_grab_offset` state entry's
internal representation, not a newly externally-owned/queried field — the
only new *interface* surface is the one boolean-returning method.

### Architecture Diagram
```
InputAbstraction.tap(position, device_id)
   │  (direct signal connection, ADR-0002 convention)
   ▼
TendingInput._on_tap()  (autoload, zero persisted state)
   │
   ├─ in_bounds(position, jar_center, jar_radii, fp=0.0)?  ── reused from
   │     ObjectPlacementMath (ADR-0003) — no ── reject, no call, no error
   │
   ├─ ObjectPlacement.is_within_any_footprint(position)?  ── true ── reject,
   │     no call, no error (Object Placement's own tap handler already
   │     plays the wobble ack for this same tap, per ADR-0003)
   │
   └─ EcosystemSimulation.apply_watering(EcosystemSimulation.get_watering_amount())
        ── exactly once, same frame, no deferred/await anywhere in this chain

ObjectPlacement (autoload, ADR-0003)
   │  NEW: is_within_any_footprint(point: Vector2) -> bool
   │       iterates _objects internally, calls
   │       ObjectPlacementMath.footprint_hit() per entry
   │  ObjectState gains: footprint_size: float (cached at population,
   │       same lifecycle as position/held/grab_offset)

EcosystemSimulation (autoload, ADR-0004)
   │  NEW: get_watering_amount() -> int
   │       returns the internally-configured tuning value, so Tending
   │       Input never hardcodes or redefines it (GDD AC1)
```

### Key Interfaces
```gdscript
# TendingInput (autoload) — Core, zero persisted fields
# No public API of its own — pure leaf consumer, same pattern as
# Diorama Rendering's role relative to Object Placement (architecture.md).
func _ready() -> void:
    InputAbstraction.tap.connect(_on_tap)

func _on_tap(position: Vector2, device_id: int) -> void:
    if not ObjectPlacementMath.in_bounds(position, _jar_center, _jar_radii, 0.0):
        return
    if ObjectPlacement.is_within_any_footprint(position):
        return
    EcosystemSimulation.apply_watering(EcosystemSimulation.get_watering_amount())

# ObjectPlacement (autoload, ADR-0003) — companion edit, this ADR
func is_within_any_footprint(point: Vector2) -> bool
# NEW. Iterates _objects internally; true on first footprint_hit. Keeps
# footprint_size private to Object Placement — no second read path for
# data ADR-0003 already owns and caches.

# ObjectState (object_state.gd) — companion edit, this ADR
# var footprint_size: float   # NEW — cached at registry population,
#                              # same lifecycle as position/held/grab_offset

# EcosystemSimulation (autoload, ADR-0004) — companion edit, this ADR
func get_watering_amount() -> int
# NEW. Returns the internally-configured tuning value so Tending Input
# never hardcodes/redefines it (GDD AC1). Same companion-edit pattern as
# get_plant_ids()/get_creature_ids() etc.
```

## Alternatives Considered

### Alternative 1: Enumeration + getter (`get_object_ids()` + `get_footprint_size(id)`)
- **Description**: Object Placement exposes the object id list and a
  per-object footprint getter; Tending Input loops itself, calling the
  already-unit-tested `ObjectPlacementMath.footprint_hit` directly.
- **Pros**: Keeps all footprint *math* in one place
  (`ObjectPlacementMath`), same as today; Tending Input's loop is trivial
  and visible at the call site.
- **Cons**: Widens Object Placement's public surface by two methods
  instead of one, and hands the *iteration* (not just the math) to a
  second system — a future change to how objects are stored (e.g. a
  spatial index instead of a flat `Dictionary`) would need to keep the
  enumeration contract stable for an external caller that doesn't actually
  need per-object detail, only a yes/no answer.
- **Rejection Reason**: Tending Input never needs individual object
  identities or positions — only "is this point inside *any* footprint."
  A single encapsulated query matches the actual shape of the need and
  keeps both the data and the iteration strategy private to their owner.

### Alternative 2: Tending Input reads Content Data directly
- **Description**: Tending Input calls `ContentData.get_definition(type_id)`
  itself for `footprint_size`, paired with `ObjectPlacement.get_position()`.
- **Pros**: None found — Tending Input still doesn't have `type_id` per
  object or a way to enumerate objects without Object Placement's help
  anyway, so this doesn't remove the Object Placement dependency, it only
  adds a second one.
- **Cons**: Duplicates a read path for data ADR-0003 already caches;
  registry's `content_data_query` contract would need tending-input added
  as a consumer for a field it only needs indirectly, via positions Object
  Placement already owns.
- **Rejection Reason**: Strictly worse than Alternative 1/the Decision —
  more dependencies, no new capability.

### Alternative 3: New standalone point-in-ellipse helper for jar bounds
- **Description**: A dedicated pure function separate from
  `ObjectPlacementMath.in_bounds`, written specifically for the
  no-footprint case.
- **Pros**: Conceptually separates "is this point in the jar" from "is
  this point near a specific object," which are different questions even
  if the underlying math coincides.
- **Cons**: A second formula computing the same ellipse membership test
  `in_bounds` already computes at `fp = 0.0` — two things to keep in sync
  if the jar's ellipse ever changes shape.
- **Rejection Reason**: `in_bounds`'s existing domain precondition
  (`fp < min(rx, ry)`) is trivially satisfied at `fp = 0.0`, so the
  degenerate case is exact, not an approximation — reusing it costs
  nothing and removes a duplicate formula.

## Consequences

### Positive
- Object Placement remains the sole owner of `footprint_size` and object
  enumeration — no second read path, no registry conflict.
- Reusing `ObjectPlacementMath.in_bounds` at `fp=0.0` means the jar-bounds
  check and the object-placement-bounds check can never silently drift
  apart into two different ellipses.
- Tending Input stays exactly as thin as the GDD specifies: one signal
  connection, two guard checks, one outward call — nothing to unit-test
  beyond wiring, since both guard checks delegate to already-tested pure
  functions.

### Negative
- `is_within_any_footprint` (ADR-0003) and `get_watering_amount()`
  (ADR-0004) are companion edits to two existing ADRs rather than changes
  scoped entirely to this document — anyone reading ADR-0003 or ADR-0004
  alone will not see these methods unless those files are also updated.
- `ObjectState.footprint_size` duplicates a value Content Data already
  holds (by design, per ADR-0003's existing caching decision) — this ADR
  adds a second cached copy of it inside the query surface, not a new
  duplication pattern, but worth naming.

### Risks
- **Risk**: If a future GDD revision makes Tending Input need per-object
  detail (e.g., different watering behavior per object type), the
  encapsulated `is_within_any_footprint(point) -> bool` boolean would need
  to be replaced with something richer.
  **Mitigation**: None needed now — `tending-input.md`'s own Formulas
  section explicitly states this system has no per-object logic of its
  own; this is a YAGNI call matching the GDD's current, approved scope,
  not a speculative gap.
- **Risk** (`godot-specialist` finding): the GDD's "input handling must
  not be enabled before Ecosystem Simulation has finished initializing"
  guarantee is structural, not a runtime guard — it depends entirely on
  Project Settings → Autoload declaration order. `EcosystemSimulation` and
  `InputAbstraction` must be declared **before** `TendingInput` in that
  list so their `_ready()` completes first (the signal connection itself
  is order-independent — signals exist at object construction, not
  `_ready()` — but the initialization guarantee is not).
  **Mitigation**: Name this explicitly in the implementation story/PR
  checklist; no code-level guard is needed if the autoload order is
  correct, matching how `InputAbstraction.register_jar()`'s ordering
  guarantee is already handled project-wide (ADR-0008).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| tending-input.md | Core Rule 1 (tap in jar bounds, not on object footprint, triggers watering) | `_on_tap()`'s two guard checks, in order: `in_bounds` (jar ellipse) then `is_within_any_footprint` (object exclusion). |
| tending-input.md | Core Rule 2 (`apply_watering` called exactly once, no batching) | Single call site, no loop, no retry path. |
| tending-input.md | Core Rule 3 implementation note (no `call_deferred`/`await`/`CONNECT_DEFERRED`) | Direct signal connection, direct method calls throughout `_on_tap()` — nothing in the chain defers to a later frame. |
| tending-input.md | Core Rule 4 (no cooldown, no state) | `TendingInput` holds zero persisted fields; every `tap` is handled identically and independently, matching "States and Transitions: N/A." |
| tending-input.md | AC1 (calls the configured `watering_amount`, not a redefined literal) | `_on_tap()` reads it via the new `EcosystemSimulation.get_watering_amount()` companion-edit getter, never redefines the value. |
| tending-input.md | AC2/AC4/AC8 (footprint/boundary/overlap exclusion, no error) | All three route through the single `is_within_any_footprint` boolean — no per-case branching needed, since the method already handles boundary-inclusive and overlapping-footprint cases per ADR-0003's `footprint_hit` semantics. |
| tending-input.md | AC5 (outside jar ellipse excluded) | `in_bounds(..., fp=0.0)` guard. |
| tending-input.md | AC7 (no objects placed → every in-bounds tap waters) | `is_within_any_footprint` returns `false` on an empty registry with no special-casing required. |
| tending-input.md | AC9 (drag events never trigger watering) | `TendingInput` only connects to `InputAbstraction.tap` — it never subscribes to `drag_start`/`drag_move`/`drag_end`. |
| object-placement.md | Footprint hit-test formula (`footprint_hit`) | Reused via the new `is_within_any_footprint` wrapper — no new footprint math written. |

## Performance Implications
- **CPU**: `is_within_any_footprint` is O(n) over a small, fixed object
  count (MVP: a handful) — same complexity class as `no_overlap`
  (ADR-0003), negligible. `in_bounds` at `fp=0.0` is O(1).
- **Memory**: One `float` field added per `ObjectState` entry — trivial.
- **Load Time**: None — `TendingInput` has no data to load, only a signal
  connection made at `_ready()`.
- **Network**: N/A.

## Migration Plan
N/A — new system, no existing implementation to migrate from.

## Validation Criteria
- Unit tests drive `TendingInput._on_tap()` (or an equivalent injectable
  entry point) against `tending-input.md`'s Acceptance Criteria 1–9,
  using a fake/stub `ObjectPlacement` and `EcosystemSimulation` to isolate
  from their live registries, per `coding-standards.md`'s
  dependency-injection requirement.
- `ObjectPlacement.is_within_any_footprint` is covered by ADR-0003's own
  test suite once implemented (it's a thin wrapper over the
  already-tested `ObjectPlacementMath.footprint_hit`).

## Related Decisions
- `docs/architecture/adr-0008-input-gesture-abstraction-web-touch-focus.md`
  — source of the `tap` signal this ADR's entire Decision is triggered by.
- `docs/architecture/adr-0003-object-placement-collision-approach.md` —
  owner of `footprint_size`/object state; companion-edited by this ADR to
  add `is_within_any_footprint()` and `ObjectState.footprint_size`.
- `docs/architecture/adr-0004-ecosystem-simulation-tick-architecture.md`
  — owner of `apply_watering()`, this ADR's only outward write call;
  companion-edited by this ADR to add `get_watering_amount()`.
- `design/gdd/tending-input.md` — full behavioral specification this ADR
  implements.
