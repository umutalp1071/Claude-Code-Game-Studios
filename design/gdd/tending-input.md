# Tending Input

> **Status**: Approved — round 1 blockers and recommended items resolved, plus a round 2 Player Fantasy correction from `/review-all-gdds` (accepted without a formal specialist re-review round; user decision, see trailing review note)
> **Author**: user + game-designer
> **Last Updated**: 2026-08-09 (both Open Questions closed — watering visual cue and repeat-tap stacking, both resolved via `diorama-rendering.md` Core Rule 11); previously 2026-08-05 (round 2 `/review-all-gdds` — stale same-session growth claim corrected — see trailing note)
> **Implements Pillar**: Pillar 3 (Care, Not Control) — watering is the other half of the tending pair alongside repositioning
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS — round 1 full specialist review (game-designer, systems-designer, qa-lead, godot-specialist, creative-director), verdict NEEDS REVISION at time of review; all 2 blockers and 5 recommended items resolved this same pass, text-only (see trailing review note). Post-fix state not re-confirmed by a fresh specialist round, per user's explicit choice to skip re-review.

## Overview

Tending Input translates a `tap` gesture over the jar background (not over
any object — that's Object Placement's claim) into a watering action: it
calls Ecosystem Simulation's `apply_watering(watering_amount)` and triggers
the immediate visual/audio feedback that makes the action feel responsive.
Mechanically, it's a thin routing layer — the actual moisture math lives in
Ecosystem Simulation — but for the player, this is one half of the tending
pair (watering, alongside repositioning), the fast, legible, satisfying
action that the prototype confirmed reads clearly as "my action caused this"
(Pillar 3: Care, Not Control).

## Player Fantasy

Watering is the simplest, most immediate act of care in the whole game: one
tap, one clear response — moisture rises immediately, visibly, the instant
the tap registers. **Corrected 2026-08-05 `/review-all-gdds`**
(`game-designer`/`systems-designer` finding, companion correction to
`ecosystem-simulation.md`'s own Overview fix the same round): the prior
version of this paragraph continued "...and within a tick or two the
plants' condition visibly shifts" — structurally impossible under the
locked tick model. `growth_stage` only ever changes on a tick, and ticks
never fire live during an ACTIVE session (`time-drift.md` Core Rule 6), so
no amount of watering in one sitting can move a plant's growth_stage; that
payoff always lands at the *next* session's catch-up batch, never "a tick
or two" later in the same visit. Moisture's live, immediate rise is still
the fast half of the tending pair this paragraph describes — that part was
always accurate. The prototype's own "Let time pass" button already
matches this corrected picture: the tester validated the water → moisture
→ growth chain as legible **across a time-pass step**, not within one — the
tester never actually needed to see growth move same-session, only that
the causal chain read clearly once observed. This is still the *fast* half
of the "balanced reactivity" design the whole concept rests on: Object
Placement's repositioning is slow and aesthetic, but watering is quick and
functional, giving the player an immediate, low-effort way to feel like
they've done something for the jar before the slower, next-visit payoff
arrives. If this system felt sluggish or its moisture effect were
invisible, the player-facing symptom is exactly the failure mode the game
must avoid — tending stops feeling like care and starts feeling like
guessing.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules.)*

## Detailed Design

### Core Rules

1. A `tap` gesture (from Input Abstraction) whose position falls within the
   jar's floor ellipse **and does not fall within any repositionable
   object's current footprint** triggers a watering action. The footprint
   exclusion is what keeps this system from colliding with Object
   Placement's claim on object-covered taps.
2. On a qualifying tap, this system calls
   `EcosystemSimulation.apply_watering(watering_amount)` exactly once — no
   batching, no double-counting per tap.
