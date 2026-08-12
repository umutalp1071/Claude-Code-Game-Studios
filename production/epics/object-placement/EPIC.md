# Epic: Object Placement

> **Layer**: Core
> **GDD**: design/gdd/object-placement.md
> **Architecture Module**: Object Placement (autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories object-placement`

## Overview

Object Placement lets the player pick up a repositionable object (a single rock at
MVP) and drag it to a new position within the jar, using the drag gestures Input
Abstraction provides. It tracks which object is currently held, constrains valid drop
positions to inside the jar and clear of other objects' footprints, and commits the
new position on release — the tactile, direct-manipulation half of tending (Pillar 3:
Care, Not Control). Per ADR-0003, it's a single autoload holding a `Dictionary`
registry (`object_id` → `ObjectState`, a `RefCounted` value) with zero scene-tree
nodes of its own; the four validity formulas (`footprint_hit`, `in_bounds`,
`no_overlap`, drag-follow) live in a separate non-autoload `ObjectPlacementMath`
script for clean unit-test isolation. ADR-0011 companion-edits in
`is_within_any_footprint()` so Tending Input can perform footprint-exclusion checks
without a second read path into Content Data.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0003: 2D Placement/Collision Approach | Autoload + `Dictionary` registry of `ObjectState` (RefCounted); pure-formula `ObjectPlacementMath` script; no `Area2D`/physics engine | LOW |
| ADR-0011 (companion edit): Tending Input — Watering Router | Adds `is_within_any_footprint()` + `ObjectState.footprint_size` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-object-placement-001 | Formulas — footprint hit-test, in-bounds ellipse, pairwise overlap, drag-follow position | ADR-0003 ✅ |
| TR-object-placement-002 | No `Area2D`/`CollisionShape2D`/physics engine | ADR-0003 ✅ |
| TR-object-placement-003 | `grab_offset` preserved for the duration of a drag | ADR-0003 ✅ |
| TR-object-placement-004 | `ObjectTypeDef.footprint_size`/`repositionable` fields consumption | ADR-0003 ✅ |
| TR-object-placement-005 | `get_position(object_id)`/`is_held(object_id)` API boundaries | ADR-0003 ✅ |
| TR-object-placement-006 | Diorama Rendering reads committed/live `visual_pos`, HELD state, `drag_end` outcome | ADR-0003 ✅ |

## Dependencies

- **Input Abstraction** (hard, Foundation) — `drag_start`/`drag_move`/`drag_end`/`tap` + `position`/`delta`/`canceled`
- **Content Data** (hard, Foundation) — `ObjectTypeDef.repositionable`, `footprint_size`

**⚠️ Inherited gate**: this GDD's own header notes it is separately BLOCKED pending
the same empirical Web-export verification Input Abstraction's epic carries
(TR-input-abstraction-006) — Object Placement's `canceled`-flag revert behavior
depends on that unverified contract. Scope stories accordingly (see the Input
Abstraction epic's Story Guidance).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/object-placement.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
  (N/A here — Object Placement has no visual surface of its own; rendered by Diorama Rendering)

## Next Step

Run `/create-stories object-placement` to break this epic into implementable stories.
