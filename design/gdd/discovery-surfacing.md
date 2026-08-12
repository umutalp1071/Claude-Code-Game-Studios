# Discovery Surfacing

> **Status**: round 2 blockers resolved (fresh-session full `/design-review`, 2026-08-05) — 4 blockers (concurrency-figure conflation, stale `diorama-rendering.md` cross-reference, Arrival "payoff" framing, Pillar 2 mis-citation), all text-level, resolved below. Round 1's blockers remain resolved from before.
> **Author**: user + game-designer, art-director, qa-lead, systems-designer, godot-specialist, performance-analyst, gameplay-programmer, creative-director
> **Last Updated**: 2026-08-09 (cross-GDD review — new Core Rule 2a `full_cycle` exception, Core Rule 7's position source corrected to Ecosystem Simulation's `last_known_position`; see trailing note). Previously 2026-08-05
> **Implements Pillar**: Pillar 4 (Every Detail Rewards Attention), Pillar 2 (Nothing Is Ever Finished, Nothing Is Ever Late)
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS (full-mode `/design-review`, round 2, 2026-08-05) — 4 blockers, all text-level fixes, resolved below. Design spine confirmed sound for the second time.
> **BLOCKED gate inherited** (Core Rule 4a / Edge Cases): the queue-pause-on-backgrounding behavior depends on the same unverified browser `visibilitychange`/focus-blur bridging signal that `time-drift.md` and `input-abstraction.md` already flag as BLOCKED pending an empirical Web-export verification prototype — does not block this GDD's own approval, same precedent as those documents, but gates implementation.

## Overview

Discovery Surfacing is the layer that turns the state deltas Ecosystem
Simulation and Time & Drift already produce into a sequenced, legible "what
changed since you left" reveal — it owns *pacing*, not detection. Ecosystem
Simulation and Time & Drift already know exactly what changed (growth
deltas, creature spawn/departure transitions, detail events); neither is
responsible for presenting it in a way that reads as discovery rather than
a data dump. It exists because Time & Drift's catch-up batch is atomic and
invisible by design (its own Acceptance Criteria guarantee no intermediate
state is ever rendered) — without a dedicated pacing layer, every visit's
worth of change would land in one simultaneous render, working directly
against Pillar 4 (small persistent details, not one big event) and risking
the core "notice what changed" hook curdling into background noise the
player learns to tune out. For the player, this is the quiet moment a
visit actually begins: before they touch anything, the jar tells them,
gently and in sequence, what happened while they were away.

## Player Fantasy

The player never operates Discovery Surfacing — they simply arrive, and the
jar tells them, in its own unhurried way, what's different. The feeling
this system exists to produce is echoed in Time & Drift's own Player
Fantasy: *"a small, private 'oh' of recognition"* — not "I made this
happen" (that's Tending Input and Object Placement's job) but "something
happened while I wasn't looking, and now I get to notice it." This is the
game's "checking on my jar" ritual made concrete: the concept doc's own
Retention Hooks name curiosity ("what changed since I last looked?") as
the primary reason players return, and this system is the mechanism that
pays that curiosity off, visit after visit, without ever demanding
attention or punishing a player who stays away. If this system fails, the
failure mode is exactly what this project's own review history has already
flagged: either everything reveals itself at once, in one flat,
overwhelming instant — undermining Pillar 4 (small details, not one big
event) — or reveals so subtly the player never notices anything changed,
and the whole "return day after day" hypothesis quietly stops paying off
without anyone knowing why.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Review manually before
production.)*

## Detailed Design

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Review manually before production.)*

### Core Rules

