# Content Data

> **Status**: Approved (2026-08-04 — see `design/gdd/reviews/content-data-review-log.md`)
> **Author**: user + game-designer
> **Last Updated**: 2026-08-04
> **Implements Pillar**: Pillar 4 (Every Detail Rewards Attention) — indirectly, by giving the simulation enough type variety to produce noticeable small details
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Lean mode

## Overview

Content Data is the foundational set of data resources that define every plant/moss
type, creature type, and tendable object in the terrarium — moisture tolerance,
growth rate, visual reference, and behavior parameters — as external, designer-editable
definitions rather than hardcoded values. It exists so that Ecosystem Simulation,
Object Placement, Creature Behavior, and Diorama Rendering all read from one shared
source of truth for "what a Moss Patch is" or "what a Snail does," instead of each
system duplicating those facts independently. Players never interact with Content
Data directly — it's the invisible layer that makes the MVP's 3 plant/moss types
and 2 creature types possible to define, tune, and expand without touching code.

## Player Fantasy

Content Data has no direct player fantasy — it is pure infrastructure the player
never sees or touches. What the player *feels* is downstream: variety and
believability. Because Moss Patch, Snail, and every other type live as distinct,
tunable definitions rather than copy-pasted logic, Ecosystem Simulation, Object
Placement, and Creature Behavior can each treat every type consistently —
supporting **Pillar 4 (Every Detail Rewards Attention)** by ensuring each type
actually behaves distinctly enough to be worth noticing, rather than blurring
into a generic "plant" or "bug." If this system were missing or inconsistent,
the player-facing symptom would be types that don't read as distinct from each
other — the opposite of what the pillar demands.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules. Review manually before
production.)*

**Correction (2026-08-03 re-review, `game-designer`):** the claim above
that Content Data *ensures* each type "behaves distinctly enough to be
worth noticing" overstates what a data-holding system can guarantee —
holding a field is not the same as a consumer reading it. This is not
hypothetical: `pause_duration_min/max` is fully defined, validated, and
pinned in this document's own fixture data specifically to give Snail and
Moth a second Pillar 4 axis, but `creature-behavior.md` still specifies a
single global `random_uniform(2.0, 5.0)` pause range and does not yet
consume this field (tracked in Open Questions). At the current MVP scope
(2 creature types, each with a distinct species/`visual_ref`), the
distinctness Pillar 4 requires is still delivered — by species identity
and `movement_speed` alone — so this gap is not player-visible today. But
the field's own Pillar-4 justification remains aspirational, not yet
shipped, until Creature Behavior's companion edit lands.

## Detailed Design

### Core Rules

1. Every plant/moss, creature, and tendable object type is defined as a distinct,
   statically-loaded type definition with a unique string `id` — never referenced
   by file path from gameplay code.
2. Type definitions are **read-only at runtime** — by convention, not by a
   runtime-enforced guard. Nothing in gameplay should mutate a definition;
   only per-instance state (a specific moss patch's current growth stage, a
   specific creature's position) changes, and that state lives in the
   systems that own it (Ecosystem Simulation, Object Placement), not here.
   Godot 4.7 has no compile-time immutability for Resource instance
   properties. An inline property setter (`@export var foo: type = default:
   set(v): ...`) *can* intercept whole-property reassignment to a real
   `@export var` field without breaking `.tres` inspector editing — but no
   setter mechanism, inline or `_set()` override, fires on in-place mutation
   of an Array/Dictionary already stored in a property (e.g.
   `def.visual_stages.append(x)`) — only whole-property reassignment
   triggers a setter. `visual_stages` and `required_ids` are exactly the
   fields most likely to be mutated this way by accident, so a setter guard
   would catch none of the realistic violation cases. Not worth that cost at
   MVP scope; a violation would be caught by code review, not an automated
   test. **Type pinned 2026-08-04 `/design-review`** (`godot-specialist`
   finding): this conclusion holds only if `visual_stages`/`required_ids`
   are implemented as typed `Array[String]`, not `PackedStringArray` — per
   this project's own `breaking-changes.md` 4.6→4.7 entry, packed-array
   element assignment stopped calling the whole-property setter only as of
   4.7 (it did fire pre-4.7). Implement both fields as `Array[String]` so
   this rule's justification stays correct regardless of that history; do
   not "optimize" either field to `PackedStringArray` later without
   re-checking this rule.
3. Three definition categories exist for MVP:
   - **PlantTypeDef** — moss/plant types (3 for MVP)
   - **CreatureTypeDef** — creature types (2 for MVP)
   - **ObjectTypeDef** — tendable/repositionable objects (e.g., rock)
4. **PlantTypeDef** fields: `id`, `display_name`, `moisture_tolerance_min/max`,
   `growth_rate`, `decay_rate`, `growth_pattern` (enum: `carpet` / `clump` /
   `climb` — the plant's spread/silhouette behavior, so the MVP's 3 plant
   types occupy distinct visual niches rather than varying on moisture band
   alone; intended meaning per value — `carpet`: spreads flat and low
   across the substrate, widening its footprint as `growth_stage` rises;
   `clump`: grows as a dense, rounded mass in place, gaining height/bulk
   rather than spreading; `climb`: grows vertically up the glass or another
   object, gaining height rather than footprint. **This is design intent
   only — the actual per-value visual/behavioral implementation is owned by
   the unauthored Diorama Rendering system; this GDD only defines the enum
   and its intended meaning, not its rendering.** See Open Questions.),
   `visual_stages` (ordered list of visual refs, index `0` to
   `max_stage`, that growth climbs up and decay retreats back down through
   — the same single sequence in both directions, see Core Rule 8).
   `visual_stages` must contain at
   least 2 entries — Ecosystem Simulation derives `max_stage =
   visual_stages.length - 1` directly from this list (no separate
   `max_stage` field exists anywhere) and its own Formulas section requires
   `max_stage ≥ 1`; a single-entry list would make growth structurally
   impossible. Enforced at load (see Formulas/Edge Cases).
   **`light_tolerance_min/max`** (added 2026-08-03, `/design-review` on
   `ecosystem-simulation.md`): a second viable-range field, same shape and
   validation pattern as `moisture_tolerance_min/max` but checked against
   Ecosystem Simulation's new `light_level` variable (see that GDD) instead
   of `jar_moisture`. Added to fix a real design defect: with only
   `moisture_tolerance` gating growth, the 3 MVP plant types' bands
   mathematically collapsed into a shared lockstep zone
   (`moisture ∈ [65,75]` put all three in GROWING at once, the opposite of
   the "possibility-space depth" Core Rule 8 requires) — see
   `ecosystem-simulation.md`'s review log. `light_level` is not
   player-controllable (no watering-equivalent action exists for it), so a
   second independent, staggered tolerance band on it gives the simulation
   real depth rather than just subdividing the one dial the player already
   directly sets.
5. **CreatureTypeDef** fields: `id`, `display_name`, `spawn_conditions` (a
   boolean expression over required plant-type growth stage(s) and/or other
   creature-type id(s)/state — e.g. a plant reaching a growth threshold, or
   another creature already being PRESENT; how this expression is authored
   and evaluated is an implementation concern owned by Ecosystem Simulation,
   not specified here), `required_ids` (array of string ids — every
   plant-type and/or creature-type `id` that `spawn_conditions` references,
   authored alongside it; this is the sole input `spawn_reference_validity`
   checks against, so Content Data never has to parse the expression
   itself), `movement_speed`, `pause_duration_min/max` (seconds, the
   creature's between-destination rest range — see the Pillar 4 rationale
   below), `visual_ref`.
   (No `behavior_pattern_id` — Creature Behavior's MVP design is a single
   shared wandering *algorithm* for every creature type, so a per-type
   behavior-branch reference would be an unused field; that decision stands.
   `pause_duration_min/max` is different in kind, and new as of this
   2026-08-03 re-review: it isn't a behavior branch, it's a per-type
   parameter to the one shared algorithm — a continuous, per-type knob
   giving Snail and Moth a second axis of difference beyond
   `movement_speed` (Pillar 4: Every Detail Rewards Attention), rather than
   the same wander loop at two speeds.
   **Correction (2026-08-03, round-8 re-review, `game-designer` +
   `creative-director`):** an earlier draft of this note called this field
   "the categorical differentiator" that "closes the gap" `growth_pattern`
   opened for plants — that overstated it. `growth_pattern` is categorical
   (a plant is carpet, clump, or climb — a silhouette difference, legible
   at a glance); `pause_duration_min/max` stacks a second continuous number
   onto the same tempo dimension `movement_speed` already occupies, which
   is a narrower, easier-to-miss signal, not an equivalent fix. The field
   is still worth keeping (cheap, additive, harmless), but it narrows the
   plant/creature variety asymmetry rather than closing it — see Open
   Questions for the required companion edit to `creature-behavior.md`,
   which currently uses one global pause range for every creature type, and
   for whether a categorical/visual differentiator would serve creatures
   better. Concrete per-type values are owned and tuned by Creature
   Behavior, same pattern as `movement_speed` — this GDD only defines that
   the field exists and is load-time validated.)
6. **ObjectTypeDef** fields: `id`, `display_name`, `visual_ref`, `repositionable`
   (bool), `footprint_size` (float, radius in jar-space units — for placement collision).
7. All definitions load once at game start into an in-memory registry keyed by
   `id`; every other system queries this registry — none holds its own copy of
   definition data. Load order is established by collecting every definition
   file's path and sorting that list lexicographically (e.g. GDScript's
   `Array.sort()` on the collected `String` paths) before loading — directory
   enumeration order is filesystem-dependent and must not be relied on
   directly. This sorted order is what makes duplicate-`id` tie-breaking
   (Edge Cases) and `spawn_reference_validity`'s second pass (Formulas)
   deterministic and reproducible. The collected list must be `res://`
   definition-file paths only, filtered to whatever extension the pending
   authoring-format decision picks (see Open Questions). **Correction
   (2026-08-03 re-review, `godot-specialist`, WebSearch-verified):** the
   originally-stated risk of `.uid`/`.import` sidecar files polluting this
   list was overstated for the likely `.tres`-only case — `.import`
   sidecars are only ever generated for imported binary assets (textures,
   audio, meshes), never for `.tres`/`.tscn`, and `.uid` sidecars are only
   generated for formats with no in-file metadata slot (`.gd` scripts,
   `.gdshader` shaders); `.tres`/`.tscn` embed their `uid=` directly in
   their own resource header instead. If the content-data directory
   contains only `.tres` definition files, no sidecar filtering is actually
   needed — this note is retained as defensive guidance in case a future
   authoring format mixes in script-based or imported-asset files, not as a
   currently-active risk. Paths must still not be resolved through `uid://`
   (which sorts unpredictably relative to file naming) — that guidance
   holds regardless. Note the sort is ordinal/
   case-sensitive (e.g. `Flower.tres` sorts before `moss.tres`) — a
   content-authoring naming convention should account for this.
