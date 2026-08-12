# ADR-0009: Diorama Rendering — Light2D/Baked-Lighting Web Export Strategy

## Status
Proposed

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Rendering |
| **Knowledge Risk** | HIGH — post-LLM-cutoff |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `modules/rendering.md`, `current-best-practices.md` |
| **Post-Cutoff APIs Used** | None specific to this domain — `Light2D`, `CanvasModulate`, `Tween`, `CanvasTexture.normal_texture` are all pre-4.3 stable APIs. The 4.6 glow/tonemapping reorder and 4.7 `LinearToSRGB` clamp removal apply only to Mobile/Forward+, not Compatibility — noted for completeness, not load-bearing here. |
| **Verification Required** | C1 (real jar normal-map asset, cross-browser — currently placeholder-art/desktop-Chrome-only) and C4 (8-concurrent-`Light2D` frame budget — currently unmeasured on any device, mobile included) per `docs/technical-setup/web-export-verification-plan.md` Gate C. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Content Data — `visual_stages`/`growth_pattern`/tolerance fields via `get_definition()`), ADR-0003 (Object Placement — `get_position()`/`is_held()` polling), ADR-0008 (Input Abstraction — this ADR's jar root scene node is the same node ADR-0008's `register_jar()` expects), ADR-0002 (signal/direct-call convention), ADR-0010 (Discovery Surfacing — `get_active_items()`, ratified; this ADR's original forward-referenced assumption matched exactly, no rework needed). |
| **Enables** | Nothing further blocked on this — Diorama Rendering is a confirmed leaf system, no downstream dependents (`systems-index.md`). |
| **Blocks** | Diorama Rendering implementation stories — already gated by the GDD's own BLOCKED status on Open Question 1, not newly introduced here. |
| **Ordering Note** | Should be Accepted after ADR-0001, ADR-0002, ADR-0003, and ADR-0008. Its Discovery Surfacing interface assumption should be revisited once that system's own ADR exists. |

## Context

### Problem Statement

`design/gdd/diorama-rendering.md` fully specifies *what* renders (11 Core
Rules, 6 Formulas, a per-object render state machine) but not *how* it's
structured in Godot: whether rendering logic is centralized or distributed
per entity, who owns creating/freeing the Discovery cue `Light2D` nodes,
and how this system's scene composition connects to Input Abstraction's
need for a jar node reference (ADR-0008). The GDD's own Open Question 1
(BLOCKING) — whether `Light2D`/normal-map/glow behave as designed on
Compatibility/WebGL2 — is only partially answered by the verification
spike: C1 passed provisionally on placeholder art only, C3 passed on
desktop Chrome only, C2 shows a directional-but-unconfirmed "clamped glow"
result with an explicit unresolved design consequence, and C4 (the actual
performance budget this whole approach depends on) has no measurements at
all, on any device, including the mobile hardware the plan itself flags as
the likeliest failure point. This ADR locks in the implementation structure
without waiting for further hardware access, on the same defensive premise
ADR-0008 used: nothing here should preclude tightening or reworking a
specific technique once real data exists.

### Constraints
- Web export only, Compatibility renderer (OpenGL ES3/WebGL2) — no
  Forward+/Mobile-only features (SDFGI, some volumetric fog) available.
  `current-best-practices.md` states this explicitly.
- ≤500 draw calls, ≤16.6ms frame budget (`technical-preferences.md`).
- No central event-bus/mediator autoload (registry `forbidden_patterns:
  event_bus_mediator`).
- This system is a pure read-only observer (GDD Core Rule 1) — it must
  never write to any upstream system's state.
- C2's potential design consequence (painted-halo vs. point-light bloom for
  Detail Event) is **out of this ADR's authority** — routed to
  `creative-director`/`art-director` per the verification plan's own
  governance, not decided here.

### Requirements
- Render plant/creature/object state exactly as the GDD's Core Rules and
  Formulas specify, with zero upstream mutation.
- Discovery cue `Light2D` nodes must be created on cue activation and freed
  on cue end, contributing to the tracked worst-case count of up to 8
  concurrent `Light2D` nodes (1–3 ambient + up to 5 cue-driven).
- Must supply a jar-local coordinate space Input Abstraction (ADR-0008) can
  convert into via `to_local()`.

