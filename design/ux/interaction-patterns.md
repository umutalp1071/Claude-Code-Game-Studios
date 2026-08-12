# Interaction Pattern Library

> **Status**: Complete — first pass, pending `/ux-review`
> **Author**: user + ux-designer
> **Last Updated**: 2026-08-10
> **Template**: Interaction Pattern Library

---

## Overview

Terrarium is built around a deliberate **"zero UI chrome"** principle: 10 of the
project's 11 MVP systems declare no UI Requirements at all — every player-facing
signal is diegetic (in-world light, material, or motion behavior), not a
conventional menu, HUD, panel, or toast. The one exception (the mute/volume
control, Pattern 8) is scoped tightly precisely *because* it's an exception to
this rule, not a foothold for more UI chrome later.

Because of this, most patterns below are **gestural or diegetic** rather than
widget-based — there is no button/modal/dropdown catalog to build here. What
this library actually catalogs is: (1) the two device-agnostic input gestures
everything routes through, (2) the small set of feedback *treatments* (wobble,
snap-back, discovery cues, tints, reveals) those gestures and simulation state
changes produce, and (3) two cross-cutting *contracts* (kill-and-restart
retrigger, the ease-in/hold/ease-out motion language) that keep all of those
treatments feeling like one coherent physical world instead of a grab-bag of
per-system effects.

New systems (Alpha/Full Vision tier) should default to reusing an existing
pattern here before inventing a new feedback treatment — see Gaps & Patterns
Needed for where this catalog is known to be incomplete.

---

## Pattern Catalog

| # | Pattern | Category | One-line |
|---|---|---|---|
| 1 | Tap Gesture | Input | Device-agnostic press-release within threshold |
| 2 | Drag Gesture | Input | Device-agnostic press-move-release beyond threshold |
| 3 | Wobble Acknowledgment | Feedback | Non-committal rotational nudge for a tap-on-object |
| 4 | Snap-back Revert | Feedback | Eased positional correction on invalid/canceled drop |
| 5 | Diegetic Discovery Cue | Feedback / Data Display | Per-element ambient cue revealing what changed since last visit |
| 6 | Watering Feedback Swell | Feedback | Same-frame visual+audio confirmation of a watering tap |
| 7 | Kill-and-Restart Retrigger | Implementation pattern | Shared no-stack/no-queue retrigger policy for all tweens |
| 8 | Persistent Mute/Volume Control | UI Chrome | The one conventional UI element in the game |
| 9 | Save-Confirmation Cue | Feedback | Brief signal that a save blob was restored |
| 10 | Ease-in/Hold/Ease-out Motion Language | Motion contract | The one motion vocabulary every tween shares |
| 11 | STALLED-state Continuous Tint | Feedback / Data Display | Live per-frame desaturation cue, moisture-ok/light-not-ok |
| 12 | Catch-up Growth Reveal | Feedback | Once-per-session eased scale transform for session-start growth |

---

## Patterns

### 1. Tap Gesture

**Category**: Input
**Used In**: Input Abstraction (source) → Tending Input, Object Placement

**Description**: A device-agnostic press-and-release gesture that fires when a
press begins and ends at approximately the same position, regardless of mouse
vs. touch.

**Specification**:
- Fires when press-release happens within `threshold_mouse` (8px) or
  `threshold_touch` (16px) — boundary strict `>`, not `>=`
- Carries `position` (Vector2, jar-local, converted before the event fires),
  `device_id` (`DEVICE_ID_MOUSE` or touch-point index)
- No feedback of its own — feedback is owned by whichever consuming system
  handles the tap
- Distance-only threshold, no time component (no long-press/double-tap
  gestures in this game)
- Multi-touch: only the first active touch point is tracked

**Accessibility**: Single-pointer, one-hand operable by construction; no
motor barrier known. Mouse/touch parity already enforced at the platform
level. See `accessibility-requirements.md` Motor Accessibility.

**When to Use**: Any single, momentary player-initiated action with no
held/dragged state.
**When NOT to Use**: Interactions needing continuous position tracking during
a hold — use Drag Gesture.
**Reference**: `input-abstraction.md` Core Rules 1-2, States/Transitions.

---

### 2. Drag Gesture

**Category**: Input
**Used In**: Input Abstraction (source) → Object Placement

**Description**: A device-agnostic press-move-release sequence that fires when
a press moves beyond a distance threshold before release.

