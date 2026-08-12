# Creature Behavior

> **Status**: Approved — round 1 blockers resolved, plus a round 2 structural fix from `/review-all-gdds` (accepted without a formal specialist re-review round; user decision, see trailing review notes)
> **Author**: user + ai-programmer
> **Last Updated**: 2026-08-09 (cross-GDD review — new Core Rule 9, reports live position to Ecosystem Simulation every frame, closing a blocking last-known-position gap; see trailing note). Previously 2026-08-05 (round 2 `/review-all-gdds` — Core Rule 8 widened to cover batch-resolved transitions — see trailing note)
> **Implements Pillar**: Pillar 3 (Care, Not Control) — the creature's independent wandering was the prototype's single strongest validated moment
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS — round 1 full specialist review (game-designer, systems-designer, qa-lead, godot-specialist, ai-programmer, creative-director), verdict NEEDS REVISION at time of review; all 3 blockers and 5 recommended items resolved this same pass, text-only (see trailing review note). Post-fix state not re-confirmed by a fresh specialist round, per user's explicit choice to skip re-review.

## Overview

Creature Behavior gives Snail and Moth actual movement once Ecosystem
Simulation marks them PRESENT: simple point-to-point wandering within the
jar's bounds, steering around placed objects (Object Placement's
footprints) rather than passing through them. It owns no spawn/departure
logic of its own — that's Ecosystem Simulation's domain — this system only
decides *how* a present creature moves, never *whether* it's there. For the
player, this is where the whole game's central proof-of-concept lives: the
prototype's single strongest validated moment was watching a creature
appear and wander on its own, reading as "my care created the conditions
for this" rather than a scripted event.

## Player Fantasy

The player never directs Snail or Moth — they simply notice it's there,
watch where it wanders, and over repeat visits start recognizing it as a
small, consistent character rather than a generic sprite. The concept doc
names this explicitly: *"players will start recognizing individual
inhabitants... and treat them as consistent little characters."* The
prototype already proved the emotional core of this — the tester's
strongest reaction in the whole test was the creature's independent
wandering, not because the behavior was clever, but because its *presence
itself* already felt earned by the player's care rather than granted on
demand. This system's entire job is to keep that earned, unscripted
feeling intact through simple, readable movement — not to make the
creature "interesting" through complex AI, since Pillar 3 favors indirect
emergence over direct control, and adding personality through elaborate
behavior risks turning "care, not control" into a separate pet-simulator
mini-game the concept never asked for.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules.)*

## Detailed Design

### Core Rules

1. When Ecosystem Simulation transitions a creature ABSENT→PRESENT,
   Creature Behavior spawns it at a valid starting position within the
   jar's floor ellipse (not overlapping any object footprint).
2. While PRESENT, the creature periodically picks a new random destination
   point within jar bounds (not inside any object footprint) and moves
   toward it at `CreatureTypeDef.movement_speed` (from Content Data) until
   arrival, then pauses briefly before picking a new destination — the
   wandering loop.