## Decision

**No central rendering coordinator.** Each rendered entity (a plant
instance, a creature instance, the one repositionable object, the jar's
static dressing) is its own small scene + script that polls its relevant
upstream system(s) directly in `_process()`, using the already-registered
read-only interfaces (`docs/registry/architecture.yaml`:
`content_data_query`, `jar_moisture_light_growth_creature_state`,
`object_position_held_grab_offset`). This matches the leaf-consumer pattern
ADR-0003 already established (`DioramaRendering._process() ──poll──>
ObjectPlacement.get_position()/is_held()`) rather than introducing a new
coordinating layer for a small, fixed entity roster (a handful of plants
and creatures, one object).

1. **Jar root scene** (`JarRoot.tscn`, owned by Diorama Rendering) is the
   scene composition root: `CanvasModulate` (day/night tint, Formulas' Day/
   Night Lighting Curve), the ambient "sun" `Light2D` (fixed direction,
   color/intensity driven by the day/night gradient and Core Rule 11's
   watering-sheen energy boost), the vignette sprite, substrate sprite,
   glass overlay sprite, and child nodes for each plant/creature/object
   instance. **This is the same jar node ADR-0008's `register_jar()`
   expects** — `JarRoot._ready()` calls `InputAbstraction.register_jar(self)`
   (runs after `InputAbstraction`'s own `_ready()`, per Godot's autoload
   load-order guarantee), tying this ADR's scene ownership directly to
   Input Abstraction's coordinate-conversion dependency.

2. **Discovery cue `Light2D` ownership**: the target element's own render
   script creates a child `Light2D` when Discovery Surfacing reports it as
   an active cue's target, and frees it when the cue ends. No separate
   pool/manager — the light's lifetime is scoped to its owning node's
   lifetime, consistent with the no-coordinator decision above, and
   Discovery Surfacing's own concurrency cap (Tuning Knobs, ≤5 cue-driven
   lights, on top of the 1–3 fixed ambient lights — ≤8 total, not two
   separate figures to reconcile) already bounds the count without
   additional enforcement here. **Engine specialist finding**: a cue
   `Light2D` must have its `range_item_cull_mask` matching the target
   sprite's light mask (default layer 1 — only a risk if any sprite uses a
   non-default mask) and `range_z_min`/`range_z_max` covering the target's
   z-index, or the light silently fails to illuminate it — verify
   explicitly per cue category during implementation, not just visually
   against placeholder art. **Ratified interface** (was provisional at
   authoring time; `docs/architecture/adr-0010-discovery-surfacing-reveal-queue-architecture.md`
   now ratifies this exact shape — the assumption below matched, no
   rework needed):
   ```gdscript
   DiscoverySurfacing.get_active_items() -> Array[DiscoveryItem]
   # DiscoveryItem (RefCounted): category (Growth/Departure/DetailEvent/Arrival),
   # target_id, from_stage/to_stage (Growth only), position (Departure only),
   # full_cycle (Departure only) — see ADR-0010 Key Interfaces for the full shape.
   ```
3. **Retriggerable tweens** (STALLED tint, snap-back, wobble, watering
   sheen) each hold a stored `Tween` reference on their owning node;
   retrigger kills the existing reference before calling `create_tween()`
   again — this is the GDD's own explicit mandate (Formulas, Snap-back/
   Wobble Timing), restated here as the implementation contract every
   entity script follows, not a new decision.
4. **Baked light + sparse `Light2D` accents**, not real-time per-pixel
   lighting scene-wide — this is the GDD's own locked Visual/Audio
   Requirements decision (`current-best-practices.md` independently
   confirms SDFGI/volumetric techniques are unavailable under
   Compatibility); this ADR's job is to confirm the technical grounding
   holds, not to re-decide it.
5. **Verification-gap handling**: implementation may proceed on this
   architecture now. However, per the GDD's own CR7/AC10b gate-ability
   language (ADVISORY, gated by a named `/smoke-check`, not a unit test),
   **no `Light2D`-dependent story is marked Done until**: (a) Gate C1 is
   re-run against the real jar normal-map asset (not the placeholder dome)
   on at least the required device matrix minimum (desktop Chrome + one iOS
   Safari device), and (b) Gate C4 produces actual ms/draw-call numbers
   under the 8-concurrent-`Light2D` worst case on a mid-range mobile
   reference device. C2's design consequence is explicitly not resolved
   here — flagged for `creative-director`/`art-director` per the
   verification plan's own routing instruction.

