# Ecosystem Simulation

> **Status**: Approved — round 16 blockers (from `/review-all-gdds`) resolved same session, no formal specialist re-review round (user decision, see `design/gdd/reviews/ecosystem-simulation-review-log.md` and trailing review note below)
> **Author**: user + systems-designer
> **Last Updated**: 2026-08-09 (cross-GDD fix — creature `last_known_position` + `was_present_during_batch` mechanism added to close a blocking gap found by `/review-all-gdds`; see trailing review note. Previously 2026-08-05)
> **Implements Pillar**: Pillars 1, 2, 3, 4 — this system IS the core hypothesis; every pillar depends on it feeling alive rather than random or static
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED — fresh-session re-review confirmed round 15's fixes hold, 0 blocking items; round 16 fixes (watering/growth Overview correction, departure-timing Anti-Pillar fix) applied 2026-08-05 without a fresh specialist round

## Overview

Ecosystem Simulation is the rule-based system that governs moisture,
plant/moss growth and decay, and creature spawn/departure — driven by the
fields Content Data defines (`moisture_tolerance`, `growth_rate`,
`decay_rate`, `spawn_conditions`) and advanced by Time & Drift's ticks.
**Corrected 2026-08-05 `/review-all-gdds`** (`game-designer`/
`systems-designer` finding): watering reacts quickly and visibly —
`jar_moisture` rises live, the instant `apply_watering()` is called (Core
Rule 5) — but growth itself does **not** nudge live; `growth_stage` only
ever changes on a tick, and ticks never fire during an ACTIVE session
(`time-drift.md` Core Rule 6), so a plant's condition can only visibly
shift at the *next* session's catch-up batch, never within the same
sitting the player watered in. This correction replaces an earlier claim
here ("watering visibly raises moisture and nudges growth") that predated
Core Rule 5's own round-14 fix fully decoupling watering from ticks —
that claim was accurate before round 14, stale afterward, and never
updated to match. Moisture's live responsiveness and growth's next-visit
payoff together still read as caused by the player's care rather than as
either a scripted response or arbitrary noise — the two halves just land
on different timescales, both intentional (moisture: immediate feedback
that a tap worked; growth: the "check in and see what changed" hook this
whole game is built around) — drifting slowly and semi-independently
between visits. This is the system the whole game's hypothesis
rests on: the terrarium-concept prototype already confirmed players can read
the cause-and-effect chain clearly (moisture → growth → creature
appearance/departure) without confusion, but also found that a small state
space gets "fully discovered" within 5–10 time-pass cycles — so this GDD must
design for *possibility-space depth* as a real requirement, not just tune
the reactive math.

## Player Fantasy

The player never controls the ecosystem directly — they nudge it (water,
reposition) and then feel like a witness to something with its own inner
life. The single strongest proof of this already exists: the prototype's
creature appeared and wandered independently once conditions crossed a
threshold, and the tester's own words were *"it felt like my actions had
actually influenced the ecosystem instead of triggering an immediate
scripted event."* That's **Pillar 3 (Care, Not Control)** working exactly as
intended, and this system's entire job is to keep reliably producing that
feeling across dozens of visits — without collapsing into either "nothing
ever changes" (static) or "I can't tell why this happened" (random). If this
system fails, the player-facing symptom is the prototype's own flattest
moment, in the tester's words: *"I felt like I had already discovered the
entire state space... pressing time-pass no longer created anticipation."*

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Given how central this
system is, consider a manual creative-director pass before production
regardless.)*

## Detailed Design

### Core Rules

