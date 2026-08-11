# ADR-0010: Discovery Surfacing — Delta Computation & Reveal-Queue Architecture

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (pure state/timing logic — no rendering, no physics; the one Web-export touchpoint is `Window.focus_exited`/`focus_entered`, already covered by ADR-0006/ADR-0008) |
| **Knowledge Risk** | LOW for this ADR's own new surface (`Dictionary`/`Array`/`Tween`-free timing math is all stable pre-cutoff) — the one HIGH-risk dependency (focus-signal reliability) is inherited, not re-opened, from ADR-0008's Gate A2 evidence. |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `deprecated-apis.md` (no entries touching `Array`/`Dictionary`/plain timing arithmetic); `docs/architecture/adr-0006-time-drift-session-lifecycle.md` and `adr-0008-input-gesture-abstraction-web-touch-focus.md` (both already establish and use `get_window().focus_exited`/`focus_entered`) |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | None new — this ADR's only empirical dependency is Gate A2 (`Window.focus_exited`/`focus_entered` timing), already PASS on desktop Chrome per ADR-0008; cross-browser confirmation remains that ADR's open item, not a new one here. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (`SessionBootstrap` fixes this system's two call points: `capture_pre_batch_snapshot()` at step 5, `compute_delta()` at step 9); ADR-0004 (companion-edited alongside this ADR to expose `get_was_present_during_batch()`, `get_detail_event_fired()`, `get_plant_ids()`, `get_creature_ids()` — see that ADR's Decision); ADR-0003 (reuses the registered `testable_pure_formula_placement` pattern) |
| **Enables** | Resolves ADR-0009's (Diorama Rendering) provisional `get_active_items()` interface assumption with a ratified signature. |
| **Blocks** | Diorama Rendering's Discovery-cue rendering stories (already stated as gated by `diorama-rendering.md`'s own Core Rule 7). |
| **Ordering Note** | Should be Accepted after ADR-0002, ADR-0003, and ADR-0004 (companion-edited version). ADR-0009 should be revisited once this ADR is Accepted to replace its provisional assumption with this ADR's ratified `get_active_items()` signature. |

## Context

### Problem Statement