3. Watering feedback (visual/audio cue) plays immediately on trigger —
   same-frame — and so does the underlying moisture math: `apply_watering()`
   raises `jar_moisture` **immediately**, live, not deferred to a tick.
   **Corrected 2026-08-04 `/design-review` (round 14 of
   `ecosystem-simulation.md`)** — this rule previously said the moisture
   math "applies at the next tick boundary." That was inconsistent with
   `time-drift.md`'s own state machine: ecosystem ticks only ever fire as a
   batch at session-start `CATCHING_UP`, never live during an `ACTIVE`
   session, so "the next tick boundary" during an ACTIVE session could mean
   "not until the next session" — a player watering mid-session would have
   seen no visible effect until closing and reopening the jar, contradicting
   this doc's own Player Fantasy ("moisture rises... within a tick or two").
   `ecosystem-simulation.md` Core Rule 5 was corrected in the same pass to
   make watering a live, immediate write to `jar_moisture`, fully decoupled
   from tick-driven decay; this rule now matches. **Split for testability
   (added 2026-08-04 `/design-review`, `qa-lead` finding):** this rule
   bundles two separate guarantees — the visual/audio cue firing same-frame
   (verified here by AC6) and the moisture write itself being immediate.
   The moisture-write half is verified by `ecosystem-simulation.md`'s own
   Acceptance Criteria (its AC2/AC4a), not duplicated in this document's AC
   list — noted here so the split isn't mistaken for a coverage gap.
   **Implementation note (added 2026-08-04 `/design-review`,
   `godot-specialist` finding):** the `tap` → `apply_watering()` →
   feedback-cue call chain must not use `call_deferred`, `await`, or a
   `CONNECT_DEFERRED` signal connection anywhere along its path — any of
   those would silently push the moisture write to the next frame,
   reopening the exact bug this rule was already corrected once to fix.
4. There is no cooldown between waterings. Tending Input places no rate
   limit on tap frequency — if the player taps twice in a row, both calls
   fire. Ecosystem Simulation's own `jar_moisture` clamp (0–100) is what
   prevents runaway effects, not this system.
5. A `tap` that lands on an object's footprint never triggers watering (a
   `tap`, by definition, never exceeded the drag threshold, so Object
   Placement's HELD state was never entered either). This is not a silent
   dead zone: Object Placement's own Core Rules consume that same `tap` and
   play a wobble acknowledgment on the object, so the player still gets
   feedback that their gesture registered — Tending Input simply isn't the
   system that provides it for this case.

### States and Transitions

N/A — Tending Input is stateless. Unlike Object Placement's HELD/IDLE or
Ecosystem Simulation's GROWING/DECAYING, there's no cooldown, no held state,
no timer to track (per Core Rule 4). Every qualifying tap is handled
identically and independently.

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Input Abstraction | Upstream | Consumes `tap` + `position` |
| Object Placement | Upstream | Queries current object positions/footprints to exclude them from the watering zone |
| Ecosystem Simulation | Downstream (calls in) | Calls `apply_watering(watering_amount)` |

**Corrected 2026-08-09** (cross-GDD review finding): this previously claimed
zero downstream dependents, which was already stale as of `ambient-audio.md`'s
2026-08-05 authoring and became doubly so with `diorama-rendering.md`'s
2026-08-09 Core Rule 11 addition. Both read this system's `apply_watering()`
trigger event (soft dependency — neither requires it to function, both
degrade gracefully to their base states without it):

| System | Relationship | What It Reads |
|--------|--------------|----------------|
| Diorama Rendering | Downstream (soft) | The `apply_watering()` trigger event, to drive Core Rule 11's Watering Substrate Sheen — no position data needed, the cue is jar-wide |
| Ambient Audio | Downstream (soft) | The same `apply_watering()` trigger event, to drive its Reactive Layer Boosts watering swell (Core Rule 3) |

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set.)*

## Formulas

N/A — no calculations performed. Footprint checking delegates entirely to
Object Placement's existing footprint data; tap/drag classification
delegates to Input Abstraction; the actual moisture math delegates to
Ecosystem Simulation (`watering_amount=25`, registered and owned there —
not redefined here).

*(`systems-designer` consulted — confirmed no formulas belong in this GDD;
it's a pure router with no math of its own.)*

## Edge Cases

- **If a tap lands exactly at an object's footprint boundary distance**
  (`distance == footprint_size` exactly): treated as **on** the footprint
  (inclusive) — consistent with Object Placement's own boundary-inclusive
  convention, so this system doesn't invent a second rule for the same
  geometry. The tap is excluded from watering (Object Placement handles the
  acknowledgment for it instead).
- **If a tap lands outside the jar's floor ellipse entirely** (e.g., on the
  glass rim or background, if such positions are reachable): does not
  trigger watering — treated as a dead-zone tap, not an error.
