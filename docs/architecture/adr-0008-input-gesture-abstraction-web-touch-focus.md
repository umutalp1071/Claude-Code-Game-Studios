# ADR-0008: Input Gesture Abstraction & Web Export Touch/Focus Handling Strategy

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Input |
| **Knowledge Risk** | HIGH — post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/input.md`, `modules/ui.md` |
| **Post-Cutoff APIs Used** | `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD` constants (4.7 — device ID numbering scheme changed; comparing against literal `0` is now wrong) |
| **Verification Required** | A1 (does a real touch also synthesize `InputEventMouseMotion`), A3 (does OS-level touch-cancellation with no focus change deliver anything to Godot), A4 (does `InputEventScreenDrag` keep delivering past the canvas DOM edge) — all UNTESTED on any real browser per `docs/technical-setup/web-export-verification-plan.md` Gate A. Only A2 (`Window.focus_exited`/`focus_entered` timing) passed, and only on desktop Chrome. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (signal-vs-direct-call communication convention — this ADR's signals follow that pattern) |
| **Enables** | Formalizes the exact signal contract `docs/architecture/adr-0003-object-placement-collision-approach.md` already assumes (`tap`/`drag_start`/`drag_move`/`drag_end`); unblocks Object Placement and Tending Input implementation stories per `design/gdd/input-abstraction.md`'s own gate |
| **Blocks** | Object Placement and Tending Input implementation stories (already stated as blocked by the GDD itself, not newly introduced here) |
| **Ordering Note** | Should be Accepted after ADR-0002, since its Key Interfaces cite that ADR's signal/direct-call convention directly. |

## Context

### Problem Statement

`design/gdd/input-abstraction.md` fully specifies the gesture state machine
(tap-vs-drag classification, single-active-pointer arbitration, jar-local
coordinate conversion, pointer-interruption handling) but leaves the Godot
implementation strategy — entry point, internal state representation, how an
autoload gets a reference to a scene node it doesn't own, and what to do
about the GDD's own unresolved empirical Open Question — undecided. That
Open Question is the load-bearing complication: the GDD's Core Rules 1, 7,
and 8 exist specifically to defend against touch behaviors
(`docs/technical-setup/web-export-verification-plan.md` Gate A1/A3/A4) that
remain completely untested on any browser, including the required iOS
Safari target. `docs/architecture/adr-0003-object-placement-collision-approach.md`
is already Accepted and already consumes this system's signals as an assumed
contract — the implementation strategy needs locking in now, without
further blocking on hardware that isn't available yet.

### Constraints
- Web export only, Compatibility renderer (OpenGL ES3/WebGL2) — no
  Forward+-only features available.
- Mouse and touch must produce identical downstream behavior
  (`technical-preferences.md` platform requirement).
- No central event-bus/mediator autoload (registry `forbidden_patterns:
  event_bus_mediator`) — must use direct signal connections.
- `coding-standards.md`: dependency injection over singletons; static
  typing on all public methods.
- Gate A's touch-specific sub-questions (A1/A3/A4) are unresolved. This ADR
  proceeds without blocking on further hardware testing, on the explicit
  premise that every defensive mechanism it adds is a no-op if the
  underlying hypothesis it defends against turns out false.

### Requirements
- Convert `InputEventMouseButton`/`InputEventMouseMotion`/
  `InputEventScreenTouch`/`InputEventScreenDrag` into `tap`/`drag_start`/
  `drag_move`/`drag_end` signals matching the exact shape ADR-0003 already
  depends on.
- Must not leave a pointer stuck in PRESSED/DRAGGING with no recovery path,
  even in the specific failure mode Gate A3 could not rule out (an OS-level
  touch-cancel that produces zero engine-visible signal).
- Must correctly convert event position to jar-local space regardless of
  whether the jar node ever gains a non-identity scene transform (GDD Core
  Rule 4 explicitly anticipates this).

## Decision

A single autoload, **`InputAbstraction`** (Foundation layer, zero
scene-tree nodes of its own — matches the project's existing small-shared-
state-module shape, registry `api_decisions: small_shared_state_module_shape`),
implements the GDD's state machine exactly as specified, with these
implementation choices:

1. **Entry point**: `_unhandled_input(event: InputEvent) -> void`, filtered
   to the four raw event types. Chosen over `_input()` so that any future UI
   `Control` (HUD button, etc.) claims its own events first — `_input()`
   would let Input Abstraction see and act on a tap that a UI button already
   consumed, since the verification probe's `_input()` usage was in a scene
   with no competing UI to test against.

2. **Internal pointer identity is tagged, not a bare int.** The public
   signal contract's `device_id: int` field is unchanged (GDD Core Rule 4,
   already fixed by ADR-0003), but internal single-active-pointer
   arbitration tracks `(source: MOUSE|TOUCH, id: int)` rather than a bare
   `int`. **Engine specialist finding**: the 4.7 device-ID renumbering means
   mouse's `DEVICE_ID_MOUSE` value is no longer guaranteed distinct from a
   legitimate touch index (e.g. touch index `0`, a normal first-finger
   value) — storing both in one field risks a same-value collision between
   an active mouse pointer and an unrelated touch, which Core Rule 7's
   "different `device_id` is ignored" arbitration would then get wrong.
   Tagging the source removes the ambiguity entirely.

3. **Coordinate conversion uses the viewport's canvas transform, not raw
   `.position`.** `InputEventMouseButton`/`MouseMotion`/`ScreenTouch`/
   `ScreenDrag.position` are all viewport-local, not global — `Node2D.to_local()`
   expects global coordinates. **Engine specialist finding**: assuming
   viewport-local == global only holds while the jar has an identity
   transform, which Core Rule 4 explicitly says may not remain true. A single
   helper applies uniformly to every event type:
   ```gdscript
   func _to_jar_local(viewport_pos: Vector2) -> Vector2:
       var global_pos := get_viewport().canvas_transform.affine_inverse() * viewport_pos
       return _jar.to_local(global_pos)
   ```
   The `drag_active` threshold check (GDD Formulas) still compares raw,
   pre-conversion viewport-space positions, exactly as the GDD specifies —
   this helper is only applied at signal-emission time, never at threshold-
   evaluation time.

4. **Jar node reference via explicit registration, not lazy lookup.** The
   jar scene's root calls `InputAbstraction.register_jar(self)` from its own
   `_ready()` — which Godot guarantees runs after every autoload's `_ready()`
   has already completed. Chosen over a `%UniqueName` lookup so a missing
   registration fails loudly (null `_jar`, first gesture event errors) rather
   than silently resolving to whatever the name currently happens to match.

5. **Interruption detection**: `get_window().focus_exited` /
   `focus_entered`, connected once in `InputAbstraction._ready()` — the only
   mechanism Gate A actually verified (A2 PASS, desktop Chrome: fired before
   the hidden frame, not deferred to return). On `focus_exited`, force the
   active pointer to IDLE; if DRAGGING, fire `drag_end(position, true,
   device_id)` at the last known (viewport-clamped, per GDD Edge Cases)
   position first, per GDD Core Rule 8 / States and Transitions.

6. **Stale-pointer watchdog, added defensively.** A single restartable
   `Timer` (not `get_tree().create_timer()` — avoids a new `SceneTreeTimer`
   per event), `process_mode = PROCESS_MODE_ALWAYS`, `wait_time = 8.0`,
   restarted on every processed event for the active pointer. On timeout, it
   drives the identical transition `focus_exited` drives (IDLE, `drag_end`
   `canceled=true` if DRAGGING). This exists because Gate A3 (OS-level
   touch-cancel with no focus change) is not just untested but, per the
   engine specialist, a documented category of cross-browser inconsistency
   on iOS Safari specifically — not a hypothetical. Since no legitimate
   press-or-drag in this slow-paced game plausibly lasts 8 uninterrupted
   seconds, the watchdog is a no-op in the success case and a safety net in
   the untested failure case. It reuses Core Rule 8's existing transition —
   it does not introduce new observable behavior, only a second trigger
   path into behavior the GDD already fully specifies.

### Architecture Diagram
```
Raw input (mouse/touch)
   │
   ▼
