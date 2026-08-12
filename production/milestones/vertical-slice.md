# Milestone: Vertical Slice

## Overview

- **Target Date**: **2026-09-10 (Must-Ship completion), projected — not a hard commitment.**
  Derived 2026-08-12 from a real `/estimate` pass against Foundation+Core epics (Content Data,
  Input Abstraction, Object Placement, Ecosystem Simulation — 12.0 expected days) plus a
  lighter complexity-based sizing pass against the 3 remaining Must-Ship systems (Tending
  Input, Time & Drift, Persistence/Save — ~7.0 expected days), using each system's actual
  GDD acceptance-criteria count and formula complexity, not a T-shirt-size guess.
  **Deliberately does not reuse `prototypes/terrarium-vertical-slice/REPORT.md`'s own build
  velocity** — that report explicitly flags itself as AI-authored against pre-specified
  GDDs and non-representative of human production velocity; using it here would silently
  reintroduce the exact fabricated-date risk this field was left TBD to avoid.
  **Assumptions this date depends on** (stated explicitly so they can be checked, not
  buried): solo full-time dedication, 1 sprint = 5 working days, start date 2026-08-13.
  Change any of these and this date should be recomputed, not just distrusted.
- **Type**: Vertical Slice
- **Duration**: ~19 expected days (Must-Ship, 7 systems) — range 13.0 (optimistic) to
  29.0 (pessimistic) days. Pessimistic case is driven almost entirely by Input Abstraction's
  unresolved Web-export verification gap (TR-input-abstraction-006) and Persistence/Save's
  34-AC dual-path (Web/non-Web) surface, not by the other 5 systems.
- **Number of Sprints**: 4 (Must-Ship, 5 working days/sprint) + 1 stretch sprint if
  Should-Ship items (Creature Behavior, Discovery Surfacing, Ambient Audio — ~6.5 expected
  days combined) are also attempted. Diorama Rendering (Stretch tier) is deliberately
  **not** sprint-assigned — still blocked on Gate C4 per the 2026-08-12 gate-check
  (`production/gate-checks/pre-production-to-production-2026-08-12.md`), which found Gate
  C4 has never produced a real frame-budget measurement on any device.

## Milestone Goal

Validate the full core loop end-to-end — tend the jar, leave, return, notice what changed — before
committing to full Production scope. Per this project's own systems-index.md Next Steps: "Validate
the highest-risk systems (Ecosystem Simulation, Time & Drift) further via `/vertical-slice` before
committing to Production." This is not a feature-complete build; it is the minimum slice that can
prove or disprove the MVP's Core Hypothesis (below).

**Core Hypothesis under test** (from `design/gdd/game-concept.md`): *"Players want to return, day
after day, to a single tended terrarium jar because tending it and noticing what changed is
satisfying on its own, without any goals, fail states, or content beyond the jar itself."*