8. **Decay never removes an instance or destroys data — it moves the same
   `growth_stage` index back toward `0`, never past it.** Per Ecosystem
   Simulation's formula (`growth_stage' = clamp(growth_stage +
   (in_range ? growth_rate : -decay_rate), 0, max_stage)`, see
   `ecosystem-simulation.md`), growth and decay are the **same index moving
   in opposite directions through the same `visual_stages` list** — growth
   increments toward `max_stage`, decay decrements back toward `0`. A
   decaying instance retreats through earlier, less-mature-looking stages of
   the same sequence it grew through; it does not jump to a separate
   "withered" asset outside that sequence, and it is never removed, hidden,
   or excluded from queries while decaying. `0` (DORMANT, per Ecosystem
   Simulation's States table) is not a fail state — the instance is held
   there, still loaded, queryable, and rendered, until moisture returns to
   range and growth resumes. This is a hard rule, not a tuning knob: per the
   concept doc's Anti-Pillar (NOT punishing) and Pillar 2 (Nothing Is Ever
   Finished, Nothing Is Ever Late), decay must always read as the plant
   "retreating" or "resting," never as loss, destruction, or a broken/end
   state. Each type's `visual_stages` sequence must therefore be authored so
   *every* stage — including `0` — reads as a legitimate, non-punishing
   point in the plant's life, since decay can revisit any of them.
   **(2026-08-03 re-review — corrected)**: an earlier draft of this rule
   described decay as continuing *forward* into dedicated late-stage "decay"
   entries, treating the index as monotonic. That contradicted Ecosystem
   Simulation's already-locked, tested, and tuned formula/States table/ACs,
   which regress the index instead. This rule is corrected to match the
   canonical (regress-toward-`0`) model rather than requiring Ecosystem
   Simulation to change.

### States and Transitions

N/A — Content Data holds no mutable state or lifecycle of its own. It is a
static, read-only registry. State machines belong to the systems that consume
it (Ecosystem Simulation for growth/decay state, Object Placement for position
state).

### Interactions with Other Systems

| System | Reads from Content Data | Data flow |
|---|---|---|
| Ecosystem Simulation | PlantTypeDef, CreatureTypeDef | `moisture_tolerance`, `growth_rate`, `decay_rate`, `spawn_conditions` → drives simulation math |
| Object Placement | ObjectTypeDef | `repositionable`, `footprint_size` → drives what can be dragged and where |
| Creature Behavior | CreatureTypeDef | `movement_speed`, `pause_duration_min/max` → drives per-creature movement and wander-pause cadence |
| Diorama Rendering | PlantTypeDef, CreatureTypeDef, ObjectTypeDef | `visual_stages`/`visual_ref` → drives what asset renders per growth stage |

Content Data has no upstream dependencies and produces no output back to any
system — it is a pure source, never a sink.

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set. Review manually before production.)*

## Formulas

Content Data performs no gameplay calculations itself (growth/decay/spawn math
lives in Ecosystem Simulation). The one thing that does belong here is a
load-time validity check, since malformed data would silently break downstream
formulas.

The `definition_validity` check is defined as:

`valid = (0 ≤ moisture_tolerance_min < moisture_tolerance_max ≤ 100)
AND (moisture_tolerance_max − moisture_tolerance_min ≥ BAND_MIN_WIDTH)
AND (0 ≤ light_tolerance_min < light_tolerance_max ≤ 100)
AND (light_tolerance_max − light_tolerance_min ≥ LIGHT_BAND_MIN_WIDTH)
AND (0.0 < footprint_size ≤ FOOTPRINT_MAX)
AND (0.0 ≤ movement_speed ≤ MOVEMENT_SPEED_MAX)
AND (0.0 ≤ pause_duration_min ≤ pause_duration_max ≤ PAUSE_DURATION_MAX)
AND (0 ≤ growth_rate ≤ RATE_MAX)
AND (0 ≤ decay_rate ≤ RATE_MAX)
AND (growth_pattern ∈ {carpet, clump, climb})`

**Per-type scoping (2026-08-03 re-review):** this formula is written as one
shared expression because the range-check *shape* (bound comparisons) is
identical across fields, not because a single definition is checked against
all seven clauses at once. `footprint_size` only exists on `ObjectTypeDef`,
`movement_speed`/`pause_duration_min/max` only on `CreatureTypeDef`, and the
moisture/light/growth/decay/`growth_pattern` clauses only on `PlantTypeDef`
(Core Rules 4–6). Each definition is checked only against the clauses whose
fields exist on its own type — a CreatureTypeDef is never evaluated against
`footprint_size`, an ObjectTypeDef never against `movement_speed`, and so
on. Clauses for fields absent from a given type are not evaluated, not
treated as vacuously true or false.

**`light_tolerance_min/max` added (2026-08-03, `/design-review` on
`ecosystem-simulation.md`):** identical shape and rationale to
`moisture_tolerance_min/max`'s own clause — same domain bound (`0–100`),
same minimum band width pattern (via the new `LIGHT_BAND_MIN_WIDTH`
constant, value 15, mirroring `BAND_MIN_WIDTH`). See Core Rule 4 for why
this field exists.

**`display_name` and `id` are deliberately outside this check (2026-08-03
round-8 re-review, `systems-designer`):** `id` uniqueness is handled by its
own dedicated Edge Cases check (a structural registry concern, not a
per-field range check), and `visual_stages`/`visual_ref` have their own
dedicated length/emptiness checks (also Edge Cases) — both intentional,
covered elsewhere. `display_name`, however, has no check anywhere: a null
or empty value loads silently on any type. Left unfixed here deliberately —
no consumer of `display_name` is documented on any system yet, so a
validity gate for it would be guarding a field nothing currently reads;
add one if and when a real consumer (e.g. a debug/dev UI) needs it
non-empty.

This replaces the earlier looser check (`min < max AND footprint > 0 AND
speed >= 0`), which passed degenerate values the Variables table already
claimed to forbid — e.g. `min=-500, max=9999` or `footprint_size=1e9` — and
independently allowed a moisture band as narrow as 0.1 units despite the
Tuning Knobs section requiring ≥15 for the anti-pillar's sake. The formula
now enforces exactly what the ranges below declare.

**`growth_rate`/`decay_rate` and `growth_pattern` added (2026-08-03
re-review):** these fields existed in Core Rule 4 and were fed directly
into Ecosystem Simulation's per-tick formula (which assumes both rates are
`int, ≥0`), but had no load-time gate at all — the exact "malformed data
silently breaks downstream formulas" scenario this check exists to prevent.
A negative `growth_rate` would invert growth (shrinking a plant under good
conditions); an unbounded `decay_rate` (e.g. `99999`) would zero a plant's
`growth_stage` in a single tick, violating Core Rule 8's hard rule that
decay is always gradual and never reads as sudden loss. `growth_pattern`
similarly had no membership check — a typo'd string would have loaded
silently and reached Diorama Rendering unchecked.

**Moisture is an int on a 0–100 scale, not a 0.0–1.0 float** — matching
`jar_moisture`'s declared type/range in Ecosystem Simulation, which compares
directly against these bounds (`jar_moisture ∈ [moisture_tolerance_min,
moisture_tolerance_max]`) with no normalization step anywhere. An earlier
draft of this formula used a 0.0–1.0 float scale; under that version, the
registry's actual MVP plant data (moisture bands in the 40–90 range) would
have failed this validity check entirely and been rejected at load,
silently shipping the MVP with zero loadable plants. Scale corrected here to
match the one already locked in by `ecosystem-simulation.md` and the
registry.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| moisture_tolerance_min/max | — | int | 0–100 | plant's viable moisture band, same scale as `jar_moisture` |
| BAND_MIN_WIDTH | — | int | constant, 15 | minimum viable moisture band width — narrower reads as a plant that dies from any moisture flicker (violates Anti-Pillar: NOT punishing) |
| light_tolerance_min/max | — | int | 0–100 | plant's viable light band, same 0–100 scale as `light_level` (Ecosystem Simulation) — an independent second axis, not player-controllable |
| LIGHT_BAND_MIN_WIDTH | — | int | constant, 15 | minimum viable light band width, same rationale as `BAND_MIN_WIDTH` |
| footprint_size | — | float | >0.0, ≤ FOOTPRINT_MAX | placement collision radius, jar-space units |
| FOOTPRINT_MAX | — | float | constant, 20.0 | ~1/3 of the jar floor's shorter radius (`ry=60` in Object Placement's worked example). Derived from that fixed scene geometry, not independently tunable — if Object Placement's jar-floor `ry` ever changes, this constant must be re-derived alongside it. Beyond this a single object would dominate collision space. |
| movement_speed | — | float | 0.0–MOVEMENT_SPEED_MAX | creature movement speed, jar-space units/sec |
| MOVEMENT_SPEED_MAX | — | float | constant, 50.0 | a data-corruption gate, not a design-taste ceiling — generous headroom above Creature Behavior's documented values (Snail=6, Moth=14) so this only rejects clearly-broken data. Creature Behavior's own tuning table separately caps the *design-safe* range much lower; that's a deliberate second, tighter gate, not a contradiction. Beyond MOVEMENT_SPEED_MAX a creature would visibly teleport between frames. |
| pause_duration_min/max | — | float | 0.0–PAUSE_DURATION_MAX, `min ≤ max` | per-type between-destination rest range, seconds — a continuous (not categorical — see Core Rule 5's correction) Pillar 4 differentiator added in Core Rule 5 |
| PAUSE_DURATION_MAX | — | float | constant, 30.0 | a data-corruption gate, same pattern as MOVEMENT_SPEED_MAX/RATE_MAX — generous headroom above Creature Behavior's current global range (2.0–5.0s). Creature Behavior's own tuning table should define the design-safe *per-type* range once it's revised to consume this field (see Open Questions); this constant only rejects clearly-broken data, not a legitimate slow-resting creature. |
| growth_rate/decay_rate | — | int | 0–RATE_MAX | per-tick growth/decay applied to a plant's `growth_stage`, per Ecosystem Simulation's formula |
| RATE_MAX | — | int | constant, 10 | a data-corruption gate, same pattern as MOVEMENT_SPEED_MAX — generous headroom above Ecosystem Simulation's documented design-safe ranges (`growth_rate` 1–3/tick, `decay_rate` 1–4/tick). **Correction (2026-08-03 re-review):** this does not mean RATE_MAX itself distinguishes "corrupted" from "legitimate" data by magnitude alone — Flower's real MVP data (`decay_rate=4`, `max_stage=3`) already zeroes `growth_stage` in a single tick by intentional design, well under RATE_MAX=10. The gate's actual job is narrower and still real: it rejects values with no plausible relationship to any MVP `max_stage` (3–6) at all, e.g. `decay_rate=99999` — not every rate that happens to clear a plant's stages quickly. |
| growth_pattern | — | enum | {carpet, clump, climb} | the plant's spread/silhouette behavior, per Core Rule 4 |
| valid | — | bool | true/false | whether the definition is safe to load |

**Output Range:** boolean — a definition that fails this check must not be
loaded into the registry (see Edge Cases). A PlantTypeDef's `visual_stages`
list length is checked separately (minimum 2 entries — see Edge Cases)
since it's a structural list-length assertion, not a numeric range
comparison like the checks above.
**Worked examples below are given per Def type (2026-08-03 re-review —
corrected)**: an earlier draft combined fields from all three Def types
into single hypothetical examples (e.g. a `moisture_tolerance` value
alongside a `footprint_size` alongside a `movement_speed`), which directly
contradicts the per-type scoping clause immediately above — no real
PlantTypeDef/CreatureTypeDef/ObjectTypeDef has all of those fields at once,
so those examples corresponded to no buildable fixture. Corrected to one
example per actual Def type.

**Example (PlantTypeDef, valid):** `moisture_tolerance_min=20,
moisture_tolerance_max=60, light_tolerance_min=20, light_tolerance_max=60,
growth_rate=1, decay_rate=2, growth_pattern=carpet` → `valid = true`.
**Example (PlantTypeDef, invalid — band too narrow):**
`moisture_tolerance_min=40, moisture_tolerance_max=41` (`growth_rate`,
`decay_rate`, `growth_pattern` otherwise valid) → `valid = false` (band
width 1 < 15).
**Example (PlantTypeDef, invalid — light band too narrow):**
`light_tolerance_min=50, light_tolerance_max=52` (all other fields
otherwise valid) → `valid = false` (band width 2 < `LIGHT_BAND_MIN_WIDTH`
15) — the same failure mode as the moisture-band example above, applied to
`light_tolerance`.
**Example (PlantTypeDef, invalid — negative growth_rate):** `growth_rate=-5`
(all other PlantTypeDef fields otherwise valid) → `valid = false` — would
invert growth/decay behavior in Ecosystem Simulation if loaded.
**Example (PlantTypeDef, invalid — unbounded decay_rate):**
`decay_rate=99999` (all other PlantTypeDef fields otherwise valid) →
`valid = false` (exceeds RATE_MAX=10) — would drive any plant's
`growth_stage` straight to `0` in a single tick if loaded, violating Core
Rule 8's gradual-never-sudden guarantee.
**Example (ObjectTypeDef, valid):** `footprint_size=8` → `valid = true`.
**Example (CreatureTypeDef, valid):** `movement_speed=6,
pause_duration_min=3, pause_duration_max=6` → `valid = true`.
**Example (CreatureTypeDef, invalid — inverted pause_duration):**
`pause_duration_min=6, pause_duration_max=3` (`movement_speed` otherwise
valid) → `valid = false` — `min` exceeds `max`, an inverted range with no
valid interpretation.

### Second-pass check: `spawn_reference_validity`

Content Data is the only system with full-registry visibility at load time,
so the existence check for `spawn_conditions`' referenced `id`s belongs
here, not punted to Ecosystem Simulation (which only ever sees whatever
Content Data already resolved). This runs after every individual definition
has been checked by `definition_validity` and loaded — a `CreatureTypeDef`
may reference a definition that loads later in sorted load order (see Core
Rule 7), so the check cannot run inline during the first pass.

This check validates `required_ids` (see Core Rule 5), not `spawn_conditions`
itself — Content Data never parses the expression. `required_ids` is the
authored, explicit list of every plant-type and/or creature-type `id` that
`spawn_conditions` references (e.g. Moth's `required_ids` would list both
`flower` and `snail`, matching its real MVP condition that requires Snail
to already be PRESENT) — keeping `required_ids` in sync with
`spawn_conditions` is a content-authoring responsibility, not something this
system derives automatically. **Gap, noted not fixed (2026-08-03 round-8
re-review, `systems-designer`):** nothing anywhere — not here, not in
`ecosystem-simulation.md` — checks that `spawn_conditions`' actual
expression only references ids present in `required_ids`; a mismatched or
malformed expression is undetected at load and unspecified at runtime. This
divergence is out of Content Data's reach by design (Content Data never
parses the expression), so if it's worth catching, it belongs to whichever
system does parse `spawn_conditions` — see Open Questions.

**Iterative, not single-pass (2026-08-03 re-review):** because `required_ids`
may reference *other CreatureTypeDef ids*, not just plant-type ids, a single
flat pass is insufficient — a creature excluded by this very check could
still be referenced by a survivor evaluated in the same pass, leaving a
dangling reference in the registry (exactly the failure this check exists to
prevent). Instead, the check runs repeatedly to a fixpoint:

`spawn_reference_valid(def) = every id in def.required_ids exists in the
registry as of the start of the current pass`

Each pass evaluates every still-registered `CreatureTypeDef` and excludes
any that fail; the next pass then re-evaluates against the reduced
registry. Passes repeat until one full pass excludes nothing new — each
pass that excludes anything guarantees the next pass has strictly fewer
candidates, so this always terminates, in at most `N + 1` passes, where `N`
is the number of `CreatureTypeDef`s (at most `N` passes can each exclude at
least one candidate, plus one final confirming pass that excludes nothing
and halts the loop). At MVP's registry size (6 definitions total, 2
`CreatureTypeDef`s), `N + 1 = 3` passes is a **worst-case ceiling, not what
the actual MVP data does** (2026-08-03 re-review, `systems-designer`) — the
real MVP fixture (Snail and Moth both immediately satisfiable) converges in
1 pass; 3 is only reached by an adversarial cascade fixture (see AC4b) that
deliberately exercises the worst case. This is a loop-until-stable
termination condition, not a fixed iteration count — an implementation must
run until a pass excludes nothing, never a hardcoded pass count.

A `CreatureTypeDef` that fails this check at any pass is excluded from the
registry (see Edge Cases) — a referenced type not existing (or no longer
existing) is a data error, not a "creature that never spawns" design.

All other formulas (growth rate application, decay curves, spawn condition
matching) are owned by Ecosystem Simulation, which consumes these fields as
inputs — not duplicated here.

*(`systems-designer` consulted — confirmed no gameplay math belongs in this
GDD beyond the load-time validity check above.)*

## Edge Cases

All load-time warnings referenced below are emitted via Godot's
`push_warning()`, with message format `[ContentData] <id>: <reason>` — this
is what an automated test asserts against. **Testability note (resolved
2026-08-03; version corrected 2026-08-03 round-8 re-review,
`godot-specialist`, WebSearch-verified against GUT's own CHANGES.md):** GUT
`assert_push_warning()`/`assert_push_warning_count()` were added in GUT
9.6.0, but **9.6.0 is compat-tagged for Godot 4.6, not 4.7.1** — this
project's pinned engine requires **GUT ≥9.7.0**. (An earlier round of this
GDD cited 9.6.0 as the 4.7.1-compatible floor; that was wrong and is
corrected here.) Whether GUT *can* capture `push_warning()` output is not an
open question — only confirming the project's actually-installed GUT
release meets the ≥9.7.0 floor remains open (a `/test-setup`-time check, not
a design question — see Open Questions). Because that confirmation is still
pending, the exclusion behavior and the warning-logging behavior are now
kept as separate acceptance criteria below (see "Warning-Logging
Assertions" after the numbered list) rather than bundled into one
conditional clause per criterion — exclusion is testable today regardless
of GUT version; the warning assertions become required once ≥9.7.0 is
confirmed.

- **If a definition fails the `definition_validity` check at load time**: it is
  excluded from the registry entirely, a load-time warning is logged with the
  definition's `id`, and the game continues running with the remaining valid
  definitions — a bad data file must never crash startup.
- **If two definitions share the same `id`**: the first-loaded one wins, the
  duplicate is rejected, and a load-time warning is logged naming both source
  files. Load order is deterministic (alphabetical by file path) so this
  behavior is reproducible.
- **If a system queries the registry for an `id` that doesn't exist**: the
  registry returns `null`/`None`, not an error or crash. The calling system is
  responsible for handling a missing lookup (e.g., Ecosystem Simulation must
  not assume every `spawn_conditions` reference resolves).
- **If `moisture_tolerance_min == moisture_tolerance_max`** (zero-width viable
  band), **or if the band is narrower than `BAND_MIN_WIDTH` (15)**, **or if
  either bound falls outside `0–100`**: all three fail the
  `definition_validity` check and are rejected at load per the first edge
  case above — a plant with no viable moisture range, a hair-trigger range,
  or an out-of-domain range is a data error, not a valid design.
- **If `light_tolerance_min == light_tolerance_max`, or the band is
  narrower than `LIGHT_BAND_MIN_WIDTH` (15), or either bound falls outside
  `0–100`** (added 2026-08-03, `/design-review` on
  `ecosystem-simulation.md`): rejected at load per the same path as the
  analogous moisture-band edge case above — same rationale (a hair-trigger
  or out-of-domain light band is a data error, not a valid design).
- **If `footprint_size` is zero or negative** (fails `0.0 < footprint_size`),
  **or exceeds `FOOTPRINT_MAX` (20.0)**: rejected at load per the same
  path — a non-positive footprint has no physical meaning for a placement
  collision radius, and a footprint that large is a data error (would make
  an object dominate jar collision space); neither is a valid
  extreme-but-legal tuning value. **(added 2026-08-03 round-8 re-review,
  `qa-lead`)** the lower-bound case was previously covered only by AC3, with
  no matching Edge Cases bullet — added here for symmetry with every other
  bounded field.
- **If `movement_speed` exceeds `MOVEMENT_SPEED_MAX` (50.0)**: rejected at
  load per the same path — a speed value that large is a data error (would
  make a creature visibly teleport between frames), not a valid
  extreme-but-legal tuning value.
- **If `growth_rate` or `decay_rate` is negative, or either exceeds
  `RATE_MAX` (10)**: rejected at load per the same path — a negative rate
  would invert growth/decay direction, which is unconditionally a data
  error. **Correction (2026-08-03, round-8 re-review, `systems-designer`):**
  the upper bound is not justified by "would zero/max `growth_stage` in a
  single tick" — a legitimate, in-range value can already do that for a
  low-`max_stage` type (e.g. `decay_rate=3` against `max_stage=3`), well
  under `RATE_MAX`. **Illustrative example updated 2026-08-03
  `/design-review`:** an earlier round of this doc cited Flower's own
  `decay_rate=4` here; that value was retuned to `1` in the same review
  that added `light_tolerance` (see `ecosystem-simulation.md` — the old
  `decay_rate=4` against `max_stage=3` one-tick-wiped Flower on any decay
  tick, a real anti-pillar violation, not just an illustrative extreme).
  The point this bullet makes still holds generally, just no longer via
  Flower as the concrete example. `RATE_MAX` is a
  corruption-scale gate only (it rejects values with no plausible
  relationship to any MVP `max_stage`, e.g. `decay_rate=99999`), not a
  tuning-sanity check — a legitimately bad-but-in-range value like
  `decay_rate=8` passes this check and must be caught by Ecosystem
  Simulation's own tuning review, not here.
- **If `pause_duration_min` exceeds `pause_duration_max`, either is
  negative, or either exceeds `PAUSE_DURATION_MAX` (30.0)**: rejected at
  load per the same path — an inverted or unbounded rest range is a data
  error, not a valid extreme tuning value.
- **If `growth_pattern` is not one of `carpet`/`clump`/`climb`** (e.g. a
  typo): rejected at load per the same path — an unrecognized spread
  pattern would otherwise reach Diorama Rendering unchecked.
- **If a `CreatureTypeDef`'s `required_ids` names a plant-type or
  creature-type `id` that doesn't exist anywhere in the registry** (checked
  by `spawn_reference_validity`, run iteratively to a fixpoint after
  first-pass loading completes — see Formulas): the `CreatureTypeDef` is
  excluded from the registry, a load-time warning is logged naming the
  creature `id` and the missing referenced `id`, and loading continues — the
  same "bad data must never crash startup" guarantee as every other validity
  failure. This also covers the case where the referenced `id` belonged to
  another `CreatureTypeDef` that was itself excluded in an earlier pass.
- **If a `CreatureTypeDef`'s `required_ids` forms a cycle back to itself**
  (directly or transitively through other CreatureTypeDefs — e.g. Snail
  requires Moth present and Moth requires Snail present, with no other
  missing reference) **— known gap, not caught by `spawn_reference_validity`
  as specified** (2026-08-03 re-review, `systems-designer`): every
  referenced `id` genuinely exists, so no pass excludes anything and the
  fixpoint check passes normally. This is a content-authoring error, not a
  data-validity failure this system detects — a cyclic spawn dependency
  creates a permanent gameplay soft-lock at the Ecosystem Simulation level
  (neither creature can ever satisfy its `spawn_conditions`). Not present in
  the MVP's actual data (Moth→Snail is one-directional), but nothing in
  `spawn_reference_validity` prevents a future content author from
  introducing it. Flagged here as a documented limitation; a dedicated
  cycle-detection pass is future scope, not required for MVP.
- **If a PlantTypeDef's `visual_stages` has fewer than 2 entries** (empty or
  a single entry): treated as invalid and rejected at load. Ecosystem
  Simulation derives `max_stage = visual_stages.length - 1` directly from
  this list and its own Formulas section requires `max_stage ≥ 1`; a
  single-entry list would make growth structurally impossible (nothing to
  grow toward) as well as leaving no renderable stage for Diorama Rendering,
  which has no fallback/placeholder asset at MVP.
- **If a CreatureTypeDef or ObjectTypeDef has an empty (null or
  zero-length) `visual_ref`**: treated as invalid and rejected at load —
  every loaded definition must have at least one renderable visual, since
  Diorama Rendering has no fallback/placeholder asset at MVP.

## Dependencies

Content Data has no upstream dependencies — it is a Foundation-layer system
with zero external inputs.

**Downstream dependents** (all hard dependencies — none has a fallback if
Content Data doesn't provide the type definition, per the "no placeholder
asset" edge case):
- **Object Placement** — needs `ObjectTypeDef.repositionable`, `footprint_size`
- **Ecosystem Simulation** — needs `PlantTypeDef`/`CreatureTypeDef` growth/decay/spawn
  fields, including the new `light_tolerance_min/max` (2026-08-03
  `/design-review`)
- **Creature Behavior** — needs `CreatureTypeDef.movement_speed`,
  `pause_duration_min/max` (the latter is new as of this 2026-08-03
  re-review — Creature Behavior's own GDD still needs a companion edit to
  consume it, see Open Questions)
- **Persistence/Save** (added 2026-08-03, `/design-review`) — validates
  loaded `type_id` references against this registry; a genuine downstream
  consumer missing from this list until now, per that system's own
  Dependencies section (which already listed Content Data on its side —
  this was a one-directional bidirectionality gap, not a new dependency)
- **Diorama Rendering** (companion edit, 2026-08-05 — `diorama-rendering.md`
  now authored) — needs `visual_stages`/`visual_ref`/`growth_pattern` from
  all three definition types, plus `moisture_tolerance_min/max` and
  `light_tolerance_min/max` from PlantTypeDef (needed to evaluate that
  system's mandated per-plant STALLED cue, per `ecosystem-simulation.md`'s
  own round-13/14 requirement)

All five of these systems now have GDDs (Object Placement, Ecosystem
Simulation, Creature Behavior, Persistence/Save, Diorama Rendering), and
each independently lists Content Data as an upstream hard dependency
naming the specific fields it consumes — confirmed bidirectionally
consistent as of this update.

## Tuning Knobs

Content Data itself has no system-level knobs (it's a static registry) — but
the *fields inside each type definition* are exactly the designer-facing knobs
that shape simulation feel, since the whole point of externalizing this data
is to make it tunable without code changes.

| Knob | Safe Range | Too Low | Too High |
|---|---|---|---|
| `moisture_tolerance_min/max` (per plant type) | 0–100, band width ≥15 (enforced by `definition_validity` — see Formulas) | Narrow band → plant dies from any moisture deviation, reads as punishing (violates Anti-Pillar: NOT punishing). Below 15 width is now a load-time rejection, not just a guideline. | Band covers full 0–100 → plant never visibly reacts to moisture, reads as static |
| `light_tolerance_min/max` (per plant type) | 0–100, band width ≥15 (enforced by `definition_validity`, `LIGHT_BAND_MIN_WIDTH`) | Narrow band → plant flickers in/out of range every few ticks purely from light's own drift, unrelated to player care — reads as arbitrary | Band covers full 0–100 → light never gates growth for this plant, defeating the reason this axis was added (see `ecosystem-simulation.md`) |
| `growth_rate` (per plant type) | 0–RATE_MAX (10), design-safe range tuned in Ecosystem Simulation GDD (1–3/tick) — RATE_MAX is enforced by `definition_validity`, see Formulas | Growth invisible between visits — defeats the core hypothesis | Growth completes in one visit — breaks the "slow drift" pacing pillar |
| `decay_rate` (per plant type) | 0–RATE_MAX (10), design-safe range tuned in Ecosystem Simulation GDD (1–4/tick) — RATE_MAX is enforced by `definition_validity`, see Formulas | Nothing ever decays — reduces discovery variety | Constant visible decay — reads as neglect/punishment (violates Anti-Pillar) |
| `movement_speed` (per creature type) | tuned in Creature Behavior GDD | Creature never appears to move — feels static | Creature "teleports" between glances — breaks believability |
| `pause_duration_min/max` (per creature type) | 0–PAUSE_DURATION_MAX (30.0), data-corruption gate enforced by `definition_validity`; design-safe per-type range to be tuned in Creature Behavior GDD once it consumes this field | No meaningful pause / min≈max → creature reads as robotic, undercuts Pillar 4 distinctiveness between types | Long pauses → creature reads as frozen/broken |
| `spawn_conditions` thresholds (per creature type) | tuned in Ecosystem Simulation GDD | Creature almost never appears — breaks "residents move in" fantasy | Creature always present — removes discovery surprise |

The exact safe values for `growth_rate`, `decay_rate`, `spawn_conditions`, and
`movement_speed` are owned by Ecosystem Simulation and Creature Behavior
respectively — this GDD only defines that these fields exist as
externally-editable data, not their tuned values. This directly serves the
concept doc's flagged risk: "the ecosystem simulation could feel either too
random or too static — needs dedicated tuning time."

## Visual/Audio Requirements

N/A — Content Data is a pure data/infrastructure layer with no visual or audio
presence of its own. Visual asset *references* (`visual_stages`, `visual_ref`)
are fields this system holds, but the actual visual/audio requirements are
owned by Diorama Rendering and Ambient Audio.

## UI Requirements

N/A — Content Data has no UI. Any future designer-facing content-authoring
tool (see Open Questions) would be a `tools-programmer` concern, not a
player-facing UI requirement.

## Acceptance Criteria

1. **GIVEN** a valid PlantTypeDef, CreatureTypeDef, or ObjectTypeDef in a data
   file, **WHEN** the game loads, **THEN** it appears in the in-memory registry
   queryable by its `id`.
2. **GIVEN** a PlantTypeDef with `moisture_tolerance_min >= moisture_tolerance_max`
   (e.g., min=60, max=40), **WHEN** the game loads, **THEN** it is
   excluded from the registry and the game continues loading without
   crashing.
2a. **GIVEN** a PlantTypeDef with a moisture bound outside `0–100` (e.g.,
   min=-500, max=9999), **WHEN** the game loads, **THEN** it is
   excluded from the registry and loading continues. **(2026-08-03
   re-review — boundary pair, required; this domain bound is distinct from
   the band-*width* boundary already covered by AC2b)** The boundary itself
   must be tested independently of this grossly-invalid case:
   `moisture_tolerance_min=-1` (max otherwise valid, e.g. 50) **is invalid**
   and excluded, while `moisture_tolerance_min=0` exactly **is valid**;
   separately, `moisture_tolerance_max=101` (min otherwise valid, e.g. 50)
   **is invalid** and excluded, while `moisture_tolerance_max=100` exactly
   **is valid** — confirming both domain bounds are inclusive (`0 ≤ min`,
   `max ≤ 100`).
2b. **GIVEN** a PlantTypeDef with a moisture band narrower than 15 (e.g.,
   min=40, max=41), **WHEN** the game loads, **THEN** it is
   excluded from the registry and loading continues. **(2026-08-03 re-review — boundary
   pair, required)** The boundary itself must be tested independently of
   this grossly-narrow case: a band width of exactly 15 (e.g., min=40,
   max=55) **is valid** and loads normally; a band width of 14 (e.g.,
   min=40, max=54) **is invalid** and excluded.
2c. **(new, 2026-08-03 `/design-review`)** **GIVEN** a PlantTypeDef with
   `light_tolerance_min >= light_tolerance_max`, a band narrower than
   `LIGHT_BAND_MIN_WIDTH` (15), or a bound outside `0–100` (e.g.,
   light_tolerance_min=50, light_tolerance_max=52), **WHEN** the game
   loads, **THEN** it is excluded from the registry and loading continues.
   *(Scope note: unlike moisture's ACs 2/2a/2b, this is deliberately one
   consolidated criterion covering all three light-band failure shapes
   rather than three separately-boundary-tested ones — the underlying
   check is a direct structural copy of the already-exhaustively-tested
   moisture-band check, so the marginal value of re-deriving every boundary
   pair a second time is low. Split further if a real bug is ever found in
   this check specifically.)*
3. **GIVEN** an ObjectTypeDef with `footprint_size <= 0` (e.g., footprint_size=0),
   **WHEN** the game loads, **THEN** it is excluded from the
   registry and loading continues without crashing. **(2026-08-03 re-review — boundary pair, required)**
   The paired valid boundary must also be tested: `footprint_size` just
   above 0 (e.g., 0.01) **is valid** and loads normally — confirming the
   bound is strict (`> 0`), not inclusive (`>= 0`).
3a. **GIVEN** an ObjectTypeDef with `footprint_size` above 20.0 (e.g.,
   footprint_size=1000), **WHEN** the game loads, **THEN** it is
   excluded from the registry and loading continues. **(2026-08-03 re-review — boundary pair, required)**
   The boundary itself must be tested independently: `footprint_size=20.0`
   exactly **is valid** (inclusive upper bound); `footprint_size=20.0001`
   **is invalid** and excluded.
3b. **GIVEN** a PlantTypeDef with `growth_rate` or `decay_rate` negative
   (e.g., growth_rate=-5), **WHEN** the game loads, **THEN** it
   is excluded from the registry and loading continues without crashing.
   **(2026-08-03
   re-review — boundary pair, required)** The paired valid boundary must
   also be tested: `growth_rate=0` (or `decay_rate=0`) **is valid** — a
   plant that never grows, or never decays, is legitimate data, confirming
   the lower bound is inclusive (`>= 0`), not strict.
3c. **GIVEN** a PlantTypeDef with `growth_rate` or `decay_rate` above
   RATE_MAX (e.g., decay_rate=99999), **WHEN** the game loads, **THEN**
   it is excluded from the registry and loading continues.
   **(2026-08-03 re-review —
   boundary pair, required)** The boundary itself must be tested
   independently: `growth_rate=10` (or `decay_rate=10`) exactly **is
   valid** (inclusive upper bound, RATE_MAX); `=11` **is invalid** and
   excluded.
3d. **GIVEN** a PlantTypeDef with `growth_pattern` set to a value other than
   `carpet`/`clump`/`climb` (e.g., a typo'd string), **WHEN** the game
   loads, **THEN** it is excluded from the registry and loading
   continues.
4. **GIVEN** a CreatureTypeDef with `movement_speed < 0` (e.g., movement_speed=-1.0),
   **WHEN** the game loads, **THEN** it is excluded from the
   registry and loading continues without crashing. **(2026-08-03 round-8 re-review, `qa-lead`)**
   **Boundary pair:** `movement_speed=0` **is valid** per this GDD's
   `definition_validity` formula (`0.0 ≤ movement_speed`, inclusive) and
   loads normally — this AC asserts today's specified load-time behavior
   only. Whether a permanently-stationary creature is *good MVP content* is
   a separate, still-open design question (see Open Questions:
   "`movement_speed == 0` legality") that this AC does not resolve or wait
   on.
4a. **GIVEN** a CreatureTypeDef with `movement_speed` above 50.0 (e.g.,
   movement_speed=1e9), **WHEN** the game loads, **THEN** it is
   excluded from the registry and loading continues. **(2026-08-03 re-review — boundary pair, required)**
   The boundary itself must be tested independently: `movement_speed=50.0`
   exactly **is valid** (inclusive upper bound); `movement_speed=50.0001`
   **is invalid** and excluded.
4b. **(rewritten 2026-08-03 re-review, `qa-lead`)** **GIVEN** the fixture
   set `tests/fixtures/content_data/spawn_cascade_set/` containing a valid
   PlantTypeDef `flower`, a CreatureTypeDef `snail` whose `required_ids`
   references a non-existent id `worm` (a direct dangling reference), and a
   CreatureTypeDef `moth` whose `required_ids` references `snail` and
   `flower` only (`moth` does **not** directly reference `worm`), **WHEN**
   the game loads and `spawn_reference_validity`'s fixpoint iteration
   completes, **THEN** both `snail` (excluded on pass 1, the direct
   dangling reference) **and** `moth` (excluded on pass 2, only detectable
   because `snail` — one of its own `required_ids` — no longer exists after
   pass 1) are excluded from the registry, and `flower` remains registered.
   An implementation that excludes only `snail` and leaves `moth`
   registered fails this criterion — this is the specific case that
   distinguishes a true iterative fixpoint from a single non-iterative
   pass, which the original single-hop wording of this AC did not force.
4c. **(new, 2026-08-03 re-review)** **GIVEN** a CreatureTypeDef with
   `pause_duration_min > pause_duration_max` (e.g., min=6, max=3), **WHEN**
   the game loads, **THEN** it is excluded from the registry and
   loading continues without crashing. **(2026-08-03 re-review — boundary
   pair, required)** The paired valid boundary must also be tested:
   `pause_duration_min == pause_duration_max` (e.g., both `=3.0`, a fixed
   non-random pause length) **is valid** and loads normally — confirming
   the bound is inclusive (`min ≤ max`), not strict, so a zero-width pause
   range is legitimate data.
4d. **(new, 2026-08-03 round-8 re-review, `qa-lead`)** **GIVEN** a
   CreatureTypeDef with `pause_duration_min` or `pause_duration_max`
   negative (e.g., pause_duration_min=-1.0), **WHEN** the game loads,
   **THEN** it is excluded from the registry and loading continues without
   crashing. **(2026-08-03 re-review — boundary pair, required)** The
   paired valid boundary must also be tested: `pause_duration_min=0.0` (or
   `pause_duration_max=0.0`) **is valid** — confirming the lower bound is
   inclusive (`>= 0`), not strict.
4e. **(new, 2026-08-03 round-8 re-review, `qa-lead`)** **GIVEN** a
   CreatureTypeDef with `pause_duration_min` or `pause_duration_max` above
   `PAUSE_DURATION_MAX` (e.g., pause_duration_max=31.0), **WHEN** the game
   loads, **THEN** it is excluded from the registry and loading continues.
   **Boundary pair:** `pause_duration_max=30.0` exactly **is valid**
   (inclusive upper bound, `PAUSE_DURATION_MAX`); `pause_duration_max=30.0001`
   **is invalid** and excluded.
5. **(fixture path added 2026-08-03 re-review, `qa-lead`)** **GIVEN** the
   fixture set `tests/fixtures/content_data/duplicate_id_set/` containing
   two definitions in different files sharing the same `id`, **WHEN** the
   game loads, **THEN** only the first-loaded (alphabetically by file path)
   definition is registered under that `id`, and all other valid
   definitions in the losing file still load normally. Kept in its own
   fixture directory, separate from AC7's `mvp_set/`, so this test cannot
   corrupt AC7's exact-set-equality assertion by leaving a stray duplicate
   file behind.
6. **GIVEN** a system queries the registry for a non-existent `id`, **WHEN**
   the query executes, **THEN** it returns null/None without throwing an error.

### Warning-Logging Assertions

**(added 2026-08-03, round-8 re-review)** These mirror ACs 2/2a/2b/3/3a/3b/
3c/3d/4/4a/4b/4c/4d/4e/5/8a/8b/8c one-to-one and become required once the
project's installed GUT release is confirmed ≥9.7.0 (see Open Questions and
the Edge Cases intro) — deliberately kept separate from the exclusion
criteria above so that no exclusion assertion's testability depends on an
external tool version, and so a rushed test author can't skip a bundled
clause by mistake. Until that floor is confirmed, treat these as tracked,
not blocking. **Rows for 8a/8b/8c added 2026-08-04 `/design-review`**
(`qa-lead` finding) — round 9's review log conditioned this document's
APPROVED verdict on this table covering every exclusion AC; it had been
extended for the round-8 ACs (2 through 5) but the earlier 8a/8b/8c
(`visual_stages`/`visual_ref` emptiness checks) were missed, an ordering
accident rather than a deliberate cut.

| AC | Warning assertion |
|---|---|
| 2 | a warning is logged naming the `id` |
| 2a | a warning is logged naming the `id` |
| 2b | a warning is logged naming the `id` |
| 3 | a warning is logged naming the `id` |
| 3a | a warning is logged naming the `id` |
| 3b | a warning is logged naming the `id` |
| 3c | a warning is logged naming the `id` |
| 3d | a warning is logged naming the `id` |
| 4 | a warning is logged naming the `id` |
| 4a | a warning is logged naming the `id` |
| 4b | a warning is logged naming both the creature `id` and the missing referenced `id` |
| 4c | a warning is logged naming the `id` |
| 4d | a warning is logged naming the `id` |
| 4e | a warning is logged naming the `id` |
| 5 | a conflict warning is logged naming both source files |
| 8a | a warning is logged naming the `id` |
| 8b | a warning is logged naming the `id` |
| 8c | a warning is logged naming the `id` |

7. **GIVEN** the pinned MVP content set — PlantTypeDef `moss`
   (`growth_pattern=carpet`), `fern` (`growth_pattern=clump`), `flower`
   (`growth_pattern=climb`); CreatureTypeDef `snail`, `moth`; ObjectTypeDef
   `rock` (the sole repositionable object at MVP, per Object Placement's
   locked scope), loaded from the fixture directory
   `tests/fixtures/content_data/mvp_set/` (not the production data
   directory, per the Testing Standards isolation rule) — **WHEN** the
   registry loads, **THEN** the registry's full set of loaded `id`s equals
   exactly `{moss, fern, flower, snail, moth, rock}` (set equality — a test
   enumerates all loaded ids and diffs against this fixed list, rather than
   relying on an unenumerated "nothing else" claim), and each plant type's
   `growth_pattern` matches the mapping above.

**Fixture value table (added 2026-08-03, round-8 re-review, `qa-lead`):**
the ids and `growth_pattern` values above were the only fields this AC
previously pinned — insufficient for a test author to actually build the
fixture files. Full field values, pinned here so `tests/fixtures/content_data/mvp_set/`
is fully specified:

| Field | moss | fern | flower | snail | moth | rock |
|---|---|---|---|---|---|---|
| `id` | moss | fern | flower | snail | moth | rock |
| `display_name` | "Moss Patch" | "Fern" | "Flower" | "Snail" | "Moth" | "Rock" |
| `moisture_tolerance_min` | 40 | 55 | 60 | — | — | — |
| `moisture_tolerance_max` | 75 | 90 | 90 | — | — | — |
| `light_tolerance_min` | 20 | 40 | 55 | — | — | — |
| `light_tolerance_max` | 60 | 80 | 95 | — | — | — |
| `growth_rate` | 1 | 1 | 2 | — | — | — |
| `decay_rate` | 2 | 1 | 1 | — | — | — |
| `growth_pattern` | carpet | clump | climb | — | — | — |
| `visual_stages` (list, index 0→`max_stage`) | `[moss_00, moss_01, moss_02, moss_03, moss_04]` (length 5, `max_stage`=4) | `[fern_00..fern_06]` (length 7, `max_stage`=6) | `[flower_00, flower_01, flower_02, flower_03]` (length 4, `max_stage`=3) | — | — | — |
| `spawn_conditions` | — | — | — | `moss.growth_stage + fern.growth_stage >= 6` | `flower.growth_stage == max_stage AND snail.state == PRESENT` | — |
| `required_ids` | — | — | — | `[moss, fern]` | `[flower, snail]` | — |
| `movement_speed` | — | — | — | 6 | 14 | — |
| `pause_duration_min` | — | — | — | 3.0 | 1.5 | — |
| `pause_duration_max` | — | — | — | 6.0 | 3.0 | — |
| `visual_ref` (CreatureTypeDef/ObjectTypeDef only) | n/a — no such field | n/a — no such field | n/a — no such field | "snail_01" | "moth_01" | "rock_01" |
| `repositionable` | — | — | — | — | — | true |
| `footprint_size` | — | — | — | — | — | 8 |

**Correction (2026-08-03 re-review, `qa-lead`):** the `visual_ref` row
previously listed a value for `moss`/`fern`/`flower` (`"moss_01"` etc.) —
but per Core Rule 4, PlantTypeDef has no `visual_ref` field at all; only
`visual_stages` (a list). A test author following the old table would have
authored a field the schema doesn't define. The plant columns are now
marked "n/a" for that row, and `visual_stages`' previously length-only
entries are now given actual per-index placeholder content (`moss_00`
through `moss_04`, etc.) so the fixture is genuinely fully specified rather
than length-only.

Moisture/growth/decay/`max_stage` values are the already-locked MVP data
from `ecosystem-simulation.md`/`entities.yaml`; `movement_speed` values are
the already-locked data from `creature-behavior.md`/`entities.yaml`;
`footprint_size` reuses Object Placement's own worked example (`fp=8`).
**`spawn_conditions`/`required_ids` values (added to this classification
2026-08-04 `/design-review`, `qa-lead` finding) are also already-locked
data**, sourced directly from `ecosystem-simulation.md`'s own Creature
Spawn Conditions table (Snail: `moss.growth_stage + fern.growth_stage >= 6`,
`required_ids: [moss, fern]`; Moth: `flower.growth_stage == max_stage AND
snail.state == PRESENT`, `required_ids: [flower, snail]`) and mirrored in
`entities.yaml` — not illustrative fixture data invented for this table, the
same locked-vs-illustrative distinction already drawn for every other row
above. `pause_duration_min/max`, `visual_stages`/`visual_ref` per-stage
names, and `display_name` values have no prior source — they are
illustrative fixture data chosen only to satisfy `definition_validity` and
are **not** a tuning or asset proposal; Creature Behavior's own tuning table
still owns the real per-type `pause_duration` values once it consumes this
field, and Diorama Rendering owns the real asset references once it exists
(see Open Questions).
8a. **GIVEN** a PlantTypeDef with `visual_stages` containing fewer than 2
   entries (empty or a single entry), **WHEN** the game loads, **THEN** it
   is treated as invalid and excluded via the same load-time validation
   path.
8b. **GIVEN** a CreatureTypeDef with an empty (null or zero-length)
   `visual_ref`, **WHEN** the game loads, **THEN** it is treated as invalid
   and excluded via the same load-time validation path.
8c. **GIVEN** an ObjectTypeDef with an empty (null or zero-length)
   `visual_ref`, **WHEN** the game loads, **THEN** it is treated as invalid
   and excluded via the same load-time validation path.

*(`qa-lead` consulted — flagged 3 gaps in the original draft, all addressed
above: split the validity check into 3 independently-testable criteria, added
a criterion for the read-only constraint, and clarified the duplicate-id
tie-break behavior for the losing file's other definitions.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — `qa-lead` and
`godot-specialist` independently flagged this criterion as unimplementable/
untestable as originally written ("code-review only"); rewritten above as a
concrete automated-test criterion. `systems-designer` and `creative-director`
also drove the range/band-width/footprint tightening in the Formulas section
and the new `spawn_reference_validity` check above; `game-designer` drove the
addition of `growth_pattern` (Detailed Design) and the decay-behavior rule
(Core Rule 8).)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round.
`moisture_tolerance` rescaled from float `0.0–1.0` to int `0–100` to match
`jar_moisture`'s actual scale in `ecosystem-simulation.md` and the
registry's real MVP data; under the old scale every MVP plant type would
have failed load-time validation and been silently rejected.
`behavior_pattern_id` removed
from CreatureTypeDef — unused by Creature Behavior's actual single-pattern
wander design, added back only if a real per-type behavior branch is
needed. Former AC9 (runtime immutability guard) removed and Core Rule 2
demoted from an enforced rule to a documented convention after
`godot-specialist` confirmed the proposed `_set()` override does not
intercept writes to real `@export var` fields — building a working guard
(backing-`Dictionary` + `_get_property_list()`) was judged not worth the
cost, and would conflict with `.tres` inspector authoring
[creative-director]. `spawn_reference_validity` widened to cover
creature-type id references, not just plant-type ids, since Moth's real
`spawn_conditions` references Snail's state. AC7 rewritten from an
untestable "2-3 object types" range to a pinned exact `id` list with
assigned `growth_pattern` values per type — object count corrected to 1
(`rock`), matching `object-placement.md`'s already-locked MVP scope (the
"2-3" range traced back to `game-concept.md`'s original aspiration, which
has since narrowed downstream; that source document was not edited as part
of this review). Warning-log format specified as Godot's `push_warning()`.
Stale Dependencies-section claim that no downstream GDD existed yet was
corrected — three of four now exist.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → blocking items resolved
below. `spawn_conditions` gained a companion `required_ids` field (Core
Rule 5) so `spawn_reference_validity` checks an authored id list instead of
parsing an unspecified expression grammar — the prior formula wasn't
implementable as written. Load order made explicit as an authored sort
step (Core Rule 7) rather than an assumed directory-iteration property.
PlantTypeDef's `visual_stages` minimum tightened from "non-empty" to "≥2
entries," since Ecosystem Simulation derives `max_stage =
visual_stages.length - 1` from this list and requires `max_stage ≥ 1` — a
single-entry list previously passed load validation while making growth
structurally impossible. AC7 rewritten as an exact-set-equality assertion
so "no other definition is missing" is testable without an external
manifest. AC8 split into type-specific 8a/8b/8c (Plant `visual_stages`
length, Creature/Object `visual_ref` emptiness); ObjectTypeDef's
`visual_ref` was previously omitted from this check despite the same
no-fallback-asset rationale applying to it. Five non-blocking findings
(Core Rule 2's `_set()` justification accuracy, `.tres` caching risk,
`FOOTPRINT_MAX` cross-GDD coupling, GUT warning-capture verification, the
`movement_speed==0` legality question) were surfaced but intentionally not
fixed in this pass — tracked below in Open Questions instead of blocking
implementation.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → blocking item resolved
below. `definition_validity` extended to check `growth_rate`/`decay_rate`
(new `RATE_MAX=10` constant) and `growth_pattern` enum membership —
previously unvalidated despite `growth_rate`/`decay_rate` feeding directly
into Ecosystem Simulation's core formula, which assumes both are `≥0`; a
negative or unbounded value would have silently broken that formula or
violated Core Rule 8's no-sudden-loss guarantee, exactly the failure class
`definition_validity` exists to catch. New ACs 3b/3c/3d added. AC7 given an
explicit fixture path per the Testing Standards isolation rule. Edge Cases
intro flagged the `push_warning()`-capture dependency explicitly, so the 9
warning-logging ACs are understood as contingent on that open
infrastructure question rather than silently assumed settled. Core Rule 7
clarified to exclude `.uid`/`.import` sidecar files from the sorted load
list and to sort `res://` paths, not `uid://`. Two Open Questions
strengthened with additional findings (Core Rule 2's setter rationale;
`.tres` caching mitigation candidates), and the per-instance-identity
question now states its underlying single-instance-per-MVP-creature-type
assumption explicitly. A new Open Question cross-references a Pillar 4
variety risk (`growth_pattern`'s 1:1 bijection to 3 plant types; creatures
differing only by a speed scalar) for Creature Behavior/Diorama Rendering
to resolve — `creative-director` judged this out of Content Data's scope
to fix directly, since it holds fields but cannot manufacture variety it
doesn't compute.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → 3 blocking items resolved
below. `spawn_reference_validity` changed from a single flat pass to an
iterative fixpoint pass (Formulas): `required_ids` can reference other
CreatureTypeDef ids (Moth→Snail), so a creature excluded by this check
could previously still be referenced by a survivor evaluated against the
same stale snapshot — a dangling reference the check exists to prevent.
`definition_validity` gained an explicit per-type scoping clause (Formulas)
— the shared formula was previously written as if every definition is
checked against all seven clauses regardless of type, which would require
evaluating e.g. `footprint_size` on a CreatureTypeDef that has no such
field; now stated explicitly that each definition is checked only against
the clauses whose fields exist on its own type. ACs 2/2a/2b/3/3a/3b/3c/3d/
4/4a/4b/5 (12 of 18 total ACs) restructured to separate a **(required)**
registry-exclusion clause from an **(advisory)** warning-logged clause,
mirroring the pattern 8a/8b/8c already used — previously these 12 bundled
both into one THEN clause despite the Edge Cases section already treating
them as differently-confident claims (exclusion testable today; warning
logging contingent on the open GUT `push_warning()` capture question). A
Pillar 4 variety-risk disagreement surfaced but intentionally left
unresolved in this pass: `game-designer` argued Content Data itself is
under-provisioning creature-differentiation data (Creature Behavior's
wander constants are global, not per-type — confirmed by reading
`creature-behavior.md` — so there is currently no field for it to read
even if it wanted to differentiate); `creative-director` partially revised
the prior round's "out of scope" call, now recommending a single gated
field (e.g. `wander_profile`) added only once Creature Behavior's GDD
commits to consuming it — tracked as a Creature Behavior-owned blocker,
not a Content Data change in this pass.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → 1 blocker + 3 near-blocking
mechanical fixes resolved below (registry staleness lived in
`entities.yaml`, not this file — see that file's own history).
`spawn_reference_validity`'s convergence bound corrected from "at most 2
passes" to "at most N+1 passes" (3 for MVP), and restated as a
loop-until-stable condition rather than a fixed count, after
`systems-designer` walked an adversarial case (Snail excluded pass 1 for a
missing reference, Moth — which referenced Snail — only excluded pass 2,
requiring a 3rd confirming pass to satisfy the stated stop condition) that
showed an implementer hardcoding a fixed 2-iteration loop would ship a
latent bug. Core Rule 2's own prose corrected to state the verified reason
runtime immutability isn't enforced (no setter, inline or `_set()`
override, fires on in-place Array/Dictionary mutation) instead of the
previously-debunked claim (that only a backing-Dictionary +
`_get_property_list()` pattern could intercept `@export var` writes at
all) — the correction had been recorded in Open Questions for two prior
rounds but never propagated into the rule text itself; that Open Question
is now removed as resolved. A live disagreement was surfaced, not silently
resolved: `game-designer` argued the Pillar 4 creature-variety gap
(`CreatureTypeDef` differentiates only by `movement_speed` + `visual_ref`,
no categorical field analogous to `growth_pattern`) is this document's own
responsibility, since the plant/creature asymmetry was authored here, not
forced by Creature Behavior being unauthored; `creative-director` partially
revised the prior round's "out of scope" ruling, agreeing the asymmetry
argument is fair but holding that — because Resource fields are additive —
this is a content-richness question jointly owned by Content Data and
Creature Behavior, not a blocker on this document. That split was left
standing, not re-litigated, pending user input.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → 4 blockers resolved below.
**Core Rule 8 corrected**: an earlier draft described decay as advancing
*forward* through dedicated late-stage entries with growth_stage monotonic
— this directly contradicted `ecosystem-simulation.md`'s already-locked,
tested formula and States table, which regress `growth_stage` back toward
`0` on decay. User confirmed the regress-toward-`0` model is canonical;
Core Rule 8 rewritten to match, reframing the Anti-Pillar guarantee around
"`0`/DORMANT is not a fail state" rather than index-monotonicity — no
change required in `ecosystem-simulation.md`. **Pillar 4 creature-variety
gap resolved**, reversing the prior round's deferral: `game-designer`
established the deferral's precondition (Creature Behavior committing to
consume a differentiator) has now resolved in favor of the gap being real,
since Creature Behavior is authored and confirmed to use only global,
type-independent wander parameters. `creative-director` ruled in a new
`pause_duration_min/max` field on `CreatureTypeDef` (Core Rule 5,
`definition_validity`, Edge Cases, Tuning Knobs, new AC4c) — the minimum
categorical differentiator serving Pillar 4 without adding AI complexity
(Pillar 3 stays intact). Flagged as still requiring a companion edit in
`creature-behavior.md` (tracked in Open Questions, not fixed in this pass
since it's outside this document). **Boundary-value ACs added**: `qa-lead`
found ACs 2b/3/3a/3b/3c/4a asserted only grossly-invalid values, never the
actual valid/invalid edge the project's Testing Standards require —
boundary-pair clauses added to each; AC4's `movement_speed=0` boundary
deliberately left unasserted pending the pre-existing open legality
question rather than invented. **GUT `push_warning()` capture narrowed**:
`godot-specialist` confirmed via WebSearch that GUT ≥9.6.0 added
`assert_push_warning()` compat-tagged for 4.7.1, so the 12 "(advisory)" AC
qualifiers and the Edge Cases intro no longer describe an open capability
question — only confirming the installed GUT version remains open, now
stated as such. Two non-blocking prose corrections also applied:
`RATE_MAX`'s rationale (it doesn't distinguish corrupted data by magnitude
alone — Flower's real locked `decay_rate=4` already zeroes `growth_stage`
in one tick by design) and Core Rule 7's `.uid`/`.import` sidecar-filtering
claim (overstated for an all-`.tres` directory, per `godot-specialist`). A
new, previously-uncaught gap was documented rather than fixed:
`spawn_reference_validity` cannot detect a cyclic creature-reference
soft-lock (`systems-designer`) — added to Edge Cases and Open Questions as
a known limitation, not in MVP's actual data.)*

