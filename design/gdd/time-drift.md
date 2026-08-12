# Time & Drift

> **Status**: Approved — round 1 blockers and recommended items resolved (accepted without a formal specialist re-review round; user decision, see trailing review note); 1 stale cross-reference fixed 2026-08-05 (`/review-all-gdds` round 2, text-only, see Formulas trailing note). **Inherited BLOCKING gate resolved 2026-08-10** by `docs/architecture/adr-0006-time-drift-session-lifecycle.md` — architecturally, not by the verification spike (which never tested, and structurally could not have tested, whether a true tab close is distinguishable from backgrounding; see that ADR's Context for why further testing would not have closed this). See Core Rule 8 and Open Questions below for the resolution.
> **Author**: user + systems-designer
> **Last Updated**: 2026-08-10 — Core Rule 8 and AC6/AC7 rewritten per
> `adr-0006-time-drift-session-lifecycle.md`: `last_visit_timestamp` now
> updates on every hide event, not gated on an undetectable true-close
> signal; previously 2026-08-05 (`/review-all-gdds` round 2 — calibration
> paragraph's stale departure-timing claim corrected to match
> `ecosystem-simulation.md`'s round-16 fix; round 1 `/design-review` — see
> trailing review note)
> **Implements Pillar**: Pillar 2 (Nothing Is Ever Finished, Nothing Is Ever Late) — the terrarium changes while the player is away, with no schedule or penalty for absence
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS — round 1 full specialist review (game-designer, systems-designer, qa-lead, godot-specialist, creative-director), verdict NEEDS REVISION at time of review; all 3 blockers and 5 recommended items resolved this same pass, text-only (see trailing review note). Post-fix state not re-confirmed by a fresh specialist round, per user's explicit choice to skip re-review.

## Overview

Time & Drift converts the passage of time into simulation progress — it
decides how many times Ecosystem Simulation's `advance_tick()` fires and
when, translating real-world elapsed time into a jar that has visibly moved
on since the player's last visit. This directly resolves the concept doc's
flagged open question (real-time vs. accelerated pacing) and the systems
index's own high-risk flag on this exact system — the Detailed Design
section below carries the actual resolution, evaluated against the
terrarium-concept prototype's findings. For the player, this is what makes
"checking in" meaningful: the jar isn't paused while they're gone, and it
isn't a live simulation they have to babysit either — it strikes the
balance **Pillar 2** demands, where nothing is ever late because nothing
was ever waiting on a schedule.

## Player Fantasy

The player never sets a clock or watches a timer — they simply leave, live
their life, and come back to find the jar has quietly become something
slightly different. The feeling this system exists to produce is a small,
private "oh" of recognition: not "I made this happen" (that's Tending Input
and Object Placement's job) but "something happened while I wasn't looking,
and it makes sense." This is the mechanism underneath the game's core
hypothesis itself — every time the prototype's tester noticed a change
without being prompted, Time & Drift (in its prototype form, the "Let Time
Pass" button) is what made that moment possible. If this system's pacing is
wrong, the failure mode is exactly what the prototype already observed:
either nothing changes fast enough to notice (static), or so much changes
that it feels overwhelming or arbitrary (random) — both violate Pillar 1's
"always surprising" half.

**Assumed session length, stated explicitly (added 2026-08-04
`/design-review`, `game-designer` finding):** this system's entire
experiential payoff is front-loaded into the instant catch-up at session
start — Core Rule 6 means no ecosystem movement of any kind happens for
the rest of an ACTIVE session (only the purely cosmetic day/night cycle
continues). That design is only coherent for a **short session (roughly
5–15 minutes)**, matching `cycle_duration_seconds`' own tuned range
(600–1800s) — a "check in, notice what changed, do a little tending, leave"
visit, not an extended sit. This is a load-bearing assumption for this
document's whole design, not an incidental detail; if actual sessions run
materially longer, the back half of a session would read as inert.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules.)*

## Detailed Design

### Core Rules

1. Time & Drift tracks a single persisted value: `last_visit_timestamp`
   (real-world Unix time), updated every time a session ends.
2. On session start/resume, it computes
   `elapsed_seconds = current_unix_time - last_visit_timestamp`.
3. `elapsed_seconds` converts to a tick count:
   `ticks_to_apply = floor(elapsed_seconds / seconds_per_tick)`, where
   `seconds_per_tick` is a tuning knob (see Tuning Knobs).
4. `ticks_to_apply` is capped at `max_catchup_ticks` — being away for weeks
   doesn't grant unbounded simulation benefit; beyond the cap, the jar
   simply reaches whatever state the capped batch produces and stops there.
5. The capped `ticks_to_apply` calls to `EcosystemSimulation.advance_tick()`
   fire as **one atomic batch**, immediately on load, before the player
   sees the jar — the catch-up itself is invisible/instant (Discovery
   Surfacing, not this system, is responsible for surfacing "what changed").
6. Once the catch-up batch completes, ecosystem ticks do **not** fire
   again until the next visit boundary (this session ending, then a future
   session starting) — no live ticking during an open session, per the
   chosen model.
7. A separate, purely **cosmetic** day/night lighting cycle runs
   continuously during an active session (real-time driven — a full
   visual cycle every N real minutes). It has zero effect on
   `jar_moisture`, `growth_stage`, or creature state — presentation only,
   so an open session still feels alive without risking the
   state-space-exhaustion failure mode the prototype flagged.
8. **Rewritten 2026-08-10 by `docs/architecture/adr-0006-time-drift-session-lifecycle.md`**
   (previously: "updates only on true session end, not backgrounding" — see
   that ADR's Context for why this was unachievable as originally
   specified, not merely unverified): `last_visit_timestamp` updates on
   **every hide event** (`visibilitychange`→hidden or `pagehide`), as well
   as on true session end — there is no reliable way to distinguish a real
   tab close from mere backgrounding on the Web platform in general
   (documented Page Lifecycle API characteristic, not an engine-version
   gap), and gating the update on an undetectable signal left it
   permanently stale for any session that ends via an untrapped OS-level
   tab kill — the common case on mobile, where `unload`/`beforeunload`
   frequently never fire at all. This has **no mid-session observable
   effect**: the value is never read again until the next real page load
   (Godot's autoload `_ready()` chain runs exactly once per load, never
   re-triggered by backgrounding/refocus of the same tab), so a quick
   tab-switch-and-return still produces no catch-up batch (see AC6) even
   though the stored timestamp technically moved. The next catch-up always
   measures from the most recent known-hidden moment, not an older
   reference point that may never have been reachable at all.

### States and Transitions

| State | Trigger | Next State | Effect |
|---|---|---|---|
| INACTIVE (no session) | Session starts/resumes | CATCHING_UP | `elapsed_seconds` computed |
| CATCHING_UP | `ticks_to_apply` calculated and applied as one batch | ACTIVE | Ecosystem Simulation advances all at once |
| ACTIVE | (session continues) | ACTIVE | Cosmetic day/night cycle runs; no ecosystem ticks fire |
| ACTIVE | session ends (close/unload) | INACTIVE | `last_visit_timestamp` updated to now |
| ACTIVE | tab hidden (`visibilitychange`→hidden or `pagehide`), session does not truly end | ACTIVE (self) | `last_visit_timestamp` updated to the hide moment (Core Rule 8, rewritten by ADR-0006) — no state transition, no catch-up batch |

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Ecosystem Simulation | Downstream (calls in) | Calls `advance_tick()` `ticks_to_apply` times during CATCHING_UP |
| Persistence/Save | Hard dependency (resolved) | Time & Drift needs `last_visit_timestamp` to survive across sessions. **Resolved** by `design/gdd/persistence-save.md` (authored after this GDD): Persistence/Save owns storage of this value directly via its own read/write API — no circular dependency, since Persistence/Save's "depends on Time & Drift" (per the systems index) refers to needing this GDD's tick-conversion logic to exist conceptually, not to Time & Drift owning its own storage. |

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Given this section resolves the project's
flagged real-time-vs-accelerated risk, consider a manual
systems-designer/game-designer pass before production regardless.)*

## Formulas

**Elapsed-time-to-ticks conversion:**

`ticks_to_apply = min(floor(elapsed_seconds / seconds_per_tick), max_catchup_ticks)`

| Variable | Type | Range | Description |
|---|---|---|---|
| elapsed_seconds | int | ≥0 | real time since `last_visit_timestamp` |
| seconds_per_tick | int | — | real seconds per simulation tick (recommended: **7200**, i.e. 2 hours) |
| max_catchup_ticks | int | — | cap on ticks applied in one batch (recommended: **84**, ≈7 days at this rate) |
| ticks_to_apply | int | 0–84 | ticks actually applied this session |

**Output Range:** 0–84.
**Example:** A typical once-daily "morning coffee" visit after ~20 hours
away → `elapsed_seconds=72000` → `72000/7200=10` ticks. A same-day recheck
3 hours later → `10800/7200=1` tick (barely any drift, appropriately less
dramatic than the daily visit).

**Calibration against Ecosystem Simulation's locked values** (corrected
2026-08-04 `/design-review`, `systems-designer` finding — the prior version
of this paragraph stated no baseline `jar_moisture`, making its "4–6 ticks"
claim unverifiable, and that claim is wrong under the only plausible
baseline): assume a typical starting `jar_moisture=75` (a just-watered jar
— the same value Ecosystem Simulation's own Formulas worked example
produces via `apply_watering()`), decaying at `moisture_decay_rate=3`/tick
with no further watering. Decay begins for each plant once `jar_moisture`
exits its own `moisture_tolerance` band — this depends only on moisture,
never on `light_level` (per `ecosystem-simulation.md`'s own Edge Cases:
light-out-of-range alone STALLS growth, it never triggers decay). Computed
directly from `75 - 3×ticks`: Flower (`[60,90]`) exits at **tick 6**
(`jar_moisture=57`); Fern (`[55,90]`) exits at **tick 7** (`54`); Moss
(`[40,75]`) exits at **tick 12** (`39`). At `seconds_per_tick=7200`, a
typical daily visit (8–12 ticks) therefore produces three genuinely
different trajectories, not one shared curve: Flower and Fern each flip
from growing (while `light_level` also cooperates) to decaying partway
through the batch, while Moss — starting at the very top of its own band —
stays in its growing/stalled window for most or all of a typical visit
before decay even begins. This is the possibility-space depth Core Rule
8/9 requires, and it also safely clears `N_spawn_ticks=3` within a typical
daily visit. **(Softened, `systems-designer` nice-to-have)**:
"safely clears" describes a plausible outcome given moisture and light
both shift within a batch, not a rigorous proof for every starting
condition.