**Primary falsifiable sub-hypothesis** (named by creative-director at the 2026-08-11 gate-check,
sharpened by `design/art/art-bible.md` Section 2's mood-state analysis): cross-session care
attribution. The architecture guarantees moisture responds live, but `growth_stage` only ever
changes between visits via an atomic catch-up batch — meaning the player acts today and receives an
undifferentiated bundle of change tomorrow, with no live feedback connecting the two. This is
asserted, not yet validated, at session-boundary scale (the concept prototype validated
within-session cause-and-effect legibility, not across a real day-to-day gap). **Concrete test
criterion**: after several real-world-spaced sessions, can a playtester correctly name one change
they caused and one that happened on its own, without being prompted?

## Success Criteria

- [ ] Full core loop playable end-to-end: tend (water + reposition) → leave → real time passes →
      return → discovery reveal surfaces what changed → tend again
- [ ] A human plays through without developer guidance and understands what to do within the first
      2 minutes (no onboarding text exists by design — this must work from affordance alone)
- [ ] The primary falsifiable hypothesis (above) is tested with at least 1 documented playtest
      session spanning a real multi-day gap, not a same-sitting simulated one
- [ ] No critical "fun blocker" bugs in the build
- [ ] The core mechanic (tending) feels good to interact with — a subjective call, made by the user,
      not inferred from passing tests
- [ ] RISK-0001 (touch input) and RISK-0003 (Diorama Rendering frame budget) are resolved or
      explicitly, formally deferred with a documented scoping decision before this milestone's
      build is called complete — see `production/risk-register/`

## Feature List

Scope pulled directly from `design/gdd/systems-index.md`'s own Recommended Design Order and effort
sizing (1×L, 4×M, 6×S across 11 systems) — this milestone does not introduce new systems, it deepens
the same 11 MVP systems already GDD'd and architected, per that document's own Priority Tiers note:
"No separate Vertical Slice tier... the Vertical Slice milestone deepens the same 11 MVP systems...
rather than introducing new systems."

### Must Ship (Milestone Fails Without These)

| Feature | Design Doc | Owner | Sprint Target | Status |
|---------|-----------|-------|--------------|--------|
| Content Data (type registry) | `content-data.md` | ADR-0001 (Accepted) | Sprint 1 | Not started |
| Input Abstraction (gesture layer) | `input-abstraction.md` | ADR-0008 (Accepted) | Sprint 1 | Not started — blocked on RISK-0001 |
| Object Placement (repositioning) | `object-placement.md` | ADR-0003 (Accepted) | Sprint 2 | Not started |
| Ecosystem Simulation (moisture/light/growth) | `ecosystem-simulation.md` | ADR-0004 (Accepted) | Sprint 2 | Not started — 1 real test exists (`EcosystemFormulas.moisture_after_watering`), rest unimplemented |
| Tending Input (watering) | `tending-input.md` | ADR-0011 (Accepted) | Sprint 3 | Not started |
| Time & Drift (session lifecycle) | `time-drift.md` | ADR-0006 (Accepted) | Sprint 3 | Not started |
| Persistence/Save | `persistence-save.md` | ADR-0005 (Accepted) | Sprint 4 | Not started — blocked on RISK-0002 for full confidence, ships on Chromium-verified design regardless |

Sprint targets follow `systems-index.md`'s own Recommended Design Order (dependency-safe:
Content Data/Input Abstraction have no upstream dependencies; Object Placement/Ecosystem
Simulation depend only on those two; Tending Input/Time & Drift depend on Ecosystem
Simulation; Persistence/Save depends on all of the above). Sprint 1's combined estimate
(5.5 expected days: Content Data 2.0 + Input Abstraction 3.5) slightly exceeds one 5-day
sprint — expected to spill a half-day into Sprint 2, not a scoping error.

### Should Ship (Planned but Cuttable)

| Feature | Design Doc | Owner | Sprint Target | Cut Impact | Status |
|---------|-----------|-------|--------------|-----------|--------|
| Creature Behavior (Snail/Moth wander) | `creature-behavior.md` | ADR-0007 (Accepted) | Sprint 5 (stretch, ~2.5d) | Jar reads as less alive; Ecosystem Simulation's PRESENT/ABSENT state still works without live movement | Not started |
| Discovery Surfacing (what-changed reveal) | `discovery-surfacing.md` | ADR-0002 + ADR-0010 (both Accepted) | Sprint 5 (stretch, ~2.0d) | Loses the primary vehicle for the falsifiable hypothesis above — cutting this cuts the milestone's own validation goal, weigh carefully | Not started |
| Ambient Audio | `ambient-audio.md` | ADR-0012 (Accepted) | Sprint 5 (stretch, ~2.0d) | Loses half the "Sensation" co-primary aesthetic; Diorama Rendering alone still carries the visual half | Not started |

Should-Ship sizing (~6.5 expected days combined) is a lighter complexity pass, not a full
`/estimate` run each — re-run `/estimate` per-system before Sprint 5 actually starts if more
precision is needed. Given Discovery Surfacing is explicitly the milestone's own primary
validation vehicle (Success Criteria above), treat it as the highest-priority of the three
Should-Ship items if Sprint 5 capacity is constrained.

### Stretch Goals (Only if Ahead of Schedule)

| Feature | Design Doc | Owner | Value Add |
|---------|-----------|-------|----------|
| Diorama Rendering (full Light2D treatment) | `diorama-rendering.md` | ADR-0009 (**Proposed, held pending RISK-0003**) | Full Diorama Realism visual identity; a baked-only fallback can substitute if RISK-0003 hasn't cleared — see that risk's Contingency |

## Quality Gates

