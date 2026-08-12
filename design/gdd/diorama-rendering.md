# Diorama Rendering

> **Status**: round 1 blockers resolved (full-mode `/design-review`, 2026-08-05) — 8 blockers, resolved below. Core Rule 11 (Watering Substrate Sheen) added 2026-08-09, `art-director` addition, no specialist re-review round — single-owner visual-spec addition within `art-director`'s own domain, closing `tending-input.md`'s two remaining Open Questions.
> **Author**: user + game-designer, systems-designer, qa-lead, performance-analyst, gameplay-programmer, godot-specialist, technical-artist, creative-director, art-director
> **Last Updated**: 2026-08-09 (Core Rule 11 added, see Status above)
> **Implements Pillar**: Pillar 4 (Every Detail Rewards Attention)
> **Creative Director Review (CD-GDD-ALIGN)**: MAJOR REVISION NEEDED (full-mode `/design-review`, 2026-08-05) — 8 blockers, resolved below (locked-anchor fidelity fixes, a Core Rule contradicting this doc's own Player Fantasy, and an escalated verification gate — none required a formula redesign).
> **BLOCKED gate** (Open Question 1, escalated from advisory to blocking this round): the Light2D/normal-map/glow rendering approach — used by both ambient lighting and all 4 Discovery Surfacing cue categories — depends on unverified Godot 4.7.1 Compatibility/WebGL2 renderer behavior. Does not block this GDD's own approval (same precedent as the `visibilitychange` gate inherited by `time-drift.md`/`input-abstraction.md`/`discovery-surfacing.md`), but gates implementation — see Open Questions.

## Overview

Diorama Rendering is the presentation layer that turns every other system's
raw state — a plant's `growth_stage`, an object's committed position, a
creature's live location, Discovery Surfacing's active cue — into the
actual jar the player sees: a small, physically-lit, macro-lens diorama.
It is purely reactive and automatic; the player never directs it, only
watches its output respond to everything else they and the simulation do.
It exists because no other system owns a single frame of visual output
today — Content Data holds `visual_stages`/`visual_ref` as data, Object
Placement/Ecosystem Simulation/Creature Behavior compute state, Discovery
Surfacing computes which cue is active, but nothing yet resolves any of
that into pixels. Without it, the game would remain literally invisible:
every mechanic (tending, growth, drift, discovery) already resolves
correctly in data, but none of it exists as a player experience without
this system rendering it. This is also where the game's entire visual
identity — the Diorama Realism anchor from `game-concept.md` (material
truth, scale intimacy, light as mood) — actually gets executed rather than
just described.

## Player Fantasy

Diorama Rendering has no gameplay input of its own, but it is the system
most responsible for whether the entire game feels real. The player
fantasy it serves is the one named directly in the concept doc's Visual
Identity Anchor: staring into a small, real, physically-lit world "like a
nature macro photograph you could stare at for an hour" — the sense that
this is a tiny, believable place, not an illustration of one. Every other
system's payoff routes through this one: Ecosystem Simulation's growth is
only satisfying if a plant visibly, believably changes; Discovery
Surfacing's cues are only legible if their light/material language reads
as real; Object Placement's drag only feels tactile if the object visually
responds like a real weighted thing. If this system fails — flat/cartoon
shading instead of physically-lit materials, a wide establishing shot
instead of intimate macro framing, UI-chrome cues instead of diegetic
light — every other system's design intent survives in data but is lost
in presentation, and the game reads as a spreadsheet with sprites rather
than a small living place worth returning to.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Review manually before
production.)*

## Detailed Design

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Review manually before production.)*

### Core Rules

1. Diorama Rendering is a **pure, read-only observer**: it renders
   whatever state Content Data, Object Placement, Ecosystem Simulation,
   Creature Behavior, Time & Drift, Persistence/Save, and Discovery
   Surfacing currently report, every frame, and writes back to none of
   them. Data flows one way only, into this system.
