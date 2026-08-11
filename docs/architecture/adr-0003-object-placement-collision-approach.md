# ADR-0003: 2D Placement/Collision Approach (Object Placement)

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Physics / Core (deliberately physics-free) |
| **Knowledge Risk** | LOW — this decision explicitly avoids the one HIGH-risk area in this domain (Jolt Physics, the 4.6+ 3D default) by using no physics engine at all; plain `Vector2` math is stable pre-cutoff. |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md` (confirms 2D physics is unchanged, still Godot Physics 2D — Jolt is 3D-only and never applies here regardless), `docs/engine-reference/godot/breaking-changes.md` (all Jolt-related entries are 3D-only, none apply), `design/gdd/object-placement.md` Formulas section (already contains a 2026-08-04 `/design-review` `godot-specialist` finding making this exact no-physics-engine decision explicit at the GDD level) |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | None. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data — `footprint_size`/`repositionable` read via `get_definition()`), ADR-0002 (signal/direct-call convention — Object Placement consumes Input Abstraction's signals and exposes direct-call queries per that ADR's pattern) |
| **Enables** | Object Placement implementation stories; unblocks Tending Input (excludes taps on object footprints) and Diorama Rendering (polls `get_position()`/`is_held()` from its own `_process()`, per `architecture.md`'s existing "pure leaf consumer" pattern — no change needed there) |
| **Blocks** | All Object Placement implementation stories |
| **Ordering Note** | Should be Accepted after ADR-0001 and ADR-0002, since its Key Interfaces cite both directly. |

## Context

### Problem Statement
`object-placement.md` already fully specifies the *math* for placement
validity — a footprint hit-test, an ellipse in-bounds check, a pairwise
overlap check, and a drag-follow position formula — and a prior
`/design-review` round (2026-08-04, `godot-specialist` finding) already
settled that none of it uses `Area2D`/`CollisionShape2D` or any
physics-engine query: every check is computed directly from stored
`Vector2` positions and scalar radii. What no document has decided is the
concrete **GDScript module shape**: what owns the per-object state
(position, HELD flag, `grab_offset`) that these formulas operate on, and
how other systems query it. `architecture.md`'s API Boundaries section
already sketched `get_position(object_id) -> Vector2` and
`is_held(object_id) -> bool` as free-function-style queries, implying a
single owning system rather than callers holding per-object node
references directly — but never named what that system is.

### Constraints
- No `Area2D`/`CollisionShape2D`/physics engine — already locked by
  `object-placement.md`'s own Formulas section (see References Consulted).
- `object-placement.md`'s pairwise `no_overlap` check compares a pending
  position against **every other currently-placed object** — whatever owns
  this needs cheap access to every object's current state at once.
- Must consume Input Abstraction's `tap`/`drag_start`/`drag_move`/
  `drag_end` signals (ADR-0002's notification pattern) and query Content
  Data's `footprint_size`/`repositionable` fields via `get_definition()`
  (ADR-0001's direct-call pattern).
- Must expose `get_position(object_id) -> Vector2` (live position while
  HELD, committed position otherwise — `architecture.md` Module Ownership:
  "Live/committed position for rendering") and `is_held(object_id) ->
  bool`, matching `architecture.md`'s already-sketched API Boundaries
  exactly — no rework needed there.
- Diorama Rendering already reads Object Placement as a poll-based leaf
  consumer from its own `_process()` (`architecture.md` Module Ownership:
  "No public API — pure leaf consumers... only read the interfaces above")
  — this ADR must not require Object Placement to push anything to it.

### Requirements
- Must support an MVP content volume of a small, fixed number of
  repositionable objects (per `content-data.md`'s `ObjectTypeDef`
  category — currently one example fixture, "rock").
- Must reject/accept a pending drop in one pass using `in_bounds AND
  no_overlap` (object-placement.md's Commit rule).
- Must preserve `grab_offset` for the duration of a drag (Drag-follow
  position formula).
- Must be unit-testable per `coding-standards.md` (dependency injection
  over singletons) — the validity formulas (`in_bounds`, `no_overlap`,
  footprint hit-test) must be callable with injected positions/radii, not
  only through the live autoload.

## Decision

**Object Placement is a single autoload holding a `Dictionary` registry**
(`String` object_id → `ObjectState`), keyed by `object_id` (never by node
reference or file path — consistent with ADR-0001's Content Data
convention of keying by `id`). `ObjectState` is a standalone `RefCounted`
subclass with `class_name`, in its own file (`object_state.gd`) — not
Content Data's `Resource` pattern (ADR-0001): this is private,
per-frame-mutated runtime state, not designer-authored data, and
`Resource`'s CoW/duplicate/serialization semantics are the wrong fit for
it. Holds `position: Vector2`, `held: bool`, `grab_offset: Vector2`.
(`godot-specialist` review, 2026-08-10: the initial draft left this shape
ambiguous between a nested inner class and a typed `Dictionary[String,
ObjectState]` generic — the latter's support for a custom class as the
value type isn't confirmed against this project's engine-reference docs
and has had parser rough edges historically; settled on plain untyped
`Dictionary` holding `RefCounted` values, which is unambiguous.)

The four validity formulas (`footprint_hit`, `in_bounds`, `no_overlap`,
drag-follow) live in a **separate, non-autoload script**,
`object_placement_math.gd` (`class_name ObjectPlacementMath`), as `static
func`s — not inside the autoload script itself. This keeps
`coding-standards.md`'s dependency-injection requirement clean: unit tests
call `ObjectPlacementMath.in_bounds(...)` directly with injected values,
never loading the autoload script (which also carries live registry state
and Input Abstraction signal-connect code) just to reach the math.

Object Placement has **zero scene-tree nodes of its own** — no visuals,
no `Area2D`, no physics bodies. It is pure data (the registry) plus calls
into `ObjectPlacementMath`.

At startup (after `ContentData` has loaded, per ADR-0002's init order),
Object Placement populates its registry from Content Data's
`ObjectTypeDef` entries (or from a restored Persistence/Save blob, once
that ADR exists) — `repositionable` and `footprint_size` are read once per
object via `ContentData.get_definition(type_id)` and cached alongside the
object's live state, rather than re-queried every formula evaluation.

Object Placement connects directly to Input Abstraction's signals
(ADR-0002's notification pattern):
- `tap(position, device_id)` → footprint hit-test against every
  `repositionable` object; on a hit, plays the wobble acknowledgment path
  (no state change — Diorama Rendering picks this up by polling, no
  signal needed, matching its existing leaf-consumer pattern).
- `drag_start(position, device_id)` → footprint hit-test; on a hit against
  a `repositionable` object, records `grab_offset`, sets `held = true`,
  transitions that object's state to HELD.
- `drag_move(position, delta, device_id)` → recomputes `visual_pos =
  pointer_pos - grab_offset` for the currently-HELD object only (Drag-
  follow position formula).
- `drag_end(position, canceled, device_id)` → if `canceled`, revert to
  last committed position (snap-back). Otherwise evaluate `valid =
  in_bounds AND no_overlap` against the pending position and every other
  object's current position; commit on `valid`, snap-back otherwise.
  Either path sets `held = false`.

The pairwise `no_overlap` check iterates the registry's other entries
directly — a single `Dictionary` in one autoload makes this a straight
loop, with no cross-node reference-passing needed.

### `is_within_any_footprint()` — Tending Input's exclusion query (companion edit, ADR-0011, 2026-08-11)

`ObjectPlacement` gains one new public query method, plus one new field on
`ObjectState`:

```gdscript
func is_within_any_footprint(point: Vector2) -> bool
```

Iterates `_objects` internally, calling
`ObjectPlacementMath.footprint_hit(point, obj.position, obj.footprint_size)`
per entry, returning `true` on the first hit. `ObjectState` gains
`footprint_size: float`, cached once at registry population (same
lifecycle as `position`/`held`/`grab_offset`) from `ContentData
.get_definition(type_id).footprint_size` — the same read this ADR's
Decision already performs for `repositionable`, just also retaining the
value instead of only branching on it. This exists so Tending Input
(ADR-0011) can perform its footprint-exclusion check without a second
read path into Content Data or an enumerable object list — `footprint_size`
and the registry stay entirely private to Object Placement, which already
owns and caches them.

### `restore()` — SessionBootstrap's population entry point (companion edit, ADR-0002 revision, 2026-08-10)

`ObjectPlacement` gains one new public method, called exactly once, only
by `SessionBootstrap`, at Data Flow §3 step 4 — strictly before Input
Abstraction's signals are live, since no gesture can be processed until
the scene tree finishes entering, which happens after every autoload's
`_ready()` (including `SessionBootstrap`'s) completes:

```gdscript
func restore(restored_blob: Dictionary) -> void
```

Populates `_objects` from `restored_blob`'s per-object positions when
`restored_blob` is non-empty (a validated save existed), or from Content
Data's `ObjectTypeDef` defaults otherwise — the exact mechanism this ADR's
Decision already anticipated in prose ("or from a restored Persistence/Save
blob, once that ADR exists") but never named as a callable. This closes
the gap `docs/consistency-failures.md`'s TR-crosscutting-003 flagged
against ADR-0002's pseudocode.

**This does not contradict "No public write API" in Key Interfaces below.**
That guarantee is about *ongoing runtime* mutation — the only thing that
can move a placed object's committed position after session start is a
drag committed through Input Abstraction's signals. `restore()` is a
one-time bootstrap population call with no runtime counterpart: it always
runs before any signal has fired, is never called again afterward, and
never overlaps in time with the gesture-driven write path it's being
distinguished from. The Key Interfaces comment is updated to say so
explicitly, rather than leaving the two statements to silently contradict
each other.

### Architecture Diagram
```
InputAbstraction (signals) ──> ObjectPlacement (autoload)
                                  │
                                  ├─ Dictionary: object_id -> ObjectState
                                  │    (RefCounted: position, held, grab_offset)
                                  │
                                  ├─ calls ObjectPlacementMath.* (separate script,
                                  │  static funcs, unit-testable without the autoload)
                                  │
                                  ├─ reads footprint_size/repositionable
                                  │  via ContentData.get_definition(type_id)  (ADR-0001)
                                  │
                                  └─ exposes:
                                       get_position(object_id) -> Vector2
                                       is_held(object_id) -> bool
                                       is_within_any_footprint(point) -> bool   # ADR-0011 companion edit

