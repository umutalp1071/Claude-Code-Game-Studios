# Consistency Check Report

**Date**: 2026-08-05
**Registry entries checked**: 5 entities, 0 items, 9 formulas, 22 constants
**GDDs scanned**: 11 (content-data, input-abstraction, object-placement,
ecosystem-simulation, tending-input, time-drift, creature-behavior,
persistence-save, discovery-surfacing, diorama-rendering, ambient-audio)

Scope: full (run after all 11 MVP GDDs reached "Designed" status for the
first time this session)

---

## Conflicts Found

None.

## Stale Registry Entries

None. One entry was investigated as a possible false positive —
`N_departure_ticks` (registry `value: 5`) — and confirmed correct:
`ecosystem-simulation.md`'s own currently-locked value is still 5; only
the *safe tuning range* was widened to 10–30 (Tuning Knobs), with the
concrete retuned value already tracked as that GDD's own required Open
Question before implementation. Registry and source GDD agree; no
staleness.

## Unverifiable References

Several GDDs reference registered entities/formulas by name without
restating every attribute (e.g. `diorama-rendering.md` reads
`moisture_tolerance_min/max` symbolically in most places). Expected, not
a conflict.

## Clean Entries

✅ All 5 entities (Moss, Fern, Flower, Snail, Moth), all 9 formulas, and
all 22 constants verified consistent across every GDD that references
them — including the 3 newest GDDs authored this session
(`discovery-surfacing.md`, `diorama-rendering.md`, `ambient-audio.md`),
the highest-risk targets since they hadn't yet gone through independent
review. Notably:
- Fern's worked-example values in `diorama-rendering.md`'s STALLED Cue
  Tint formula (`moisture_tolerance=[55,90]`, `light_tolerance=[40,80]`)
  match the registry exactly.
- Fern's `growth_pattern=clump` assignment in `diorama-rendering.md`
  matches `content-data.md`'s fixture (`moss=carpet`, `fern=clump`,
  `flower=climb`).
- `cue_fade_duration=6.0` (source `discovery-surfacing.md`) is reused
  identically in `ambient-audio.md`'s Reactive Layer Boosts formula, and
  its registry `referenced_by` was updated accordingly.

---

## Verdict: PASS

## Context

This check followed a session that completed all 3 remaining Not
Started MVP GDDs (Discovery Surfacing, Diorama Rendering, Ambient
Audio) — all 11 MVP systems now have a GDD for the first time. Several
real cross-GDD gaps were found and fixed *during* authoring (not by this
check, but worth noting as the reason this check came back clean):
- A contradiction between Discovery Surfacing's States/Transitions table
  and its own Formulas section (sequential vs. deliberate overlap) — fixed.
- A missed hard-blocking requirement from `ecosystem-simulation.md` (the
  mandated per-plant STALLED visual cue) — caught and fully implemented
  in `diorama-rendering.md`.
- Three stale/missing bidirectional dependency listings across
  `content-data.md`, `ecosystem-simulation.md`, and `time-drift.md`.
- A scope gap (no Settings system anywhere in the project) affecting
  Ambient Audio's required mute/volume control — resolved with a
  provisional minimal solution.

## Recommended Next Steps

- Run `/design-review` on `discovery-surfacing.md`, `diorama-rendering.md`,
  and `ambient-audio.md` in **fresh sessions** (never inline) — none of
  the 3 newest GDDs have had independent review yet.
- Run `/review-all-gdds` for holistic cross-GDD design-theory review
  (dominant strategies, pacing conflicts, ownership gaps) now that all
  11 MVP GDDs exist.
- `/gate-check pre-production` becomes reachable once the above review
  passes clear.