| Gate | Threshold | Measurement Method |
|------|-----------|-------------------|
| Frame rate | ≥ 60 FPS | `technical-preferences.md` target; RISK-0003's Gate C4 measurement is the first real data point |
| Frame budget | ≤ 16.6ms | Same source; currently `performance_budgets: []` in `docs/registry/architecture.yaml` — needs populating once first real measurements exist |
| Draw calls | ≤ 500 | Same source |
| Memory | ≤ 256MB active | Same source |
| Critical bugs | 0 open | No bug tracker exists yet — `production/qa/` not yet scaffolded |
| Test coverage | Logic stories: 100% (per `.claude/docs/coding-standards.md`'s BLOCKING gate) | GUT test suite, CI-verified (pipeline confirmed working 2026-08-11 — see `tests/README.md`) |

## Risk Register

Full entries live in `production/risk-register/` — summarized here per this template's convention.

| Risk | Probability | Impact | Mitigation | Owner | Status |
|------|------------|--------|-----------|-------|--------|
| RISK-0001: Touch input untested | Medium-High | Major | Arrange device access before slice scoping locks, or scope desktop-first | producer | Open |
| RISK-0002: Safari/iOS persistence untested | Medium | Critical | ADR-0005 already hedges structurally; re-verify on real WebKit device when access exists | technical-director | Open (accepted residual) |
| RISK-0003: Diorama Rendering frame budget unmeasured | Medium | Major | Run Gate C4 before Diorama Rendering implementation begins | technical-director | Open |

## Dependencies

### Internal Dependencies

| Feature | Depends On | Owner of Dependency | Status |
|---------|-----------|-------------------|--------|
| Tending Input, Object Placement | Input Abstraction | ADR-0008 | Accepted, unimplemented |
| Time & Drift, Creature Behavior, Discovery Surfacing, Persistence/Save | Ecosystem Simulation | ADR-0004 | Accepted, 1 formula implemented |
| Discovery Surfacing | Ecosystem Simulation + Time & Drift + Creature Behavior | ADR-0002/0004/0006/0010 | All Accepted |
| Diorama Rendering | Nearly everything (per `architecture.md` Module Ownership) | ADR-0009 | **Proposed — RISK-0003** |

### External Dependencies

| Dependency | Provider | Status | Risk if Delayed |
|-----------|---------|--------|----------------|
| Touch-capable test device | User / remote-device service | Not arranged | Blocks RISK-0001 resolution, and therefore full input validation |
| Mac/iOS Safari test device | User / remote-device service | Not arranged | Blocks RISK-0002 resolution (non-blocking to shipping — Chromium path is verified) |
| Mobile reference device (Gate C4) | User / remote-device service | Not arranged | Blocks RISK-0003 resolution and ADR-0009's promotion to Accepted |

## Review Schedule

End of each sprint (weekly, ~5 working days), against that sprint's assigned features above:
- **End of Sprint 1**: Content Data + Input Abstraction implemented and unit-tested; confirm
  Gate A (touch hardware) access decision is made per RISK-0001 before Sprint 2 needs it.
- **End of Sprint 2**: Object Placement + Ecosystem Simulation implemented and unit-tested —
  this is the project's single highest-risk system (per `systems-index.md`'s High-Risk
  Systems table); do not proceed to Sprint 3 without its formula tests passing.
- **End of Sprint 3**: Tending Input + Time & Drift implemented; cross-system integration
  smoke test (all 4 Sprint 1-2 systems + these 2 wired together via a `SessionBootstrap`-
  equivalent) run for the first time.
- **End of Sprint 4 (Must-Ship complete)**: Persistence/Save implemented; formal milestone
  review — re-run `/gate-check pre-production` at this point, since this is when the
  gate's other named blocker (real dates) will have been exercised end-to-end. Decide then
  whether Sprint 5 (Should-Ship) proceeds or the milestone closes with Must-Ship only.
- **End of Sprint 5 (if attempted)**: Creature Behavior + Discovery Surfacing + Ambient Audio.
  Re-run the vertical-slice playtest at this point if any real Diorama Rendering art has
  landed by then — this is the earliest point the unretired core-fantasy hypothesis
  (`prototypes/terrarium-vertical-slice/REPORT.md`) could be legitimately re-tested.

**Not covered by this schedule**: Diorama Rendering (Stretch, blocked on Gate C4 — no sprint
assigned per the Overview above). Gate C4 measurement should happen in parallel with Sprints
1-4, not block them, per Technical Director's finding at the 2026-08-12 gate-check.