2. A plant instance renders `visual_stages[growth_stage]` for its type
   (Content Data) — the exact visual asset at the plant's current index,
   **with no sprite cross-fade between stages, ever** (cross-fading two
   textures means blending two contradictory baked shadows and doubles
   draws — never worth it, see Formulas' Catch-up Growth Reveal). For a
   plant whose `growth_stage` is **unchanged** since last rendered (the
   common case, and the only case during live ACTIVE play, since
   `growth_stage` never changes outside Time & Drift's catch-up batch —
   see `time-drift.md` Core Rule 6): the sprite and its Growth Pattern
   Scaling transform (Core Rule 10) both render instantly, no
   interpolation, exactly as before.

   **Corrected this review (`creative-director` ruling on a
   `game-designer` finding) — struck the prior "dead code, player
   structurally never present" justification for treating EVERY
   stage-swap as instant.** That reasoning only holds *within* a session;
   it doesn't hold *across* one. This is a cozy check-in game with no
   stated minimum session length — a player returning via tab close/
   reopen (this game's normal play pattern, not an edge case) witnesses
   the catch-up render on effectively every session with growth. A plant
   silently popping to a new size/shape between glances contradicts this
   document's own Player Fantasy ("growth is only satisfying if a plant
   visibly, believably changes") and its own macro-lens visual rule. See
   Core Rule 2a and Formulas' Catch-up Growth Reveal for the fix — which
   eases the *scale transform*, not the sprite, so the "no cross-fade"
   guarantee above is fully preserved.
2a. **Catch-up Growth Reveal (new this review).** For a plant WITH an
   active Growth discovery item this session (Discovery Surfacing's own
   delta set already records `{from, to}` for it — see
   `discovery-surfacing.md` AC1 — this system reads that recorded value,
   it does not track its own history, preserving Core Rule 1's pure
   read-only/no-state guarantee): the sprite still hard-swaps to
   `visual_stages[to]` with zero interpolation on the swap itself (Core
   Rule 2's "no cross-fade" holds), but the Growth Pattern Scaling
   transform (Core Rule 10) eases from the `from`-stage's scale to the
   `to`-stage's scale over `CATCHUP_REVEAL_DURATION`, once, starting on
   that plant's first rendered frame this session — timed so the sprite
   swap lands at the ease's midpoint, where the scale is already
   mid-motion and the discrete change reads as part of one continuous
   "settling into its new size" rather than an isolated pop. See Formulas
   for the exact expression. A plant with no active Growth item this
   session (unchanged, or no prior session exists) is unaffected — Core
   Rule 2's instant render applies.
3. **Mandated per-plant STALLED cue (hard requirement, not a stretch
   goal).** Each plant instance evaluates `moisture_ok = jar_moisture ∈
   [plant.moisture_tolerance_min, plant.moisture_tolerance_max]` and
   `light_ok = light_level ∈ [plant.light_tolerance_min,
   plant.light_tolerance_max]` — the same sub-expressions Ecosystem
   Simulation's own `growth_stage_delta` formula uses — **every frame**
   (same cadence as Core Rules 1/4/5, a cheap boolean check, never
   throttled or gated on an external event) and desaturates/dims its
   rendered sprite whenever `moisture_ok AND NOT light_ok` (the STALLED
   condition), returning to full color otherwise. Unlike Core Rule 2,
   **this check runs continuously/live, not only at session start**:
   `jar_moisture` can change live via watering (Tending Input),
   so a player who waters a light-stalled plant must see it *stay*
   desaturated immediately — communicating "moisture is fine now,
   something else is blocking growth" even though no tick has run yet
   and `growth_stage` hasn't moved. This is not optional polish: per
   `ecosystem-simulation.md`'s own round-13/14 review, that system is not
   considered implementation-complete until this cue exists — STALLED
   and DECAYING otherwise render identically (both just "`growth_stage`
   didn't move"), leaving a player watering correctly unable to tell
   working-as-intended from broken. A secondary jar-wide `light_level`
   ambient tint (ambient mood only) may ship alongside this cue per that
   GDD's own suggestion, but does not substitute for it.
4. Repositionable objects render at Object Placement's live `visual_pos`
   every frame while HELD (continuous drag-follow, per that GDD's
   Drag-follow position formula) and at their committed position
   otherwise — no separate rendering-side interpolation on top of what
   Object Placement already computes for the live-follow case.
5. Creatures render at Creature Behavior's live position every frame
   while PRESENT, continuously, matching that system's
   `movement_speed`-driven motion — this is the **one actor type that
   moves live during an ACTIVE session** (unlike plant growth, which
   never does — see Core Rule 2).
6. Object Placement's snap-back (invalid-placement revert, Core Rule 4
   of that GDD) and wobble (tap-on-footprint acknowledgment, Core Rule 7
   of that GDD) render as **eased tweens, never instant resets** — this
   closes both of that GDD's own pending Open Questions ("Snap-back
   animation style," "Tap-on-footprint wobble animation style") with a
   concrete choice. Concrete timing/easing values are defined in Visual/
   Audio Requirements below.
7. Discovery Surfacing's active queue item(s) render **exactly** per
   that GDD's already-locked Visual/Audio Requirements (per-category
   diegetic light/material cues, ease-in/hold/ease-out motion, no
   looping pulse) — this system **executes** that spec, it does not
   redefine it.
8. Time & Drift's `day_night_phase` drives a continuous, cosmetic-only
   ambient lighting/color shift across the whole scene, applied every
   frame — never gated by or interacting with any other rendering rule,
   per that GDD's own "zero gameplay effect" guarantee.
9. On session start (after Persistence/Save resolves and Time & Drift's
   catch-up batch completes), the scene's **data state** is
   fully-resolved on its very first frame — no loading spinner, no
   placeholder/default data, no frame ever shows pre-catch-up state. This
   extends Time & Drift's own atomic/invisible catch-up guarantee one
   layer further into presentation. **Reworded this review
   (`creative-director` ruling):** this is a guarantee about *data*, not
   a prohibition on *motion* — Core Rule 2a's Catch-up Growth Reveal
   plays an authored, bounded animation whose start and end points are
   both already fully-resolved, correct data (sourced from Discovery
   Surfacing's own delta computation, never a placeholder), so it does
   not reopen this guarantee. What this rule forbids is a frame showing
   *wrong or default* data — not every frame rendering with zero motion.
10. A plant's `growth_pattern` (Content Data: `carpet`/`clump`/`climb`)
   determines that type's spread/silhouette treatment as `growth_stage`
   rises — `carpet` spreads its rendered footprint outward, `clump`
   grows in place (height/bulk, not footprint), `climb` grows vertically
   — per Content Data's own stated intent for the enum. This GDD is
   where that design intent is actually realized; concrete per-type
   asset authoring is Visual/Audio Requirements' concern, not a further
   rule here.
11. **Watering Substrate Sheen (new 2026-08-09, `art-director` addition —
   closes `tending-input.md`'s "Watering cue treatment" Open Question,
   visual half).** Tending Input's `apply_watering()` call triggers an
   immediate, same-frame visual cue — matching that GDD's Core Rule 3
   same-frame requirement and `ambient-audio.md`'s identical same-frame
   guarantee for the audio half of this same unified moment — built
   entirely from this document's own established toolkit, no new
   rendering technique: (a) the substrate sprite's `self_modulate` tweens
   toward a darker, faintly cool-shifted `WATERING_SHEEN_TINT` and back,
   the same tween mechanism Core Rule 3's STALLED cue already uses,
   jar-wide rather than positioned at the tap point (Ecosystem Simulation
   only tracks `jar_moisture` at jar level, not per-region, so a
   localized patch would misrepresent what actually changed — see Visual/
   Audio Requirements' existing "no per-region moisture-render system"
   scope limit, which this does not reopen); (b) the existing ambient
   "sun" `Light2D` (Visual/Audio Requirements — already used for rim-light
   on wet leaves and the glass jar's highlight band) briefly raises its
   `energy`, reading as increased specular catch-light off newly-wet
   surfaces — **no new `Light2D` node is instantiated for this cue**,
   unlike Discovery Surfacing's four categories, so it adds zero nodes to
   the worst-case concurrent `Light2D` count tracked in Open Question 1/
   Visual/Audio Requirements. Both channels share one 3-second
   rise-hold-fall envelope, `sheen_intensity(t)`, reused directly from
   `ambient-audio.md`'s Reactive Layer Boosts `envelope(t, D_water)`
   function — same shape, same `D_water=3.0s` constant — so the visual
   and audio swells are locked to one shared clock, not merely the same
   duration by coincidence; this is what makes the two read as one
   sensory moment rather than two effects competing for attention. No
   droplet particle, no ripple decal, no discrete "splash"-equivalent
   pop — matching Ambient Audio's Core Rule 3 exactly: atmospheric, not
   informational. Both channels use the same kill-and-restart retrigger
   policy already established for every other retrigger-able tween in
   this document (Snap-back/Wobble Timing's shared pattern): a repeat tap
   before the current swell finishes restarts both tweens from their live
   interpolated values, never stacking or queuing a second concurrent
   swell — this is the concrete resolution of `tending-input.md`'s
   "Repeat-tap feedback stacking" Open Question. See Formulas for the
   exact expressions.

### States and Transitions

This system holds no single global state machine of its own (it is a
pure reactive renderer, same "no lifecycle" pattern as Content Data) —
but each individually rendered **repositionable object** does have a
small per-instance render state, driven entirely by Object Placement's
own state:

| State | Trigger | Next State |
|---|---|---|
| SETTLED | Object Placement reports the object is now HELD | FOLLOWING (renders live `visual_pos` every frame, Core Rule 4) |
| FOLLOWING | Object Placement reports `drag_end`, position commits | SETTLED (renders the new committed position) |
| FOLLOWING | Object Placement reports `drag_end`, position reverts (invalid or `canceled`) | SNAPPING_BACK (eased tween from the held position back to the last committed position, Core Rule 6) |
| SNAPPING_BACK | tween completes | SETTLED |
| SETTLED | a `tap` lands on this object's footprint (Object Placement Core Rule 7) | WOBBLING (eased, non-committal tween, Core Rule 6) |
| WOBBLING | tween completes | SETTLED |

Plants and creatures have no comparable render-state machine: a plant
simply renders its current `visual_stages` index and STALLED-cue tint
every frame (Core Rules 2–3), and a creature simply renders its current
live position every frame (Core Rule 5) — neither has a distinct
"settled vs. transitioning" mode.

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Content Data | Upstream | Reads `visual_stages`/`visual_ref`/`growth_pattern` per type, plus `moisture_tolerance_min/max`/`light_tolerance_min/max` (needed to evaluate the STALLED cue's `moisture_ok`/`light_ok`, Core Rule 3) — resolves which asset to render |
| Object Placement | Upstream | Reads committed/live `visual_pos`, HELD state, `drag_end` outcome (commit vs. revert) — drives object rendering and the snap-back/wobble tweens |
| Ecosystem Simulation | Upstream (hard) | Reads `growth_stage`, `jar_moisture`, and `light_level` per plant instance/jar — the latter two drive the mandated STALLED cue (Core Rule 3); this is a hard blocking dependency per that GDD's own round-13 review, not merely indirect |
| Creature Behavior | Upstream | Reads live position and PRESENT/ABSENT state per creature — drives creature rendering |
| Time & Drift | Upstream | Reads `day_night_phase` for the cosmetic ambient lighting shift |
| Persistence/Save | Upstream (indirect) | Renders whatever state the other upstream systems already resolved post-restore — never reads the save blob directly itself |
| Discovery Surfacing | Upstream | Reads the active discovery item(s) (category, target element/position) — renders the already-locked per-category diegetic cue; a Growth item's `{from, to}` also drives Core Rule 2a's Catch-up Growth Reveal |
| Tending Input | Upstream (soft, added 2026-08-09) | Reads the `apply_watering()` trigger event only (no position data needed — the cue is jar-wide/existing-light-based, not tap-positioned) — drives Core Rule 11's Watering Substrate Sheen; mirrors `ambient-audio.md`'s own identical dependency on the same trigger for the audio half of this unified cue |

Diorama Rendering has **no downstream dependents** — it is a leaf system
in the dependency graph (confirmed by `systems-index.md`).

## Formulas

Six formulas, covering the places this system produces continuous
numeric output rather than a direct data pass-through: the mandated
STALLED-cue tint (Core Rule 3), the snap-back/wobble tweens (Core Rule
6), the day/night ambient lighting (Core Rule 8), the `growth_pattern`
scale transform (Core Rule 10), the Catch-up Growth Reveal (Core Rule
2a, added 2026-08-05), and the Watering Substrate Sheen (Core Rule 11,
added 2026-08-09). All six use native Godot resources (`Tween`,
`Gradient`, and — for Watering Substrate Sheen — a property tween on an
already-existing `Light2D` node's `energy`, not a new one) — no new
dependencies, and all are cheap enough (transform/tint math, no
per-pixel shader work) on their own terms to stay well within the ≤500
draw call / 60fps Compatibility-renderer budget — this claim covers only
these formulas' own math cost, not the separate, still-unverified
question of worst-case concurrent Light2D/cue overlap (see Open
Questions and Visual/Audio Requirements' Budget Allocation; Watering
Substrate Sheen does not add to that concurrent-Light2D count at all,
since it reuses an existing node rather than instantiating one).

### STALLED Cue Tint

Mandated by Core Rule 3 — this is not optional polish, `ecosystem-
simulation.md` treats it as a blocking requirement for that system's own
implementation-completeness.

`stalled = moisture_ok AND NOT light_ok`
`target_modulate = stalled ? STALLED_TINT : Color(1.0, 1.0, 1.0, 1.0)`

Applied as a tween on the plant sprite's `self_modulate`, re-triggered
(kill-and-restart from the live interpolated color, same policy as the
snap-back/wobble tweens) every time `stalled` flips — this can happen
live, mid-session, whenever watering changes `jar_moisture` enough to
cross `moisture_tolerance_min/max`.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| moisture_ok | — | bool | — | `jar_moisture ∈ [moisture_tolerance_min, moisture_tolerance_max]` (Ecosystem Simulation's own sub-expression) |
| light_ok | — | bool | — | `light_level ∈ [light_tolerance_min, light_tolerance_max]` (same source) |
| stalled | — | bool | — | true only when moisture is fine but light is not — the exact STALLED condition |
| STALLED_TINT | — | Color | constant, `(0.88, 0.90, 0.62, 1.0)` | **corrected this review (`creative-director` ruling on `game-designer`/`technical-artist` findings)** — was `(0.55, 0.58, 0.62, 1.0)`, a flat cool grey-blue that read as a status indicator, not a material response, and failed this document's own corrective test ("would it still make physical sense without the glow?"). New value is **etiolation**-based: pale, slightly yellow-green-shifted, desaturated via `self_modulate` multiply — the real physiological response of a light-starved-but-adequately-watered plant, not an arbitrary "paused" color |
| STALLED_TRANSITION_DURATION | — | float | constant, 0.6 (seconds) | tween duration between full color and the tint, `TRANS_SINE`/`EASE_IN_OUT` — slow enough to read as a gentle mood shift, not a flicker |

**Output Range:** `self_modulate` interpolates strictly between
`Color(1,1,1,1)` and `STALLED_TINT` — never darker/more desaturated than
the tint, never brighter than full color.
**Example:** Fern (`moisture_tolerance=[55,90]`, `light_tolerance=[40,80]`),
`jar_moisture=70` (in range → `moisture_ok=true`), `light_level=25` (out
of range → `light_ok=false`) → `stalled=true` → sprite tweens to
`STALLED_TINT` over 0.6s, reading as pale/etiolated rather than merely
dimmed. Player waters (`jar_moisture` rises further, still in range) —
`stalled` remains `true`, sprite stays etiolated, correctly communicating
the plant is not about to resume growing at the next tick despite the
successful watering. **Legibility under the day/night gradient must be
confirmed** during the technical-artist pass this cue already needs
(Open Questions) — specifically that the pale-yellow tint stays
distinguishable from the warm amber dawn/dusk gradient stop
(`(1.00, 0.82, 0.60)`), since both lean warm/yellow.

### Snap-back / Wobble Tween Timing

These share a timing *philosophy*, not one equation. Snap-back is a
one-way positional correction (a "never mind," proportional to how far it
has to travel); wobble is a stationary rotational nudge (a non-committal
"I heard you," fixed regardless of distance since it never travels).
Forcing them into a single formula would make wobble travel-dependent (it
has no travel) or make snap-back's duration constant (glitchy-fast on
long drags, sluggish on short ones). Both use non-elastic, non-bounce
easing — the same motion language `discovery-surfacing.md`'s Visual/Audio
Requirements already locked for cues ("ease-in/hold/ease-out only, never
linear or bouncy — bounce reads as UI feedback"), extended here from cues
to physical objects so the whole game shares one motion vocabulary.

**Kill-and-restart implementation pattern stated explicitly (added this
review, `gameplay-programmer` finding):** every retrigger-able tween in
this document (snap-back, wobble, STALLED-cue tint) must hold a
persistent stored `Tween` reference on its owning node, and on retrigger
must call `kill()` on that reference (if still valid/running) *before*
calling `create_tween()` again — never let a fresh `create_tween()` call
run concurrently with a still-active prior tween on the same property.
This is stated here once, as the shared pattern, rather than repeated
per-effect — Godot 4's `Tween` has no `stop()`-and-reconfigure API for
this use case, so "kill and restart" specifically means "hold a
reference, kill it, create a new one," not "reuse a stopped instance."

**Snap-back** (positional, distance-scaled):

`duration = clamp(SNAP_BASE_DURATION + distance × SNAP_PER_UNIT_DURATION, SNAP_BASE_DURATION, SNAP_MAX_DURATION)`

Tween: `TRANS_CUBIC`, `EASE_OUT` — fast start, decelerating into rest
(reads as settling under weight, not snapping).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| distance | — | float | 0–~200 (jar diameter, `rx=100`) | jar-space distance between the HELD `visual_pos` at `drag_end` and the last committed position |
| SNAP_BASE_DURATION | — | float | constant, 0.18 | minimum tween duration (also the clamp's lower bound) |
| SNAP_PER_UNIT_DURATION | — | float | constant, 0.0014 | seconds added per jar-space unit traveled |
| SNAP_MAX_DURATION | — | float | constant, 0.45 | maximum tween duration, regardless of distance |

**Output Range:** 0.18–0.45s, clamped — fast enough to never feel laggy
during normal frequent play, never so fast it reads as an instant
pop/glitch, never so slow that a full-jar-width revert feels sluggish.
**Example:** `distance=120` → `duration = clamp(0.18 + 120×0.0014, 0.18,
0.45) = clamp(0.348, 0.18, 0.45) = 0.348s`.

**Wobble** (rotational, fixed, non-committal):

`angle(t) = WOBBLE_ANGLE_DEG × sin(π × t / WOBBLE_DURATION)`, for `0 ≤ t ≤ WOBBLE_DURATION`

A single sine pulse: eases in from 0°, peaks at `t = WOBBLE_DURATION/2`,
eases back to 0° at `t = WOBBLE_DURATION`. Position and scale never
change — only rotation, matching Object Placement Core Rule 7's "position
never changes."

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| t | — | float | 0–WOBBLE_DURATION (seconds) | elapsed time since the wobble tween started |
| WOBBLE_ANGLE_DEG | — | float | constant, 4.0 | peak rotation amplitude in degrees |
| WOBBLE_DURATION | — | float | constant, 0.30 | total tween duration (seconds) |

**Output Range:** 0°–4°, always returning to exactly 0° at completion.
Amplitude fixed small enough to read as a friendly nudge, not a comic
shake or an error-buzz.
**Example:** `t=0.15` (midpoint) → `angle = 4.0 × sin(π×0.15/0.30) = 4.0
× sin(π/2) = 4.0°` (peak). At `t=0.30` → `angle = 4.0 × sin(π) = 0°` (rest).

### Day/Night Lighting Curve

Time & Drift's `day_night_phase` formula (`(session_elapsed_seconds mod
cycle_duration_seconds) / cycle_duration_seconds`) is a **sawtooth**: a
linear ramp 0→1 followed by an instantaneous reset to 0. A naive linear
map from raw `phase` straight to a lighting value would produce a visible
pop at every cycle wrap. This formula routes `phase` through a cosine
first, which is periodic and continuous across the wrap by construction
(`cos(2π×0.999...) ≈ cos(2π×0.0)`) — the seam is invisible regardless.

`t = (cos(2π × day_night_phase) + 1) / 2`
`canvas_modulate_color = DAY_NIGHT_GRADIENT.sample(t)`

Implemented as a single Godot `Gradient` resource, applied as a
`CanvasModulate` multiply tint over the diorama scene — Compatibility-
renderer safe (no per-pixel dynamic lighting required), effectively free
against the draw call budget.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| day_night_phase | — | float | 0.0–1.0 | Time & Drift's cosmetic phase (input, unmodified) |
| t | — | float | 0.0–1.0 | normalized "daylight-ness" — 1.0 = solar peak, 0.0 = deepest night |
| DAY_NIGHT_GRADIENT | — | Gradient | 4 color stops (below) | maps `t` to a CanvasModulate multiply color |

Gradient stops (all channels ≤1.0 — this only ever dims/tints toward
night or warms toward dawn/dusk, never brightens past the base art, so
highlights never blow out — matching the "material truth" principle):

| t | Color (R,G,B) | Read |
|---|---|---|
| 0.00 | (0.50, 0.58, 0.80) | deep night — cool, dim, desaturated blue |
| 0.35 | (0.78, 0.68, 0.75) | pre-dawn/late-dusk — transitional, still dim |
| 0.55 | (1.00, 0.82, 0.60) | dawn/dusk peak — warm amber glow |
| 1.00 | (1.00, 1.00, 1.00) | midday — neutral, true material color (no tint at peak) |

**Output Range:** `t` is bounded [0,1] since cosine is inherently
bounded, so the gradient sample never extrapolates. `canvas_modulate_color`
stays within each stop's authored channel range — gentle continuous
drift, never full blackout, never overexposure.
**Example:** `cycle_duration_seconds=1200`, `session_elapsed_seconds=900`
→ `day_night_phase = (900 mod 1200)/1200 = 0.75`. `t = (cos(2π×0.75)+1)/2
= (cos(270°)+1)/2 = 0.5` — a gentle amber-leaning tint between the 0.35
and 0.55 stops.

### Growth Pattern Scaling

`p = (max_stage == 0) ? 1.0 : clamp(growth_stage / max_stage, 0.0, 1.0)`
`scale_x = lerp(MIN_X[growth_pattern], 1.0, p)`
`scale_y = lerp(MIN_Y[growth_pattern], 1.0, p)`

**Local clamp added this review (`systems-designer` finding):** `p` is
now defensively clamped even though `growth_stage` is already clamped to
`[0, max_stage]` upstream (Ecosystem Simulation's `growth_stage_delta`
formula) — the prior version relied entirely on that upstream guarantee
holding with zero local defense-in-depth, inconsistent with this same
formula's existing local guard against `max_stage==0`. If the upstream
clamp were ever violated, this local clamp prevents `scale_x`/`scale_y`
from silently extrapolating past `1.0` or below `MIN_X`/`MIN_Y`.

Applied as a `Node2D.scale` transform on top of the already-selected
`visual_stages[growth_stage]` sprite (Core Rule 2 — the sprite itself
doesn't change smoothly, but this transform gives every stage-swap a
size/shape delta even without a cross-fade). **The anchor/pivot must be
the plant's base** (its root point on the jar floor), not sprite center —
otherwise `clump`/`climb` types would visually sink into the floor at low
`growth_stage` instead of growing up from a fixed base. This is a
required implementation detail, not optional polish.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| growth_stage | — | int | 0–max_stage | current stage index (Ecosystem Simulation, already clamped) |
| max_stage | — | int | 0–∞ (MVP: 3–6) | `visual_stages.length - 1` (Content Data) |
| growth_pattern | — | enum | {carpet, clump, climb} | Content Data field |
| p | — | float | 0.0–1.0 | normalized growth progress |
| MIN_X/MIN_Y[pattern] | — | float | constants, see table | per-axis scale floor at `growth_stage=0` |

Per-pattern constants (all reach exactly `1.0` at `growth_stage ==
max_stage`, so the terminal stage always matches the authored asset size
undistorted):

| growth_pattern | MIN_X | MIN_Y | Silhouette read |
|---|---|---|---|
| carpet | 0.35 | 0.35 | uniform spread outward on both axes |
| clump | 0.55 | 0.40 | modest footprint growth, more vertical bulk (Y grows faster than X) |
| climb | 0.75 | 0.45 | footprint nearly fixed, height grows more than footprint |

**Climb retuned this review (`creative-director` ruling on a
`technical-artist` finding):** was `MIN_X=0.85, MIN_Y=0.25` (a 0.60
per-axis divergence). Because light direction is *baked into the pixels*
(Visual/Audio Requirements), stretching X and Y non-uniformly by that
much visibly warps the baked-in shadow shape at every intermediate growth
stage — a physically-implausible skew this document never accounted for,
and one the new Catch-up Growth Reveal (below) would make more visible,
not less, by animating through it. **New constraint**: per-pattern
`MIN_X`/`MIN_Y` divergence is capped at 0.30 — climb retains a
directional "height grows more than footprint" read (0.75 vs. 0.45 is
still clearly asymmetric) without the extreme stretch. Any further
silhouette differentiation belongs in the authored per-stage
`visual_stages` sprites themselves, not in a larger non-uniform scale.

**Output Range:** bounded [MIN_X or MIN_Y, 1.0] per axis —
`growth_stage` is already clamped to `[0, max_stage]` by Ecosystem
Simulation's registered `growth_stage_delta` formula, and now also
locally clamped above, so `p` never leaves [0,1] and this never
extrapolates past the authored asset size.
**Example (Fern, `growth_pattern=clump`, `max_stage=6`):**
`growth_stage=3` → `p = 3/6 = 0.5` → `scale_x = lerp(0.55, 1.0, 0.5) =
0.775`, `scale_y = lerp(0.40, 1.0, 0.5) = 0.70`.

*(`systems-designer` consulted for these formulas — mandatory per this
section's high-risk gate, applies regardless of review mode.)*

### Catch-up Growth Reveal (new this review)

Per Core Rule 2a — plays once, only for a plant with an active Growth
discovery item this session (`from`/`to` stage values read from
Discovery Surfacing's own delta set, not tracked locally):

`p_from = (max_stage == 0) ? 1.0 : clamp(from_stage / max_stage, 0.0, 1.0)`
`p_to = (max_stage == 0) ? 1.0 : clamp(to_stage / max_stage, 0.0, 1.0)`
`reveal_t = clamp(seconds_since_first_render_this_session / CATCHUP_REVEAL_DURATION, 0.0, 1.0)`
`p_display = lerp(p_from, p_to, ease_in_out(reveal_t))`
`scale_x = lerp(MIN_X[growth_pattern], 1.0, p_display)`
`scale_y = lerp(MIN_Y[growth_pattern], 1.0, p_display)`

The sprite itself hard-swaps from `visual_stages[from_stage]` to
`visual_stages[to_stage]` at `reveal_t = 0.5` (the ease's midpoint) — not
at `reveal_t = 0` or `1.0` — so the discrete swap lands while the scale
is already mid-motion, reading as part of one continuous "settling"
rather than an isolated pop preceding or following a separate scale
animation. `ease_in_out` uses `TRANS_SINE`/`EASE_IN_OUT`, matching this
document's established motion language (Snap-back/Wobble Timing).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| from_stage, to_stage | — | int | 0–max_stage | this plant's Growth discovery item's recorded `from`/`to` (`discovery-surfacing.md` AC1) |
| CATCHUP_REVEAL_DURATION | — | float | constant, 0.5 (seconds) | total duration of the catch-up reveal, once per plant per session |
| reveal_t | — | float | 0.0–1.0 | normalized elapsed time since this plant's first rendered frame this session |
| p_display | — | float | 0.0–1.0 | the interpolated growth-progress value driving scale during the reveal |

**Output Range:** bounded exactly as Growth Pattern Scaling above —
`p_display` is a lerp between two already-clamped `[0,1]` values, so it
cannot leave `[0,1]` either.
**Example:** Fern (`growth_pattern=clump`, `max_stage=6`), Growth item
`{from: 2, to: 3}` → `p_from = 2/6 = 0.333`, `p_to = 3/6 = 0.5`. At
`reveal_t=0.5` (the swap instant): `p_display` is roughly the midpoint of
the eased curve between 0.333 and 0.5; sprite swaps to
`visual_stages[3]` at this exact instant while `scale_x`/`scale_y` are
already partway from their `p_from`-based values toward their
`p_to`-based ones. By `reveal_t=1.0` (0.5s elapsed): `p_display=0.5`
exactly, matching Growth Pattern Scaling's own steady-state formula for
`growth_stage=3` — the reveal converges to the same value the plant
would show if it had simply rendered `to_stage` from frame one, it only
delays reaching that value by `CATCHUP_REVEAL_DURATION`.

**Does not reopen Core Rule 9 (reworded this review):** both `p_from`
and `p_to` are already fully-resolved, correct data at the reveal's
start — this animates *through* two correct values, it never shows a
placeholder or default one.

*(`systems-designer` consulted for this formula — added this review to
resolve the Core Rule 2/Player Fantasy contradiction `game-designer`
raised; `creative-director` ruling on scope: animate the scale transform
only, never the sprite/texture itself, to avoid a cross-fade's draw-call
and baked-shadow-blending cost.)*

### Watering Substrate Sheen (new 2026-08-09)

Per Core Rule 11 — triggered by Tending Input's `apply_watering()` call,
same frame, no batching (mirrors `ambient-audio.md`'s own Core Rule 3
same-frame guarantee for the audio half of this same unified moment).

`sheen_intensity(t) = envelope(t, D_water)`

Reuses `ambient-audio.md`'s Reactive Layer Boosts `envelope(t, D)`
function directly, not a re-derivation — the same three-phase
rise-hold-fall shape (ease-in `D_water/6`, hold `D_water/3`, ease-out
`D_water/2`, each phase quarter-sine eased) and the same `D_water=3.0s`
constant, so the visual swell and the audio swell are locked to one
shared clock by construction. This is what makes the two cues read as
one sensory moment rather than two effects that merely happen to share a
duration.

`substrate_modulate(t) = lerp(Color(1.0, 1.0, 1.0, 1.0), WATERING_SHEEN_TINT, sheen_intensity(t))`
`sun_light_energy(t) = BASE_SUN_ENERGY × (1.0 + WATERING_SUN_ENERGY_BOOST × sheen_intensity(t))`

Applied as a tween on the substrate sprite's `self_modulate` (same tween
mechanism as the STALLED cue tint above) plus a tween on the existing
ambient "sun" `Light2D`'s `energy` property (Visual/Audio Requirements —
the light already used for rim-light on wet leaves and the glass jar's
highlight band) — **no new `Light2D` node is created for this cue**,
unlike Discovery Surfacing's four categories. Both tweens follow the
shared kill-and-restart retrigger policy (Snap-back/Wobble Timing
above) — see Edge Cases.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| t | — | float | 0.0–D_water | seconds elapsed since `apply_watering()` fired (reset to 0 on retrigger — see Edge Cases) |
| D_water | — | float | constant, 3.0 (seconds) | shared directly with `ambient-audio.md`'s `WATERING_SWELL_DURATION` — registered in `entities.yaml` now that a second document depends on it |
| sheen_intensity | — | float | 0.0–1.0 | normalized envelope output, reused from `ambient-audio.md`'s `envelope(t, D)` |
| WATERING_SHEEN_TINT | — | Color | constant, `(0.74, 0.78, 0.83, 1.0)` | darker, faintly cool-shifted multiply tint — the real physical response of wet soil/moss darkening and gaining a faint sheen, the same "would it still make physical sense" test the STALLED tint above already passes |
| BASE_SUN_ENERGY | — | float | asset-authored constant (Visual/Audio Requirements) | the ambient sun `Light2D`'s already-authored steady-state energy — not newly introduced by this formula, only referenced |
| WATERING_SUN_ENERGY_BOOST | — | float | constant, 0.35 | peak fractional energy increase during the swell's hold phase (a 35% brighten at peak) |

**Output Range:** `substrate_modulate` interpolates strictly between
`Color(1,1,1,1)` and `WATERING_SHEEN_TINT` — same bounding convention as
the STALLED tint. `sun_light_energy` interpolates strictly between
`BASE_SUN_ENERGY` and `BASE_SUN_ENERGY × 1.35`, never below baseline —
this cue only ever briefly brightens the sun light, it never dims it.
**Example:** `D_water=3.0` → rise = 0.5s (`0` to `D_water/6`), hold =
1.0s (`D_water/6` to `D_water/2`), fall = 1.5s (`D_water/2` to
`D_water`). At `t=1.0` (hold-phase midpoint): `sheen_intensity=1.0` →
`substrate_modulate=(0.74,0.78,0.83,1.0)` exactly,
`sun_light_energy = BASE_SUN_ENERGY × 1.35`. At `t=0.25` (rise-phase
midpoint): `sheen_intensity = sin(0.5 × π/2) ≈ 0.707` →
`substrate_modulate ≈ lerp(white, tint, 0.707)`,
`sun_light_energy ≈ BASE_SUN_ENERGY × 1.247`.

## Edge Cases

- **If Object Placement's snap-back distance is effectively 0**:
  reachable, not structurally impossible. **Corrected this review
  (`creative-director` ruling on a `systems-designer` finding)**: the
  prior claim conflated two different quantities — Input Abstraction's
  `threshold_mouse`/`threshold_touch` (8px/16px, logical pixels) gate
  *entering* a drag, but the Snap-back formula's `distance` is the
  *release*-time gap (jar-space units) between the HELD `visual_pos` at
  `drag_end` and the last committed position. A player can clear the
  entry threshold, then drag back near the original spot before
  releasing — release distance can land near 0 regardless of the entry
  threshold, and the two quantities aren't even the same unit. No special
  handling is actually needed, though: the formula itself is
  non-degenerate at `distance=0` — `duration = clamp(0.18, 0.18, 0.45) =
  0.18s`, the lower bound — so this case doesn't need defending against,
  it just needed its own reasoning corrected rather than dismissed as
  unreachable. See AC47, also corrected.
- **If a wobble or snap-back tween is retriggered before the current one
  finishes** (e.g. rapid repeated taps/drags on the same object): the new
  tween replaces the in-progress one, starting from its live interpolated
  value (kill and restart, never queued) — queuing would let a burst of
  taps produce an unbounded backlog of pending wobbles, drifting toward
  the exact "reads as nagging UI feedback" failure mode the Anti-Pillar
  warns against.
- **If Discovery Surfacing's active cue is visible while the day/night
  `CanvasModulate` tint is mid-cycle**: the cue renders on the same
  tinted canvas as everything else — since cues are diegetic light/
  material behavior (per `discovery-surfacing.md`'s own Visual/Audio
  Requirements), tinting them along with the rest of the scene is
  consistent with "the jar is one lit place," not a separate
  always-neutral overlay. No special-casing needed; this is the default
  behavior of a single scene-wide `CanvasModulate`.
- **If a plant type's `visual_stages` sprites are authored with their own
  size/spread progression already baked in** (a future content-authoring
  mistake): the Growth Pattern Scaling transform would double the
  intended growth effect. Not caught by any load-time check (Content
  Data's `definition_validity` cannot inspect sprite content) — this is
  an authoring-convention risk, not a runtime bug: `visual_stages`
  sprites must be authored at their final per-stage silhouette, with this
  system's transform as the *only* source of continuous size change
  between stages.
- **If a PlantTypeDef has `max_stage = 0`** (a single-entry
  `visual_stages` list — rejected at load per Content Data's own Edge
  Cases, so unreachable in practice): the Growth Pattern Scaling
  formula's `p = (max_stage == 0) ? 1.0 : ...` guard renders such a plant
  at full authored scale rather than dividing by zero — defensive against
  a case Content Data already guarantees can't occur, not a live gap.
- **If Content Data excludes a type at load time, or a type's
  `visual_ref`/`visual_stages` is missing**: not a case this system needs
  to defend against — Content Data's own load-time validity check
  guarantees every type reaching this system has a non-empty
  `visual_ref`/`visual_stages` (rejected otherwise; no fallback/
  placeholder asset exists at MVP) — mirrors the same upstream-guarantee
  pattern already established in `discovery-surfacing.md` and
  `creature-behavior.md`.
- **If `stalled` flips rapidly** (e.g., repeated watering taps in quick
  succession near a plant's `moisture_tolerance` boundary): same
  retrigger policy as the snap-back/wobble tweens (Core Rule 6) — the
  `self_modulate` tween kills and restarts from its live interpolated
  color, never queued, so a burst of flips never produces a backlog of
  pending color animations.
- **If a plant is both DORMANT (`growth_stage == 0`, Ecosystem
  Simulation) and STALLED (`moisture_ok AND NOT light_ok`,
  Core Rule 3) at the same time**: both render simultaneously and
  independently — the `growth_stage == 0` asset from `visual_stages`
  (Core Rule 2) plus the desaturation tint from Core Rule 3 layered on
  top via `self_modulate`. These are independent signals (asset
  selection vs. color modulation), not a conflict to resolve — a
  DORMANT-and-STALLED plant simply looks like its most-decayed sprite,
  dimmed.
- **If a second `apply_watering()` fires while a Watering Substrate
  Sheen swell is already mid-flight** (before `D_water=3.0s` elapses):
  both the substrate tween and the sun-light energy tween retrigger,
  continuing from their live interpolated values (kill-and-restart, same
  policy as Core Rule 6's snap-back/wobble and the STALLED tint above)
  rather than stacking a second simultaneous swell or queuing one to play
  after the first — this is the concrete resolution of
  `tending-input.md`'s "Repeat-tap feedback stacking" Open Question, and
  mirrors `ambient-audio.md`'s own identical ruling for the audio half of
  the same trigger (that document's own retrigger-not-stack policy for
  its watering boost).
- **If Discovery Surfacing's deliberate cue overlap (up to 5 concurrent
  cues at that document's Tuning Knobs' legal extremes — corrected here,
  `discovery-surfacing.md`'s own round-1 correction from "2-3" was never
  propagated to this document until now, flagged in that GDD's
  `/design-review` round 2) coincides with an active snap-back/wobble
  tween and a day/night tint transition, all at once**: no special
  handling needed structurally — these remain independent rendering
  operations (per-element cues, a per-object tween, one scene-wide
  multiply tint) — but the budget claim below is **not yet verified**
  against the corrected figure. **Needs profiling** (per
  `discovery-surfacing.md`'s own Open Question 3 and named
  `/smoke-check` gate before this system's cue-rendering implementation
  story is marked Done), not assumed — do not treat "stays within
  budget" as confirmed until that profiling pass runs against 5
  concurrent cues plus the tween/tint, not the stale 2-3 figure this
  bullet previously assumed (see Tuning Knobs / Acceptance Criteria for
  the specific budget check).

## Dependencies

Diorama Rendering depends on:
- **Content Data** (hard) — `visual_stages`/`visual_ref`/`growth_pattern`
  per type, plus `moisture_tolerance_min/max`/`light_tolerance_min/max`
  (needed for the STALLED cue)
- **Object Placement** (hard) — committed/live `visual_pos`, HELD state,
  `drag_end` outcome (commit vs. revert)
- **Ecosystem Simulation** (hard) — `growth_stage`, `jar_moisture`, and
  `light_level` per plant instance/jar (the latter two drive the
  mandated STALLED cue — a hard blocking dependency per that GDD's own
  round-13/14 review, not merely indirect)
- **Creature Behavior** (hard) — live position and PRESENT/ABSENT state
  per creature
- **Time & Drift** (hard) — `day_night_phase` for the cosmetic ambient
  lighting shift
- **Discovery Surfacing** (hard) — the active discovery item(s) (category,
  target element/position), **and, added this review, a Growth item's
  recorded `{from, to}` stage values** — needed by Core Rule 2a's
  Catch-up Growth Reveal, which reads this rather than tracking its own
  growth-stage history (preserving Core Rule 1's pure read-only
  guarantee)
- **Tending Input** (soft, added 2026-08-09) — the `apply_watering()`
  trigger event, for Core Rule 11's Watering Substrate Sheen; mirrors
  `ambient-audio.md`'s own identical soft dependency on the same trigger

**Persistence/Save** (indirect, not a direct dependency) — this system
never reads the save blob itself; it renders whatever state the other six
upstream systems already resolved after Persistence/Save restores them,
same pattern as `object-placement.md`'s own downstream position data. No
new dependency edge needed on Persistence/Save's own side.

Diorama Rendering has **no downstream dependents** — confirmed leaf
system by `systems-index.md`.

**Bidirectionality**: all 6 hard upstream dependencies now correctly
reciprocate this system in their own Dependencies sections, including 3
companion edits made alongside this GDD's own authoring (2026-08-05):
`content-data.md`'s Diorama Rendering row was stale ("remains
unauthored") and missing the tolerance fields — corrected;
`ecosystem-simulation.md`'s row listed `light_level` but not
`jar_moisture`, even though the mandated STALLED cue needs both together
— corrected; `time-drift.md` didn't list Diorama Rendering at all despite
`day_night_phase` existing entirely for it — added. **A 7th, soft
dependency was added 2026-08-09** (Tending Input, Core Rule 11) —
reciprocated in `tending-input.md`'s own Interactions/Dependencies
sections the same pass, which also corrected that document's stale "no
downstream dependents" claim (it had already been inaccurate since
`ambient-audio.md`'s own authoring added an identical soft dependency on
the same trigger, just never propagated back).

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `SNAP_BASE_DURATION`/`SNAP_MAX_DURATION` | 0.15–0.6s | Reads as an instant pop/glitch, undercuts the "settling under weight" feel | Reads as sluggish — undercuts the game's calm-but-responsive tending feel |
| `WOBBLE_DURATION`/`WOBBLE_ANGLE_DEG` | duration 0.2–0.5s, angle 2–8° | Too subtle to register as feedback — reintroduces the exact touch/mouse silent-feedback gap `object-placement.md` Core Rule 7 exists to close | Reads as an exaggerated shake/comic bounce — risks the wobble misreading as a rejection, violating the locked "playful, never rejecting" emotional register |
| `STALLED_TRANSITION_DURATION` | 0.3–1.2s | Flickers if `stalled` toggles near a moisture boundary during repeated watering | Feels laggy/unresponsive to a watering action, undercutting the cue's whole legibility purpose |
| `STALLED_TINT` desaturation floor (per channel) | ≥0.4 | Too subtle to distinguish from full color — defeats the entire point of the mandated cue (the exact "can't tell working-as-intended from broken" failure `ecosystem-simulation.md` requires this to fix) | **Corrected this review**: the risk is not "reads as an error/broken state" (that was UI-affordance reasoning for the old flat grey-blue tint) — it's that pushing saturation too low or the hue too far from a believable etiolation pale-yellow-green stops reading as a real plant material response and starts reading as an arbitrary color filter, failing this document's own "would it still make physical sense" test from the other direction |
| `DAY_NIGHT_GRADIENT` night-stop channel floor | ≥0.4 | Below ~0.4 starts reading as unreadable near-black, breaking the gradient's own "never full blackout" design goal | No meaningful ceiling risk — a higher floor just narrows the day/night contrast, a taste call for `art-director` |
| `growth_pattern` `MIN_X`/`MIN_Y` floors | 0.2–0.9, **and per-axis divergence (`|MIN_X - MIN_Y|`) must not exceed 0.30 (added this review, see Formulas' Growth Pattern Scaling)** | Too close to 0 makes the smallest growth stage nearly invisible — could misread as a missing/broken asset rather than an early-growth stage | Too close to 1.0 makes growth barely perceptible across stages, defeating the point of the transform. **A per-axis divergence beyond 0.30 additionally risks visibly warping the baked-in shadow shape** (`technical-artist` finding) — silhouette differentiation beyond that cap belongs in authored per-stage sprites, not a larger non-uniform scale |
| `WATERING_SHEEN_TINT` darkening floor (per channel, added 2026-08-09) | ≥0.5 | Too subtle to read as "just watered," undercutting the cue's whole purpose (mirrors `STALLED_TINT`'s floor risk above) | Reads as a discolored/dirty substrate rather than a wet one, failing the same "physically plausible" test `STALLED_TINT` is held to |
| `WATERING_SUN_ENERGY_BOOST` (added 2026-08-09) | 0.15–0.6 | Too subtle to register alongside the substrate darkening, especially under a bright midday `DAY_NIGHT_GRADIENT` stop | Overpowers the ambient sun light's steady-state role, risks misreading as a Discovery Detail Event bloom (a rarer, different cue) instead of routine watering feedback |

## Visual/Audio Requirements

**Scene composition and the diorama illusion.** The jar-space ellipse
math (`object-placement.md`) already gives every element a back-to-front
coordinate — render order is simply that same coordinate used as
Y-sort/z-index order, no separate depth system needed. The "angled
diorama" read comes from three cheap 2D techniques layered on top: (1)
tight camera framing — the jar fills nearly the whole viewport, glass rim
slightly cropped at top/edges like a close macro shot, never a wide
establishing shot with visible surrounding table/background; (2) a
static full-screen vignette sprite (radial alpha gradient, one draw call)
as a **composition** device — pulling the eye toward jar center, same
technique many real macro photographs use — layered on top of, not
substituting for, actual depth-of-field treatment; (3) **depth of field
delivered by asset authoring, not a runtime effect (corrected this
review, `creative-director` ruling on a `technical-artist` finding —
struck the prior "vignette... standing in for depth-of-field" claim: a
vignette darkens edges, it doesn't blur anything, and claiming
equivalence to the locked Visual Identity Anchor's "shallow depth of
field" principle was false)**: far-plane elements (background substrate,
rear-of-jar dressing) are painted with softened edges, reduced
micro-contrast, and slightly lowered saturation relative to the sharp
mid-plane "hero row" the camera is framed on — the same baked-authoring
discipline this document already uses for lighting, applied to focus
falloff instead. Zero runtime cost, and it actually delivers the
locked principle rather than approximating it with a cheaper substitute;
(4) scale
intimacy enforced at the *asset-authoring* level, not the render level —
every sprite (dirt granules, moss fibers, glass grain) is painted
assuming the player is permanently at this fixed macro zoom (no zoom
controls exist), so detail density rewards close inspection per Pillar 4
rather than only reading correctly from a pulled-back camera.

**Lighting and material approach (honest MVP scoping).** True per-pixel
dynamic lighting across the whole scene is not achievable cheaply in
Compatibility/WebGL2 and shouldn't be attempted — the primary technique
is **baked light**: every `visual_stages` sprite is hand-painted with a
consistent directional light+shadow already in the texture (light from
upper-left, matching macro-photography convention), so "physically lit"
is an art-authoring discipline, not a runtime lighting system. On top of
that, a small number (1–3, budget-capped) of real ambient-accent
`Light2D` nodes are used for moments where reactive specular actually
matters: a soft warm "sun" `Light2D` used for rim-light on wet leaves and
the glass jar's highlight band. **Direction corrected this review
(`creative-director` ruling on a `technical-artist` finding)**: this
light's **direction is fixed**, matching the baked upper-left key light
exactly — only its **color/intensity** track the day/night gradient
(warming toward dawn/dusk, cooling toward night, same palette as
`DAY_NIGHT_GRADIENT`). The prior version let this light's *direction*
track day/night, which would visibly contradict every sprite's
permanently-fixed baked shadow as the light swept across the sky —
color/intensity drift alone delivers the "reactive to time of day" effect
this light exists for without that contradiction. Normal maps are
reserved for the two or three hero materials where the payoff is highest
— the glass jar surface and visibly wet/moist surfaces — not applied
blanket-wide. **This same ambient sun `Light2D` also carries the
Watering Substrate Sheen cue's specular half (Core Rule 11, added
2026-08-09)** — a brief `energy` boost during the 3-second watering
swell, timed identically to Ambient Audio's own watering swell — rather
than a dedicated new light, keeping that cue's cost at effectively zero
against the `Light2D` budget tracked below.

**Discovery Surfacing cue mechanism, stated explicitly (added this
review — was previously an unstated gap, `gameplay-programmer` finding;
resolution below per user decision)**: all 4 of Discovery Surfacing's
diegetic cue categories (Growth's subsurface glow, Arrival's specular
catch-light, Departure's ambient settle, Detail Event's point-light
bloom) are realized as **real, individually-instantiated `Light2D`
nodes** — brief-lived, created when the cue activates and freed when it
fades — never a flat additive decal sprite. This is the honest reading
of this document's own corrective test ("if you removed the glow, would
the underlying lighting/material still make physical sense? A pure
additive sprite/decal fails this test") — a decal that doesn't actually
interact with the material fails that test by construction, so all four
categories need a real light, not just some of them. **Budget
consequence, stated explicitly**: these cue-driven lights are
**additive to**, not included in, the "1–3, budget-capped" ambient-accent
figure above — with Discovery Surfacing's own corrected Tuning Knobs
allowing up to 5 concurrent cues, the true worst-case concurrent
`Light2D` count is **1–3 ambient + up to 5 cue-driven = up to 8**. This
is the real number Open Question 1's verification test and the
draw-call budget check (Budget Allocation, below) must both budget
against — see Open Questions.

**Creatures and objects.** Snail and Moth need instant silhouette
legibility against the jar's green/brown palette, since they're the one
element that moves live every frame (Core Rule 5) and can't rely on
Discovery-style attention cues to be noticed — give each a deliberate
small value/hue contrast against its typical surroundings (e.g. a warmer
terracotta shell against green moss for Snail; a paler wing value against
dark leaf-shadow for Moth). Material treatment follows the same
baked-light convention as plants; Moth's wings are the one candidate for
a subtle normal-map/`Light2D` rim pass, since thin translucent material is
where dynamic backlight reads best. The Rock (the MVP's one repositionable
object) renders matte and diffuse with baked AO in its crevices and
minimal specular — a deliberate material contrast against the glass and
wet substrate, so the eye separates "dry moveable object" from
"glass/moisture" categories on sight, reinforcing visual hierarchy
through material language rather than outline alone.

**The jar itself.** The glass is the highest-value asset in the whole
scene — it's the outermost frame present in every single screenshot.
Render it as a hand-authored semi-transparent overlay sprite with baked
specular rim bands and a painted (not shader-computed) refraction
distortion, rather than true screen-space refraction — safer on
Compatibility/WebGL2 and visually sufficient at this scale. The glass
overlay passes through the same day/night `CanvasModulate` tint as
everything else (Core Rule 8), which is what actually sells it as "one
lit place" rather than a static prop. Substrate/dirt is matte with high
apparent micro-detail (visible granule/pebble texture at the target zoom)
and a baked, static moisture-darkening variation near damp-reading areas
— no new dynamic per-region moisture-render system is needed; Ecosystem
Simulation only tracks moisture at jar level, and a per-region system
would exceed this GDD's scope. **The Watering Substrate Sheen cue's tween
(Core Rule 11/Formulas, added 2026-08-09) is a separate, jar-wide
`self_modulate` shift layered on top of this baked static variation, not
a replacement for it or a new per-region system** — it stays a single
uniform tint precisely because Ecosystem Simulation only tracks moisture
at jar level, the same scope limit stated in the sentence above; it does
not reopen that decision. Any moss/wood dressing follows the same
baked-light convention: moss slightly more saturated with baked crevice
AO to read "alive/damp," wood matte with visible grain at macro scale.

**Budget allocation.** This is a single small jar with a handful of
elements, not an open world — spend the ≤500 draw call budget generously
rather than economizing preemptively. Worth spending on: the glass
overlay (its own hero-quality asset), the ambient accent lighting, and
per-sprite texture/paint quality for the small plant/creature/object
roster (fewer total assets than a game with a large cast means each one
can carry more painted detail). Already effectively free and shouldn't be
second-guessed: the STALLED tint, day/night `CanvasModulate`, snap-back/
wobble tweens, and growth-pattern scale transform (all confirmed cheap in
the Formulas section above). Cut without hesitation: no real-time
per-pixel lighting scene-wide, no screen-space blur/refraction shaders,
no growth-stage cross-fades (already ruled out structurally by Core Rule
2), and no particle/weather VFX unless a future GDD specifically calls
for one.

**Worst-case concurrent overlap — corrected this review, no longer a
confidence claim (`performance-analyst`/`qa-lead` finding, `creative-
director` ruling):** the prior version of this paragraph asserted the
worst-case simultaneous overlap named in Edge Cases "stays far under the
draw-call ceiling" — this directly contradicted Edge Cases' own
"not yet verified... do not treat as confirmed" language about the exact
same scenario, and unlike every Formula in this document, that claim had
zero supporting arithmetic anywhere. **Struck.** The true worst case is
now stated precisely rather than asserted away: up to 8 concurrent
`Light2D` nodes (1–3 ambient + up to 5 cue-driven, see Visual/Audio
Requirements above) plus one active object tween plus a mid-cycle
day/night transition, all simultaneously. Whether this stays within
budget is genuinely unknown until Open Question 1's verification pass
and the named `/smoke-check` (Open Questions) both run — see the new
Acceptance Criterion added this review that actually gates this.

*(`art-director` consulted — Visual/Audio Requirements is mandatory for
this system's category regardless of review mode. No art bible exists
yet — this section's treatments are flagged as candidate first entries
for it, same pattern as `discovery-surfacing.md`'s own Visual/Audio
Requirements.)*

## UI Requirements

None. This system renders the world scene itself — no menu, HUD, panel,
or screen. Every player-facing surface it produces is diegetic (the jar
and everything in it), covered entirely under Visual/Audio Requirements.

## Acceptance Criteria

### Core Rules

**CR1 — Pure read-only observer**
1. GIVEN a frozen/read-only snapshot of all upstream state (Content Data,
   Object Placement, Ecosystem Simulation, Creature Behavior, Time &
   Drift, Discovery Surfacing) passed into one render pass, WHEN the pass
   executes, THEN no upstream object is mutated (post-render
   deep-equality against a pre-render copy holds) and no upstream write
   method is invoked. *(Requires a spy/mock harness over the upstream
   interfaces to assert — a design decision for implementation, not this
   GDD.)*

**CR2 — Discrete stage rendering, no cross-fade**
2. GIVEN a plant with `growth_stage=3` unchanged from the prior frame,
   WHEN it renders, THEN the sprite reference equals `visual_stages[3]`
   exactly and no Tween/AnimationPlayer is started for the swap.
3. **(narrowed this review — see CR2a for the changed-stage case, now
   covered by the Catch-up Growth Reveal instead of this criterion)**
   GIVEN a plant with NO active Growth discovery item this session
   (`growth_stage` unchanged since it was last rendered, or no prior
   session exists), WHEN it renders, THEN the sprite reference equals
   `visual_stages[growth_stage]` exactly with zero interpolation time
   elapsed — this criterion no longer covers the changed-stage case.

**CR2a — Catch-up Growth Reveal (new this review)**
3a. GIVEN a plant WITH an active Growth discovery item this session
   (`{from: 2, to: 3}`), WHEN the session's first frame for that plant
   renders, THEN the sprite reference still equals `visual_stages[2]`
   (the `from` stage) — confirming the sprite has NOT yet swapped on
   frame one, only the scale transform has begun its reveal.
3b. GIVEN the same setup, WHEN `reveal_t` reaches exactly `0.5`, THEN the
   sprite reference switches to `visual_stages[3]` (the `to` stage) on
   that exact frame — never earlier, never later.
3c. GIVEN the same setup, WHEN `reveal_t` reaches `1.0`
   (`CATCHUP_REVEAL_DURATION` elapsed), THEN `scale_x`/`scale_y` equal
   exactly the values Growth Pattern Scaling's steady-state formula
   would produce for `growth_stage=3` — the reveal converges to, and
   never overshoots past, the correct terminal value.
3d. GIVEN the same setup, WHEN `p_from` and `p_to` are computed at the
   reveal's start, THEN both are derived from already-resolved,
   non-default data (Discovery Surfacing's own recorded `from`/`to`) —
   confirming this does not reopen Core Rule 9's data guarantee, since
   no placeholder or default value is ever animated through.

**CR3 — Mandated STALLED cue**
4. GIVEN a plant already tinted `STALLED_TINT` (`moisture_ok=true,
   light_ok=false`) and `jar_moisture` then changes so `moisture_ok`
   stays true and `light_ok` stays false, with no simulation tick run,
   WHEN the next frame renders, THEN `stalled` remains `true` and tint is
   unaffected — proving the check runs every frame, not gated on a tick.
5. GIVEN `moisture_ok=false, light_ok=true` (DECAYING via moisture, not
   STALLED), WHEN evaluated, THEN `stalled=false` and `self_modulate`
   targets full color — proving the cue does NOT fire for the
   moisture-decay case, only the exact STALLED condition.

**CR4 — Repositionable object position**
6. GIVEN an object reported HELD with `visual_pos=(x,y)`, WHEN rendered,
   THEN rendered position equals `visual_pos` exactly, no smoothing added.
7. GIVEN the same object not HELD at committed `(cx,cy)`, WHEN rendered,
   THEN rendered position equals the committed position exactly.

**CR5 — Live creature position**
8. GIVEN a creature PRESENT at `P_n` then `P_(n+1)` across two frames,
   WHEN both render, THEN each frame's rendered position equals the
   supplied position exactly, with no rendering-side
   interpolation/prediction between them.

**CR6 — Eased tweens, never instant**
9. GIVEN a snap-back or wobble trigger fires, WHEN the tween is created,
   THEN duration > 0 and the transition type is non-linear/non-instant
   (`TRANS_CUBIC`/`EASE_OUT` for snap-back; sine pulse for wobble) — an
   instant `duration==0` set never occurs.

**CR7 — Discovery cue execution**
10. GIVEN Discovery Surfacing reports one active cue (category C), WHEN
    rendered, THEN its motion profile matches `discovery-surfacing.md`'s
    locked parameters exactly (ease-in→hold→ease-out present, zero
    looping iterations). *(This criterion cross-checks against values
    owned and independently tested by `discovery-surfacing.md`'s own
    suite — it verifies this system correctly consumes that spec, not a
    re-derivation of the values themselves.)*
10a. **(new this review, `qa-lead` finding)** GIVEN an active Discovery
    cue's `Light2D` node, WHEN the scene tree is inspected, THEN it is
    parented under (or otherwise subject to) the same `CanvasModulate`
    node as every other scene element — confirming cues share the
    day/night tint rather than rendering on a separate always-neutral
    layer (asserted on scene-tree structure, not pixel output).
10b. **(new this review, `qa-lead` finding — the flagged-unverified
    budget claim previously had zero AC coverage, contradicting this
    document's own stated `/smoke-check` gate)** GIVEN up to 5 concurrent
    Discovery cues (each a real `Light2D` per Visual/Audio Requirements)
    + 1–3 ambient accent `Light2D` nodes + 1 active object tween
    (snap-back or wobble) + a mid-transition day/night tint, all
    rendering simultaneously, WHEN the named `/smoke-check` (Open
    Questions) profiles this frame, THEN draw calls stay ≤500 and frame
    time stays ≤16.6ms — this is the actual gate Edge Cases and Budget
    Allocation both reference, now enforceable rather than merely
    promised. **(Config/Data type, ADVISORY per this project's Testing
    Standards — gated by the named smoke check, not a unit test.)**

**CR8 — Day/night never gated**
11. GIVEN `day_night_phase` changes while a snap-back tween, wobble
    tween, and Discovery cue are all simultaneously active, WHEN the
    frame renders, THEN `canvas_modulate_color` updates per the formula
    that frame regardless of the other concurrent effects.

**CR9 — Fully-resolved first frame**
12. GIVEN Persistence/Save restore and Time & Drift's catch-up batch have
    completed, WHEN the scene's first frame renders, THEN every
    element's data state (stage indices, positions, tints) already
    equals the fully-resolved post-catch-up values — no frame exists
    showing pre-catch-up/default data. **(Logic, BLOCKING.)**
12a. *(Visual/Feel, ADVISORY — screenshot/manual check per
    coding-standards.md's exclusion of visual fidelity from automation)*
    GIVEN the same setup, WHEN the first frame is observed, THEN no
    loading spinner, placeholder state, or visible "assembling the jar"
    pop-in is shown.

**CR10 — growth_pattern silhouette treatment**
13. **(values corrected this review — see Formulas)** GIVEN three plants
    (same `max_stage`, same `growth_stage`) with `growth_pattern` =
    carpet/clump/climb respectively, WHEN Growth Pattern Scaling applies,
    THEN carpet's `scale_x==scale_y` throughout, clump's `scale_y` floor
    (0.40) is lower than its `scale_x` floor (0.55), and climb's
    `scale_x` floor (0.75) stays higher than its `scale_y` floor (0.45)
    — the three patterns produce distinguishable per-axis curves, each
    within the ≤0.30 per-axis divergence cap.

**CR11 — Watering Substrate Sheen (new 2026-08-09)**
13a. GIVEN Tending Input's `apply_watering()` fires, WHEN the same frame
    renders, THEN `sheen_intensity(t)` begins evaluating at `t=0` that
    same frame — no deferred start, mirroring `ambient-audio.md`'s own
    same-frame trigger guarantee (that document's Core Rule 3/AC3).
13b. GIVEN `sheen_intensity(t)` at its hold-phase plateau (`t` between
    `D_water/6` and `D_water/2`), WHEN evaluated, THEN
    `sheen_intensity(t)=1.0` exactly, `substrate_modulate` equals
    `WATERING_SHEEN_TINT` exactly, and `sun_light_energy =
    BASE_SUN_ENERGY × 1.35` exactly.
13c. GIVEN `sheen_intensity(t)=0.0` (before any trigger, or after a swell
    fully completes with no retrigger), WHEN evaluated, THEN
    `substrate_modulate=(1,1,1,1)` and `sun_light_energy =
    BASE_SUN_ENERGY` (no boost active).
13d. GIVEN the scene tree is inspected during an active watering swell,
    WHEN checked, THEN no new `Light2D` node exists for this cue — only
    the pre-existing ambient sun `Light2D`'s `energy` property differs
    from its steady-state value — confirming this cue adds zero nodes to
    the worst-case concurrent `Light2D` count tracked elsewhere in this
    document (Visual/Audio Requirements, Open Question 1). *(Asserted on
    scene-tree structure, not pixel output — same pattern as CR7's
    10a.)*
13e. GIVEN a second `apply_watering()` fires while a swell is already
    mid-flight (`0 < t1 < D_water`), WHEN the new trigger processes,
    THEN both the substrate tween and the sun-light energy tween
    continue from their live interpolated levels (never resetting to 0/
    `BASE_SUN_ENERGY` first) and only one swell instance ever exists —
    never two concurrent, never queued. This is the concrete resolution
    of `tending-input.md`'s "Repeat-tap feedback stacking" Open
    Question.

### Formulas

**STALLED Cue Tint**
14. **(value corrected this review — see Formulas)** GIVEN
    `moisture_ok=true, light_ok=false`, WHEN evaluated, THEN
    `stalled=true`, `target_modulate=(0.88,0.90,0.62,1.0)`.
15. GIVEN `moisture_ok=true, light_ok=true`, WHEN evaluated, THEN
    `stalled=false`, `target_modulate=(1,1,1,1)`.
16. GIVEN `moisture_ok=false, light_ok=false`, WHEN evaluated, THEN
    `stalled=false` (only `moisture_ok AND NOT light_ok` qualifies).
17. GIVEN `moisture_ok=false, light_ok=true`, WHEN evaluated, THEN
    `stalled=false`.
18. GIVEN `jar_moisture` exactly equal to `moisture_tolerance_min` or
    `moisture_tolerance_max`, WHEN `moisture_ok` is computed, THEN it is
    `true` (boundary inclusive).
18a. **(new this review, `qa-lead` finding — mirrors AC18, previously
    untested for `light_ok`)** GIVEN `light_level` exactly equal to
    `light_tolerance_min` or `light_tolerance_max`, WHEN `light_ok` is
    computed, THEN it is `true` (boundary inclusive, same rule as
    `moisture_ok`).
19. GIVEN a stalled transition fires, WHEN the tween runs, THEN it uses
    `TRANS_SINE`/`EASE_IN_OUT` over exactly 0.6s, and `self_modulate`
    never exceeds `(1,1,1,1)` nor falls below `STALLED_TINT` at any
    sampled point.
20. GIVEN Fern (`jar_moisture=70`, `light_level=25`, tolerances per this
    doc's worked example), WHEN evaluated, THEN `stalled=true`.

**Snap-back / Wobble Timing**
21. GIVEN `distance=120`, WHEN duration is computed, THEN
    `duration=0.348s`.
22. GIVEN `distance=300` (exceeds jar diameter), WHEN computed, THEN
    duration clamps to `0.45s` exactly.
23. GIVEN `distance` at the theoretical minimum (0), WHEN computed, THEN
    duration clamps to `0.18s` (lower bound holds even at a
    zero-distance input).
24. GIVEN wobble `t=0` and `t=WOBBLE_DURATION` (0.30), WHEN angle is
    computed, THEN `angle=0°` at both endpoints.
25. GIVEN wobble `t=0.15`, WHEN computed, THEN `angle=4.0°` (peak).
26. GIVEN a wobble tween sampled at any `t∈[0,0.30]`, WHEN checked, THEN
    position and scale are unchanged — only rotation varies.
26a. **(new this review, `qa-lead` finding — the kill-and-restart policy
    was previously tested only for the STALLED tint, AC44/45, not for
    position/rotation tweens)** GIVEN a snap-back or wobble tween
    mid-interpolation, WHEN a new trigger fires (a re-tap, or a new
    `drag_end` revert) before it completes, THEN the new tween starts
    from the live interpolated position/rotation value (not from either
    endpoint) and the prior tween is killed — never two concurrent tweens
    driving the same object's position or rotation, never queued.

**Day/Night Lighting Curve**
27. GIVEN `cycle_duration_seconds=1200, session_elapsed_seconds=900`,
    WHEN `t` is computed, THEN `t=0.5`.
28. GIVEN `day_night_phase=0.0`, WHEN computed, THEN `t=1.0` (solar peak).
29. GIVEN `day_night_phase=0.5`, WHEN computed, THEN `t=0.0` (deepest
    night).
30. GIVEN `day_night_phase=0.999` and `0.001` (either side of the
    sawtooth wrap), WHEN `t` is computed for both, THEN the two values
    differ by <0.01 — no pop across the wrap.
31. GIVEN `t=1.0` and `t=0.0`, WHEN the gradient is sampled, THEN
    `canvas_modulate_color` equals `(1.00,1.00,1.00)` and
    `(0.50,0.58,0.80)` respectively (exact stop values).

**Growth Pattern Scaling**
32. GIVEN `growth_stage=3, max_stage=6, growth_pattern=clump`, WHEN scale
    is computed, THEN `scale_x=0.775, scale_y=0.70`.
33. GIVEN `growth_stage==max_stage` (any pattern), WHEN computed, THEN
    `scale_x=scale_y=1.0` exactly.
34. **(values corrected this review — see Formulas)** GIVEN
    `growth_stage=0` for carpet/climb, WHEN computed, THEN
    `scale_x=scale_y=0.35` (carpet, uniform) vs. `scale_x=0.75,
    scale_y=0.45` (climb, footprint grows less than height).
35. GIVEN `max_stage=0`, WHEN `p` is computed, THEN `p=1.0` via the guard
    clause (no division-by-zero) — testable as pure math regardless of
    Content Data's own load-time rejection of this case.
36. GIVEN the scale transform is applied, WHEN inspected, THEN the
    `Node2D` pivot/offset used is the plant's base point, not sprite
    center (asserted on transform configuration, not pixels).

### States and Transitions

37. GIVEN SETTLED, WHEN Object Placement reports HELD, THEN state →
    FOLLOWING, rendering live `visual_pos` every frame.
38. GIVEN FOLLOWING, WHEN `drag_end` commits, THEN state → SETTLED at the
    new committed position.
39. GIVEN FOLLOWING, WHEN `drag_end` reverts (invalid/canceled), THEN
    state → SNAPPING_BACK, tween starts from the held position to the
    last committed position.
40. GIVEN SNAPPING_BACK, WHEN the tween completes, THEN state → SETTLED.
41. GIVEN SETTLED, WHEN a tap lands on the object's footprint, THEN state
    → WOBBLING, non-committal tween starts.
42. GIVEN WOBBLING, WHEN the tween completes, THEN state → SETTLED.
43. GIVEN FOLLOWING with no `drag_end` reported yet, WHEN intervening
    frames render, THEN state remains FOLLOWING (no premature
    transition).

### Edge Cases

**Rapid STALLED-flip retrigger**
44. GIVEN a `self_modulate` tween mid-interpolation at color `C_mid`,
    WHEN `stalled` flips before the tween completes, THEN the new tween
    starts from `C_mid` (not from either endpoint) and the old tween is
    killed — never two concurrent tweens on the same sprite.
45. GIVEN `stalled` flips 5 times within <0.6s, WHEN all flips process,
    THEN at most one active `self_modulate` tween exists at any instant
    (no queued backlog).

**DORMANT + STALLED co-occurring**
46. GIVEN `growth_stage=0` (DORMANT) AND `moisture_ok=true,
    light_ok=false` (STALLED) simultaneously, WHEN rendered, THEN sprite
    = `visual_stages[0]` (Core Rule 2) AND `self_modulate` tweens toward
    `STALLED_TINT` (Core Rule 3) — both signals present, neither
    suppresses the other.

**Zero-distance snap-back**
47. **(corrected this review — see Edge Cases)** GIVEN `distance=0`
    (a real, reachable release position per the corrected Edge Case
    above, not a defended-against impossibility), WHEN duration is
    computed, THEN `duration = SNAP_BASE_DURATION` (0.18s) exactly —
    confirming the formula is non-degenerate at the true minimum input,
    not merely at Object Placement's drag-*entry* threshold, which is a
    different quantity in a different unit.

**Missing-asset guarantee from Content Data**
48. GIVEN Content Data's load-time guarantee that every type has a
    non-empty `visual_ref`/`visual_stages`, WHEN Diorama Rendering's
    render step executes for any type instance, THEN no fallback/
    placeholder-asset code path exists to reach (verified by code
    inspection/coverage — zero call sites, not a runtime input/output
    check). *(The underlying guarantee itself is `content-data.md`'s own
    Acceptance Criteria territory — this criterion only confirms this
    system correctly has no dead fallback path.)*

*(`qa-lead` consulted — mandatory for this high-risk section regardless
of review mode. Their review also surfaced that Core Rule 3's evaluation
cadence was unstated — resolved as "every frame," now stated explicitly
in Core Rule 3 above — and flagged 3 criteria (CR7's cue-motion check,
the zero-distance snap-back guarantee, the missing-asset guarantee) as
cross-doc checks bounded to this system's own behavior rather than proof
of guarantees owned elsewhere.)*

## Open Questions

1. **[BLOCKING, escalated this review] Compatibility-renderer 2D lighting
   verification**: no engine-reference doc confirms `Light2D`/normal-map/
   glow behavior on Godot 4.7.1's Compatibility/WebGL2 renderer, and this
   gates the *entire* visual approach — ambient accent lighting, all 4
   Discovery cue categories (now confirmed to require real `Light2D`
   instances, see Visual/Audio Requirements), and the glass jar (this
   document's own "highest-value asset," which specifically pairs a
   normal map with `Light2D` rim-lighting). **Corrected this review
   (`creative-director` ruling on `godot-specialist`/`performance-
   analyst` findings)**: escalated from advisory ("before
   `/architecture-decision`") to blocking — deferring it past this GDD's
   own approval left the entire lighting approach unverified while other
   systems' implementation could proceed as if it were settled. Run an
   explicit throwaway render test (not "WebSearch or" — a test, not just
   a literature check), validated first against the actual jar
   normal-map setup specifically (the highest-value, most load-bearing
   asset), and fold in Godot 4.6's Glow/HDR compositing-order change
   (needed for Detail Event's "point-light bloom" cue, which implies
   Glow). Owner: technical-director/godot-specialist. Target: before
   implementation begins on any `Light2D`-dependent rendering, same
   BLOCKED-gate pattern as `time-drift.md`/`input-abstraction.md`/
   `discovery-surfacing.md`'s shared `visibilitychange` gate. **How this gets
   resolved (added 2026-08-09):** see
   `docs/technical-setup/web-export-verification-plan.md` → Gate C, which
   specifies the render-probe scene and pass/fail criteria for C1
   (`Light2D` + normal map on WebGL2, validated against the real jar asset),
   C2 (whether 2D glow exists at all under Compatibility — flagged there as a
   likely contradiction with this document's "point-light bloom" cue, since
   Godot docs state `rendering/viewport/hdr_2d` only affects Forward+/Mobile),
   C3 (`CanvasModulate` compositing over lit pixels), and C4 (the 8-concurrent-
   `Light2D` worst case against the 16.6ms / ≤500-draw-call budget). Run this
   gate first — it has the widest blast radius of the three. Still unverified —
   nothing has been run.
2. **Held-object visual feedback** (lift/scale/highlight while dragging):
   `object-placement.md`'s own Open Question, still unresolved here —
   Core Rule 4 only specifies live position-follow, no additional
   HELD-state treatment. Owner: art-director. Target: before
   implementation (low priority, nice-to-have).
3. **Departure cue's "residual light disturbance" treatment**:
   `discovery-surfacing.md` already flagged this needs a dedicated
   technical-artist prototype (no direct real-world reference) — inherited
   here since this is the system that implements it. Owner:
   technical-artist. Target: before that cue is implemented.