### Architecture Diagram
```
JarRoot (Diorama Rendering's own scene, .tscn)
  ├─ CanvasModulate           (day/night tint, Formulas: Day/Night Lighting Curve)
  ├─ Light2D "sun"            (fixed direction; color/intensity ← day/night gradient
  │                             + Core Rule 11 watering-sheen energy boost)
  ├─ vignette Sprite2D        (static, one draw call)
  ├─ substrate Sprite2D       (baked moisture variation + Watering Sheen self_modulate tween)
  ├─ glass overlay Sprite2D   (hand-authored, passes through CanvasModulate)
  ├─ PlantInstance × N        (script polls EcosystemSimulation.get_growth_stage()/
  │                             get_jar_moisture()/get_light_level(), ContentData.get_definition();
  │                             owns its own STALLED-tint Tween, Growth Pattern Scaling transform,
  │                             and — if it's an active Discovery cue target — its own cue Light2D)
  ├─ CreatureInstance × N     (script polls CreatureBehavior's live position/PRESENT-ABSENT state)
  └─ ObjectInstance (Rock)    (script polls ObjectPlacement.get_position()/is_held();
                                owns its own snap-back/wobble Tween + WOBBLING/SNAPPING_BACK state)

JarRoot._ready() ──register_jar(self)──> InputAbstraction (ADR-0008)
  (runs after InputAbstraction's own _ready(), per autoload load-order guarantee)

No central coordinator. No event bus (registry forbidden_patterns).
Discovery cue Light2D nodes: created/freed by whichever entity script is
the current cue's target — not a separate pool.
```

### Key Interfaces
```gdscript
# JarRoot (scene root, Diorama Rendering) — not an autoload, a scene node
func _ready() -> void:
    InputAbstraction.register_jar(self)   # ADR-0008 — must run before any gesture event

# PlantInstance (scene node + script, one per plant) — illustrative shape,
# not an exhaustive spec; the GDD's Formulas remain the source of truth
# for every numeric expression.
var _stalled_tween: Tween       # kill-and-restart per Formulas
var _cue_light: Light2D         # null unless this plant is the active cue target
func _process(_delta: float) -> void:
    var stage := EcosystemSimulation.get_growth_stage(plant_id)
    var moisture := EcosystemSimulation.get_jar_moisture()
    var light := EcosystemSimulation.get_light_level()
    # ... Core Rules 2/2a/3/10, Formulas, applied exactly as specified in the GDD

# ObjectInstance (scene node + script, the Rock)
func _process(_delta: float) -> void:
    var pos := ObjectPlacement.get_position(object_id)
    var held := ObjectPlacement.is_held(object_id)
    # ... Core Rule 4, States and Transitions (SETTLED/FOLLOWING/SNAPPING_BACK/WOBBLING)
```

## Alternatives Considered

### Alternative 1: Central `DioramaRenderer` coordinator autoload
- **Description**: One autoload polls every upstream system once per
  frame and pushes updates out to entity nodes it owns/manages centrally.
- **Pros**: Single place to reason about total `Light2D` count and frame
  cost.
- **Cons**: Introduces a new coordinating layer this project's established
  patterns don't otherwise use; every existing leaf-consumer system
  (Diorama Rendering's own prior informal pattern, per ADR-0003's diagram)
  already polls upstream systems directly from wherever the visual lives.
- **Rejection Reason**: The entity roster is small and fixed (a handful of
  plants/creatures, one object) — a coordinator solves a fan-out problem
  this project doesn't have, and Discovery Surfacing's own concurrency cap
  already bounds the `Light2D` count without central accounting.

### Alternative 2: Dedicated `CueLightManager` pool for Discovery cues
- **Description**: A separate script/autoload owns a pool of up to 5
  `Light2D` nodes, repositioning them at whatever element Discovery
  Surfacing names as the current cue target.