1. Discovery Surfacing computes a **delta set** exactly once per session, at
   the moment Time & Drift transitions CATCHING_UP→ACTIVE (the same
   settlement point Creature Behavior's own Core Rule 8 queries) —
   comparing each plant's `growth_stage`, each creature's PRESENT/ABSENT
   state, and any detail-event flags against their values at the start of
   the batch. This is the only trigger that exists — `time-drift.md`'s own
   States and Transitions table guarantees "no ecosystem ticks fire" while
   ACTIVE, so `growth_stage` and PRESENT/ABSENT cannot change at any other
   moment during a session; there is no live/mid-session case this system
   needs to separately handle.
2. Each detected change becomes one **discovery item**, categorized as:
   **Growth** (a plant's `growth_stage` changed, either direction),
   **Arrival** (a creature transitioned ABSENT→PRESENT during the batch),
   **Departure** (a creature transitioned PRESENT→ABSENT during the
   batch), or **Detail Event** (Ecosystem Simulation's rare-bloom flag
   fired). A plant/creature that ends the batch in the same state it
   started produces no item — no discovery for "nothing changed."
2a. **`full_cycle` exception (new 2026-08-09, `/review-all-gdds` cross-GDD
   finding — closes a blocking gap in Rule 2's "nothing changed" logic).**
   A creature that is ABSENT at both batch-start and batch-end, but was
   PRESENT at some point *during* the batch (a full spawn-then-departure
   residency the player never witnessed — reachable at this game's tuned
   values: `max_catchup_ticks=84` comfortably fits `N_spawn_ticks=3` +
   `N_departure_ticks=25`), **does** produce a discovery item — Rule 2's
   net-delta suppression exists to hide within-batch flicker noise, not to
   hide a genuine, complete residency. This is still a **Departure** item
   (not a new 5th category), flagged `full_cycle=true`, generated from
   Ecosystem Simulation's `was_present_during_batch` flag (that system's
   Core Rule 13) — a single boolean per creature per batch, so exactly one
   item is generated regardless of how many spawn/depart cycles occurred
   within the batch (consistent with this rule's existing "one item per
   element per batch" granularity). Distinguishing this from an ordinary
   Departure matters for Pillar 4 (Every Detail Rewards Attention): a
   full, unwitnessed arrival-and-departure is a stranger, more noteworthy
   absence of evidence than either a plain Arrival or Departure alone, and
   silently dropping it (the pre-2026-08-09 behavior) was a worse outcome
   than the "nothing changed" case Rule 2 was designed to produce.
3. On the very first session (no prior state to compare against), the
   delta set is empty and no discovery items are generated — matches every
   other system's own first-session convention.
4. Discovery items reveal **one at a time, staggered**: each item's
   ambient cue activates only after a fixed pacing delay past the previous
   item's activation — never two cues arriving in the same instant, even
   though the underlying state changed in one atomic batch (Time & Drift
   AC11). This is the pacing layer the Overview promises; it does not
   change *when* state changed, only *when the player is shown* it
   changed.
4a. **The queue's elapsed-time clock runs on focused attention, not
   wall-clock time.** It advances only while the tab is visible/focused,
   pauses on backgrounding (`visibilitychange`→hidden or equivalent
   signal), and resumes from exactly where it paused when the tab regains
   focus — never resets to 0, never fast-forwards through the paused
   interval. This exists because the reveal's entire purpose is to be
   *seen*: without this rule, a routine notification-check or alt-tab
   during the ~30s reveal window could let every item activate and fully
   fade while the player wasn't looking, silently defeating Rule 4's
   pacing layer and producing exactly the "reveals so subtly nobody
   notices" failure mode named in Player Fantasy. **Status: BLOCKED
   pending empirical verification** — depends on the same browser
   `visibilitychange`/focus-blur bridging signal that `time-drift.md`
   (Core Rule 8/Edge Cases) and `input-abstraction.md` already flag as
   unverified on Web export; this rule inherits that gate rather than
   re-opening it. (Added round 1 `/design-review`, `game-designer`
   finding, `creative-director` ruling.)
5. Each ambient cue is **per-element**, attached to the specific
   plant/creature/position it concerns — never a global banner or panel.
   The cue's exact visual treatment (glow, pulse, color) is Diorama
   Rendering's implementation call; this GDD locks only that a cue exists,
   is per-element, and is non-blocking.
6. A cue **fades out automatically after a fixed duration**, regardless of
   whether the player looked at it. This system tracks no
   "seen/acknowledged" state per item — a player who never visits during a
   cue's active window simply never sees that cue. Accepted by design, not
   a gap: matches the Anti-Pillar against demanding attention. **(Citation
   corrected this review, `creative-director` ruling on a `game-designer`
   finding: struck the prior additional citation to Pillar 2, "nothing is
   ever late."** Pillar 2 is about the *ecosystem* never being late for
   the player, not the reverse — a cue that vanishes forever once its
   window passes is, if anything, late in exactly the sense Pillar 2
   forbids. The actual justification is the Anti-Pillar alone: this
   system will not force a "seen" state or retroactively resurface a
   missed cue, because either would cross into demanding acknowledgment.)
7. **Departure is surfaced, never silent.** A Departure item's cue plays
   at the creature's **last-known position** — a gentle, distinct cue type
   from Arrival's, satisfying `creature-behavior.md`'s flagged requirement
   that departure read as "moved on," not a cold, unexplained absence.
   **Position source corrected 2026-08-09** (`/review-all-gdds` cross-GDD
   finding — closes a blocking gap): this is Ecosystem Simulation's own
   `last_known_position` value (that system's Core Rule 12), not "the
   creature's position at the moment of transition" as originally worded
   here — that literal moment has no observer for the now-dominant case
   where departure resolves entirely inside an invisible catch-up batch,
   since Creature Behavior (position's actual owner while a live instance
   exists) never spawns an instance for a creature that settles ABSENT
   (`creature-behavior.md` Core Rule 8). `last_known_position` freezes at
   the creature's true last-observed position instead, or defaults to the
   jar-floor center `(0, 0)` for a creature that has never had a live
   instance (the `full_cycle` case, Core Rule 2a) — see
   `ecosystem-simulation.md` Core Rule 12 for the full mechanism.
8. **Queue ordering** is deterministic, by category tier (ascending):
   Growth → Departure → Detail Event → Arrival, then by a stable tie-break
   within a tier (registration order of the item's associated plant/
   creature, per Content Data's own sorted load order — never
   randomized). This tie-break rule applies uniformly across all four
   categories, including Detail Event: since every Detail Event item is
   itself tied to the specific plant whose rare-bloom flag fired (Core
   Rule 2), two Detail Event items in the same batch break their tie by
   that plant's registration order, same as any other tier. Rationale:
   the most common, most mundane changes surface first; the rarest
   discovery (a new creature has moved in) surfaces last, so it's never
   buried or overshadowed by a bigger event landing first. **(Wording
   corrected this review, `creative-director` ruling: struck "always the
   payoff" — this rule stands on anti-overshadowing alone, not on
   engineering a climax; see Visual/Audio Requirements' Arrival entry for
   the same correction.)**
9. **This system never blocks or gates gameplay input.** Tending,
   dragging, and all other interactions function identically regardless of
   queue state — the reveal is observed, never a modal the player must
   clear before playing.

### States and Transitions

| State | Trigger | Next State |
|---|---|---|
| IDLE | Time & Drift reaches ACTIVE, delta set is empty (nothing changed, or first session) | IDLE (self, no-op) |
| IDLE | Time & Drift reaches ACTIVE, delta set is non-empty | REVEALING (queue begins; item 0 activates immediately at `activation_time(0)=0`, per Formulas) |
| REVEALING | focused-elapsed time since queue start (Core Rule 4a — paused while backgrounded) < `total_reveal_duration` | REVEALING (self — each item's visibility is derived independently from its own `activation_time(i)`/`fade_end_time(i)`, never gated by another item's fade completion; cues may overlap by design, see Formulas) |
| REVEALING | focused-elapsed time since queue start (Core Rule 4a) ≥ `total_reveal_duration` (every item has passed its `fade_end_time`) | IDLE |

**Correction (round of Acceptance Criteria authoring, `qa-lead` finding):** the
original two-state QUEUED↔REVEALING ping-pong implied a strictly sequential
reveal (next item only activates once the previous one's fade completes),
which contradicted Core Rule 4 and the Formulas section's explicit,
deliberate overlap (`pacing_delay=4.0s < cue_fade_duration=6.0s`). Collapsed
to a single REVEALING state for the whole queue window; per-item visibility
is now computed directly from the Formula, matching the design that was
already locked elsewhere in this document.

**Note on time basis (added round 1 `/design-review`)**: everywhere "elapsed
time" appears in this document (this table, the Formulas section, and the
Acceptance Criteria), it means focused-elapsed time per Core Rule 4a —
cumulative visible/focused duration since the queue started, not wall-clock
duration. This is a single canonical definition rather than restating the
qualifier at every reference.

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Ecosystem Simulation | Upstream | Reads pre/post-batch `growth_stage` per plant, pre/post-batch PRESENT/ABSENT per creature, detail-event flags fired during the batch, and (added 2026-08-09) per-creature `last_known_position` for the Departure cue and `was_present_during_batch` for the `full_cycle` case (Core Rule 12/13) |
| Time & Drift | Upstream | Reads the CATCHING_UP→ACTIVE transition as the trigger to compute the delta set |
| Diorama Rendering | Downstream | Reads the active discovery item (category, target element/position) to render its ambient cue |
| Object Placement, Tending Input | None | Explicitly no interaction — gameplay is never gated on this system's queue state (Core Rule 9) |

## Formulas

**Discovery Queue Timing** — two fixed constants, no formula scaling with
queue depth (Core Rule 4 already commits to "fixed," and worst-case queue
depth resolves comfortably within target even at a flat value):

`activation_time(i) = i × pacing_delay` (i = 0..n-1, queue order per Core Rule 8)
`fade_end_time(i) = activation_time(i) + cue_fade_duration`
`total_reveal_duration = (n-1) × pacing_delay + cue_fade_duration`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| i | — | int | 0 to n-1 | zero-indexed position of a discovery item in the deterministic queue (Core Rule 8 tier order) |
| n | — | int | 1–8 | total items in this session's queue. **Corrected round 1 `/design-review`, `systems-designer` finding** (was stated 1–7): 3 plants can each independently contribute BOTH a Growth item AND a Detail Event item in the same catch-up batch (`ecosystem-simulation.md` confirms rare-bloom flags are independent of `growth_stage` and can fire on a plant already at `max_stage`), so the true worst case is 3 Growth + 3 Detail Event + 2 creature transitions = 8, not 3 plants + 2 creatures + 1-2 details. |
| pacing_delay | — | float | seconds, constant (recommended: 4.0) | gap between one cue's activation and the next. **Constraint**: must remain strictly less than `cue_fade_duration` (see Tuning Knobs) — required for the overlap guarantee (AC23) to hold |
| cue_fade_duration | — | float | seconds, constant (recommended: 6.0) | how long one cue stays visible before it fades |

**Output Range:** `total_reveal_duration` 6.0–34.0s at recommended
defaults across the corrected n=1–8 range. Worst case n=8 → 34.0s;
realistic max n=5 → 22.0s — both resolve well within a typical 5-15 min
session. **At the Tuning Knobs' legal extremes** (`pacing_delay=8.0`,
`cue_fade_duration=10.0`, both individually within their own safe ranges
and still satisfying `pacing_delay < cue_fade_duration`), the true
tunable ceiling is `7×8.0+10.0 = 66.0s` — **corrected round 1
`/design-review`, `systems-designer` finding**; still bounded, but a
future tuning pass should not assume 30.0s is the hard ceiling.
**Example:** A 3-item queue (Growth, Departure, Arrival, per Core Rule 8's
tier order) — Growth activates at 0.0s, fades at 6.0s; Departure activates
at 4.0s, fades at 10.0s; Arrival activates at 8.0s, fades at 14.0s.
`total_reveal_duration = 14.0s`.

**Overlap is deliberate, not a bug**: since `cue_fade_duration (6.0s) >
pacing_delay (4.0s)`, adjacent cues briefly overlap (e.g. Growth is still
visible when Departure activates). Core Rule 4 only forbids simultaneous
*activation*, not simultaneous *visibility* — and because each cue is
per-element and spatially separated (Core Rule 5), overlap reads as "the
jar is quietly alive in a few places" rather than a stacked notification
queue, which is closer to this project's Anti-Pillar-safe tone than a
strict single-file reveal would be.

*(`systems-designer` consulted for these timing values — mandatory per
this section's high-risk gate, applies regardless of review mode.
**Round 1 `/design-review` update**: `systems-designer` also found the
queue-depth ceiling and the Tuning Knobs' cross-knob coupling were both
wrong — both corrected above.)*

## Edge Cases

- **If a creature's state oscillates within a single catch-up batch** (e.g.,
  departs then re-arrives, or vice versa, across multiple ticks in the
  batch) and its state at the end of the batch matches its state at the
  start: no discovery item is generated **unless** the creature was
  PRESENT at some point during the batch while ending ABSENT — that
  specific case is the `full_cycle` exception (Core Rule 2a, new
  2026-08-09), which *does* generate a Departure item. Any other
  same-state-at-both-ends oscillation (e.g., PRESENT→PRESENT with a dip in
  between) still produces nothing (Core Rule 2's "no discovery for nothing
  changed" applies to net delta, not intermediate ticks) — nothing was
  ever rendered mid-batch (Time & Drift AC11), so there is nothing the
  player could have perceived to surface.
- **If a plant's `growth_stage` fluctuates within a batch but returns to
  its starting value by the batch's end**: same reasoning — no discovery
  item, since only the net start/end delta is compared.
- **If the tab is backgrounded while the discovery queue is REVEALING**
  (not closed/unloaded — a different case from the session-end bullet
  below): the queue's elapsed-time clock pauses per Core Rule 4a. No
  items activate, fade, or advance while backgrounded. Refocusing resumes
  the same REVEALING queue from its paused focused-elapsed-time — items
  already fully faded before backgrounding stay faded, an item mid-cue
  resumes its remaining visible duration, and any not-yet-activated item
  still activates in original queue order once its focused-elapsed-time
  threshold is reached. **Status: BLOCKED pending the same empirical
  verification as Core Rule 4a.** (Added round 1 `/design-review`,
  `game-designer` finding.)
- **If the discovery queue is still REVEALING when the session ends**
  (Time & Drift's ACTIVE→INACTIVE transition — a true close/unload, never
  a backgrounded tab, per `time-drift.md`'s own States and Transitions):
  the remaining queue is simply discarded — this system persists no state
  across a session boundary (see Dependencies). It is fully re-derived
  from Ecosystem Simulation's own state at the start of the *next*
  session's catch-up, same as any other session.
- **If the player interacts with an element (waters it, drags it) while
  its discovery cue is actively displaying**: the interaction proceeds
  normally (Core Rule 9) and does **not** extend, shorten, or dismiss the
  cue early — this system tracks no per-item "acknowledged" state (Core
  Rule 6), so touching the element has no special effect on its cue's
  fixed timer.
- **If Content Data excludes a plant/creature type at load time**: not a
  case this system needs to defend against — Discovery Surfacing only
  ever reads Ecosystem Simulation's live registered instances, which by
  construction only include valid loaded types (mirrors
  `creature-behavior.md`'s own established Edge Case: the upstream
  guarantee is owned entirely by Content Data/Ecosystem Simulation). Test
  coverage for this guarantee lives in `ecosystem-simulation.md`'s own
  Acceptance Criteria (its `definition_validity` gate), not duplicated
  here — added as an explicit cross-reference (round 1 `/design-review`,
  `qa-lead` finding) rather than left silently uncovered from this
  document's own AC list.
- **If Persistence/Save falls back to default-init** (its own validity
  failure, both fallback tiers exhausted): the batch's start-of-comparison
  snapshot is simply the freshly-initialized default state, and Time &
  Drift's own Edge Cases already treat this as a "first session" case
  (`ticks_to_apply=0`) — so no ticks run and the delta set is trivially
  empty, consistent with Core Rule 3. No special handling needed here
  beyond what those two systems already guarantee.

## Dependencies

Discovery Surfacing depends on:
- **Ecosystem Simulation** (hard) — pre/post-batch `growth_stage` per
  plant, pre/post-batch PRESENT/ABSENT per creature, detail-event flags
  fired during the batch
- **Time & Drift** (hard) — the CATCHING_UP→ACTIVE transition as the
  delta-computation trigger
- **Creature Behavior** (hard) — a departed creature's last-known
  position, needed for Core Rule 7's Departure cue

Downstream dependents:
- **Diorama Rendering** — reads each active discovery item (category,
  target element/position) to render its ambient cue, **and, per that
  document's own `/design-review` this session, a Growth item's recorded
  `{from, to}` stage values specifically** — consumed by its Catch-up
  Growth Reveal, which needs the pre-catch-up stage to ease the
  growth-pattern scale transform from rather than tracking its own
  history. **Corrected round 1 `/design-review`**: this row previously
  read "provisional — not yet authored"; `diorama-rendering.md` is now
  authored (2026-08-05) and already treats this dependency as
  hard/already-locked on its own side (its own Interactions table lists
  Discovery Surfacing as a plain Upstream dependency, not provisional).

**No dependency on or from Persistence/Save** (stated explicitly, mirrors
Ecosystem Simulation's detail-event-flag exclusion pattern): this system's
discovery items are fully transient, re-derived fresh every session from
upstream state, and never carried across a session boundary — see Edge
Cases.

**Bidirectionality note**: `ecosystem-simulation.md` and `time-drift.md`
list Discovery Surfacing as a downstream dependent on their own side
(confirmed consistent). `creature-behavior.md`'s own Downstream
dependents list is **now also updated** (companion edit, round 1
`/design-review`, same session) to include Discovery Surfacing — closes
the gap that previously existed there (it had only mentioned Discovery
Surfacing in an Open Question, not its Dependencies section).

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `pacing_delay` | 2.0–8.0s | Cues fire in a near-simultaneous burst — hard to visually track which highlight is new, starts reading as a flicker rather than staggered noticing | With a large queue (n=8, corrected round 1 `/design-review` from n=7), total reveal stretches past ~50-55s at default `cue_fade_duration`, or up to 66s at both knobs' legal extremes together — starts feeling like a wait/timer, which the Anti-Pillars forbid |
| `cue_fade_duration` | 4.0–10.0s | Cue can vanish before the player's eye lands on the jar (especially the very first cue, right at session start) — risks the "reveals so subtly nobody notices" failure mode named in Player Fantasy | Combined with overlap, up to 5 concurrent cues on-screen at once — **corrected this review, `systems-designer` finding**: this is a *different* knob combination from the 66s duration ceiling above (which uses `pacing_delay` at its own maximum). Maximum concurrency instead requires `pacing_delay` at its **minimum** (2.0s) paired with `cue_fade_duration` at its maximum (10.0s): `floor(10.0/2.0)=5` cues can overlap. The 66s-ceiling combination (`pacing_delay=8.0`, `cue_fade_duration=10.0`) only ever produces ~2 concurrent cues. These two "legal extremes" are mutually exclusive, not the same tuning — see Visual/Audio Requirements and Open Question 3, also corrected. |

**Constraint (added round 1 `/design-review`, `systems-designer`
finding)**: `pacing_delay` must remain strictly less than
`cue_fade_duration`. A combination where `pacing_delay ≥
cue_fade_duration` (e.g. 8.0/4.0 — each individually within its own
"safe range" above) inverts Acceptance Criterion 23's overlap guarantee
into visible gaps between cues, breaking the "jar is quietly alive" read
this system is built around. Not gated by a validity check (same pattern
as this project's other cross-knob invariants, e.g.
`ecosystem-simulation.md`'s `N_departure_ticks ≥ N_spawn_ticks`) —
flagged here, not enforced in data.

**Data-driven, not hardcoded (added this review, `gameplay-programmer`
finding)**: both `pacing_delay` and `cue_fade_duration` must be exposed as
authorable data (a Resource field or project-level tuning constant), not
hardcoded literals in implementation code, per `coding-standards.md`
("Gameplay values must be data-driven... never hardcoded"). The specific
storage mechanism is an implementation/architecture decision, not fixed
here — consistent with how this project's other GDDs (e.g.
`time-drift.md`'s `seconds_per_tick`, `ecosystem-simulation.md`'s
`N_departure_ticks`) document recommended values and safe ranges without
pinning a file format.

## Visual/Audio Requirements

All cues are diegetic light/material behavior — never UI chrome (no icons,
badges, outlines, or color-coded status lights). The distinguishing axis
between categories is *where light/material behavior lives*, not hue-coding.

- **Growth**: subsurface warm light bloom from within the plant tissue at
  the specific changed part (new leaf/stem), not the whole plant. Zero
  positional motion — light-only.
- **Arrival**: a specular catch-light animating in from the creature's
  silhouette edge, like a lens catching dew — the only category with
  genuine (sub-second, subtle) motion. **Reworked this review
  (`creative-director` ruling on a `game-designer` finding) — struck the
  prior "the queue's designed payoff... should read as the most lingering
  of the four" framing**: that wording engineered this cue as a
  deliberate climax, which directly contradicts Core Rules 6 and 9 (no
  acknowledgment tracking, gameplay never waits on the queue) — a player
  is explicitly free to leave before this cue, which always activates
  last, ever fires. The distinguishing motion alone is sufficient
  differentiation; this cue carries no duration or intensity bias over
  the other three.
- **Departure**: no phantom shape/outline. A faint, cooling desaturation/
  settle in ambient light at the last-known position (e.g. nearby moss/
  substrate light rebalancing) — reads as "recently vacated," not "marker
  here." Flagged as a novel VFX ask with no direct real-world reference —
  needs a dedicated technical-artist experiment pass. **Must remain
  perceptible under normal play** — the quietest cue of the four, not an
  imperceptible one (added round 1 `/design-review`, `game-designer`
  finding); Core Rule 7 exists specifically so departure never reads as
  silent absence, and a cue nobody notices defeats that purpose just as
  surely as no cue at all.
- **Detail Event**: brightest-but-briefest of the four — a genuine
  point-light flicker/bloom at the specific point, distinct in intensity
  but the shortest-held cue in the queue. **Corrected round 1
  `/design-review`** (`game-designer` finding, `creative-director`
  ruling; was "the most saturated/high-contrast of the four, rarity earns
  it"): rarity earns *distinctiveness*, not primacy or duration — this
  cue stays sharp and brief on its own terms. **Re-corrected this review**
  (`creative-director` ruling): struck the prior "must not out-hold or
  out-intensify Arrival, the queue's payoff" justification — Arrival is
  no longer treated as a climax to protect (see Arrival's own entry
  above), so this cue's brevity stands on its own rarity-earns-
  distinctiveness rationale, not on deference to another cue's position
  in the queue.

**Motion**: ease-in/hold/ease-out only, never linear or bouncy (bounce
reads as UI feedback). One rise-hold-fade arc per cue — no looping pulse/
blink (a flashing cue reads as an alert, violating "never demands
acknowledgment").

**Art Bible alignment**: extends Diorama Realism's "light as mood"
language rather than adding a separate overlay system. Corrective test for
implementation: *if you removed the glow, would the underlying lighting/
material still make physical sense?* A pure additive sprite/decal fails
this test. No art bible exists yet — this system's treatment should seed
its Lighting/VFX section. Technical-artist must confirm per-cue light cost
against the ≤500 draw call budget (Compatibility renderer), especially
given deliberate cue overlap — **up to 5 concurrent cues at
`pacing_delay=2.0` (minimum) combined with `cue_fade_duration=10.0`
(maximum), not 2-3** (corrected round 1 `/design-review`,
`performance-analyst`/`godot-specialist` finding; **re-corrected this
review, `systems-designer` finding**: the prior wording implied this
figure came from the same "legal extreme" as the 66.0s duration ceiling —
it doesn't; that combination, `pacing_delay=8.0`/`cue_fade_duration=10.0`,
yields only ~2 concurrent cues. The 5-concurrent figure requires the
*opposite* end of `pacing_delay`'s range); this is the real number Diorama
Rendering's profiling pass must budget against — and per
`performance-analyst`'s review-round finding, it does not yet include the
continuous day/night `CanvasModulate` tint or any active drag/snap-back
tween that may be running at the same time (Core Rule 9 guarantees
gameplay is never paused during a reveal), which Diorama Rendering's own
profiling pass must account for on top of this figure.

**Audio**: out of scope for this GDD (owned by Ambient Audio/audio-director).
Directional note to pass along: texture-based ambient-bed shifts, not
discrete per-cue "dings." Departure should get no sound, or the softest of
the four.

*(`art-director` consulted — Visual/Audio Requirements is mandatory for
UI-category systems regardless of review mode. No art bible exists yet;
this section's treatments are flagged as candidate first entries for it.)*

## UI Requirements

None. This system produces no menu, HUD, panel, or screen — Core Rule 5
("never a global banner or panel") and Core Rule 9 ("never blocks or gates
gameplay input") already rule out a traditional UI surface. All player-
facing behavior is diegetic and covered under Visual/Audio Requirements.

## Acceptance Criteria

**Core Rule 1 — delta set computation**

1. GIVEN plant P's `growth_stage` = 2 at batch start and 3 at batch end, and
   nothing else changed, WHEN the delta set is computed at the
   CATCHING_UP→ACTIVE transition, THEN the delta set contains exactly one
   item `{category: Growth, target: P, from: 2, to: 3}`.
2. GIVEN creature C's PRESENT/ABSENT flag is identical at batch start and
   batch end, WHEN the delta set is computed, THEN no item is generated
   for C.
3. GIVEN an identical pre-batch/post-batch snapshot pair, WHEN delta
   computation is invoked twice with that same pair, THEN both
   invocations return identical delta sets (same items, categories,
   order) — confirms determinism as a pure function of the snapshot pair.

**Core Rule 2 — categorization**

4. GIVEN plant P's `growth_stage` changes 1→2, WHEN the delta set is
   computed, THEN P's item is categorized Growth.
5. GIVEN plant P's `growth_stage` changes 3→1 (regression), WHEN the delta
   set is computed, THEN P's item is still categorized Growth
   (direction-agnostic).
6. GIVEN creature C transitions ABSENT→PRESENT within the batch, WHEN the
   delta set is computed, THEN C's item is categorized Arrival.
7. GIVEN creature C transitions PRESENT→ABSENT within the batch, WHEN the
   delta set is computed, THEN C's item is categorized Departure.
8. GIVEN Ecosystem Simulation's rare-bloom flag fires for plant P during
   the batch, WHEN the delta set is computed, THEN a Detail Event item
   referencing P is generated.
8a. **(new 2026-08-09, Core Rule 2a)** GIVEN creature C is ABSENT at both
   batch-start and batch-end, but Ecosystem Simulation's
   `was_present_during_batch` flag is `true` for C (it was PRESENT at some
   point during the batch), WHEN the delta set is computed, THEN a
   Departure item referencing C is generated, flagged `full_cycle=true` —
   not suppressed by Rule 2's ordinary same-state-at-both-ends logic.
8b. **(new 2026-08-09, Core Rule 2a)** GIVEN creature C is ABSENT at both
   batch-start and batch-end, and `was_present_during_batch` is `false`
   (never PRESENT during the batch — the ordinary "nothing changed" case),
   WHEN the delta set is computed, THEN no item is generated for C —
   confirms the `full_cycle` exception fires only for a genuine
   within-batch residency, not every ABSENT→ABSENT case.

**Core Rule 3 — first session**

9. GIVEN no prior saved state exists (first session), WHEN Time & Drift
   transitions CATCHING_UP→ACTIVE, THEN the computed delta set is empty
   and Discovery Surfacing's state is IDLE.

**Core Rule 4 — staggered activation**

10. GIVEN a deterministic 3-item queue and `pacing_delay = 4.0`, WHEN
    `activation_time(i)` is evaluated for i=0,1,2, THEN the results are
    0.0s, 4.0s, 8.0s respectively — no two items share an activation time.

**Core Rule 4a — pause on backgrounding (added round 1 `/design-review`)**

10a. GIVEN state REVEALING with focused-elapsed-time `t=2.0s` since queue
    start, WHEN the tab is backgrounded (`visibilitychange`→hidden) for
    45 real-world seconds and then refocused, THEN the queue's
    focused-elapsed-time resumes at `t=2.0s` (unchanged by the
    backgrounded duration) — no items that would have activated or faded
    during the backgrounded interval are skipped or auto-completed.
10b. GIVEN an item i with `activation_time(i)=8.0s` that has not yet
    activated when the tab backgrounds, WHEN the tab remains backgrounded
    for any duration and is then refocused, THEN item i still activates
    only once focused-elapsed-time reaches 8.0s post-refocus — never
    immediately upon refocus regardless of real-world elapsed time.

**Core Rule 5 — per-element cue**

11. GIVEN a discovery item is active, WHEN its target reference is
    queried, THEN it resolves to a specific plant/creature id or
    last-known position — never null and never a shared/global target
    referenced by multiple items.

**Core Rule 6 — fixed fade, no acknowledgment**

12. GIVEN item i activates at `activation_time(i)` and
    `cue_fade_duration = 6.0`, WHEN `fade_end_time(i)` is evaluated, THEN
    it equals `activation_time(i) + 6.0`, independent of any
    observation/look event.
13. GIVEN item i reaches `fade_end_time(i)` and no observation event was
    ever recorded for it, WHEN its final state is queried, THEN it
    carries no "seen"/"acknowledged" flag distinguishing it from an item
    that was viewed.

**Core Rule 7 — departure**

14. **(corrected 2026-08-09 — position source, see Core Rule 7 above)**
    GIVEN creature C transitions PRESENT→ABSENT and Ecosystem Simulation's
    `last_known_position` for C is `(x,y)`, WHEN C's Departure item is
    generated, THEN its target position equals `(x,y)` and its cue type
    is Departure, distinct from Arrival's cue type.
14a. **(new 2026-08-09, Core Rule 2a/7)** GIVEN creature C has never had a
    live instance (its `last_known_position` is still the `(0, 0)`
    default, per `ecosystem-simulation.md` AC27) and its first residency
    resolves as a `full_cycle` departure, WHEN C's Departure item is
    generated, THEN its target position is `(0, 0)`, the jar-floor
    center — an honest approximation, not an error or a null target.

**Core Rule 8 — queue ordering**

15. GIVEN a batch yields one item each of Growth, Departure, Detail
    Event, Arrival, WHEN the queue is ordered, THEN the order is exactly
    [Growth, Departure, Detail Event, Arrival].
16. GIVEN two Growth items for P1, P2 where P1's registration index <
    P2's, WHEN the queue is ordered, THEN P1 precedes P2 within the
    Growth tier.
17. GIVEN two Detail Event items whose associated plants P1, P2 have
    registration index P1 < P2, WHEN the queue is ordered, THEN P1's
    Detail Event item precedes P2's within the Detail Event tier — same
    tie-break rule as every other category.
18. GIVEN the same delta set computed twice, WHEN the queue order is
    generated both times, THEN the order is identical both times.

**Core Rule 9 — never blocks input**

19. GIVEN the queue is REVEALING with one or more items currently visible
    or still pending, WHEN the player issues a tending/drag interaction
    on any element (including one with an active cue), THEN the
    interaction produces the same resulting state change, on the same
    frame, with no additional latency attributable to queue processing,
    as the identical interaction issued while state is IDLE — nothing is
    blocked, delayed, or intercepted. **(Operational definition added
    round 1 `/design-review`, `qa-lead` finding.)**

**Formulas**

20. GIVEN `pacing_delay=4.0`, `cue_fade_duration=6.0`, `n=3`, WHEN
    `total_reveal_duration` is computed, THEN it equals 14.0s.
21. GIVEN `n=1`, same constants, WHEN computed, THEN
    `total_reveal_duration = 6.0s` (range floor).
22. GIVEN `n=8`, same constants, WHEN computed, THEN
    `total_reveal_duration = 34.0s` (range ceiling at recommended
    defaults — **corrected round 1 `/design-review`, `systems-designer`
    finding**: true max queue depth is 8, not 7, since a single plant can
    contribute both a Growth item and a Detail Event item in one batch;
    see Formulas' Variables table).
23. GIVEN `pacing_delay(4.0) < cue_fade_duration(6.0)`, WHEN
    `activation_time(i+1)` and `fade_end_time(i)` are compared for any
    consecutive i, THEN `activation_time(i+1) < fade_end_time(i)` —
    confirms deliberate overlap.

**States and Transitions**

24. GIVEN state IDLE, WHEN Time & Drift reaches ACTIVE with an empty
    delta set, THEN state remains IDLE.
25. GIVEN state IDLE, WHEN Time & Drift reaches ACTIVE with a non-empty
    delta set, THEN state becomes REVEALING and item 0 is immediately
    visible (`activation_time(0)=0`) — no separate waiting period
    precedes the first cue.
26. GIVEN state REVEALING and elapsed time `t` since the queue started,
    WHEN `t` satisfies `activation_time(i) ≤ t < fade_end_time(i)` for
    item i, THEN item i reports visible, independent of any other item's
    activation or fade state.
27. GIVEN state REVEALING and `pacing_delay(4.0) < cue_fade_duration(6.0)`,
    WHEN elapsed time `t` satisfies
    `activation_time(i+1) ≤ t < fade_end_time(i)` for consecutive items i,
    i+1, THEN both item i and item i+1 report visible simultaneously —
    confirms the state model supports deliberate overlap.
28. GIVEN state REVEALING, WHEN elapsed time since the queue started
    reaches `total_reveal_duration`, THEN state becomes IDLE.

**Edge Cases**

29. GIVEN creature C is PRESENT at batch start, ABSENT mid-batch, PRESENT
    again by batch end, WHEN the delta set is computed, THEN no item is
    generated for C.
30. GIVEN plant P's `growth_stage` is 2 at batch start, becomes 3
    mid-batch, returns to 2 by batch end, WHEN the delta set is computed,
    THEN no item is generated for P.
31. GIVEN item i is visible with `activation_time(i)=t0` and
    `fade_end_time(i)=t0+cue_fade_duration`, WHEN the player interacts
    with item i's target element at any time strictly between t0 and its
    fade_end_time, THEN `fade_end_time(i)` is unchanged and the item
    still stops being visible at exactly the original fade_end_time.
32. GIVEN state REVEALING with items still pending or visible, WHEN Time
    & Drift's ACTIVE→INACTIVE transition fires (a true close/unload, not
    backgrounding — per `time-drift.md`'s own States and Transitions),
    THEN the remaining queue is discarded and the next delta set is
    computed solely from Ecosystem Simulation's state at that next
    session's catch-up, with zero carryover.
33. GIVEN Persistence/Save falls back to default-init (both fallback
    tiers exhausted) and Time & Drift consequently computes
    `ticks_to_apply=0`, WHEN CATCHING_UP→ACTIVE fires, THEN the delta set
    is empty and state is IDLE — same outcome as AC 9.

*(`qa-lead` consulted — mandatory for this high-risk section regardless of
review mode. Their review also surfaced a real contradiction between the
States/Transitions table and the Formulas section's deliberate-overlap
design, since fixed in Detailed Design above, plus the Detail Event
tie-break gap fixed in Core Rule 8 and the Core Rule 1 live-session
clarification.)*

*(Fixed 2026-08-09 — cross-GDD review finding, no formal specialist
re-review round (user decision), same pattern as this project's other
same-session fixes. **Core Rule 7's Departure position source corrected**:
was described as "the creature's position at the moment of transition," a
value with no observer for the now-dominant case where departure resolves
entirely inside Time & Drift's invisible catch-up batch — Creature
Behavior never spawns a live instance for a creature that settles ABSENT
(`creature-behavior.md` Core Rule 8), so no such moment is ever actually
witnessed. Corrected to source from Ecosystem Simulation's own
`last_known_position` (that system's new Core Rule 12), which freezes at
the creature's true most-recent position instead of requiring a live
observation at the exact transition instant. **New Core Rule 2a
`full_cycle` exception added**: closes a second gap the same review found
— Core Rule 2's net-delta suppression was silently swallowing a complete
spawn-then-departure residency that occurs entirely within one catch-up
batch (reachable at this game's actual tuned values, not hypothetical),
producing zero player-visible trace of a real event and cutting against
Pillar 4. Now generates a `full_cycle`-flagged Departure item, driven by
Ecosystem Simulation's new `was_present_during_batch` flag (Core Rule 13).
AC8a/8b (Core Rule 2a) and AC14a (Core Rule 7 default position) added;
Interactions table and Edge Cases updated to match. See
`ecosystem-simulation.md` Core Rules 12/13 for the full mechanism this
document consumes.)*

## Open Questions

1. **Departure's "residual light disturbance" VFX treatment** has no
   direct real-world reference (unlike Growth/Arrival/Detail Event, which
   anchor to real light-material behaviors) — needs a dedicated
   technical-artist prototype before Diorama Rendering implements it.
   Owner: technical-artist. Target: before Diorama Rendering's
   `/architecture-decision`.
2. **No art bible exists yet.** This system's Visual/Audio Requirements
   (the four per-category cue treatments, the ease-in/hold/ease-out
   motion rule, the "would the lighting still make physical sense without
   the glow?" test) should seed its Lighting/VFX section once authored.
   Owner: art-director.
3. **Per-cue light/material rendering cost** against the ≤500 draw call
   budget (Compatibility renderer) under deliberate cue overlap — up to 5
   concurrent at `pacing_delay=2.0`/`cue_fade_duration=10.0` (the
   maximum-concurrency combination, distinct from the 66.0s
   maximum-duration combination — see Tuning Knobs), corrected round 1
   `/design-review` from an earlier "2-3" estimate, precise combination
   corrected this review (`systems-designer` finding) — needs profiling
   once Diorama Rendering actually implements the cues, and that
   profiling must also account for the concurrent day/night tint and any
   active object drag tween (`performance-analyst` finding, this review).
   **Verification path added (round 1 `/design-review`, `qa-lead`
   finding)**: gate this via a named `/smoke-check` before Diorama
   Rendering's implementation story is marked Done, not left as an
   open-ended profiling task with no milestone. Owner: technical-artist /
   performance-analyst.
