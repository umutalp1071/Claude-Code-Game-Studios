# Ambient Audio

> **Status**: round 1 blockers resolved (full-mode `/design-review`, 2026-08-05) — 12 blockers, resolved below.
> **Author**: user + audio-director, systems-designer, qa-lead, game-designer, performance-analyst, gameplay-programmer, godot-specialist, ux-designer, creative-director
> **Last Updated**: 2026-08-05
> **Implements Pillar**: Pillar 4 (Every Detail Rewards Attention) — via the "Sensation" MDA aesthetic
> **Creative Director Review (CD-GDD-ALIGN)**: NEEDS REVISION (full-mode `/design-review`, 2026-08-05) — 12 blockers, resolved below. Two reactive-layer formulas redesigned to share one output unit; browser autoplay policy addressed; mute-control constraints locked. No structural rework — every fix localized.

## Overview

Ambient Audio is the sound layer that makes the jar feel like a real,
quietly alive place: a continuous, looping nature soundscape
(birdsong-adjacent ambience, soft water/moisture texture, faint rustle)
underlying every session, plus a small set of optional reactive audio
layers (a soft response to watering, a texture shift accompanying
Discovery Surfacing's cues) layered on top without ever becoming discrete
"sound effect" stingers. It is fully automatic and passive — the player
never directly operates audio (no music player UI, no sound triggers they
consciously fire) — it simply plays, continuously, for as long as a
session is open. It exists because the concept doc names "Sensation"
(sensory pleasure) as a co-primary aesthetic goal alongside
diorama-realism visuals, and explicitly calls an "ambient nature
soundscape... central to the calm feeling" the game is built around;
without it, the jar would be a silent diorama, undermining half of the
game's core sensory pitch. MVP scope is deliberately narrow: a single
ambient loop, not a full music/sound-design pass (explicitly excluded
from MVP per the concept doc's own Scope Tiers) — this GDD defines that
loop and its handful of optional reactive layers, not a broader audio
system.

## Player Fantasy

The player never operates Ambient Audio, but they feel it constantly — it
is the sensory undertone present in literally every second spent with the
jar. The fantasy it serves is named directly in the concept doc:
"Sensation," a co-primary aesthetic alongside Diorama Rendering's visual
identity, not a secondary polish layer. Where Diorama Rendering makes the
jar look like a real, tiny, believable place, Ambient Audio makes it
sound like one — together they're what turns "checking on my jar" from a
glance into a moment worth lingering in. This directly serves the game's
calm, low-pressure tone: the soundscape should read as something the
player could leave running and just listen to, the audio equivalent of
Diorama Rendering's "macro photograph you could stare at for an hour." If
this system fails — a loop with an audible seam/repeat, a mix too sparse
to register as "alive" or too busy to read as calm, or any sound that
plays as a discrete jingle/stinger rather than a continuous texture — it
breaks the "Sensation" pillar exactly the way flat/cartoon shading would
break Diorama Rendering's.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Review manually before
production.)*

## Detailed Design

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Review manually before production.)*

### Core Rules