- **Pros**: More explicit central accounting of the concurrent-`Light2D`
  count Open Question 1/C4 care about.
- **Cons**: A pooled/repositioned light needs to also inherit or fake the
  target element's local transform for the cue to read as attached to that
  element, adding complexity a directly-owned child `Light2D` gets for
  free from normal scene-tree parenting.
- **Rejection Reason**: Consistent with the no-coordinator decision — the
  target element already exists and already has a transform; a child
  `Light2D` scoped to its lifetime is simpler and needs no separate pool
  bookkeeping.

### Alternative 3: Real-time per-pixel dynamic lighting scene-wide
- **Description**: Light every material dynamically at runtime instead of
  baking light into `visual_stages` sprites.
- **Pros**: Would make the "reactive to time of day" effect fully dynamic
  rather than color/intensity-only.
- **Cons**: Not achievable cheaply under Compatibility/WebGL2 — SDFGI and
  related techniques require Forward+/Mobile (`current-best-practices.md`
  confirms this independently of the GDD's own claim).
- **Rejection Reason**: Already ruled out by the GDD itself (Visual/Audio
  Requirements: "not achievable cheaply... and shouldn't be attempted");
  restated here because it's the alternative this ADR's Engine Compatibility
  table exists to rule out with an independent citation, not because it was
  genuinely still open.

## Consequences

### Positive
- No new coordinating component to build or reason about; each entity's
  render logic is self-contained and independently testable in isolation.
- Tying `JarRoot._ready()` to `InputAbstraction.register_jar()` makes the
  cross-ADR dependency between Input Abstraction and Diorama Rendering
  explicit in code, not just in documentation.
- Discovery cue `Light2D` lifetime is scoped to its owning node by
  construction — freeing the entity frees the light, no leak class to
  guard against separately.

### Negative
- No single place to query "how many `Light2D` nodes exist right now" —
  if C4's re-verification later demands active budget enforcement (not
  just measurement), that logic would need to be added somewhere, likely
  requiring a small registry this decision currently avoids.
- **Resolved 2026-08-10** (previously read: "The Discovery Surfacing query
  shape (`get_active_items()`) is an assumption, not a ratified contract —
  if that system's own ADR settles on a different shape, this ADR's entity
  scripts need a follow-up pass."): ADR-0010 ratified this exact shape (see
  Decision §2 above and ADR Dependencies) — the assumption matched, no
  follow-up pass needed. `docs/consistency-failures.md` flagged this
  leftover wording as stale relative to the rest of this document, which
  already treats the interface as ratified.