**Departure claim struck, corrected 2026-08-05 `/review-all-gdds` round 2**
(round-2 cross-GDD finding): this paragraph previously also claimed it
"can clear `N_departure_ticks=5`... a spawn or departure can plausibly
resolve in one visit" — `ecosystem-simulation.md`'s own round-16 fix
(same session) directly refutes this for departure specifically:
*"That goal is correct for spawning but wrong for departure... a
weekend-length absence... is enough to depart both Snail and Moth, every
time, with no player action able to prevent it"* — the exact property
this calibration paragraph was citing as a design goal is the Anti-Pillar
violation that fix corrects. `N_departure_ticks`'s safe range was widened
to 10–30 there specifically so departure does **not** resolve within one
typical visit; the "resolves within one visit" framing applies only to
`N_spawn_ticks` now, per that document's own Core Rule 7. This paragraph
was never updated to match at the time — corrected here rather than left
contradicting the source document's own fix.

**Cosmetic day/night cycle** (presentation only, zero gameplay effect):

`day_night_phase = (session_elapsed_seconds mod cycle_duration_seconds) / cycle_duration_seconds`

| Variable | Type | Range | Description |
|---|---|---|---|
| cycle_duration_seconds | int | — | real seconds per full visual day/night loop (recommended: **1200**, 20 minutes) |
| day_night_phase | float | 0.0–1.0 | current position in the visual cycle, drives lighting only |