`design/gdd/discovery-surfacing.md` fully specifies the delta-computation
rules, queue ordering, and staggered-reveal timing (9 Core Rules, 1
Formulas section) but leaves three implementation questions open: what data
structure represents one discovery item, how the queue's focused-elapsed
timer is driven (Core Rule 4a's pause-on-background requirement), and
where the per-plant/creature enumeration and registration-order tie-break
(Core Rule 8) actually come from — which, on inspection, no existing ADR
yet exposes. `SessionBootstrap` (ADR-0002) already fixes *when* this
system's two entry points fire; this ADR fixes *how* they're implemented.

### Constraints
- Fully transient — no session-boundary persistence (GDD Dependencies:
  explicitly no relationship with Persistence/Save).
- Must never block gameplay input (Core Rule 9) — this system only ever
  produces read-only query state, never gates another system's calls.
- No central event-bus/mediator autoload (registry `forbidden_patterns:
  event_bus_mediator`).
- `pacing_delay`/`cue_fade_duration` must be data-driven, not hardcoded
  (GDD Tuning Knobs, `coding-standards.md`).

### Requirements
- Compute a deterministic delta set exactly once per session, at the
  `CATCHING_UP`→`ACTIVE` transition (Core Rule 1).
- Queue items visible independently per-item based on `activation_time(i)`/
  `fade_end_time(i)` (Core Rule 4, deliberate overlap).
- The queue's elapsed-time clock must pause while the tab is backgrounded
  and resume from exactly where it paused (Core Rule 4a).

## Decision

A single autoload, **`DiscoverySurfacing`** (Feature layer — an autoload
singleton is necessarily a `Node` in the tree, since `_ready()`/`_process()`
require it; "no scene-tree nodes" elsewhere in this document means no
*child* nodes/visuals of its own, same convention ADR-0003 uses for Object
Placement, not that this script itself isn't a `Node`), holds `_queue: Array[DiscoveryItem]`, `_state: State` (`{IDLE,
REVEALING}`), and `_focused_elapsed: float`. It follows the same
leaf-consumer/pure-formula pattern already established by Time & Drift and
Ecosystem Simulation.

1. **Two entry points, exactly where `SessionBootstrap` already calls
   them** (ADR-0002, unchanged): `capture_pre_batch_snapshot()` (step 5)
   deep-copies each plant's `growth_stage` and each creature's
   `CreatureState.Presence` via `EcosystemSimulation.get_plant_ids()`/
   `get_creature_ids()` (companion-edited into ADR-0004 alongside this
   ADR) and their per-id getters — a plain `Dictionary` snapshot, primitives
   only, matching ADR-0002's own "deep-copy snapshot of primitives, not a
   replay log" description. `compute_delta()` (step 9, after Time & Drift's
   catch-up and Creature Behavior's settle) re-reads the same getters,
   diffs against the snapshot, and builds `_queue`.
2. **`DiscoveryItem` is a `RefCounted`** (matches `PlantState`/
   `CreatureState`/`ObjectState`'s established shape, registry
   `small_shared_state_module_shape`), not a `Resource` — private runtime
   data, never serialized.
3. **Registration-order tie-break (Core Rule 8) uses `get_plant_ids()`/
   `get_creature_ids()`'s array index directly** as the registration index
   — the same companion-edited getters that solve enumeration also solve
   ordering, since both need "the same deterministic order" and `Array`
   index trivially provides it. No separate index-lookup mechanism.
4. **Queue ordering and timing are pure functions** in a new
   `DiscoverySurfacingMath` script (non-autoload, reuses the registered
   `testable_pure_formula_placement` convention) — `activation_time(i)`,
   `fade_end_time(i)`, `total_reveal_duration(n)`, and the category-tier +
   registration-index comparator used to sort `_queue` once at
   `compute_delta()` time.
5. **Focus-pause timing connects directly to `Window.focus_exited`/
   `focus_entered` in `DiscoverySurfacing._ready()`**, independent of Input
   Abstraction — Godot signals support multiple independent listeners, and
   this system's need (pause a queue timer) is unrelated to Input
   Abstraction's pointer state machine. Reuses the same signal ADR-0008's
   Gate A2 already found reliable on desktop Chrome, as a second,
   independent connection to it — no new engine risk, no cross-ADR
   coupling. On `focus_exited`, `_paused = true`; on `focus_entered`,
   `_paused = false`. `_process(delta)` only advances `_focused_elapsed`
   when `_state == REVEALING and not _paused`.
6. **No stale-timer watchdog** (unlike Input Abstraction's, ADR-0008 §6).
   The failure mode if `focus_exited` never fires on some browser is a
   missed pacing pause — the queue keeps advancing while backgrounded, at
   worst finishing unseen — not a stuck/unrecoverable state. That's a
   lower-severity UX-quality risk than Input Abstraction's stuck pointer,
   and doesn't warrant the same defensive machinery (YAGNI).

### Architecture Diagram
```
SessionBootstrap step 5 ──capture_pre_batch_snapshot()──> DiscoverySurfacing
  (reads EcosystemSimulation.get_plant_ids()/get_creature_ids() + per-id getters,
   stores a Dictionary snapshot of primitives)

SessionBootstrap step 9 ──compute_delta()──> DiscoverySurfacing
  (re-reads the same getters + get_was_present_during_batch()/get_detail_event_fired(),
   diffs against the snapshot, builds Array[DiscoveryItem] via DiscoverySurfacingMath's
   comparator, sets _state = REVEALING (or IDLE if empty), _focused_elapsed = 0.0)

Window.focus_exited/focus_entered ──> DiscoverySurfacing._paused = true/false
  (independent connection, same verified signal ADR-0008 also uses — no coupling)

DiscoverySurfacing._process(delta):
  if _state == REVEALING and not _paused: _focused_elapsed += delta
  if _focused_elapsed >= DiscoverySurfacingMath.total_reveal_duration(_queue.size()):
      _state = IDLE

DioramaRendering (per-entity scripts, ADR-0009) ──poll get_active_items()──> DiscoverySurfacing
  (leaf-consumer pattern, resolves ADR-0009's provisional assumption)
```

### Key Interfaces
```gdscript
# DiscoverySurfacing (autoload) — Feature. extends Node (every autoload is,
# required for _ready()/_process() to fire) — no CHILD nodes/visuals of its own.
func capture_pre_batch_snapshot() -> void   # SessionBootstrap step 5
func compute_delta() -> void                # SessionBootstrap step 9
func get_active_items() -> Array[DiscoveryItem]
# Ratifies ADR-0009's provisional assumption — same purpose, concrete shape below.

# DiscoveryItem (discovery_item.gd) — RefCounted
class_name DiscoveryItem
extends RefCounted
enum Category { GROWTH, DEPARTURE, DETAIL_EVENT, ARRIVAL }
var category: Category
var target_id: String        # plant_id or creature_id
var from_stage: int = -1     # Growth only; -1 = not applicable
var to_stage: int = -1       # Growth only
var position: Vector2        # Departure only (last_known_position); unused otherwise
var full_cycle: bool = false # Departure only (Core Rule 2a)

# DiscoverySurfacingMath (discovery_surfacing_math.gd) — separate script, static, pure
static func activation_time(i: int, pacing_delay: float) -> float:
    return i * pacing_delay
static func fade_end_time(i: int, pacing_delay: float, cue_fade_duration: float) -> float:
    return activation_time(i, pacing_delay) + cue_fade_duration
static func total_reveal_duration(n: int, pacing_delay: float, cue_fade_duration: float) -> float:
    return (n - 1) * pacing_delay + cue_fade_duration if n > 0 else 0.0
static func tier(category: DiscoveryItem.Category) -> int:
    # Growth=0, Departure=1, Detail Event=2, Arrival=3 (Core Rule 8 order)
    match category:
        DiscoveryItem.Category.GROWTH: return 0
        DiscoveryItem.Category.DEPARTURE: return 1
        DiscoveryItem.Category.DETAIL_EVENT: return 2
        DiscoveryItem.Category.ARRIVAL: return 3
        _: return -1   # unknown category sentinel
# Sort comparator: (tier(item.category), registration_index[item.target_id]) ascending —
# registration_index supplied by the caller (compute_delta(), from get_plant_ids()/
# get_creature_ids() array position), not looked up internally — keeps this script
# free of any EcosystemSimulation dependency, matching the pure/static convention.
```

## Alternatives Considered

### Alternative 1: Route focus-pause through Input Abstraction
- **Description**: Input Abstraction re-emits its own `focus_lost`/
  `focus_gained` signals; Discovery Surfacing subscribes to those instead
  of connecting to `Window` directly.
- **Pros**: One declared "focus source" system.
- **Cons**: Couples an unrelated concern (pausing a reveal-queue timer) to
  Input Abstraction's pointer state machine, for no benefit — Godot signals
  already support multiple independent listeners natively.
- **Rejection Reason**: Adds an indirection layer and a cross-ADR
  dependency neither system needs; the `Window` signal is not owned by
  Input Abstraction, it's global engine state either system can observe.

### Alternative 2: Two-state QUEUED↔REVEALING ping-pong (per-item sequencing)
- **Description**: An earlier version of the GDD itself considered this —
  next item only activates once the previous one's fade completes.
- **Pros**: Simpler state machine, no overlap to reason about.
- **Cons**: Contradicts the GDD's own locked Formulas (`pacing_delay <
  cue_fade_duration` deliberately produces overlap) and States/Transitions
  correction (already fixed in the GDD itself, per its own trailing
  review note).
- **Rejection Reason**: Already resolved by the GDD, not a live
  architectural choice — restated here only because `get_active_items()`'s
  correctness depends on computing each item's visibility independently
  from `activation_time(i)`/`fade_end_time(i)`, not from a shared queue
  cursor, which is what makes overlap possible at all.

## Consequences

### Positive
- `get_plant_ids()`/`get_creature_ids()` close a gap that also affected
  `capture_pre_batch_snapshot()`'s own implementability (ADR-0002 named the
  method but never specified how it enumerates plants/creatures) — this
  ADR's companion edit to ADR-0004 fixes both call sites, not just this one.
- No new engine-verification risk — the one Web-export touchpoint reuses
  already-established, already-tested ground (ADR-0008's Gate A2).
- `DiscoveryItem`/`DiscoverySurfacingMath` follow this project's own
  established conventions exactly (RefCounted registry pattern, pure
  formula script) — no new architectural pattern introduced.

### Negative
- `DiscoverySurfacingMath`'s comparator takes `registration_index` as a
  caller-supplied parameter rather than looking it up itself — slightly
  more plumbing at the `compute_delta()` call site (building an id→index
  map from the two array getters) in exchange for keeping the formula
  script fully pure/dependency-free.

### Risks
- **Cross-browser focus-signal reliability remains ADR-0008's open risk,
  inherited here, not independently re-verified.** If Gate A2 fails on a
  browser Input Abstraction hasn't tested yet, this system's Core Rule 4a
  pause also silently stops working on that browser — same failure
  surface, no new one. No watchdog added here (see Decision §6) since the
  consequence is lower-severity than a stuck pointer.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `discovery-surfacing.md` | Core Rule 1 (delta set computed once, at transition) | `capture_pre_batch_snapshot()`/`compute_delta()` at `SessionBootstrap`'s already-fixed steps 5/9. |
| `discovery-surfacing.md` | Core Rule 2a (`full_cycle` exception) | `get_was_present_during_batch()` (companion-edited into ADR-0004) drives the check directly. |
| `discovery-surfacing.md` | Core Rule 4/4a (staggered, overlapping, pause-on-background reveal) | `DiscoverySurfacingMath`'s independent per-item visibility formulas + direct `Window.focus_exited`/`focus_entered` connection. |
| `discovery-surfacing.md` | Core Rule 7 (Departure position source) | `DiscoveryItem.position` populated from `get_last_known_position()` at `compute_delta()` time, per that already-registered interface. |
| `discovery-surfacing.md` | Core Rule 8 (deterministic queue ordering) | `DiscoverySurfacingMath.tier()` + caller-supplied `registration_index` from the companion-edited `get_plant_ids()`/`get_creature_ids()`. |
| `diorama-rendering.md` (via ADR-0009) | Provisional `get_active_items()` assumption | Ratified here with a concrete `DiscoveryItem` shape — ADR-0009 should be revisited to drop its "provisional" qualifier once this ADR is Accepted. |

## Performance Implications
- **CPU**: `compute_delta()` is O(plants + creatures), once per session.
  `get_active_items()` is O(queue depth, ≤8), called every frame by Diorama
  Rendering's polling entities — negligible.
- **Memory**: One snapshot `Dictionary` (freed after `compute_delta()`
  consumes it) plus `_queue` (≤8 `DiscoveryItem` `RefCounted` objects).
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan
N/A — new system, no existing implementation.

## Validation Criteria
- Unit tests: `DiscoverySurfacingMath`'s pure functions against the GDD's
  Formulas ACs (20–23) directly, no autoload needed.
- Integration tests: `compute_delta()` against a constructed
  `EcosystemSimulation` state for Core Rule 1/2/2a/8 ACs (1–8b, 15–18).
- The focus-pause behavior (AC10a/10b) is simulated-signal-testable today,
  same gate-ability caveat ADR-0008 already established for its own
  interruption ACs — not production-verified until Gate A2 (or an
  equivalent) is confirmed cross-browser.

## Related Decisions
- `docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md`
  — fixes this system's two `SessionBootstrap` call points.
- `docs/architecture/adr-0004-ecosystem-simulation-tick-architecture.md`
  — companion-edited alongside this ADR for the four getters this system
  needs.
- `docs/architecture/adr-0006-time-drift-session-lifecycle.md` /
  `adr-0008-input-gesture-abstraction-web-touch-focus.md` — establish and
  verify the `Window.focus_exited`/`focus_entered` signal this ADR reuses.
- `docs/architecture/adr-0009-diorama-rendering-light2d-web-strategy.md` —
  consumer of `get_active_items()`; its provisional assumption should be
  reconciled against this ADR's ratified shape.
- `design/gdd/discovery-surfacing.md` — full behavioral specification this
  ADR implements.
