# Input Abstraction

> **Status**: Approved (round 2, 2026-08-04). Still separately BLOCKED pending empirical verification of Core Rules 1/8's Web-export behavior claims before Object Placement/Tending Input implementation begins (see Open Questions) — this is an implementation-readiness gate independent of this GDD's own review/approval status; Core Rule 7a is self-contained and not part of this gate (corrected round 2 — see trailing review note).
> **Author**: user + systems-designer
> **Last Updated**: 2026-08-04
> **Implements Pillar**: N/A — satisfies the platform requirement in `technical-preferences.md` (mouse and touch must work equally for every tending interaction, no hover-only interactions)
> **Creative Director Review (CD-GDD-ALIGN)**: APPROVED — round 2 full specialist review, 3 nice-to-have/recommended cleanup items applied in the same pass (see trailing review note)

## Overview

Input Abstraction is the unified interaction layer that converts raw mouse and
touch events — clicks, drags, taps — into a single set of device-agnostic
gestures (`tap`, `drag_start`, `drag_move`, `drag_end`) that every gameplay
system consumes identically, regardless of whether the player is using a
mouse or a touchscreen. It exists because the platform requirement is strict:
every tending interaction must work equally well via mouse click-and-drag and
touch tap-and-drag, with no hover-only interaction as the sole means of
conveying information. Without this layer, Tending Input and Object Placement
would each need their own mouse/touch branching logic, risking the two input
paths drifting out of parity over time.

## Player Fantasy

Input Abstraction has no direct player fantasy — success here is invisible by
design. What the player *feels* is that tending the terrarium "just works,"
whether they're on a laptop trackpad or tapping a phone screen — the
interaction never calls attention to itself or breaks the calm, low-friction
tone the game's Anti-Pillars demand (no punishing mechanics, no friction). If
this system fails, the player-facing symptom is a device-specific bug:
dragging the rock works with a mouse but not on touch, or vice versa — a
direct violation of the platform requirement, not just a bug.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Review manually before
production.)*

## Detailed Design

### Core Rules

1. Raw input events (`InputEventMouseButton`, `InputEventMouseMotion`,
   `InputEventScreenTouch`, `InputEventScreenDrag`) are captured at a single
   entry point and translated into four device-agnostic gesture events: `tap`,
   `drag_start`, `drag_move`, `drag_end`. Godot's `emulate_mouse_from_touch`
   project setting must be disabled — on Web export a real touch may still
   synthesize an `InputEventMouseMotion` alongside its `InputEventScreenTouch`/
   `InputEventScreenDrag` even with the setting off. **This is an unverified
   hypothesis, not a confirmed engine behavior** (no prior citation for it
   survived fact-check against `docs/engine-reference/godot/`) — treat it as
   the reason Core Rule 7 exists defensively, not as proven fact. See Open
   Questions: this must be empirically confirmed on a real Web export build
   before Object Placement/Tending Input are considered safely built on this
   contract.
2. A `tap` fires when a press-and-release happens at approximately the same
   position within a short time/distance threshold — regardless of whether
   the press was a mouse click or a touch.
3. A `drag_start` → `drag_move`(×N) → `drag_end` sequence fires when a press
   moves beyond a small distance threshold before release — again regardless
   of input device.
4. Every gesture event carries: `position` (Vector2, **true jar-local
   coordinates** — this layer must explicitly convert into jar-local space
   before emitting the event, not just read raw pointer position and label it
   jar-local). Concretely: read the raw pointer position from
   `get_viewport().get_mouse_position()`/the equivalent touch position (this
   is post-stretch logical space, not raw window pixels — standard `Viewport`
   behavior under stretch modes, unchanged across the pinned 4.4–4.7 version
   range; not itself a version-specific change, so no citation into
   `docs/engine-reference/godot/` is expected or claimed here), then convert
   that viewport-space position into the jar's local space via the jar node's
   `to_local()` (or equivalent scene-space transform) before it ever reaches a
   gesture event. This keeps the conversion in one place — Input Abstraction —
   rather than duplicated (and potentially inconsistently applied) across
   Object Placement's and Tending Input's own ellipse/footprint math, both of
   which assume a genuinely jar-local `position` already. If the jar node ever
   gains a camera/scene transform, only this conversion step needs updating.
   **The `drag_active` threshold check (Formulas) is evaluated on this
   pre-conversion viewport-space reading, never on the post-conversion
   jar-local `position` below** — see Formulas for why that distinction is
   load-bearing, not stylistic.
   `device_id` (using the 4.7 `DEVICE_ID_MOUSE` constant for mouse — confirmed
   current for 4.7.1 per `docs/engine-reference/godot/current-best-practices.md`;
   do not compare against a literal `0` the way older Godot tutorials do —
   constructed from the raw event's `device` property for mouse; for touch,
   from the raw event's `index` property instead, since
   `InputEventScreenTouch`/`InputEventScreenDrag.device` does not distinguish
   concurrent fingers), and for drag events, `delta`
   (movement since the last `drag_move`). `drag_end` additionally carries
   `canceled` (bool, default `false`) — `true` when the drag ended via
   Core Rule 8's interruption path rather than a normal release.