DioramaRendering._process() ──poll──> ObjectPlacement.get_position()/is_held()
                                       (existing leaf-consumer pattern, unchanged)
TendingInput ──query (footprint exclusion)──> ObjectPlacement.is_within_any_footprint()
                                       (ADR-0011 companion edit)
```

### Key Interfaces
```gdscript
# Object Placement (autoload) — Core
func get_position(object_id: String) -> Vector2
# Live position while HELD (drag-follow), committed position otherwise.
func is_held(object_id: String) -> bool
func is_within_any_footprint(point: Vector2) -> bool
# NEW — companion edit, ADR-0011 (2026-08-11). Iterates _objects internally,
# calling ObjectPlacementMath.footprint_hit() per entry. Keeps footprint_size
# and the registry private to this system; Tending Input never reads
# Content Data or enumerates objects directly.
func restore(restored_blob: Dictionary) -> void
# NEW — companion edit, ADR-0002 revision (2026-08-10). Called ONLY by
# SessionBootstrap, step 4, before any gesture has been processed. See
# Decision above for the full contract.
# No public RUNTIME write API beyond restore() — every post-session-start
# position change is still driven entirely by Input Abstraction's signals
# (ADR-0002); restore() is one-time bootstrap population, not a runtime
# write path, and the two never overlap in time.

