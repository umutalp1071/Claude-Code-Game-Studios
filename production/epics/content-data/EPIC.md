# Epic: Content Data

> **Layer**: Foundation
> **GDD**: design/gdd/content-data.md
> **Architecture Module**: Content Data (autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories content-data`

## Overview

Content Data is the foundational registry of plant/moss, creature, and tendable-object
type definitions — moisture/light tolerance bands, growth/decay rates, movement speed,
footprint size, visual references — authored as external, designer-editable `.tres`
Resource files rather than hardcoded values. It has zero upstream dependencies and is
the sole source of truth every other MVP system (Ecosystem Simulation, Object Placement,
Creature Behavior, Persistence/Save, Diorama Rendering) reads type data from. Per
ADR-0001, the autoload's `_ready()` scans `res://data/content/{plants,creatures,objects}/`,
sorts paths ordinally, loads each via `ResourceLoader.load()`, runs `definition_validity()`
before registry admission, and keys the in-memory registry by each definition's own `id`
— never by file path. The registry must be fully loaded before any other system
initializes.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0001: Content Data Authoring Format | Native `.tres` Resource subclasses (`PlantTypeDef`/`CreatureTypeDef`/`ObjectTypeDef`), load-time `definition_validity` + iterative `spawn_reference_validity` fixpoint, registry keyed by `id` | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-content-data-001 | Authoring format decision — `.tres` vs JSON/CSV | ADR-0001 ✅ |
| TR-content-data-002 | Core Rule 1 — unique string `id`, never referenced by file path from gameplay code | ADR-0001 ✅ |
| TR-content-data-003 | Core Rule 2 — `visual_stages`/`required_ids` implemented as `Array[String]`, not `PackedStringArray` | ADR-0001 ✅ |
| TR-content-data-004 | `definition_validity` must run before a definition is admitted to the registry | ADR-0001 ✅ |
| TR-content-data-005 | Deterministic, ordinally-sorted `res://` path collection; never resolve via `uid://` | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/content-data.md` are verified (ACs 1–6, including
  the boundary-pair ACs 2a/2b/2c/3a/3b/3c/3d/4a/4b/4c/4d/4e and the Warning-Logging
  Assertions table, gated on the project's installed GUT release confirming ≥9.7.0)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
  (N/A here — Content Data has no visual/UI surface of its own)

## Next Step

Run `/create-stories content-data` to break this epic into implementable stories.