InputAbstraction._unhandled_input()  (autoload, Foundation, no nodes)
   │  filters: MouseButton/MouseMotion/ScreenTouch/ScreenDrag
   ▼
Per-pointer state machine (IDLE/PRESSED/DRAGGING)
   keyed by (source: MOUSE|TOUCH, id: int) — not a bare int
   │
   ├─ drag_active = distance(press_pos, current_pos) > threshold[source]
   │    (evaluated pre-conversion, viewport-space — GDD Formulas)
   │
   ├─ position = _to_jar_local(event.position)   ← canvas_transform.affine_inverse()
   │    (post-conversion, jar-local — emitted on every signal)
   │
   └─ emits: tap / drag_start / drag_move / drag_end
                  │
                  ▼
        ObjectPlacement (ADR-0003) / TendingInput  — direct signal connections

Interruption sources (either forces active pointer → IDLE, drag_end(canceled=true) if DRAGGING):
  get_window().focus_exited        (verified: Gate A2, desktop Chrome)
  Timer timeout (8s, restarted per event)   (defensive — Gate A3 unverified)

Jar node wiring:
  JarScene._ready() ──register_jar(self)──> InputAbstraction._jar
  (runs after all autoloads' _ready(), per Godot's load-order guarantee)
```

### Key Interfaces
```gdscript
# InputAbstraction (autoload) — Foundation, no scene-tree nodes of its own
signal tap(position: Vector2, device_id: int)
signal drag_start(position: Vector2, device_id: int)
signal drag_move(position: Vector2, delta: Vector2, device_id: int)
signal drag_end(position: Vector2, canceled: bool, device_id: int)

