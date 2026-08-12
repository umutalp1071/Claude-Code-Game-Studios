# Object Placement

> **Status**: Approved — round 13 blockers and recommended items resolved (accepted without a formal specialist re-review round; user decision, see trailing review note). Also separately BLOCKED pending empirical verification of `input-abstraction.md` Core Rules 1/8's Web-export behavior claims before this system's implementation begins — inherited gate, not this doc's own review status (see `input-abstraction.md` header and Edge Cases below).
> **Author**: user + systems-designer
> **Last Updated**: 2026-08-04
> **Implements Pillar**: Pillar 3 (Care, Not Control) — repositioning is the direct, indirect-nudge tending action
> **Creative Director Review (CD-GDD-ALIGN)**: CONCERNS — round 13 full specialist review (game-designer, systems-designer, qa-lead, godot-specialist, creative-director), verdict NEEDS REVISION at time of review; all 3 blockers and 6 recommended items resolved this same pass, text-only (see trailing review note). Post-fix state not re-confirmed by a fresh specialist round, per user's explicit choice to skip re-review.

## Overview

Object Placement lets the player pick up a repositionable object (starting
with a single rock at MVP) and drag it to a new position within the jar,
using the drag gestures Input Abstraction already provides. Mechanically, it
tracks which object is currently held, constrains valid drop positions to
inside the jar and clear of other objects' footprints, and commits the new
position on release. For the player, this is the tactile half of tending the
terrarium — the direct, hands-on counterpart to watering — letting them
nudge the world's arrangement (Pillar 3: Care, Not Control) without ever
fully dictating what grows where.

## Player Fantasy

Repositioning the rock is a small act of quiet care — the player isn't
building or optimizing toward a score or win condition; the satisfaction is
primarily aesthetic and personal, echoing the "arrange for its own sake"
appeal the concept doc cites from Tiny Glade. This directly serves **Pillar
3 (Care, Not Control)**: the player moves an object, but never commands the
ecosystem directly — moss growth and moisture never respond to where the
rock sits. Placement does, however, shape *where* Snail and Moth wander
(`creature-behavior.md` treats every object's footprint as a hard wander
obstacle — see the correction below); a player may come to prefer an
arrangement that happens to draw a creature past more often, and that
preference is theirs, not the game's — an emergent, personal reason to
rearrange, not a hidden objective the system is scoring them against.
**Corrected 2026-08-04 `/design-review`**
(`game-designer` finding): an earlier version of this section additionally
claimed placement "just changes what the jar looks like" as if in isolation
— that understated this same real, live effect: repositioning the rock does
shape where Snail and Moth wander. This is not a contradiction of Pillar 3,
it's Pillar 3 working as designed — the player creates *conditions* (a path
is now open or blocked) rather than *commanding* creature movement directly,
the same indirect-influence pattern the whole game is built on. If this
system felt clunky or imprecise (objects snapping oddly, drags failing on
touch), the player-facing symptom would directly undercut the game's calm,
low-friction promise.

**Reframed 2026-08-04 `/design-review`, round 13** (`game-designer` finding,
`creative-director` ruling): a prior round's opening sentence flatly stated
"no correct position... can never be optimized for outcomes," which read as
a rebuttal to the creature-wandering effect described above rather than an
acknowledgment of it. Considered and rejected as an alternative fix: making
creature visitation frequency placement-invariant, which would make the
world unresponsive to the player's own actions — failing Pillar 3 in the
opposite direction (an inert world, not a controlled one). The paragraph
above now states the concession directly instead of asserting it away.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Review manually before
production.)*

## Detailed Design

### Core Rules

1. Only objects whose `ObjectTypeDef.repositionable == true` can be picked
   up. Non-repositionable objects (if any exist later) are inert to drag
   input entirely.
2. A `drag_start` event whose position falls within a repositionable
   object's current footprint picks that object up — it becomes the single
   "held" object for the duration of the drag.
3. While held, each `drag_move` updates the object's visual position to
   follow the pointer, preserving the initial grab offset (the point where
   the player grabbed the object relative to its origin) — the object's
   origin is not forced to snap to the cursor position. **Corrected
   2026-08-04 `/design-review`, round 13** (`systems-designer` finding):
   "never snaps to the cursor" overclaimed this — if the player grabs
   exactly at the object's own origin, `grab_offset=(0,0)` and the origin
   legitimately does track the cursor 1:1 (see the Drag-follow position
   formula). The offset is always preserved; it just happens to be zero in
   that one case.
4. On `drag_end`, **first check `canceled`** (Input Abstraction's field,
   `true` when the drag ended via a pointer interruption rather than a
   normal release): if `canceled == true`, the object always animates back to
   its last committed position, regardless of whether the pending position
   would otherwise have been valid. Only if `canceled == false` does the
   pending position get validated against placement rules (in-bounds, no
   footprint overlap with another object) — valid commits the new position,
   invalid animates back. Either revert path is a gentle snap-back, never a
   hard rejection message or blocked interaction.
5. Only one object can be held at a time, matching Input Abstraction's
   single-pointer tracking (no multi-touch).