1. Jar moisture is a **single shared value**, not per-plant — watering
   affects the whole jar at once (matches the prototype's single moisture
   meter and Tending Input's jar-wide watering action).
2. Each placed plant instance tracks its own `growth_stage` (integer, `0` to
   `visual_stages.length - 1` from its `PlantTypeDef`).
3. Each tick (driven by Time & Drift's `advance_tick()` call): if current jar
   moisture is within a plant's `moisture_tolerance_min/max`, its
   `growth_stage` advances by `growth_rate`; if moisture is outside that
   range, `growth_stage` regresses by `decay_rate` instead. This is the
   exact cause-and-effect chain the prototype validated as legible.
4. `growth_stage` is clamped to `[0, max_stage]` — it never goes negative or
   exceeds the plant's defined visual stages.
5. Watering raises jar moisture by a fixed amount, applied **immediately**
   when `apply_watering()` is called — it is a live action, not deferred to
   a tick, since Time & Drift's ticks only ever fire as a batch at session
   start (`CATCHING_UP`), never live during an `ACTIVE` session (see
   `time-drift.md` Core Rule 6). Moisture decay is the opposite: it is
   **purely tick-driven** and fires only as part of `advance_tick()`,
   regardless of whether any watering happened in between. These are two
   independent write paths to the same `jar_moisture` value, not one
   combined per-tick formula — see the correction below and Formulas.
   Starting values carried forward from the prototype (+25 watering, -3/tick
   decay, 40–75 optimal range) — refined in Tuning Knobs.

   **Corrected 2026-08-04 `/design-review`, round 14 — this rule previously
   implied watering and decay resolve together in one per-tick formula
   evaluation.** `game-designer` found this directly contradicted
   `tending-input.md`'s own Core Rule 3 read literally against
   `time-drift.md`'s state machine: if watering only ever "applied at the
   next tick boundary" and ticks never fire live during `ACTIVE`, a player
   watering mid-session would see zero visible effect until they closed and
   reopened the jar — falsifying this GDD's own Overview claim ("reacts
   quickly to tending") and the Player Fantasy's legibility promise, a real
   defect, not a documentation nuance. `creative-director` ruled the fix:
   watering is a live, immediate mutation of `jar_moisture`, fully decoupled
   from the tick cycle; decay remains exclusively tick-driven. This also
   resolves the previously-open question "does a watered tick and a decay
   tick ever actually co-occur in real play" — they don't, by design, and no
   longer need to. `tending-input.md` Core Rule 3 corrected to match in the
   same pass.
6. Creature spawn: a `CreatureTypeDef`'s `spawn_conditions` (total moss
   coverage and/or moisture range) must hold for `N_spawn_ticks`
   **consecutive** ticks before the creature becomes present — this
   debounce prevents single-tick flicker spawns and preserves the
   "conditions caused this" feeling over "it just appeared."
7. Creature departure is symmetric: conditions must fail for
   `N_departure_ticks` consecutive ticks before the creature departs.
   Departure must always read as the creature "moving on," never as a
   punishment or death event — matching the Anti-Pillar (different, never
   punished).

   **Departure debounce decoupled from spawn's speed (corrected 2026-08-05
   `/review-all-gdds`, `game-designer`/`systems-designer` finding,
   `creative-director` ruling: user selected this over a fast-recovery
   mechanic or documenting the outcome as intentional).** `N_departure_ticks`
   was tuned (alongside `N_spawn_ticks`) so a debounce can resolve within a
   single visit's catch-up batch — `time-drift.md`'s own calibration states
   this as a deliberate goal ("a spawn or departure can plausibly resolve
   in one visit"). That goal is correct for *spawning* (a player should be
   able to earn a new resident in one good visit) but wrong for
   *departure*: since moisture converges out of every MVP plant's
   tolerance band within roughly 7–12 ticks regardless of absence length
   (`time-drift.md`'s own per-plant exit-tick trace), and growth_stage then
   decays toward the spawn-condition threshold shortly after, the same
   short absence that makes departure *possible* also makes it complete —
   a same-length debounce means departure and its own precondition resolve
   inside the same brief window. Traced concretely: at the current
   `N_departure_ticks=5`, a weekend-length absence (roughly 40–48 hours,
   well inside the ~7–12 tick moisture-exit window plus 5 more ticks) is
   enough to depart **both** Snail and Moth, every time, with no player
   action able to prevent it — a guaranteed, repeatable outcome rather than
   one of several possible "different" states, which is what actually
   trips the Anti-Pillar despite this rule's own "moving on, not
   punishment" framing.

   **Structural fix**: `N_departure_ticks`'s safe range is widened and its
   default substantially increased (see Tuning Knobs) so departure
   requires a genuinely long absence spanning multiple typical visits, not
   one resolvable inside the same short window that makes it eligible in
   the first place — decoupling "how fast a debounce *can* resolve" from
   "how fast *this specific* debounce should," now that the two directions
   have been shown to need different answers. `N_spawn_ticks` is unaffected
   by this correction; only the reasoning that previously assumed both
   constants should share one "resolves within a visit" design goal is
   corrected.

   **Retuned value picked, 2026-08-09 (required pre-implementation tuning
   pass, see Open Questions — RESOLVED):** `N_departure_ticks=25`, within
   the widened 10–30 range above. See Tuning Knobs for the full trace; in
   short, the fastest possible departure path (Moth, via Flower's
   razor-thin `==max_stage` condition) now takes 30 ticks total, and
   Snail's takes 31–35 depending on starting `growth_stage` — both
   meaningfully longer than a typical 1–2 day absence (8–24 ticks) and
   comfortably under `max_catchup_ticks=84`.
7a. **(new, not a renumbering — inserted between Core Rules 7 and 8 to
   avoid disturbing the existing Core Rule 8/9/10 numbering, which
   `content-data.md` cross-references by number. Corrected 2026-08-04
   round 12: an earlier version of this note also claimed
   `persistence-save.md` and `input-abstraction.md` cross-reference this
   numbering — spot-checked and false; those docs' own "Core Rule 8"
   mentions refer to their own Core Rule 8 (or `time-drift.md`'s), not this
   one. Harmless either way since 7a was kept regardless, but the
   justification is now accurate.)** The debounce counter behind Core Rules 6/7 is
   named `condition_streak_ticks`, one per creature instance, and is
   persisted (added 2026-08-04, `/design-review` round 11) — a single
   per-creature
   integer counting consecutive ticks toward whichever debounce currently
   applies: consecutive ticks `spawn_conditions` has held **true** while
   ABSENT (toward `N_spawn_ticks`), or consecutive ticks it has held
   **false** while PRESENT (toward `N_departure_ticks`). It resets to `0`
   on any ABSENT↔PRESENT transition (the same tick the debounce it was
   counting toward resolves) and on any tick where the relevant condition
   breaks (per the existing oscillation Edge Case below). Previously this
   counter was implied by Core Rules 6/7's prose and the States and
   Transitions table but never named or persisted — every session boundary
   silently reset it, which meant a frequent-short-visit play pattern (few
   ticks per session) could never accumulate a debounce streak across a
   session boundary at all, making `N_spawn_ticks`/`N_departure_ticks`
   unreachable for that cadence rather than merely slower. Now persisted —
   see `persistence-save.md` Core Rule 1.
8. **Possibility-space depth requirement** (directly from the prototype's
   recommendation, not an afterthought): within the MVP's 3 plant/moss + 2
   creature scope, growth rates and spawn conditions must be varied enough
   that the jar doesn't hit a single simultaneous steady state. Concretely:
   the 3 plant types must have staggered `moisture_tolerance` ranges and
   `growth_rate` values so they don't all mature/decay in lockstep, and the
   2 creatures' `spawn_conditions` must be distinct enough that one
   creature's presence measurably changes the odds or timing of the other's
   (sequential/conditional, not two independent coin-flips on the same
   variable).

   **Corrected 2026-08-03 `/design-review` — this rule previously failed on
   its own terms.** `game-designer` and `systems-designer` independently
   found that staggering bands on `jar_moisture` alone cannot produce real
   depth: it's one shared scalar under direct, immediate player control (via
   watering), so staggered bands just slice one line into buckets a player
   maps in a single watering sweep. Worse, the original MVP bands
   mathematically collapsed: Moss `[40,75]` ∩ Fern `[55,90]` ∩ Flower
   `[65,85]` = `[65,75]` — any `jar_moisture` in that 10-point range put
   **all three plants in GROWING simultaneously**, the exact lockstep this
   rule claims to prevent, and a rational player chasing Flower's narrow,
   sharply-punishing old band would be pulled straight into it.
   `creative-director` ruled the fix: restore a second, independent
   variable — `light_level` (Core Rule 9 below and Formulas) — that drifts
   on its own regardless of player action. This is a **regression fix, not
   new scope**: `game-concept.md`'s MVP Definition already specifies
   "moisture/light-driven growth" (item 3) and Core Mechanics item 2; this
   GDD had silently dropped the light half and tried to manufacture depth
   by over-subdividing the one remaining dial instead. Explicitly **not**
   fixed via randomness — `creative-director` rejected RNG here, since it
   would trade the "static" failure mode for the "random, can't tell why"
   one the prototype already flagged as the opposite failure.
9. **Light level** (new 2026-08-03, see Core Rule 8's correction above): a
   second global jar-wide value, `light_level` (int, 0–100), updated once
   per tick alongside `jar_moisture` but by a wholly separate, deterministic
   formula (Formulas) — not player-settable by any tending action. Each
   plant type gains a `light_tolerance_min/max` band (Content Data). Growth
   is now a **three-state** outcome per tick, not a binary grow/decay
   (**corrected 2026-08-04 `/design-review`, round 12 — see below**):
   **GROWING** when both bands are satisfied, **STALLED** (no change either
   way) when moisture is satisfied but light is not, and **DECAYING** only
   when moisture itself is unsatisfied, regardless of light. Because the
   player can hold `jar_moisture` wherever they like but cannot touch
   `light_level`, the jar can never be permanently "parked" in one static
   state the way pure moisture control risked — light keeps moving the
   system through different combined states on its own, which is also a
   more honest expression of **Pillar 3 (Care, Not Control)**: the player
   nudges one axis, the world owns the other. This is **distinct from and
   unrelated to** Time & Drift's cosmetic `day_night_phase` — that value
   stays presentation-only with zero gameplay effect, per that GDD's own
   Core Rule 7, untouched by this addition. (Two independent "things drift
   over time" concepts coexisting — one cosmetic/fast/session-scoped, one
   gameplay-relevant/slow/tick-scoped — is intentional, not a naming
   collision to resolve; see that GDD if the naming proximity is confusing
   during implementation.)

   **Corrected 2026-08-04 `/design-review`, round 12 — this rule previously
   over-punished light alone.** The prior version required BOTH bands
   simultaneously to grow, decaying otherwise — `game-designer` and
   `systems-designer` independently traced a full 40-tick light cycle and
   found this decay-biases 2 of the 3 MVP plant types (Moss, Fern) *even
   under flawless player moisture care*, purely because all three light
   bands are width-40 (light sits out-of-band ~60% of ticks regardless of
   anything the player does) while `decay_rate ≥ growth_rate` for those two
   types. A player watering perfectly would still watch those plants
   net-decay, with no player-visible explanation (`light_level` has no
   rendering yet — see the visibility contract below) — a direct Anti-Pillar
   violation (punished for something invisible and uncontrollable), not a
   tuning risk. `creative-director` ruled the fix: light failing alone now
   **stalls** growth (freezes `growth_stage`) instead of reversing it;
   only moisture failing still triggers decay. This preserves everything
   `light_level` was added for in Core Rule 8's correction (the jar still
   can't be permanently parked, since light still gates *when* growth can
   resume) while removing the erasure risk — shade should pause a plant,
   not rot it. See Formulas (Plant Growth Delta) for the corrected formula
   and States and Transitions for the new STALLED state.
10. **Detail events**: when a plant has held `moisture` within its optimal
    range for an extended duration, a small probabilistic visual variation
    (e.g., a rare bloom) can trigger. This directly serves Pillar 4 and was
    explicitly flagged as untested-at-density in the prototype — it is a
    real MVP mechanic, not decoration to cut under time pressure.
    **Lifetime stated explicitly (added 2026-08-05 `/design-review` on
    `persistence-save.md`, round 13 — `game-designer`/`systems-designer`
    companion-edit finding):** the per-tick trigger this flag represents is
    transient, not persisted across a save/load boundary — it can only fire
    during a tick, and ticks only ever fire inside Time & Drift's catch-up
    batch at session start (`time-drift.md` Core Rule 6), so a triggered
    flag is always generated *and* surfaced to the player (via Discovery
    Surfacing, reading this system's own state-delta feed) within the same
    session, strictly before any save write can occur. It deliberately has
    no corresponding field in `persistence-save.md`'s blob — see that
    document's Formulas for the full lifecycle argument. This is distinct
    from `optimal_hold_ticks` (the counter gating this event), which *is*
    persisted, since that counter's value does carry across a session
    boundary even though the one-shot firing flag it occasionally produces
    does not.
11. **Tick evaluation order** (new, 2026-08-04 `/design-review`, round 13,
    `systems-designer` finding, `creative-director` ruling): within a
    single tick, all plants resolve their Plant Growth Delta first, against
    that tick's `jar_moisture`/`light_level`. Only after every plant has
    resolved do creatures evaluate `spawn_conditions`, in Content Data's
    creature-type definition order. Any `spawn_conditions` expression that
    reads another creature's state (e.g. Moth reading `snail.state`) always
    reads that creature's state **as it was at the start of the tick**, not
    a value produced earlier in the same tick's creature pass — so creature
    evaluation order never changes the outcome, even though the pass itself
    is ordered. This resolves an ambiguity flagged this round: without a
    stated order, Moth's read of Snail's live state on the exact tick
    Snail's departure debounce resolves was implementation-defined, not
    specified.

12. **Creature last-known position** (new 2026-08-09, `/review-all-gdds`
    cross-GDD finding — closes a blocking gap: no system supplied a valid
    position for a creature that departs entirely inside an invisible
    catch-up batch, since Creature Behavior — the sole owner of live
    position — never spawns an instance for a creature whose settled state
    is ABSENT, per its own Core Rule 8). Ecosystem Simulation stores one
    `last_known_position` value `(px, py)` per creature (Snail, Moth),
    independent of and in addition to the creature's own PRESENT/ABSENT
    state — it does not clear or become invalid when the creature is
    ABSENT, unlike Creature Behavior's own live position, which only
    exists while an instance does. **Write path**: Creature Behavior calls
    `set_last_known_position(creature_id, pos)` on every frame it holds a
    live instance for that creature — the same frame it computes `pos'` in
    its own Movement/arrival formula — so this value is always exactly the
    creature's true current position whenever one exists, and freezes at
    its most recent true value the instant no live instance exists
    (including through a departure that resolves entirely inside a
    catch-up batch, or a spawn that happens live but a subsequent
    departure resolves in a later batch). **Default**: `(0, 0)` — Object
    Placement's own jar-floor ellipse center `(cx, cy)`, not a newly
    authored value — for any creature that has never yet had a live
    instance in this game's history (e.g. its very first spawn-and-
    departure cycle completes entirely inside one catch-up batch before
    ever going live; see Core Rule 13 below and `discovery-surfacing.md`'s
    new `full_cycle` Departure case). This keeps Ecosystem Simulation a
    pure state owner with a query/command interface — Creature Behavior
    calls *into* it (the same pattern Tending Input already uses for
    `apply_watering()`); Ecosystem Simulation still never reaches outward.
13. **`was_present_during_batch` flag** (new 2026-08-09, companion to Core
    Rule 12, same root finding): a transient, per-creature boolean, reset
    to `false` at the start of every catch-up batch and set `true` the
    moment that creature is PRESENT at the end of **any** tick within the
    batch (regardless of how many times it subsequently flips back to
    ABSENT before the batch ends). This exists so Discovery Surfacing can
    detect a creature that both spawned and departed within one invisible
    batch — net PRESENT/ABSENT state unchanged (ABSENT at both batch start
    and end), yet a real, if unwitnessed, residency occurred — a case its
    own Core Rule 2's "no discovery for nothing changed" rule would
    otherwise silently swallow (see `discovery-surfacing.md` Core Rule 2a's
    `full_cycle` case). Lifecycle is identical to Core Rule 10's existing
    detail-event flag: transient, generated during a tick, always read by
    Discovery Surfacing within the same session strictly before any save
    write can occur (ticks only ever fire inside Time & Drift's catch-up
    batch; Discovery Surfacing computes its delta set at the very next
    CATCHING_UP→ACTIVE transition) — it deliberately has **no**
    corresponding field in `persistence-save.md`'s blob, for the same
    reason Core Rule 10's flag doesn't.

### States and Transitions

**Per-plant growth state (corrected 2026-08-04 `/design-review`, round 12 — added STALLED, see Formulas for the three-state rationale):**
| State | Condition | Behavior |
|---|---|---|
| GROWING | moisture AND light both within tolerance range | `growth_stage` increments toward `max_stage` each tick |
| STALLED | moisture within tolerance range, light outside it | `growth_stage` unchanged that tick — neither grows nor decays |
| DECAYING | moisture outside tolerance range (regardless of light) | `growth_stage` decrements toward `0` each tick |
| DORMANT | `growth_stage == 0` | Held at 0 while moisture stays out of range; if moisture returns but light doesn't, stays at 0 via STALLED rather than resuming growth; resumes GROWING once both bands are satisfied |
| MATURE | `growth_stage == max_stage` | Held at max while moisture stays in range — **regardless of light** (GROWING clamps at max, STALLED holds it unchanged; only moisture failing can move it off max) |

**Per-creature presence state:**
| State | Trigger | Next State |
|---|---|---|
| ABSENT | `spawn_conditions` met for `N_spawn_ticks` consecutive ticks | PRESENT |
| PRESENT | `spawn_conditions` remain met | PRESENT (continues; wandering behavior owned by Creature Behavior) |
| PRESENT | `spawn_conditions` fail for `N_departure_ticks` consecutive ticks | ABSENT |

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Content Data | Upstream | Reads `PlantTypeDef`/`CreatureTypeDef` fields |
| Tending Input | Downstream (calls in) | Calls `apply_watering(amount)` to raise jar moisture **immediately, live** — not deferred to a tick (corrected round 14, see Core Rule 5) |
| Time & Drift | Downstream (calls in) | Calls `advance_tick()` once per simulated tick |
| Creature Behavior | Downstream (bidirectional, corrected 2026-08-09) | Reads creature PRESENT/ABSENT state; calls `set_last_known_position(creature_id, pos)` every frame it holds a live instance (new, Core Rule 12) |
| Persistence/Save | Downstream (bidirectional) | Reads/writes `jar_moisture`, `light_level`/`light_direction`, per-plant `growth_stage`/`optimal_hold_ticks`, per-creature state/`condition_streak_ticks` (added 2026-08-04 round 12 — this row was missing despite the Dependencies section below already describing the full relationship) |
| Discovery Surfacing | Downstream (reads) | Reads state deltas since last visit (growth changes, spawn/departure, detail events) |
| Diorama Rendering | Downstream (reads) | Reads `growth_stage`, creature presence, detail-event flags, `light_level`, **and `jar_moisture`** (companion edit, 2026-08-05 — `diorama-rendering.md` now authored; both `jar_moisture` and `light_level` are needed together to evaluate the mandated per-plant STALLED cue's `moisture_ok`/`light_ok` sub-expressions, see note below) |

Ecosystem Simulation exposes its state to five downstream systems but calls
into none of them — it's a pure state owner with a query/command interface,
never reaching outward. **This still holds after the 2026-08-09 fix
above**: Creature Behavior calling `set_last_known_position()` is Creature
Behavior calling *into* Ecosystem Simulation, the same direction Tending
Input's `apply_watering()` already uses — Ecosystem Simulation itself
still never queries or calls any other system.

**`light_level` must be perceivable, not just computed (added 2026-08-04
`/design-review`, `game-designer` finding, `creative-director` ruling):**
`light_level` co-equally gates every plant's growth alongside moisture
(Formulas), but as originally specified nothing downstream ever rendered
it — Diorama Rendering's row above didn't list it, and Time & Drift's
`day_night_phase` is deliberately decoupled and cosmetic-only (that GDD's
own Core Rule 7). A mechanic invisible to the player that silently decides
whether a well-watered plant grows or decays directly contradicts this
GDD's own Player Fantasy ("the exact cause-and-effect chain the prototype
validated as legible"). This is not new scope: `game-concept.md`'s Visual
Identity Anchor already commits to "light as mood... lighting communicates
time of day/season more than UI does" (supporting visual principle 3) —
this requirement was already implied, just never wired to this variable.
**Resolution**: Diorama Rendering must read `light_level` and reflect it as
a visible lighting/mood shift in the jar — the exact treatment (color
temperature, brightness, shadow softness) is that system's design decision,
same pattern as every other "owned by Diorama Rendering" open item in this
project, but the *requirement that it be visible at all* is locked here,
not deferred. Flagged for Diorama Rendering's own Dependencies section when
that GDD is authored.

**Upgraded to a hard blocking dependency (added 2026-08-04 `/design-review`,
round 13, `game-designer` finding, `creative-director` ruling):** STALLED
and DECAYING currently render identically — both are just "growth_stage
didn't move" — because nothing yet distinguishes "paused, waiting on light"
from "actively failing." That collapses the round-12 fix's own precision
(pausing instead of punishing) back into the same ambiguity it was meant to
remove, one layer up: a player watering perfectly cannot tell "working as
intended" from "broken." Ecosystem Simulation is therefore **not considered
implementation-complete** until `light_level` has some visible
representation in the jar — Diorama Rendering is promoted from a
provisional downstream reader to a hard blocking dependency for this
reason, unlike Discovery Surfacing (below), which remains genuinely
provisional.

**Interim fallback corrected to per-plant (2026-08-04 `/design-review`,
round 14, `game-designer` finding, `creative-director` ruling):** the
round-13 fallback (a single jar-wide color-temperature tint driven by
`light_level`) does not actually clear round 13's own bar. A jar-wide tint
communicates the global `light_level` value, not any individual plant's
STALLED/GROWING/DECAYING state — a player would still have to mentally
intersect the global tint against each plant's own `light_tolerance` band to
know whether *that specific plant* is paused, which is exactly the
legibility gap round 13 was meant to close. **Mandated interim fallback
(corrected)**: pending Diorama Rendering's own GDD and art pass, each plant
instance must show a minimal **per-plant** visual cue driven by its own
STALLED state — e.g., the plant's sprite desaturates/dims while STALLED and
returns to normal color while GROWING or DECAYING — rather than a single
jar-wide tint. This still requires no new art (a shader/modulate-color
adjustment on the existing plant sprite), so it ships alongside this
system's own implementation the same way the prior fallback did. A
secondary jar-wide tint reflecting `light_level` itself (the original round-13
proposal) may still ship alongside this per-plant cue for ambient mood, but
it does not substitute for it — the per-plant cue is what satisfies this
blocking dependency. Diorama Rendering's eventual full treatment supersedes
both; it does not block on either.

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Given this is the project's highest-risk system,
consider a manual systems-designer/game-designer pass before production
regardless.)*

## Formulas

**Jar Moisture** — two independent operations on the same value (split
2026-08-04, round 14 — see Core Rule 5's correction):

**(a) Watering** (live, fires immediately on `apply_watering()`, decoupled
from ticks):

`jar_moisture' = clamp(jar_moisture + watering_amount, 0, 100)`

**(b) Tick decay** (fires only as part of `advance_tick()`):

`jar_moisture' = clamp(jar_moisture - moisture_decay_rate, 0, 100)`

| Variable | Type | Range | Description |
|---|---|---|---|
| jar_moisture | int | 0–100 | shared jar-wide moisture value |
| moisture_decay_rate | int | — | per-tick decay (recommended: 3) |
| watering_amount | int | — | per-watering-action increase (recommended: 25) |

**Output Range:** 0–100, clamped both ends, for either operation.
**Example:** `jar_moisture=50` — a tick with no prior watering → `47`.
Separately, `apply_watering()` on `jar_moisture=50` → `75` immediately, with
no tick required. The two never combine into one formula evaluation: a
watering call and a decay tick are independent writes, applied whenever each
is actually triggered.

---

**Light Level** (global, per tick — new 2026-08-03, see Core Rules 8/9):

`light_level' = clamp(light_level + light_direction × LIGHT_STEP_PER_TICK, 0, 100)`
`light_direction' = -light_direction` if the clamp triggered (hit 0 or 100
this tick), else unchanged — a deterministic triangle wave, not a random
walk.

| Variable | Type | Range | Description |
|---|---|---|---|
| light_level | int | 0–100 | shared jar-wide light value, independent of `jar_moisture` |
| light_direction | int | {-1, +1} | current drift direction, persisted (Persistence/Save) |
| LIGHT_STEP_PER_TICK | int | — | per-tick drift magnitude (recommended: 5) |

**Output Range:** 0–100, clamped both ends, direction flips on clamp.
**Example:** `light_level=97`, `light_direction=+1` → next tick:
`97+5=102`, clamped to `100`, direction flips to `-1`. The tick after:
`100-5=95`, direction stays `-1`. A full 0→100→0 sweep takes 40 ticks
(20 up, 20 down) — at `seconds_per_tick=7200` (Time & Drift), roughly 3.3
real days round-trip, distinctly slower than Time & Drift's 20-minute
cosmetic day/night loop and distinctly slower than `jar_moisture`'s own
~15–17 tick convergence-to-zero — a third, independent pace in the system,
not a duplicate of either existing cycle.
**First-session default:** `light_level=50`, `light_direction=+1` (the
midpoint, ascending) — same "authored initial state, not pre-decayed"
principle Time & Drift already applies to `last_visit_timestamp`.

---

**Plant Growth Delta** (per plant instance, per tick):

`moisture_ok = jar_moisture ∈ [moisture_tolerance_min, moisture_tolerance_max]`
`light_ok = light_level ∈ [light_tolerance_min, light_tolerance_max]`

```
growth_stage' =
  clamp(growth_stage + growth_rate, 0, max_stage)   if moisture_ok AND light_ok       (GROWING)
  growth_stage                                       if moisture_ok AND NOT light_ok   (STALLED)
  clamp(growth_stage - decay_rate, 0, max_stage)      if NOT moisture_ok               (DECAYING — light irrelevant)
```

**Three-state, corrected 2026-08-04 `/design-review`, round 12 (was a binary
AND-gate as of the 2026-08-03 round)**: the prior version decayed whenever
either condition failed, which `game-designer`/`systems-designer` found
decay-biases Moss and Fern even under flawless moisture care, purely from
the light cycle's own duty cycle — see Core Rule 9's correction for the
full trace and rationale. Now, light failing alone **stalls** growth
(freezes `growth_stage`, no change either direction) rather than reversing
it; only moisture failing triggers decay, regardless of light. A plant with
an excellent moisture reading but light currently out of its band pauses,
it does not retreat.

| Variable | Type | Range | Description |
|---|---|---|---|
| growth_stage | int | 0–max_stage | current growth stage, from Content Data |
| growth_rate, decay_rate | int | ≥0 | from `PlantTypeDef`, per Content Data |
| max_stage | int | ≥1 | `visual_stages.length - 1` |
| light_tolerance_min/max | int | 0–100 | per-plant viable light band, from Content Data |
| moisture_ok, light_ok | bool | — | per-tick band checks, see above |

**Output Range:** `[0, max_stage]`.

**Concrete staggered values for MVP's 3 plant types** — satisfying the
possibility-space depth requirement (Core Rule 8): these must NOT share one
tolerance band, or the whole jar hits one steady state together.

| Type | moisture range | light range | growth_rate | decay_rate | max_stage | Character |
|---|---|---|---|---|---|---|
| Moss (baseline) | 40–75 | 20–60 | 1 | 2 | 4 | Prototype's validated anchor |
| Fern | 55–90 | 40–80 | 1 | 1 | 6 | Slow to mature, slow to decay — forgiving, wants a wetter, brighter jar |
| Flower | 60–90 | 55–95 | 2 | 1 | 3 | Fast reward, gentle to lose (retuned 2026-08-03 — see below) — needs the wettest, brightest jar of the three |

**Flower retuned 2026-08-03 `/design-review`**: the prior `decay_rate=4`
against `max_stage=3` zeroed Flower's `growth_stage` on a single bad tick —
`game-designer` flagged this as a direct "NOT punishing" anti-pillar
violation, not a defensible extreme-but-legal tuning value, since it's the
*only* one-tick full wipe among the three plant types. `creative-director`
ruled: `decay_rate` 4→1 (matching Fern's forgiving rate) and the moisture
band widened 65–85→60–90. Flower keeps its "fast reward" character
(`growth_rate=2`, the highest of the three, and the narrowest `max_stage=3`
so it still matures quickest) without the punishing decay half.

At `jar_moisture=50`, `light_level=50`: moisture alone would put Moss and
Fern both in-range and Flower out — but this no longer demonstrates three
*distinct* outcomes on its own now that a second axis is in play; see
Acceptance Criteria (AC15) for a worked example that does, and note the
3-way band intersections are now much narrower than the pre-fix collapse:
moisture `[60,75]` (still nonzero, by design — see Core Rule 8's note that
this isn't required to fully vanish, only for `light_level` to keep the
system from ever getting permanently stuck there) and light `[55,60]`
(narrower still). A player can still park `jar_moisture` inside `[60,75]`
by choice, but `light_level` cannot be parked by anyone — it keeps sweeping
through the full `[0,100]` range every ~40 ticks regardless, so the
combined `(moisture, light)` lockstep window is transient, not a
permanently reachable steady state.

---

**Creature Spawn Conditions** — deliberately sequential, not parallel
coin-flips (per Core Rule 8):

| Creature | spawn_conditions |
|---|---|
| Snail | `moss.growth_stage + fern.growth_stage ≥ 6` |
| Moth | `flower.growth_stage == max_stage AND snail.state == PRESENT` |

Moth's spawn is gated on Snail already being present — Snail's own timing
directly shifts when (or whether) Moth can appear, giving the jar a
discoverable *sequence* rather than two independent thresholds.

**Debounce constants:** `N_spawn_ticks = 3`, `N_departure_ticks = 25`
(departure is deliberately slower than spawn — a longer "still here" grace
period reads as the creature settling in and wandering off gradually, not
an abrupt punishment). **Retuned 2026-08-09 (required pre-implementation
tuning pass — RESOLVED, see Open Questions):** `N_departure_ticks` is
locked at `25`, within the widened 10–30 safe range (Core Rule 7's
correction, 2026-08-05). Full trace and rationale in Tuning Knobs and
Open Questions.

---

**Detail Event Probability** (per plant, per tick, while conditions hold):

`p_detail = optimal_hold_ticks ≥ 6 ? 0.05 : 0`, and `optimal_hold_ticks`
resets to `0` the moment the plant is not in the strict **GROWING** state
(i.e., moisture **or** light leaves its tolerance range — the same
`moisture_ok AND light_ok` check Plant Growth Delta's GROWING branch uses,
above). **This is deliberately the strict AND, not the three-state
grow/stall/decay outcome** — a STALLED plant (moisture fine, light out) is
not actively decaying, but it is also not "held in its optimal state," so
it does not accumulate hold-ticks either; only genuine GROWING ticks count.

**Threshold lowered 10→6, corrected 2026-08-04 `/design-review`, round 12**
(`game-designer` finding): at the documented default `LIGHT_STEP_PER_TICK=5`
and all three MVP plants' light bands being width-40, the longest possible
contiguous GROWING streak is `40/5+1=9` ticks (none of the three bands
include the `light_level` 0/100 turnaround points, which would otherwise
roughly double the achievable streak) — one tick short of the old 10-tick
gate, for all three plant types, unconditionally. The "rare bloom" mechanic
was mathematically dead content at the documented default. Lowered to `6`
(within the existing Tuning Knobs safe range of 5–15) so it's reachable
inside the 9-tick ceiling with margin.

**Corrected 2026-08-04 `/design-review`** (`systems-designer` finding, prior
round): this reset condition previously read only "the moment moisture
leaves that plant's tolerance range," unchanged since before `light_level`
was added — corrected to also reset on light leaving range, for the reason
above.

| Variable | Type | Range | Description |
|---|---|---|---|
| optimal_hold_ticks | int | ≥0 | consecutive ticks the plant has been in the strict GROWING state (moisture AND light both in this plant's tolerance bands) — persisted, see `persistence-save.md` (added 2026-08-04, round 11) |
| p_detail | float | 0 or 0.05 | per-tick probability of a rare visual detail event once the hold threshold is met |
| roll | float | [0, 1) | externally-supplied random draw, injected rather than read from engine RNG (see Acceptance Criteria — testability fix, round 12) |

**Example:** A Fern held with both moisture and light in its `[55,90]`/
`[40,80]` ranges for 8 consecutive ticks has a 5% chance each further tick
of triggering a rare bloom — but if moisture dips to 50, **or** light drifts
outside `[40,80]`, at tick 5, the counter resets to 0 and the plant must
hold steady on both axes for another 6 ticks before details can trigger
again.

*(`systems-designer` consulted for all formulas and tuning values above,
anchored to the terrarium-concept prototype's validated starting numbers.)*

---

**Creature Last-Known Position** (per creature, event-driven — not a
per-tick formula; new 2026-08-09, see Core Rule 12):

`last_known_position' = pos'` — written by Creature Behavior every frame
it holds a live instance for that creature (the same `pos'` its own
Movement/arrival formula computes), otherwise unchanged.

`last_known_position_default = (cx, cy) = (0, 0)` — Object Placement's
jar-floor ellipse center (`object-placement.md`'s worked example:
`(cx,cy,rx,ry)=(0,0,100,60)`), used until the first write ever occurs for
that creature.

| Variable | Type | Range | Description |
|---|---|---|---|
| last_known_position | (float, float) | within the jar's floor ellipse in ordinary play; unclamped by this formula itself | most recent true position of a live instance, or the default if none has ever existed |
| pos' | (float, float) | jar-space | Creature Behavior's own current-frame position, from its Movement/arrival formula (`creature-behavior.md`) |
| cx, cy | float | jar-space | jar-floor ellipse center, reused from `object-placement.md`, not re-authored here |

**Output Range**: unbounded by this formula itself (it is a direct copy of
whatever Creature Behavior's own formula already produces, which is
already bounded to the jar's floor ellipse by that document's own
destination sampling) — the only value this formula can independently
produce is the `(0, 0)` default.
**Example**: Snail has never spawned — `last_known_position = (0, 0)`
(default). Snail spawns and wanders live for a session, ending the session
still PRESENT at `pos = (34.2, -11.6)` — `last_known_position` is
`(34.2, -11.6)` at session end (kept in sync every frame while live).
Three sessions later, Snail's departure debounce resolves entirely inside
that session's catch-up batch (no live instance this session, per
`creature-behavior.md` Core Rule 8) — Discovery Surfacing's Departure item
for Snail is positioned at `(34.2, -11.6)`, the last position anyone
actually observed, not a guess made up for this session.

---

**`was_present_during_batch`** (per creature, per catch-up batch — new
2026-08-09, see Core Rule 13):

`was_present_during_batch' = was_present_during_batch OR (state_after_this_tick == PRESENT)`,
reset to `false` at the start of each catch-up batch, evaluated once per
tick alongside that tick's creature-state resolution (Core Rule 11's
existing plants-then-creatures ordering).

| Variable | Type | Range | Description |
|---|---|---|---|
| was_present_during_batch | bool | — | true if the creature was PRESENT at the end of at least one tick this batch, regardless of its state at batch start/end |
| state_after_this_tick | enum | {PRESENT, ABSENT} | this creature's settled state for the tick just resolved |

**Output Range**: boolean.
**Example**: Moth is ABSENT at batch start. Tick 40: Moth's spawn debounce
resolves, `state=PRESENT`, `was_present_during_batch=true`. Tick 63 (23
ticks later, within the same 84-tick-capped batch): Moth's departure
debounce resolves, `state=ABSENT`. At batch end, Moth's net transition is
ABSENT→ABSENT (Discovery Surfacing's Core Rule 2 would normally generate
nothing), but `was_present_during_batch=true` — Discovery Surfacing
generates a `full_cycle`-flagged Departure item instead of staying silent
(see `discovery-surfacing.md` Core Rule 2a).

## Edge Cases

- **If watering occurs while `jar_moisture` is already at or near 100**: it
  clamps at 100 — no overflow, and "wasted" extra watering has no negative
  effect. Over-tending is never punished.
- **If moisture decay would push `jar_moisture` below 0**: it clamps at 0 —
  moisture never goes negative.
- **If `jar_moisture` sits exactly on a plant's `moisture_tolerance_min` or
  `_max` boundary**: `in_range` is inclusive (`∈ [min, max]`) — a plant
  exactly at its boundary is growing, not decaying. Consistent with the
  permissive-boundary pattern already used in Object Placement and Content
  Data.
- **(added 2026-08-04 `/design-review`, round 12) If moisture is within a
  plant's tolerance range but light is not**: `growth_stage` is STALLED —
  it neither increments nor decrements that tick. This is intentionally
  different from `jar_moisture` being out of range, which always decays
  regardless of light — moisture failure is a care failure, light failure
  alone is not, so it pauses rather than punishes.
- **If a creature's `spawn_conditions` oscillate true/false near the
  threshold** (e.g., true for 2 ticks, false for 1, true for 2 more): the
  consecutive-tick counter resets to `0` on any tick where the condition is
  false — partial runs never accumulate across a gap. This prevents a
  creature from spawning prematurely off flickering conditions.
- **If `growth_stage` is already at `max_stage` and moisture stays in range
  (MATURE)**: it holds steady regardless of light — via the GROWING branch
  (`clamp(max_stage + growth_rate, 0, max_stage) = max_stage`) if light is
  also in range, or via the STALLED branch (unchanged) if it isn't. Either
  way, no error, no further visible growth, and no risk of MATURE silently
  decaying just because light happens to be out of band that tick
  (corrected 2026-08-04 round 12 — see Formulas).
- **If a plant's authored `moisture_tolerance` range never overlaps with
  any achievable `jar_moisture` value** (a content-authoring error, not a
  runtime error — e.g., a range entirely above 100): the plant simply
  always decays. This is not auto-blocked at the data-validity level
  (Content Data's `definition_validity` only checks `min < max`, not
  reachability) because an intentionally hard-to-satisfy range could be a
  valid design choice (a "drought specialist" plant) — flagged as an
  authoring caution, not a hard rule.
- **If two plants cross their GROWING↔DECAYING threshold on the same tick**:
  each resolves independently — `jar_moisture` is a single shared read, and
  no plant's growth calculation depends on another plant's state, so
  simultaneity causes no ordering issue.
- **If a detail event's `optimal_hold_ticks` threshold is reached on a
  plant already at `max_stage`**: the detail event is independent of
  `growth_stage` and can still trigger — maturity doesn't gate rare visual
  variation.
- **(added 2026-08-03 `/design-review`) If `light_level` hits exactly `0` or
  `100`**: it clamps there for that tick and `light_direction` flips for
  the *next* tick — it never overshoots past the bound, and never gets
  stuck oscillating between two out-of-range values on the boundary itself.
- **(added 2026-08-03, corrected 2026-08-04 round 12) If a plant's
  `light_tolerance` range never overlaps with any achievable `light_level`
  value** (a content-authoring error, mirroring the existing moisture-range
  edge case above): the plant can **never GROW**, but its fate now depends
  on moisture — it is **STALLED (frozen, never decays)** whenever
  `jar_moisture` is in range, and **DECAYING** whenever moisture is also
  out of range. **This behavior changed under the round-12 three-state
  fix** — the pre-fix binary formula made this always decay regardless of
  moisture; that is no longer true, since light failing alone now stalls
  rather than decays. Not auto-blocked at the data-validity level for the
  same reason as the moisture case — an intentionally hard-to-satisfy range
  could be a valid "shade specialist" or "sun specialist" design choice,
  though under the new formula such a plant would be permanently frozen
  rather than slowly dying, which authors should be aware of.
- **(added 2026-08-03) `light_level` drift is never paused, reset, or
  affected by watering or any tending action** — it advances by
  `LIGHT_STEP_PER_TICK` every tick unconditionally, the same as
  `jar_moisture`'s decay is unconditional regardless of watering. This is
  the load-bearing property that keeps the system from getting
  permanently parked (Core Rule 8/9) — an implementation that gates
  `light_level`'s update on any player action would silently reopen the
  lockstep bug this variable exists to close.
- **(new 2026-08-09) If a creature has never had a live instance in this
  game's history** (its very first spawn-and-departure cycle completes
  entirely inside one catch-up batch, per Core Rule 13's `full_cycle`
  case): `last_known_position` is still `(0, 0)`, the jar-center default
  (Core Rule 12) — an honest "somewhere in the jar" approximation rather
  than a guessed real point, accepted as the rare-case cost of this fix,
  not a defect. This can only happen on a creature's first-ever residency;
  any subsequent departure benefits from a real recorded position, since
  Core Rule 12's write path runs on every live frame, not just at
  departure.
- **(new 2026-08-09) If a creature's departure resolves inside a catch-up
  batch that follows one or more *prior* sessions where it was live** (the
  dominant departure path this fix targets, per `N_departure_ticks=25`
  against Time & Drift's catch-up-only tick model): `last_known_position`
  holds whatever position it last had at the end of its most recent live
  session — genuinely real, not synthetic, even though no instance is ever
  spawned in *this* session. This is the primary case Core Rule 12 exists
  to solve.
- **(new 2026-08-09) If a creature spawns, departs, and re-spawns multiple
  times within one catch-up batch** (possible at `max_catchup_ticks=84`
  against `N_spawn_ticks=3`/`N_departure_ticks=25`): `was_present_during_batch`
  is a single OR'd boolean, not a count or log — it stays `true` after the
  first PRESENT tick regardless of how many additional cycles follow, and
  Discovery Surfacing still generates exactly one discovery item for that
  creature (Core Rule 2's existing "one item per element per batch"
  granularity, unchanged).

## Dependencies

Ecosystem Simulation depends on:
- **Content Data** (hard) — `PlantTypeDef`/`CreatureTypeDef` fields
  (`moisture_tolerance`, `growth_rate`, `decay_rate`, `spawn_conditions`)

Downstream dependents (all hard — none has a fallback path):
- **Tending Input** — calls `apply_watering(amount)`, applied immediately
  (round 14, see Core Rule 5)
- **Time & Drift** — calls `advance_tick()`
- **Creature Behavior** — reads creature PRESENT/ABSENT state; **also
  calls in** `set_last_known_position(creature_id, pos)` every live frame
  (new 2026-08-09, Core Rule 12) — Ecosystem Simulation still calls into
  no one, this is Creature Behavior calling into Ecosystem Simulation, the
  same direction Tending Input already uses
- **Persistence/Save** (added 2026-08-03, `/design-review`) — bidirectional
  read/write of `jar_moisture`, `growth_stage`, creature state, and now
  `light_level`/`light_direction` (see Formulas); this was a genuine
  bidirectionality gap — `persistence-save.md` already listed Ecosystem
  Simulation as a hard dependency, but this section didn't reciprocate.
  **Extended 2026-08-04, round 11**: also `optimal_hold_ticks` (per plant)
  and `condition_streak_ticks` (per creature, Core Rule 7a) — both are real
  per-instance state that was silently reset at every session boundary
  before this round, now persisted per `persistence-save.md`'s new
  blob-completeness principle. **Extended 2026-08-09**: also per-creature
  `last_known_position` (Core Rule 12) — persists across ABSENT gaps and
  session boundaries alike, unlike `persistence-save.md`'s existing
  PRESENT-only `creature_position` field, which this is deliberately kept
  separate from (see that document's own Core Rule 1/Formulas).
- **Discovery Surfacing** — reads state deltas since last visit
- **Diorama Rendering** (upgraded to hard blocking, round 13 — see
  Interactions with Other Systems) — reads `growth_stage`, creature
  presence, detail-event flags, `light_level`, and `jar_moisture` (must
  render a **per-plant** visual cue distinguishing STALLED from
  GROWING/DECAYING, minimum a per-plant desaturate/dim, before this
  system is implementation-complete — corrected round 14, a jar-wide
  tint alone does not satisfy this)

This is the largest fan-out of any system in the project (flagged as the
bottleneck in the systems index) — Discovery Surfacing remains provisional
until it is authored; Diorama Rendering is now authored (`diorama-rendering.md`,
2026-08-05) and its own Core Rule 3/Formulas implement this exact
requirement, closing this blocking dependency. Tending Input, Time & Drift,
Creature Behavior, and Persistence/Save all now correctly reciprocate this
dependency in their own Dependencies sections.

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `moisture_decay_rate` | 2–5/tick | Moisture barely drops — watering becomes irrelevant, jar feels static | Moisture crashes before the next visit — feels impossible to keep up with, reads as punishing |
| `watering_amount` | 15–30 | Watering feels ineffective, no visible feedback | A single watering maxes moisture instantly, removing any need for repeat care |
| plant `growth_rate` (per type) | 1–3/tick | Growth invisible between visits — defeats the core hypothesis | Growth completes in one visit — breaks the slow-drift pacing pillar |
| plant `decay_rate` (per type) | 1–4/tick | Nothing visibly decays — reduces discovery variety | Constant visible decay — reads as neglect/punishment |
| `moisture_tolerance` band width (per type) | ≥15 units | Plant dies from tiny moisture deviations — punishing | Plant never reacts to moisture changes — reads as static |
| `light_tolerance` band width (per type) | ≥15 units | Plant flickers in/out of range purely from light's own drift, unrelated to care — reads as arbitrary | Plant never reacts to light — light axis contributes nothing, reintroducing the moisture-only lockstep risk this variable exists to fix |
| `LIGHT_STEP_PER_TICK` | 3–8 | Light barely moves — a full sweep takes so long it's effectively static within a normal play window, weakening the anti-lockstep guarantee | Light swings wildly tick to tick — reads as flickery/random rather than a slow ambient drift |
| `N_spawn_ticks` | 2–5, **and must be ≤ the chosen `N_departure_ticks`** | Creature flickers in/out on noisy conditions | Creature takes too long to ever appear — the "discovery" moment gets delayed past the point of anticipation |
| `N_departure_ticks` | **Widened 2026-08-05 `/review-all-gdds`, `game-designer`/`systems-designer` finding (see Core Rule 7's correction) — was 4–8.** The old range was calibrated for "a debounce resolves within one visit," a goal that's right for spawning and wrong for departure: at any value in 4–8, departure resolves inside the same short absence (~7–12 ticks of moisture-exit, per `time-drift.md`'s own per-plant trace) that makes it eligible, guaranteeing both creatures depart on nearly any multi-day absence. New range: **10–30**, wide enough to require a genuinely multi-visit absence to resolve, **and must still be ≥ the chosen `N_spawn_ticks`**. **Retuned value picked, 2026-08-09 (required pre-implementation tuning pass — RESOLVED):** `N_departure_ticks=25`. Traced against `time-drift.md`'s per-plant moisture-exit ticks (Flower 6, Fern 7, Moss 12) and this document's own decay rates/thresholds, using `total_ticks_to_departure = first_false_tick + N_departure_ticks − 1`: **Moth** (`flower.growth_stage==max_stage`, a razor-thin condition — any single decay tick off `max_stage` breaks it, regardless of starting state) has a fixed first-false-tick of `6` (Flower's own exit tick, since Core Rule 11 resolves growth the same tick moisture exits), giving a deterministic `30` ticks total — the fastest possible departure path of either creature. **Snail** (`moss.growth_stage+fern.growth_stage≥6`, Fern exits first at tick 7, `decay_rate=1`) ranges from `31` ticks (sum starts exactly at the `6` threshold, crosses on Fern's very first decay tick) to `35` ticks (sum starts at its max of `10` — Moss `max_stage=4` + Fern `max_stage=6` — and takes 5 ticks of Fern-only decay, since Moss doesn't start decaying until tick 12, to cross below `6`). Both comfortably exceed a typical 1–2 day absence (`8–24` ticks, per `time-drift.md`'s own daily-visit calibration doubled) with real margin (`6`+ ticks / `12`+ hours beyond the top of that window, not a one-tick shave), and both sit well under `max_catchup_ticks=84` (`49` ticks of headroom on the slowest path), so a genuinely long multi-week absence — capped at 84 ticks regardless — still resolves departure within a single catch-up batch. `N_departure_ticks ≥ N_spawn_ticks` (2–5) holds trivially, since this constant's entire 10–30 range sits above `N_spawn_ticks`'s range ceiling of `5`. | Creature leaves too quickly after a brief dip — reads as fragile/punishing. **Confirmed concretely 2026-08-05**: the pre-correction default of 5 sat here, and resolved within a single weekend-length absence for both MVP creatures, unconditionally | Creature never leaves even when conditions are clearly gone, or takes so long that a real multi-week absence still shows the creature present when everything else in the jar has visibly moved on — breaks the "moving on" believability from the other direction |
| `p_detail` | 0.02–0.10 (baseline 0.05) | Rare details almost never trigger — risks the exact "untested at density" gap the prototype flagged | Details trigger too often — stop feeling rare/special, cheapens Pillar 4 |
| `optimal_hold_ticks` threshold | 5–15 (baseline 6, lowered from 10 in round 12 — see Formulas), **and must satisfy `threshold ≤ floor(light_tolerance_width / LIGHT_STEP_PER_TICK) + 1` for the chosen plant type (added round 13 — see below)** | Details trigger too easily, cheapening the reward | Details essentially never trigger within a normal session length. **Concrete defect found round 13, `systems-designer`**: at the legal minimum `light_tolerance` width of 15 (Content Data's own `LIGHT_BAND_MIN_WIDTH`) and the documented default `LIGHT_STEP_PER_TICK=5`, the longest achievable contiguous GROWING streak is `floor(15/5)+1=4` ticks — below this row's *entire* stated safe range floor of 5, making the "5–15" range structurally unreachable in full for any type authored at the legal minimum width, not merely a value to spot-check in isolation. |
| plant `growth_rate` (per type), spawn-reachability constraint | must be `> 0` for any spawn-condition threshold summing growth stages (e.g. Snail's `moss+fern≥6`) to stay reachable | A `growth_rate=0` (legal per Content Data's own validity gate, though outside this doc's 1–3 safe range) can make a dependent spawn threshold permanently unreachable | N/A — this constraint only has a "too low" failure mode |

**Both debounce constraints above state the same relationship from each
side** — `N_departure_ticks ≥ N_spawn_ticks` is intentional and load-bearing
(Core Rule 7); inverting it would make creatures leave faster than they
arrive, breaking the "settling in, then wandering off" read. **Not yet
enforced by any validity gate** (flagged 2026-08-04, round 12,
`systems-designer` — advisory, not blocking): unlike Content Data's
`definition_validity` pattern, nothing currently catches an individually
in-range but jointly invalid pair (e.g. `N_spawn_ticks=5,
N_departure_ticks=4`) at data-authoring time. Consider whether this belongs
in a future `spawn_debounce_validity` check alongside Content Data's own
gates, or is acceptable as a documented-only constraint at MVP's single
creature-pair scope.

## Visual/Audio Requirements

**Not fully N/A — corrected 2026-08-04 `/design-review`, round 15.** The
general rendering of growth stages, creature presence, and detail events
still belongs to Diorama Rendering, which consumes this system's state, and
ambient audio response (if any) is still owned by Ambient Audio. But this
GDD itself mandates one specific requirement that lives here, not there:
per Interactions with Other Systems and Dependencies, **a per-plant STALLED
state must be visually distinguishable from GROWING/DECAYING** (minimum a
per-plant desaturate/dim cue on the plant sprite while STALLED) — this is a
**hard blocking dependency** for this system to be considered
implementation-complete, not an optional polish item Diorama Rendering can
defer. See AC26. The exact full treatment (once Diorama Rendering's own GDD
and art pass land) is still that system's call; only the requirement that
STALLED be visibly distinct at all is locked here.

## UI Requirements

N/A — Ecosystem Simulation has no UI of its own. "What changed since last
visit" is surfaced by Discovery Surfacing, which reads this system's state
deltas.

## Acceptance Criteria

1. **GIVEN** `jar_moisture=50` with no watering, **WHEN** one tick advances,
   **THEN** `jar_moisture` becomes `47`.
2. **(rewritten 2026-08-04 `/design-review`, round 14 — watering and tick
   decay decoupled, see Core Rule 5/Formulas)** **GIVEN** `jar_moisture=50`,
   **WHEN** `apply_watering()` fires, **THEN** `jar_moisture` becomes `75`
   immediately — no tick required, and no decay applied in the same step.
3. **(rewritten 2026-08-04, round 14)** **GIVEN** `jar_moisture=95`, **WHEN**
   `apply_watering()` fires, **THEN** `jar_moisture` clamps to `100`
   immediately, not `120`.
4. **GIVEN** `jar_moisture=2` with no watering, **WHEN** the tick advances,
   **THEN** `jar_moisture` clamps to `0`, not negative.
4a. **(new, 2026-08-04, round 14 — closes the gap AC2/AC3's rewrite leaves:
   the old combined watering+decay-in-one-tick case had coverage, the new
   decoupled model needs its own)** **GIVEN** `jar_moisture=50`, **WHEN**
   `apply_watering()` fires and, separately, a tick later advances with no
   further watering, **THEN** `jar_moisture` is `75` immediately after the
   watering call, then `72` after the subsequent tick — confirming the two
   operations apply independently, in the order they actually occur, not as
   one combined per-tick formula.
5. **GIVEN** a Moss plant at `growth_stage=2` with `jar_moisture=50` (in
   its `[40,75]` range) **and** `light_level=50` (in its `[20,60]` range),
   **WHEN** one tick advances, **THEN** `growth_stage` becomes `3`.
   **(updated 2026-08-03 `/design-review`)** — `light_level` is now a
   required second condition; see AC5a for the case where moisture alone
   is satisfied but light is not.
5a. **(rewritten 2026-08-04 `/design-review`, round 12 — was blocking: the
   prior version's stated outcome, "decreases to 1," did not match
   Moss's own `decay_rate=2` (`clamp(2-2,0,4)=0`, not `1`), confirmed
   independently by `game-designer`, `systems-designer`, and `qa-lead`.
   The round-12 formula fix also changes what this criterion demonstrates:
   light-out-of-range with moisture-in-range no longer decays at all, it
   STALLS.)** **GIVEN** a Moss plant at `growth_stage=2` with
   `jar_moisture=50` (in range) **but** `light_level=90` (outside its
   `[20,60]` range), **WHEN** one tick advances, **THEN** `growth_stage`
   **remains at `2`** (STALLED — neither grows to `3` nor decays) — an
   in-range moisture reading alone is no longer sufficient to grow, but it
   is sufficient to avoid decaying.
6. **GIVEN** a Moss plant at `growth_stage=1` with `jar_moisture=90` (out
   of its `[40,75]` range, `decay_rate=2`), **WHEN** one tick advances,
   **THEN** `growth_stage` clamps to `0`, not `-1`, **regardless of
   `light_level`** (moisture failure alone triggers DECAYING under the
   round-12 three-state formula — this criterion's outcome holds for any
   light value, not just a specific one). **(updated 2026-08-03
   `/design-review`)** — this criterion previously used Flower
   (`decay_rate=4`); Flower's `decay_rate` was retuned to `1` in this same
   review (see Formulas — the old value one-tick-wiped it, an anti-pillar
   violation), so it no longer demonstrates a clamp-to-zero in one tick.
   Moss's `decay_rate=2` from `growth_stage=1` now serves this criterion's
   original purpose instead.
7. **GIVEN** a plant at `growth_stage=max_stage` with moisture in range,
   **WHEN** the tick advances, **THEN** `growth_stage` remains at
   `max_stage`, **regardless of `light_level`**. **(clarified 2026-08-04
   `/design-review`, round 12 — `qa-lead` flagged that under the prior
   binary formula this criterion's Given was ambiguous, since light out of
   range would have decayed a MATURE plant off `max_stage` despite this AC
   only pinning moisture. The round-12 three-state fix resolves this at the
   formula level rather than the AC level: light failing alone now STALLS,
   never decays, so "moisture in range" is sufficient on its own again —
   this criterion's original wording was correct all along under the
   corrected formula.)**
8. **GIVEN** Snail's `spawn_conditions` become true, **WHEN** they remain
   true for `3` consecutive ticks, **THEN** Snail transitions ABSENT →
   PRESENT on the 3rd tick.
9. **GIVEN** Snail's `spawn_conditions` are true for 2 consecutive ticks
   then false, **WHEN** the condition fails on tick 3, **THEN** Snail
   remains ABSENT and the counter resets to `0`.
10. **GIVEN** Snail is PRESENT and Flower reaches `max_stage`, **WHEN** this
    occurs, **THEN** Moth's `spawn_conditions` evaluate true.
11. **GIVEN** Flower reaches `max_stage` but Snail is ABSENT, **WHEN** this
    occurs, **THEN** Moth's `spawn_conditions` evaluate false regardless of
    Flower's state.
12. **(concrete value locked 2026-08-09, required tuning pass — see Tuning
    Knobs)** **GIVEN** a creature is PRESENT and its `spawn_conditions`
    fail, **WHEN** they remain false for `N_departure_ticks` (`25`)
    consecutive ticks, **THEN** the creature transitions PRESENT → ABSENT
    on the 25th tick.
13. **(updated 2026-08-04 `/design-review`, round 12 — threshold 10→6, see
    Formulas)** **GIVEN** a plant's `optimal_hold_ticks=5`, **WHEN** the
    tick advances (making it `6`), **THEN** `p_detail` transitions from `0`
    to `0.05` for that plant on that tick — a deterministic gate test, not
    a probability assertion.
13a. **(new, 2026-08-04 `/design-review`, round 12, `qa-lead` finding,
    `creative-director`-adopted — testability fix)** The detail-event roll
    itself must be a pure, dependency-injected function
    (`should_trigger_detail(roll: float, p_detail: float) -> bool`) per
    `coding-standards.md`'s "all public methods must be unit-testable"
    rule — an engine-seeded-RNG statistical pass would otherwise conflict
    with that same document's "no random seeds" testing rule, which is why
    AC13's original statistical-QA-pass note was deferred unresolved for 3
    prior review rounds. **GIVEN** `p_detail=0.05` and an injected
    `roll=0.049`, **WHEN** `should_trigger_detail` is evaluated, **THEN**
    it returns `true` (fires).
13b. **(new, 2026-08-04, round 12)** **GIVEN** `p_detail=0.05` and an
    injected `roll=0.05`, **WHEN** `should_trigger_detail` is evaluated,
    **THEN** it returns `false` (does not fire) — confirms the roll
    comparison's boundary is exclusive on the high end (`roll < p_detail`,
    not `≤`).

*(The prior deferred "statistical QA pass — 1000+ ticks, expecting observed
detail-trigger frequency in the 3–7% band" is demoted from a blocking
automated criterion to a manual/smoke-test tuning-pass item — it validates
*feel density* against the real RNG, not correctness of the gate logic,
which AC13/13a/13b now cover deterministically. See the required
pre-implementation tuning pass logged in Open Questions.)*
14. **(updated 2026-08-04 `/design-review`)** **GIVEN** a plant's
    `optimal_hold_ticks=7` and moisture then leaves its tolerance range
    (light unchanged, still in range), **WHEN** this occurs, **THEN**
    `optimal_hold_ticks` resets to `0` — moisture leaving range takes the
    plant out of the strict GROWING state (moisture AND light both in
    range) that gates this counter, into DECAYING (round 12: not STALLED —
    moisture failure decays regardless of light, see Formulas).
14a. **(new, 2026-08-04, `systems-designer` finding)** **GIVEN** a plant's
    `optimal_hold_ticks=7` with moisture still in range but light then
    leaves its tolerance range, **WHEN** this occurs, **THEN**
    `optimal_hold_ticks` resets to `0` — confirming the reset is keyed to
    the strict GROWING state (moisture AND light both in range), not
    moisture alone, even though this specific case now transitions the
    plant to STALLED rather than DECAYING (round 12) — hold-ticks require
    active growth, not merely the absence of decay. An implementation that
    only checks moisture fails this criterion by continuing to accumulate
    `optimal_hold_ticks` on a plant that is only stalled, not growing.
15. **(rewritten 2026-08-03 `/design-review`)** **GIVEN** `jar_moisture=88`
    and `light_level=75` with all three plant types present, **WHEN** one
    tick advances, **THEN** Moss `growth_stage` decreases by `2` (moisture
    88 is outside its `[40,75]` range), Fern `growth_stage` increases by
    `1` (moisture 88 and light 75 both inside its `[55,90]`/`[40,80]`
    ranges), and Flower `growth_stage` increases by `2` (moisture 88 and
    light 75 both inside its `[60,90]`/`[55,95]` ranges) — three distinct
    simultaneous outcomes from one `(moisture, light)` pair, directly
    verifying the possibility-space depth requirement (Core Rule 8/9). The
    original version of this criterion (`jar_moisture=50` alone, before the
    `light_level` fix) no longer demonstrates three distinct deltas now
    that Flower's `decay_rate` matches Fern's — this replacement point was
    chosen specifically to still exercise three different outcomes under
    the retuned values.
16. **(new, 2026-08-03 `/design-review`, mirrors AC9 for the departure
    side — `qa-lead` finding; concrete value locked 2026-08-09, required
    tuning pass — see Tuning Knobs)** **GIVEN** a creature is PRESENT and
    its `spawn_conditions` are false for `N_departure_ticks - 1` (`24`)
    consecutive ticks, **WHEN** the condition becomes true again on the
    next tick, **THEN** the creature remains PRESENT and the departure
    counter resets to `0` — a partial departure run never accumulates
    across a gap, mirroring AC9's spawn-side guarantee.
17. **(new, 2026-08-03, `qa-lead` finding)** **GIVEN** a plant with
    `moisture_tolerance_min=110, moisture_tolerance_max=120` (an
    authoring-error range outside any achievable `jar_moisture`, per Edge
    Cases), **WHEN** a tick advances at any `jar_moisture` in `[0,100]`,
    **THEN** `growth_stage` always decreases (never grows), regardless of
    `light_level` — moisture failing alone always triggers the DECAYING
    branch, unconditional on light (round 12: this is unchanged by the
    three-state fix, since only light-alone-failing became non-punishing,
    not moisture-alone-failing).
17a. **(new, 2026-08-04 `/design-review`, round 12, `qa-lead` finding —
    mirrors AC17 for the light-side unreachable-range edge case, which had
    Edge Cases coverage but no AC)** **GIVEN** a plant with
    `light_tolerance_min=110, light_tolerance_max=120` (an authoring-error
    range outside any achievable `light_level`) and `jar_moisture` within
    the plant's moisture range, **WHEN** a tick advances at any
    `light_level` in `[0,100]`, **THEN** `growth_stage` **remains
    unchanged** (STALLED, never grows) — this is deliberately NOT the same
    outcome as AC17: an unreachable *light* range freezes the plant rather
    than decaying it, since moisture is satisfied and only light is failing.
18. **(new, 2026-08-03, light mechanic)** **GIVEN** `light_level=50` and
    `light_direction=+1`, **WHEN** one tick advances, **THEN**
    `light_level` becomes `55` and `light_direction` remains `+1`.
19. **(new, 2026-08-03)** **GIVEN** `light_level=98` and
    `light_direction=+1`, **WHEN** one tick advances (step `5` would give
    `103`), **THEN** `light_level` clamps to `100` and `light_direction`
    flips to `-1`.
20. **(new, 2026-08-03)** **GIVEN** `light_level=2` and
    `light_direction=-1`, **WHEN** one tick advances (step `5` would give
    `-3`), **THEN** `light_level` clamps to `0` and `light_direction` flips
    to `+1` — the paired boundary to AC19, confirming both ends clamp and
    flip symmetrically.
21. **(new, 2026-08-04 `/design-review`, round 12, `qa-lead` finding —
    boundary pair for `in_range`'s inclusive bound, following this
    project's own established house style)** **GIVEN** a Moss plant with
    `light_level` in range and `jar_moisture=40` (exactly its
    `moisture_tolerance_min`), **WHEN** one tick advances, **THEN**
    `growth_stage` grows (the boundary itself is in-range, inclusive) —
    paired with `jar_moisture=39`, **WHEN** one tick advances, **THEN**
    `growth_stage` decays (one unit outside the boundary), confirming the
    inclusive/exclusive edge.
22. **(new, 2026-08-04, round 12, `qa-lead` finding — N-1/N boundary pair
    for the debounce counters; concrete value locked 2026-08-09, required
    tuning pass — see Tuning Knobs)** **GIVEN** Snail's `spawn_conditions`
    are true for `2` consecutive ticks (`N_spawn_ticks=3`), **WHEN** the
    2nd tick resolves, **THEN** Snail remains ABSENT (has not yet reached
    the 3rd consecutive tick) — paired with AC8, which confirms the 3rd
    tick does transition it. Mirrors for departure: **GIVEN** a PRESENT
    creature's `spawn_conditions` are false for `N_departure_ticks - 1`
    (`24`) consecutive ticks, **WHEN** that tick resolves, **THEN** the
    creature remains PRESENT — paired with AC12, which confirms the 25th
    tick does transition it.
23. **(new, 2026-08-04, round 12 — closes an Edge Cases gap: "detail event
    can fire at max_stage" had no AC)** **GIVEN** a plant at
    `growth_stage=max_stage` with `optimal_hold_ticks` reaching the `6`-tick
    threshold, **WHEN** the tick advances, **THEN** `p_detail` still
    transitions to `0.05` — maturity does not gate the rare-bloom mechanic.
24. **(new, 2026-08-04, round 12 — closes an Edge Cases gap: "light drift
    unaffected by watering" had no AC; updated 2026-08-04 round 14 for the
    decoupled watering model)** **GIVEN** `light_level=50`,
    `light_direction=+1`, and `apply_watering()` also fires (live,
    independent of the tick), **WHEN** the tick advances, **THEN**
    `light_level` still becomes `55` exactly as in AC18 — the watering
    action affects only `jar_moisture`, never `light_level` or
    `light_direction`, regardless of whether it fired before, during, or
    after the tick.
25. **(new, 2026-08-04 `/design-review`, round 13, `systems-designer`
    finding — tests Core Rule 11's tick evaluation order)** **GIVEN** Snail
    is PRESENT at the start of tick T, its `spawn_conditions` are false and
    its departure debounce reaches `N_departure_ticks` **on tick T**
    (transitioning Snail PRESENT → ABSENT during tick T's creature pass),
    **AND** Flower independently reaches `max_stage` on that same tick,
    **WHEN** Moth's `spawn_conditions` evaluate during tick T's creature
    pass, **THEN** Moth reads Snail as **PRESENT** (its state at the start
    of tick T), not the ABSENT state Snail transitions to later in that
    same tick — Moth's spawn debounce counter increments as if Snail were
    still PRESENT for tick T, confirming creature-state reads use
    previous-tick values regardless of same-tick transitions.
26. **(new, 2026-08-04 `/design-review`, round 15, `qa-lead` finding —
    closes the gap where the STALLED visual-cue hard blocking dependency
    had no checkable criterion at all)** **GIVEN** a plant in the STALLED
    state (moisture in range, light out of range), **WHEN** it is rendered
    (via the mandated interim per-plant fallback or Diorama Rendering's
    eventual full treatment), **THEN** it is visually distinguishable from
    both GROWING and DECAYING — verified via screenshot evidence per this
    project's Visual/Feel test-evidence standard (`coding-standards.md`),
    referenced in this story's Definition of Done. This is the sole
    ADVISORY-gate criterion in this list; AC1–25 remain BLOCKING/automated
    per the Logic story type. Without this criterion, nothing in the
    checkable Acceptance Criteria stopped a programmer marking this story
    Done with the fallback unbuilt, even though Visual/Audio Requirements
    and Dependencies both call it blocking.
27. **(new, 2026-08-09, `/review-all-gdds` cross-GDD finding — Core Rule
    12)** **GIVEN** a creature that has never had a live instance, **WHEN**
    `last_known_position` is queried, **THEN** it returns `(0, 0)`, the
    jar-center default — not null, not an error.
28. **(new, 2026-08-09, Core Rule 12)** **GIVEN** Creature Behavior calls
    `set_last_known_position(Snail, (34.2, -11.6))`, **WHEN**
    `last_known_position` is subsequently queried for Snail, **THEN** it
    returns `(34.2, -11.6)` — confirms the write path updates the stored
    value directly, with no transformation or clamping applied by
    Ecosystem Simulation itself.
29. **(new, 2026-08-09, Core Rule 12)** **GIVEN** `last_known_position` was
    last set to `(34.2, -11.6)` for a creature, **WHEN** that creature
    later transitions PRESENT→ABSENT entirely within a catch-up batch (no
    live instance this session, per `creature-behavior.md` Core Rule 8),
    **THEN** `last_known_position` remains `(34.2, -11.6)`, unchanged by
    the transition itself — only a live write updates it.
30. **(new, 2026-08-09, Core Rule 13)** **GIVEN** a creature is ABSENT at
    a catch-up batch's start, transitions to PRESENT on tick 10 of the
    batch, then back to ABSENT on tick 33 of the same batch (batch-end
    state ABSENT, matching batch-start state), **WHEN**
    `was_present_during_batch` is queried at batch end, **THEN** it is
    `true` — even though the net PRESENT/ABSENT delta is unchanged.
31. **(new, 2026-08-09, Core Rule 13)** **GIVEN** a creature remains
    ABSENT for every tick of a catch-up batch, **WHEN**
    `was_present_during_batch` is queried at batch end, **THEN** it is
    `false`.
32. **(new, 2026-08-09, Core Rule 13)** **GIVEN** a new catch-up batch
    begins, **WHEN** it starts, **THEN** `was_present_during_batch` resets
    to `false` for every creature regardless of its value at the end of
    the previous batch.

*(`qa-lead` consulted — flagged that the possibility-space depth requirement
had zero test coverage and that the original detail-event criterion was
non-deterministic (a single run can't assert a 5% probability); both fixed
above. Re-consulted round 12 for AC5a/AC6/AC7/AC13 corrections and ACs
17a/21/22/23/24, see the round-12 review note below.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `creative-director`.
Verdict: NEEDS REVISION → all blocking items resolved above.
**Possibility-space depth mechanism replaced**: `game-designer` and
`systems-designer` independently found the moisture-only staggered-bands
design (Core Rule 8) failed on its own terms — one shared, player-controlled
scalar can't produce real depth, and the specific MVP bands mathematically
collapsed into a shared lockstep zone (`moisture ∈ [65,75]` put all three
plants in GROWING at once). `creative-director` ruled the fix: a new,
independent, non-player-controllable `light_level` variable (Core Rule 9,
Formulas), restoring the light-driven growth already scoped in
`game-concept.md`'s MVP Definition but silently dropped from this GDD.
Explicitly not fixed via randomness (rejected — would trade "static" for
"random/illegible," the prototype's other flagged failure mode). **Flower
retuned**: `decay_rate` 4→1, moisture band widened 65–85→60–90 —
`game-designer` flagged the old value as a direct one-tick-wipe anti-pillar
violation ("NOT punishing"), not a defensible tuning extreme.
**Bidirectional-dependency gap fixed**: Persistence/Save added to Downstream
dependents (it already listed this system as a hard dependency; this
section didn't reciprocate). **Type drift fixed**: `jar_moisture`'s `int`
type made explicit in the registry after `systems-designer` found
`persistence-save.md` typed the same value as `float` (fixed there, this
doc's `int` typing confirmed as the source of truth). **AC gaps closed**
(`qa-lead`): AC16 added to mirror AC9's spawn-flicker-reset test for
departure/`N_departure_ticks` (previously zero coverage on that path); AC17
added to test the "unreachable tolerance band" edge case (previously
narrative-only); AC5/6/15 rewritten for the new light-dependent formula;
AC18–20 added for the new `light_level` tick formula's boundary behavior.
Two `qa-lead` findings intentionally not addressed this pass, tracked
instead: AC13's statistical detail-event pass remains underspecified
(seed/methodology/sample-size), and no explicit boundary-pair AC exists for
the inclusive in-range check or N-minus-1 debounce boundaries — both
lower-severity than the blocking items above, deferred to a future pass
rather than expanding this revision's scope further.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — full specialist round
across content-data.md, ecosystem-simulation.md, persistence-save.md,
object-placement.md as a set: `game-designer`, `systems-designer`,
`qa-lead`, `godot-specialist`, `creative-director`. Verdict: NEEDS REVISION
→ 2 blockers resolved below. **`light_level` visibility contract added**
(Interactions): `game-designer` found `light_level` co-equally gates every
plant's growth yet had no player-visible representation anywhere — not read
by Diorama Rendering, deliberately decoupled from Time & Drift's cosmetic
cycle — directly undercutting this GDD's own legibility-focused Player
Fantasy. `creative-director` ruled this is not new scope (`game-concept.md`'s
visual principle 3 already commits to "lighting communicates... more than
UI does") and locked the requirement that Diorama Rendering must render
`light_level` visibly, deferring only the exact visual treatment. **Detail
Event formula corrected**: `systems-designer` found `optimal_hold_ticks`
still reset only on moisture leaving range, unchanged since before
`light_level` existed — since growth itself now requires moisture AND light
in range, a plant could accumulate hold-ticks toward a "rare bloom" while
actually DECAYING from light alone, a Pillar 4 legibility violation.
Corrected to key off the same `in_range` boolean the growth formula uses;
AC14 updated and AC14a added to test the light-only reset path.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 11, full
specialist round across content-data.md, ecosystem-simulation.md,
persistence-save.md, object-placement.md as a set: `game-designer`,
`systems-designer`, `qa-lead`, `godot-specialist`, `creative-director`.
Verdict: NEEDS REVISION → 1 blocker resolved below (this document's own
content), with a companion fix landing in `persistence-save.md`.
**Debounce counter named and marked persisted (new Core Rule 7a)**:
`game-designer`/`qa-lead`/`systems-designer` independently found this
document's own per-creature spawn/departure debounce counter (behind Core
Rules 6/7) was never named as a distinct variable and — because it lived
only in `persistence-save.md`'s blind spot, not this document's own
Formulas — was silently reset at every session boundary, making
`N_spawn_ticks`/`N_departure_ticks` unreachable (not just slower) for a
frequent-short-visit play pattern. Named `condition_streak_ticks` and
inserted as Core Rule 7a (not renumbered as 8, to avoid disturbing the
existing Core Rule 8/9/10 numbering other GDDs cross-reference by number).
`optimal_hold_ticks`'s Formulas variable row updated to note it is now
also persisted, for the same reason. Both fields now round-trip through
`persistence-save.md`'s save blob under that document's new
blob-completeness principle — see that GDD's own round-11 review note for
the full rationale. This document's Dependencies section updated to
reciprocate.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 12, full
specialist round: `game-designer`, `systems-designer`, `qa-lead`,
`creative-director`. Verdict: NEEDS REVISION → all 5 blockers resolved
below (user confirmed "revise now" and adopted `creative-director`'s
proposed formula fix over the tuning-only alternative). **AC5a corrected**
(unanimous finding, all three specialists independently confirmed the same
arithmetic): stated outcome "decreases to 1" didn't match Moss's own
`decay_rate=2` — correct value is `0`. **Plant Growth Delta formula
redesigned from binary to three-state** (`game-designer`/`systems-designer`
finding, `creative-director` ruling): tracing a full 40-tick `light_level`
cycle showed the prior binary AND-gated formula decay-biases Moss and Fern
even under flawless player moisture care, purely from the light cycle's own
duty cycle (all 3 MVP plants have width-40 light bands, so light sits
out-of-band ~60% of ticks regardless of player action) — a real Anti-Pillar
violation (punished for something invisible and uncontrollable), not a
tuning risk. Fixed by splitting growth into three states: GROWING (both
bands satisfied), STALLED (moisture ok, light not — frozen, no change),
DECAYING (moisture failing, regardless of light) — light failing alone now
pauses rather than reverses growth. This also resolved AC7's
qa-lead-flagged ambiguity for free (MATURE-hold is now correct as
originally written, since STALLED also holds at max). **Detail Event
threshold lowered 10→6** (`game-designer` finding): at the documented
default `LIGHT_STEP_PER_TICK=5`, the longest possible contiguous GROWING
streak for any of the 3 MVP plants' width-40 light bands is 9 ticks — one
short of the old 10-tick gate, making the "rare bloom" mechanic
mathematically dead content at the documented default for every MVP plant
type, unconditionally. **AC13 rewritten for testability** (`qa-lead`
finding, adopted with modification): the deferred statistical detail-event
test (3 rounds unresolved) directly conflicts with `coding-standards.md`'s
own "no random seeds" rule; replaced with a DI'd `should_trigger_detail(roll,
p_detail)` pure function and two deterministic boundary ACs (13a/13b); the
statistical density check is demoted to a manual tuning-pass item (see new
Open Question below) rather than a blocking automated criterion.
**Light-tolerance-unreachable Edge Case corrected**: its old text ("always
decays") no longer held once light-alone-failing stopped decaying — updated
to STALLED-when-moisture-ok, DECAYING-when-moisture-also-fails; new AC17a
added (previously only the moisture-side mirror, AC17, existed). **5 more
qa-lead/systems-designer advisories folded in per `creative-director`'s
recommendation** ("cheap, house-style-expected, take them in the same
pass"): boundary-pair ACs 21 (in_range inclusive boundary) and 22 (debounce
N-1 boundary), AC23 (detail event at max_stage), AC24 (light drift
unaffected by watering), and the `N_departure_ticks ≥ N_spawn_ticks`
invariant + `growth_rate=0` reachability risk folded into the Tuning Knobs
table (previously prose-only, not gated by any validity check — still not
gated after this round, flagged as a possible future `spawn_debounce_validity`
addition, not blocking at MVP's single-creature-pair scope). **Two
nice-to-have corrections**: Interactions with Other Systems table was
missing a Persistence/Save row despite the Dependencies section describing
a full bidirectional relationship — added. Core Rule 7a's justification for
its own numbering claimed cross-references from `persistence-save.md` and
`input-abstraction.md` that, on inspection, don't actually exist by that
name (only `content-data.md` genuinely does) — corrected to name only the
real one. **One item intentionally NOT resolved this round** (see Open
Questions): `qa-lead` rated AC7's original ambiguity BLOCKING;
`creative-director`'s synthesis implicitly treated it as part of the
"cheap fixes" batch without an explicit severity ruling. The disagreement
is moot in practice (AC7 needed no edit — the formula fix resolved it
structurally) but is logged here since it was surfaced to the user as an
open disagreement during this review round and not explicitly adjudicated.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 13, full
specialist round: `game-designer`, `systems-designer`, `qa-lead`,
`creative-director`. Verdict: NEEDS REVISION → all 4 blockers resolved
below (user confirmed "revise now"). **`light_level` visibility upgraded to
a hard blocking dependency** (Interactions, Dependencies): `game-designer`
found STALLED and DECAYING currently render identically, silently
reopening the same anti-pillar ambiguity round 12's formula fix closed at
the mechanical level. Diorama Rendering is no longer provisional for this
system — a minimal jar-wide `light_level`-driven tint is now a mandated
interim fallback so STALLED is never invisible before Diorama Rendering's
own GDD and art land. **Pre-implementation tuning-pass exit criterion
corrected** (Open Questions): `systems-designer` found the existing
"hold moisture perfectly" trace methodology structurally guarantees zero
DECAYING ticks, so it could never catch a decay-side bug — split into two
required trace arms, one perfect-moisture and one realistic/imperfect.
**`optimal_hold_ticks` reachability constraint made explicit** (Tuning
Knobs): `systems-designer` found the legal-minimum `light_tolerance` width
(15) caps the achievable GROWING streak at 4 ticks, below this row's
entire stated 5–15 safe range — the prose "check this" caution replaced
with the actual formula constraint. **Tick evaluation order specified**
(new Core Rule 11, new AC25): `systems-designer` found no defined order
between plant and creature resolution within a tick, leaving Moth's
same-tick read of Snail's live state implementation-defined on the exact
tick Snail's departure debounce resolves — resolved as plants-then-
creatures, with all cross-creature state reads using previous-tick values.
**Recommended items deferred, not addressed this round** (user scoped this
revision to blocking items only): `growth_rate=0`/`decay_rate=10`
floor-lock risk and the Fern-max_stage/Snail-threshold coincidence
(`systems-designer`); zero AC coverage for the same-tick multi-plant
independence edge case and the DORMANT-via-STALLED-at-`growth_stage=0`
claim (`qa-lead`); reframing `light_level` explicitly as an anti-parking
mechanism rather than a depth mechanism, with "does the jar still create
anticipation at cycle 20?" logged as a vertical-slice exit question
(`creative-director`). Tracked for a future pass.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 14, full specialist
round: `game-designer`, `systems-designer`, `qa-lead`, `creative-director`.
Verdict: NEEDS REVISION → all 3 blockers resolved below (user scoped this
revision to blocking items only, deferring the recommended items listed at
the end of the round-13 note above). **Watering/tick contradiction fixed**
(Core Rule 5, Formulas, AC2/AC3/new AC4a, AC24): `game-designer` found
`tending-input.md` Core Rule 3's claim that watering "applies at the next
tick boundary" was literally false against `time-drift.md`'s own state
machine, since ticks never fire live during an ACTIVE session — meaning a
mid-session watering action would have had zero visible effect until the
next session, contradicting this GDD's own "reacts quickly to tending"
claim and the Player Fantasy's legibility promise. `creative-director`
ruled: watering is now a live, immediate mutation of `jar_moisture`, fully
decoupled from the tick cycle; decay remains exclusively tick-driven.
`tending-input.md` Core Rule 3 corrected to match in the same pass (see that
GDD's own review note). **STALLED interim fallback corrected to per-plant**
(Interactions, Dependencies): `game-designer` found round 13's mandated
jar-wide color-temperature tint didn't actually satisfy round 13's own
requirement that STALLED be distinguishable from DECAYING — a global tint
doesn't communicate any individual plant's state. Corrected to a per-plant
desaturate/dim cue keyed to that plant's own STALLED status; the jar-wide
tint may still ship alongside it for ambient mood but no longer substitutes
for it. **Pre-implementation tuning-pass gate given a numeric exit bar**
(Open Questions): `qa-lead` found the gate's exit criteria were
unfalsifiable as worded — "isn't punished" and "stays reachable" had no
threshold, and the perfect-moisture trace arm could structurally never fail
in the first place. Added concrete numbers: net `growth_stage` change `≥ 0`
per plant type under the perfect-moisture arm; Snail's `≥6` spawn threshold
must actually be reached within 40 ticks under the imperfect-moisture arm,
with a failing result requiring a value change, not a pass-anyway note.
**One disagreement adjudicated, not silently resolved**: `game-designer`
also argued the deterministic `light_level` triangle wave doesn't fix the
prototype's "fully discovered in 5–10 cycles" finding, just moves the
discovery-fatigue point to roughly cycle 15–20 once a player memorizes the
40-tick period, and that this should gate implementation rather than stay a
deferred vertical-slice question. `creative-director` declined to escalate:
deterministic light was a deliberate prior ruling (RNG was explicitly
rejected in an earlier round), the concern is playtest-measurable rather
than a spec defect, and a cheap known lever exists if it proves true (a
per-plant `light_phase_offset`) — logged as a pre-identified fix to measure
at vertical slice, not blocking. **Recommended items still deferred, not
addressed this round** (unchanged from round 13's list, user re-confirmed
blocking-only scope): `growth_rate=0`/`decay_rate=10` floor-lock risk and
the Fern-max_stage/Snail-threshold coincidence; zero AC coverage for the
same-tick multi-plant independence edge case and the
DORMANT-via-STALLED-at-`growth_stage=0` claim; reframing `light_level`
explicitly as an anti-parking mechanism in Core Rule 8's own prose (the
disagreement above already established this framing is correct, just not
yet written back into Core Rule 8 itself); a light-tolerance-band
grid-alignment caveat on the detail-event streak formula and a
`growth_rate=0`-is-asymmetric correction to the spawn-reachability Tuning
Knobs row (both `systems-designer`, newly surfaced this round). Tracked for
a future pass.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 15, full specialist
round: `game-designer`, `systems-designer`, `qa-lead`, `creative-director`.
Verdict: NEEDS REVISION → the 1 blocker resolved below (user scoped this
revision to blocking items only). **STALLED visual-cue requirement made
enforceable** (Visual/Audio Requirements, new AC26): `game-designer` and
`qa-lead` independently converged on the same underlying gap from two
angles — the section literally titled Visual/Audio Requirements still said
"N/A" despite Interactions/Dependencies declaring the per-plant STALLED cue
a hard blocking dependency (round 13/14), and separately, none of AC1–25
touched rendering at all, so nothing checkable would have stopped this
story being marked Done with the fallback unbuilt. `creative-director`
ruled both symptoms are one issue and fixed it as a two-line, zero-decision
edit: Visual/Audio Requirements now states the requirement instead of "N/A"
and cross-links to Interactions/Dependencies; new AC26 makes it a checkable
(ADVISORY, screenshot-evidence) criterion referenced in this story's
Definition of Done. **One proposal rejected, not deferred**:
`game-designer` proposed superimposing two coprime-period light waves
(e.g. 40+17 ticks) as a cheaper alternative to the already-identified
`light_phase_offset` lever for the light-cycle-memorization risk.
`creative-director` rejected it outright rather than tracking it — a second
wave would break the `floor(light_band_width / LIGHT_STEP_PER_TICK) + 1`
streak-ceiling formula rounds 12–13's detail-event threshold (6) depends
on, reopening settled math to pre-empt an unmeasured problem;
`light_phase_offset` remains the designated lever, with coprime periods
only a fallback if it proves insufficient at vertical slice. **Recommended
items deferred, not addressed this round** (user scoped this revision to
blocking-only): a canonical 40-tick moisture/light input fixture for the
pre-implementation tuning pass's imperfect-moisture arm, so it's
reproducible rather than trace-author-dependent (`qa-lead`); the
`optimal_hold_ticks`/`light_tolerance` Tuning Knobs cross-row inconsistency
at the legal-minimum band width, confirmed non-blocking for current
width-40 MVP data (`systems-designer`); cleanup of the Detail Event
worked example's two stitched-together leftover fragments
(`systems-designer`); Flower's light-band ceiling-asymmetry note
(`systems-designer`, nice-to-have). Tracked for a future pass.)*

*(Reviewed via `/review-all-gdds` on 2026-08-05 — round 16, holistic
cross-GDD consistency and design-theory pass across all 8 approved MVP
GDDs. Verdict on the pass: FAIL; this document's own 2 blockers resolved
below, same session, no formal specialist re-review round (user
decision). **Overview's stale "watering nudges growth" claim corrected**
(`game-designer`/`systems-designer` finding): this predated Core Rule 5's
own round-14 fix fully decoupling watering from ticks and was never
updated afterward — growth only ever changes on a tick, and ticks never
fire live during an ACTIVE session (`time-drift.md` Core Rule 6), so
watering's live payoff is moisture-only; growth is a next-visit payoff.
Corrected to state this accurately rather than promise same-session
growth feedback the mechanics don't deliver. **Creature-departure-on-
absence Anti-Pillar conflict resolved structurally** (Core Rule 7,
Debounce constants, Tuning Knobs, Open Questions, ACs 12/16/22 —
`game-designer`/`systems-designer` finding, `creative-director` ruling:
user selected decoupling departure's debounce speed from spawn's over a
fast-recovery mechanic or documenting the outcome as intentional): traced
concretely, `N_departure_ticks=5` — tuned so a debounce resolves within
one visit, a goal correct for spawning but not for departure — meant
departure resolved inside the same ~40–48-hour absence that made it
possible in the first place, guaranteeing both MVP creatures depart on
nearly any multi-day absence with zero player mitigation. This directly
tripped the Anti-Pillar (NOT punishing) despite Core Rule 7's own "moving
on, not punishment" framing, since a guaranteed, repeatable, unavoidable
outcome is not one of several possible "different" states. Fixed
structurally: `N_departure_ticks`'s safe range widened 4–8 → 10–30, with
the exact retuned value deliberately deferred to a new required
pre-implementation tuning pass (Open Questions) rather than guessed here
— same structural-rule-now/number-later split this document already used
for the `optimal_hold_ticks` threshold. `N_spawn_ticks` and its own 2–5
range are unaffected; only the assumption that both constants should
share one "resolves within a visit" design goal was corrected. ACs
12/16/22 rewritten to reference `N_departure_ticks` symbolically rather
than the pre-correction literal `5`, flagged for a concrete-number pass
once tuning completes — as is `persistence-save.md`'s `CONDITION_STREAK_MAX`
constant, whose own coupling to this value was already tracked as an Open
Question on that document's side before this round.)*

## Open Questions

- **Required pre-implementation tuning pass** (new, 2026-08-04, round 12,
  `creative-director` ruling — BLOCKING gate before implementation begins,
  not before this GDD's approval): the round-12 formula redesign (three-state
  grow/stall/decay) and threshold change (10→6) fix the confirmed defects,
  but nobody has traced the *new* formula across a full 40-tick light cycle
  the way the old one was traced to find the bug. **Exit criterion, two
  required trace arms per MVP plant type (corrected 2026-08-04
  `/design-review`, round 13 — `systems-designer` finding: a single
  perfect-moisture trace structurally cannot exercise `decay_rate` at all,
  since DECAYING is gated on moisture failing, so "holding moisture
  perfectly" guarantees zero DECAYING ticks by construction and can never
  catch a decay-side bug):** (a) a worked 40-tick trace holding moisture
  perfectly, showing net `growth_stage` change under the corrected formula
  — validates the GROWING/STALLED split and confirms the plant isn't
  punished by light alone under flawless care; (b) a second worked 40-tick
  trace using realistic, imperfect moisture (moisture dipping out of range
  at least once per plant type) — the only arm that actually exercises
  `decay_rate`, required before this gate is considered passed. Both arms
  together, plus confirmation that Snail's
  `moss.growth_stage + fern.growth_stage ≥ 6` threshold stays genuinely
  reachable under real play (not just legal per the formula). Also folds in
  the demoted statistical detail-event density check (AC13's original
  "3–7% observed frequency over 1000+ ticks" note — now a manual/smoke-test
  tuning verification, not a blocking automated AC, per the AC13 rewrite
  above). Owner: systems-designer, with game-designer sign-off. Target:
  before this system's `/architecture-decision`, and before implementation
  of the Plant Growth Delta / Detail Event formulas begins.

  **Numeric pass/fail bar added (2026-08-04 `/design-review`, round 14,
  `qa-lead` finding):** as previously worded, this gate had no concrete
  threshold — "confirms the plant isn't punished" and "stays genuinely
  reachable" aren't numbers, and arm (a) specifically can never fail as
  written, since DECAYING is structurally impossible under perfect moisture
  (it's gated purely on moisture failing), so a trace that starts and stays
  perfect can't exercise the thing it's meant to catch. Concrete exit
  criteria: **(a)** net `growth_stage` change over the 40-tick perfect-
  moisture trace must be `≥ 0` for each of the 3 MVP plant types (i.e., the
  STALLED ticks a plant's own light band forces it through must never leave
  it worse off than it started, only paused); **(b)** under the imperfect-
  moisture trace, `moss.growth_stage + fern.growth_stage ≥ 6` (Snail's
  threshold) must actually be reached within the 40-tick window — if it
  isn't, that is a failing result requiring a value change (e.g. widening
  Moss/Fern's moisture overlap, see the Tuning Knobs advisory on this), not
  something to note and pass anyway.
- ~~**Required tuning pass: `N_departure_ticks` retuned value**~~ —
  **RESOLVED 2026-08-09**: `N_departure_ticks=25`, picked within the
  widened 10–30 range (Core Rule 7's correction, 2026-08-05). **Trace
  against all three exit criteria** (full numbers in Tuning Knobs):
  **(a)** using `time-drift.md`'s own per-plant moisture-exit ticks
  (Flower 6, Fern 7, Moss 12) and this document's decay rates, the
  fastest possible departure path (Moth, via Flower's `==max_stage`
  condition, which breaks on the very first decay tick regardless of
  starting state) resolves in a deterministic `30` ticks total
  (`first_false_tick=6` + `N_departure_ticks−1`); Snail's resolves in
  `31–35` ticks depending on starting `growth_stage`. Both exceed a
  typical 1–2 day absence (`8–24` ticks, per `time-drift.md`'s own
  daily-visit calibration doubled) with a real margin of `6`+ ticks
  (`12`+ hours), not a one-tick shave — departure now requires an
  absence meaningfully longer than daily-visit cadence. **(b)** the
  slowest realistic path (`35` ticks, Snail) sits `49` ticks under
  `max_catchup_ticks=84` — comfortable headroom, and a genuinely long
  multi-week absence (capped at 84 ticks regardless of actual length)
  still resolves departure within a single catch-up batch, so the fix
  makes departure rarer, not unreachable. **(c)** `N_departure_ticks
  (10–30) ≥ N_spawn_ticks (2–5)` holds trivially at `25`, and in fact
  for any legal pair from either range, since the departure range's
  floor (`10`) already exceeds the spawn range's ceiling (`5`). Full
  worked trace lives in the Tuning Knobs `N_departure_ticks` row.
  **Companion updates applied same pass**: this document's ACs 12/16/22
  now state the concrete `25`/`24` tick counts; `persistence-save.md`'s
  `CONDITION_STREAK_MAX` constant recomputed to `max(N_spawn_ticks,
  N_departure_ticks) = 25` (see that document).
- ~~**Plant instance count per type**~~ — **RESOLVED 2026-08-09**: MVP ships
  exactly **one instance per plant type** (1 Moss, 1 Fern, 1 Flower),
  matching the validated terrarium-concept prototype setup and
  `game-concept.md`'s MVP Definition (3 plant/moss *types*, not a patch
  count). Formulas' one-`growth_stage`-per-type assumption is therefore
  already correct as written — no sum-across-instances mechanic needed for
  MVP. The multi-instance-per-type question (and the sum-vs-designated-
  instance formula choice it would require) is deferred to a future
  content-scale pass (Alpha/Full Vision), not MVP. **Note**:
  `diorama-rendering.md` was designed and approved without this being
  formally closed, but its own scene layout and Core Rules already assume
  one instance per type throughout (see its "per plant instance/jar"
  language) — no companion edit needed, this resolution just makes that
  implicit assumption explicit and load-bearing. Owner: game-designer.
- ~~**AC1/AC2's same-tick watering assumption vs. Time & Drift's batch
  architecture**~~ — **RESOLVED 2026-08-04, round 14** (was RECOMMENDED not
  blocking, escalated and fixed this round): watering and tick decay are now
  two independent, decoupled operations on `jar_moisture` — watering applies
  immediately, live, on `apply_watering()`; decay applies only as part of
  `advance_tick()`. They never need to co-occur in the same formula
  evaluation, since they're no longer one formula. See Core Rule 5 and
  Formulas (Jar Moisture). `tending-input.md` Core Rule 3 corrected to match
  in the same pass.
- **Tick definition vs. Time & Drift pacing**: This GDD defines "one tick"
  as the unit all formulas operate on, but doesn't resolve whether a tick
  maps to real elapsed time or an accelerated "time pass" action — that's
  explicitly an open question in the concept doc itself (real-time vs.
  accelerated pacing, untested). This must be resolved during Time & Drift's
  own GDD authoring, and this system's tuning values (moisture_decay_rate,
  growth_rate, etc.) may need rescaling once tick duration is fixed. Owner:
  game-designer + technical-director. Target: before Time & Drift GDD
  authoring begins.
