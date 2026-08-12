# Cross-GDD Review Report

**Date**: 2026-08-09
**GDDs Reviewed**: 11 (all MVP systems) + `game-concept.md` + `systems-index.md`
**Systems Covered**: Content Data, Input Abstraction, Object Placement, Ecosystem Simulation, Tending Input, Time & Drift, Creature Behavior, Persistence/Save, Discovery Surfacing, Diorama Rendering, Ambient Audio

**Context**: this review ran immediately after a same-session batch of fixes (art bible timing decision, GUT/gdUnit4 resolution, plant-instance-count closure, the `N_departure_ticks` tuning pass, the watering visual cue addition, and the Web-export verification plan). It served two purposes: reviewing the whole GDD set as usual, and specifically checking whether that same-session batch introduced new drift — a real risk this exact review caught (see Blocking Consistency Issues).

---

## Consistency Issues

### Blocking — found and fixed same session

🔴 **`CONDITION_STREAK_MAX` was internally contradictory within `persistence-save.md`.**
The document's header, Core Rule 1 prose, AC5b, and Open Questions all said 25 (following the `N_departure_ticks` retune), but the Formulas section's own Variables table row still showed the stale value 5 with "provisional" language. **Fixed**: table row corrected to 25, stale language removed.

🔴 **`tending-input.md` still claimed zero downstream dependents**, despite `diorama-rendering.md`'s new Core Rule 11 (Watering Substrate Sheen) and `ambient-audio.md`'s existing Core Rule 3 both reading its `apply_watering()` trigger event — and despite `diorama-rendering.md` explicitly claiming this had already been reciprocated. **Fixed**: `tending-input.md`'s Interactions and Dependencies sections now list both as soft downstream dependents.

### Warnings — found and fixed same session

⚠️ `diorama-rendering.md`'s new `D_water` constant was claimed registered in `entities.yaml` but wasn't. **Fixed**: registered (source `ambient-audio.md`, referenced by both docs).
⚠️ `systems-index.md`'s Diorama Rendering row was missing the new Tending Input (soft) dependency. **Fixed**: both the Systems Enumeration table and Dependency Map updated.
⚠️ `entities.yaml`'s top-level `last_updated` stamp was stale relative to entries revised inside it. **Fixed**: bumped with a summary comment.
⚠️ `tending-input.md`'s watering-saturation Open Question ("is `jar_moisture=100` actually optimal?") was answerable from already-locked numbers but left open. **Fixed**: closed — max-watering pushes all three MVP plants outside their moisture bands, so saturation is actively counterproductive, not dominant.

### Warnings — not resolved, flagged for design judgment

⚠️ **Operator vs. witness identity skew** (first flagged 2026-08-05, still open): the new Watering Substrate Sheen cue makes the immediate "operator" feedback loop richer while growth's "witness" payoff remains next-visit-only by design — the imbalance the prior review flagged may have widened, not narrowed. Recommend treating this as a specific Vertical Slice playtest question.
⚠️ **`N_departure_ticks=25`'s fastest path is ~2.5 real days** (Moth's deterministic floor) — a plausible normal weekend absence for this game's own target player profile, not obviously "a genuinely long absence." The retune is structurally correct math; whether it *reads* as "moving on" vs. "penalized for a normal weekend" is an empirical question for Vertical Slice, not settled by the trace alone.
⚠️ **Object Placement's Player Fantasy overstates the felt magnitude** of creature-wander influence (quantified 2026-08-05 as ≈2.4% of jar sampling area — real but likely imperceptible). Unfixed since first flagged.
⚠️ **First-watering-tap fade-in race** in `ambient-audio.md`: if a player's very first interaction is a watering tap, it's undefined whether the watering swell reads against the still-fading-in base loop or a not-yet-reached target volume. No AC exercises this specific ordering.
⚠️ **Live-vs-committed object position ambiguity**: `creature-behavior.md`'s destination-sampling formula doesn't specify whether it reads Object Placement's committed `position` or live `visual_pos` during an in-progress drag.
⚠️ **Session-start audio/visual reveal timing gap**: Discovery Surfacing's reveal begins at `t=0` on `ACTIVE`, but Ambient Audio's fade-in is gated on the player's first input gesture — a player who looks before touching sees part of the reveal silently, with no audio.

---

## Design/Architecture Issues

### Blocking — found and fixed same session

🔴 **No system supplied a valid "last-known position" for a creature that departs entirely inside Time & Drift's invisible catch-up batch** — and, given `N_departure_ticks=25`, this is now the *dominant* departure path, not an edge case. `ecosystem-simulation.md` never tracked position; `creature-behavior.md` never spawns an instance for a creature that settles ABSENT; `discovery-surfacing.md`'s Departure cue nonetheless required a position at "the moment of transition" that no system ever computed.