**Example:** A 5-minute session shows ~25% of one visual cycle (a clear
lighting shift); a 15-minute session shows most of a full loop — ambient
movement without frantic pacing, and entirely decoupled from
`jar_moisture`/`growth_stage`.

**Honest limitation, worth stating rather than hiding**: under the current
locked formulas, moisture with no watering converges to 0 within ~14–17
ticks regardless of how long the player stays away, and every plant's
`growth_stage` converges to DORMANT (0) shortly after. This means a
week-long absence and a month-long absence will render **identically** —
the `max_catchup_ticks=84` cap is an honest bound against unbounded
compute, not a real differentiator past that convergence point. This is
consistent with Pillar 2's "different, never punished" philosophy (DORMANT
is fully recoverable, not a loss state) and doesn't require a fix — but
it's worth confirming this convergence-to-dormancy behavior is the
intended long-absence experience, not an oversight. See Open Questions.

*(`systems-designer` consulted for all pacing values above, calibrated
directly against Ecosystem Simulation's locked growth/decay rates and the
concept doc's stated session cadence.)*

## Edge Cases

- **If `elapsed_seconds` is negative** (device clock adjusted backward,
  timezone/DST edge case): `ticks_to_apply` clamps to 0 — no negative
  ticks, no error, treated as "no time has passed."
- **If this is the player's very first session ever** (no
  `last_visit_timestamp` exists yet): no catch-up occurs
  (`ticks_to_apply=0`), and `last_visit_timestamp` initializes to the
  current time. The jar starts in its authored initial state, not
  pre-decayed.
