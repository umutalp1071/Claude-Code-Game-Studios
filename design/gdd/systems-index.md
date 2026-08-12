# Systems Index: Terrarium

> **Status**: All MVP GDDs Approved — Technical Setup gate CONCERNS (2026-08-06), entering Technical Setup. Full `/review-all-gdds` pass run 2026-08-09 (first pass covering all 11 MVP GDDs together, including the 3 newest — Discovery Surfacing, Diorama Rendering, Ambient Audio — which had never had a cross-GDD round before): verdict CONCERNS, 3 blocking findings all fixed same session (see `gdd-cross-review-2026-08-09.md`), 6 non-blocking warnings tracked for Vertical Slice.
> **Created**: 2026-08-03
> **Last Updated**: 2026-08-09 (Diorama Rendering's dependency list corrected to include Tending Input, soft — a 2026-08-09 cross-GDD review finding)
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Terrarium is a small-scope cozy ecosystem-tending sim: the player cares for a single
jar whose moisture, moss, and creature population drift on their own between visits,
driven by a rule-based simulation rather than direct player control. The mechanical
scope is deliberately narrow — no fail state, no schedule, no combat — but the
simulation itself (Ecosystem Simulation, Time & Drift) carries almost all of the
design risk, since the entire "curious satisfaction noticing what changed" hypothesis
depends on it feeling alive rather than random or static. Every other system exists
to let the player observe and gently nudge that simulation: tending input and object
placement for interaction, persistence so the terrarium survives between sessions,
and diorama-realism rendering/ambient audio so the small jar reads as a real,
physically believable place.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Content Data (inferred) | Core | MVP | Approved | [content-data.md](content-data.md) | — |
| 2 | Input Abstraction (inferred) | Core | MVP | Approved | [input-abstraction.md](input-abstraction.md) | — |
| 3 | Object Placement (inferred) | Core | MVP | Approved | [object-placement.md](object-placement.md) | Input Abstraction, Content Data |
| 4 | Ecosystem Simulation | Gameplay | MVP | Approved | [ecosystem-simulation.md](ecosystem-simulation.md) | Content Data |
| 5 | Tending Input | Gameplay | MVP | Approved | [tending-input.md](tending-input.md) | Input Abstraction, Object Placement, Ecosystem Simulation |
| 6 | Time & Drift | Gameplay | MVP | Approved | [time-drift.md](time-drift.md) | Ecosystem Simulation |
| 7 | Creature Behavior (inferred) | Gameplay | MVP | Approved | [creature-behavior.md](creature-behavior.md) | Ecosystem Simulation, Object Placement, Time & Drift |
| 8 | Persistence/Save (inferred) | Persistence | MVP | Approved | [persistence-save.md](persistence-save.md) | Content Data, Ecosystem Simulation, Object Placement, Time & Drift |
| 9 | Discovery Surfacing | UI | MVP | Approved | [discovery-surfacing.md](discovery-surfacing.md) | Ecosystem Simulation, Time & Drift, Creature Behavior |
| 10 | Diorama Rendering | UI | MVP | Approved | [diorama-rendering.md](diorama-rendering.md) | Content Data, Object Placement, Ecosystem Simulation, Creature Behavior, Time & Drift, Discovery Surfacing, Tending Input (soft, added 2026-08-09 — Core Rule 11 Watering Substrate Sheen) |
| 11 | Ambient Audio | Audio | MVP | Approved | [ambient-audio.md](ambient-audio.md) | Tending Input, Discovery Surfacing, Time & Drift (soft only — degrades gracefully to the base loop alone if any/all are absent) |
| 12 | Seasonal Cycle (inferred) | Gameplay | Alpha | Not Started | — | Time & Drift |
| 13 | Multi-Jar Management (inferred) | Core | Alpha | Not Started | — | Persistence/Save |
| 14 | Collection Tracking (inferred) | Progression | Full Vision | Not Started | — | Ecosystem Simulation, Creature Behavior |

---

## Categories

| Category | Description | Typical Systems |
|----------|-------------|-----------------|
| **Core** | Foundation systems everything depends on | Content Data, Input Abstraction, Object Placement, Multi-Jar Management |
| **Gameplay** | The systems that make the game fun | Ecosystem Simulation, Tending Input, Time & Drift, Creature Behavior, Seasonal Cycle |
| **Persistence** | Save state and continuity | Persistence/Save |
| **UI** | Player-facing information displays | Discovery Surfacing, Diorama Rendering |
| **Audio** | Sound and music systems | Ambient Audio |
| **Progression** | How the player grows over time | Collection Tracking |

*(Economy, Narrative, and Meta categories are not used — this game has no
currency/crafting, no plot, and no tutorial/analytics scope at MVP.)*

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable prototype | Design FIRST |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content OK. | Alpha milestone | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, and content-complete features. | Beta / Release | Design as needed |

*(No separate Vertical Slice tier: per the concept's Scope Tiers table, the
Vertical Slice milestone deepens the same 11 MVP systems — full art/audio polish
and refined ecosystem tuning — rather than introducing new systems.)*

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Content Data — plant/moss/creature type definitions everything else reads from
2. Input Abstraction — unified mouse+touch handling (hard platform requirement)

### Core Layer (depends on foundation)

1. Object Placement — depends on: Input Abstraction, Content Data
2. Ecosystem Simulation — depends on: Content Data

### Feature Layer (depends on core)

1. Tending Input — depends on: Input Abstraction, Object Placement, Ecosystem Simulation
2. Time & Drift — depends on: Ecosystem Simulation
3. Creature Behavior — depends on: Ecosystem Simulation, Object Placement, Time & Drift
4. Persistence/Save — depends on: Content Data, Ecosystem Simulation, Object Placement, Time & Drift

### Presentation Layer (depends on features)

1. Discovery Surfacing — depends on: Ecosystem Simulation, Time & Drift, Creature Behavior
2. Diorama Rendering — depends on: Content Data, Object Placement, Ecosystem Simulation, Creature Behavior, Time & Drift, Discovery Surfacing, Tending Input (soft, added 2026-08-09)
3. Ambient Audio — depends on: Tending Input, Discovery Surfacing, Time & Drift (all soft — degrades gracefully to the base loop alone if any/all are absent)

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Content Data | MVP | Foundation | game-designer | S |
| 2 | Input Abstraction | MVP | Foundation | ux-designer | S |
| 3 | Object Placement | MVP | Core | systems-designer | M |
| 4 | Ecosystem Simulation | MVP | Core | systems-designer | L |
| 5 | Tending Input | MVP | Feature | game-designer | M |
| 6 | Time & Drift | MVP | Feature | systems-designer | M |
| 7 | Creature Behavior | MVP | Feature | systems-designer | M |
| 8 | Persistence/Save | MVP | Feature | game-designer | S |
| 9 | Discovery Surfacing | MVP | Presentation | ux-designer | S |
| 10 | Diorama Rendering | MVP | Presentation | art-director | M |
| 11 | Ambient Audio | MVP | Presentation | audio-director | S |

---

## Circular Dependencies

- **(corrected 2026-08-05, `/review-all-gdds` consistency finding)** One
  genuine implementation-gating cycle exists: **Ecosystem Simulation ↔
  Diorama Rendering**. `ecosystem-simulation.md` upgrades Diorama Rendering
  to a hard blocking dependency (that system is "not implementation-complete
  until `light_level` has some visible representation"), while Diorama
  Rendering depends on Ecosystem Simulation for the state it renders. Not a
  design flaw — Ecosystem Simulation's own interim per-plant visual fallback
  (a shader/modulate-color cue, no new art) satisfies the blocking
  dependency without waiting on Diorama Rendering's full GDD, so the cycle
  doesn't stall implementation — but it is a real cycle, not "none," and
  should be flagged if `/architecture-review` traces this dependency graph.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Ecosystem Simulation | Design | The single biggest risk in the whole project — must feel alive/emergent, not random or static. Five other MVP systems depend on it. | Already partially de-risked by the terrarium-concept prototype (verdict: PROCEED). Continue tuning in the GDD's Formulas/Tuning Knobs sections before implementation. |
| Time & Drift | Design | Open question from the concept doc: how much real-time vs. accelerated time should drift run on — untested. | Prototype both timing models during this system's GDD authoring; pick based on which produces a better "something changed" feeling. |
| Diorama Rendering | Technical | Diorama-realism lighting/materials must run in the Compatibility (WebGL2) renderer, not Forward+ — some techniques may not be available. | Cross-check every rendering technique against `docs/engine-reference/godot/current-best-practices.md` and `breaking-changes.md` before committing to an approach. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 14 |
| Design docs started | 11 |
| Design docs reviewed | 11 |
| Design docs approved | 11 (2 briefly flagged Needs Revision by `/review-all-gdds` round 2, 2026-08-05; Discovery Surfacing briefly flagged NEEDS REVISION, Diorama Rendering briefly flagged MAJOR REVISION NEEDED, and Ambient Audio briefly flagged NEEDS REVISION, each by its own first fresh-session `/design-review` — all 5 fixed same session, re-marked Approved) |
| MVP systems designed | 11/11 — **all 11 MVP GDDs now designed AND reviewed.** Discovery Surfacing, Diorama Rendering, and Ambient Audio have each completed their first fresh-session `/design-review` (all Approved, 2026-08-05) — companion edits were exchanged between Discovery Surfacing and Diorama Rendering (cue concurrency figures, Growth-reveal dependency), plus one to `entities.yaml`. Every MVP GDD has now been through at least one full-mode `/design-review` pass. |
| Alpha systems designed | 0/2 |
| Full Vision systems designed | 0/1 |

---

## Next Steps

- [x] Review and approve this systems enumeration
- [x] Design MVP-tier systems first, in order (use `/design-system [system-name]` or `/map-systems next`)
- [x] Run `/design-review` on each completed GDD
- [ ] Technical Setup: `/create-architecture`, ADRs, test framework (GUT — resolved 2026-08-09, see `.claude/docs/coding-standards.md`) (see `/gate-check technical-setup` output, 2026-08-06, for open items)
- [ ] **Week 1 of Technical Setup**: run the combined Web-export verification spike (`docs/technical-setup/web-export-verification-plan.md`, scoped 2026-08-09) before writing the 3 gated ADRs (Input Abstraction, Persistence/Save, Diorama Rendering all have BLOCKING Open Questions pending this)
- [ ] **Art bible** (`/art-bible`): decision 2026-08-09 — author in parallel with Technical Setup architecture work, not as a gating prerequisite (art-director confirmed READY either way; Diorama Rendering and Discovery Surfacing GDDs already lock most of what it needs as candidate first entries)
- [ ] Run `/gate-check pre-production` once Technical Setup is complete
- [ ] Validate the highest-risk systems (Ecosystem Simulation, Time & Drift) further via `/vertical-slice` before committing to Production