5. Multi-touch is explicitly out of scope for MVP — only the first active
   touch point is tracked; additional simultaneous touch points are ignored
   for state purposes and produce no `tap`/`drag_*` events (Core Rule 7
   extends this to touch-emulated mouse events from the same physical touch,
   not just genuine second touch points). An ignored touch point never
   inherits state when the tracked pointer later returns to IDLE — even if
   still held down, it must lift and press again to become trackable. This
   rules out an entire class of stale-position/spurious-teleport bugs a
   resume-in-place rule would otherwise risk.

   **Cut 2026-08-04 `/design-review` (`game-designer` finding,
   `creative-director` ruling):** an earlier version of this rule required an
   ignored second touch point (e.g. a resting palm or a second finger
   incidental to normal two-handed device holding) to fire a lightweight
   `pointer_ignored` signal so a consuming/presentation system could give a
   minimal passive acknowledgment (e.g. a faint visual pulse) that the
   contact was registered but not actioned. `game-designer` found this
   undermines this GDD's own Player Fantasy: the system cannot distinguish
   an incidental resting palm from an intended second action, so the pulse
   would most often fire for contact the player never consciously made —
   converting silent-correct behavior into an unexplained spontaneous visual
   event, the opposite of "just works... never calls attention to itself."
   The original justification (zero feedback reads as "the game is broken")
   only holds when the player *intended* a second action and got no
   response, which an incidental palm rest is not. `creative-director` ruled
   the fix: an ignored second touch point produces **no signal and no
   feedback at all** — trust silence, consistent with this section's own
   stated philosophy. If playtesting later surfaces genuine player confusion
   from an intended-but-ignored second touch, reintroduce a signal with that
   evidence rather than pre-emptively.
6. No hover-only signal exists in this abstraction. Per the platform
   requirement, hover state is never the sole means of conveying information —
   this system may forward raw mouse-motion-without-press for optional visual
   polish (e.g., a cursor highlight), but that channel is never
   gameplay-critical, since touch has no equivalent.
7. **Single active pointer.** The first device_id to enter PRESSED owns the
   state machine until it returns to IDLE; input from any other `device_id`
   is ignored for the duration — including a touch-emulated mouse event
   sharing an origin with an already-active touch pointer (Core Rule 1).
   This is what actually prevents one physical touch from double-driving the
   state machine, not just the emulation project setting.