# Internal (not public API, but the shape the above reads from):
# var _objects: Dictionary  # String (object_id) -> ObjectState

# ObjectState (object_state.gd) — RefCounted, not Resource (private
# runtime state, not designer-authored data — see Decision)
class_name ObjectState
extends RefCounted
var position: Vector2
var held: bool = false
var grab_offset: Vector2
var footprint_size: float
# NEW — companion edit, ADR-0011 (2026-08-11). Cached once at registry
# population from ContentData.get_definition(type_id).footprint_size,
# same lifecycle as the fields above.

# ObjectPlacementMath (object_placement_math.gd) — separate script, not
# inside the autoload, so unit tests never load registry/signal code to
# reach these. Pure functions, take injected values per coding-standards.md.
class_name ObjectPlacementMath
extends RefCounted

static func footprint_hit(point: Vector2, obj_pos: Vector2, fp: float) -> bool:
    return point.distance_to(obj_pos) <= fp  # inclusive, per object-placement.md

static func in_bounds(p: Vector2, c: Vector2, r: Vector2, fp: float) -> bool:
    # ((px-cx)/(rx-fp))^2 + ((py-cy)/(ry-fp))^2 <= 1
    # Precondition: fp < min(r.x, r.y) — reject outright (return false)
    # outside this domain, per object-placement.md's explicit domain note.
    ...