1. A single continuous ambient loop plays for the full duration of any
   ACTIVE session, starting the moment the scene is ready to render (same
   "no gap" timing as Diorama Rendering's own session-start guarantee).
   **Loop-point architecture stated explicitly (added this review,
   `gameplay-programmer`/`godot-specialist` finding)**: the crossfade is
   baked into the source audio file at author time (see Loop Authoring,
   Visual/Audio Requirements — "last ~2-4s under first ~2-4s"), then
   played back as **one `AudioStreamPlayer` using Godot's native Ogg
   loop-point metadata** — never a runtime dual-`AudioStreamPlayer`
   cross-mix. This was previously implied only by the content-authoring
   section, leaving an implementer to guess between two materially
   different architectures.
1a. **Browser autoplay policy (new this review — `performance-analyst`/
   `gameplay-programmer`/`godot-specialist` independently converging
   finding).** Browsers block an `AudioContext` from producing sound
   until a prior user gesture (click/tap/key) unlocks it — a
   platform-level restriction inherited from the Web Audio API
   regardless of Godot version, not addressed anywhere in the original
   version of this rule. `play()` still fires at scene-ready with zero
   added delay, exactly as Core Rule 1 already promises, but if the
   audio context is not yet unlocked, playback holds silently
   (`PENDING_GESTURE`, see States and Transitions) rather than being
   audible. The fade-in begins on the player's **first input of any
   kind** — Tending Input's first tap/drag already supplies this signal,
   so no dedicated "click to enable sound" prompt is needed or wanted
   (a prompt would itself violate the zero-UI-chrome anchor `discovery-
   surfacing.md`/`diorama-rendering.md` establish, and break the calm
   first impression this system exists to create).
2. The ambient loop is the **only required audio** in this GDD's MVP
   scope. Every other sound in this document is optional and additive —
   the game must feel and sound complete with the loop alone, matching
   the concept doc's explicit MVP exclusion of "music beyond a single
   ambient loop."
3. **Reactive layer — watering**: Tending Input's `apply_watering()` call
   may trigger a soft, textural swell layered on top of the ambient loop
   (e.g. a brief rise in a water-trickle texture already present in the
   mix) — never a discrete "ding"/stinger, never an interruption or
   restart of the base loop.
4. **Reactive layer — discovery cues**: Discovery Surfacing's active
   queue item may trigger a soft ambient-bed shift for its duration, per
   that GDD's own already-locked handoff note in its Visual/Audio
   Requirements ("texture-based ambient-bed shifts, not discrete
   per-cue dings... Departure should get no sound at all, or an even
   softer treatment than the other three"). This system **executes**
   that handoff; it does not redefine Discovery Surfacing's cue
   categories or timing.

   **Intensity now weighted by category, not just count (corrected this
   review, `creative-director` ruling on a `game-designer` finding)**:
   the prior version scaled the boost purely by `N_active` (how many
   cues happen to be concurrently visible), which meant three simultaneous
   mundane Growth ticks could outrank one rare Detail Event — inverting
   meaning rather than withholding it, since a bigger number reading as
   "more important" is itself information, just backwards information.
   The texture itself stays **uniform** across categories (still no
   ear-learnable per-category identity, preserving the original
   anti-informational intent) — only its *intensity* now reflects which
   category is present via `CATEGORY_WEIGHT` (see Formulas), with
   `N_active` demoted to a secondary term rather than the primary driver.
   **Envelope timing rule, stated explicitly (added this review,
   `gameplay-programmer` finding)**: there is one continuous shared
   envelope for "discovery cues are currently active," not one per cue —
   its `t` starts at `0` only when the first cue enters REVEALING after a
   period where none were active, and does **not** reset when `N_active`
   subsequently changes (a cue entering or leaving while others remain
   active); only the coefficient the envelope scales toward changes. This
   mirrors Core Rule 3's watering-retrigger principle (continues from its
   current interpolated level, never restarts from 0) rather than leaving
   it as a gap the watering case didn't have.
5. **No music beyond the single ambient loop** — no discrete
   melodic/thematic score, no stingers, no achievement-style jingles
   anywhere in this system. Matches both the Anti-Pillar against
   demanding attention and the concept doc's explicit MVP scope cut.
6. This system never gates or blocks gameplay input — audio is purely
   additive/observational, the same "never blocks" guarantee Discovery
   Surfacing and Diorama Rendering already commit to.
7. **A persisted mute/volume control is required**, not optional polish:
   looping audio with no off-switch is an accessibility basics gap. No
   dedicated Settings system exists yet in this project's systems index
   — Ambient Audio owns a minimal `ambient_volume` (0.0–1.0) and `muted`
   (bool) setting, persisted via Persistence/Save. **Reworded this review
   (`ux-designer` finding)**: previously called this ownership
   "provisional... until a future Settings system absorbs it" — but
   `systems-index.md` lists a Settings system only as a possible future
   addition, not a committed one. This is **the permanent home for this
   setting unless and until a Settings system is actually scoped**, not
   a placeholder to be casually superseded — the control built for this
   GDD (see UI Requirements) should be built to last, not treated as
   throwaway.
8. The ambient loop plays identically regardless of Time & Drift's
   cosmetic `day_night_phase` — **explicitly not wired together for
   MVP**. `systems-index.md` already names a day/night-reactive audio
   layer as a stretch goal ("wireable to Time & Drift later"), not MVP
   scope; this document locks that as a deliberate cut, not an oversight.

### States and Transitions

| State | Trigger | Next State |
|---|---|---|
| INACTIVE | session not yet ACTIVE (Time & Drift) | INACTIVE (self, no-op) |
| INACTIVE | session becomes ACTIVE, scene ready, audio context already unlocked | LOOPING (ambient loop starts, brief fade-in) |
| INACTIVE | session becomes ACTIVE, scene ready, audio context NOT yet unlocked (new this review, Core Rule 1a) | PENDING_GESTURE (`play()` fires, holds silently at `SILENCE_FLOOR_DB`) |
| PENDING_GESTURE | player's first input of any kind fires (new this review) | LOOPING (fade-in begins now, at `t=0`, per the Fade Envelope formula — not backdated to session start) |
| LOOPING | player mutes | MUTED (loop continues playing internally but audible volume is 0 — never stopped/restarted, so unmuting resumes in-phase with no re-fade-in) |
| MUTED | player unmutes | LOOPING |
| LOOPING | session ends (Time & Drift ACTIVE→INACTIVE) | INACTIVE |
| MUTED | session ends | INACTIVE |
| PENDING_GESTURE | session ends (rare — session closes before any input ever fires) | INACTIVE |

The two reactive layers (Core Rules 3–4) are transient overlays on top of
whichever top-level state is active — a watering swell or a Discovery cue
bed shift never produces its own top-level state, and both respect
`MUTED` (silent, not merely quieter, while muted).

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Tending Input | Upstream (soft) | Reads the `apply_watering()` trigger to layer the optional watering swell (Core Rule 3) |
| Discovery Surfacing | Upstream (soft) | Reads the **live set** of discovery cues currently in their REVEALING window — category per item (needed to compute `W`, the max active `CATEGORY_WEIGHT`), plus the count (`N_active`, **corrected this review to 1–5**, was stale "1–3") needed by the Reactive Layer Boosts formula — not just a single "active item," since up to 5 cues can be concurrently visible by that GDD's own corrected deliberate-overlap design |
| Time & Drift | Upstream (soft) | Reads the ACTIVE/INACTIVE session boundary to start/stop the loop; `day_night_phase` is deliberately **not** read for MVP (Core Rule 8) |
| Persistence/Save | Upstream (soft, new dependency) | Reads/writes the persisted `ambient_volume`/`muted` setting across sessions (Core Rule 7) |

Ambient Audio has **no downstream dependents** — a leaf system, same
pattern as Diorama Rendering.

## Formulas

Four formula groups (expanded this review — was three): converting the
persisted linear volume/mute setting into Godot's `volume_db` scale, the
fade envelope shared by session-start fade-in and mute/unmute, the two
reactive-layer boosts (watering, discovery cues — now pure deltas, see
Reactive Layer Boosts), and a new combining function that sums both
boosts against `base_volume_db` under two explicit ceilings before
writing the final bus volume.

### Volume/Mute Conversion

`volume_db = (muted OR ambient_volume ≤ 0.0) ? SILENCE_FLOOR_DB : max(SILENCE_FLOOR_DB, 20 × log10(ambient_volume))`

Naive `20×log10(x)` alone never reaches true silence (approaches −∞
asymptotically, undefined at 0) — both the `muted` and
`ambient_volume == 0.0` cases are routed to an explicit finite floor
instead of relying on the log curve to get there.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| ambient_volume | — | float | 0.0–1.0 | persisted linear volume slider (Core Rule 7) |
| muted | — | bool | {true, false} | persisted mute toggle (Core Rule 7) |
| SILENCE_FLOOR_DB | — | float | constant, −80.0 | practical silence floor, matches Godot's own audio-bus panel slider floor |

**Output Range:** `[-80.0, 0.0]` dB — always finite by construction,
never `-INF` (Godot's built-in `linear_to_db()` returns `-INF` at 0; this
formula deliberately clamps instead, so downstream comparisons/
serialization/tweening never special-case infinity).
**Examples:** `ambient_volume=1.0, muted=false` → `0.0dB` (unity).
`ambient_volume=0.5, muted=false` → `-6.02dB`. `ambient_volume=0.5,
muted=true` → `-80.0dB` (true silence regardless of slider).
`ambient_volume=0.0, muted=false` → `-80.0dB` (slider-at-zero is also
true silence, not merely "very negative").

### Fade Envelope

One shape, two durations — a quarter-sine ("equal-power") ease, the
audio-industry-standard fade curve (chosen over this project's visual
`TRANS_CUBIC`/`EASE_OUT` convention because a linear or cubic
amplitude fade causes an audible loudness dip mid-fade; quarter-sine
avoids that while still satisfying "never linear or bouncy").

`volume_db(t) = SILENCE_FLOOR_DB + (target_volume_db - SILENCE_FLOOR_DB) × ease(clamp(t/D, 0, 1))`
`ease(x) = sin(x × π/2)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| t | — | float | 0.0–D | seconds elapsed since the transition trigger fired |
| D | — | float | constant, 0.08 or 2.0 | `MUTE_DECLICK_DURATION` (mute/unmute) or `AMBIENT_FADE_IN_DURATION` (session start) |
| target_volume_db | — | float | −80.0–0.0 | destination level (Volume/Mute Conversion's output, or `SILENCE_FLOOR_DB` when muting) |

**Output Range:** `[-80.0, target_volume_db]`, monotonic — `ease(x)` never
overshoots (no bounce).
**Two applications:**
- **Session-start fade-in** (INACTIVE→LOOPING): `D = AMBIENT_FADE_IN_DURATION
  = 2.0s`, starts at `SILENCE_FLOOR_DB`, target = the Volume/Mute
  Conversion formula's output. One-directional ease-in only.
- **Mute/unmute** (LOOPING↔MUTED): `D = MUTE_DECLICK_DURATION = 0.08s`
  (80ms) — well under the ~150–300ms threshold where a fade becomes
  consciously perceptible. This is not a repeat of the 2.0s fade-in; it
  exists purely to avoid a sample-domain discontinuity click that a
  literal 0ms snap would produce.

**Example (fade-in):** `ambient_volume=0.8` → `target=-1.94dB`. At
`t=0.5s`: `x=0.25`, `ease=sin(22.5°)=0.383` →
`volume_db=-80+78.06×0.383=-50.1dB`. At `t=2.0s`: `-1.94dB` (target
reached).
**Example (unmute):** same `-1.94dB` target, `D=0.08s`. At `t=0.04s`
(`x=0.5`): `ease=0.707` → `volume_db=-24.8dB`. Full transition completes
in 80ms — reads as instant, but click-free.

### Reactive Layer Boosts

**Redesigned this review (`creative-director` ruling on `systems-designer`/
`qa-lead` findings — both independently confirmed the same arithmetic
error in the prior worked examples and AC16).** Root cause: the prior
`watering_layer_db` returned an *absolute level* (`base_volume_db +
boost`) while `discovery_boost_db` returned a bare *delta* — two
different output units combined as if interchangeable, which is what
produced the wrong worked-example numbers. Both are now pure deltas,
combined by one explicit function below. Watering gets the more
perceptible, single-shot treatment (player-initiated, wants clear "the
jar responded" feedback). Discovery cues get a softer treatment now
weighted by **which category is present**, not merely how many.

**Watering boost (pure delta):**
`watering_boost_db(t) = WATERING_BOOST_DB × envelope(t, D_water)`

**Discovery boost (pure delta, category-weighted — corrected this
review, `creative-director` ruling on a `game-designer` finding):**
`discovery_boost_db(t, N_active, W) = min(DISCOVERY_BOOST_MAX_DB, SINGLE_CUE_BOOST_DB × W + N_BUSYNESS_DB × log10(max(1, N_active))) × envelope(t, cue_fade_duration)`

where `W = max(CATEGORY_WEIGHT[c] for c in active_categories)` — the
highest-weighted category currently present in the REVEALING window, not
a sum or an average. **This replaces `DEPARTURE_MULTIPLIER`
entirely**: a Departure-only active set now naturally evaluates to
`W=0` (silent), and — the actual bug the old multiplier design never
correctly handled — a Departure cue active *alongside* a Growth or
Arrival cue no longer silences the whole boost, since each category
contributes only through `W`, not a single global on/off flag applied to
the entire call.

`envelope(t, D)` = normalized rise-hold-fall shape (ease-in 1/6·D, hold
1/3·D, ease-out 1/2·D, each phase using the Fade Envelope's quarter-sine
ease) — matches this project's established "ease-in/hold/ease-out, one
rise-hold-fade arc" motion language (`discovery-surfacing.md`,
`diorama-rendering.md`).

**Combined output (new this review):**
`final_volume_db(t) = min(HEADROOM_CEILING_DB, base_volume_db + min(COMBINED_BOOST_MAX_DB, watering_boost_db(t) + discovery_boost_db(t, N_active, W)))`

This is the value actually written to the ambient bus — `base_volume_db`
(Volume/Mute Conversion's output) is never modified in place; both
reactive layers are summed as deltas, that sum is capped, then the whole
result (base + capped boosts) is capped again against an absolute
headroom ceiling. This closes three findings from this review in one
change: the missing combined-boost ceiling (`systems-designer`), the
undocumented clipping/headroom risk from a boosted signal exceeding 0dB
unity gain (`systems-designer`), and the missing AC for simultaneous
watering+discovery stacking (`qa-lead`).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| base_volume_db | — | float | −80.0–0.0 | loop's current steady-state level (Volume/Mute Conversion's output) |
| WATERING_BOOST_DB | — | float | constant, 4.0 | peak dB added during a watering swell |
| D_water | — | float | constant, 3.0 (seconds) | `WATERING_SWELL_DURATION` |
| SINGLE_CUE_BOOST_DB | — | float | constant, 2.5 | the discovery boost's own peak dB at maximum category weight (`W=1.0`) |
| CATEGORY_WEIGHT | — | float | Detail Event 1.0, Arrival 0.8, Growth 0.55, Departure 0.0 | per-category intensity weight — Departure's `0.0` absorbs the prior `DEPARTURE_MULTIPLIER` |
| W | — | float | 0.0–1.0 | `max(CATEGORY_WEIGHT[c])` across all currently-active discovery categories |
| N_active | — | int | **1–5 (corrected this review, `systems-designer`/`qa-lead` finding — was stale "1–3")** | count of discovery cues currently in their REVEALING window (`discovery-surfacing.md`'s own corrected cap: up to 5 concurrent at its Tuning Knobs' legal extremes) |
| N_BUSYNESS_DB | — | float | constant, 1.0 (new) | small secondary coefficient — `N_active` now contributes a modest "busyness" term, demoted from its prior role as the primary driver |
| DISCOVERY_BOOST_MAX_DB | — | float | constant, 5.0 (renamed from `BOOST_DB_MAX`, same value) | defensive per-layer ceiling on the discovery boost alone — see Output Range note below on why this is now rarely reached |
| cue_fade_duration | — | float | 6.0 (reused directly from `discovery-surfacing.md`'s registered constant) | bed-shift envelope matches the visual cue's own fade duration exactly |
| COMBINED_BOOST_MAX_DB | — | float | constant, 6.0 (new) | ceiling on `watering_boost_db + discovery_boost_db` summed together, before either touches `base_volume_db` |
| HEADROOM_CEILING_DB | — | float | constant, −1.0 (new) | absolute ceiling on the final output — standard mixing-headroom practice (reserving output below 0dBFS even at maximum slider position) so a boosted signal can never clip regardless of `ambient_volume`; **this is intentional, not a slider malfunction** — flagged for confirmation during the listening-test pass already required in Open Questions |

**Output Range:** `watering_boost_db` bounded to `[0.0, 4.0]`;
`discovery_boost_db` bounded to `[0.0, DISCOVERY_BOOST_MAX_DB]` but, at
the current constants, its practical ceiling is `SINGLE_CUE_BOOST_DB ×
1.0 + N_BUSYNESS_DB × log10(5) ≈ 2.5 + 0.70 = 3.2dB` — meaning
`DISCOVERY_BOOST_MAX_DB=5.0` is a defensive backstop that isn't actually
reachable under these constants, not a routinely-hit cap the way it was
before this review's redesign; `final_volume_db` is bounded to
`[SILENCE_FLOOR_DB, HEADROOM_CEILING_DB]` always, regardless of any
combination of boosts.

**Example (watering alone, peak, base=-1.94dB):**
`watering_boost_db = 4.0dB` (pure delta) → `final_volume_db = min(-1.0,
-1.94 + min(6.0, 4.0 + 0.0)) = min(-1.0, 2.06) = -1.0dB` — the headroom
ceiling engages here, capping what would otherwise be a
louder-than-unity 2.06dB.
**Example (discovery alone, single Detail Event, N_active=1, peak,
`W=1.0`):** `discovery_boost_db = min(5.0, 2.5×1.0 + 1.0×log10(1)) =
min(5.0, 2.5) = 2.5dB` (corrected — was wrongly stated as `0.56dB`).
**Example (three simultaneous Growth cues, N_active=3, `W=0.55`,
peak):** `discovery_boost_db = min(5.0, 2.5×0.55 + 1.0×log10(3)) =
min(5.0, 1.375+0.477) = 1.852dB` — still noticeably **quieter** than one
Detail Event's `2.5dB` above, confirming the fix: count alone can no
longer outrank the rarer category.
**Example (watering + discovery simultaneously, base=-1.94dB, watering
at peak, one Detail Event cue at peak, `W=1.0, N_active=1`):**
`watering_boost_db + discovery_boost_db = 4.0 + 2.5 = 6.5`, capped by
`COMBINED_BOOST_MAX_DB` to `6.0` → `final_volume_db = min(-1.0, -1.94 +
6.0) = min(-1.0, 4.06) = -1.0dB` — both the combined-boost cap and the
headroom ceiling engage in this worked example.

*(`systems-designer` consulted for these formulas — mandatory per this
section's high-risk gate, applies regardless of review mode.)*

## Edge Cases

- **If the player mutes**: implemented as a true `AudioServer.set_bus_mute()`
  on the ambient bus, not solely reliance on the −80dB floor from the
  Volume/Mute Conversion formula. `−80dB` is "very quiet," not
  hardware-silent — a true bus mute is a real zero-output flag, and it
  still doesn't stop or restart the underlying `AudioStreamPlayer`, so it
  remains fully compatible with the States table's "loop continues
  playing internally, never stopped" requirement.
- **If the player drags the volume slider while LOOPING** (not a
  INACTIVE→LOOPING or mute/unmute state transition): the new
  `volume_db` snaps instantly via the Volume/Mute Conversion formula —
  the Fade Envelope formula applies only to the two named transitions
  (session-start fade-in, mute/unmute declick), never to ordinary live
  slider adjustment.
- **If watering triggers a new swell while a previous watering swell is
  still active** (before `D_water=3.0s` elapses): the envelope
  retriggers, continuing from its current interpolated level rather than
  stacking two additive boosts — same anti-stacking principle the
  Reactive Layer Boosts formula already applies to concurrent discovery
  cues, extended to rapid repeated watering.
- **If the session ends while LOOPING or MUTED** (Time & Drift's
  ACTIVE→INACTIVE transition): the loop stops with a hard cut, no
  fade-out — matches Diorama Rendering's own precedent of no special
  session-teardown treatment, and coincides with the scene tearing down
  regardless.
- **If a loaded `ambient_volume` is outside `[0.0, 1.0]`** (corrupted
  save data): the Volume/Mute Conversion formula's implementation
  defensively clamps it to `[0.0, 1.0]` before use — this preference is
  deliberately **not** gated by Persistence/Save's strict
  `save_blob_validity` check (a companion note added there, 2026-08-05):
  a corrupted volume value is cosmetic, not simulation-critical, and must
  never discard `jar_moisture`/`growth_stage`/etc. alongside it the way
  a genuine blob-validity failure would.
- **If Persistence/Save falls back to default-init** (both fallback
  tiers exhausted, per that GDD's own Edge Cases): `ambient_volume` and
  `muted` simply take their documented defaults (0.7, `false` — see
  Tuning Knobs) — same "first session" convention every other system in
  this project already follows, no special handling needed here.
- **If Discovery Surfacing's active cue set changes mid-envelope** (a
  cue enters or exits its REVEALING window while the discovery
  ambient-bed shift is already playing): `N_active` and `W` (the active
  set's max category weight) are both re-evaluated live and the boost
  recalculates continuously from the Reactive Layer Boosts formula —
  there is no separate "per-cue" envelope instance to manage. **`t`-reset
  rule stated explicitly (added this review, `gameplay-programmer`
  finding — previously a gap without the equivalent rule watering
  already had)**: the shared envelope's `t` starts at `0` only when the
  active set transitions from empty to non-empty (the first cue of a new
  active window), and does **not** reset when the set's membership
  changes thereafter (a cue entering or leaving while others remain
  active) — only `N_active`/`W`, and therefore which coefficient the
  in-progress envelope scales toward, change. This mirrors Core Rule 3's
  watering-retrigger principle (continue from the current interpolated
  level, never restart from 0) rather than leaving Discovery's case
  without an equivalent rule.
- **If watering and a Discovery ambient-bed shift are both active
  simultaneously** (new this review, `systems-designer`/`qa-lead`
  finding — previously unaddressed): both boosts are summed as deltas
  and the sum is capped by `COMBINED_BOOST_MAX_DB`, then the whole
  result is capped again by `HEADROOM_CEILING_DB` — see the Reactive
  Layer Boosts formula's new Combined Output. Neither layer is silenced
  or paused for the other; both contribute, bounded.

## Dependencies

Ambient Audio depends on:
- **Tending Input** (soft) — the `apply_watering()` trigger, for the
  optional watering swell (Core Rule 3)
- **Discovery Surfacing** (soft) — the live set of discovery cues
  currently in their REVEALING window (category per item, plus count —
  up to 5, corrected this review), for the optional ambient-bed shift
  (Core Rule 4)
- **Time & Drift** (soft) — the ACTIVE/INACTIVE session boundary only, to
  start/stop the loop; `day_night_phase` is deliberately not read for
  MVP (Core Rule 8)
- **Persistence/Save** (soft, new dependency) — read/write of the
  persisted `ambient_volume`/`muted` setting (Core Rule 7)

All four are soft dependencies: this system degrades gracefully with any
of them absent or undesigned — the base ambient loop (Core Rule 1) still
plays with default volume and no reactive layers, satisfying this GDD's
own "loop alone is a complete experience" requirement (Core Rule 2).

Ambient Audio has **no downstream dependents** — a leaf system, same
pattern as Diorama Rendering.

**Companion edit made alongside this GDD's authoring (2026-08-05)**:
`tending-input.md`'s "Watering cue treatment" Open Question is partially
resolved — the audio half now has a concrete answer here (Core Rule 3,
Reactive Layer Boosts formula); the visual half (ripple/mist/droplet)
remains open, since `diorama-rendering.md` never defined a
watering-specific visual effect.

**Bidirectionality**: none of the four upstream GDDs previously listed
Ambient Audio as a downstream dependent (it was `Not Started` until this
session) — all four are soft/optional dependencies from this system's
own side, so no companion edit to their Dependencies sections is required
for consistency (a soft dependency need not be reciprocated the way a
hard one must be, since this system's absence or undesign never blocks
theirs).

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| default `ambient_volume` (first session) | 0.5–0.85 | Too quiet on first launch — a player may think audio is broken/missing before finding the setting | Startles/overwhelms a player who wasn't expecting sound, undercutting the calm first impression |
| `AMBIENT_FADE_IN_DURATION` | 1.0–4.0s | Sudden audio onset reads as jarring, breaking the calm first moment | Session feels like it's "waiting for audio" before feeling complete |
| `WATERING_BOOST_DB`/`D_water` | boost 2–6dB, duration 1.5–5s | Too subtle to register as feedback — defeats `tending-input.md`'s whole reason for wanting a watering cue | Reads as an alert/stinger, breaking Core Rule 3's "never a discrete ding" rule |
| `SINGLE_CUE_BOOST_DB`/`DISCOVERY_BOOST_MAX_DB` (**renamed this review from `BOOST_DB_MAX`**) | single 1.5–4dB, cap 3–7dB | Discovery cues become audio-inert, undercutting their pairing with the visual cue's own "Sensation" purpose | Multiple overlapping cues read as noisy/alarming, contradicting "the jar is quietly alive in a few places" |
| `CATEGORY_WEIGHT` (new this review) | Detail Event fixed at 1.0 (ceiling reference); Arrival/Growth/Departure 0.0–1.0, monotonic with visual rarity | Weights too close together defeats the fix this review made — count would dominate again | Weights too far apart (e.g. Growth near 0) makes the common case nearly silent, undercutting "Sensation" for most of a session |
| `N_BUSYNESS_DB` (new this review) | 0.5–1.5 | Concurrent cue count becomes inaudible even as a secondary signal | Busyness term competes with `CATEGORY_WEIGHT` for dominance, reopening the count-outranks-rarity problem this review fixed |
| `COMBINED_BOOST_MAX_DB` (new this review) | 5–8dB | Watering and discovery boosts cancel each other out when both active, reading as inconsistent | Combined stacking reads as noisy even after the headroom ceiling clips it |
| `HEADROOM_CEILING_DB` (new this review) | −3 to 0dB | Below −3, even peak boosts stay too quiet to register as feedback | Above 0dB reopens the unity-gain clipping risk this review's fix exists to close |
| `SILENCE_FLOOR_DB` | −100 to −60 | Closer to −100 risks perceptible residual noise depending on asset/hardware noise floor | Closer to −60 may not read as "true" mute to a sensitive listener |

All values above are formula-consistent placeholders, not validated
against real audio assets — a listening-test pass is required once
actual ambient audio content exists (see Open Questions).

## Visual/Audio Requirements

*(This section defines sonic content and direction — what the audio
actually contains and how a sound designer would source it. The dB math,
fade curves, and reactive-layer volume math are already fully specified
in Formulas above; this section does not redefine any of it.)*

### Ambient Loop — Sonic Palette

Three layers, close-mic'd/intimate perspective — matching Diorama
Rendering's macro-lens closeness; this is not a wide outdoor field
recording, it should read as if your ear is right up against the jar,
not standing in a meadow.

1. **Distant songbird bed** — sparse, occasional single calls, not a
   dawn chorus, pitched/EQ'd soft and distant. Reference species: robin,
   wren, or similar small garden bird. Source real field recordings of a
   quiet garden/woodland at a calm mid-morning hour (a dawn chorus is
   too dense/busy for this), or licensed nature-ambience libraries
   tagged "garden ambience, sparse birdsong, no wind."
2. **Water/moisture micro-texture** — continuous, very low-level, closer
   to felt-than-heard: condensation/dew micro-drip, damp moss, faint
   trickle. Source: contact-mic'd wet moss, terrarium/vivarium drip
   recordings, or a quiet stream recorded close and heavily low-passed
   to strip its "stream" identity down to pure texture. Avoid anything
   identifiable as a river or waterfall — the terrarium's water content
   is condensation-scale, not flowing-water scale.
3. **Foliage rustle** — intermittent, irregular (not rhythmic or
   loop-obvious), soft brushing/settling texture: dry fern frond against
   fern frond, light leaf-litter shift. Source: foley of dry
   leaves/ferns handled gently, or light-breeze-through-undergrowth
   field recordings low-passed to remove any audible "wind" character.

**Explicitly excluded**: wind (jar is enclosed — no wind), flowing
water/streams (scale mismatch), loud/dense bird choruses (reads busy/
gamey, breaks calm), rhythmically-pulsing insect chirps (risks reading
as a timer/alert), any tonal or musical element (breaks Core Rule 5's
no-music rule).

### Loop Authoring

- **Target length**: **4–6 minutes before repeat (raised this review,
  `creative-director` ruling on a `game-designer` finding — was 90–150
  seconds)**. Player Fantasy claims parity with "a macro photograph you
  could stare at for an hour" and names "an audible seam/repeat" as this
  system's own failure condition — a 90–150s loop repeats 24–80 times
  across the concept doc's own 30–120 min Session-Level core loop, which
  fails that bar through sheer repetition regardless of how irregularly
  events are placed within it. At Vorbis quality ~4–5, a 4–6 minute loop
  is still only ~4MB, a reasonable Web asset size. Further variety
  (generative/shuffled stems) is logged as an Open Question, not required
  for this fix.
- **Loop-point technique**: equal-power crossfade (last ~2–4s under
  first ~2–4s, quarter-sine ease — the same curve the Fade Envelope
  formula already establishes), not a hard splice. **Architecture stated
  explicitly (see Core Rule 1)**: this crossfade is baked into the source
  file at author time — the shipped asset's own native Ogg loop point
  sits inside an already-blended region, so playback needs only one
  `AudioStreamPlayer` with no runtime crossfade logic.
- **Source from a long take**: build the loop by selecting a window out
  of a genuinely long field-recording take (10–15 min, lengthened to
  comfortably cover the new 4–6 minute target), not a short repeating
  cell — pick a stretch where the birdsong calls and rustle events land
  unevenly (several calls, several rustles, no predictable interval), so
  the loop doesn't feel "on a timer."

### Web Export Format

- **Format**: Ogg Vorbis — Godot's native compressed format, good
  size/quality tradeoff for a looping bed, avoids MP3 licensing/decode-gap
  issues.
- **Import mode**: **corrected this review (`godot-specialist` finding,
  verified against this project's own pinned engine-reference docs)** —
  struck the prior "streamed, not fully decoded to memory" claim. Godot's
  Ogg Vorbis playback (`AudioStreamOggVorbis`) has no WAV-style RAM-vs-
  Stream import toggle — that setting is specific to `.wav` import; Ogg
  Vorbis decode is inherently chunk-based already, with no separate
  import-mode choice to make. No action needed here beyond removing the
  inaccurate claim.
- **Quality target**: Vorbis quality ~4–5 (roughly 96–128kbps VBR) — this
  content has no sharp transients that demand high bitrate; that range
  keeps the (now 4–6 minute) loop around 3–5MB, still reasonable for
  browser delivery.
- **Channels**: stereo, even if narrow/subtle width — a mono ambient bed
  reads flatter and more artificial.

### Reactive Layer Content

- **Watering swell**: built from the water/moisture micro-texture layer
  (palette item 2) already present in the mix, not a bolted-on splash
  one-shot. The swell is literally "the trickle/drip texture that's
  already quietly there becomes briefly more present" — reusing the
  existing source material is what keeps it from reading as an inserted
  SFX, and is the concrete reason Core Rule 3 forbids a discrete "ding."
- **Discovery ambient-bed shift**: **one uniform texture** across all
  three non-silent categories (Growth, Arrival, Detail Event) — the
  songbird layer's presence nudged up. **Corrected this review
  (`performance-analyst`/`godot-specialist` finding)**: struck the prior
  "a slight EQ/filter opening" phrasing — Formulas only ever computes a
  `volume_db` scalar, never a filter/EQ cutoff parameter, so an actual
  filter effect was never specified and would require its own
  `AudioEffectFilter` bus setup and formula this document doesn't define.
  The volume nudge alone is what's implementable from Formulas as
  written. Category *identity* stays purely visual — Discovery
  Surfacing's own doc already differentiates the three categories that
  way — but **intensity** now varies by category (Core Rule 4's
  `CATEGORY_WEIGHT`), not by uniform count alone: giving audio three
  distinct *textures* would risk the player learning to audio-identify
  categories by ear, pulling audio toward being informational rather
  than atmospheric (contradicting Core Rule 2 and this system's
  anti-stinger stance) — but giving every category the *same weight*
  regardless of rarity was its own defect, now fixed. A single uniform
  texture at category-weighted intensity threads both needles.

### Silence-Safe Composition

Mute is a first-class, persisted, accessible setting (Core Rule 7), so
nothing in the visual layer may depend on audio for legibility — already
true by construction, since Discovery Surfacing and Diorama Rendering
are fully visual systems with no audio-only cues. This constrains
sourcing rather than adding a new rule: no detail placed in the ambient
loop should ever become the sole indicator of anything the player needs
to notice. The loop should read as complete when muted the same way a
still photograph of the jar reads as complete without its accompanying
field recording — audio is enrichment layered on an already-complete
visual, never information the player is required to hear.

*(`audio-director` consulted for this system's sonic content and
direction — no art bible or sound-design document exists yet; this
section's treatments are flagged as candidate first entries for a future
one, same pattern as `discovery-surfacing.md`'s and
`diorama-rendering.md`'s own Visual/Audio Requirements.)*

## UI Requirements

Unlike Discovery Surfacing and Diorama Rendering, this system genuinely
needs a UI surface: Core Rule 7's persisted `ambient_volume`/`muted`
setting requires a player-reachable control. Given no dedicated Settings
system exists in this project's scope and Ambient Audio is the only
MVP audio-producing system, the recommended MVP surface is the smallest
correct one: a small, always-reachable mute/volume control (e.g. a
single corner icon — tap/click to mute, drag or a small popover for the
volume level) — not a full settings menu, which would be scope well
beyond what one persisted float and one bool need. Mouse and touch must
work equally per this project's platform standard (no hover-only
interaction as the sole means of reaching it).

**Constraints locked this review (`creative-director` ruling on a
`ux-designer` finding) — no longer left entirely to a future pass.**
This control is the sole exception to a "zero UI chrome" rule that
`discovery-surfacing.md` and `diorama-rendering.md` both fought to
establish and hold ("UI Requirements: None" in both). The exception to a
locked rule deserves tighter scoping than the rule itself, not looser —
deferring every decision risked whoever implements this reaching for a
generic flat mute icon and puncturing the "macro photograph" illusion
Pillar 4 depends on. This document now locks:
- **Fixed corner placement**, not floating/repositionable.
- **≤4% of viewport area** — small enough to never compete with the
  jar's own visual density (Pillar 4: "every detail rewards attention").
- **Persistent visibility, never fade-after-idle.** This is the actual
  answer to discoverability in a zero-onboarding game with no tooltips —
  a control that only appears on hover or after some idle timer is
  undiscoverable by construction in a game that never teaches the player
  to look for it.
- **≥44×44px hit area** (standard mobile accessibility minimum),
  regardless of the icon's own visual footprint within that ≤4% budget.
- **Z-order above all diegetic jar content** — never obscured by or
  competing with scene elements for input priority.
- **"Diegetic-adjacent" styling directive**: should read as an object in
  the world (e.g. styled like a small switch, vent, or physical dial)
  rather than a flat generic UI glyph, so the one necessary exception to
  "no UI chrome" still respects the spirit of that rule as closely as a
  functional control allows.

Exact icon treatment, popover interaction pattern, and pixel-level
placement within the locked corner remain `ux-designer`/`art-director`
territory — this section locks the *box*, not its contents. See Open
Question 2.

## Acceptance Criteria

### Core Rules

1a. **(narrowed this review — see 1b for the cold-start case, `performance-
   analyst`/`gameplay-programmer`/`godot-specialist` finding)** (Rule 1 —
   session-start, no gap, audio context already unlocked) GIVEN a
   session transitions INACTIVE→ACTIVE and the scene is ready to render,
   with the browser's audio context already unlocked by a prior user
   gesture, WHEN the ambient audio system processes this transition,
   THEN `play()` on the ambient loop fires in the same tick as
   scene-ready (zero-frame delay), and the Fade Envelope begins
   evaluating at `t=0` in that same tick. **(Integration — requires a
   mocked `AudioServer`/scene-tree harness, not a pure function.)**
1b. **(new this review)** (Rule 1a — cold start, context not yet
   unlocked) GIVEN the same transition, but the audio context has NOT
   yet been unlocked by any prior user gesture, WHEN the transition
   processes, THEN state becomes `PENDING_GESTURE` (not `LOOPING`),
   `play()` still fires with zero-frame delay but produces no audible
   output, and the Fade Envelope does NOT begin evaluating until the
   player's first input event of any kind fires — at which point state
   becomes `LOOPING` and the fade-in begins fresh at `t=0` from that
   moment, never backdated to session start. **(Integration.)**
2. (Rule 2 — loop alone is complete) GIVEN the loop is LOOPING and
   neither watering nor a discovery cue has ever triggered, WHEN
   `final_volume_db` is computed, THEN it equals `min(HEADROOM_CEILING_DB,
   base_volume_db)` — both reactive boost functions return `0.0dB` when
   never invoked / `N_active=0`.
3. (Rule 3 — watering never restarts base loop) GIVEN the loop is
   LOOPING at stream position P, WHEN `apply_watering()` fires, THEN the
   base `AudioStreamPlayer` is not stopped or re-triggered (no new
   `play()` call), only `watering_boost_db` begins evaluating
   additively into `final_volume_db`, and stream position continues
   advancing from P uninterrupted. **(Integration — requires a mocked
   `AudioServer`/scene-tree harness, not a pure function.)**
4. **(corrected this review — see Reactive Layer Boosts, `DEPARTURE_
   MULTIPLIER` replaced by `CATEGORY_WEIGHT`)** (Rule 4 — Departure gets
   no sound) GIVEN a discovery cue enters REVEALING with category =
   Departure and it is the ONLY active category (`W=0.0`), WHEN
   `discovery_boost_db(t, N_active, W)` is evaluated, THEN the result is
   `0.0dB` for all t; GIVEN a Departure cue active ALONGSIDE a
   Growth/Arrival/Detail Event cue (mixed active set), WHEN evaluated,
   THEN `W` equals the non-Departure category's weight (Departure
   contributes `0.0` to the `max()`, it does not zero the whole result)
   — confirming the fix to the case the prior single global multiplier
   never correctly handled.
5. (Rule 5 — no music beyond the loop) GIVEN the shipped audio asset
   manifest for this system, WHEN all registered `AudioStream`
   resources are enumerated, THEN exactly one loop asset exists and
   none are tagged/named as score, stinger, or jingle. **Paired with a
   manual content-review checklist item** — a manifest audit alone
   cannot catch an untagged asset added later; treat both together, not
   the automated check alone, as satisfying this rule.
6. (Rule 6 — never blocks input) GIVEN Ambient Audio is in any state
   (INACTIVE/LOOPING/MUTED, or mid-envelope), WHEN an `apply_watering()`
   input event is dispatched, THEN the input system processes it to
   completion independent of `AudioServer`/`AudioStreamPlayer` state,
   with no blocking call or error path gated on audio state.
   **(Integration, not Logic — requires a live or mocked `AudioServer` +
   input-dispatch harness, not a pure function; belongs in
   `tests/integration/ambient-audio/`.)**
7. (Rule 7 — persisted mute/volume) GIVEN `ambient_volume=0.35,
   muted=true` set during a session, WHEN the session ends and a new
   session loads via Persistence/Save, THEN both values are restored
   exactly (within float epsilon) before any fade-in evaluation occurs.
8. (Rule 8 — not wired to day/night) GIVEN identical `ambient_volume,
   muted, t`, WHEN `volume_db` is computed once per `day_night_phase`
   value, THEN the result is bit-identical across all phase values — the
   function takes no `day_night_phase` input.

### Formulas

**Volume/Mute Conversion**
9. GIVEN `ambient_volume=0.5, muted=false`, WHEN `volume_db()` is
   called, THEN result `== -6.02dB` (±0.01dB).
10. GIVEN (a) `ambient_volume=0.5, muted=true` and (b)
    `ambient_volume=0.0, muted=false`, WHEN `volume_db()` is evaluated
    for each, THEN both return exactly `-80.0dB`, never `-INF`, never
    below `-80.0`.
11. GIVEN `ambient_volume=1.0, muted=false`, WHEN `volume_db()` is
    called, THEN result `== 0.0dB` exactly.

**Fade Envelope**
12. GIVEN `target_volume_db=-1.94dB, D=2.0s` (`AMBIENT_FADE_IN_DURATION`),
    t passed as an explicit parameter, WHEN `volume_db(t)` is evaluated
    at `t=0.5` and `t=2.0`, THEN `t=0.5 → ≈-50.1dB` (±0.1), `t=2.0 →
    -1.94dB` exactly (target reached, no overshoot).
13. GIVEN `target_volume_db=-1.94dB, D=0.08s` (`MUTE_DECLICK_DURATION`),
    WHEN `volume_db(t)` is evaluated at `t=0.04`, THEN `≈-24.8dB`
    (±0.1); at `t=0.08` returns target exactly with no value in `[0,D]`
    exceeding target.
14. GIVEN any `D>0`, any `target_volume_db ∈ [-80.0, 0.0]`, WHEN sampled
    at increasing t from 0 to D, THEN the sequence is non-decreasing and
    never exceeds `target_volume_db`.

**Reactive Layer Boosts**
15. **(corrected this review — `watering_boost_db` is now a pure delta,
    no `base_volume_db` term)** GIVEN `WATERING_BOOST_DB=4.0`, WHEN
    `watering_boost_db(t)` is evaluated at the envelope's hold phase
    (`envelope=1.0`), THEN result `== 4.0dB` exactly.
16. **(values corrected this review, `systems-designer`/`qa-lead`
    finding — the prior 0.56dB/3.06dB/3.06dB were arithmetically wrong;
    formula also redesigned to be category-weighted, see Reactive Layer
    Boosts)** GIVEN a single Detail Event cue (`W=1.0, N_active=1`)
    evaluated at envelope peak, WHEN `discovery_boost_db(t, N_active, W)`
    is evaluated, THEN result `== 2.5dB` exactly (`min(5.0, 2.5×1.0 +
    1.0×log10(1)) = 2.5`).
16a. **(new this review)** GIVEN three simultaneous Growth cues (`W=0.55,
    N_active=3`) evaluated at envelope peak, WHEN evaluated, THEN result
    `≈ 1.852dB` (`min(5.0, 2.5×0.55 + 1.0×log10(3)) ≈ 1.375+0.477`) —
    confirming this is LOWER than AC16's single-Detail-Event result
    despite the higher count, proving category weight now dominates
    count.
16b. **(new this review, extends coverage to the corrected `N_active`
    ceiling)** GIVEN `N_active=4` and `N_active=5`, each with `W=1.0`
    (Detail Event), evaluated at envelope peak, WHEN evaluated, THEN
    `N=4 → ≈2.90dB`, `N=5 → ≈3.20dB` — both comfortably under
    `DISCOVERY_BOOST_MAX_DB=5.0`, confirming the cap is not routinely
    reached under current constants even at the true maximum concurrency
    (up to 5, per `discovery-surfacing.md`'s corrected cap), not merely
    up to the stale N=3 ceiling the prior AC stopped at.
16c. **(new this review, `systems-designer`/`qa-lead` finding — missing
    AC for simultaneous stacking)** GIVEN watering at peak
    (`watering_boost_db=4.0`) AND a single Detail Event discovery cue at
    peak (`discovery_boost_db=2.5`) simultaneously, with `base_volume_db
    = -1.94dB`, WHEN `final_volume_db(t)` is evaluated, THEN the summed
    boost (`6.5`) is first capped by `COMBINED_BOOST_MAX_DB` to `6.0`,
    THEN the result (`base + 6.0 = 4.06`) is capped by
    `HEADROOM_CEILING_DB` to exactly `-1.0dB` — confirming both caps
    engage correctly in sequence, and the final output never exceeds
    `HEADROOM_CEILING_DB` regardless of how many boosts stack.

### States and Transitions

17. GIVEN state=INACTIVE, session not ACTIVE, WHEN the system ticks,
    THEN state remains INACTIVE, no `play()` call issued. **(Integration.)**
18. GIVEN state=INACTIVE, session becomes ACTIVE with scene ready and the
    audio context already unlocked, WHEN the transition processes, THEN
    state=LOOPING, `play()` fires, fade-in envelope starts at
    `SILENCE_FLOOR_DB` at `t=0`. **(Integration.)**
18a. **(new this review)** GIVEN state=INACTIVE, session becomes ACTIVE
    with scene ready but the audio context NOT yet unlocked, WHEN the
    transition processes, THEN state=`PENDING_GESTURE`, `play()` still
    fires but produces no audible output, no Fade Envelope evaluation
    begins yet. **(Integration.)**
18b. **(new this review)** GIVEN state=`PENDING_GESTURE`, WHEN the
    player's first input event of any kind fires, THEN state=LOOPING,
    fade-in envelope starts fresh at `SILENCE_FLOOR_DB` at `t=0` from
    that moment. **(Integration.)**
19. GIVEN state=LOOPING at stream position P, WHEN the player mutes,
    THEN state=MUTED, `set_bus_mute(true)` called, `AudioStreamPlayer`
    never stopped/reset, position keeps advancing. **(Integration.)**
20. GIVEN state=MUTED, stream has advanced to position P2 while muted,
    WHEN the player unmutes, THEN state=LOOPING, `set_bus_mute(false)`
    called, no fade-in-from-floor envelope triggers (only the 0.08s
    declick), playback resumes audibly at P2 — not restarted.
    **(Integration.)**
21. GIVEN state=LOOPING, WHEN session transitions ACTIVE→INACTIVE, THEN
    state=INACTIVE, playback stops immediately, zero Fade Envelope
    evaluations occur between trigger and stop. **(Integration.)**
22. GIVEN state=MUTED, WHEN session transitions ACTIVE→INACTIVE, THEN
    state=INACTIVE, playback stops immediately, identical hard-cut
    behavior to AC21. **(Integration.)**

### Edge Cases

23. (True bus-mute, not just −80dB) GIVEN state=LOOPING, WHEN the player
    mutes, THEN `AudioServer.get_bus_mute(ambient_bus)==true` AND the
    `AudioStreamPlayer` is never stopped/paused — proves mute uses the
    real bus-mute flag, not reliance on `volume_db→-80` alone.
    **(Integration.)**
24. (Live slider snap vs. fade) GIVEN state=LOOPING, not mid fade-in and
    not mid mute/unmute, WHEN `ambient_volume` changes from 0.5→0.8 via
    live drag, THEN `volume_db` updates to `-1.94dB` on the same tick,
    with zero Fade Envelope function calls for this change.
    **(Integration.)**
25. **(corrected this review — `watering_layer_db` renamed
    `watering_boost_db`, now a pure delta)** (Re-watering retrigger, no
    stacking) GIVEN a watering swell mid-flight, `watering_boost_db(t1)`
    currently at interpolated level L (`0<t1<3.0s`), WHEN a second
    `apply_watering()` fires before `D_water` elapses, THEN the envelope
    resets `t→0` and continues from L (not from 0), and only one
    envelope instance/output ever exists — never the sum of two.
    **(Integration.)**
25a. **(new this review, `gameplay-programmer` finding — the discovery
    envelope's `t`-reset rule previously had no equivalent AC to
    watering's)** (Discovery envelope continuity across membership
    change) GIVEN a discovery ambient-bed envelope already mid-flight
    (one cue active, `t1 > 0`), WHEN a second cue enters the REVEALING
    window before the envelope completes, THEN `t` does **not** reset to
    `0` — it continues from `t1`, and only `N_active`/`W` (and therefore
    the coefficient the envelope scales toward) update; WHEN one of two
    active cues instead exits REVEALING (leaving one still active), THEN
    the same rule applies in reverse — `t` continues uninterrupted,
    only the coefficient changes.
26. (Session-end hard cut, no fade-out, boost mid-flight) GIVEN
    state=LOOPING with an active watering or discovery boost in
    progress, WHEN session transitions ACTIVE→INACTIVE, THEN zero Fade
    Envelope calls occur for teardown, and `stop()` (or scene teardown)
    happens within the same frame as the transition. **(Integration.)**

### Testability Notes (not gaps requiring rework — perceptual claims by nature)

- Rule 1's "no audible seam" and Rule 2's "feels complete" are
  perceptual, not automatable — need a human listening review (same
  evidence tier as Visual/Feel screenshot review: a reviewed audio clip
  + lead sign-off), not a Logic-type unit test.
- The entire Visual/Audio Requirements section (sonic palette choices,
  "reads calm not busy," the "one uniform treatment" decision for
  discovery categories, Vorbis quality/size tradeoffs) is audio-content
  quality — not automatable at all, and already flagged in Tuning Knobs
  as needing a listening-test pass once real audio assets exist.
- UI Requirements (the mute/volume control, mouse+touch parity) needs
  its own manual UI walkthrough evidence per this project's Testing
  Standards when that story is built — not folded into these criteria.

*(`qa-lead` consulted — mandatory for this high-risk section regardless
of review mode. Their review also reclassified AC6 as Integration rather
than Logic, and flagged AC5 as needing a paired manual content-review
step alongside the automated manifest check. **This review (full-mode
`/design-review`, 2026-08-05)**: `qa-lead` and `systems-designer`
independently found and corrected the same arithmetic error in AC16 (see
Reactive Layer Boosts), and extended the Integration-tier reclassification
from AC6 alone to every criterion that calls a real engine API
(AC1a/1b, AC3, AC17–26) rather than leaving them read as pure-function
Logic tests.)*

## Open Questions

1. **Listening-test validation**: all dB/duration constants
   (`SILENCE_FLOOR_DB`, boost values, durations) are formula-consistent
   placeholders, not validated against real audio assets — needs a
   listening-test pass once actual ambient audio content exists. Owner:
   audio-director/sound-designer. Target: before implementation.
2. **Mute/volume control — narrowed this review**: the box is now locked
   (fixed corner, ≤4% viewport, persistent visibility, ≥44×44px hit area,
   diegetic-adjacent styling — see UI Requirements). Still open: exact
   corner choice, icon treatment, and popover interaction pattern within
   those constraints. Owner: ux-designer. Target: before `/ux-design`.
3. **Future Settings system ownership**: whether a future Settings
   system (if ever scoped — none exists today) should absorb ownership
   of `ambient_volume`/`muted` from this GDD. Owner:
   producer/technical-director. Target: if/when a Settings system enters
   the systems index.
4. **Independent base-loop and reactive-layer volume control** (new
   this review, `game-designer` finding): the single mute/volume control
   currently affects the whole mix — there's no way to hear the base
   loop without the reactive layers, or vice versa, despite "Sensation"
   being a co-primary pillar. Logged as a real gap, not silently
   absorbed into "the UI is fine" — but not blocking at MVP scope
   (one slider, one bool). Owner: audio-director/ux-designer. Target:
   revisit if player feedback flags the reactive layers as intrusive.
5. **Loop content variety beyond one authored take** (new this review,
   `game-designer` finding): raising the loop length to 4-6 minutes
   (see Loop Authoring) delays but doesn't eliminate eventual pattern
   recognition across very long "leave it running" sessions. Generative
   variation (shuffled stems, randomized micro-timing per pass) would
   solve this more completely but is real added scope. Owner:
   audio-director. Target: post-MVP, revisit if playtesting flags the
   loop as learnable.
