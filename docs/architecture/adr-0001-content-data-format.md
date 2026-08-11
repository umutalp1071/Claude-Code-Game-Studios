# ADR-0001: Content Data Authoring Format

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (Data / Resource Management) |
| **Knowledge Risk** | MEDIUM — built on stable pre-cutoff `Resource`/`ResourceLoader`/`DirAccess` APIs, but one field-typing detail is governed by a documented Godot 4.7 behavior change |
| **References Consulted** | `docs/engine-reference/godot/current-best-practices.md` (Resources section), `docs/engine-reference/godot/breaking-changes.md` (4.6→4.7 GDScript packed-array entry), `docs/engine-reference/godot/deprecated-apis.md`, `design/gdd/content-data.md` (Core Rule 2's own prior research into this exact risk) |
| **Post-Cutoff APIs Used** | None load-bearing. `Array[String]` typed arrays are used instead of `PackedStringArray`, per `current-best-practices.md`'s general typed-array guidance. Note: none of these fields use a custom property setter, so the 4.6→4.7 packed-array/setter change (godot-specialist review, 2026-08-10) doesn't actually apply to this specific field set — it's cited in `content-data.md` as defensive precedent, not an active hazard here. |
| **Verification Required** | None — `Resource`, `ResourceLoader.load()`, and `DirAccess` directory listing are unchanged across the 4.3→4.7 range per `breaking-changes.md`. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (first ADR — ADR-0001) |
| **Enables** | Content Data implementation; unblocks Ecosystem Simulation, Object Placement, Creature Behavior, Diorama Rendering, Persistence/Save stories, all of which read type definitions through `Content Data.get_definition()` |
| **Blocks** | All Content Data implementation stories, and any story in a dependent system that reads a type definition |
| **Ordering Note** | None |

## Context

### Problem Statement
`content-data.md` defines three type-definition categories (PlantTypeDef,
CreatureTypeDef, ObjectTypeDef) that every downstream MVP system (Ecosystem
Simulation, Object Placement, Creature Behavior, Diorama Rendering,
Persistence/Save) reads through a single `get_definition(id)` query, but the
GDD explicitly defers *how those definitions are authored and loaded* to this
ADR (see its Open Questions: "Should type definitions be authored as native
Godot `.tres` Resource files directly in the editor, or as external data
(JSON/CSV) imported at build time?"). This decision must be made before any
Content Data implementation work, since it determines the on-disk file
format, the loading/validation code shape, and whether a designer without
editor access can tune values.

### Constraints
- Web export target (Compatibility renderer, no native filesystem access
  beyond Godot's own `res://`/`user://` abstractions).
- No build pipeline exists yet for this project beyond Godot's own import
  system — introducing a new build step is not free.
- MVP scope: 3 plant types, 2 creature types, a small number of object
  types — content volume does not justify tooling investment.
- `content-data.md` Core Rule 1 requires a unique string `id` per
  definition, never referenced by file path from gameplay code.
- `content-data.md`'s `definition_validity` check must run before a
  definition is admitted to the in-memory registry (load-time gate).
- `docs/architecture/architecture.md`'s already-drafted API Boundaries
  section sketched `Content Data.get_definition(id) -> Resource` — any
  format choice that can't return a `Resource` would require reworking
  that boundary.

### Requirements
- Must support typed fields per `content-data.md`'s field tables
  (`moisture_tolerance_min/max`, `growth_rate`, `visual_stages: Array[String]`,
  etc.) with load-time validation (`definition_validity`).
- Must produce a deterministic, ordinally-sorted list of definition file
  paths for registry population (`content-data.md`'s own determinism
  requirement, to keep load order reproducible for tests).
- Must not require a designer to touch code to add or tune a definition.
- Must work under the Web/Compatibility export target with no filesystem
  access beyond `res://`.

## Decision

Content Data type definitions are authored as **native Godot `.tres`
Resource files**, using three custom `Resource` subclasses:
`PlantTypeDef`, `CreatureTypeDef`, `ObjectTypeDef`, each declaring typed
`@export` fields matching `content-data.md`'s per-type field tables
(e.g. `@export var moisture_tolerance_min: float`, `@export var
visual_stages: Array[String]` — not `PackedStringArray`, per the Engine
Compatibility note above).

Each subclass declares `class_name` (e.g. `class_name PlantTypeDef`) so it
appears by name in the editor's "New Resource" dialog — without it, a
designer would have to browse to the script file directly, which works
but defeats the point of a friction-free authoring workflow.

Definitions live one file per instance, under:
```
res://data/content/plants/*.tres
res://data/content/creatures/*.tres
res://data/content/objects/*.tres
```

At startup, the Content Data autoload (`_ready()`):
1. For each of the three category directories, lists `.tres` files via
   `DirAccess`, collects their `res://` paths, and sorts the list
   ordinally (matches `content-data.md`'s explicit determinism
   requirement; never resolves through `uid://`, which sorts
   unpredictably relative to file naming).
2. Loads each path with `ResourceLoader.load()`.
3. Runs `definition_validity()` (per `content-data.md`) against the
   loaded Resource; a failing definition is excluded from the registry
   and logged via `push_warning()`, never loaded.
4. Valid definitions are inserted into an in-memory `Dictionary[String,
   Resource]` keyed by the definition's own `id` field (never by file
   path — satisfies Core Rule 1).

No parser, no external file format, no build step. Godot's own inspector
is the authoring tool; adding a new plant/creature/object type means
creating a new `.tres` file via the editor's "New Resource" flow, no
code change required.

### Architecture Diagram
```
res://data/content/{plants,creatures,objects}/*.tres
              │  DirAccess scan (sorted, ordinal)
              ▼
      ResourceLoader.load() per path
              │
              ▼
      definition_validity() gate ──✗──> push_warning(), excluded
              │ ✓
              ▼
   Dictionary[String, Resource]  (Content Data autoload's in-memory registry)
              │
              ▼
   get_definition(id) -> Resource | null   (public API, unchanged from architecture.md's draft)
```

### Key Interfaces
```gdscript
# Content Data (autoload) — Foundation
func get_definition(id: String) -> Resource  # PlantTypeDef/CreatureTypeDef/ObjectTypeDef, or null
# Invariant: registry fully loaded before any other system initializes.
# Guarantee: returned Resource is read-only by convention (content-data.md Core Rule 2).

# PlantTypeDef extends Resource
class_name PlantTypeDef  # required for the type to appear by name in the
                          # editor's "New Resource" dialog, not just by
                          # browsing to the script file
@export var id: String
@export var display_name: String
@export var moisture_tolerance_min: float
@export var moisture_tolerance_max: float
@export var light_tolerance_min: float
@export var light_tolerance_max: float
@export var growth_rate: int
@export var decay_rate: int
@export var growth_pattern: String  # enum-like: "carpet" | "clump" | "climb"
@export var visual_stages: Array[String]  # not PackedStringArray — see Engine Compatibility

# CreatureTypeDef extends Resource, ObjectTypeDef extends Resource follow the
# same pattern — typed @export fields matching content-data.md's field tables.
```

## Alternatives Considered

### Alternative 1: External JSON/CSV
- **Description**: Definitions authored as plain JSON or CSV files,
  parsed at load time into `Dictionary` instances.
- **Pros**: Editable in any text editor or spreadsheet without opening
  Godot; more familiar to non-technical designers or external tools.
- **Cons**: Requires hand-rolled parsing and validation code (Godot has
  no built-in JSON schema/typing for this); no compile-time field typing;
  no inspector UI for designers; would require reworking
  `architecture.md`'s already-drafted `get_definition() -> Resource` API
  boundary since JSON parses to `Dictionary`, not `Resource`.
- **Rejection Reason**: More code to write and maintain (a parser and a
  validator this project doesn't need) for a benefit — non-editor tuning
  — that no stakeholder has asked for at MVP scope. Native `Resource`
  loading is stdlib; JSON parsing plus validation is code this project
  would have to write and keep correct itself.

### Alternative 2: Hybrid — `.tres` source, JSON export
- **Description**: Author in `.tres` (inspector-editable, typed) and add
  a build-time export step that also emits JSON, for external tooling or
  analytics consumers.
- **Pros**: Gets inspector editing and typed fields, plus a
  tooling-friendly format for anything that can't load `.tres`.
- **Cons**: A second format to keep in sync, a build step that doesn't
  exist yet, and — critically — no consumer for the JSON export exists
  anywhere in this project's 11 MVP GDDs or architecture.md today.
- **Rejection Reason**: Speculative. Nothing in this project currently
  needs a non-Godot consumer of Content Data. Add this only if a real
  external tool or pipeline needs it later — the `.tres` files remain the
  source of truth either way, so this is a non-breaking future addition,
  not a decision that needs to be made now.

## Consequences

### Positive
- Zero parsing/validation-framework code to write — `ResourceLoader` and
  the inspector are engine-native.
- Typed fields (`@export var growth_rate: int`) get compile-time type
  checking and inspector-side range/enum editing for free.
- No rework needed on `architecture.md`'s already-drafted
  `get_definition() -> Resource` API boundary.
- Matches this project's existing `technical-preferences.md` engine-first
  bias (GDScript/Godot-native patterns over custom infrastructure).

### Negative
- Tuning values requires opening the Godot editor — no external
  spreadsheet/text-editor workflow for designers without editor access.
  Not a cost at current team scale (this is a solo/small-team project per
  `game-concept.md`), but would need revisiting if non-technical
  contributors join.
- Adding a new definition category (a 4th type beyond Plant/Creature/
  Object) means writing a new `Resource` subclass, not just adding rows
  to a schema-less file.

### Risks
- **Risk**: A `.tres` file's `id` field could accidentally duplicate
  another definition's `id` within the same category, silently
  overwriting one registry entry with another at load time (dictionary
  key collision).
  **Mitigation**: `definition_validity()` (already specified in
  `content-data.md`) should include a duplicate-`id` check within each
  category; `push_warning()` on collision, first-loaded (by the sorted
  scan order) wins. Flag as an explicit addition to
  `content-data.md`'s validity check if not already covered — confirmed
  covered in the GDD's existing edge cases (see GDD Requirements table
  below).
- **Risk**: `Array[String]` typed-array fields are edited via a
  slightly less convenient inspector widget than a flat text field.
  **Mitigation**: Accepted — `Array[String]` is still the correct choice
  per general typed-array guidance, independent of the setter-behavior
  question.

**`godot-specialist` review (2026-08-10)**: Decision confirmed idiomatic
for Godot 4.7.1, no blocking issues. One gap caught and fixed in this
draft: custom `Resource` subclasses need `class_name` to appear by name
in the editor's "New Resource" dialog — without it the claimed
friction-free authoring workflow would be technically true but clunkier
in practice (Key Interfaces now includes `class_name` on each subclass).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| content-data.md | Open Questions: "Authoring format — `.tres` vs JSON/CSV" | Resolved: native `.tres` Resource files, per the Decision above. |
| content-data.md | Core Rule 1: unique string `id`, never referenced by file path from gameplay code | Registry is keyed by `id` in the in-memory `Dictionary`, not by path; `get_definition(id)` is the only lookup surface. |
| content-data.md | Core Rule 2: `visual_stages`/`required_ids` implemented as `Array[String]`, not `PackedStringArray` | Directly adopted into the Key Interfaces field declarations. |
| content-data.md | `definition_validity` — must run before a definition is admitted to the registry | Load sequence step 3 runs this gate synchronously at `_ready()`, before any definition enters the registry. |
| content-data.md | Deterministic, ordinally-sorted `res://` path collection; never resolve via `uid://` | Load sequence step 1 scans and sorts paths ordinally before loading. |
| architecture.md | `get_definition(id) -> Resource`, "registry fully loaded before any other system initializes" | Adopted unchanged — this ADR confirms the API boundary rather than requiring a rework. |

## Performance Implications
- **CPU**: Negligible — a one-time directory scan + `ResourceLoader.load()`
  per definition at startup (single digits of files at MVP scope: 3
  plants + 2 creatures + a handful of objects). No per-frame cost.
- **Memory**: Each loaded `Resource` stays resident for the game's
  lifetime (shared, read-only, never duplicated per instance) — trivial
  at MVP content volume.
- **Load Time**: Sub-frame at MVP scale; not measured as a distinct
  budget item.
- **Network**: N/A — bundled in the Web export, not fetched separately.

## Migration Plan
N/A — no existing Content Data implementation to migrate from. This is
the initial decision.

## Validation Criteria
- A unit test (per `coding-standards.md`'s dependency-injection
  requirement) constructs `PlantTypeDef`/`CreatureTypeDef`/`ObjectTypeDef`
  instances directly (not via file load) and confirms
  `definition_validity()` accepts valid data and rejects each documented
  invalid case from `content-data.md`'s Edge Cases.
- An integration or smoke test confirms the Content Data autoload's
  `_ready()` populates the registry from the real `res://data/content/`
  directories in sorted order, and that `get_definition()` returns `null`
  on an unknown `id`.

## Related Decisions
- `docs/architecture/architecture.md` — API Boundaries section (Content
  Data's `get_definition()` signature, adopted unchanged by this ADR).
- Depends on / interacts with the still-unwritten cross-cutting
  signal/init-order ADR (Content Data must finish loading before any
  other system initializes — already noted in architecture.md's Init
  Order sequence).