**Specification**:
- Fires `drag_start` when movement exceeds threshold; PRESSED→DRAGGING is a
  one-way latch
- `drag_move` carries `delta`; `drag_end` carries `canceled` (true when ended
  via pointer interruption, not normal release)
- Position clamped to viewport edge if out of bounds mid-drag (mouse); touch
  behavior at the canvas edge unverified
- Single active pointer only — a second `device_id` is ignored while one is
  already active

**Accessibility**: Fine-motor precision concern, tracked but not yet
resolved — touch's larger drag threshold (16px vs. mouse's 8px) may make
small, deliberate drags systematically harder to land on touch than mouse.
Inherited from `input-abstraction.md`'s own Open Question, not re-derived
here. See `accessibility-requirements.md` Motor Accessibility ("Drag
precision").

**When to Use**: Continuous movement the player commits or reverts at
release.
**When NOT to Use**: Momentary actions — use Tap Gesture.
**Reference**: `input-abstraction.md` Core Rules 1, 3, 7, 8; Formulas.

---

### 3. Wobble Acknowledgment

**Category**: Feedback
**Used In**: Object Placement (trigger) → Diorama Rendering (visual)

**Description**: A brief, non-committal rotational nudge acknowledging a tap
on a repositionable object's footprint without picking it up — closes the
touch feedback gap where a tap can register without crossing the (larger)
touch drag threshold.

**Specification**:
- Trigger: tap (not drag) within an object's footprint
- Visual: 4° peak sine-pulse rotation over 0.30s, `TRANS_SINE`/`EASE_IN_OUT`,
  rotation only — no position/scale change
- Retrigger: kill-and-restart (Pattern 7)
- Emotional register locked: must read as "the jar noticed you," never
  rejection

**Accessibility**: Rotation-only motion, no color dependency — no known
gap. The not-yet-designed reduced-motion mode must preserve this cue's
signal (shorten/reduce, don't remove) since it's this game's only feedback
for a touch tap that fell short of the drag threshold. See
`accessibility-requirements.md` Visual Accessibility ("Motion/animation
reduction mode").

**When to Use**: Confirming a tap-on-target registered without committing an
action.
**When NOT to Use**: Genuine action confirmation — use Watering Feedback
Swell instead.
**Reference**: `object-placement.md` Core Rule 7; `diorama-rendering.md` Core
Rule 6, Formulas.

---

### 4. Snap-back Revert

**Category**: Feedback
**Used In**: Object Placement (trigger) → Diorama Rendering (visual)

**Description**: An eased positional correction returning a dragged object to
its last committed position on an invalid or canceled drop.

**Specification**:
- Trigger: `canceled==true` (always reverts), or `canceled==false` with an
  invalid pending position
- `duration = clamp(0.18 + distance×0.0014, 0.18, 0.45)`s,
  `TRANS_CUBIC`/`EASE_OUT`
- Retrigger: kill-and-restart (Pattern 7)
- Never a hard rejection message — always a gentle revert (Anti-Pillar: NOT
  punishing)

**Accessibility**: Positional motion, no color dependency — no known gap.
Same reduced-motion-mode caveat as Wobble Acknowledgment applies: the
revert's own motion is the confirmation a drop was rejected, so a
reduced-motion pass must shorten it, not silently cut it.

**When to Use**: Any drag-and-drop with a graceful, non-punishing revert.
**When NOT to Use**: A committed/valid placement — just renders at the new
position.
**Reference**: `object-placement.md` Core Rule 4; `diorama-rendering.md` Core
Rule 6, Formulas.

---

### 5. Diegetic Discovery Cue

**Category**: Feedback / Data Display
**Used In**: Discovery Surfacing (pacing) → Diorama Rendering (visual)

**Description**: A per-element, non-blocking ambient light/material cue
revealing one "what changed since you left" item at a time — replaces every
conventional badge/toast/notification panel in this game.

**Specification**:
- 4 categories: Growth (subsurface bloom), Arrival (specular catch-light,
  only category with motion), Departure (cooling desaturation at last-known
  position), Detail Event (brightest-briefest point-light bloom)
- Staggered: `activation_time(i) = i × pacing_delay` (4.0s); cues
  deliberately overlap (`cue_fade_duration`=6.0s > `pacing_delay`)
- Fixed fade regardless of whether the player looked — no "seen" state
  tracked
- Queue order: Growth → Departure → Detail Event → Arrival, then
  registration order
- Never blocks gameplay input
- Motion: ease-in/hold/ease-out only (Pattern 10)
- Real, individually-instantiated `Light2D` nodes — must pass "would the
  lighting make physical sense without the glow?"

**Accessibility**: Two real, unresolved gaps. (1) Colorblind-safe
verification hasn't been run yet — the Growth/Departure pair relies on
warm-vs-cool temperature contrast, which several colorblind types compress.
(2) Missed-cue recovery: a cue that fades unseen is gone for good, by
design (Core Rule 6) — a genuine cognitive-accessibility tension for a
player who's distracted or steps away mid-reveal, accepted as a design
tradeoff for now, not silently overlooked. See
`accessibility-requirements.md` Visual and Cognitive Accessibility.

**When to Use**: Surfacing any state change the player wasn't present to see
happen live.
**When NOT to Use**: Live, in-session player-caused feedback — those get
dedicated same-frame cues.
**Reference**: `discovery-surfacing.md` Core Rules 2/2a/4-8;
`diorama-rendering.md` Core Rule 7.

---

### 6. Watering Feedback Swell

**Category**: Feedback
**Used In**: Tending Input (trigger) → Diorama Rendering (visual) + Ambient
Audio (audio)

**Description**: A same-frame, multi-sensory rise-hold-fall swell confirming
a watering tap landed — the fast half of the tending pair.

**Specification**:
- Trigger: `apply_watering()`, same frame, no `call_deferred`/`await`
  anywhere in the chain
- Visual: substrate `self_modulate` darkens/cool-shifts + brief `energy`
  boost on existing sun `Light2D` (no new node)
- Audio: soft trickle-texture swell on the ambient loop, never a discrete
  "ding"
- Shared 3-second envelope across both channels — reads as one sensory
  moment
- Retrigger: kill-and-restart independently per channel (Pattern 7)

**Accessibility**: Lower risk than most patterns here — it's
player-triggered, so the tap's own timing already confirms the action
registered even if the visual tint shift is hard to perceive. If a future
reduced-motion pass dampens the visual half, the audio half should remain
intact as a redundant channel.

**When to Use**: Immediate, low-effort confirmation of a player action.
**When NOT to Use**: State the player wasn't present to cause — use Diegetic
Discovery Cue.
**Reference**: `tending-input.md` Core Rule 3; `diorama-rendering.md` Core
Rule 11; `ambient-audio.md` Core Rule 3.

---

### 7. Kill-and-Restart Retrigger

**Category**: Implementation pattern (shared contract, not directly
player-facing)
**Used In**: Wobble, Snap-back, STALLED-tint, Watering Swell

**Description**: The shared policy for what happens when an already-mid-
animation effect retriggers — never stack, never queue, always continue from
the live interpolated value.

**Specification**:
- Persistent stored `Tween` reference on the owning node
- On retrigger: `kill()` the reference before `create_tween()` again — never
  run two concurrent tweens on the same property
- Godot 4's `Tween` has no `stop()`-and-reconfigure API for this
- Rationale: queuing would let rapid repeated input produce an unbounded
  backlog — the "nagging UI feedback" failure mode

**Accessibility**: Implementation-only pattern with no direct player-facing
accessibility surface of its own — inherited by whichever patterns use it.

**When to Use**: Any effect plausibly re-triggered by rapid repeated input
before it finishes.
**When NOT to Use**: One-shot effects with no rapid-retrigger path (e.g.
Catch-up Growth Reveal).
**Reference**: `diorama-rendering.md` Snap-back/Wobble Timing section.

---

### 8. Persistent Mute/Volume Control

**Category**: UI Chrome (the *only* conventional UI element in the game)
**Used In**: Ambient Audio

**Description**: A small, always-reachable control for the one persisted
audio preference — the sole exception to this project's locked "zero UI
chrome" rule.

**Specification**:
- Fixed corner placement, not floating
- ≤4% of viewport area
- Persistent visibility, never fade-after-idle
- ≥44×44px hit area
- Z-order above all diegetic content
- "Diegetic-adjacent" styling (a switch/vent/dial, not a flat glyph)
- Mouse and touch work equally, no hover-only reach

**Accessibility**: The `≥44×44px` hit area and persistent (never
fade-after-idle) visibility requirements are themselves
accessibility-motivated, already locked at the GDD level. Text/icon
contrast on the control still needs verification once its exact treatment
is designed (`ambient-audio.md` Open Question 2). This is the one pattern
in the whole library where a future screen-reader pass (Comprehensive tier)
would actually have something concrete to attach to.

**When to Use**: This exact control only.
**When NOT to Use**: Don't generalize into a pattern for future settings
without revisiting the "zero UI chrome" exception this makes.
**Reference**: `ambient-audio.md` Core Rule 7, UI Requirements.

---

### 9. Save-Confirmation Cue

**Category**: Feedback
**Used In**: Persistence/Save (trigger) → Diorama Rendering (visual, TBD)

**Description**: A brief, easy-to-miss confirmation that a save blob was
successfully restored.

**Specification**:
- Fires once, on session start, only if a blob was successfully restored
  (current or last-known-good)
- Does NOT fire on first-ever session or full default-init fallback — a
  false "saved" signal would actively mislead
- Exact visual treatment not yet locked (Diorama Rendering's call)

**Accessibility**: No color dependency, low-frequency (once per session at
most). A reduced-motion pass should still leave some detectable signal
rather than removing it silently — this is the player's only confirmation
their tending actually survived.

**When to Use**: This exact moment only.
**When NOT to Use**: Not a general success-toast pattern.
**Reference**: `persistence-save.md` Core Rule 8.

---

### 10. Ease-in/Hold/Ease-out Motion Language

**Category**: Motion contract (cross-cutting)
**Used In**: Discovery Surfacing (origin) → Diorama Rendering, Ambient Audio

**Description**: The one motion vocabulary every animated element shares, so
the game reads as one coherent physical world rather than mixed
UI-feedback/diegetic styles.

**Specification**:
- One rise-hold-fade arc — no looping pulse/blink
- Never linear or bouncy — bounce reads as UI feedback (avoided everywhere
  except Pattern 8)
- Visual: `TRANS_SINE`/`EASE_IN_OUT` (pulse/glow) or
  `TRANS_CUBIC`/`EASE_OUT` (positional, "settling under weight")
- Audio: quarter-sine ("equal-power") ease — avoids the loudness dip a
  linear/cubic amplitude fade causes

**Accessibility**: **The single biggest open accessibility item in this
game.** Every other pattern in this library either cites this one directly
or inherits its timing/easing, and nearly all of them carry real
information through motion (a Departure's settle, a STALLED plant's tint
shift) rather than decorating an already-legible state. A reduced-motion
mode therefore cannot simply disable this language — it needs its own
design pass (shorten/simplify while preserving the signal), not yet done.
See `accessibility-requirements.md` Open Questions.

**When to Use**: Any new tweened/animated effect added to this game.
**When NOT to Use**: N/A — deviations should be deliberate, flagged
exceptions.
**Reference**: `discovery-surfacing.md` Visual/Audio Requirements;
`diorama-rendering.md`; `ambient-audio.md` Fade Envelope.

---

### 11. STALLED-state Continuous Tint

**Category**: Feedback / Data Display
**Used In**: Diorama Rendering

**Description**: A live, every-frame desaturation cue for a plant whose
moisture is fine but light is out of tolerance — the one cue that must
respond immediately to live watering rather than only at session
boundaries.

**Specification**:
- Evaluated every frame: `stalled = moisture_ok AND NOT light_ok`
- Etiolation-based tint (pale, yellow-green-shifted), `self_modulate`
  multiply
- 0.6s transition, `TRANS_SINE`/`EASE_IN_OUT`
- Retrigger: kill-and-restart (Pattern 7)
- Mandated, not optional — the only thing distinguishing "paused" from
  "broken" for a watering player

**Accessibility**: **The one confirmed color-only-indicator gap in the
whole game.** Nothing currently distinguishes "frozen because STALLED"
from "frozen because nothing changed this tick" without perceiving the
tint — no non-color backup exists yet. Needs resolution before this
pattern's implementation story is marked Done. See
`accessibility-requirements.md`'s Color-as-Only-Indicator Audit.

**When to Use**: Live, frame-by-frame state signals needing visibility
before the next session boundary.
**When NOT to Use**: Session-boundary-only changes — use Diegetic Discovery
Cue.
**Reference**: `diorama-rendering.md` Core Rule 3, Formulas.

---

### 12. Catch-up Growth Reveal

**Category**: Feedback
**Used In**: Diorama Rendering

**Description**: A once-per-plant-per-session eased scale transform
reconciling pre/post catch-up growth, so a returning player sees the plant
"settle into its new size" rather than silently popping.

**Specification**:
- Only for a plant with an active Growth discovery item this session
- Sprite hard-swaps at the ease's midpoint, never cross-fades
- Scale eases from `from`-stage to `to`-stage over 0.5s,
  `TRANS_SINE`/`EASE_IN_OUT`
- Unaffected plants render instantly (the common case)

**Accessibility**: No color dependency, one-shot per plant per session. A
reduced-motion pass should shorten this rather than remove it — the
sprite-swap-at-the-ease's-midpoint timing is itself part of what
communicates that growth occurred, not just decoration on top of an
already-obvious change.

**When to Use**: Session-start-only, for a plant whose `growth_stage`
changed during catch-up.
**When NOT to Use**: Never live/mid-session.
**Reference**: `diorama-rendering.md` Core Rule 2/2a, Formulas.

---

## Gaps & Patterns Needed

- **Mute/volume control interaction detail** — Pattern 8's box is locked (fixed
  corner, ≤4% viewport, ≥44×44px, diegetic-adjacent styling) but the exact
  corner choice, icon treatment, and popover interaction pattern (tap-to-toggle
  vs. tap-to-open-popover vs. drag-to-adjust) are still open per
  `ambient-audio.md`'s own Open Question 2. Owner: ux-designer/art-director.
- **Alpha-tier jar-switching navigation** — Multi-Jar Management (systems-index.md,
  Alpha tier, Not Started) will need some way to move between jars. No pattern
  exists yet, and it's the first interaction in this game that would need
  actual navigation (as opposed to in-place tending) — likely the first real
  test of whether "zero UI chrome" survives multiple jars. Owner:
  ux-designer/game-designer, before Multi-Jar Management's own GDD.
- **Alpha-tier seasonal visual transition** — Seasonal Cycle (Alpha tier, Not
  Started) will extend Time & Drift's cosmetic day/night cycle into a seasonal
  one. Likely reuses Pattern 10 (Motion Language) and something like Pattern 8's
  `CanvasModulate` gradient approach, but at a different timescale — not yet
  designed. Owner: art-director, before Seasonal Cycle's own GDD.
- **Full Vision Collection Tracking UI** — Collection Tracking (Full Vision tier,
  Not Started) is the one future system most likely to need conventional UI
  (a gallery/checklist of observed creatures) — a direct tension with "zero UI
  chrome" that hasn't been resolved yet. Flagging now so it isn't discovered
  as a surprise design conflict when that system's GDD is authored. Owner:
  creative-director, before Collection Tracking's own GDD.
- **No inconsistencies found between existing specs** — expected, since this is
  the first `design/ux/*.md` file; re-check this section once a per-screen spec
  exists to cross-reference against.

---

## Open Questions

- **Player journey map doesn't exist yet.** Designing without it means this
  library was built from GDD Core Rules/Formulas alone, without confirming
  against actual player-emotional-state context at each interaction point.
  Template available at `.claude/docs/templates/player-journey.md`. Owner:
  ux-designer/game-designer.
- ~~**Accessibility tier not yet defined.**~~ — **RESOLVED 2026-08-10**:
  `design/ux/accessibility-requirements.md` now exists (Standard tier
  committed) and each of the 12 patterns above carries its own Accessibility
  note. Two real gaps surfaced by that pass remain genuinely open, not
  resolved by adding the notes themselves: (1) reduced-motion mode doesn't
  exist yet and needs its own design pass, since motion carries real
  information in nearly every pattern here (Pattern 10); (2) the
  STALLED-state tint (Pattern 11) is a confirmed color-only indicator with
  no non-color backup yet. Both tracked in `accessibility-requirements.md`'s
  own Open Questions, not restated here.
- **No art bible exists yet.** Several patterns (STALLED tint, discovery cues,
  watering sheen) already carry provisional color/material values authored
  directly in their owning GDDs (`diorama-rendering.md`, `ambient-audio.md`) —
  this pattern library references those values rather than owning them, but an
  eventual art bible should reconcile them into one canonical palette. Owner:
  art-director.
