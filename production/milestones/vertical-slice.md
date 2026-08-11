# Milestone: Vertical Slice

## Overview

- **Target Date**: **TBD — not yet committed.** `design/gdd/game-concept.md`'s own Scope Tiers table
  explicitly defers this: "Rebaselined 2026-08-09: pending `/estimate` against Technical Setup
  epics/stories — 11 MVP systems are now fully specified (vs. the pre-design '2-4 weeks' guess), so
  this figure is no longer load-bearing." Run `/estimate` once epics/stories exist (after this
  milestone's own scoping work below) and fill in a real date then — not before. A fabricated date
  here would be worse than an honest TBD.
- **Type**: Vertical Slice
- **Duration**: TBD (pending `/estimate`)
- **Number of Sprints**: TBD (pending `/estimate`)

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
| Content Data (type registry) | `content-data.md` | ADR-0001 (Accepted) | TBD | Not started |
| Input Abstraction (gesture layer) | `input-abstraction.md` | ADR-0008 (Accepted) | TBD | Not started — blocked on RISK-0001 |
| Object Placement (repositioning) | `object-placement.md` | ADR-0003 (Accepted) | TBD | Not started |
| Ecosystem Simulation (moisture/light/growth) | `ecosystem-simulation.md` | ADR-0004 (Accepted) | TBD | Not started — 1 real test exists (`EcosystemFormulas.moisture_after_watering`), rest unimplemented |
| Tending Input (watering) | `tending-input.md` | ADR-0011 (Accepted) | TBD | Not started |
| Time & Drift (session lifecycle) | `time-drift.md` | ADR-0006 (Accepted) | TBD | Not started |
| Persistence/Save | `persistence-save.md` | ADR-0005 (Accepted) | TBD | Not started — blocked on RISK-0002 for full confidence, ships on Chromium-verified design regardless |

### Should Ship (Planned but Cuttable)

| Feature | Design Doc | Owner | Sprint Target | Cut Impact | Status |
|---------|-----------|-------|--------------|-----------|--------|
| Creature Behavior (Snail/Moth wander) | `creature-behavior.md` | ADR-0007 (Accepted) | TBD | Jar reads as less alive; Ecosystem Simulation's PRESENT/ABSENT state still works without live movement | Not started |
| Discovery Surfacing (what-changed reveal) | `discovery-surfacing.md` | ADR-0002 + ADR-0010 (both Accepted) | TBD | Loses the primary vehicle for the falsifiable hypothesis above — cutting this cuts the milestone's own validation goal, weigh carefully | Not started |
| Ambient Audio | `ambient-audio.md` | ADR-0012 (Accepted) | TBD | Loses half the "Sensation" co-primary aesthetic; Diorama Rendering alone still carries the visual half | Not started |

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

TBD — depends on the sprint count `/estimate` produces. Populate once `/sprint-plan new` has run
against real epics/stories.