- **If two objects' footprints happen to overlap** (**corrected 2026-08-04
  `/design-review`, `systems-designer` finding** — previously called this a
  data/authoring bug that Object Placement's validity check "should
  prevent"; that's wrong. Object Placement's own `no_overlap` formula
  permits real footprint overlap by design via its `LENIENCY` knob (default
  0.8) — its own Tuning Knobs section states this is intentional so sprites
  can visually overlap slightly before a placement is rejected, and its
  Open Questions confirms this is guaranteed to occur, not merely
  hypothetical, once a second repositionable object exists. This is
  expected behavior under that tolerance, not an authoring error) and a tap
  lands in the overlapping zone: still excluded from watering — being
  within *any* footprint is sufficient exclusion, regardless of how many
  footprints overlap there.
- **If no objects are currently placed/loaded** (e.g., a loading-order edge
  case before the MVP's single rock instantiates): every in-bounds tap
  triggers watering normally, since there's nothing to exclude — this
  system degrades gracefully with zero objects.
- **If a tap fires before Ecosystem Simulation has finished initializing**:
  this is avoided structurally, not handled reactively — Tending Input's
  input handling is not enabled until Ecosystem Simulation has completed
  initialization, so the race condition never occurs at runtime.

## Dependencies

Tending Input depends on:
- **Input Abstraction** (hard) — `tap` + `position`. **Stated explicitly
  (added 2026-08-04 `/design-review`, `qa-lead` finding):** this system has
  no state of its own (Core Rule 4/States and Transitions), so it relies
  entirely on Input Abstraction's own state machine to guarantee a `tap`
  never fires mid-drag and that a post-drag release is never misclassified
  as a `tap` on open jar space — AC9 only verifies drag events themselves
  never trigger watering, not this upstream guarantee.
- **Object Placement** (hard) — current object footprints, to exclude them
  from the watering zone
- **Ecosystem Simulation** (hard) — calls `apply_watering(watering_amount)`

Downstream dependents (soft, both corrected 2026-08-09 — see Interactions
above for detail): **Diorama Rendering** (Core Rule 11, Watering Substrate
Sheen) and **Ambient Audio** (Core Rule 3, watering swell), both reading only
the `apply_watering()` trigger event, not any state this system owns.

## Tuning Knobs

N/A — this system has no designer-adjustable values of its own.
`watering_amount` is Ecosystem Simulation's tuning knob (already documented
there), and Tending Input deliberately has no cooldown to tune (Core Rule
4) — there's nothing here to expose as a knob.

## Visual/Audio Requirements

N/A for this GDD's scope — Core Rule 3 requires an immediate visual/audio
watering cue, but the actual treatment (what it looks/sounds like) is owned
by Diorama Rendering and Ambient Audio, which consume this system's
watering-trigger event. See Open Questions for the one unresolved detail.

## UI Requirements

N/A — Tending Input has no UI; it's a direct world-space tap interaction.

## Acceptance Criteria