3. **Presence is tick-driven; movement is continuous.** Ecosystem
   Simulation's PRESENT/ABSENT state only changes at visit boundaries
   (Time & Drift's batched ticks), but wandering itself runs smoothly every
   frame during an ACTIVE session — a present creature keeps moving
   continuously, it doesn't jump between tick-snapshotted positions.
4. When Ecosystem Simulation transitions PRESENT→ABSENT, the creature does
   not vanish instantly — it plays a brief "wandering off" exit (moves
   toward a jar edge and fades out), consistent with departure always
   reading as the creature "moving on," never a punishment or death event
   (Ecosystem Simulation's own framing).
5. Destination **selection** treats Object Placement's footprints as
   obstacles — a chosen destination is never on or inside an object's
   footprint. The straight-line path *to* that destination does **not**
   additionally steer around objects encountered en route — this is a
   deliberate simplification (extending Core Rule 6 below), acceptable
   because the jar is small and the MVP has only one object, so any
   momentary visual clip near an object's edge is rare and minor.
6. If an object's footprint changes while the creature is already en route
   (the player drags the rock mid-wander), the current path is **not**
   recalculated mid-transit for MVP — the creature finishes its current
   destination; only the *next* destination pick accounts for the object's
   new position. This is a deliberate simplification appropriate to the
   game's low-precision, low-stakes aesthetic, not an oversight.
7. `PRESENT→ABSENT` interrupts **any** active state — SPAWNING, WANDERING,
   or PAUSING all transition directly to DEPARTING, from whatever position
   the creature currently occupies. If `PRESENT→ABSENT` fires while the
   creature is already DEPARTING, it is a no-op — departure is already in
   progress and is not restarted or double-triggered.
8. **Session-start entry point: presents only the state once all
   session-start processing resolves, never an intermediate state, and
   never an animation for a transition the player didn't see happen
   (added 2026-08-04, round 11; widened 2026-08-05 `/review-all-gdds`,
   `game-designer`/`systems-designer` finding, `creative-director`
   ruling).**

   **Original scope (round 11):** a creature restored from a save blob
   (`persistence-save.md`) that is already `state == PRESENT` enters
   **WANDERING directly** at its restored position, with a freshly-sampled
   destination via the normal destination-sampling formula (Formulas
   below) — it does **not** pass through SPAWNING. This exists because
   routing a restored creature through SPAWNING would replay the arrival
   animation for a creature that may have been resident for days,
   producing a false "something new arrived" signal on every single
   session start — directly contradicting this GDD's own Player Fantasy
   ("recognizing individual inhabitants... as consistent little
   characters") and this game's core "notice what changed since last
   visit" read.

   **Scope widened 2026-08-05, closing a gap the round-11 wording left
   open:** Core Rule 3's tick-driven PRESENT/ABSENT state only ever changes
   on a tick, and every tick fires exclusively inside Time & Drift's
   atomic, non-rendering catch-up batch at session start (`time-drift.md`
   Core Rules 5/6, CATCHING_UP state) — never live once that system reaches
   its ACTIVE state. Core Rule 1's SPAWNING entry and Core Rules 4/7's
   DEPARTING exit both specify a real, observable animation (placement, or
   a "moves toward a jar edge and fades out" exit) that cannot complete
   inside a batch the player never sees mid-progress (`time-drift.md`
   AC11: "no intermediate/partial state... is observable... the full batch
   completes before the jar is rendered"). The round-11 wording above only
   covered the *raw* value read directly from the save blob, before any
   catch-up ticks run — it left undefined what happens when the catch-up
   batch *itself* flips a creature's state one or more times (e.g., a
   creature restored ABSENT that spawns partway through the batch, or one
   restored PRESENT that departs partway through). Read literally, the
   round-11 wording would route such a mid-batch transition through Core
   Rule 1 or Core Rules 4/7's normal live, animated path instead — which
   cannot execute inside an atomic invisible batch.

   **Unified resolution**: Creature Behavior does not react to any
   Ecosystem Simulation PRESENT/ABSENT transition that fires while Time &
   Drift is in its CATCHING_UP state, no matter how many such transitions
   occur within one catch-up batch. Once Time & Drift transitions
   CATCHING_UP→ACTIVE (the batch complete, the jar about to render for the
   first time this session), Creature Behavior queries each creature's
   now-settled state exactly once: if **PRESENT** — whether because it was
   restored PRESENT and stayed PRESENT throughout the batch (entering at
   its restored position), or because it transitioned ABSENT→PRESENT at
   some point during the batch (entering at the position Core Rule 1's
   SPAWNING placement would have chosen) — the creature enters **WANDERING
   directly**, with a freshly-sampled destination, never passing through a
   visible SPAWNING placement. If **ABSENT** — whether it was restored
   ABSENT and stayed ABSENT throughout, or was PRESENT at some point during
   the batch and departed before the batch completed — no instance is
   spawned and no DEPARTING exit animation plays; the player never saw the
   creature to begin with, so there is nothing to visibly remove. **This
   does not change live, in-session behavior at all**: Core Rule 1's
   SPAWNING and Core Rules 4/7's DEPARTING remain exactly as specified for
   any transition that fires *after* Time & Drift has reached ACTIVE — the
   only case where an animated response is actually observable, and
   therefore still required. This is the only entry point into this state
   machine other than such a live, post-ACTIVE Ecosystem Simulation
   `ABSENT→PRESENT` transition (Core Rule 1).

   The creature's pause timer and prior in-transit destination are **not**
   persisted (only `state` and `position` are, per `persistence-save.md`'s
   Core Rule 1) — entering WANDERING with a fresh destination sample is
   the intentional, cheap resolution to that, not an oversight requiring
   those fields to be saved too. **Departure-while-away ownership
   stated explicitly (added 2026-08-04 `/design-review`, `game-designer`
   finding, `creative-director` ruling):** "the creature simply does not
   exist yet" is correct and complete from *this system's* side, but it is
   not the same as the departure being unframed for the player. Because
   Ecosystem Simulation's ticks batch at visit boundaries (`time-drift.md`),
   a creature departing *while the player was away* is the more common
   departure path — more common than the live, in-session DEPARTING case
   Core Rule 4 already handles with careful "moving on, not punishment"
   framing. That framing is not missing, it is owned elsewhere:
   `ecosystem-simulation.md`'s own Interactions table already tracks
   spawn/departure as a state delta for the not-yet-authored Discovery
   Surfacing system to surface as part of "what changed since last visit."
   Creature Behavior has nothing to render for a creature that is no longer
   PRESENT, so it correctly does nothing here — but this is stated
   explicitly, as a requirement flagged for Discovery Surfacing's own GDD,
   rather than left as a silent absence with no framing anywhere. See
   Dependencies and Open Questions.

9. **Reports live position to Ecosystem Simulation every frame (new
   2026-08-09, `/review-all-gdds` cross-GDD finding).** While this system
   holds a live instance for a creature, it calls
   `set_last_known_position(creature_id, pos')` into Ecosystem Simulation
   every frame — the exact same `pos'` this system's own Movement/arrival
   formula computes that frame (see Formulas). This closes a blocking gap:
   Ecosystem Simulation is the only system whose state persists across a
   session in which a creature never gets a live instance at all (e.g. a
   departure that resolves entirely inside Time & Drift's invisible
   catch-up batch, per Core Rule 8 above) — without this write path,
   nothing supplies Discovery Surfacing's Departure cue with a real
   position for that now-dominant case. This system still never reads
   `last_known_position` back — it is a write-only call, consistent with
   Ecosystem Simulation calling into no one and this system calling in, the
   same direction Tending Input already uses for `apply_watering()`. See
   `ecosystem-simulation.md` Core Rule 12.

### States and Transitions

| State | Trigger | Next State |
|---|---|---|
| (none — ABSENT) | Ecosystem Simulation: ABSENT→PRESENT **while Time & Drift is ACTIVE** (scope clarified 2026-08-05 — see Core Rule 8) | SPAWNING |
| (none) | Time & Drift transitions CATCHING_UP→ACTIVE with the creature's now-settled state == PRESENT — whether from a raw restored blob value or a mid-batch spawn (widened 2026-08-05, Core Rule 8) | WANDERING (directly, at the settled position, fresh destination sampled — bypasses SPAWNING) |
| SPAWNING | creature placed at valid start position | WANDERING |
| WANDERING (moving) | reaches destination | PAUSING |
| PAUSING | pause duration elapses | WANDERING (new destination picked) |
| SPAWNING, WANDERING, or PAUSING | Ecosystem Simulation: PRESENT→ABSENT **while Time & Drift is ACTIVE** (scope clarified 2026-08-05) | DEPARTING (from current position) |
| DEPARTING | Ecosystem Simulation: PRESENT→ABSENT (redundant) | DEPARTING (no-op, already in progress) |
| DEPARTING | exit animation completes | (instance removed) |
| (none) | Time & Drift transitions CATCHING_UP→ACTIVE with the creature's now-settled state == ABSENT (new 2026-08-05, Core Rule 8) | (no instance — nothing to show; no DEPARTING animation plays for a creature the player never saw) |

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Ecosystem Simulation | Upstream (bidirectional, corrected 2026-08-09) | Reads creature PRESENT/ABSENT transitions; **also calls in** `set_last_known_position(creature_id, pos)` every frame this system holds a live instance (new — closes a blocking cross-GDD gap, see Core Rule 9 below and `ecosystem-simulation.md` Core Rule 12) |
| Content Data | Upstream | Reads `CreatureTypeDef.movement_speed`, `visual_ref` |
| Object Placement | Upstream (soft) | Reads current object footprints as movement obstacles |
| Time & Drift | Upstream (new, 2026-08-05 `/review-all-gdds` — Core Rule 8) | Reads CATCHING_UP vs. ACTIVE state to gate reaction to Ecosystem Simulation's PRESENT/ABSENT transitions — no reaction while CATCHING_UP, settled state queried once on reaching ACTIVE |
| Diorama Rendering | Downstream | Reads live creature position every frame for rendering — **(corrected 2026-08-05 `/review-all-gdds`, `qa-lead` finding) this dependency is already listed on Diorama Rendering's row in the systems index** (stale claim that it was missing, struck; see Dependencies section) |

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set.)*

## Formulas

**Destination sampling** (reuses Object Placement's existing ellipse
geometry, rejection sampling):

`dest = sample() where in_bounds(dx,dy) AND ∀obj: dist((dx,dy), obj.pos) ≥ obj.footprint_size + CREATURE_CLEARANCE`

**`sample()` distribution stated explicitly (added 2026-08-04
`/design-review`, `ai-programmer` finding — previously unspecified, which
left the wander distribution itself implementer-dependent):** `(dx,dy)` is
drawn uniformly at random from the jar's bounding rectangle
(`[cx-rx, cx+rx] × [cy-ry, cy+ry]`), then tested against `in_bounds` and
the clearance condition above — rejecting and re-drawing on failure, up to
`MAX_SAMPLE_ATTEMPTS`. This is a standard rejection-sampling-over-a-
bounding-box approach, not uniform sampling directly over the ellipse's
area (which would require a different, more complex draw); since the
ellipse fills a large majority of its own bounding box at this jar's
`rx=100, ry=60` proportions, the rejection rate from the box-vs-ellipse
mismatch alone is low and adds no meaningful bias concern at this scale.

`in_bounds` reuses Object Placement's formula directly
(`((dx-cx)/(rx-fp))² + ((dy-cy)/(ry-fp))² ≤ 1`, with `fp=0` since a wander
destination has no footprint of its own — not reinvented here). Retry up
to `MAX_SAMPLE_ATTEMPTS`; if exhausted, drop the clearance term for that
pick (the jar is small and mostly empty, so starvation risk is negligible,
but this is the documented fallback rather than an infinite loop).

| Variable | Type | Range | Description |
|---|---|---|---|
| CREATURE_CLEARANCE | float | ≥0 (default 4) | extra buffer beyond an object's footprint |
| MAX_SAMPLE_ATTEMPTS | int | 10–30 (default 20) | rejection-sampling retry cap |

**Movement/arrival** (clamp expression stated explicitly, added 2026-08-04
`/design-review`, `systems-designer` + `ai-programmer` independently
converging finding — the prior version asserted "clamped so `pos'` never
overshoots `dest`" without the operative expression, a real gap at this
document's own documented tuning ceiling: `movement_speed=20` at a low
frame rate, e.g. 5fps/`delta_time=0.2s`, produces a naive step of `4.0`
units, exceeding `ARRIVAL_THRESHOLD=2.0`, where an unspecified
implementation could diverge):

`step = min(movement_speed × delta_time, dist(pos, dest))`
`pos' = pos + normalize(dest - pos) × step`

This clamps the step to the remaining distance whenever a frame's naive
movement would exceed it, so `pos'` can equal `dest` exactly but never pass
beyond it, regardless of `movement_speed` or frame-time size.

**(new 2026-08-09, Core Rule 9)** The same frame this formula computes
`pos'`, this system calls `set_last_known_position(creature_id, pos')` into
Ecosystem Simulation — not a separate step or a separate cadence, the exact
same value, same frame, every frame a live instance exists.

`arrived = dist(pos, dest) ≤ ARRIVAL_THRESHOLD` (default **2.0** jar-space
units — small enough to look precise, large enough to avoid frame-jitter
false-negatives at 60fps). **Timing stated explicitly (same finding):**
arrival is checked against `pos'` — the already-updated, already-clamped
position — in the same frame the movement update runs, not deferred to the
next frame. This means a single large-delta frame (a frame hitch, or the
first frame after a tab regains focus) that would have overshot can still
arrive and transition to PAUSING within that same frame, rather than
needing an extra frame to detect arrival after clamping.

**Concrete `movement_speed` values** (jar-space units/sec, calibrated
against the jar's `rx=100, ry=60` scale from Object Placement's worked
example):

| Creature | movement_speed | Character |
|---|---|---|
| Snail | 6 | Crosses the jar in ~15–20s — genuinely slow, matches its name |
| Moth | 14 | ~2.3× Snail's speed, still gentle — nothing twitchy in a tiny jar |

**Pause duration** between destinations (**corrected 2026-08-04
`/design-review`, `game-designer` + `systems-designer` finding — this was
an owed, already-adjudicated companion edit, not a fresh design change:
`content-data.md`'s own history records `creative-director` ruling
`CreatureTypeDef.pause_duration_min/max` into existence specifically
because `movement_speed` alone was judged an insufficient Pillar 4
differentiator; this document's Formulas section had never actually
consumed the field it was created for**): `random_uniform(pause_duration_min,
pause_duration_max)` seconds, read per-`CreatureTypeDef` from Content Data —
**not** a single global range shared by every creature type. Per the pinned
MVP fixture (`content-data.md`): Snail `[3.0, 6.0]`, Moth `[1.5, 3.0]` — Moth
pauses roughly half as long as Snail, stacking a second, independent axis of
difference on top of the 2.3× speed gap, so the two creatures differ in both
*how fast* and *how often* they move, not speed alone. Long enough to read
as a deliberate pause, short enough that neither creature looks
frozen/broken.

*(`systems-designer` consulted for all movement math and values above,
reusing Object Placement's ellipse geometry rather than duplicating it.)*

## Edge Cases

- **If `MAX_SAMPLE_ATTEMPTS` is exhausted during destination sampling**:
  the clearance term is dropped and any in-bounds point is accepted
  regardless of object proximity, per the Formulas fallback — the
  creature might rarely pick a destination near an object's footprint,
  but this is a harmless, rare visual approximation, not a crash or stall.
- **If a creature is mid-transit (WANDERING) when Ecosystem Simulation
  transitions it PRESENT→ABSENT**: it switches to DEPARTING immediately
  from its current position — it does **not** need to reach its current
  destination first. Departure is an interruption, not something the
  player waits on.
- **If Snail and Moth are both PRESENT and their destinations or paths
  coincide**: no collision avoidance between creatures is required for
  MVP — brief visual overlap is accepted, not a bug, given only 2 creature
  types exist and any overlap is momentary.
- **If an object is dragged directly into a creature's already-chosen
  path** (not just its destination, per Core Rule 6's no-mid-transit-
  replanning rule): the creature continues toward its original
  destination, potentially causing a brief visual clip near the object's
  edge — accepted as a rare, minor artifact rather than added
  path-replanning complexity, consistent with Core Rule 6.
- **If an object is dragged onto a creature's already-chosen *destination*
  point itself** (added 2026-08-04 `/design-review`, `ai-programmer`
  finding — distinct from the path-crossing case above, which this rule
  does not cover): arrival is a pure distance check
  (`dist(pos,dest) ≤ ARRIVAL_THRESHOLD`) with no footprint re-check, so the
  creature can arrive at that point and then sit in PAUSING for its full
  pause duration (up to several seconds) visually overlapping the object —
  a static overlap for the whole pause, not the momentary clip the
  path-crossing case above accepts. Still accepted as a rare MVP
  simplification (this document's destination sampling already excludes
  footprints at *pick* time — Core Rule 5 — this is only reachable if the
  object moves there *after* the pick), consistent with Core Rule 6's
  no-mid-transit-replanning philosophy, but named here as its own distinct,
  slightly worse-case artifact rather than silently folded into the
  path-crossing bullet above.
- **If no valid destination point exists at all** (not realistically
  reachable with the MVP's single object, but a defensive case): after
  `MAX_SAMPLE_ATTEMPTS` exhausts even with clearance dropped, the creature
  remains in PAUSING and retries next frame rather than crashing or
  stalling permanently.
- **If Ecosystem Simulation ever signaled PRESENT for a `CreatureTypeDef`
  Content Data rejected at load time** (added 2026-08-04 `/design-review`,
  `ai-programmer` finding): out of scope for this document by design, not
  an unstated assumption — Ecosystem Simulation is solely responsible for
  never transitioning a creature type to PRESENT unless Content Data's
  registry actually holds a valid definition for it (`content-data.md`'s
  own load-time validity/exclusion rules already guarantee this). Creature
  Behavior has no defensive fallback for a missing `movement_speed`/
  `visual_ref` because this case cannot occur if that upstream guarantee
  holds.

## Dependencies

Creature Behavior depends on:
- **Ecosystem Simulation** (hard) — PRESENT/ABSENT state transitions
- **Content Data** (hard) — `CreatureTypeDef.movement_speed`, `visual_ref`
- **Object Placement** (soft) — current object footprints as movement
  obstacles; degrades gracefully with zero objects placed, per the Edge
  Cases pattern already established elsewhere in this project
- **Persistence/Save** (soft, added 2026-08-04 round 11) — a restored
  `state`/position (per `persistence-save.md` Core Rule 1) is the input to
  this system's Core Rule 8 session-start entry rule; soft because
  Creature Behavior only reacts to whatever Ecosystem Simulation's
  post-restore state already is, it never reads the save blob directly
- **Time & Drift** (hard, added 2026-08-05 `/review-all-gdds` — Core Rule
  8's scope widening) — reads its CATCHING_UP/ACTIVE state to know when a
  creature's session-start state has settled; a genuine new dependency

Ecosystem Simulation also depends on Creature Behavior calling in (not
"depends on" in the traditional sense — Ecosystem Simulation still never
reaches outward, this system calls into it, the same direction Tending
Input already uses for `apply_watering()`): **new 2026-08-09** —
`set_last_known_position(creature_id, pos)`, called every frame this
system holds a live instance for that creature, so Ecosystem Simulation's
`last_known_position` (its Core Rule 12) is always exactly this system's
own current-frame position whenever a live instance exists. See Core Rule
16 below.
  this round's cross-GDD review surfaced, not a bidirectionality gap
  carried over from an earlier round

Downstream dependents:
- **Diorama Rendering** (hard) — needs live creature position every
  frame. **(corrected 2026-08-05 `/review-all-gdds`, `qa-lead` finding)**
  the systems index's Diorama Rendering row already lists Creature
  Behavior as a dependency — the prior claim that it was missing was
  stale, struck rather than left to mislead a future reader.
- **Discovery Surfacing** (hard, added round 1 `/design-review` of
  `discovery-surfacing.md`) — reads a departed creature's last-known
  position for its Departure cue. Closes a bidirectionality gap:
  `discovery-surfacing.md`'s own Dependencies section already listed this
  as a hard upstream dependency; this document previously only mentioned
  Discovery Surfacing in an Open Question, not here.
- **Collection Tracking** (Full Vision, future) — will likely track which
  creatures have been observed

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `CREATURE_CLEARANCE` | 2–8 | Creature paths pass uncomfortably close to objects, may visually clip | Wastes valid destination space in a small jar, more rejection-sampling retries |
| `MAX_SAMPLE_ATTEMPTS` | 10–30 | Falls back to the no-clearance case more often, more visible near-object destinations | Wastes per-frame compute retrying (negligible at this scale, but still a knob) |
| `ARRIVAL_THRESHOLD` | 1–4 | Creature "hunts"/jitters near its destination without quite arriving, due to frame timing | Creature visibly stops short of its intended destination — looks imprecise |
| `movement_speed` (per creature type) | 4–20 units/sec | Creature looks frozen/barely moving — undercuts the "wandering" feel | Creature "teleports"/zips across the jar — breaks the calm, cozy tone |
| `pause_duration_min/max` (per creature type) | 1–8 sec, `min ≤ max` (data-corruption gate `PAUSE_DURATION_MAX=30` enforced by Content Data's own `definition_validity`) | Constant motion, no restful pauses — feels busy/frantic for a calm game; if both types converge to the same range, undercuts the Pillar 4 differentiation this field exists for | Creature looks stuck/frozen too often between destinations |

`movement_speed` values themselves (Snail=6, Moth=14) and
`pause_duration_min/max` values (Snail `[3.0,6.0]`, Moth `[1.5,3.0]`) are
already documented per-type in Formulas (**corrected 2026-08-04
`/design-review`** — pause duration was previously a single global value
here, not a per-type one) — this row exists to bound future tuning, not
duplicate the concrete values.

## Visual/Audio Requirements

N/A for this GDD's scope — Creature Behavior produces position and
state (SPAWNING/WANDERING/PAUSING/DEPARTING), but the actual sprite,
animation, and any SFX for movement/spawn/departure are owned by Diorama
Rendering and Ambient Audio, which consume this system's state.

## UI Requirements

N/A — Creature Behavior has no UI of its own.

## Acceptance Criteria

1. **GIVEN** Ecosystem Simulation transitions Snail ABSENT→PRESENT, **WHEN**
   this occurs, **THEN** Snail enters SPAWNING and is placed at a valid
   position (in-bounds, not overlapping any object footprint).
2. **GIVEN** a creature in SPAWNING has been placed at its valid start
   position, **WHEN** placement completes, **THEN** it transitions to
   WANDERING and picks its first destination.
3. **(corrected 2026-08-04 `/design-review` — previously cited a single
   global `[2.0, 5.0]`s range for every creature type; see Formulas'
   corrected Pause duration entry)** **GIVEN** a PRESENT Snail reaches its
   current destination (distance ≤ `ARRIVAL_THRESHOLD=2.0`), **WHEN** this
   occurs, **THEN** it transitions to PAUSING for a duration sampled from
   `[3.0, 6.0]` seconds (Snail's own `pause_duration_min/max`, per Content
   Data).
3a. **(new, 2026-08-04 `/design-review`)** **GIVEN** a PRESENT Moth reaches
   its current destination, **WHEN** this occurs, **THEN** it transitions
   to PAUSING for a duration sampled from `[1.5, 3.0]` seconds (Moth's own
   `pause_duration_min/max`) — distinct from Snail's range in AC3,
   confirming the pause range is read per-`CreatureTypeDef`, not shared.
4. **GIVEN** a creature in PAUSING, **WHEN** the pause duration elapses,
   **THEN** it picks a new destination via the sampling formula and
   transitions to WANDERING.
5. **GIVEN** a creature is WANDERING toward a destination, **WHEN** each
   frame updates, **THEN** its position advances by
   `movement_speed × delta_time` toward the destination without
   overshooting.
6. **GIVEN** no new visit boundary/tick has fired within a session,
   **WHEN** any number of frames render during that session, **THEN** the
   creature continues moving every frame regardless — movement is never
   gated on a new ecosystem tick.
7. **GIVEN** a destination sample would overlap an object's footprint plus
   `CREATURE_CLEARANCE`, **WHEN** sampling runs, **THEN** that candidate is
   rejected and resampled, up to 20 attempts.
8. **(pinned 2026-08-04 `/design-review`, `qa-lead` finding — previously
   ambiguous whether attempt #20 itself could still succeed)** **GIVEN**
   sampling attempts 1 through 20 each reject their candidate against the
   clearance condition (attempt 20 also fails, not just attempts 1–19),
   **WHEN** attempt 20 fails, **THEN** the 21st draw drops the clearance
   term and accepts any in-bounds point — confirming the fallback triggers
   only once all 20 clearance-checked attempts have failed, not on
   reaching attempt 20 regardless of its own outcome.
8a. **(new, 2026-08-04 `/design-review`, `qa-lead` finding)** **GIVEN** no
   valid destination exists even after the clearance term is dropped
   (Edge Cases' defensive case — not realistically reachable at MVP's
   single-object scope), **WHEN** sampling is attempted, **THEN** the
   creature remains in PAUSING and retries destination sampling on a
   subsequent frame — no crash, no exception, and no permanent stall.
9. **GIVEN** a creature's chosen destination lies beyond an object sitting
   directly on the straight-line path to it, **WHEN** the creature moves,
   **THEN** it travels the straight line without steering around the
   object — a visual clip is accepted, not corrected mid-transit.
10. **GIVEN** Ecosystem Simulation transitions a creature PRESENT→ABSENT
    while it is WANDERING, PAUSING, or still SPAWNING, **WHEN** this
    occurs, **THEN** it immediately transitions to DEPARTING from its
    current position.
11. **GIVEN** a creature is already DEPARTING, **WHEN** a redundant
    PRESENT→ABSENT transition fires, **THEN** nothing changes — the
    creature remains DEPARTING, the exit is not restarted.
12. **GIVEN** a creature in DEPARTING, **WHEN** its exit animation
    completes, **THEN** its instance is removed/hidden.
13. **GIVEN** Snail and Moth are both PRESENT with overlapping paths,
    **WHEN** this occurs, **THEN** no collision resolution occurs between
    them — both continue independently.
14. **GIVEN** an object is dragged into a creature's already-chosen path
    mid-transit, **WHEN** this occurs, **THEN** the current destination is
    **not** recalculated — only the *next* destination pick accounts for
    the object's new position.
15. **(new, 2026-08-04 `/design-review`, round 11, Core Rule 8; widened
    2026-08-05 `/review-all-gdds`, Core Rule 8's scope correction)**
    **GIVEN** a session starts and, after Time & Drift's catch-up batch
    completes and that system reaches ACTIVE, a creature's settled state is
    PRESENT — whether because it was restored `state == PRESENT` and
    stayed PRESENT throughout the batch (settled position `p` = the
    restored position), or because it transitioned ABSENT→PRESENT at some
    point *during* the batch (settled position `p` = the position Core
    Rule 1's SPAWNING placement would have chosen) — **WHEN** the first
    live frame runs, **THEN** the creature is in WANDERING (never having
    played a visible SPAWNING placement for this or any earlier transition
    that occurred before this frame) at position `p`, with a destination
    already sampled via the normal destination-sampling formula. An
    implementation that plays a SPAWNING animation for any transition
    resolved during the catch-up batch — including the very first
    transition into PRESENT, if that's what happened — fails this
    criterion.
15a. **(new, 2026-08-05 `/review-all-gdds`, Core Rule 8's scope
    correction)** **GIVEN** a session starts and, after Time & Drift's
    catch-up batch completes and that system reaches ACTIVE, a creature's
    settled state is ABSENT — whether it was restored ABSENT and stayed
    ABSENT throughout the batch, or was PRESENT at some point during the
    batch and departed before the batch completed — **WHEN** the first
    live frame runs, **THEN** no instance of that creature exists, and no
    DEPARTING exit animation has played at any point — an implementation
    that plays a DEPARTING animation for a departure resolved entirely
    within an invisible catch-up batch fails this criterion, since the
    player never saw the creature present to begin with.

*(`qa-lead` consulted — flagged 2 genuine GDD gaps (Core Rule 5's
contradiction between claimed path-avoidance and the straight-line-only
Formulas, and undefined behavior for ABSENT firing during SPAWNING/
DEPARTING), both fixed in Detailed Design before finalizing these criteria.
Also added missing criteria for the tick/frame decoupling and the
redundant-ABSENT no-op.)*

*(Touched by `/design-review` on 2026-08-04 — round 11, as a companion edit
during the full specialist round on content-data.md, ecosystem-
simulation.md, persistence-save.md, object-placement.md as a set (this
document is a dependent of that set, not one of its 4 target docs, but
`game-designer` and `qa-lead` found this document's own state machine had
no entry point for a creature restored from a save blob already PRESENT —
the only existing entry edge was Ecosystem Simulation's live ABSENT→PRESENT
transition. The dangerous default an implementer would reach for — routing
a restored creature through SPAWNING — would replay the arrival animation
for a creature that may have been resident for days, a false "something new
arrived" signal that directly contradicts this GDD's own Player Fantasy.
`creative-director` ruled: new Core Rule 8 — a restored PRESENT creature
enters WANDERING directly at its restored position with a freshly-sampled
destination. New state-table row and AC15 added. Persistence/Save added as
a soft downstream-triggering dependency.)*

*(Reviewed via `/design-review` on 2026-08-04 — round 1, first dedicated
full specialist round for this document: `game-designer`,
`systems-designer`, `qa-lead`, `godot-specialist`, `ai-programmer`,
`creative-director`. Verdict: NEEDS REVISION → all 3 blockers resolved
below, text-only, no formula redesign beyond stating what was already
implied. **Pause duration finally consumed per creature type**
(`game-designer`, `systems-designer` finding): `content-data.md` has
tracked, across multiple of its own review rounds, that this document owed
a "companion edit" to consume `CreatureTypeDef.pause_duration_min/max`
(created specifically because `movement_speed` alone was ruled insufficient
for Pillar 4 differentiation) — this document's Formulas still specified a
single global `random_uniform(2.0, 5.0)` and its own Open Questions never
tracked the debt. `creative-director`: "approving this document with the
edit outstanding would silently overturn a prior CD ruling by inaction."
Fixed: Formulas now reads per-type from Content Data (Snail `[3.0,6.0]`,
Moth `[1.5,3.0]`), AC3 corrected to Snail's range, new AC3a added for
Moth's, Tuning Knobs row updated to match. **Departure-while-away ownership
stated** (`game-designer` finding): Core Rule 8 already solved the
"restored still-PRESENT" arrival-asymmetry case, but the mirror case — a
creature that departed *while the player was away*, the more common path
since ticks batch at visit boundaries — got zero player-facing framing,
unlike the careful "moving on, not punishment" treatment the live DEPARTING
case (Core Rule 4) receives. Resolved not by adding new Creature Behavior
logic (there is nothing to render for an already-absent creature) but by
stating explicitly that this framing is owned by Discovery Surfacing,
consuming Ecosystem Simulation's existing spawn/departure state-delta feed
— a new Open Question flags this as a stated requirement for that
not-yet-authored GDD, rather than a silent gap with no owner anywhere.
**Movement clamp formula stated explicitly** (`systems-designer` and
`ai-programmer` independently converging finding): "clamped so `pos'`
never overshoots `dest`" previously named no operative expression, a real
gap at this document's own tuning ceiling (`movement_speed=20` at low
frame rate). Added `step = min(movement_speed × delta_time, dist(pos,
dest))` and stated arrival is checked same-frame against the already-
clamped position, not deferred. **All 5 recommended items applied in the
same pass** (cheap, text-only, already specialist-vetted this round):
`sample()`'s distribution stated explicitly (`ai-programmer`); a new edge
case added for an object dragged onto an already-chosen destination,
distinct from Core Rule 6's path-crossing case (`ai-programmer`); AC8
rewritten to pin the exact fallback-trigger attempt count, new AC8a added
for the "no valid destination at all" defensive case (`qa-lead`);
Ecosystem Simulation's responsibility for never signaling PRESENT on a
rejected CreatureTypeDef stated explicitly as a new Edge Case
(`ai-programmer`). **Nice-to-have, deferred**: softening the
inter-creature-overlap dismissal (`game-designer`); a
`CREATURE_CLEARANCE`-vs-`LENIENCY` cross-reference (`systems-designer`); a
`_process()` implementation note (`godot-specialist`); folding the
SPAWNING-entrance-animation-interrupt risk into the existing spawn/exit
Open Question (`ai-programmer`).)*

*(Reviewed via `/review-all-gdds` on 2026-08-05 — round 2, holistic
cross-GDD consistency pass across all 8 approved MVP GDDs. Verdict on the
pass: FAIL; this document's own 1 blocker resolved below, same session,
no formal specialist re-review round (user decision). **Core Rule 8
widened to cover every session-start transition, not just the raw
restored blob value** (`game-designer`/`systems-designer` finding): every
PRESENT/ABSENT transition Ecosystem Simulation produces happens on a
tick, and every tick fires exclusively inside Time & Drift's atomic,
non-rendering catch-up batch — never live once that system reaches
ACTIVE. The round-11 version of Core Rule 8 only handled the raw value
read directly from the save blob before any catch-up ticks ran, leaving
undefined what happens when the batch *itself* flips a creature's state
(e.g., a restored-ABSENT creature that spawns mid-batch, or a
restored-PRESENT one that departs mid-batch) — read literally, such a
transition would route through Core Rule 1's SPAWNING or Core Rules 4/7's
DEPARTING, both of which specify a real animation that cannot complete
inside an atomic invisible batch (`time-drift.md` AC11). Fixed by
widening Core Rule 8's scope from "the raw pre-catchup blob value" to
"the creature's settled state once Time & Drift reaches ACTIVE" — no
animation plays for any transition resolved during CATCHING_UP, only the
final settled state (PRESENT → WANDERING directly; ABSENT → nothing
shown) is ever presented. Live, in-session SPAWNING/DEPARTING are
completely unaffected. States and Transitions table, AC15, and new AC15a
updated to match. **New hard dependency on Time & Drift added** (this
system now reads its CATCHING_UP/ACTIVE state directly) — companion edit
added to `time-drift.md`'s own Dependencies section for bidirectionality.
**Stale self-claim struck** (`qa-lead` finding): this document's
Interactions/Dependencies sections both still asserted "this dependency
is missing from Diorama Rendering's row in the systems index" — false;
`systems-index.md` row 10 already lists Creature Behavior. Both notes
corrected rather than left to mislead a future reader.)*

*(Fixed 2026-08-09 — cross-GDD review finding, no formal specialist
re-review round (user decision), same pattern as the round-2 fix above.
**New Core Rule 9 added**: this system now calls
`set_last_known_position(creature_id, pos')` into Ecosystem Simulation
every frame it holds a live instance, closing a blocking gap the review
found — no system supplied a valid position for a creature whose
departure resolves entirely inside an invisible catch-up batch (the
dominant departure path once `N_departure_ticks=25`, since ticks only
ever fire inside that batch). Interactions table's Ecosystem Simulation
row corrected from one-directional (Upstream) to bidirectional; Dependencies
section extended to describe the new call-in. See
`ecosystem-simulation.md` Core Rule 12 for the full mechanism this
services.)*

## Open Questions

- **Spawn/exit visual treatment**: What does SPAWNING and DEPARTING
  actually look like (fade-in/out, a small entrance animation, a specific
  jar-edge exit point)? Owner: art-director. Target: before Diorama
  Rendering GDD authoring.
- **Straight-line-path simplification's scaling limit**: Core Rules 5/9
  accept a straight-line path with no obstacle steering, justified by the
  MVP's single small object. If Alpha/Full Vision adds more objects or
  multiple jars (per the systems index's Alpha tier), should this
  simplification be revisited with real steering, or does it still hold at
  that scale? Owner: systems-designer. Target: before Alpha-tier scoping.
- **"First seen" signal for Collection Tracking**: The Full Vision
  Collection Tracking system will likely need to know when a creature is
  first observed by the player. Does that event belong here (Creature
  Behavior) or in Ecosystem Simulation (where PRESENT/ABSENT already
  lives)? Owner: game-designer. Target: before Collection Tracking GDD
  authoring (Full Vision — not urgent).
- ~~**Requirement flagged for Discovery Surfacing (added 2026-08-04
  `/design-review`, `game-designer` finding, `creative-director` ruling)**:
  a creature departing while the player was away (the common case, per
  Core Rule 8's departure-ownership note above) must read as "moved on,"
  consistent with this document's own live-DEPARTING framing (Core Rule
  4) — not as silent absence discovered cold on return.~~ **Resolved
  (round 1 `/design-review` of `discovery-surfacing.md`)**: that
  document's Core Rule 7 delivers exactly this — Departure is surfaced,
  never silent, cued at the creature's last-known position. See this
  document's Dependencies section above.