7a. **(new, 2026-08-04 `/design-review`, `systems-designer` finding,
   inserted between Core Rules 7 and 8 to avoid renumbering) Same-`device_id`
   re-press while already active.** Core Rule 7 only specifies what happens
   when a *different* `device_id` presses while one is already active
   (ignored). It was previously silent on the same `device_id` producing a
   new press-begin event while its own pointer is already PRESSED or
   DRAGGING — a real, reachable case: if a touch's release event is ever
   lost (an OS-level touch-loss not caught by Core Rule 8's focus-based
   detection — see that rule's own provisional-verification note) and the
   platform later reuses that same touch `index` for a new physical contact,
   this exact case occurs. **Resolution**: treat it as an implicit
   release-then-press. If the existing pointer was DRAGGING, fire
   `drag_end(canceled = true)` at its last known position first (the same
   contract Core Rule 8's interruption path produces, since from the
   consuming system's perspective a lost release is indistinguishable from
   an interruption); if it was PRESSED, no event fires. Either way, the
   pointer then immediately transitions to PRESSED for the new press,
   exactly as if it had legitimately returned to IDLE first. This never
   produces two simultaneously-active states for one `device_id`.
   **Explicit for clarity (added round 2 `/design-review`,
   `systems-designer` nice-to-have):** "as if it had legitimately returned
   to IDLE first" includes `press_pos` — the new press's `press_pos` (Formulas)
   is the new press's own position, not carried over from the old, ended
   press. This already follows from Formulas' own definition of `press_pos`
   as "position at PRESSED state entry," but is stated here directly so no
   implementation accidentally lets stale `press_pos` leak into the new
   press's `drag_active` threshold calculation.
8. **Pointer interruption** (browser tab/app loses visibility, or an
   OS-level touch cancellation — incoming call, pull-to-refresh, edge-swipe
   navigation) forces the active pointer back to IDLE regardless of its
   current state, so it is never left stuck. Detection differs by cause but
   the resulting transition is identical (see States and Transitions, Edge
   Cases): if PRESSED, no event fires; if DRAGGING, `drag_end` fires at the
   last known position (clamped position if the pointer was currently outside
   viewport bounds — Core Rule/Edge Case on out-of-bounds dragging) with
   `canceled = true`, so the consuming system reverts rather than commits a
   position the player never intended to release.

   **Status: provisional, pending empirical verification.** This rule's
   detection mechanism (Godot's `Window.focus_exited`/`focus_entered`
   signals firing reliably on Web export, for both tab-visibility loss and
   OS-level touch-cancellation) is currently an unverified assumption, not a
   confirmed engine behavior — see Open Questions. Object Placement and
   Tending Input's dependency on the `canceled` contract this rule produces
   should be treated as at-risk until a throwaway prototype confirms this on
   real target mobile browsers.

### States and Transitions

Per active pointer (mouse or first touch point):

| State | Trigger | Next State | Event Fired |
|---|---|---|---|
| IDLE | press begins (mouse down / touch begin) | PRESSED | none |
| PRESSED | release before drag threshold exceeded | IDLE | `tap` |
| PRESSED | movement exceeds drag distance threshold | DRAGGING | `drag_start` |
| PRESSED | another `device_id` begins a press (Core Rule 7/5) | PRESSED (self) | none |
| DRAGGING | movement continues | DRAGGING | `drag_move` |
| DRAGGING | release | IDLE | `drag_end` (`canceled=false`) |
| DRAGGING | another `device_id` begins a press (Core Rule 7/5) | DRAGGING (self) | none |
| PRESSED | pointer interrupted (Core Rule 8) | IDLE | none |
| DRAGGING | pointer interrupted (Core Rule 8) | IDLE | `drag_end` (`canceled=true`) |
| PRESSED | *same* `device_id` begins a new press (Core Rule 7a) | PRESSED (new press) | none |
| DRAGGING | *same* `device_id` begins a new press (Core Rule 7a) | PRESSED (new press) | `drag_end` (`canceled=true`) |

**Implementation note (corrected):** an earlier version of this rule
described the interruption as "discarding an already-queued release event,"
which isn't actually expressible — `focus_exited` is a signal with no
guaranteed ordering relative to input-event dispatch within a frame, so
there is no reliable point at which a release event can be intercepted and
discarded before it reaches a consumer. The rule is instead a **state
guard**: the pointer's state machine transitions to IDLE the instant
interruption is detected, and any input event for that `device_id` processed
afterward — in the same frame or a later one — is evaluated against the
pointer's *current* state, which is already IDLE. A release event that
"arrives after" interruption therefore has nothing to resolve into (IDLE has
no release transition) and produces no event, achieving the same practical
outcome — never a queued release followed by an interruption transition, and
never two `drag_end` events — without requiring retroactive event discarding.
Concretely: if the pointer was PRESSED, the interruption transition fires
(no event) and any trailing release for that `device_id` is a no-op; if
DRAGGING, the interruption's own `drag_end` (`canceled = true`) fires at the
last known position, and any trailing release is likewise a no-op against an
already-IDLE pointer.

### Interactions with Other Systems

| System | Consumes | Data flow |
|---|---|---|
| Object Placement | `drag_start`, `drag_move`, `drag_end`, `tap` | `position`/`delta`/`canceled` → drives dragging a repositionable object; `tap` on a footprint → wobble acknowledgment (no position change) |
| Tending Input | `tap` (and possibly drag, per that system's own design) | `position` → drives the watering/misting action target |

Input Abstraction has no upstream dependencies. Both downstream systems now
exist (see Dependencies section below for the correction to this table's
previously-stale "undesigned so far" framing).

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Review manually before production.)*

## Formulas

The `drag_active` classification is defined as:

`drag_active = (distance(press_pos, current_pos) > threshold[device_id])`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| threshold_mouse | — | float | 6–10 px | Distance threshold for mouse pointer (recommended: 8px) |
| threshold_touch | — | float | 14–20 px | Distance threshold for touch pointer (recommended: 16px) |
| press_pos | — | Vector2 | screen space | Pointer position at PRESSED state entry |
| current_pos | — | Vector2 | screen space | Live pointer position |
| distance | — | float | 0–unbounded | Euclidean distance between press_pos and current_pos |
| device_id | — | int | `DEVICE_ID_MOUSE` or a touch-point id | Selects which threshold `threshold[device_id]` resolves to |

`press_pos`/`current_pos` are both in the same post-stretch logical space as
`position` (Core Rule 4) — if the live pointer is currently clamped to the
viewport edge (Edge Cases), `current_pos` is the clamped value, not the raw
off-screen one, so `distance` never spikes on re-entry.

If `device_id` is neither `DEVICE_ID_MOUSE` nor an active touch-point id
(e.g. a joypad event slipping past Core Rule 1's event-type filter), the
event is not processed by this state machine at all — `threshold[device_id]`
is never evaluated for it. Defensive clarification, not an expected runtime
case at MVP scope (no gamepad support per `technical-preferences.md`).

**Latching:** `drag_active` is evaluated continuously only while in PRESSED —
the instant it evaluates `true`, the pointer transitions to DRAGGING and the
formula is no longer re-evaluated against it for the remainder of that
press. This is a state latch, not a per-frame predicate: if the pointer
later moves back near `press_pos` while DRAGGING, it does **not** revert to
tap/PRESSED. The States and Transitions table's DRAGGING row already implies
this (there is no "movement drops below threshold" transition out of
DRAGGING), but it is stated explicitly here to remove any ambiguity for a
literal per-frame implementation of the formula.

**Output Range:** boolean — `true` transitions PRESSED→DRAGGING (fires
`drag_start`); staying `false` until release fires `tap` instead.
**Example:** Touch press at (100,100) drifts to (112,100) — distance=12px <
16px threshold → still classified as `tap` (absorbs finger jitter). Continues
to (118,100) — distance=18px > 16px → `drag_start` fires.

Two device-keyed thresholds rather than one shared value, because mouse input
is precise (~1px jitter) while touch has real finger-contact imprecision
(8-10mm pad) — a shared value would force either false-positive drags on
mouse or missed drags on touch. Distance alone is sufficient; no time
threshold is needed since this is a slow-paced game with no long-press/
double-tap gestures to disambiguate.

*(`systems-designer` consulted for these threshold values.)*

## Edge Cases

- **If the pointer moves outside the viewport/jar bounds mid-drag**:
  `drag_move` continues to fire with the position clamped to the viewport
  edge — the drag is not canceled. Consuming systems (e.g., Object Placement)
  decide whether a clamped position is a valid drop location. **Caveat for
  touch specifically:** on Web export, a finger that leaves the canvas DOM
  element may simply stop delivering `InputEventScreenDrag` altogether
  (unlike mouse, which the OS/browser typically keeps capturing past the
  canvas edge) — in which case the drag may stall at the last in-bounds
  position rather than continuing to clamp-and-update at the edge. This is
  unverified; confirm actual Web-export touch behavior empirically (same
  verification pass as Core Rule 8/Open Questions) before assuming clamped
  continuation holds for touch the same way it does for mouse.
- **If a touch is lifted while positioned outside the jar bounds**: `drag_end`
  fires at the last known position — this is a normal release, not an error;
  the consuming system decides whether that location is valid.
- **If a second touch point appears while the first pointer is already
  PRESSED or DRAGGING**: the second touch point produces no `tap`/`drag_*`
  event and no feedback of any kind (corrected round-2 `/design-review` —
  see Core Rule 5), and does not affect the first pointer's state, per Core
  Rule 5/7 (multi-touch out of scope). It does **not** become trackable when
  the first pointer returns to IDLE, even if still held down — it must lift
  and press again (Core Rule 5).
- **If a genuine touch and its engine-synthesized mouse-emulation event
  arrive for the same physical contact** (Core Rule 1 — a live Web-export
  behavior, not a hypothetical): the mouse event is ignored per Core Rule 7,
  since the touch pointer already owns the state machine. This is the same
  "second device_id while one is active" rule as the bullet above, applied
  to a same-contact synthetic event rather than a second finger.
- **If a pointer is interrupted while PRESSED or DRAGGING** (Core Rule 8) —
  browser tab/app loses visibility (alt-tab, tab switch, app switch), or an
  OS-level touch cancellation (incoming call, pull-to-refresh, edge-swipe
  navigation): the pointer returns to IDLE immediately; if it was DRAGGING,
  `drag_end` fires at the last known position (clamped, if the pointer was
  currently out of viewport bounds) with `canceled = true`. A pointer must
  never be left stuck in PRESSED or DRAGGING with no way to release.
  **Detection note (corrected):** an earlier version of this doc cited
  specific GitHub issue numbers as proof that Godot's native
  `Window.focus_exited`/`focus_entered` signals fire correctly on Web export
  (and that a `JavaScriptBridge`-driven `document.visibilitychange` hook is
  unnecessary). Those citations did not survive fact-checking against this
  project's own pinned engine-reference library
  (`docs/engine-reference/godot/`) and must be treated as unverified, not
  confirmed fact — see Open Questions below (corrected 2026-08-04
  `/design-review` — a prior version of this line cited "this doc's design
  review log," which does not exist as a file; there is no separate review
  log for this document, only this inline history). The underlying
  behavioral claim (native `focus_exited`/
  `focus_entered` firing on Web export, no `JavaScriptBridge` workaround
  needed) remains the working hypothesis this design is built on, but it is
  now explicitly a **hypothesis pending empirical confirmation**, tracked in
  Open Questions, not a cited-and-closed engine fact. Whether OS-level touch
  cancellation without an accompanying focus change (some pull-to-refresh or
  edge-swipe gestures, possibly) reliably triggers `focus_exited` on mobile
  browsers is a second, separate unconfirmed question — also tracked in Open
  Questions. Both causes are still meant to route through this same Core
  Rule 8 transition once detected, pending that verification.
- **If input events arrive faster than one per frame** (rapid touch-move
  deltas): every event is processed in order with no coalescing or skipping —
  this game's interaction volume is low enough that this is not a performance
  concern at MVP scope.

## Dependencies

Input Abstraction has no upstream dependencies — Foundation layer, zero
external inputs.

**Downstream dependents** (hard dependencies — neither has an alternative
input path):
- **Object Placement** — needs `drag_start`/`drag_move`/`drag_end` + `tap` +
  `position`/`delta`/`canceled` to reposition objects and to acknowledge a
  tap landing on an object's footprint (wobble feedback). Object Placement's
  Core Rule 4 now checks `canceled` before validity, and a new Core Rule
  handles the tap-on-footprint case — see that file's Core Rules and
  Acceptance Criteria.
- **Tending Input** — needs `tap` (and possibly drag, depending on how that
  system designs the watering gesture) + `position` to target the action

Both dependents (`object-placement.md`, `tending-input.md`) exist and list
"Input Abstraction" in their own Dependencies sections (bidirectionally
consistent, confirmed).

## Tuning Knobs

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `threshold_mouse` | 6–10px | Natural hand jitter on click gets misclassified as a drag — "tap to water" becomes unreliable | Small intentional drags get misclassified as taps — the object won't move on short repositions |
| `threshold_touch` | 14–20px | Finger jitter on tap gets misclassified as a drag — watering becomes unreliable on touch | Genuine short drags get misclassified as taps, especially on a small jar where repositions may be small |
| `watchdog_timeout_sec` | 5–10s | A genuinely held press/drag gets force-cancelled (`drag_end(canceled=true)`) before the player releases — reads as the game randomly dropping their input mid-action | The stale-pointer safety net (ADR-0008 Decision §6 — a pointer stuck down with no engine-visible interruption signal, the untested Gate A3 worst case) takes longer to recover a genuinely stuck pointer |

These two threshold knobs are independent (per-device) but both feed the
same `drag_active` formula in the Formulas section — tuning one never
affects the other. `watchdog_timeout_sec` is unrelated to the threshold
formula; it is a separate implementation-level safety-net timer defined in
`docs/architecture/adr-0008-input-gesture-abstraction-web-touch-focus.md`
Decision §6, not empirically derived (no real touch-cancellation data exists
yet — see that ADR's Risks) and should be revisited once Web Export
Verification Plan Gate A3 is actually run on real touch hardware.

## Visual/Audio Requirements

N/A — Input Abstraction is a pure infrastructure layer with no visual or
audio presence of its own. The optional cursor-highlight hover polish
mentioned in Core Rule 6 belongs to whichever presentation system implements
it (likely Diorama Rendering), not here.

## UI Requirements

N/A — Input Abstraction has no UI. It is consumed by other systems' input
handling, not exposed to the player as a screen or control.

## Acceptance Criteria

1. **GIVEN** a mouse press-and-release at the same position within
   `threshold_mouse` (8px), **WHEN** the sequence completes, **THEN** a
   single `tap` event fires with the release position.
2. **GIVEN** a mouse press followed by movement of exactly 8px (==
   `threshold_mouse`), **WHEN** release happens without exceeding 8px,
   **THEN** a `tap` fires, not `drag_start` — the boundary is strict `>`,
   not `>=`.
3. **GIVEN** a mouse press followed by movement of 9px (> `threshold_mouse`),
   **WHEN** the movement is detected, **THEN** `drag_start` fires, followed
   by `drag_move` events for continued movement, and `drag_end`
   (`canceled = false`) on release.
4. **GIVEN** a touch press-and-release within `threshold_touch` (16px),
   **WHEN** the sequence completes, **THEN** a single `tap` event fires.
5. **GIVEN** a touch press followed by movement of 17px (> `threshold_touch`),
   **WHEN** detected, **THEN** `drag_start`/`drag_move`/`drag_end`
   (`canceled = false`) fire as with mouse.
5a. **GIVEN** a touch press followed by movement of
   exactly 16px (== `threshold_touch`), **WHEN** release happens without
   exceeding 16px, **THEN** `tap` fires, not `drag_start` — the touch-side
   twin of AC2, confirming the boundary is strict `>` for both devices.
6. **GIVEN** any gesture event, **WHEN** it fires, **THEN** it carries a
   `device_id` field identifying whether the source was mouse
   (`DEVICE_ID_MOUSE`) or a specific touch point.
7. **GIVEN** a `drag_move` or `drag_end` event, **WHEN** it fires, **THEN**
   its `delta` field equals the movement since the previous `drag_move` (or
   since `drag_start` for the first `drag_move`).
8. **GIVEN** a pointer already in PRESSED state, **WHEN** a second touch
   point begins, **THEN** no `tap`/`drag_*` event fires for the second touch
   point, no other event or signal fires for it either (corrected round-2
   `/design-review` — see Core Rule 5), and the first pointer's state is
   unaffected.
8a. **GIVEN** a second touch point that began (and was
   ignored) while the first pointer was PRESSED, and that second touch is
   still held down, **WHEN** the first pointer releases and returns to IDLE,
   **THEN** the held second touch does **not** automatically enter PRESSED —
   it produces no event until it lifts and presses again (Core Rule 5). An
   implementation that promotes it using its current position on the first
   pointer's release fails this criterion.
9. **GIVEN** a pointer already in DRAGGING state, **WHEN** a second touch
   point begins, **THEN** no `tap`/`drag_*` event fires for the second touch
   point, no other event or signal fires for it either (corrected round-2
   `/design-review` — see Core Rule 5), and the first pointer's drag
   continues uninterrupted.
9a. **GIVEN** a touch pointer already in PRESSED or
   DRAGGING state, **WHEN** an engine-synthesized mouse-emulation event
   (`InputEventMouseButton`/`InputEventMouseMotion`) arrives for the same
   physical contact, **THEN** no event fires for the mouse device_id and the
   touch pointer's state is unaffected (Core Rule 7) — this is the same
   arbitration as AC8/9, applied to a same-contact synthetic event.
10. **GIVEN** a pointer in DRAGGING state, **WHEN** it is interrupted (tab/app
    loses visibility, or a touch-cancel event), **THEN** `drag_end` fires
    immediately at the last known position with `canceled = true`, and state
    returns to IDLE. **Gate-ability (restructured 2026-08-04 round 2
    `/design-review`, `qa-lead` finding — this caveat previously lived in a
    separate paragraph before this criterion, reachable only by a two-hop
    pointer from 10a/10c/10d/10e; folded in here directly so it travels with
    AC10 itself if this criterion is ever copied into a story file in
    isolation):** this and every criterion in the AC10 family (10a, 10c,
    10d, 10e — 10b carries its own equivalent split already) verifies
    state-machine behavior *given that an interruption signal was detected*
    — none of them can independently confirm that a real interruption
    (tab-visibility loss or OS-level touch-cancel) actually produces that
    signal on a target Web-export browser in the first place, since that is
    exactly the hypothesis Core Rule 8 and Open Questions flag as
    unconfirmed. Unit-testable today only against a *simulated* interruption
    signal; none of them counts as production-verified until the same
    empirical prototype pass required by Open Questions confirms real
    interruptions actually fire that signal on target browsers. Do not mark
    any of AC10/10a/10c/10d/10e "passing" on simulated-signal unit-test
    evidence alone.
10a. **GIVEN** a pointer in PRESSED state (no
    `drag_start` fired yet), **WHEN** it is interrupted, **THEN** no event
    fires and state returns directly to IDLE — the boundary case AC10 alone
    doesn't cover, since PRESSED has no drag to cancel. **Gate-ability:**
    same caveat as AC10's own body above — simulated-signal unit-testable
    now, not yet production-gate-able.
10b. **GIVEN** a touch pointer in DRAGGING state,
    **WHEN** the OS delivers a touch-cancel (not a tab-visibility change —
    e.g. an incoming call), **THEN** the same AC10 behavior applies
    (`drag_end`, `canceled = true`, IDLE) — touch-cancel and tab-visibility
    loss both route through Core Rule 8's single interruption transition.
    **Split for gate-ability:** this AC has two parts that must be verified
    separately. (i) *Unit-testable now*: given a `focus_exited`-equivalent
    signal fires, `drag_end`/`canceled=true`/IDLE results — this can be
    verified today against a simulated signal. (ii) *Not yet gate-able*:
    that a real OS-level touch-cancel on a target mobile browser actually
    triggers that signal in the first place — this is unconfirmed (see Core
    Rule 8, Open Questions) and must be verified empirically via a throwaway
    prototype before this AC counts as production-verified. Do not mark this
    AC "passing" on unit-test evidence alone.
10c. **GIVEN** a pointer in DRAGGING state with its
    reported position currently clamped to the viewport edge (Edge Cases),
    **WHEN** it is interrupted, **THEN** `drag_end` fires at the clamped
    position, not an unclamped/raw one. **Gate-ability:** same caveat as
    AC10's own body above — simulated-signal unit-testable now, not yet
    production-gate-able.
10d. **GIVEN** a pointer in PRESSED state with a completed tap (press-and-
    release within threshold) queued in the same frame that an interruption
    also arrives, **WHEN** both are processed, **THEN** the interruption
    transition fires (state → IDLE, no event) and the queued `tap` never
    fires — never both. **Gate-ability:** same caveat as AC10's own body
    above — simulated-signal unit-testable now, not yet production-gate-able.
10e. **GIVEN** a pointer in DRAGGING state with a normal release queued in
    the same frame that an interruption also arrives, **WHEN** both are
    processed, **THEN** only the interruption's `drag_end`
    (`canceled = true`) fires at the last known position — the queued normal
    `drag_end` (`canceled = false`) never fires, and no duplicate `drag_end`
    occurs. **Gate-ability:** same caveat as AC10's own body above —
    simulated-signal unit-testable now, not yet production-gate-able.
11. **GIVEN** a drag that moves the pointer outside viewport bounds, **WHEN**
    `drag_move` fires, **THEN** the reported position is clamped to the
    viewport edge, not extrapolated beyond it.
12. **(narrowed 2026-08-04 `/design-review`, `qa-lead` finding — this
    criterion previously asserted a downstream fact as already true; it
    wasn't. Neither `object-placement.md` nor `tending-input.md` currently
    documents any hover-derived signal as presentation-only, since neither
    consumes one yet. Narrowed to only what this system itself can verify.)**
    **GIVEN** raw mouse-motion-without-press over the jar (hover, no click),
    **WHEN** this occurs, **THEN** no `tap`/`drag_start`/`drag_move`/
    `drag_end` fires from Input Abstraction — this system itself stays fully
    silent on hover, regardless of what any consuming system does with raw
    motion data it separately chooses to forward. Core Rule 6's *cross-system*
    parity guarantee — that hover is never the *sole* channel conveying
    information to the player — is a separate, currently-unenforced
    obligation: it requires its own corresponding acceptance criterion in
    each consuming system's GDD (e.g. Object Placement, Tending Input)
    verifying that system doesn't gate information behind hover. Neither
    currently has one. Tracked in Open Questions, not asserted as already
    satisfied.
13. **GIVEN** a touch lifted while positioned outside the jar bounds (a
    normal release, not an interruption — Edge Cases), **WHEN** `drag_end`
    fires, **THEN** it fires at the clamped last-known position with
    `canceled = false`, distinguishing this from the interrupted case (AC10c,
    which fires `canceled = true`) even though both report a clamped
    position.
14. **GIVEN** the jar node has a non-identity transform (e.g. camera framing
    or scene-space offset) relative to the viewport, **WHEN** any gesture
    event fires, **THEN** its `position` reflects the jar-local conversion
    (Core Rule 4), not the raw unconverted viewport-space coordinate — this
    verifies the coordinate-space fix directly rather than relying on
    consuming systems to catch a mismatch indirectly.
15. **GIVEN** the project's `emulate_mouse_from_touch` setting, **WHEN** the
    project is configured for this game, **THEN** it is confirmed disabled —
    verifiable as a project-settings check, not a runtime behavior test.
16. **GIVEN** a touch pointer already active (PRESSED or DRAGGING), **WHEN**
    a distinct physical mouse device (not a touch-emulated mouse event from
    the same contact — see AC9a) begins a press, **THEN** no event fires for
    the mouse `device_id` and the touch pointer's state is unaffected — the
    general case of Core Rule 7 that AC8/9/9a only partially cover.
17. **GIVEN** an input event whose `device_id` is neither `DEVICE_ID_MOUSE`
    nor an active touch-point id (e.g. a joypad event), **WHEN** it arrives,
    **THEN** it is not processed by this state machine at all — no state
    transition, no gesture event, and `threshold[device_id]` is never
    evaluated for it (Formulas' defensive clarification).
~~18. **GIVEN** a second touch point that begins while the first pointer is
    already PRESSED or DRAGGING (AC8/9's ignored case), WHEN it is ignored,
    THEN a `pointer_ignored` signal fires with that contact's position and
    no state change.~~ — **Removed 2026-08-04 `/design-review`** (see Core
    Rule 5's correction): the `pointer_ignored` acknowledgment signal this
    criterion tested was cut entirely, not just its visual treatment — an
    ignored second touch point now produces no signal and no feedback of any
    kind. AC8/9 (unaffected — they verify the first pointer's state and the
    absence of `tap`/`drag_*` events, which still holds) already fully cover
    what remains true after this cut.
19. **(new, 2026-08-04 `/design-review`, `systems-designer` finding — tests
    new Core Rule 7a)** **GIVEN** a pointer with `device_id` X is in PRESSED
    state, **WHEN** a new press-begin event for that *same* `device_id` X
    arrives (e.g. a lost release followed by touch-index reuse), **THEN** no
    event fires for the stale press, and the pointer transitions directly to
    PRESSED for the new press — never remaining in a state that reflects the
    old, already-ended contact.
19a. **(new, 2026-08-04 `/design-review`, `systems-designer` finding)**
    **GIVEN** a pointer with `device_id` X is in DRAGGING state, **WHEN** a
    new press-begin event for that *same* `device_id` X arrives, **THEN**
    `drag_end(canceled = true)` fires at the pointer's last known position
    first, and only then does the pointer transition to PRESSED for the new
    press — confirming the implicit-release-then-press contract from Core
    Rule 7a produces the same `canceled = true` semantics as a genuine
    interruption (Core Rule 8), not a silent state overwrite.

*(Reviewed via `/design-review` on 2026-08-04 — first full review, full
specialist round: `godot-specialist`, `systems-designer`, `qa-lead`,
`game-designer`, `creative-director`. Verdict: NEEDS REVISION → all 5
blockers resolved below (user confirmed "revise now"). **Blocking status
propagated** (header, new AC10-family gate-ability note): `qa-lead` found
this document's own self-declared `[BLOCKING, escalated this revision]`
Open Question wasn't surfaced in the header (still read "Designed — pending
review") or in AC10/10a/10c/10d/10e, which silently depend on the same
unconfirmed engine behavior as AC10b without AC10b's explicit "not yet
gate-able" caveat — a reviewer could mark them passing on simulated-signal
evidence alone. Fixed: header now states the BLOCKED status; a single
shared gate-ability note now covers the whole AC10 family instead of
repeating AC10b's caveat five times. **Same-`device_id` re-press defined**
(new Core Rule 7a, new States/Transitions rows, new AC19/19a):
`systems-designer` found no defined behavior for a same-`device_id`
press-begin arriving while that pointer is already PRESSED/DRAGGING (as
opposed to a *different* `device_id`, which Core Rule 7 already covers) —
concretely reachable via a dropped touch-release event followed by
touch-index reuse. Resolved as an implicit release-then-press, producing
the same `canceled=true` semantics as a genuine interruption if the pointer
was DRAGGING. **AC12 narrowed to what's actually true today**: `qa-lead`
found AC12 asserted, as an already-satisfied fact, that consuming systems
document hover-derived signals as presentation-only — grep-confirmed false
for both `object-placement.md` and `tending-input.md`, since neither
consumes a hover signal yet. Narrowed to only what Input Abstraction itself
can verify (it stays silent on hover); the cross-system obligation is now
tracked as a new Open Question instead of asserted as already met.
**Dangling review-log citations removed**: `godot-specialist` confirmed
this document cited "this doc's design review log" twice with no such file
existing on disk (only `content-data.md` and `ecosystem-simulation.md` have
review logs). Both citations corrected to point at this document's own
Open Questions / this trailing note instead. **`pointer_ignored` visual
acknowledgment cut, not just its styling deferred** (Core Rule 5, Edge
Cases, AC8/9, removed AC18): `game-designer` found the mandated pulse for
an ignored second touch point (meant to acknowledge things like a resting
palm) actually undermines this document's own Player Fantasy, since the
system can't distinguish incidental contact from intended input — the
pulse would most often fire for contact the player never consciously made,
which is a louder "calls attention to itself" violation than the silence
it was meant to fix. `creative-director` ruled: cut it entirely, trust
silence; reintroduce only with playtest evidence of genuine confusion. The
underlying `pointer_ignored` *Open Question about styling* is resolved as
moot (there is nothing left to style); a genuinely new "hover-parity ACs
missing downstream" Open Question was added in its place, unrelated to the
removed signal. **Two findings independently validated, not new
blockers**: `godot-specialist` re-checked both of Core Rule 1/8's unverified
Web-export behavior claims directly against this project's full
`docs/engine-reference/godot/` snapshot and confirmed neither is resolvable
from documentation alone — this confirms the document's own existing Open
Question is correctly scoped, not a new defect to fix. **Recommended items
deferred, not addressed this round** (user scoped this revision to blocking
items only): jitter-drag-then-return latching false positive, no
hysteresis/return-to-tap path (`systems-designer`); `threshold_touch`'s
screen-pixel space vs. `footprint_size`'s jar-local space has no stated
scale factor, making the already-deferred small-object-precision playtest
question actually unquantifiable as specified (`systems-designer`);
per-consumer threshold override architecture left unresolved rather than
built now (`game-designer`); `DEVICE_ID_MOUSE` vs. touch-index numeric
collision unverified (`godot-specialist`); snap-back-vs-commit-position on
interruption not reconsidered against the "never punish" anti-pillar
(`game-designer`). Tracked for a future pass.)*

*(Reviewed via `/design-review` on 2026-08-04 — round 2, full specialist
round: `godot-specialist`, `systems-designer`, `qa-lead`, `game-designer`,
`creative-director`. Verdict: **APPROVED** — no new blocking findings; all
four specialists independently confirmed round 1's 5 fixes hold up
correctly. Three small cleanup items applied in this same pass rather than
deferred, per `creative-director`'s "ship it, none warrants another review
round" ruling: **Header corrected** — `godot-specialist` found the header's
"Core Rules 1/7a/8" over-scoped the BLOCKED gate; Core Rule 7a's resolution
is fully self-contained and makes no unverified engine-behavior claim (the
BLOCKING Open Question itself only ever named "Core Rule 8 and Rule 1/7,"
never 7a) — header narrowed to match. **Gate-ability note restructured**
(AC10 family): `qa-lead` found the shared caveat note lived in a separate
paragraph before AC10, reachable from AC10a/10c/10d/10e only by a two-hop
pointer ("see the note above") — a real risk given this document explicitly
anticipates individual ACs being lifted into story files. Folded directly
into AC10's own body (single-hop for the rest of the family), matching this
document's established self-contained-caveat convention already used by
AC10b/12/19. `creative-director` called this "the same defect class round 1
fixed [for the header], reintroduced one section lower" — correctly
recommended, not blocking, only because the document's own BLOCKED gate
already prevents story decomposition today. **`press_pos` reset made
explicit** (Core Rule 7a, nice-to-have): `systems-designer` found the reset
was implied but not stated; added directly, though `creative-director`
noted the ambiguity was never truly live given Formulas' existing
definition. No disagreements this round beyond `creative-director`
downgrading the `press_pos` finding from recommended to nice-to-have (still
applied, since free) — surfaced here for completeness, not left open.)*

## Open Questions

- **[BLOCKING, escalated this revision] Empirical verification of Core Rule
  8 and Rule 1/7 before downstream lock-in required.** This doc's own prior
  citations for (a) `focus_exited`/`focus_entered` firing reliably on Web
  export, and (b) real touch synthesizing a duplicate `InputEventMouseMotion`
  despite `emulate_mouse_from_touch` being disabled, did not survive
  fact-checking against `docs/engine-reference/godot/` and must be treated as
  unverified hypotheses, not confirmed engine behavior — independently
  re-checked by `godot-specialist` during the 2026-08-04 `/design-review`
  pass against this project's full `docs/engine-reference/godot/` snapshot
  (VERSION.md, breaking-changes.md, deprecated-apis.md,
  current-best-practices.md): neither behavior is covered by that snapshot
  either way, confirming this really is unresolvable from documentation
  alone, not merely unresearched. Both behaviors remain this design's
  working assumptions, but Object
  Placement and Tending Input already depend on the `canceled` contract these
  rules produce. **Required before those two systems' dependency on this
  contract is considered safe**: build a throwaway prototype (`prototypes/`)
  that exercises pointer interruption and touch/mouse-emulation dedup on real
  target mobile browsers (via WebSearch for current Godot 4.7.1 Web-export
  input behavior plus hands-on testing), and confirm both behaviors hold.
  Owner: technical-director. Target: before implementation begins on Object
  Placement or Tending Input's input-handling code. **How this gets resolved
  (added 2026-08-09):** see `docs/technical-setup/web-export-verification-plan.md`
  → Gate A, which specifies the probe scene, procedure, and pass/fail criteria
  for each sub-question (A1 touch/mouse synthesis, A2 focus-out reachability and
  delivery timing, A3 OS-level touch cancellation, A4 drag past the canvas edge,
  A5 DPI/zoom independence). Still unverified — nothing has been run.
- **Touch drag-continuation past the canvas edge on Web export**: whether
  `InputEventScreenDrag` keeps delivering (allowing clamp-and-continue) or
  stops entirely once a finger leaves the canvas DOM element, unlike mouse.
  Verify as part of the same prototype pass above. Owner: technical-director.
- **Hover-highlight scope**: Is the optional mouse-hover visual polish
  mentioned in Core Rule 6 in scope for MVP, or deferred to a later polish
  pass? It's explicitly non-gameplay-critical, so it can slip without
  blocking other systems. Owner: art-director. Target: before Diorama
  Rendering GDD authoring.
- ~~**`pointer_ignored` acknowledgment styling**~~ — **RESOLVED (removed)
  2026-08-04 `/design-review`**: the underlying acknowledgment signal this
  question was about was cut entirely (see Core Rule 5's correction) rather
  than left open for a future styling pass — an ignored second touch point
  now produces no feedback of any kind, so there is no treatment left to
  decide.
- **Hover-parity acceptance criteria missing in consuming systems** (new,
  2026-08-04 `/design-review`, `qa-lead` finding — see AC12's correction):
  Core Rule 6's cross-system guarantee that hover is never the *sole*
  channel conveying information requires a corresponding acceptance
  criterion in each consuming system's own GDD, verifying that system
  doesn't gate information behind hover. Neither `object-placement.md` nor
  `tending-input.md` currently has one, since neither yet forwards or
  consumes a hover-derived signal. Owner: whoever authors the first
  hover-derived signal in a consuming system. Target: before that signal
  ships, not before this GDD's approval.
- **DPI/zoom independence of thresholds:** Core Rule 4's jar-local conversion
  closes the most likely failure mode (canvas stretch-mode desync), but
  empirically verifying this holds across actual browser zoom levels and
  high-DPI displays, per the project's chosen `window/stretch` settings, is
  still open. Owner: technical-director. Target: technical setup phase.
- **Touch-threshold precision on small objects**: the single global
  `threshold_touch` (16px) may make precise small-object repositioning (e.g.
  the rock, per `object-placement.md`) systematically less precise on touch
  than mouse. Flagged for playtest validation during Vertical Slice — if the
  asymmetry proves to matter in practice, revisit whether Object Placement
  should own its own drag-intent threshold rather than inheriting this one.
  Owner: game-designer. Target: vertical-slice playtesting.

**Resolved this revision** (previously tracked here as Object Placement
companion edits — now implemented directly in `object-placement.md`, see
that file's Core Rules and Acceptance Criteria): the `canceled`-flag revert
check, and tap-on-footprint acknowledgment (wobble) for touch parity.