*(Re-reviewed via `/design-review` on 2026-08-03 (round 8) — full
specialist round: `game-designer`, `systems-designer`, `qa-lead`,
`godot-specialist`, `creative-director`. Verdict: NEEDS REVISION → 7
blockers resolved below, all text-level corrections, no design rework.
**GUT version floor corrected**: `godot-specialist` (WebSearch-verified
against GUT's own CHANGES.md) found the previous round's "GUT ≥9.6.0 is
compat-tagged for Godot 4.7.1" claim was wrong — 9.6.0 is tagged for Godot
4.6; the 4.7.1-compatible line is 9.7.x. Corrected in the Edge Cases intro
and Open Questions. **Bundled ACs split**: the 12 ACs mixing a "(required)
excluded..." clause with an "(advisory) warning logged..." clause in one
sentence were split into exclusion-only ACs plus a new "Warning-Logging
Assertions" table, so no exclusion assertion's testability depends on
confirming an external tool version (`qa-lead`). **`RATE_MAX` rationale
fixed**: the Edge Cases bullet claimed exceeding `RATE_MAX` is what
"zeroes/maxes `growth_stage` in a single tick" — but Flower's own locked
MVP data already does that well under `RATE_MAX`, a direct
self-contradiction `systems-designer` traced between Edge Cases and the
Formulas section's own prior correction; rewritten to state plainly that
`RATE_MAX`/`MOVEMENT_SPEED_MAX`/`PAUSE_DURATION_MAX` are corruption-scale
gates only, not tuning-sanity checks. **Missing boundary ACs added**: new
AC4d/AC4e cover `pause_duration`'s negative and `>PAUSE_DURATION_MAX`
boundaries, previously untested unlike every other bounded field
(`qa-lead`). **AC4 fixed**: now asserts today's spec behavior
(`movement_speed=0` is valid, per `definition_validity`'s own inclusive
lower bound) instead of leaving the entire boundary unasserted; the
separate design-legality question stays open. **AC7 fixture table added**:
the AC previously pinned only ids and `growth_pattern`, leaving every other
fixture field (moisture bands, rates, `visual_stages` length,
`movement_speed`, `pause_duration`, `footprint_size`, `visual_ref`)
unspecified and the fixture unbuildable (`qa-lead`) — a full value table
was added, sourced from already-locked data in `ecosystem-simulation.md`/
`creature-behavior.md`/`entities.yaml` where it exists, with `pause_duration`
and `visual_ref` values explicitly marked illustrative-only. **"Categorical"
overstatement corrected**: `game-designer` argued `pause_duration_min/max`
was mischaracterized in the prior round (by `creative-director`, this
document's own ruling) as "the categorical differentiator" closing the
Pillar 4 plant/creature variety gap — it's a continuous knob stacked on the
same tempo axis as `movement_speed`, not a categorical split like
`growth_pattern`; Core Rule 5 and Open Questions corrected to say it
narrows the gap, not closes it. Two non-blocking gaps documented rather
than fixed: `display_name` has no validity check on any type (no confirmed
consumer yet) and `spawn_conditions`' expression is never checked against
`required_ids` for consistency (out of Content Data's reach by design) —
both added to Formulas/Open Questions as tracked, not-blocking gaps. A
missing `footprint_size ≤ 0` Edge Cases bullet (previously tested by AC3
with no matching prose) was also added for symmetry.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round:
`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`,
`creative-director`. Verdict: NEEDS REVISION → 6 blockers + 3 non-blocking
items resolved below, all text-level, no design rework. **Formulas
worked-examples fixed**: the shared "valid"/"band too narrow" examples
mixed fields from all three Def types into one hypothetical definition,
contradicting the per-type-scoping clause one paragraph above and
corresponding to no buildable fixture (`systems-designer`) — split into one
example per actual Def type. **AC7 fixture table corrected**: the table
assigned a `visual_ref` value to PlantTypeDef rows despite Core Rule 4
defining PlantTypeDef without that field (`qa-lead`) — removed for plants,
and `visual_stages`' previously length-only entries given actual per-index
placeholder content so the fixture is genuinely fully specified.
**AC4b rewritten**: its disjunctive wording was satisfiable by a
non-iterative single-pass implementation, giving zero test pressure toward
the exact bug `spawn_reference_validity`'s fixpoint design exists to
prevent (`qa-lead`) — replaced with a concrete 2-hop cascade fixture
(`tests/fixtures/content_data/spawn_cascade_set/`) that only a true
iterative implementation satisfies. **AC5 given its own fixture path**
(`duplicate_id_set/`) so it can no longer collide with AC7's `mvp_set/`
exact-set-equality assertion (`qa-lead`). **Three new boundary-pair ACs
added**: moisture's own `0`/`100` domain bound (AC2a, distinct from the
band-width bound AC2b already covered), `pause_duration_min ==
pause_duration_max` as a valid zero-width pause (AC4c), and
`pause_duration = 0` as a valid lower boundary (AC4d) — all previously
missing despite every sibling bounded field receiving this treatment in
earlier rounds (`qa-lead`, `systems-designer`, independently). **Pillar 4
creature-variety gap ruled RESOLVED**, overturning 4+ prior rounds'
repeated deferral: at 2-creature MVP scope, species identity alone already
delivers Pillar 4 distinctness; `creative-director` closed the thread,
reopening only if the roster grows large enough for two creatures to share
both species and silhouette family. **Two non-blocking prose fixes**:
`growth_pattern`'s Core Rule 4 entry gained a one-line design-intent note
per enum value (`game-designer`) — a stopgap until Diorama Rendering
formally owns the interpretation; and `spawn_reference_validity`'s "at most
3 passes" framing was clarified as a worst-case ceiling, not what the
actual MVP fixture does (1 pass) (`systems-designer`). Player Fantasy
section's distinctness claim reworded from asserted-as-delivered to
aspirational-for-the-unconsumed-field, since `pause_duration_min/max` is
validated here but not yet read by `creature-behavior.md` (`game-designer`)
— not player-visible today, since species identity alone already carries
Pillar 4 at 2 creature types. Two qa-lead findings (GUT not installed;
missing dependency-injectable load entry point) were reviewed and ruled
out of scope for this document — the former belongs to `/test-setup`, the
latter to the pending authoring-format ADR — though the concrete
fixture-collision risk they surfaced was fixed directly (see AC5 above).
`entities.yaml`'s `definition_validity.expression` field also received a
one-line "shape only, see notes" prefix so a reader translating the
registry field literally is pointed at the per-type carve-out already
documented in its own `notes:`.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — full specialist round on
`ecosystem-simulation.md` (`game-designer`, `systems-designer`, `qa-lead`,
`creative-director`) surfaced a real design defect there: moisture-only
tolerance bands mathematically collapsed into a shared lockstep zone,
undermining Core Rule 8's possibility-space depth requirement. Fix (ruled
by `creative-director`, ecosystem-simulation.md is the source document):
add a second, independent, non-player-controllable `light_level` variable.
This document gained the companion field — `PlantTypeDef.light_tolerance_min/max`
(Core Rule 4), extended `definition_validity` (new `LIGHT_BAND_MIN_WIDTH`
constant, mirroring `BAND_MIN_WIDTH`'s exact pattern), a new Edge Cases
rejection bullet, a new Tuning Knobs row, a new consolidated boundary AC
(AC2c), and updated AC7's fixture table with real per-plant light bands.
Also fixed a bidirectional-dependency gap: Persistence/Save was missing
from this document's own Downstream dependents list despite already
listing Content Data on its side. A stale illustrative example (RATE_MAX's
Edge Cases justification, previously citing Flower's `decay_rate=4`) was
corrected after that value was retuned to `1` in the same
`ecosystem-simulation.md` review — Flower's old decay rate one-tick-wiped
it against `max_stage=3`, a real anti-pillar violation, not just an
extreme-but-legal tuning value.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — full specialist round
across content-data.md, ecosystem-simulation.md, persistence-save.md,
object-placement.md as a set: `game-designer`, `systems-designer`,
`qa-lead`, `godot-specialist`, `creative-director`. Verdict: the round-9
review log (`design/gdd/reviews/content-data-review-log.md`) had already
marked this document APPROVED conditioned on 3 specific fixes, but `qa-lead`
found only 1 of 3 had actually landed in this file's body: the Warning-
Logging Assertions table still ended at row 5 with no 8a/8b/8c rows, and
AC7's fixture-provenance paragraph never classified `spawn_conditions`/
`required_ids` as locked-vs-illustrative data. Both landed this round (see
Warning-Logging Assertions and AC7's fixture-provenance paragraph above) —
the document's header status is corrected from "pending review" to
"Approved" to match, and the review log below gets a new entry confirming
this. No design rework — text-only completion of already-agreed fixes.)*

*(Touched by `/design-review` on 2026-08-04 — round 11, as part of the full
specialist round on content-data.md, ecosystem-simulation.md,
persistence-save.md, object-placement.md as a set. No blocking findings
against this document's own content this round — `systems-designer` found
an `object-placement.md` formula issue whose root cause traced back to this
document's `FOOTPRINT_MAX` constant being coupled to `object-placement.md`'s
jar geometry only by an unenforced code comment (an already-tracked Open
Question here). The fix landed entirely in `object-placement.md` (a stated
domain precondition + invariant); this document's own `FOOTPRINT_MAX`
definition is unchanged, only its Open Questions entry is updated to record
the resolution. **Status remains Approved.**)*

## Open Questions

- **Authoring format**: Should type definitions be authored as native Godot
  `.tres` Resource files directly in the editor, or as external data
  (JSON/CSV) imported at build time? This is really an implementation
  decision (→ becomes an ADR), but it affects whether a designer without
  editor access can tune values — worth resolving before `/architecture-decision`
  for this system. Owner: technical-director. Target: before Object Placement
  or Ecosystem Simulation GDD authoring begins (they'll assume a format).
- **Authoring-time validation**: Should `definition_validity` also run as an
  editor-time check (e.g., an `@tool` script or import plugin) so bad data is
  caught while authoring rather than only at game load? Owner: tools-programmer.
  Target: technical setup phase.
- **Per-instance creature identity**: The game concept's Key Dynamics promise
  players will "start recognizing individual inhabitants... and treat them as
  consistent little characters," but `CreatureTypeDef` only defines shared
  *type* data (every Snail has the same `movement_speed`, `visual_ref`,
  etc.) — nothing here or in any declared dependent currently models what
  makes one specific creature instance distinguishable or persistent across
  visits. This is legitimately out of scope for Content Data (Core Rule 2 —
  instance state lives with the systems that own it), but no downstream GDD
  currently owns it either. **This deferral currently rests on an unstated
  assumption — single-instance-per-creature-type at MVP** (inferred from
  Ecosystem Simulation's binary ABSENT/PRESENT state, never asserted
  explicitly by any document) — the game-concept's own Alpha tier
  ("expanded creature roster") will break that assumption the moment a
  second Snail can exist simultaneously. Owner: Creature Behavior (the
  system that will own creature instance state). Target: before Creature
  Behavior's GDD is marked reviewed — flagged here so it isn't silently
  lost.
- **Pillar 4 creature-variety gap — RESOLVED as a non-issue at MVP scope
  (2026-08-03 re-review, `creative-director` ruling, overturning prior
  rounds' deferral).** At 2-creature-type MVP scope, Snail and Moth are
  already maximally distinct via species identity and `visual_ref` alone
  (entirely different sprites), independent of any numeric tuning —
  `game-designer` argued this thread had been re-litigated across at least
  4 prior rounds solving a problem that doesn't actually exist yet at this
  scale, and `creative-director` agreed, closing it. **This reopens only if
  the creature roster grows large enough (~4+ types, per Alpha's "expanded
  creature roster") that two creatures could plausibly share both species
  *and* silhouette family** — at that point a categorical/visual
  differentiator (idle pose, path shape, etc.) would become worth
  revisiting. Not a concern for MVP's 2 types. `pause_duration_min/max`
  remains a legitimate secondary richness knob regardless (see the
  companion-edit item retained below), just no longer framed as closing a
  "gap." The history below is retained for record; treat it as superseded
  by this ruling, not as still-open litigation. Prior rounds deferred this pending Creature Behavior
  committing to consume a differentiator; Creature Behavior is now authored
  and confirmed (by `game-designer`) to use one global pause range, one
  destination-sampling algorithm, and one state machine across both
  creature types — `movement_speed` was the only per-type variable reaching
  behavior. The deferral's precondition resolved in favor of the gap being
  real. `creative-director`'s ruling: `CreatureTypeDef` gains
  `pause_duration_min/max` (Core Rule 5, `definition_validity`), giving
  Snail/Moth a second numeric knob without adding decision-making
  complexity. **Correction (round-8 re-review, `game-designer` +
  `creative-director`):** this bullet and Core Rule 5 previously called
  `pause_duration_min/max` "the categorical differentiator" that "closes"
  this gap — that overstated it. It is continuous, not categorical, and
  stacks on the same tempo axis `movement_speed` already occupies; it
  narrows the plant/creature variety asymmetry, it does not close it the
  way `growth_pattern`'s silhouette split does for plants. A genuine close
  would need a categorical or visual differentiator (idle pose, path
  shape, etc.) — deferred to whoever revises Creature Behavior/Diorama
  Rendering next, not required of this document. **Still open (both
  true regardless of the correction above):** `creature-behavior.md` needs
  a companion edit to actually consume `pause_duration_min/max` (it
  currently specifies a single global `random_uniform(2.0, 5.0)` pause
  range in its Formulas section) — this document can only supply the data,
  not force the consuming system to read it. Owner: systems-designer /
  ai-programmer (creature-behavior.md's authors). Target: before Creature
  Behavior is re-marked reviewed. Separately, `game-designer` flagged that
  `growth_pattern` itself has no confirmed consumer yet either — not read
  by `ecosystem-simulation.md` — **RESOLVED (2026-08-05,
  `diorama-rendering.md` authored)**: that GDD's Core Rule 10 and its
  Growth Pattern Scaling formula now consume `growth_pattern` directly
  (a per-axis scale transform, distinct floor values per
  carpet/clump/climb), confirming the plant-side variety claim.
- **`spawn_conditions`/`required_ids` drift is undetected by any system**
  (`systems-designer`, 2026-08-03 round-8 re-review): `spawn_reference_validity`
  only checks that every id in `required_ids` exists — nothing checks that
  `spawn_conditions`' actual boolean expression only references ids that
  are also listed in `required_ids`. A content author could add a new
  reference to `spawn_conditions` and forget to add it to `required_ids`
  (or vice versa) and nothing would catch it, since Content Data never
  parses the expression and Ecosystem Simulation only ever sees whatever
  Content Data already resolved. Owner: whichever system ends up parsing
  `spawn_conditions` (likely Ecosystem Simulation, since it already
  evaluates the expression at runtime). Target: before Ecosystem
  Simulation's implementation, if this is judged worth a runtime assertion
  rather than a content-authoring discipline.
- **`spawn_reference_validity` cannot detect cyclic spawn dependencies**
  (`systems-designer`, 2026-08-03 review): documented as a known Edge Cases
  limitation rather than fixed this round — see Edge Cases for the concrete
  Snail↔Moth cycle example and its soft-lock consequence. A dedicated
  cycle-detection pass is future scope if content authoring ever needs it.
  Owner: systems-designer. Target: revisit if/when creature `required_ids`
  chains grow past the MVP's 2 `CreatureTypeDef`s.
- **`.tres` resource caching risk**: If the pending authoring-format ADR
  (below) picks native `.tres` Resources, `ResourceLoader.load()` caches by
  path by default — every registry consumer would share the literal same
  instance, so an accidental mutation corrupts a shared singleton for every
  reader, not a local copy. This turns Core Rule 2's "convention" into a
  real correctness dependency and should be stated explicitly in that ADR
  regardless of which format wins. **Concrete mitigation candidates**
  (`godot-specialist`, 2026-08-03 review): the risk isn't the registry
  itself sharing one instance per `id` (that's the intended design, per
  Core Rule 7) — it's code *outside* the registry (tests, tools) calling
  `load()` on the same path and unknowingly getting the live shared
  instance. `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`
  for an independent copy, or `duplicate_deep()` (added in Godot 4.5,
  preferred over `duplicate(true)` on 4.7) for duplicating an
  already-loaded instance in test fixtures, are the relevant tools. Owner:
  technical-director. Target: alongside the authoring-format ADR below.
- **`FOOTPRINT_MAX` cross-GDD coupling — RESOLVED as a stated invariant
  (2026-08-04, `/design-review` round 11, `systems-designer` finding,
  closed by an edit to `object-placement.md`, not this document).**
  `FOOTPRINT_MAX` (20.0) is derived from Object Placement's jar-floor
  `ry=60` but was enforced only by a code comment — the concrete risk this
  posed: Object Placement's `in_bounds` formula (and its two verbatim
  reuses in `persistence-save.md`/`creature-behavior.md`) divides by zero,
  or silently miscomputes, once `footprint_size ≥ min(rx,ry)`, so an
  unenforced relationship between these two constants was a live landmine
  for any future geometry or constant change, even though no valid MVP
  data reaches it today. `object-placement.md`'s own Formulas section now
  states `fp < min(rx,ry)` as an explicit domain precondition and
  `FOOTPRINT_MAX < min(rx,ry)` as a named invariant, rather than leaving
  the relationship implicit. No change required in this document —
  `FOOTPRINT_MAX`'s own definition and value are unaffected; this entry is
  retained (not deleted) as the record of where the coupling risk was
  first flagged and where it was ultimately closed, per this project's
  own registry convention of never deleting entries.
- **GUT `push_warning()` capture — narrowed, not fully resolved; version
  floor corrected (2026-08-03 round-8 re-review, `godot-specialist`,
  WebSearch-verified against GUT's own CHANGES.md):** GUT added
  `assert_push_warning()`/`assert_push_warning_count()` in version 9.6.0 —
  the *capability* question is answered. **Correction:** a prior round
  claimed 9.6.0 itself is compat-tagged for Godot 4.7.1; it is not — 9.6.0
  is tagged for Godot 4.6, and the 4.7-compatible line is **9.7.x**. What
  remains open: confirm the project's *actually-installed* GUT release
  meets the **≥9.7.0** floor. Once confirmed, every Warning-Logging
  Assertion (see Acceptance Criteria) should be treated as required on the
  same footing as its paired exclusion criterion. Owner: qa-lead /
  devops-engineer. Target: `/test-setup` (technical setup phase).
- **`movement_speed == 0` legality**: `definition_validity` currently
  allows `movement_speed = 0` (a creature that never moves) while
  `footprint_size` must be strictly `> 0`. Confirm this asymmetry is
  intentional — is a stationary creature a valid MVP data value, or should
  the lower bound tighten to match footprint's strict inequality? Owner:
  game-designer. Target: before Creature Behavior content authoring.