### Risks
- **C1/C4 remain genuinely unverified**, and unlike Input Abstraction's
  gap, this is the *primary rendering technique* and the *actual target
  hardware*, not an edge case. If C1 fails against the real jar asset
  (normal-map response doesn't hold on real production art), the "highest-
  value asset" treatment described in the GDD needs to move to baked/
  painted specular — a design escalation, not a fix, per the GDD's own C1
  FAIL criterion. If C4 fails on mobile, the 8-concurrent-`Light2D` worst
  case needs a tuning-knob reduction (Discovery Surfacing's own cue-
  concurrency cap, or the 1–3 ambient light count) — a decision for
  `creative-director`/`art-director`/`game-designer`, not this ADR.
  **Mitigation**: neither failure mode invalidates the no-coordinator
  structural decision itself — both are tuning/asset consequences within
  the same architecture, not architecture-level rework.
- **C2's design consequence is unresolved** and this ADR deliberately
  does not decide it — Detail Event's "point-light bloom" cue may need to
  become a painted additive halo if C2's "clamped glow" finding holds
  cross-browser. Tracked as an open flag, not a blocker to this ADR's own
  Acceptance. **Engine specialist context** (not a confirmed cause, offered
  to inform the eventual `creative-director`/`art-director` ruling):
  Compatibility/WebGL2 HDR glow needs float/half-float render target
  support (`EXT_color_buffer_float`), which is inconsistently available
  across GPU/driver/browser combinations and can silently fall back to LDR
  with no error — plausible explanation for "no visible `hdr_2d` on/off
  difference," but Gate C ran no energy sweep to confirm this specific
  mechanism versus some other configuration issue. Whoever re-runs C2
  should test an energy sweep to distinguish the two before treating the
  cause as settled.
- **Engine specialist gotcha, not yet exercised by Gate C**: normal-map
  lighting shader variants compile per distinct light `blend_mode`/
  `texture`/`shadow` configuration, not per instance — reused configs
  shouldn't stall, but this is unverified for the real jar asset + multiple
  simultaneous lights specifically on lower-end mobile GPUs, which is
  exactly the untested C1/C4 gap above, not a new one.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `diorama-rendering.md` | Core Rule 1 (pure read-only observer) | Per-entity scripts only ever call already-registered read-only query interfaces (`get_*`), never a write method — no upstream mutation path exists in this structure. |
| `diorama-rendering.md` | Visual/Audio Requirements (Discovery cue `Light2D` lifecycle) | Target-element-owned `Light2D` creation/freeing, scoped to cue activation/end. |
| `diorama-rendering.md` | Open Question 1 (BLOCKING — Compatibility 2D lighting) | Not resolved by this ADR. Architecture proceeds per the GDD's own defensive premise; C1/C4 re-verification required before any `Light2D`-dependent story is marked Done, per the GDD's own CR7/AC10b gate-ability language. |
| `diorama-rendering.md` | Core Rule 4/Object Placement rendering | `ObjectInstance` script polls `ObjectPlacement.get_position()`/`is_held()` per the already-registered `object_position_held_grab_offset` interface. |
| `input-abstraction.md` (via ADR-0008) | `register_jar()` coordinate-conversion dependency | `JarRoot._ready()` is the concrete call site — this ADR is what actually satisfies that dependency, not just documents it. |

## Performance Implications
- **CPU**: Per-entity `_process()` polling is cheap (a handful of getter
  calls per plant/creature/object, no per-pixel work) — matches the GDD's
  own Formulas section claim that all six formulas are "cheap enough... to
  stay well within the ≤500 draw call / 60fps... budget," which this ADR
  does not re-verify independently.
- **Memory**: `Light2D` nodes are created/freed per cue activation, not
  pooled — negligible churn given cue frequency (Discovery Surfacing's own
  pacing) is low relative to frame rate.
- **Load Time**: None beyond normal scene instantiation.
- **Network**: N/A.
- **Unresolved**: The actual worst-case frame cost (C4, 8 concurrent
  `Light2D` + tween + day/night transition) is not measured — this ADR's
  performance claims above are about the *structural* cost (polling,
  node create/free), not the *rendering* cost, which remains the open
  Gate C4 question.

## Migration Plan
N/A — new system, no existing implementation to migrate from.

## Validation Criteria
- Unit/scene-tree-structure tests against the GDD's Acceptance Criteria
  that are testable today (CR1 read-only-observer spy harness, CR6 tween
  non-instant checks, CR10a/13d scene-tree parenting assertions, the
  Formulas' pure-math criteria).
- **Not closed by unit tests alone**: CR7's 10b (the 8-concurrent-`Light2D`
  budget check) is explicitly ADVISORY, gated by the named `/smoke-check`
  against real Gate C1/C4 re-verification data — do not mark it passing
  without that profiling pass, per the GDD's own explicit caveat.

## Related Decisions
- `docs/architecture/adr-0001-content-data-format.md` — `get_definition()`
  contract this ADR's entity scripts read from.
- `docs/architecture/adr-0003-object-placement-collision-approach.md` —
  originating leaf-consumer pattern this ADR extends.
- `docs/architecture/adr-0008-input-gesture-abstraction-web-touch-focus.md`
  — `register_jar()` call this ADR's `JarRoot` scene satisfies.
- `design/gdd/diorama-rendering.md` — full behavioral specification this
  ADR implements.
- `docs/technical-setup/web-export-verification-plan.md` — Gate C, the
  still-open empirical verification this ADR proceeds without.
- `docs/architecture/adr-0012-ambient-audio-godot-strategy.md` — this
  ADR's Decision (Core Rule 11, Watering Substrate Sheen) names the tween
  but never specified what triggers it; ADR-0012 closes that gap with a
  new `EcosystemSimulation.watering_applied` signal (companion edit to
  ADR-0004), which this system's substrate sprite script should connect
  to. Content otherwise unchanged by this note.