func register_jar(jar_node: Node2D) -> void
# Called once by the jar scene's own _ready(). Required before any gesture
# event's position can be converted to jar-local space; a gesture firing
# before registration indicates a wiring bug, not a runtime case to guard.

# Internal (not public API):
enum PointerSource { NONE, MOUSE, TOUCH }
# var _active_source: PointerSource = PointerSource.NONE
# var _active_id: int = -1        # DEVICE_ID_MOUSE when MOUSE; touch index when TOUCH
# var _state: State = State.IDLE  # IDLE | PRESSED | DRAGGING
# var _press_pos: Vector2         # viewport-space, set at PRESSED entry
# var _jar: Node2D                # set via register_jar()
# var _watchdog: Timer            # one-shot, restarted per event, process_mode ALWAYS

func _to_jar_local(viewport_pos: Vector2) -> Vector2:
    var global_pos := get_viewport().canvas_transform.affine_inverse() * viewport_pos
    return _jar.to_local(global_pos)
```

## Alternatives Considered

### Alternative 1: `_input()` as the entry point
- **Description**: Capture every raw event unconditionally, as the
  verification probe (`InputProbe.tscn`) did.
- **Pros**: Matches the one thing that's actually been run in a browser;
  guaranteed to see every event regardless of UI state.
- **Cons**: Sees events a UI `Control` already claimed — a tap landing on a
  future HUD button over the jar canvas would also drive the gesture state
  machine underneath it.
- **Rejection Reason**: The verification probe had no competing UI to
  expose this; `_unhandled_input()` is the idiomatic Godot pattern for
  world/gameplay input specifically because it defers to UI first, and this
  project will have UI (Diorama Rendering's HUD elements).

### Alternative 2: Central event-bus/mediator autoload
- **Description**: Route gesture events through a shared dispatcher autoload
  instead of direct signal connections from `InputAbstraction` to each
  consumer.
- **Pros**: Would decouple producer/consumer wiring further.
- **Cons**: None that matter here.
- **Rejection Reason**: Explicitly forbidden — registry `forbidden_patterns:
  event_bus_mediator` (ADR-0002). Direct signal connections are the
  project's established pattern for exactly this producer/many-consumers
  shape.

### Alternative 3: Lazy `%UniqueName` lookup for the jar node reference
- **Description**: `InputAbstraction` resolves `%JarRoot` via
  `get_tree().current_scene` on first use instead of an explicit
  `register_jar()` call.
- **Pros**: No wiring code required in the jar scene.
- **Cons**: Couples this autoload to a naming convention rather than an
  explicit contract; a renamed or restructured jar scene fails silently
  (null reference resolved late) instead of loudly at the call site.
- **Rejection Reason**: `coding-standards.md` prefers dependency injection
  over singleton/implicit-lookup patterns; explicit registration surfaces a
  missing-wiring bug immediately rather than as a mysterious null downstream.

## Consequences

### Positive
- Single, testable source of truth for gesture translation — matches the
  GDD's own stated purpose (prevent mouse/touch parity drift).
- The watchdog and the tagged pointer identity close two real gaps the
  engine specialist identified before they became field bugs, at
  effectively zero cost when the underlying hypotheses hold.
- `register_jar()` and the `_to_jar_local()` helper make the coordinate
  conversion correct even before a camera/scene transform exists, so Core
  Rule 4's "only this conversion step needs updating" promise is actually
  true when that day comes.

### Negative
- `register_jar()` is one more piece of required scene wiring a future
  contributor must remember; forgetting it produces a null-reference error
  on the first gesture rather than a compile-time failure.
- The watchdog's 8-second timeout is a judgment call, not an empirically
  derived value — no real touch-cancellation data exists yet to tune it
  against.

### Risks
- **A1/A3/A4 remain unverified.** If A1 (touch→duplicate mouse event) turns
  out false, Core Rule 7's dedup is simply inert — no harm. If A3 (OS
  touch-cancel) fails entirely on some browser (no signal at all), the
  watchdog is the only recovery path, and its untested 8s timeout could
  either fire falsely on a legitimate long press or take up to 8s to recover
  a genuinely stuck pointer. **Mitigation**: revisit the timeout once Gate A
  is actually run on real touch hardware; nothing about this ADR prevents
  tightening it later.
- **iOS Safari touch-cancel/focus-blur inconsistency** (engine specialist
  finding, not previously documented in the GDD or verification plan): iOS
  Safari's native touch-cancel gestures do not reliably fire a window blur
  event, independent of whatever Gate A eventually finds for desktop
  browsers. This reinforces rather than changes the decision — it is direct
  evidence the watchdog is a necessary hedge, not a speculative one.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `input-abstraction.md` | Core Rule 1 / 7 (mouse-emulation dedup, single active pointer) | Tagged `(source, id)` internal state avoids the numeric collision risk the bare-int approach would have; arbitration logic matches the GDD's States and Transitions table exactly. |
| `input-abstraction.md` | Core Rule 4 (jar-local position conversion) | `register_jar()` DI pattern + `canvas_transform.affine_inverse()`-based `_to_jar_local()` helper, correct even under a future non-identity jar transform. |
| `input-abstraction.md` | Core Rule 8 (pointer interruption) | `Window.focus_exited`/`focus_entered` as the verified (Gate A2) primary trigger, plus the watchdog Timer as a second, defensive trigger into the identical transition. |
| `input-abstraction.md` | Open Questions (BLOCKING — empirical verification) | Explicitly not resolved by this ADR. This ADR proceeds without blocking, per user decision, on the premise that every defensive mechanism it adds is harmless if the hypothesis it guards against is false. Gate A1/A3/A4 must still be run on real touch hardware before Object Placement/Tending Input's `canceled` contract is considered field-verified — tracked in `web-export-verification-plan.md`, not closed here. |
| `object-placement.md` (via ADR-0003) | Already-assumed `tap`/`drag_start`/`drag_move`/`drag_end` signal contract | This ADR formalizes exactly the signal signatures ADR-0003 already consumes — no discrepancy found. |

## Performance Implications
- **CPU**: Negligible — event-driven, no per-frame polling. The watchdog
  `Timer` only ticks while a pointer is active (PRESSED/DRAGGING), which is
  a small fraction of session time in this slow-paced game.
- **Memory**: One autoload, one `Timer` node, no per-frame allocation. Using
  a persistent `Timer` instead of `get_tree().create_timer()` avoids
  `SceneTreeTimer` churn on every input event.
- **Load Time**: None — autoload initializes with no data to load.
- **Network**: N/A.

## Migration Plan
N/A — new system, no existing implementation to migrate from.

## Validation Criteria
- Unit tests against the GDD's Acceptance Criteria (1–19a) using simulated
  input events and a simulated `focus_exited`/watchdog-timeout signal — this
  is what the GDD's own AC10-family gate-ability note already scopes as
  achievable today.
- **Not closed by unit tests alone**: AC10/10a/10b/10c/10d/10e and this
  ADR's watchdog addition are not production-verified until Gate A1/A3/A4
  are actually run on real touch hardware (iOS Safari required per the
  verification plan's device matrix). Do not mark those criteria passing on
  simulated-signal evidence alone, per the GDD's own explicit caveat.

## Related Decisions
- `docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md` —
  signal/direct-call communication convention this ADR follows.
- `docs/architecture/adr-0003-object-placement-collision-approach.md` —
  already-Accepted consumer of this ADR's signal contract.
- `design/gdd/input-abstraction.md` — full behavioral specification this ADR
  implements.
- `docs/technical-setup/web-export-verification-plan.md` — Gate A, the
  still-open empirical verification this ADR proceeds without.
