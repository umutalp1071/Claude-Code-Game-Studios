# Epic: Ecosystem Simulation

> **Layer**: Core
> **GDD**: design/gdd/ecosystem-simulation.md
> **Architecture Module**: Ecosystem Simulation (autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories ecosystem-simulation`

## Overview

Ecosystem Simulation is the rule-based system governing moisture, plant/moss growth
and decay, and creature spawn/departure — driven by fields Content Data defines and
advanced by Time & Drift's ticks. Per `systems-index.md`'s own High-Risk Systems
table, this is **the single biggest risk in the whole project**: it implements
Pillars 1–4 directly and every other MVP system's design hinges on it feeling alive
rather than random or static. Per ADR-0004, it's a single autoload holding jar-wide
scalars plus two `Dictionary` registries (`_plants`, `_creatures`) of `RefCounted`
state classes; every formula lives in a separate non-autoload `EcosystemFormulas`
script as pure `static func`s; the system owns a private `RandomNumberGenerator`
internally and never calls outward to any other system. The vertical slice
(`prototypes/terrarium-vertical-slice/`) already exercised this system's full
mechanical implementation with zero architectural rework required — this epic is
about the real, production-quality implementation from scratch, using that slice as
reference only, never migrated.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0004: Ecosystem Simulation Tick Architecture & Testable-RNG Injection | Autoload + two `Dictionary` registries; pure `EcosystemFormulas` script; private internal RNG, roll generated internally then passed to a pure gate function | LOW |
| ADR-0002 (companion edit) | Adds `restore()`, `watering_applied` signal, `get_watering_amount()`, `get_plant_ids()`/`get_creature_ids()`, `get_was_present_during_batch()`, `get_detail_event_fired()` | — |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-ecosystem-simulation-001 | Formulas — jar moisture (watering + decay), light triangle wave, three-state plant growth, spawn/departure debounce, detail-event gate | ADR-0004 ✅ |
| TR-ecosystem-simulation-002 | `should_trigger_detail(roll, p_detail)` must be pure/DI'd | ADR-0004 ✅ |
| TR-ecosystem-simulation-003 | Core Rule 11 — plants evaluated before creatures, every tick | ADR-0004 ✅ |
| TR-ecosystem-simulation-004 | Core Rule 12/13 — `last_known_position`/`was_present_during_batch` | ADR-0004 ✅ |
| TR-ecosystem-simulation-005 | Pure state owner — exposes state to 5 downstream systems, calls into none | ADR-0004 ✅ |

## Dependencies

- **Content Data** (hard, Foundation) — `PlantTypeDef`/`CreatureTypeDef` fields (`moisture_tolerance`, `light_tolerance`, `growth_rate`, `decay_rate`, `spawn_conditions`)

Downstream dependents (all hard, no fallback path): Tending Input, Time & Drift,
Creature Behavior, Persistence/Save, Discovery Surfacing, Diorama Rendering, Ambient
Audio — this system has the widest fan-out of any MVP system.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ecosystem-simulation.md` are verified
- All Logic and Integration stories have passing test files in `tests/` — given this
  system's risk profile, formula-level unit tests against the GDD's own worked examples
  (moisture decay, light triangle wave, growth/decay boundary ACs, detail-event gate
  boundary values) are non-negotiable, not optional coverage
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
  (N/A here — no visual surface of its own; rendered by Diorama Rendering)

## Next Step

Run `/create-stories ecosystem-simulation` to break this epic into implementable stories.