- **If the browser tab is backgrounded but not closed** (switched tabs,
  minimized, not unloaded): **resolved 2026-08-10 by
  `adr-0006-time-drift-session-lifecycle.md`** (previously provisional,
  pending verification that never actually became possible — see that
  ADR's Context). `last_visit_timestamp` **does** update on hide
  (Core Rule 8, rewritten), but no mid-session catch-up recalculation
  occurs and refocusing a backgrounded tab resumes the same ACTIVE
  session unaffected — Godot's `_ready()` chain does not re-run for the
  same still-open tab, so nothing observable changes until the next real
  page load. This is a deliberate departure from trying to distinguish a
  true close/unload from mere backgrounding, which the ADR establishes is
  not reliably possible on the Web platform in general (not an
  engine-version gap — mobile Safari in particular frequently never fires
  a genuine `unload` event at all, and no other close-only signal exists).
  This document's definition of "a visit" no longer depends on making
  that distinction.
- **If the catch-up batch would run before Ecosystem Simulation has
  finished initializing**: this is avoided structurally, not handled
  reactively — same pattern as Tending Input's dependency handling. Time &
  Drift's catch-up is deferred until Ecosystem Simulation confirms
  readiness.
- **If the stored `last_visit_timestamp` is invalid** (corrupted, in the
  future relative to now, or absurdly old beyond any plausible game
  lifetime): treat it as the "first session" case above — reset to current
  time, no catch-up — rather than computing a nonsensical or exploitable
  tick count.
- **If the cosmetic day/night cycle loops back to 0 mid-session**:
  expected, cyclic behavior — the visual simply repeats continuously; no
  special handling needed since it has no gameplay effect.

## Dependencies

Time & Drift depends on:
- **Ecosystem Simulation** (hard) — calls `advance_tick()`

Downstream dependents:
- **Persistence/Save** (hard) — needs `last_visit_timestamp` and catch-up
  state to persist across sessions
- **Discovery Surfacing** (hard) — needs to know what changed across the
  catch-up batch, to surface it to the player. **Noted explicitly (added
  2026-08-04 `/design-review`, `game-designer` finding):** this document's
  own Acceptance Criteria are entirely mechanical/state-consistency checks
  — none test whether the player actually *perceives* time having passed.
  That experiential half of this system's Player Fantasy is an intentional
  handoff to Discovery Surfacing's own GDD (authored 2026-08-05), not a
  silent coverage gap in this one; Discovery Surfacing's own Acceptance
  Criteria are where "the player noticed what changed" gets verified.
- **Creature Behavior** (hard, added 2026-08-05 `/review-all-gdds` —
  closes a bidirectionality gap that document's own Core Rule 8 introduced
  this round) — reads this system's CATCHING_UP/ACTIVE state directly, to
  know when a creature's session-start PRESENT/ABSENT resolution has
  settled and it's safe to present (WANDERING or nothing) without playing
  a SPAWNING/DEPARTING animation for a transition that happened inside an
  invisible catch-up batch. This is a genuinely new dependency this round
  surfaced (Time & Drift's own state machine was already fully sufficient
  to support it — nothing here changed, only `creature-behavior.md`'s use
  of it), not a pre-existing gap.
- **Diorama Rendering** (hard, companion edit, 2026-08-05 —
  `diorama-rendering.md` now authored; a genuine missing entry, not a new
  dependency — `day_night_phase`'s entire purpose is visual) — reads
  `day_night_phase` every frame to drive a continuous, cosmetic-only
  ambient lighting/color shift (a `CanvasModulate` tint sampled from a
  Gradient); consistent with this document's own "zero gameplay effect"
  guarantee, since that system's own Core Rule explicitly never gates any
  other rendering behavior on this value
- **Seasonal Cycle** (Alpha tier, future) — will extend the cosmetic
  day/night cycle into a seasonal one

**Update**: this dependency is now resolved — Persistence/Save (authored
after this GDD) confirmed it owns storage of `last_visit_timestamp`
directly, per its Core Rule 2. This is no longer a soft/provisional
dependency.

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `seconds_per_tick` | 3600–14400 (1–4 hrs) | Too many ticks accumulate per visit — risks exhausting the state space in one sitting, the exact flatness failure the prototype flagged | Barely any ticks accumulate even after a full day away — the jar feels static, defeating the core hypothesis |
| `max_catchup_ticks` | 60–120 | A genuinely long absence (weeks) gets cut short of reaching its natural convergence point — feels arbitrary | **Corrected 2026-08-04 `/design-review`, `systems-designer` finding**: not a state-space-exhaustion risk — that exhaustion is driven by Ecosystem Simulation's own decay rate (moisture converges to DORMANT in ~14–17 ticks regardless of this knob, per Formulas' Honest Limitation; even the *recommended default* of 84 sits far past that point), not by where this knob sits in its range. The actual cost of a high value is purely wasted compute on ticks that produce no additional visible change past convergence. |
| `cycle_duration_seconds` | 600–1800 (10–30 min) | Day/night cycling feels frantic/distracting during a calm session | A typical 5–15 min session barely sees any visible lighting change — undercuts the "living" ambiance this cycle exists for |

These three knobs are independent of each other and of Ecosystem
Simulation's own knobs — but `seconds_per_tick` should always be
re-validated against Ecosystem Simulation's growth/decay rates if either
GDD's numbers change later, since the calibration in Formulas depends on
both.

## Visual/Audio Requirements

N/A for this GDD's scope — Time & Drift produces the `day_night_phase`
value (0.0–1.0) driving cosmetic lighting, but the actual lighting
treatment (color grading, shadow angle, etc.) is owned by Diorama
Rendering, which consumes this system's phase value.

## UI Requirements

N/A — Time & Drift has no UI of its own; it runs invisibly at session
boundaries.

## Acceptance Criteria

1. **(narrowed 2026-08-04 `/design-review`, `qa-lead` finding — previously
   bundled a trivially-testable value assertion with an unobservable
   render-timing claim; the render-timing half now belongs solely to
   AC11)** **GIVEN** `last_visit_timestamp` is 20 hours ago (72000s),
   **WHEN** a new session starts, **THEN** `ticks_to_apply=10` and
   `advance_tick()` is called exactly 10 times.
2. **GIVEN** `last_visit_timestamp` is 3 hours ago (10800s), **WHEN** a
   new session starts, **THEN** `ticks_to_apply=1`.
3. **GIVEN** elapsed time exceeds `max_catchup_ticks × seconds_per_tick`
   (604800s, 7 days), **WHEN** a new session starts after 30 days away,
   **THEN** `ticks_to_apply` is capped at `84`, not the raw computed value.
3a. **(new, 2026-08-04 `/design-review`, `qa-lead` finding — AC3 only
   tested a grossly-over-cap scenario; the exact cap boundary itself was
   untested, breaking this project's own established boundary-pair
   convention)** **GIVEN** elapsed time equals exactly `max_catchup_ticks ×
   seconds_per_tick` (604800s, 7 days exactly), **WHEN** a new session
   starts, **THEN** `ticks_to_apply=84` (the uncapped, exact computed
   value) — paired with `elapsed_seconds=612000` (7 days plus one more
   tick's worth), **WHEN** a new session starts, **THEN**
   `ticks_to_apply` is capped at `84`, not the raw `85` — confirming the
   cap boundary itself, not just a case far beyond it.
4. **GIVEN** `elapsed_seconds` is negative (clock rolled back), **WHEN** a
   new session starts, **THEN** `ticks_to_apply=0`.
5. **GIVEN** no `last_visit_timestamp` exists (first-ever session),
   **WHEN** the session starts, **THEN** `ticks_to_apply=0` and
   `last_visit_timestamp` is set to the current time.
6. **(Rewritten 2026-08-10 by `adr-0006-time-drift-session-lifecycle.md`
   — previously asserted `last_visit_timestamp` is unchanged; corrected
   because that was gated on an undetectable close-vs-background signal,
   see Core Rule 8)** **GIVEN** a tab is backgrounded and later refocused
   without closing/unloading, **WHEN** this occurs, **THEN** no new
   catch-up batch runs and `day_night_phase` is unaffected —
   `last_visit_timestamp` **may** update to the hide moment, but this has
   no observable effect this session, since Godot's `_ready()` chain does
   not re-run for the same still-open tab and the value is not read again
   until the next real page load.
7. **GIVEN** a session truly ends (close/unload), **WHEN** this occurs,
   **THEN** `last_visit_timestamp` updates to the current time (unchanged
   from before — this is the foreground write path; Core Rule 8's
   rewrite adds the hide-triggered path alongside this one, not instead
   of it).
8. **GIVEN** an active session, **WHEN** `session_elapsed_seconds`
   progresses, **THEN** `day_night_phase` cycles from `0.0` to `1.0` every
   1200 seconds and has no effect on `jar_moisture` or `growth_stage`.
9. **GIVEN** a stored `last_visit_timestamp` in the future relative to
   current time (corrupted data), **WHEN** a session starts, **THEN** it's
   treated as the first-session case (`ticks_to_apply=0`, timestamp reset).
10. **GIVEN** the catch-up batch has completed and the session is ACTIVE,
    **WHEN** any amount of time passes during that same session without a
    new session start, **THEN** `advance_tick()` is never called again —
    ecosystem ticks fire only once per visit boundary.
11. **(sole owner of the atomicity/render-timing guarantee as of
    2026-08-04 `/design-review`, `qa-lead` finding — AC1 previously
    duplicated part of this claim in a form no pure logic test could
    observe; that clause was removed from AC1 and this criterion is now
    the only place it's tested)** **GIVEN** a catch-up batch of
    `ticks_to_apply=10` is executing, **WHEN** the batch runs, **THEN** no
    intermediate/partial state (e.g., a render showing tick 3 of 10) is
    observable to the player — the full batch completes before the jar is
    rendered.

*(`qa-lead` consulted — flagged 2 missing criteria (no ticks re-firing
during ACTIVE, batch atomicity) and a genuine spec inconsistency between
the States table and Edge Cases regarding what counts as "session end,"
now fixed in Detailed Design.)*

*(Reviewed via `/design-review` on 2026-08-04 — round 1, first dedicated
full specialist round for this document: `game-designer`, `systems-designer`,
`qa-lead`, `godot-specialist`, `creative-director`. Verdict: NEEDS REVISION
→ all 3 blockers resolved below, text-only, no formula redesign.
**BLOCKED gate inherited** (`godot-specialist` finding): this document's
Core Rule 8/Edge Cases stated close/unload-vs-backgrounding detection as
settled fact, with zero hedging, despite depending on the exact same
unverified Web-export browser-event class already flagged BLOCKING in
`input-abstraction.md` — header and Edge Cases now inherit that gate,
matching the precedent `object-placement.md` already set for its own
inherited dependency on the same underlying verification. **Calibration
paragraph corrected** (`systems-designer` finding): the prior version
stated no baseline `jar_moisture`, and its "drifts out of most tolerance
bands within 4–6 ticks" claim was wrong under the only plausible baseline
(post-watering, `jar_moisture=75`) — true for Flower (exits at tick 6) but
not Fern (tick 7) or Moss (tick 12). Corrected with the actual computed
per-plant exit ticks and a restated conclusion (three different
trajectories within one visit, not one shared curve) — this was blocking
because it's the sole stated justification for `seconds_per_tick=7200`,
the project's single highest-risk tuning value. **`max_catchup_ticks`
rationale corrected** (`systems-designer` finding): the Tuning Knobs table
wrongly attributed state-space exhaustion to this knob's own range — the
convergence is driven by Ecosystem Simulation's decay rate (even the
recommended default of 84 ticks sits far past the ~14–17 tick convergence
point), not by where this knob sits between 60–120. Corrected to state the
actual cost of a high value (wasted compute past convergence). **Dormancy
convergence re-diagnosed, not treated as blocking** (`game-designer`
finding, `creative-director` ruling): the existing Open Question framed
convergence-to-DORMANT as a Pillar 2 question; `game-designer` correctly
identified it as actually a Pillar 1 ("always surprising") risk instead —
`creative-director` agreed with the reframe but ruled it RECOMMENDED, not
blocking, since the core daily-visit hypothesis (8–12 ticks) sits well
below the ~14–17 tick convergence ceiling this only affects repeat
multi-day absences, a retention question needing playtest data rather than
a reason to redesign Ecosystem Simulation's already-locked rates on
speculation now. **All 5 recommended items applied in the same pass**
(cheap, text-only, already specialist-vetted this round): the
dormancy-convergence Open Question reframed under Pillar 1 with a hardened
before-Vertical-Slice deadline (`game-designer`); AC1's unobservable
render-timing clause stripped, leaving AC11 as sole owner of the atomicity
guarantee (`qa-lead`); a new boundary-pair AC at exactly 84 vs. 85 ticks
(`qa-lead`); the assumed session length stated explicitly in Player
Fantasy (`game-designer`); this document's zero experiential ACs noted as
an intentional handoff to the unauthored Discovery Surfacing GDD, not a
silent gap (`game-designer`). **Nice-to-have, deferred**: an Edge Case/AC
for `elapsed_seconds=0` (`qa-lead`); an Edge Case for an indefinitely-open
tab never triggering catch-up (`game-designer`); already softened language
on the debounce "safely clears" framing, folded into the calibration-
paragraph fix above
(`systems-designer`).)*

## Open Questions

- ~~**Timestamp storage mechanism**~~ — **RESOLVED** by
  `design/gdd/persistence-save.md`: `last_visit_timestamp` is owned and
  stored by Persistence/Save, not a separate self-contained store as
  originally assumed here.
- ~~**[BLOCKING, inherited] Empirical verification of close/unload vs.
  backgrounding detection required before implementation begins**~~ —
  **RESOLVED 2026-08-10** by
  `docs/architecture/adr-0006-time-drift-session-lifecycle.md`. Not
  resolved by verification — the underlying claim (no reliable
  close-vs-background signal exists on the Web platform) is a documented
  Page Lifecycle API characteristic, not a per-browser unknown further
  testing would settle. Resolved architecturally instead: `last_visit_timestamp`
  now updates on every hide event, not gated on detecting true close (Core
  Rule 8, rewritten). This also fixes `persistence-save.md`'s previously
  separate "frequent-backgrounder never sees catch-up" Open Question as a
  direct consequence.
- **Dormancy-convergence confirmation** (**reframed 2026-08-04
  `/design-review`, `game-designer` finding, `creative-director` ruling** —
  previously framed as a Pillar 2 question and left open-ended; both are
  corrected below): Per the Formulas section's honest limitation — under
  current locked values, a week-long and month-long absence render
  identically once every plant converges to DORMANT. This is primarily a
  **Pillar 1** ("always surprising") risk, not a Pillar 2 one — Pillar 2's
  "different, never punished" is already satisfied (DORMANT is fully
  recoverable, not a loss state), but a player who learns the convergence
  ceiling gets an experience that's surprising exactly once, then flat for
  every longer absence after. Not blocking at MVP: the core daily-visit
  hypothesis (8–12 ticks) sits well below the ~14–17 tick convergence
  point, so this only affects repeat multi-day absences — a retention
  question needing playtest data, not a reason to redesign Ecosystem
  Simulation's already-locked decay rates on speculation now. Should
  Ecosystem Simulation's decay rates or this system's pacing be revisited
  (e.g., staggered per-plant dormancy timing, or non-monotonic decay
  states) so longer absences remain meaningfully distinct? Owner:
  game-designer + creative-director. **Target: before `/vertical-slice`**
  (hardened from the prior "before `/gate-check` or `/vertical-slice`" —
  this needs playtest signal Vertical Slice is positioned to produce, not
  an earlier gate).
- **Day/night visual treatment**: What does the cosmetic day/night cycle
  actually look like (lighting color temperature, shadow angle, ambient
  color shift)? Owner: art-director. Target: before Diorama Rendering GDD
  authoring.