static func no_overlap(pa: Vector2, fp_a: float, pb: Vector2, fp_b: float, leniency: float) -> bool:
    return pa.distance_to(pb) >= (fp_a + fp_b) * leniency
```

## Alternatives Considered

### Alternative 1: Per-object Node2D scripts
- **Description**: Each placed object is its own scene-tree node running
  its own script, independently handling input hit-testing and validity.
- **Pros**: Feels more conventionally "Godot" for visual, positionable
  objects; each object's script is self-contained.
- **Cons**: The pairwise `no_overlap` check needs every object to see
  every other object's current position — with per-node scripts this
  means either a shared group lookup (`get_tree().get_nodes_in_group(...)`)
  every validity check or each node holding sibling references, both
  messier than one `Dictionary` in one place. Also doesn't produce the
  single `get_position(object_id)`/`is_held(object_id)` query API
  `architecture.md` already assumed — callers would need node references
  instead of an id-based lookup.
- **Rejection Reason**: More coordination code for the same result. The
  autoload+registry shape gives the pairwise check and the id-based query
  API for free; per-node scripts would have to build both.

### Alternative 2: Hybrid — autoload for math, separate visual nodes
- **Description**: Object Placement autoload owns validity/position
  logic; a parallel set of visual `Node2D` instances render it.
- **Pros**: Explicit separation of logic and rendering.
- **Cons**: Functionally identical to the Decision above once you account
  for the fact that Diorama Rendering already is that separate
  poll-based visual layer (`architecture.md`'s existing "pure leaf
  consumer" pattern) — this alternative just restates the Decision with
  extra words, or risks Object Placement growing scene-tree
  responsibilities it doesn't need.
- **Rejection Reason**: No actual difference from the chosen Decision;
  not a real alternative once Diorama Rendering's existing role is
  accounted for.

## Consequences

### Positive
- One place (`_objects: Dictionary`) to read for the pairwise
  `no_overlap` check, matching how `object-placement.md`'s own formula is
  already written ("checked against every other currently-placed
  object").
- Matches `architecture.md`'s already-sketched `get_position(object_id)`/
  `is_held(object_id)` API exactly — zero rework there.
- The four formulas (`footprint_hit`, `in_bounds`, `no_overlap`,
  drag-follow) are pure/static and injectable, satisfying
  `coding-standards.md`'s unit-testability requirement directly.
- No new scene-tree nodes, no physics engine, no `Area2D` — matches the
  GDD's own prior explicit ruling.

### Negative
- Object Placement has no visual representation of its own — a developer
  reading only this system would need to also read Diorama Rendering to
  see anything on screen. Acceptable: this split (logic autoload +
  poll-based visual leaf) already exists project-wide (Ecosystem
  Simulation/Diorama Rendering follow the same pattern).
- Adding a genuinely different object *shape* in the future (non-circular
  footprint) would require revisiting `footprint_hit`/`in_bounds`, both of
  which assume a circular radius — not a cost at MVP scope (every
  `ObjectTypeDef` uses `footprint_size` as a radius, per `content-data.md`).

### Risks
- **Risk**: `in_bounds`'s domain precondition (`fp < min(rx, ry)`) being
  silently violated if a future `content-data.md` change raises
  `FOOTPRINT_MAX` above the jar ellipse's `min(rx, ry)`.
  **Mitigation**: Already tracked as an explicit invariant in
  `content-data.md`'s Open Questions (`FOOTPRINT_MAX < min(rx, ry)`); this
  ADR's `in_bounds` implementation must return `false` outright outside
  the domain (per `object-placement.md`'s explicit ruling), never compute
  a misleading value.
- **Risk**: The off-axis `in_bounds` approximation (documented in
  `object-placement.md` as accepted, ≈0.85 jar-space-unit worst-case
  overshoot at `fp=FOOTPRINT_MAX=20`) carries forward unchanged into this
  implementation.
  **Mitigation**: None needed — already an accepted, not-fixed GDD-level
  decision (Anti-Pillar reasoning against a more punishing exact check);
  this ADR implements the formula as specified, not a corrected version.

**`godot-specialist` review (2026-08-10)**: core Decision confirmed
idiomatic for Godot 4.7.1, no blocking issues. Three shape refinements
made to the draft: the four validity formulas moved out of the autoload
into a standalone `ObjectPlacementMath` script (cleaner test isolation);
`ObjectState` settled as a `RefCounted` subclass rather than a nested
inner class or an unverified typed-Dictionary-with-custom-class-value
generic; registry typing left as plain `Dictionary` rather than asserting
`Dictionary[String, ObjectState]` syntax this project's engine-reference
docs don't confirm support for.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| object-placement.md | Formulas: footprint hit-test, in-bounds ellipse, pairwise overlap, drag-follow position | Implemented as pure/static functions per Key Interfaces, operating on the autoload's `Dictionary[String, ObjectState]` registry. |
| object-placement.md | "No `Area2D`/`CollisionShape2D`/physics engine" (2026-08-04 `/design-review` finding) | Confirmed and carried forward unchanged — this ADR's entire Decision is physics-free. |
| object-placement.md | Core Rule: `grab_offset` preserved for the duration of a drag | `ObjectState.grab_offset`, set at `drag_start`, read on every `drag_move`, cleared implicitly on `drag_end`. |
| content-data.md | `ObjectTypeDef.footprint_size`/`repositionable` fields | Read once per object at registry population via `ContentData.get_definition()` (ADR-0001), cached alongside live state. |
| architecture.md | `get_position(object_id) -> Vector2`, `is_held(object_id) -> bool` API Boundaries | Adopted unchanged — this ADR confirms the shape rather than requiring a rework. |
| diorama-rendering.md | Reads "committed/live `visual_pos`, HELD state, `drag_end` outcome" via its own `_process()` | No change needed — Object Placement's `get_position()` already returns live-while-HELD/committed-otherwise, satisfying this without a new signal. |
| tending-input.md | Footprint exclusion (taps on object footprints don't trigger watering) | `is_within_any_footprint()` companion edit (ADR-0011, 2026-08-11) — see Decision above. |

## Performance Implications
- **CPU**: `no_overlap` is O(n) per validity check against a small, fixed
  object count (MVP: a handful of `ObjectTypeDef` instances) — negligible.
  `drag_move` recomputes one `Vector2` subtraction per frame for the
  single HELD object.
- **Memory**: One small `Dictionary` entry per placed object — trivial.
- **Load Time**: Registry population is a single pass over Content Data's
  already-loaded `ObjectTypeDef` entries at session start (ADR-0002's
  `SessionBootstrap` sequence, step 4).
- **Network**: N/A.

## Migration Plan
N/A — no existing Object Placement implementation to migrate from.

## Validation Criteria
- Unit tests call `ObjectPlacementMath.footprint_hit`/`in_bounds`/
  `no_overlap`/the drag-follow formula directly with injected values (no
  autoload load required), reproducing
  `object-placement.md`'s own worked examples (rock at `(60,20)`, `fp=8`,
  jar `(cx,cy,rx,ry)=(0,0,100,60)` → `in_bounds ≈ 0.573` valid; second
  object overlap example) and its documented edge cases (domain
  precondition violation, boundary-inclusive hit-test).
- An integration test drives a fake `tap`/`drag_start`/`drag_move`/
  `drag_end` sequence through the autoload and confirms `get_position()`/
  `is_held()` report the expected values at each step, including the
  `canceled == true` snap-back path.

## Related Decisions
- `docs/architecture/adr-0001-content-data-format.md` — `get_definition()`
  is how Object Placement reads `footprint_size`/`repositionable`.
- `docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md`
  — establishes the direct-call/signal convention this ADR's Key
  Interfaces follow, and the `SessionBootstrap` init sequence Object
  Placement's registry population slots into (step 4). **Companion-edited
  by that ADR's 2026-08-10 revision** to add `restore()` — see this
  document's Decision section, "restore() — SessionBootstrap's population
  entry point."
- `docs/architecture/architecture.md` — API Boundaries (Object Placement's
  `get_position()`/`is_held()`, adopted unchanged) and Module Ownership
  (Diorama Rendering's existing poll-based leaf-consumer pattern).
- `docs/architecture/adr-0011-tending-input-watering-router.md` —
  companion-edits this ADR to add `is_within_any_footprint()` and
  `ObjectState.footprint_size` (2026-08-11).