6. A `drag_start` that doesn't originate over any repositionable object's
   footprint is not consumed by this system — it passes through untouched
   (e.g., for Tending Input's watering gesture elsewhere in the jar).
7. A `tap` (not a drag — never exceeded Input Abstraction's drag distance
   threshold) landing within a repositionable object's current footprint
   triggers a brief, non-committal **wobble** acknowledgment on that object —
   its position never changes, and it does not become HELD. This exists so a
   touch player gets feedback when their gesture registers on an object even
   though it didn't cross `threshold_touch`: the same physical displacement
   that would move the object via drag on mouse (`threshold_mouse` is
   smaller) can register as `tap` on touch, and without this rule that tap
   would produce zero feedback of any kind — the exact device-parity failure
   Input Abstraction's own Player Fantasy names as unacceptable. The wobble's
   exact animation (amplitude, duration, easing) is Diorama Rendering's
   implementation detail, same as the snap-back's open styling question
   below — this rule only specifies that some non-silent acknowledgment
   fires.

   **Corrected 2026-08-04 `/design-review`, round 12 (`game-designer`
   finding, `creative-director` ruling) — this rule only closes the
   *feedback* half of touch/mouse parity, not the *capability* half.**
   `input-abstraction.md`'s own Open Questions separately flags that
   `threshold_touch` (16px) being roughly double `threshold_mouse` (8px)
   may make small, deliberate repositioning nudges — exactly this system's
   Player Fantasy — systematically harder to land as a drag on touch than
   on mouse, flagged there for Vertical Slice playtest validation. The
   wobble does not fix that gap, it only ensures a touch tap that falls
   short of the drag threshold isn't silent. **The wobble's emotional
   register is locked here, not left to art-director's styling pass**: it
   must read as a playful acknowledgment ("the jar noticed you"), never as
   a rejection ("you failed, try again") — a wobble that reads as failure
   would violate the Anti-Pillar against punishing mechanics regardless of
   how well-animated it is. Amplitude/duration/easing remain
   art-director's call within that constraint.
8. A `tap` that does not fall within any repositionable object's footprint is
   not consumed by this system — it passes through untouched (e.g., for
   Tending Input's watering gesture).

### States and Transitions

| State | Trigger | Next State | Effect |
|---|---|---|---|
| IDLE | `drag_start` over a repositionable object's footprint | HELD | Object picked up, grab offset recorded |
| IDLE | `tap` over a repositionable object's footprint | IDLE (self) | Wobble acknowledgment fires, no position change |
| HELD | `drag_move` | HELD | Object visual position follows pointer (offset-preserved) |
| HELD | `drag_end`, `canceled == true` | IDLE | Position reverts to last committed (snap-back), regardless of validity |
| HELD | `drag_end`, `canceled == false`, new position valid | IDLE | Position commits |
| HELD | `drag_end`, `canceled == false`, new position invalid | IDLE | Position reverts to last committed (snap-back) |

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Input Abstraction | Upstream | Consumes `drag_start`/`drag_move`/`drag_end`/`tap` + `position`/`delta`/`canceled` |
| Content Data | Upstream | Reads `ObjectTypeDef.repositionable`, `footprint_size` |
| Diorama Rendering | Downstream | Exposes each object's current committed (or in-progress held) position for rendering |
| Creature Behavior | Downstream | Exposes object positions/footprints as wander-destination obstacles (soft dependency — per `creature-behavior.md`'s own framing, this degrades gracefully with zero objects placed; it is not "undesigned," Creature Behavior is authored and reads this live today, see Player Fantasy correction above) |

**Coordinate-space assumption stated (added 2026-08-04 `/design-review`,
round 12, `godot-specialist` finding):** every formula in this document
(`in_bounds`, `no_overlap`, the footprint hit-test below) assumes placed-
object positions live in the same jar-local coordinate space Input
Abstraction converts pointer positions into (`to_local()` or an equivalent
scene-space transform, per `input-abstraction.md` Core Rule 4). This holds
by construction if placed-object nodes are parented under the jar's own
scene node — stated here explicitly so it isn't independently re-derived
(and potentially gotten wrong) elsewhere. If Diorama Rendering's eventual
scene is not a flat 2D jar (e.g. an angled-camera 3D diorama), the pointer-
to-jar-space conversion itself changes on Input Abstraction's side; this
document's formulas are unaffected as long as they keep receiving jar-local
coordinates, but that is a prerequisite decision for Diorama Rendering's own
GDD, not this one.

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Review manually before production.)*

## Formulas

`footprint_size` is defined as a **radius** (jar-space units, same unit as
position coordinates) — treating every object's footprint as a circle
centered on its origin. Circles avoid rotation/orientation edge cases
entirely, which matters for a simple drag-and-drop mechanic rather than a
physics simulation. **Stated explicitly (added 2026-08-04 `/design-review`,
round 13, `godot-specialist` finding):** this system uses no
`Area2D`/`CollisionShape2D` or any physics-engine query — every check below
(`in_bounds`, `no_overlap`, the footprint hit-test) is computed directly
from stored `Vector2` positions and scalar radii. Jolt Physics (this
project's 4.6+ default per `technical-preferences.md`) is a 3D-only engine
default and doesn't apply to 2D collision at all; this note exists only to
foreclose an implementer reaching for `Area2D` overlap signals instead of
this document's own formulas.

**In-bounds check** (jar floor modeled as an ellipse — matches the angled
diorama view, center `(cx,cy)`, radii `(rx,ry)`):

`in_bounds = ((px-cx)/(rx-fp))² + ((py-cy)/(ry-fp))² ≤ 1`

**Domain precondition, stated explicitly (added 2026-08-04 `/design-review`,
round 11, `systems-designer` finding):** this formula is defined only for
`fp < min(rx, ry)`. At `fp = ry` (or `fp = rx`) the corresponding
denominator is zero and the term is undefined (division by zero); for
`fp > min(rx, ry)` the squared negative denominator silently *shrinks* the
effective ellipse rather than erroring, which could wrongly accept or
reject an otherwise-valid placement. Outside this domain, a placement must
be rejected outright (treated as `in_bounds = false`) rather than computed.
This formula is reused verbatim by two other systems —
`persistence-save.md`'s `object_in_bounds`/`creature_in_bounds` clauses,
and `creature-behavior.md`'s destination sampling (which always passes
`fp=0`, so it is unaffected by this precondition) — so this domain
statement covers all three call sites, not just this document's own use.
**Nothing in valid per-field content data reaches this domain today**:
Content Data's `FOOTPRINT_MAX=20.0` sits well under this jar's `ry=60`, and
that ceiling is load-time enforced (`content-data.md`'s `definition_validity`
check, with a paired boundary AC). The precondition is stated here anyway
because the only thing preventing the crossing is a cross-file numeric
coincidence between two independently-tunable constants
(`FOOTPRINT_MAX` here, `rx`/`ry` in this document's own fixed scene
geometry) that `content-data.md` already flagged in its own Open Questions
("`FOOTPRINT_MAX` cross-GDD coupling") as enforced only by a code comment,
not a cross-file check — this note closes that tracked Open Question by
giving the relationship a stated home (`FOOTPRINT_MAX < min(rx, ry)` is now
an explicit invariant, checked here rather than assumed) instead of
resolving it silently.

**Overlap check** (pairwise, generalizes to any number of objects):

`no_overlap = dist(pa, pb) ≥ (fp_a + fp_b) × LENIENCY`

**Variables:**
| Variable | Type | Range | Description |
|---|---|---|---|
| px, py | float | jar-space | pending drop position being validated |
| cx, cy, rx, ry | float | jar-space | jar floor ellipse center/radii |
| fp, fp_a, fp_b | float | `0 < fp < min(rx,ry)` (see domain precondition above) | `footprint_size`, treated as a radius |
| dist(pa,pb) | float | ≥0 | Euclidean distance between two object centers |
| LENIENCY | float | 0.7–0.9 (default 0.8) | shrinks the required clearance so sprites can visually overlap slightly before a placement is rejected — the forgiveness knob, per the Anti-Pillar against finicky/punishing mechanics |

**Commit rule:** `valid = in_bounds AND no_overlap` (checked against every
other currently-placed object).

**Output Range:** boolean — `valid = false` triggers the snap-back behavior
from Core Rule 4.
**Example:** Jar `(cx,cy,rx,ry)=(0,0,100,60)`, rock `fp=8` dropped at
`(60,20)` → `in_bounds = (60/92)² + (20/52)² ≈ 0.573` ✓ valid (`≤ 1`).
**Corrected 2026-08-03 `/design-review`**: this worked example previously
stated `≈ 0.44`, a straightforward arithmetic error caught during review —
the correct value is `≈ 0.573`; both are `≤ 1` so the "valid" conclusion
itself was never wrong, only the intermediate number. A second object
`fp=6` dropped at `(63,21)` → `dist≈3.16`, required clearance =
`(8+6)×0.8=11.2` → `dist < clearance` → overlap → snap-back.

`LENIENCY` will be listed as a Tuning Knob in that section, not duplicated
here.

**Known approximation, documented not fixed (added 2026-08-04
`/design-review`, round 12 — independently found by both `systems-designer`
and `godot-specialist`, confirming it's a real gap rather than a fluke):**
the shrunk-ellipse `in_bounds` check (`(rx-fp, ry-fp)`) is exact only
on-axis. For this jar's eccentric ellipse (`rx=100, ry=60`), it under-shrinks
off-axis, so a footprint circle centered exactly on the reported valid
boundary can bulge slightly past the *true* ellipse boundary at diagonal
angles. At the legal maximum `fp = FOOTPRINT_MAX = 20`, the worst-case
overshoot is **≈0.85 jar-space units** past the true boundary — small
relative to the jar's own scale (`rx=100, ry=60`) and smaller than the
visual slack `LENIENCY` already tolerates for overlap. **Corrected
2026-08-04 `/design-review`, round 13** (`systems-designer` finding): a
prior round additionally cited the angle at which this worst case occurs
("~62–63° from the x-axis") without showing a derivation; an independent
re-derivation confirmed the ≈0.85 magnitude but placed the worst case at a
different angle, so the specific angle figure is struck as unverified. The
magnitude is what the "accepted, not fixed" argument below actually rests
on — the angle was never load-bearing.
**Accepted, not fixed**: per the Anti-Pillar against finicky/punishing
mechanics, tightening this formula to be exact off-axis would only make
valid-feeling placements near the boundary get rejected more often, trading
a sub-unit invisible overshoot for a more punishing edge. The error shrinks
roughly quadratically with `fp`, so every worked example and AC in this
document (`fp=6–8`) is unaffected in practice.

---

**Footprint hit-test** (used by pickup — Core Rule 2 — and tap-wobble —
Core Rule 7 — added 2026-08-04 `/design-review`, round 12, `qa-lead`
finding: this predicate was referenced by two Core Rules and five
Acceptance Criteria but never actually defined):

`hit = dist(P, obj.pos) ≤ fp`

Inclusive boundary, matching the permissive-boundary convention already
used by `in_bounds`/`no_overlap` above — a press or tap landing exactly on
an object's footprint edge counts as hitting it.

| Variable | Type | Range | Description |
|---|---|---|---|
| P | Vector2 | jar-space | `drag_start`/`tap` position being tested |
| obj.pos | Vector2 | jar-space | the object's current committed (or held) position |

**Output Range:** boolean.
**Example:** rock at `(60,20)`, `fp=8` — a press at `(66,20)` (`dist=6`) hits
(`6 ≤ 8`); a press at `(68,20)` (`dist=8`, exactly on the boundary) still
hits (`8 ≤ 8`, inclusive); a press at `(69,20)` (`dist=9`) misses.

---

**Drag-follow position** (Core Rule 3's "grab offset preserved," added
2026-08-04 `/design-review`, round 12, `qa-lead` finding: this was asserted
qualitatively with no formula, unlike every other piece of runtime math in
this document):

`grab_offset = grab_point - obj.origin` (computed once, at `drag_start`)
`visual_pos' = pointer_pos - grab_offset` (recomputed on every `drag_move`)

| Variable | Type | Range | Description |
|---|---|---|---|
| grab_point | Vector2 | jar-space | pointer position at the moment `drag_start` picks up the object |
| obj.origin | Vector2 | jar-space | the object's position at the moment it was picked up |
| pointer_pos | Vector2 | jar-space | live pointer position during `drag_move` |
| visual_pos | Vector2 | jar-space | the object's in-progress visual position while HELD (not yet committed) |

**Output Range:** jar-space position, unclamped during the drag (clamping
only matters for the pending *commit*, validated by `in_bounds`/`no_overlap`
at `drag_end`, not for the live visual follow).
**Example:** rock's origin at `(60,20)`, grabbed at `(63,-2)` →
`grab_offset = (3,-22)`. Pointer moves to `(50,50)` → `visual_pos =
(50,50) - (3,-22) = (47,72)` — the object trails the pointer by the same
offset at which it was grabbed, never snapping its origin to the cursor.

*(`systems-designer` consulted for these placement validity formulas.)*

## Edge Cases

- **If the pointer's clamped position (per Input Abstraction's viewport-edge
  clamping) is outside the jar's ellipse while HELD, on mouse**: the object
  visually follows the clamped position during the drag, but the validity
  check still runs at `drag_end` — since the position is out-of-bounds, it
  fails and snaps back normally. No special-casing needed; the existing
  commit rule already covers it.

  **Corrected 2026-08-04 `/design-review`, round 12 (`godot-specialist`
  finding) — this conclusion is stated as settled fact above, but it is
  contingent on touch behaving the same as mouse at the canvas edge, which
  `input-abstraction.md`'s own Edge Cases explicitly flags as
  unverified.** That document hypothesizes a finger leaving the canvas DOM
  element may cause the touch drag to *stall* at the last in-bounds
  position instead of clamping-and-continuing like mouse. If stall is what
  actually happens on Web export: `drag_end` fires at that stale, still
  in-bounds position, which then **passes** validation and **commits** —
  even though the player's physical intent was to push the object further,
  possibly out of the jar. This would be a genuine mouse/touch parity
  divergence on this system's own commit behavior. This is not a new gap to
  fix here — it's gated by the same empirical Web-export verification
  `input-abstraction.md`'s Open Questions already require before this
  system's implementation begins (see this document's own header). Stated
  as a contingency rather than settled fact so a future reader isn't misled
  into thinking touch is confirmed to behave identically to mouse here.
- **If the drop position lands exactly on the jar boundary** (`in_bounds`
  formula evaluates to exactly `1`): treated as **valid** — the check is
  `≤ 1`, inclusive — erring toward permissive rather than rejecting a
  boundary-line placement, consistent with the Anti-Pillar against punishing
  mechanics.
- **If two footprints' distance exactly equals the leniency-scaled
  clearance** (`dist == (fp_a+fp_b)×LENIENCY`): treated as **no overlap**
  (valid) — the check is `≥`, inclusive, same permissive-boundary reasoning.
- **If the window loses focus mid-drag** (Input Abstraction's pointer
  interruption fires `drag_end` at the last known position with
  `canceled = true`): per Core Rule 4, the object always reverts to its last
  committed position — the validity check is never consulted, since
  `canceled` is checked first. This holds even if the last-known position
  happens to be in-bounds and non-overlapping; a canceled drag never commits
  regardless of where it ended.
- **If no other objects are currently placed** (true for the entire MVP
  scope, since only one object — the rock — is repositionable): the overlap
  check trivially always passes; only the in-bounds check applies.
- **If a `drag_start` somehow arrives while another object is already HELD**
  (should be structurally impossible given Input Abstraction's
  single-pointer guarantee, but stated as a defensive invariant): the new
  `drag_start` is ignored until the currently-HELD object resolves to IDLE.
- **If a placed object is dropped at a position that visually overlaps a
  live creature** (added 2026-08-04 `/design-review`, round 12,
  `game-designer` finding, `creative-director` ruling): **accepted, out of
  scope for MVP — creature positions are never checked by this system's
  overlap validation.** `no_overlap` only checks the pending position
  against other placed *objects*; it never reads creature state. This is
  intentional, not an oversight: `creature-behavior.md`'s own wander
  behavior already treats object footprints as obstacles it steers around
  when *selecting* a new destination, so a momentary rock-on-creature
  overlap self-resolves the next time that creature picks a new
  destination — it does not persist as a stuck/broken-looking state. Adding
  the reverse check (rejecting an object drop because a creature currently
  stands there) would require a new upstream read of Creature Behavior's
  live position, which is out of scope for this system's MVP formulas.

## Dependencies

Object Placement depends on:
- **Input Abstraction** (hard) — `drag_start`/`drag_move`/`drag_end`/`tap` +
  `position`/`delta`/`canceled`
- **Content Data** (hard) — `ObjectTypeDef.repositionable`, `footprint_size`

Downstream dependents:
- **Diorama Rendering** (hard) — needs each object's current position every
  frame to render it
- **Creature Behavior** (soft) — reads object footprints as wander-
  destination obstacles; degrades gracefully with zero objects placed. Not
  "undesigned" — Creature Behavior is authored and reads this live today
  (see Player Fantasy correction above and Interactions with Other Systems).
  **Corrected 2026-08-04 `/design-review`, re-review pass** (`game-designer`
  finding): this row still carried the stale "just less spatially informed
  if undesigned" phrasing round 12's own trailing note claimed was already
  removed — that removal only reached the Interactions table, not here.
  Propagated here now.
- **Tending Input** (hard, added 2026-08-03 `/design-review`) — queries
  current object footprints to exclude them from the watering zone; a
  genuine bidirectionality gap until now, since `tending-input.md` already
  listed Object Placement as a hard dependency
- **Persistence/Save** (hard, added 2026-08-03) — bidirectional read/write
  of the placed object's position; same gap, `persistence-save.md` already
  listed Object Placement on its side

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `LENIENCY` | 0.7–0.9 (default 0.8) | Objects can visually overlap significantly before a placement is rejected — looks glitchy/broken | Placement becomes finicky — small drags near another object get rejected, reads as punishing (violates Anti-Pillar) |

The jar's ellipse bounds (`cx, cy, rx, ry`) are fixed scene geometry set by
the jar's art/scene layout, not a designer-facing gameplay knob — they're
not listed here since they don't get iterated on during balance passes the
way `LENIENCY` does.

## Visual/Audio Requirements

N/A for this GDD's scope — the actual visual treatment of holding/dragging/
snapping-back an object (highlight, lift, ease curve) is owned by Diorama
Rendering, which consumes this system's HELD/committed position state. See
Open Questions for the one unresolved visual detail this system surfaces.

## UI Requirements

N/A — Object Placement has no UI of its own; it's a direct world-space
interaction, not a screen/menu.

## Acceptance Criteria

1. **(rewritten 2026-08-04 `/design-review`, round 12 — `qa-lead` finding:
   "grab offset preserved" had no worked example or backing formula, unlike
   every other numeric AC in this doc; see Formulas' new Drag-follow
   position formula)** **GIVEN** a `drag_start` picks up the rock at origin
   `(60,20)`, grabbed at pointer position `(63,-2)` (`grab_offset =
   (3,-22)`), **WHEN** a subsequent `drag_move` reports pointer position
   `(50,50)`, **THEN** the rock's visual position becomes `(47,72)`
   (`pointer_pos - grab_offset`) — the object trails the pointer by the
   offset at which it was grabbed, never snapping its origin to the cursor.
1a. **(new, 2026-08-04 `/design-review`, round 12, `qa-lead` finding — the
    footprint hit-test predicate underlying Core Rules 2/7 was never
    formally defined; see Formulas' new Footprint hit-test formula)**
    **GIVEN** the rock at `(60,20)` with `fp=8`, **WHEN** a `drag_start` or
    `tap` fires at `(68,20)` (`dist=8`, exactly on the footprint boundary),
    **THEN** it counts as a hit on the rock — the hit-test boundary is
    inclusive, matching the permissive-boundary convention `in_bounds`/
    `no_overlap` already use.
1b. **(new, 2026-08-04 `/design-review`, re-review pass — `qa-lead` finding:
    Core Rule 2's IDLE→HELD pickup transition itself had no direct positive
    AC; AC1/AC1a both assume pickup already succeeded)** **GIVEN** the rock
    (repositionable) at rest at `(60,20)` with `fp=8`, **WHEN** a
    `drag_start` fires at `(63,17)` (`dist≈4.24 ≤ 8`, a footprint hit),
    **THEN** the rock becomes the HELD object, `grab_offset` is recorded per
    the Drag-follow position formula, and the state transitions IDLE→HELD.
2. **GIVEN** a `drag_start` over a non-repositionable object's footprint
   (`ObjectTypeDef.repositionable == false`), **WHEN** the event fires,
   **THEN** no object becomes HELD and the event is not consumed by this
   system.
3. **GIVEN** a `drag_start` that does not fall within any repositionable
   object's footprint, **WHEN** the event fires, **THEN** no object becomes
   HELD and the event is not consumed by this system.
4. **GIVEN** a HELD object, **WHEN** `drag_end` fires at a position that is
   in-bounds and does not overlap any other object, **THEN** the new
   position commits as the object's position.
5. **GIVEN** a HELD object, **WHEN** `drag_end` fires outside the jar
   ellipse (e.g., jar `(cx,cy,rx,ry)=(0,0,100,60)`, drop at `(150,20)` →
   `in_bounds > 1`), **THEN** the object animates back to its last
   committed position.
6. **GIVEN** a HELD object, **WHEN** `drag_end` fires overlapping another
   object's footprint (e.g., rock `fp=8` at `(60,20)`, second object `fp=6`
   at `(63,21)` — `dist≈3.16 < clearance=11.2`), **THEN** the object
   animates back to its last committed position.
6a. **(new, 2026-08-04 `/design-review`, re-review pass — `qa-lead` finding:
    the `no_overlap` formula's own parenthetical claims it "generalizes to
    any number of objects," and the Commit rule checks "every other
    currently-placed object" — plural — yet no existing AC exercises more
    than 2 placed objects, so nothing would catch an implementation that
    only checks the nearest or most-recently-placed object instead of
    iterating all of them)** **GIVEN** three placed objects — object A
    `fp=8` at `(60,20)`, object B `fp=6` at `(-50,0)`, object C `fp=5` at
    `(0,-40)` — and a fourth HELD object `fp=8`, **WHEN** `drag_end` fires
    at `(63,21)` (in-bounds; overlaps only A's clearance, `dist≈3.16 <
    (8+8)×0.8=12.8`; B and C are far outside their own clearance radii —
    `dist` to B `≈114.9`, `dist` to C `≈87.7`, both ≫ their clearances),
    **THEN** the placement is rejected (snap-back) — confirming validation
    checks every other placed object individually, not only whichever one
    happens to be nearest, first, or last in whatever order an
    implementation iterates them.
7. **(added a concrete worked example 2026-08-04 `/design-review`, round
   12, `qa-lead` finding — previously stated with no coordinates, unlike
   its paired case AC8)** **GIVEN** a HELD object, **WHEN** `drag_end` fires
   exactly on the jar boundary (e.g. jar `(cx,cy,rx,ry)=(0,0,100,60)`,
   `fp=8` → boundary point `(92,0)` gives `in_bounds = (92/92)² +
   (0/52)² = 1` exactly), **THEN** the placement is treated as valid.
8. **GIVEN** two footprints at a distance exactly equal to
   `(fp_a+fp_b)×LENIENCY` (e.g., `fp_a=8, fp_b=6, LENIENCY=0.8` → clearance
   `11.2`, objects placed exactly `11.2` apart), **WHEN** `drag_end` fires,
   **THEN** the placement is treated as valid.
9. **(reworded 2026-08-04 `/design-review`, round 12, `qa-lead` finding —
   previously asserted an internal mechanism, "the overlap check trivially
   passes," which a test can't directly observe; reworded to the observable
   outcome)** **GIVEN** the rock is the only currently-placed object (MVP
   scope), **WHEN** `drag_end` fires at any in-bounds, non-canceled
   position, **THEN** the placement commits — no overlap rejection is
   possible with zero other objects present.
10. **GIVEN** an object is already HELD, **WHEN** a new `drag_start` arrives
    before the current drag resolves, **THEN** the new `drag_start` is
    ignored and the currently-HELD object's drag continues unaffected.
11. **GIVEN** a HELD object, **WHEN** `drag_end` fires with `canceled = true`
    (Input Abstraction's pointer-interruption path) at a position that would
    otherwise be valid (in-bounds, no overlap), **THEN** the object still
    reverts to its last committed position — `canceled = true` always
    reverts, checked before the validity check, regardless of where the
    interruption left the pointer.
12. **GIVEN** a HELD object, **WHEN** `drag_end` fires with `canceled = false`
    at an in-bounds, non-overlapping position, **THEN** the position
    commits normally (the pre-existing AC4 case, restated to make explicit
    this only applies when `canceled = false`).
13. **GIVEN** a `tap` (not a drag) landing within a repositionable object's
    footprint, **WHEN** the tap fires, **THEN** a wobble acknowledgment plays
    on that object, the object's position does not change, and the object
    does not become HELD.
14. **GIVEN** a `tap` that does not fall within any repositionable object's
    footprint, **WHEN** the tap fires, **THEN** no wobble fires and the event
    is not consumed by this system.

*(`qa-lead` consulted — flagged 3 missing criteria in the original draft
(repositionable-gate, single-held invariant, MVP no-other-objects case) and
a testability gap in the boundary criteria, all addressed above.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — lean mode. Verdict:
NEEDS REVISION → 2 blockers resolved: the Formulas worked example's
`in_bounds ≈ 0.44` was a genuine arithmetic error, corrected to the actual
`≈ 0.573` (the "valid" conclusion itself was unaffected — both values are
`≤ 1`); and this Dependencies section was missing two real downstream
dependents (Tending Input, Persistence/Save) that already listed Object
Placement as a hard dependency on their own side — added for bidirectional
consistency.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — full specialist round
across content-data.md, ecosystem-simulation.md, persistence-save.md,
object-placement.md as a set: `game-designer`, `systems-designer`,
`qa-lead`, `godot-specialist`, `creative-director`. Verdict: NEEDS REVISION
→ 1 recommended item resolved (no blocking findings against this document).
**Player Fantasy corrected**: `game-designer` found the "purely aesthetic...
just changes what the jar looks like" framing denied a dependency that's
actually live — `creature-behavior.md` already treats footprints as hard
wander obstacles, so repositioning the rock does shape creature movement.
Reframed as Pillar 3 working as intended (shaping conditions, not
commanding creatures) rather than a contradiction; the Interactions table's
Creature Behavior row updated to match, removing its stale "if undesigned"
phrasing.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 11, full
specialist round across content-data.md, ecosystem-simulation.md,
persistence-save.md, object-placement.md as a set: `game-designer`,
`systems-designer`, `qa-lead`, `godot-specialist`, `creative-director`.
Verdict: NEEDS REVISION → 1 blocker resolved below, text-only, no design
rework. **`in_bounds` domain precondition stated**: `systems-designer`
found this formula divides by zero (or silently shrinks the ellipse for
`fp > min(rx,ry)`) outside the domain `fp < min(rx,ry)`, and that domain
boundary was previously an unstated assumption held together only by a
cross-file numeric coincidence between `content-data.md`'s `FOOTPRINT_MAX`
and this document's own jar-floor `ry` — a coincidence `content-data.md`
had already flagged as unenforced in its own Open Questions. Verified not
reachable by any valid per-field input today (Content Data's
`FOOTPRINT_MAX=20.0` is well under `ry=60` and load-time enforced), so
rated a must-fix-before-implementation documentation gap rather than a live
bug: this formula is reused verbatim by two other systems
(`persistence-save.md`, `creature-behavior.md`), and the only guard against
the domain being crossed by a future geometry or constant change was a code
comment, not a stated invariant. One paragraph added to Formulas stating
the domain and promoting `FOOTPRINT_MAX < min(rx,ry)` to an explicit
invariant — closes `content-data.md`'s existing "FOOTPRINT_MAX cross-GDD
coupling" Open Question rather than reopening that document.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 12, full
specialist round: `game-designer`, `systems-designer`, `qa-lead`,
`godot-specialist`, `creative-director`. Verdict: NEEDS REVISION → all 3
blockers resolved below, text-only, no design rework, no new scope.
**Footprint hit-test formula added** (`qa-lead` finding): Core Rules 2/7
and five ACs (1/2/3/13/14) depended on an undefined "is point P within this
object's footprint" predicate — added as `hit = dist(P, obj.pos) ≤ fp`,
inclusive, with new AC1a. **Drag-follow formula added** (`qa-lead`
finding): AC1's "grab offset preserved" had no formula or worked example,
unlike every other numeric AC — added `visual_pos = pointer_pos -
grab_offset` and rewrote AC1 with concrete numbers. **Creature-collision
silence resolved** (`game-designer` finding, `creative-director` ruling):
this system's overlap check never reads creature positions, so a dropped
object could render on top of a live creature with no stated behavior —
ruled "accepted, out of scope for MVP" rather than adding a new upstream
dependency on Creature Behavior, since `creature-behavior.md`'s own wander
logic self-resolves the overlap on the creature's next destination pick.
**Touch-stall contingency stated** (`godot-specialist` finding): Edge
Cases previously asserted "no special-casing needed" for a pointer clamped
outside the jar while HELD, as settled fact — but `input-abstraction.md`
itself flags an unverified hypothesis that touch may *stall* rather than
clamp-and-continue at the canvas edge, which would let `drag_end` commit a
stale in-bounds position the player meant to drop out-of-bounds. Restated
as an explicit contingency cross-referenced to that document's own pending
verification gate, rather than re-blocking this document on it — the gate
already exists upstream. **Off-axis `in_bounds` approximation documented**
(`systems-designer` and `godot-specialist` independently found the same
gap): the shrunk-ellipse check under-shrinks off-axis for this jar's
eccentric geometry, worst case ≈0.85 jar-space units past the true
boundary at `fp=FOOTPRINT_MAX=20`. `creative-director` ruled this accepted
rather than fixed — tightening it would only reject more near-boundary
placements, which cuts against the Anti-Pillar `LENIENCY` already exists to
serve, and the error is negligible at every value this document's own
worked examples and ACs actually use (`fp=6–8`). **One BLOCKING claim
downgraded, not silently dropped**: `qa-lead` rated the missing epsilon-
boundary tests (AC5/AC6's invalid-side cases weren't tight against AC7/
AC8's exact-boundary valid cases) as BLOCKING; `creative-director`
downgraded to RECOMMENDED and deferred, since AC7/AC8 already catch a
`<`-vs-`≤` operator-flip bug on their own — the epsilon-tolerance case is
real but lower severity, tracked for a future pass rather than gating this
one. **Recommended items folded in, cheap/text-only**: wobble's emotional
register locked (Core Rule 7 — "playful, never rejecting," an Anti-Pillar
call, not left to art-director alone) and cross-referenced to
`input-abstraction.md`'s still-open touch-threshold-precision question;
jar-local coordinate-space/parenting assumption stated explicitly
(Interactions); this document's header now propagates
`input-abstraction.md`'s BLOCKED-pending-verification gate; AC7 given
concrete coordinates to match AC8's rigor; AC9 reworded from an internal
mechanism to an observable outcome; the "second repositionable object"
questions raised independently by three specialists (non-repositionable
overlap semantics, footprint-overlap pick-priority) merged into one Open
Question. **Deferred, not addressed this round**: AC coverage for 3+
placed objects, a defensive unit test for the already-unreachable `fp <
min(rx,ry)` domain precondition, a cross-reference noting AC11 inherits
`input-abstraction.md`'s own "canceled is provisional" caveat, a defensive
"tap arrives while HELD" statement (asymmetric with the existing
drag_start-while-HELD case), and the 2D-vs-3D pointer-conversion question
for Diorama Rendering's eventual scene (belongs in that GDD, not here) —
all lower-severity or out of this document's scope, tracked for a future
pass.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 13, full specialist
round: `game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → all 3 blockers resolved
below, text-only, no design rework. **Stale "if undesigned" phrasing
finally removed** (`game-designer` finding): round 12 claimed this was
fixed but only updated the Interactions table's Creature Behavior row, not
the parallel row in Dependencies — both now match. **Pickup transition AC
added** (`qa-lead` finding, new AC1b): Core Rule 2's IDLE→HELD transition
had no direct positive AC; AC1/AC1a both assumed pickup already succeeded.
**Multi-object overlap AC added** (`qa-lead` finding, new AC6a): the
`no_overlap` formula and Commit rule both claim/require checking every
other placed object, but no AC exercised more than 2 objects — added a
3-other-objects case where only the nearest triggers rejection, so an
implementation checking just one arbitrary other object cannot pass by
accident. **All 6 recommended items applied in the same pass** (cheap,
text-only, already specialist-vetted this round — no new review round
spawned to re-confirm them): Player Fantasy's "no correct position" framing
rewritten as an honest concession rather than left as a philosophical
rebuttal against its own footnoted correction (`game-designer`); Core Rule
3's "never snaps" overclaim at `grab_offset=(0,0)` corrected
(`systems-designer`); the pick-priority Open Question sharpened below from
hypothetical to guaranteed-at-default-tuning, `[0.8×sum, sum)`
(`systems-designer`); the unverified 62–63° angle struck from the off-axis
approximation note, keeping the confirmed ≈0.85 magnitude
(`systems-designer`); an explicit "no Area2D/CollisionShape2D" sentence
added to Formulas (`godot-specialist`); an N≥3 packing-feasibility question
folded into the existing second-object Open Question below
(`systems-designer`). **Disagreement
surfaced, not silently resolved**: `game-designer` argued the touch/mouse
threshold asymmetry should block this document for Vertical Slice;
`creative-director` ruled it RECOMMENDED here since `input-abstraction.md`
already gates it upstream with its own Open Question, and re-blocking here
would duplicate that gate. `creative-director`'s closing note: "twelve
[now thirteen] rounds on a single-rock drag mechanic is a Pillar 1
violation applied to our own process" — further rounds on this document
should wait for new design scope (e.g., a second repositionable object).)*

## Open Questions

- **Snap-back animation style — RESOLVED (2026-08-05, `diorama-rendering.md`
  authored)**: eased tween, not instant — `TRANS_CUBIC`/`EASE_OUT`,
  distance-scaled duration 0.18–0.45s. See that GDD's Core Rule 6 and its
  Snap-back/Wobble Timing formula.
- **Held-object visual feedback**: Should a held object lift, scale slightly,
  or highlight while being dragged, to reinforce "you're holding this"?
  Nice-to-have, not required for MVP function. **Still open** —
  `diorama-rendering.md`'s Core Rule 4 only specifies live position-follow
  while HELD, no additional visual treatment; carried forward as that
  GDD's own Open Question #2. Owner: art-director. Target: before
  implementation.
- **Tap-on-footprint wobble animation style — RESOLVED (2026-08-05,
  `diorama-rendering.md` authored)**: a fixed 4° sine-pulse rotation over
  0.30s (`TRANS_SINE`/`EASE_IN_OUT`), position and scale unchanged. See
  that GDD's Core Rule 6 and its Snap-back/Wobble Timing formula.
- **Second repositionable object semantics** (merged 2026-08-04
  `/design-review`, round 12 — three specialists independently raised
  pieces of this, unified into one question since MVP scope makes none of
  it reachable today, only forward-looking): once a second
  `ObjectTypeDef.repositionable == true` entry exists, three questions need
  answers before it ships: (1) if a future *non*-repositionable object
  (e.g. a decorative prop) also carries a `footprint_size`, does the
  overlap check include it, or only other repositionable objects?
  `content-data.md` doesn't currently rule this out. (2) **Sharpened
  2026-08-04 `/design-review`, round 13** (`systems-designer` finding): this
  is not merely a hypothetical "if footprints overlap" case — at default
  `LENIENCY=0.8`, `no_overlap` validly permits any two objects placed at a
  distance in `[0.8×(fp_a+fp_b), fp_a+fp_b)`, and the footprint hit-test
  formula carries no `LENIENCY` term at all, so any pair placed in that
  range is *guaranteed* to have a real zone where a single `drag_start`
  hits both footprints simultaneously. No pick-priority rule exists yet
  (e.g. nearest footprint center to the press position) — this will be
  reachable on the very first `drag_start` into that zone once a second
  object exists, not an edge case to discover later. (3) **Added 2026-08-04
  `/design-review`, round 13** (`systems-designer` finding): whether N≥3
  max-`footprint_size` (`FOOTPRINT_MAX=20`) objects can always find a valid
  non-overlapping in-bounds position in this jar — verified non-infeasible
  for 2 such objects at any `LENIENCY` value (the shrunk-ellipse valid
  region is far larger than the required clearance), but packing feasibility
  at higher object counts isn't yet checked. All three are unreachable at
  MVP's single-object (the rock) cap — see AC9 — so none blocks this
  document. Owner: systems-designer. Target: before a second
  `ObjectTypeDef.repositionable` entry is authored in Content Data.