**Fixed** with a real mechanism, not a text patch:
- `ecosystem-simulation.md` — new **Core Rule 12**: owns one `last_known_position` per creature, written by Creature Behavior every live frame, defaulting to jar-center `(0,0)` until a creature's first-ever live instance. New **Core Rule 13**: a transient `was_present_during_batch` flag so a full spawn-then-departure cycle within one batch isn't silently swallowed.
- `creature-behavior.md` — new **Core Rule 9**: calls `set_last_known_position()` every live frame, same frame as its own movement update.
- `discovery-surfacing.md` — Core Rule 7 corrected to source position from Ecosystem Simulation's `last_known_position` rather than an unwitnessed "moment of transition"; new **Core Rule 2a** (`full_cycle` exception) generates a Departure item for a within-batch spawn-then-departure cycle instead of suppressing it as "nothing changed" — closing a second gap (the residency was real even though net PRESENT/ABSENT state was unchanged, and silently dropping it read worse than Pillar 4 intends).
- `persistence-save.md` — new `last_known_position` blob field (always present, unlike the existing PRESENT-only `creature_position`), a matching `save_blob_validity` clause, and AC7b.

New ACs added: ecosystem-simulation.md 27–30+, creature-behavior.md's Core Rule 9 description, discovery-surfacing.md AC8a/8b/14/14a, persistence-save.md AC7b.

### Warnings — carried over or newly surfaced, not resolved

(See Consistency Issues warnings above — the design-theory and consistency warnings overlap substantially this round since most trace back to the same two root causes: the watering-cue addition and the `N_departure_ticks` retune.)

---

## Cross-System Scenario Findings

Five scenarios walked (session start after a long absence; a watering tap; object drag-and-drop near a wandering creature; a save/load cycle spanning a mid-drag/mid-swell tab close; a creature departing while Discovery Surfacing reveals it). Three confirmed **clean by deliberate construction** (no finding): Object Placement's committed-vs-live position split means a save mid-drag never races; a mid-swell close persists nothing extra since `jar_moisture` is already written live and independently of the swell animation.

The one blocker found (the last-known-position gap) is now fixed above. Four warnings carried through from the scenario walkthrough are listed in the Consistency Issues warnings section (first-watering-tap race, live-vs-committed position ambiguity, session-start audio/visual timing gap) plus the shared point-of-failure note: Object Placement's interrupt-revert and Persistence/Save's backgrounding write both depend on the same unverified `visibilitychange`/`focus_exited` signal — already tracked BLOCKING in three GDDs and the subject of `docs/technical-setup/web-export-verification-plan.md`.

---

## GDDs Flagged for Revision

All blocking items were fixed same-session (this project's established pattern — see prior review rounds 2026-08-05). No GDD requires further revision to clear this review's blocking findings. Remaining warnings are tracked above as open design judgment calls, not doc defects.

| GDD | Warning | Priority |
|---|---|---|
| `ecosystem-simulation.md`, `tending-input.md`, `diorama-rendering.md` | Operator-vs-witness identity skew, possibly widened by the new watering cue | Warning — Vertical Slice playtest question |
| `ecosystem-simulation.md` | `N_departure_ticks=25`'s fastest path (~2.5 days) may still read as punishing for a normal weekend absence | Warning — Vertical Slice playtest question |
| `object-placement.md` | Player Fantasy overstates felt magnitude of creature-wander influence | Warning — unfixed since 2026-08-05 |
| `ambient-audio.md` | First-watering-tap-as-first-interaction fade-in race, undefined | Warning |
| `creature-behavior.md` | Destination sampling doesn't specify committed-vs-live object position during a drag | Warning |
| `discovery-surfacing.md`, `ambient-audio.md` | Session-start reveal can begin before audio context unlocks | Warning |

---

## Verdict: **CONCERNS**

All findings that would have blocked architecture (2 consistency, 1 design/architecture — the last-known-position gap) were resolved same session, matching this project's established review pattern (fix-in-session, no formal specialist re-review round, user decision). Six warnings remain, none blocking — all are genuine design judgment calls (playtest questions, unqualified claims, unspecified edge-case ordering) rather than defects requiring a doc fix before `/create-architecture` can proceed.

### Recommended before Vertical Slice (not blocking Technical Setup)
- Playtest the operator/witness identity split and the `N_departure_ticks=25` "does this read as punishing" question specifically — both are empirical, not resolvable by further doc analysis.
- Resolve the first-watering-tap audio race and the session-start audio/visual timing gap in `ambient-audio.md` (small, concrete fixes — audio-director's call).
- Resolve the committed-vs-live object position ambiguity in `creature-behavior.md`'s destination sampling (small, concrete — systems-designer's call).