1. **(corrected 2026-08-04 `/design-review`, `qa-lead` finding — previously
   asserted the literal value `apply_watering(25)`, which this document's
   own Formulas section explicitly disclaims owning; a retune of
   Ecosystem Simulation's `watering_amount` would break this test with zero
   change to Tending Input's own behavior)** **GIVEN** a tap over the open
   jar (not on any object footprint), **WHEN** the tap fires, **THEN**
   `apply_watering(watering_amount)` is called exactly once, passing
   Ecosystem Simulation's configured `watering_amount` constant, not a
   value redefined here.
2. **GIVEN** a tap directly on the rock's footprint, **WHEN** the tap
   fires, **THEN** `apply_watering` is **not** called and no error or
   exception occurs in this system — this is not silent overall, since
   `object-placement.md`'s own AC13 (tap-on-footprint wobble) covers the
   player-facing feedback for this same tap. **(cross-referenced by AC
   number 2026-08-04 `/design-review`, `game-designer` finding)** if AC13
   is ever weakened or removed, that regression surfaces in
   `object-placement.md`'s own suite, not silently here — this AC only
   verifies Tending Input's own half (no call, no error).
3. **GIVEN** two consecutive taps on open jar space, **WHEN** both fire,
   **THEN** `apply_watering` is called twice, once per tap, with no
   cooldown blocking the second call.
4. **GIVEN** a tap at exactly the footprint boundary distance from an
   object's center, **WHEN** the tap fires, **THEN** it's treated as on the
   footprint and `apply_watering` is **not** called.
5. **GIVEN** a tap outside the jar's floor ellipse, **WHEN** the tap fires,
   **THEN** `apply_watering` is **not** called.
6. **GIVEN** a watering trigger, **WHEN** it fires, **THEN** a visual/audio
   feedback cue plays on the same frame, not deferred to the next
   simulation tick.
7. **GIVEN** no objects are currently placed, **WHEN** any in-bounds tap
   fires, **THEN** `apply_watering` is called (no exclusion zone to check).
8. **GIVEN** a tap lands within the overlapping footprint zone of two
   objects (**corrected 2026-08-04 `/design-review`** — not a data-bug
   scenario; expected under Object Placement's `LENIENCY` tolerance, per
   the corrected Edge Cases entry above), **WHEN** the tap fires, **THEN**
   `apply_watering` is **not** called — excluded once, not double-processed
   or errored.
9. **GIVEN** a `drag_start`/`drag_move`/`drag_end` event (not a `tap`),
   **WHEN** it fires anywhere in the jar including open space, **THEN**
   Tending Input never calls `apply_watering` — only `tap` events are
   consumed by this system.

*(`qa-lead` consulted — flagged 2 missing criteria (overlapping-footprint
zone, drag-vs-tap boundary) and one under-specified criterion (dead-zone
tap needed an explicit "no error" assertion), all addressed above.)*

*(Reviewed via `/design-review` on 2026-08-04 — round 1, first dedicated
full specialist round for this document: `game-designer`, `systems-designer`,
`qa-lead`, `godot-specialist`, `creative-director`. Verdict: NEEDS REVISION
→ 2 blockers resolved below, text-only, no design rework. **Footprint-
overlap rationale corrected** (`systems-designer` finding): Edge Cases and
AC8 both wrongly called two-objects-overlapping a "data/authoring bug" that
Object Placement's validity check "should prevent" — `object-placement.md`'s
own `LENIENCY` knob permits exactly this by design, confirmed guaranteed
(not hypothetical) in that document's own Open Questions. Corrected to
"expected under Object Placement's `LENIENCY` tolerance, not an authoring
error" — the underlying excluded-from-watering behavior was already
correct, only the stated reason was wrong. **AC1 value ownership fixed**
(`qa-lead` finding): AC1 hardcoded the literal `apply_watering(25)` despite
this document's own Formulas section explicitly disclaiming ownership of
that value ("registered and owned there [Ecosystem Simulation] — not
redefined here"); rewritten to assert the call against the configured
`watering_amount` constant instead of a literal, so this test doesn't break
on an Ecosystem Simulation retune with zero change to Tending Input's own
logic. **`game-designer`'s no-cooldown concern ruled, not changed**
(`creative-director`): Core Rule 4's lack of a cooldown was flagged as a
"mash to win" degenerate-strategy risk, but `creative-director` downgraded
this — a cooldown is a timer, and this game's own Anti-Pillars name timers
as a punishing-mechanic category to avoid; Object Placement's own
`LENIENCY` knob exists to *remove* friction for the same underlying reason,
so adding friction to the "quick, functional, low-effort" half of the
tending pair would invert this document's own stated design intent. If a
ceiling on watering value matters, that's Ecosystem Simulation's
moisture-response curve to own, not a gate here — see Open Questions.
**All 5 recommended items applied in the same pass** (cheap, text-only,
already specialist-vetted this round): AC2 cross-references Object
Placement's AC13 wobble by number (`game-designer`); Core Rule 3 now notes
its moisture-immediacy half is verified by `ecosystem-simulation.md`'s own
suite, plus a `call_deferred`/`await`-avoidance implementation note for the
tap→water→cue chain (`qa-lead`, `godot-specialist`); Dependencies now
states this system's reliance on Input Abstraction's own state machine
explicitly (`qa-lead`); the no-cooldown ruling and a new moisture-ceiling
question against `ecosystem-simulation.md` are recorded in Open Questions
below (`creative-director`). **Deferred, nice-to-have, not this document's
problem to fix**: flagging a forward-looking save-write-storm risk in
`persistence-save.md`'s own Open Questions if its drafted
write-on-mutation trigger is ever adopted (`systems-designer`, nice-to-have,
not this document's problem to solve).)*

*(Reviewed via `/review-all-gdds` on 2026-08-05 — round 2, holistic
cross-GDD consistency pass across all 8 approved MVP GDDs. Verdict on the
pass: FAIL; this document's own 1 blocker resolved below, same session, no
formal specialist re-review round (user decision). **Player Fantasy's
stale same-session growth claim corrected** (`game-designer`/
`systems-designer` finding, companion to the identical correction made to
`ecosystem-simulation.md`'s Overview the same round): "moisture rises, and
within a tick or two the plants' condition visibly shifts" is structurally
impossible under the locked tick model — `growth_stage` only changes on a
tick, and ticks never fire live during an ACTIVE session
(`time-drift.md` Core Rule 6). Corrected to describe what's actually true:
moisture's rise is live and immediate; growth's payoff lands at the next
session's catch-up batch. The prototype's own "Let time pass" button
already matches this corrected picture, so no design change was needed,
only the description.)*

## Open Questions

- ~~**Watering cue treatment**~~ — **RESOLVED 2026-08-09** (visual half;
  audio half already RESOLVED 2026-08-05). `diorama-rendering.md` Core
  Rule 11 ("Watering Substrate Sheen", `art-director` addition): the
  substrate darkens/cool-shifts via a `self_modulate` tween (same
  mechanism as that doc's STALLED cue) plus a brief `energy` boost on the
  existing ambient sun `Light2D` for a specular catch-light read — no
  ripple/mist/droplet particle, no new node. Jar-wide, not tap-positioned
  (Ecosystem Simulation only tracks `jar_moisture` at jar level). Shares
  the same 3-second rise-hold-fall envelope and same-frame trigger as
  `ambient-audio.md`'s audio swell, so both channels read as one unified
  sensory moment. See that document's Core Rule 11 and Formulas
  (`sheen_intensity(t)`).
- ~~**Repeat-tap feedback stacking**~~ — **RESOLVED 2026-08-09**, by the
  same Core Rule 11 addition: a second `apply_watering()` mid-swell
  retriggers (kill-and-restart from the live interpolated value) rather
  than stacking or queuing — mirrors `ambient-audio.md`'s identical
  retrigger-not-stack ruling for the audio half, and Core Rule 6's
  existing snap-back/wobble retrigger policy elsewhere in
  `diorama-rendering.md`. **Ruled 2026-08-04 `/design-review`
  (`creative-director`):** this is correctly scoped as a visual-only
  question — Core Rule 4's lack of a gameplay cooldown is deliberate design
  (see below), not a gap this question is meant to patch.
- **No-cooldown design, confirmed not a gap (added 2026-08-04
  `/design-review`, `game-designer` finding, `creative-director` ruling):**
  Core Rule 4's lack of a cooldown was raised as a possible "mash to win"
  degenerate strategy (rapid tapping saturates `jar_moisture` to 100 with
  no friction or judgment required). Ruled **not a defect**: a cooldown is
  a timer, and this game's Anti-Pillars name timers as a punishing-mechanic
  category to avoid; Object Placement's own `LENIENCY` knob exists to
  *remove* friction from tending for the same underlying reason, so adding
  friction here would invert this document's own stated contrast ("watering
  is quick and functional... Object Placement is slow and aesthetic"). No
  action needed in this document. ~~The one real open question this
  reframes: is `jar_moisture=100` actually the strictly optimal state with
  no downside?~~ — **RESOLVED 2026-08-09** (cross-GDD review, derived from
  already-locked numbers, no new tuning pass needed): no. `jar_moisture=100`
  sits outside **all three** MVP plants' moisture tolerance bands (Moss max
  75, Fern max 90, Flower max 90, per `ecosystem-simulation.md` Formulas) —
  spam-watering to saturation puts every plant into DECAYING, not GROWING.
  Mash-to-win is not a dominant strategy; it's actively counterproductive.
  This currently holds by coincidence of unrelated tuning rather than
  documented intent — worth keeping in mind if any plant's moisture band is
  ever retuned toward 100 in a future balance pass, since that would
  silently reopen this question.
