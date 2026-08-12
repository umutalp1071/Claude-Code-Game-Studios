# Persistence/Save

> **Status**: Approved — round 12 and round 13 blockers resolved (accepted without a formal specialist re-review round; user decision, see trailing review notes); 1 stale cross-reference fixed 2026-08-05 (`/review-all-gdds` round 2, text-only, see Formulas/Open Questions `CONDITION_STREAK_MAX` note). **Both previously-BLOCKING Open Questions (HTML5/IndexedDB write reliability; `visibilitychange`/`pagehide` reachability) resolved 2026-08-10 by `docs/architecture/adr-0005-persistence-save-web-storage-strategy.md`**, from the Web Export Spike's Gate B evidence (desktop Chrome only — see Open Questions below for the exact scope and the named WebKit/iOS Safari residual risk that decision carries forward, not silently closes).
> **Author**: user + systems-designer
> **Last Updated**: 2026-08-10 — Open Questions: HTML5/IndexedDB write
> reliability and `visibilitychange`/`pagehide` reachability resolved by
> `adr-0005-persistence-save-web-storage-strategy.md` (Web Export Spike Gate
> B, desktop Chrome only; WebKit/iOS Safari recorded as an explicit residual
> risk, not tested); Core Rule 5's reachability note updated to match;
> previously 2026-08-09 — new `last_known_position` blob field, `save_blob_validity` clause, and AC7b added (cross-GDD review finding, companion to `ecosystem-simulation.md`'s new Core Rule 12); also `CONDITION_STREAK_MAX` recomputed 5→25 now that `ecosystem-simulation.md`'s pre-implementation tuning pass picked `N_departure_ticks=25`; previously 2026-08-05 (`/review-all-gdds` round 2 — `CONDITION_STREAK_MAX` coupling citation corrected to match `ecosystem-simulation.md`'s round-16 `N_departure_ticks` range widening)
> **Implements Pillar**: Pillar 2 (Nothing Is Ever Finished, Nothing Is Ever Late) — the "return day after day" hypothesis depends on state surviving between sessions
> **Creative Director Review (CD-GDD-ALIGN)**: Full specialist round completed 2026-08-05 (`game-designer`, `systems-designer`, `qa-lead`, `godot-specialist`, `creative-director`); round 13 fixes (from `/review-all-gdds`) applied same day — 8 blockers total resolved across both rounds (see trailing review notes)

## Overview

Persistence/Save is the layer that makes the terrarium survive between
sessions: it serializes and restores `jar_moisture`, each plant's
`growth_stage`, each creature's PRESENT/ABSENT state, the placed object's
position, and Time & Drift's `last_visit_timestamp`, writing to
browser-persisted storage on session end and reading it back on session
start. It exists because none of the actual gameplay systems own any
concept of "surviving a browser close" — without this layer, every visit
would restart from the jar's authored initial state, making the entire
"return day after day" hypothesis untestable. Players never interact with
this system directly; it's the invisible floor every other system's state
stands on.

## Player Fantasy

Persistence/Save has no direct player fantasy — it's pure infrastructure
the player never sees. What the player *feels* is the absence of its
failure: opening the game tomorrow and finding the same jar, not a fresh
one. This is the quiet precondition for every other pillar in the game —
Pillar 2's "the terrarium waits for you exactly as you left it" is a lie
without this system working correctly every single time. If this system
fails, the player-facing symptom is severe and immediate: the jar resets,
care is erased, and the entire premise of the game collapses on the very
first return visit.

*(`creative-director` not consulted — Lean mode; this section is not a
high-risk section per the review-mode gate rules.)*

## Detailed Design

### Core Rules

1. **Blob completeness principle (added 2026-08-04, `/design-review` round
   11 — `creative-director` ruling):** the save blob must contain every
   value Ecosystem Simulation (or any other upstream system) carries across
   a tick or session boundary — not just visibly-rendered state, but any
   counter, accumulator, or direction flag whose value on tick `N` depends
   on tick `N-1` (a value fully generated *and* consumed within one
   session, never depended on by a later tick, is not "carried across a
   boundary" and is not obligated here — see Formulas for the confirmed
   example, Ecosystem Simulation's detail-event flag). Adding such a value
   to an upstream system's own GDD
   obligates a matching blob field here, a `save_blob_validity` clause, and
   an Acceptance Criterion, in the same change that adds it upstream — this
   is a standing rule this document is checked against, not a one-time list
   to keep manually in sync. This exists because the same class of gap
   (a new piece of carried-across-tick state shipping upstream without a
   matching blob field) has now been found and patched twice before under
   the old enumerated-list model (`light_level`/`light_direction` in the
   prior round; `optimal_hold_ticks`/`condition_streak_ticks` this round,
   see below) — an enumerated list depends on someone remembering, and
   nine-plus rounds of evidence say that doesn't reliably hold.

   **Concretely, as of this round, that principle currently instantiates
   as:** on true session end (close/unload — reusing Time & Drift's
   existing "not backgrounding" definition), Persistence/Save serializes
   one save blob containing: `schema_version` (int, tagging the blob with
   the format version it was written under — added 2026-08-05
   `/design-review`, round 12, `systems-designer`/`qa-lead` independently
   convergent finding: `save_blob_validity`'s own first clause already
   checked this field, and Edge Cases/AC9 already discussed it at length,
   but no Core Rule ever actually listed it as a field written to the
   blob — a real instance of the exact silent-omission class this
   blob-completeness principle exists to catch, found in this principle's
   own founding rule); `jar_moisture`; `light_level` and
   `light_direction` (added 2026-08-03, `/design-review` — Ecosystem
   Simulation's new possibility-space-depth variable, see that GDD); an
   array of per-plant `{type_id, growth_stage, optimal_hold_ticks}`; an
   array of per-creature `{type_id, state, condition_streak_ticks, position
   if PRESENT, last_known_position}` (see below for the last field, added
   2026-08-09); the placed object's `{type_id, position}`; Time &
   Drift's `last_visit_timestamp`; and Ambient Audio's `ambient_volume`/
   `muted` (added 2026-08-11, `/architecture-decision` ADR-0012 finding —
   another instance of this principle's own founding pattern: this
   document's Dependencies section already described Persistence/Save as
   reading/writing these two fields since `ambient-audio.md` was authored
   2026-08-05, but this Core Rule's own field list never listed them
   until now).

   **`ambient_volume`/`muted` are deliberately excluded from
   `save_blob_validity`'s all-or-nothing gate** (see Formulas below) —
   `ambient-audio.md`'s own Edge Cases already specify defensive clamping
   of a corrupted value independent of this document's blob-discard
   behavior, the same treatment `last_visit_timestamp` already gets for
   the same reason (a cosmetic preference must not discard
   `jar_moisture`/`growth_stage`/etc. alongside it).

   **`last_known_position` added 2026-08-09** (`/review-all-gdds` cross-GDD
   finding, another instance of this principle's own founding pattern —
   found upstream in `ecosystem-simulation.md`'s new Core Rule 12 before a
   matching blob field existed here): Ecosystem Simulation now tracks one
   `last_known_position` value per creature, written by Creature Behavior
   every frame a live instance exists, that survives regardless of
   PRESENT/ABSENT state — unlike this blob's existing `position` field,
   which is only ever present/meaningful `if PRESENT`. Without persisting
   it, a creature that goes ABSENT, gets saved, and is reloaded in a later
   session would lose its true last-observed position, forcing
   `last_known_position` back to Ecosystem Simulation's `(0, 0)` default
   and defeating the entire point of that mechanism for exactly the
   multi-session-absence case it exists to serve. Deliberately a separate
   field, not a repurposing of `position` — the two have different
   validity conditions (`position` only exists `if PRESENT`;
   `last_known_position` always exists), and conflating them would either
   lose the PRESENT-only field's cleaner semantics or force
   `last_known_position` to inherit `position`'s in-bounds validity
   constraint. Both share the same in-bounds data-corruption gate approach
   (see Formulas/`save_blob_validity`) — the constraint is appropriate for
   both fields, this paragraph just clarifies they are tracked separately,
   not merged.

   **`optimal_hold_ticks`/`condition_streak_ticks` added 2026-08-04
   `/design-review`** (this is the first application of the blob-
   completeness principle above, not a special case carved out for it):
   both are real per-instance Ecosystem Simulation state that was already
   being computed and used, just never persisted. `optimal_hold_ticks` (one
   per plant instance) gates the Pillar 4 rare-bloom detail event —
   `p_detail` only goes nonzero once it reaches 6 (**corrected 2026-08-05
   `/design-review`, round 12, `qa-lead` finding**: this threshold was
   lowered from 10 to 6 in `ecosystem-simulation.md`'s own round 12,
   before this document's round 11 was even written — this stale
   cross-reference cited the pre-correction value; see
   `ecosystem-simulation.md` Formulas). `condition_streak_ticks` (one per
   creature instance, new name for the previously-unnamed debounce counter
   behind Core Rules 6/7 of that GDD) tracks consecutive ticks toward
   `N_spawn_ticks`/`N_departure_ticks` — contextually meaning "consecutive
   ticks `spawn_conditions` has held true" while the creature is ABSENT, or
   "consecutive ticks it has held false" while PRESENT; it resets to `0` on
   any ABSENT↔PRESENT transition, the same moment the debounce it was
   counting toward resolves.

   Neither was previously in this blob, so every session boundary (true
   end or the backgrounding write, Core Rule 5) silently zeroed both.
   Concrete effect on `optimal_hold_ticks`: this systematically suppressed
   the rare-bloom event specifically for players following the game's own
   intended daily-visit cadence — typical daily catch-up batches are 8–12
   ticks (`time-drift.md`'s own calibration), which often lands just short
   of the 10-tick threshold, so the counter kept getting truncated before
   completion on exactly the cadence the game is designed around. Concrete
   effect on `condition_streak_ticks`: for a frequent-short-visit play
   pattern (e.g. `time-drift.md`'s own documented 3-hour-recheck example,
   which yields just 1 tick), the counter could never accumulate across a
   session boundary at all — silently narrowing "3 consecutive ticks" (the
   documented `N_spawn_ticks` guarantee) to "3 consecutive ticks within one
   visit," a permanent lockout for that cadence rather than a delay, and a
   real Pillar 2/3 violation, not a cosmetic gap. `creative-director` ruled
   both persisted — resolving a specialist disagreement on the debounce
   counter specifically (`game-designer` rated it advisory, since typical
   daily batch sizes comfortably clear both thresholds in one batch;
   `systems-designer` rated it blocking, since the frequent-revisit persona
   can never accumulate a streak across a boundary at all — a permanent
   lockout, not a delay, which is what made the blocking call decisive).
2. **This resolves Time & Drift's open question**: Persistence/Save is the
   sole owner of the storage location for `last_visit_timestamp` — Time &
   Drift's read/write calls for that value route through this system's
   API, not a separate self-contained store.
3. On session start, Persistence/Save reads the save blob (if one exists)
   and restores state in order: Ecosystem Simulation's `jar_moisture`/
   `growth_stage`/creature state, then Object Placement's object position,
   then Time & Drift's `last_visit_timestamp` — all restored *before* Time
   & Drift computes its catch-up batch.
4. If no save blob exists (first-ever session), every system initializes
   to its authored default — the same "first session" case Content Data
   and Time & Drift already define. Persistence/Save does nothing in this
   case rather than writing an empty placeholder.
5. Saves are **not** continuous during an ACTIVE session, and there is no
   periodic/interval autosave. A write fires at two points: true session end
   (close/unload, matching Time & Drift's own session-end definition), and
   the browser tab being hidden/backgrounded (`visibilitychange` to hidden,
   or `pagehide` — the browser's last reliable callback before an
   uncontrolled termination). **Corrected 2026-08-04 `/design-review`**: an
   earlier version of this rule wrote only on true session end; `qa-lead`
   flagged (as AC10, now rewritten) that a crash or forced tab-kill under
   that design loses the entire current visit's tending with zero mitigation
   beyond the already-tracked IndexedDB-reliability question — a real
   design gap for a game whose Anti-Pillar is NOT punishing, not just an
   engineering risk. `creative-director` ruled: add the backgrounding write.
   **This does not change what counts as a "visit"** — per
   `time-drift.md`'s own Core Rule 8, `last_visit_timestamp` still updates
   only at true session end, never on backgrounding, so Time & Drift's
   tick-catchup semantics are unaffected.
   A backgrounding write simply persists current state more often; it is
   not a second kind of session boundary.
   **Reachability resolved 2026-08-10 by `docs/architecture/adr-0005-persistence-save-web-storage-strategy.md`**
   (previously flagged unverified 2026-08-04 `/design-review`, round 11,
   `godot-specialist` finding — see Open Questions for the full resolution
   text and its Chrome-desktop-only scope). The reachability concern is
   resolved architecturally, not just measured: the backgrounding write is
   implemented as a pure-JS `visibilitychange`/`pagehide` listener with
   **zero GDScript execution required at the moment of hiding** — a JS-side
   mirror of the save blob, kept current via tending/placement gesture
   commits, is what the listener persists, sidestepping the WASM-main-loop-
   suspended risk entirely rather than depending on the engine getting a
   frame while hidden. The write-on-mutation fallback drafted below was
   **not** adopted — it remains documented as a rejected alternative, not a
   fallback still in play.
6. The save write must reliably complete before the browser actually
   terminates the page — this is precisely the HTML5/IndexedDB knowledge
   gap flagged in the feasibility brief. This GDD does **not** assume it
   "just works"; it's captured as an Open Question requiring technical
   verification before implementation.
7. **Last-known-good fallback (added 2026-08-05 `/design-review`, round
   12 — resolves an Anti-Pillar tension this round's review surfaced,
   `game-designer` finding, `creative-director` ruling: user selected the
   last-known-good option over documenting the tradeoff unchanged or
   splitting fallback behavior by cause).** A single full-discard-to-defaults
   on any `save_blob_validity` failure is the punishing loss the Anti-Pillar
   (NOT punishing) forbids, applied to weeks of tending on the strength of
   one corrupted field — most commonly devtools tampering or a genuinely
   corrupted write. **Scope corrected 2026-08-05 `/design-review`, round
   13** (`systems-designer` finding): this fallback does **not** protect
   against a content-balance edit (a renamed `type_id`, a narrowed
   `max_stage`) — `save_blob_validity`'s `type_id`-existence and
   `growth_stage`-range clauses are checked against the *current* Content
   Data registry, so both the current blob and the last-known-good blob
   (written under the same, now-superseded content) fail identically; this
   fallback tier cannot recover from that cause, only from tampering or
   corruption introduced *after* the last-known-good blob was itself
   written and validated. That cause remains owned entirely by the Save
   Schema Migration Open Question, not this Core Rule — see Edge Cases for
   the corrected framing. Persistence/Save therefore retains **two**
   stored blobs, not one: the **current** blob (most recently written) and
   a **last-known-good** blob (the most recent blob that *passed*
   `save_blob_validity` on a prior load). On write: before the new blob
   replaces current, if the outgoing current blob is itself known-valid
   (i.e., it was the blob most recently loaded successfully, or has since
   been validated), it is promoted to last-known-good first — so
   last-known-good always trails one successful load behind current, never
   behind an unvalidated write. On load: if the current blob fails
   `save_blob_validity`, Persistence/Save attempts to load the
   last-known-good blob instead, re-running the same validity check
   against it; only if *that* also fails (or doesn't exist) does the system
   fall back to default-init (Core Rule 4). For the tampering/corruption
   case this fallback actually covers, it bounds worst-case loss to
   whatever changed between the last two successful loads — typically one
   visit's tending — rather than the entire save history, **without
   weakening the all-or-nothing validity gate itself**: field-level partial
   restoration is still rejected at every tier (see Formulas); only
   whole-blob substitution (current → last-known-good → defaults) is
   permitted. A load that falls back to last-known-good is still a
   **discard** of the immediately-prior write and logs a warning distinct
   from the "no valid blob at all" case, so this stays diagnosable rather
   than silently masking a real corruption source.
8. **Save-confirmation signal, corrected to fire on next load, not on
   write (added 2026-08-05 `/design-review`, round 12; corrected same-day,
   round 13 — `game-designer`/`systems-designer` independently found the
   original version fires only at true session-end or tab-backgrounding
   (Core Rule 5), moments the player can never actually see — the page is
   either unloading or the tab is hidden at exactly the two points the cue
   was specified to fire, making it unobservable at both its trigger
   points. `creative-director` ruling: user selected deferring the
   confirmation to the next session start over adding a new in-session
   write trigger).** On session start (Core Rule 3), if a save blob was
   successfully restored — whether from the current blob or the
   last-known-good fallback (Core Rule 7) — a brief, easy-to-miss
   confirmation cue fires once, before or as the jar becomes interactive
   (e.g., "welcome back — your jar was saved"). This GDD locks only that
   some non-silent, non-intrusive confirmation must exist — the exact
   visual treatment (icon, fade, ambient cue) is Diorama Rendering's
   design call once that system is authored, not specified here. This
   exists because Pillar 2's promise ("the terrarium waits for you exactly
   as you left it") currently has **no observable confirmation**:
   save-commit reliability is still an open technical question (see Open
   Questions — IndexedDB write reliability, `visibilitychange`/`pagehide`
   reachability), and without this signal a player has no way to know
   their last visit's tending actually survived. Firing on successful
   *restore* rather than on the write itself sidesteps the observability
   problem entirely — session start is always live and rendered, unlike
   either write trigger. **Does not fire** on a first-ever session (Core
   Rule 4 — no blob exists, nothing to confirm) or when the blob fails
   validity at both fallback tiers and default-init occurs (Core Rule
   7/Edge Cases) — a false-positive "saved" confirmation on a blob that
   was actually discarded would be worse than no signal at all, since it
   would actively mislead rather than merely stay silent.

### States and Transitions

| State | Trigger | Next State |
|---|---|---|
| (app loads) | — | LOADING |
| LOADING | current blob read and passes `save_blob_validity` | RESTORED — save-confirmation cue fires (Core Rule 8, corrected round 13 to fire on restore, not write) |
| LOADING | current blob fails `save_blob_validity`, last-known-good blob read and passes `save_blob_validity` (**added 2026-08-05, round 12 — Core Rule 7**) | RESTORED (from last-known-good, not current) — save-confirmation cue fires (Core Rule 8) |
| LOADING | current and last-known-good blobs both fail `save_blob_validity` (or neither exists) | RESTORED (from authored defaults, Core Rule 4) — no cue fires (nothing was actually restored) |
| RESTORED | (gameplay proceeds normally) | RESTORED |
| RESTORED | tab hidden/backgrounded (`visibilitychange`→hidden, or `pagehide`) | RESTORED (self) — save write fires (promoting the outgoing current blob to last-known-good first, Core Rule 7), `last_visit_timestamp` unchanged, session not ended |
| RESTORED | true session end (close/unload) | SAVING |
| SAVING | write completes (or is reliably queued) | (session terminates) |

### Interactions with Other Systems

| System | Direction | Data flow |
|---|---|---|
| Ecosystem Simulation | Bidirectional | Reads/writes `jar_moisture`, `light_level`/`light_direction` (added 2026-08-03), per-plant `growth_stage`/`optimal_hold_ticks`, per-creature PRESENT/ABSENT state/`condition_streak_ticks` (both added 2026-08-04) |
| Object Placement | Bidirectional | Reads/writes the placed object's position |
| Time & Drift | Bidirectional | Reads/writes `last_visit_timestamp` — this is the resolution to that GDD's own open question |
| Diorama Rendering | Downstream (reads) | **(new, 2026-08-05 `/design-review`, round 12 — Core Rule 8)** Reads the save-confirmation-cue signal to render it; provisional until Diorama Rendering's own GDD is authored, same pattern `ecosystem-simulation.md` uses for its `light_level` visibility requirement — flagged for that GDD's own Dependencies section when it exists. |

Persistence/Save has no upstream dependency that constrains its own logic —
it's the one system every other MVP system's state ultimately routes
through for cross-session survival.

*(Specialist agents not consulted — Lean mode; this section is not in the
high-risk Section D/H set.)*

## Formulas

The `save_blob_validity` check is defined as:

`save_blob_validity = (schema_version == CURRENT_SCHEMA_VERSION) AND (∀ plant/creature/object: type_id exists in Content Data's current registry) AND (0 ≤ jar_moisture ≤ 100) AND (0 ≤ light_level ≤ 100) AND (light_direction ∈ {-1, +1}) AND (∀ plant: 0 ≤ growth_stage ≤ plant_type.max_stage) AND (∀ plant: 0 ≤ optimal_hold_ticks ≤ OPTIMAL_HOLD_TICKS_MAX) AND (∀ creature: state ∈ {PRESENT, ABSENT}) AND (∀ creature: 0 ≤ condition_streak_ticks ≤ CONDITION_STREAK_MAX) AND (position fields present when state == PRESENT) AND (∀ creature where state == PRESENT: creature_in_bounds(position)) AND (∀ creature: creature_in_bounds(last_known_position)) AND (object_in_bounds(object_position))`

**`creature_in_bounds(last_known_position)` clause added 2026-08-09**
(`/review-all-gdds` cross-GDD finding, companion to the new
`last_known_position` blob field above): reuses the exact same ellipse
check already defined below for `creature_position`, unconditionally (not
gated on `state==PRESENT`, since unlike `creature_position` this field is
always present). A corrupted or out-of-bounds `last_known_position` fails
the same way any other corrupted position field does — whole-blob
discard, never a partial restore.

**Evaluation order is significant, not just presentational (corrected
2026-08-05 `/design-review`, round 12, `systems-designer` finding,
independently confirmed by `qa-lead`).** The clauses above must be
evaluated left-to-right with short-circuit AND, not treated as an
order-independent set — this is why the `type_id`-existence clause was
moved to position 2, immediately after `schema_version`. The
`growth_stage` clause reads `plant_type.max_stage`, which requires
resolving `type_id` first; `object_in_bounds` reads the object's
`footprint_size` the same way. **Under the prior ordering, a corrupted or
nonexistent `type_id` reached the `growth_stage` clause before the clause
that verifies `type_id` exists** — a null-dereference crash instead of a
graceful validity failure, directly contradicting Edge Cases' "never
crash startup" guarantee, and making **AC8's own scenario (a bad plant
`type_id` → graceful blob discard) unreachable as specified**, since the
formula would crash before ever reaching a state where it could return
`false`. `object_in_bounds` was already correctly positioned after the
type_id-existence clause under the prior ordering, which is what made
this asymmetric rather than a whole-formula problem. Moving the
existence check to position 2 removes the dependency-ordering hazard
entirely — no remaining clause depends on another clause succeeding
first to evaluate safely.

`object_in_bounds(px, py) = ((px-cx)/(rx-fp))² + ((py-cy)/(ry-fp))² ≤ 1` — this
is `object-placement.md`'s own `in_bounds` check (see that GDD's Formulas),
reused verbatim rather than redefined, with `fp` = the loaded object's
`footprint_size` from Content Data.

`creature_in_bounds(px, py) = ((px-cx)/(rx-fp))² + ((py-cy)/(ry-fp))² ≤ 1`
with `fp=0` (added 2026-08-04 `/design-review`, `qa-lead` finding) — the
same ellipse check, reused a second time, with `fp=0` since a creature has
no footprint of its own (matching `creature-behavior.md`'s own destination-
sampling reuse of this identical formula for the same reason). Previously
the object's position was the only saved position with a validity clause
— `save_blob_validity`'s clause 7 (position-present-when-PRESENT) checked
only that a creature's position *existed* when PRESENT, never that it was
*sane*. This asymmetry became load-bearing this round: a restored PRESENT
creature now enters WANDERING immediately at its restored position (see
`creature-behavior.md`'s new restore-entry rule), making an unchecked
out-of-bounds position an immediately-live wander origin, not just an inert
stored value — a corrupted/devtools-tampered position could otherwise feed
Creature Behavior a destination-sampling origin outside the jar entirely.

**`light_level`/`light_direction` clauses added 2026-08-03
`/design-review`** — same mirrored pattern as every other field here,
covering Ecosystem Simulation's new possibility-space-depth variable (see
that GDD's Formulas).

**`type_id`-existence and `object_in_bounds` clauses added 2026-08-04
`/design-review`** (`systems-designer` + `qa-lead`, independently
convergent findings): Edge Cases already claimed "a loaded plant/creature/
object entry referencing a `type_id` no longer present in Content Data's
registry... is treated as a validity failure, same as any other," and AC8
tested exactly that for a plant — but the formula itself had no clause that
could produce that behavior, and AC8 never exercised a creature or object
`type_id` (see Acceptance Criteria). Separately, the placed object's
position was serialized (Core Rule 1) and read/written bidirectionally
(Interactions) but had zero validity clause and zero corrupted-value
Acceptance Criterion anywhere — unlike every other saved field. Concrete
failure mode this closes: a corrupted or out-of-bounds object position
would previously load unchecked and render the rock permanently outside
the jar ellipse, since Object Placement only re-validates position at
`drag_end`, never on load.

**`last_visit_timestamp` is deliberately NOT a clause here** (also
2026-08-04, same finding): `time-drift.md`'s own Edge Cases already sanitize
an invalid, negative-implying, or future-dated timestamp by resetting it to
the "first session" case (no catch-up, timestamp reset to now) rather than
failing outright — folding it into this all-or-nothing gate would discard
`jar_moisture`/`growth_stage` alongside a bad timestamp for no reason, which
is *more* destructive than Time & Drift's own graceful handling. Excluded by
design, not an oversight.

**Ecosystem Simulation's per-plant detail-event flag is also deliberately
NOT part of this blob, unlike `optimal_hold_ticks`/`condition_streak_ticks`
below (added 2026-08-05 `/design-review`, round 13 — `game-designer`/
`systems-designer` finding, `creative-director` ruling: user confirmed this
is transient, not a persistence gap).** Tracing its actual lifecycle: a
detail event (`ecosystem-simulation.md` Core Rule 10) can only trigger
during a tick, and ticks only ever fire inside Time & Drift's catch-up
batch at session start (`time-drift.md` Core Rule 6) — so a triggered flag
is always generated *and* shown to the player (via Discovery Surfacing,
reading Ecosystem Simulation's own state-delta feed) within the same
session, strictly before any save write (Core Rule 5) can occur. It never
has a reason to survive a save/load boundary. This is a different
exclusion reason than `last_visit_timestamp` above (that field is excluded
because Time & Drift already sanitizes it more precisely; this one is
excluded because it is fully consumed before any write happens) but the
same category: Core Rule 1's blob-completeness principle only ever
obligated values that persist *across* a tick or session boundary, and
this flag does not — its absence here is the principle correctly scoping
itself, not an exception carved out of it. See `ecosystem-simulation.md`
Core Rule 10 for the companion statement of this same lifecycle fact.

**`optimal_hold_ticks`/`condition_streak_ticks`/`creature_in_bounds` clauses
added 2026-08-04 `/design-review`, round 11** — the first fields added under
Core Rule 1's new blob-completeness principle rather than found via ad-hoc
audit. `OPTIMAL_HOLD_TICKS_MAX`/`CONDITION_STREAK_MAX` are data-corruption
gates, same pattern as `content-data.md`'s `RATE_MAX`/`MOVEMENT_SPEED_MAX` —
generous headroom above any value legitimate play can produce, not a
tuning-sanity check. `condition_streak_ticks` in particular should never
legitimately reach `N_departure_ticks` (**25**, retuned 2026-08-09 — see
Open Questions) while PRESENT or `N_spawn_ticks` (3) while ABSENT —
Ecosystem Simulation's own Core Rules 6/7 have the
transition fire and the counter reset to `0` in the same tick the threshold
is met — so `CONDITION_STREAK_MAX = max(N_spawn_ticks, N_departure_ticks) =
25` already sits above every value the formula should ever legitimately
produce; it exists to reject clearly-corrupted data (e.g. a negative value
or an absurd magnitude), not to gate a real design boundary.
**Corrected 2026-08-05 `/design-review`, round 12 (`systems-designer`
finding):** the claim that `optimal_hold_ticks` "has no natural cap" is
not accurate under `ecosystem-simulation.md`'s own locked tuning — that
document's round-12 analysis proves the longest achievable contiguous
GROWING streak is `40/5+1=9` ticks for any MVP plant type at the
documented default `LIGHT_STEP_PER_TICK=5` and width-40 light bands (see
that GDD's Formulas, Detail Event Probability). `optimal_hold_ticks` is
therefore bounded in practice under current tuning, not unbounded — this
correction changes only the stated justification, not the constant's
value: `OPTIMAL_HOLD_TICKS_MAX=10000` remains a safe corruption-scale
ceiling regardless of any retuning within the documented safe ranges for
`LIGHT_STEP_PER_TICK` or light-band width, sitting far above even a
generously-retuned achievable streak.

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| schema_version | int | ≥1 | version tag written with the blob |
| optimal_hold_ticks | int | 0–`OPTIMAL_HOLD_TICKS_MAX` | loaded per-plant detail-event hold counter (new 2026-08-04) |
| OPTIMAL_HOLD_TICKS_MAX | int | constant, 10000 | data-corruption gate on `optimal_hold_ticks` — bounded to ~9 ticks under current tuning (**corrected 2026-08-05, round 13**, propagating the round-12 prose fix above that this table row had not yet picked up), not literally unbounded; 10000 remains safe headroom regardless of any legal retuning |
| condition_streak_ticks | int | 0–`CONDITION_STREAK_MAX` | loaded per-creature spawn/departure debounce counter (new 2026-08-04) |
| CONDITION_STREAK_MAX | int | constant, **25** (`max(N_spawn_ticks, N_departure_ticks) = max(3, 25)`) — **recomputed 2026-08-09, see Open Questions** | data-corruption gate — above every value the formula should legitimately produce, since the counter resets to 0 the same tick its threshold fires. `ecosystem-simulation.md`'s required pre-implementation tuning pass picked `N_departure_ticks=25` (within its 10–30 safe range); this constant re-derived to match. Not enforced by any cross-file check today — if `N_departure_ticks` is ever retuned again, this constant must be manually re-derived again (see Open Questions). |
| creature_position (px, py) | float | must satisfy `creature_in_bounds` when `state==PRESENT` | loaded position of a PRESENT creature (new 2026-08-04) |
| last_known_position (px, py) | float | must satisfy `creature_in_bounds`, unconditionally (new 2026-08-09) | loaded most-recent-observed position of a creature, from `ecosystem-simulation.md` Core Rule 12 — unlike `creature_position`, always present regardless of `state`; source of Discovery Surfacing's Departure cue position |
| jar_moisture | int | 0–100 | loaded moisture value. **Corrected 2026-08-03 `/design-review`**: previously typed `float` here, inconsistent with `ecosystem-simulation.md`'s own `int` typing for the same shared value (`systems-designer` finding) — `jar_moisture` is an int on the 0–100 scale everywhere else in the project; corrected to match. |
| light_level | int | 0–100 | loaded light value (new 2026-08-03) |
| light_direction | int | {-1, +1} | loaded light drift direction (new 2026-08-03) |
| growth_stage | int | 0–max_stage (per plant type, from Content Data) | loaded plant growth stage |
| state | enum | {PRESENT, ABSENT} | loaded creature state |
| type_id | string | must exist in Content Data's registry | loaded plant/creature/object type reference (new 2026-08-04) |
| object_position (px, py) | float | must satisfy `object_in_bounds` | loaded position of the placed object (new 2026-08-04) |
| save_blob_validity | bool | true/false | gate on whether to restore the blob at all |

**Output Range:** boolean.
**Example:** A blob with `schema_version=1` (current), `jar_moisture=62`, a
Moss `growth_stage=3` (≤ its `max_stage=4`), Snail `state=PRESENT` with a
valid position → `valid=true`. A blob with `jar_moisture=150` (out of
range, e.g. from a corrupted write) → `valid=false`, discard.

This is warranted for a stronger reason than Content Data's analogous
`definition_validity` check: save blobs come from browser-persisted
storage, which users can corrupt via devtools, or which a future game
version's schema change could invalidate — Edge Cases alone can't carry
that weight without a formal gate first. **On `false`, Persistence/Save
attempts the last-known-good fallback (Core Rule 7) before falling back
to the existing "no save blob" default-init path (Core Rule 4). Never
partially restore a failing blob at any tier** — field-level partial
restoration is rejected throughout; only whole-blob substitution
(current → last-known-good → defaults) is permitted. **(Fallback tier
added 2026-08-05 `/design-review`, round 12 — see Core Rule 7 for the
full rationale: an unconditional single-tier discard was found to
conflict with the Anti-Pillar, NOT punishing, since it applied the same
total loss to one corrupted field as to intentional tampering.)**

*(`systems-designer` consulted — recommended mirroring Content Data's
`definition_validity` pattern exactly, for a stronger reason: save data is
more corruption-prone than authored data.)*

## Edge Cases

- **If `save_blob_validity` fails at load on the current blob (updated
  2026-08-05 `/design-review`, round 12 — see Core Rule 7)**:
  Persistence/Save attempts to load and validate the last-known-good blob
  instead; if that also fails or doesn't exist, all systems initialize to
  their authored defaults (matching the "first session" behavior already
  defined). A warning is logged at whichever tier the failure occurs
  (current-blob failure and last-known-good-blob failure are logged
  distinctly) — never crash startup at any tier.
- **If a loaded plant/creature/object entry references a `type_id` no
  longer present in Content Data's registry** (e.g., a type was renamed or
  removed in a later game version): treated as a validity failure, same as
  any other — the current blob is discarded (subject to the last-known-good
  fallback above), not just the unresolvable entry, since partial
  restoration risks an inconsistent jar state.
- **(new, 2026-08-05 `/design-review`, round 12; corrected round 13) If a
  validity failure is actually caused by a legitimate content update**
  (e.g., a renamed `type_id`, or a plant's `max_stage` narrowed below a
  previously-saved `growth_stage`) **rather than corruption or
  tampering**: this system cannot distinguish the two causes at load
  time. **Unlike the tampering/corruption case, the last-known-good tier
  provides no protection here** (Core Rule 7's round-13 scope correction)
  — both the current blob and the last-known-good blob were written
  against the same now-superseded content, so both fail
  `save_blob_validity`'s `type_id`-existence/`growth_stage`-range clauses
  identically, and the system always falls through to full default-init
  (Core Rule 4) for this cause. This is an accepted limitation, not a gap
  this round closes: reliably telling "intentional content change" apart
  from "corruption" would require Content Data to carry migration
  metadata this project's MVP scope doesn't define — tracked under Open
  Questions (Save schema migration strategy), the sole owner of this
  cause, not solved here.
- **(added 2026-08-04 `/design-review`) If the loaded object's position
  fails `object_in_bounds`** (e.g., corrupted via devtools, or from a
  future geometry change): treated as a validity failure, same as any other
  — the entire blob is discarded. Without this check, the object would load
  outside the jar ellipse and stay there, since Object Placement only
  re-validates position on the next `drag_end`, never on load.
- **If the save write itself fails or is interrupted** (e.g., the browser
  closes before the underlying storage commit completes — the flagged
  HIGH-risk technical gap): the next session simply reads whatever blob
  was last *successfully* committed, or none if one was never written.
  This GDD's logic cannot recover a failed/partial write — that's an
  inherent limitation of the storage mechanism, not something save/load
  logic can fix. See Open Questions.
- **If a loaded blob's `schema_version` is older than
  `CURRENT_SCHEMA_VERSION`**: fails validity under the current check and
  the blob is discarded — no migration path exists at MVP scope. This is
  an accepted limitation for MVP, not an oversight; flagged in Open
  Questions for whether a migration strategy is needed post-MVP.
- **If multiple save blobs somehow exist** (not expected under normal
  operation): only one storage key is ever used — there is no multi-slot
  save concept for MVP's single jar.

## Dependencies

Persistence/Save depends on:
- **Ecosystem Simulation** (hard) — bidirectional read/write of
  `jar_moisture`, `growth_stage`/`optimal_hold_ticks`, creature state/
  `condition_streak_ticks` (both added 2026-08-04), and now
  `last_known_position` (added 2026-08-09, see that GDD's Core Rule 12)
- **Object Placement** (hard) — bidirectional read/write of object
  position
- **Time & Drift** (hard) — bidirectional read/write of
  `last_visit_timestamp` (this GDD is the resolution to that system's own
  open question)
- **Content Data** (hard) — validates loaded `type_id` references against
  the current registry

Downstream dependents:
- **Diorama Rendering** (provisional, added 2026-08-05 `/design-review`,
  round 12 — Core Rule 8) — reads the save-confirmation-cue signal to
  render it; degrades gracefully (no cue rendered) until that GDD is
  authored, same provisional pattern used elsewhere in this project for
  Diorama Rendering dependencies.
- **Ambient Audio** (soft, companion edit, 2026-08-05 —
  `ambient-audio.md` now authored) — reads/writes a persisted
  `ambient_volume`/`muted` preference. **Deliberately outside
  `save_blob_validity`'s all-or-nothing gate**: this is a cosmetic
  preference, not simulation-critical state, so a corrupted/out-of-range
  value must not discard `jar_moisture`/`growth_stage`/etc. alongside it
  — Ambient Audio's own Volume/Mute Conversion formula defensively
  clamps the loaded value to `[0.0, 1.0]` on its own, independent of this
  document's blob-discard behavior.
- **Creature Behavior** (soft, added 2026-08-05 `/design-review`, round
  13 — closes a bidirectionality gap `creature-behavior.md` already
  flagged on its own side since round 11): a restored creature `state`/
  position feeds that system's restore-entry rule (its own Core Rule 8) —
  soft because Creature Behavior reacts to Ecosystem Simulation's
  post-restore state, never reading this system's blob directly.
- **Multi-Jar Management** (Alpha tier, future) — will extend this
  system's save schema to cover multiple jars.

## Tuning Knobs

N/A — this system has no designer-adjustable gameplay values.
`CURRENT_SCHEMA_VERSION` is a technical version counter incremented by
engineering when the save format changes, not a balance/feel knob with a
meaningful "too low/too high" tradeoff.

## Visual/Audio Requirements

N/A — Persistence/Save has no visual or audio presence of its own.

## UI Requirements

**Not fully N/A — corrected 2026-08-05 `/design-review`, round 12; cue
trigger corrected round 13.** There is no save-slot picker, load screen,
or manual save button at MVP scope (single implicit save/load, per Core
Rules) — that part remains true. But per Core Rule 8, a brief,
non-intrusive **save-confirmation cue** must fire once on session start
whenever a save blob was successfully restored (never on the write itself
— see round-13 correction, Core Rule 8) — this is a hard requirement for
this system to be considered implementation-complete, not an optional
polish item. The exact visual treatment is Diorama Rendering's design
call once that system is authored, matching the pattern
`ecosystem-simulation.md` already used for `light_level`'s visibility
requirement — only the requirement that some confirmation exist at all is
locked here.

## Acceptance Criteria

1. **GIVEN** a true session end (close/unload), **WHEN** this occurs,
   **THEN** a save blob is written containing `schema_version` (**new,
   2026-08-05 `/design-review`, round 12** — closes a gap where this field
   was checked at load by `save_blob_validity` and tested in AC9 but never
   asserted as actually written), `jar_moisture`, `light_level`/
   `light_direction`, all plant `growth_stage`/`optimal_hold_ticks` values,
   all creature states/`condition_streak_ticks` (with position included
   only for creatures currently PRESENT), the object position, and
   `last_visit_timestamp`. **(2026-08-04 `/design-review`, round 11)**
   updated to include `optimal_hold_ticks`/`condition_streak_ticks` per
   Core Rule 1's blob-completeness principle.
1a. **(new, 2026-08-04 `/design-review`)** **GIVEN** the browser tab is
   hidden/backgrounded (`visibilitychange`→hidden, or `pagehide`) during an
   ACTIVE/RESTORED session, **WHEN** this occurs, **THEN** a save blob is
   written with the same contents as AC1, **except** `last_visit_timestamp`
   retains its current stored value unchanged — it is not updated to the
   current time, per Core Rule 5's correction.
2. **GIVEN** a session start with a previously saved valid blob, **WHEN**
   loading occurs, **THEN** `jar_moisture`, `growth_stage`/
   `optimal_hold_ticks`, creature state/`condition_streak_ticks`, object
   position, and `last_visit_timestamp` are all restored before Time &
   Drift computes its catch-up batch.
2a. **(new, 2026-08-04 `/design-review`, round 11 — generic round-trip
   completeness AC, the direct test of Core Rule 1's blob-completeness
   principle)** **GIVEN** a save blob is written and then immediately
   reloaded with no intervening ticks and no corruption, **WHEN** the
   round-trip completes, **THEN** every value Ecosystem Simulation carries
   across a tick boundary — `jar_moisture`, `light_level`, `light_direction`,
   each plant's `growth_stage` and `optimal_hold_ticks`, each creature's
   `state`, `condition_streak_ticks`, and position (if PRESENT) — is
   bit-for-bit identical before and after. This criterion exists
   specifically to catch the class of bug AC1/AC2's field-by-field
   enumeration cannot: a future field added to Ecosystem Simulation but
   never wired into Core Rule 1's blob would fail this test generically,
   without needing its own dedicated AC first. **Testability note added
   2026-08-05 `/design-review`, round 12 (`qa-lead` finding):** Core Rule
   5's only write triggers are true session-end and backgrounding — there
   is no on-demand save, so this round trip cannot be exercised through the
   live trigger path within a single session. This criterion is verified
   by invoking the serialize/deserialize functions directly (unit-level),
   independent of the `visibilitychange`/session-end trigger plumbing,
   which AC1/AC1a/AC10 cover separately.
3. **GIVEN** no save blob exists (first session), **WHEN** the session
   starts, **THEN** all systems initialize to their authored defaults and
   Persistence/Save performs no write.
4. **GIVEN** a loaded blob has `jar_moisture=150` (out of the 0–100
   range), **WHEN** `save_blob_validity` is checked, **THEN** the entire
   blob is discarded and all systems default-initialize.
   **(2026-08-04 `/design-review` — boundary pair, `qa-lead` finding)** The
   boundary itself must be tested independently of this grossly-invalid
   case: `jar_moisture=100` exactly **is valid** and loads normally;
   `jar_moisture=101` **is invalid** and discarded — confirming the bound
   is inclusive (`≤ 100`).
4a. **(new, 2026-08-03 `/design-review`)** **GIVEN** a loaded blob has
   `light_level=150` (out of the 0–100 range), **WHEN**
   `save_blob_validity` is checked, **THEN** the entire blob is discarded
   and all systems default-initialize — mirrors AC4 for the new
   `light_level` field. **(2026-08-04 — boundary pair)**
   `light_level=100` exactly **is valid**; `light_level=101` **is
   invalid** and discarded.
4b. **(new, 2026-08-03; extended 2026-08-05 `/design-review`, round 12,
   `qa-lead` finding — enum valid-side coverage)** **GIVEN** a loaded blob
   has `light_direction=0` (neither `-1` nor `+1`, a corrupted value),
   **WHEN** `save_blob_validity` is checked, **THEN** the entire blob is
   discarded. **Paired valid cases:** `light_direction=-1` and
   `light_direction=+1` are each independently valid and load normally —
   confirming both legal enum members pass, not just that one arbitrary
   corrupted value fails.
5. **GIVEN** a loaded blob has a plant `growth_stage=99` exceeding that
   plant type's `max_stage`, **WHEN** `save_blob_validity` is checked,
   **THEN** the entire blob is discarded. **(2026-08-04 `/design-review` —
   boundary pair, `qa-lead` finding)** The boundary itself must be tested
   independently: for a plant type with `max_stage=4` (e.g. Moss),
   `growth_stage=4` exactly **is valid** and loads normally;
   `growth_stage=5` **is invalid** and discarded — confirming the bound is
   inclusive (`≤ max_stage`).
5a. **(new, 2026-08-04 `/design-review`, round 11)** **GIVEN** a loaded
   blob has a plant `optimal_hold_ticks=-1` (negative, a corrupted value),
   **WHEN** `save_blob_validity` is checked, **THEN** the entire blob is
   discarded. **Boundary pair:** `optimal_hold_ticks=0` **is valid** (a
   plant that has never held its range) and loads normally;
   `optimal_hold_ticks=OPTIMAL_HOLD_TICKS_MAX` (10000) exactly **is
   valid**; `10001` **is invalid** and discarded.
5b. **(new, 2026-08-04, round 11)** **GIVEN** a loaded blob has a creature
   `condition_streak_ticks=-1` (negative, a corrupted value), **WHEN**
   `save_blob_validity` is checked, **THEN** the entire blob is discarded.
   **Boundary pair (updated 2026-08-09 — `CONDITION_STREAK_MAX` retuned
   5→25, see Open Questions):** `condition_streak_ticks=0` **is valid** and
   loads normally; `condition_streak_ticks=CONDITION_STREAK_MAX` (25)
   exactly **is valid**; `26` **is invalid** and discarded.
6. **GIVEN** a loaded blob has a creature state value that is neither
   PRESENT nor ABSENT (a corrupted enum), **WHEN** `save_blob_validity`
   is checked, **THEN** the entire blob is discarded. **(extended
   2026-08-05 `/design-review`, round 12, `qa-lead` finding)** **Paired
   valid cases:** a creature `state=PRESENT` (with a valid position) and a
   creature `state=ABSENT` are each independently valid and load normally
   — confirming both legal enum members pass, not just that one corrupted
   value fails.
7. **GIVEN** a loaded blob has a creature marked PRESENT but missing its
   position fields, **WHEN** `save_blob_validity` is checked, **THEN**
   the entire blob is discarded.
7a. **(new, 2026-08-04 `/design-review`, round 11, `qa-lead` finding —
   the creature-side twin of AC8c)** **GIVEN** a loaded blob has a PRESENT
   creature's position failing `creature_in_bounds` (e.g., a position far
   outside the jar ellipse, from devtools tampering or corruption),
   **WHEN** `save_blob_validity` is checked, **THEN** the entire blob is
   discarded — previously a PRESENT creature's position had presence
   checked (AC7) but never sanity, unlike the object's position, which
   received this exact fix (AC8c) a round earlier.
7b. **(new, 2026-08-09, cross-GDD review — the `last_known_position` twin
   of AC7a)** **GIVEN** a loaded blob has a creature's `last_known_position`
   failing `creature_in_bounds`, **WHEN** `save_blob_validity` is checked,
   **THEN** the entire blob is discarded — checked unconditionally,
   regardless of that creature's `state`, unlike AC7/7a which only apply
   `if PRESENT`.
8. **GIVEN** a loaded blob references a plant `type_id` not present in
   Content Data's current registry, **WHEN** `save_blob_validity` is
   checked, **THEN** the entire blob is discarded.
8a. **(new, 2026-08-04 `/design-review`, `qa-lead` finding)** **GIVEN** a
   loaded blob references a creature `type_id` not present in Content
   Data's current registry, **WHEN** `save_blob_validity` is checked,
   **THEN** the entire blob is discarded — AC8's original wording only
   exercised a plant `type_id` despite Edge Cases claiming symmetric
   "plant/creature/object" treatment; this closes the untested creature
   case.
8b. **(new, 2026-08-04)** **GIVEN** a loaded blob references the placed
   object's `type_id` not present in Content Data's current registry,
   **WHEN** `save_blob_validity` is checked, **THEN** the entire blob is
   discarded — the object-side twin of 8a/8, completing the "plant/
   creature/object" symmetry Edge Cases already claimed.
8c. **(new, 2026-08-04, `systems-designer` + `qa-lead` independently
   convergent finding)** **GIVEN** a loaded blob has the object's position
   failing `object_in_bounds` (e.g., a position far outside the jar
   ellipse, from devtools tampering or corruption), **WHEN**
   `save_blob_validity` is checked, **THEN** the entire blob is discarded —
   previously the object's position had no validity clause and no AC at
   all, unlike every other saved field.
9. **GIVEN** a loaded blob's `schema_version` is older than
   `CURRENT_SCHEMA_VERSION`, **WHEN** `save_blob_validity` is checked,
   **THEN** the blob is discarded. **(2026-08-04 `/design-review`, round
   11 — boundary pair, `qa-lead` finding)** Unlike every other bounded
   field in this doc, this criterion previously tested only the
   older-than case. The boundary itself must also be tested:
   `schema_version == CURRENT_SCHEMA_VERSION` exactly **is valid** and
   loads normally; a `schema_version` *newer* than `CURRENT_SCHEMA_VERSION`
   (e.g. a save written by a future game version, then loaded by this
   older one) **is also invalid** and discarded under the same `==` check
   — the formula's equality (not `≤`) already rejects both directions, this
   just makes the newer-than case an explicitly tested boundary rather than
   an implicit consequence of the `==` operator.
10. **(rewritten 2026-08-04 `/design-review`)** **GIVEN** the browser tab
    is hidden/backgrounded (`visibilitychange`→hidden, or `pagehide`) but
    not truly closed, **WHEN** this occurs, **THEN** a save write fires
    (per AC1a) but `last_visit_timestamp` is **not** updated and the
    session is not considered ended. The original version of this
    criterion asserted "no save write fires" — that was the pre-2026-08-04
    design; Core Rule 5 was corrected to close a crash/forced-close data-loss
    gap, and this criterion is rewritten to match rather than contradict it.
10a. **(new, 2026-08-04)** **GIVEN** a backgrounding write has just fired
    per AC10, **WHEN** the tab is refocused without having been truly
    closed, **THEN** no catch-up batch runs and `last_visit_timestamp` is
    unchanged — mirrors `time-drift.md`'s own AC6, confirming the
    backgrounding write is a pure persistence action, not a second kind of
    session boundary.
10b. **(new, 2026-08-05 `/design-review`, round 12, `qa-lead` finding)**
    **GIVEN** a backgrounding write has fired per AC10 within a session,
    **WHEN** that same session later reaches a true session end, **THEN**
    the session-end write fires per AC1 and `last_visit_timestamp` updates
    to the current time — confirming a prior backgrounding write does not
    permanently suppress later timestamp updates. This closes a gap
    AC1/AC1a/AC10/AC10a each miss individually: none of them alone would
    catch an implementation that latches `last_visit_timestamp` as
    permanently frozen after the first backgrounding event in a session.
11. **GIVEN** a session is ACTIVE, **WHEN** any amount of time passes
    without a true session end **or** a backgrounding event, **THEN** no
    save write occurs — no periodic/interval autosave exists beyond the two
    triggers in AC1/AC1a/AC10.
12. **(new, 2026-08-05 `/design-review`, round 12 — Core Rule 7,
    last-known-good fallback)** **GIVEN** the current blob fails
    `save_blob_validity` and a last-known-good blob exists and itself
    passes `save_blob_validity`, **WHEN** load occurs, **THEN** the
    last-known-good blob is restored instead of default-initializing, and
    a warning distinct from the "no valid blob at all" case is logged.
12a. **(new, 2026-08-05, round 12)** **GIVEN** both the current blob and
    the last-known-good blob fail `save_blob_validity` (or no
    last-known-good blob exists), **WHEN** load occurs, **THEN** the
    system falls back to default-init per Core Rule 4, matching this
    document's pre-round-12 behavior.
12b. **(new, 2026-08-05, round 12)** **GIVEN** a write occurs and the
    outgoing blob about to be overwritten (the current blob prior to this
    write) passes `save_blob_validity`, **WHEN** the write completes,
    **THEN** that outgoing blob is promoted to last-known-good before the
    new blob becomes current.
12c. **(new, 2026-08-05, round 13 — Core Rule 7's scope correction)**
    **GIVEN** both the current blob and the last-known-good blob reference
    a plant `type_id` that a Content Data update has since removed (both
    blobs written under the same, now-superseded content), **WHEN** load
    occurs, **THEN** both blobs fail `save_blob_validity` identically and
    the system falls back to default-init per AC12a — confirming the
    last-known-good tier provides no recovery for a content-edit cause,
    distinct from AC12's tampering/corruption case where the two blobs
    genuinely differ in validity.
13. **(new, 2026-08-05 `/design-review`, round 12 — Core Rule 8,
    save-confirmation signal; rewritten round 13 — cue moved from the
    write to the following restore)** **GIVEN** a session starts and a
    save blob (current or last-known-good) is successfully restored,
    **WHEN** restoration completes, **THEN** a save-confirmation cue fires
    once, before or as the jar becomes interactive (exact visual treatment
    owned by Diorama Rendering, per UI Requirements).
13a. **(new, 2026-08-05, round 12; rewritten round 13)** **GIVEN** a
    session starts with no save blob to restore (first-ever session, Core
    Rule 4) **or** with a blob that fails `save_blob_validity` at both
    fallback tiers (Core Rule 7 — default-init occurs), **WHEN** this
    occurs, **THEN** no save-confirmation cue fires — a false-positive
    "saved" signal on nothing actually restored is not permitted.

*(`qa-lead` consulted — flagged that 3 of the formula's 5 conjunctive
terms had no dedicated criterion (growth_stage range, creature state
enum, position-when-PRESENT), and a wording issue in the original AC1;
both addressed above.)*

*(Re-reviewed via `/design-review` on 2026-08-03 — lean mode. Verdict:
NEEDS REVISION → 1 blocker resolved: `jar_moisture` was typed `float` in
this doc's `save_blob_validity` check, inconsistent with
`ecosystem-simulation.md`'s `int` typing for the same shared value
(`systems-designer` finding, surfaced during that doc's full specialist
review) — corrected to `int`. Also picked up a companion edit from that
same review: Ecosystem Simulation's new `light_level`/`light_direction`
variable (added to fix a possibility-space-depth defect) now needs to
survive across sessions the same as `jar_moisture` — added to Core Rule 1's
save blob, `save_blob_validity`'s formula, the Variables table, and two new
Acceptance Criteria (4a/4b) mirroring the existing moisture-range pattern.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — full specialist round
across content-data.md, ecosystem-simulation.md, persistence-save.md,
object-placement.md as a set: `game-designer`, `systems-designer`,
`qa-lead`, `godot-specialist`, `creative-director`. Verdict: NEEDS REVISION
→ 2 blockers resolved below. **Save trigger changed (Core Rule 5,
States and Transitions, AC1a/10/10a/11)**: `game-designer` flagged that a
single write at true session end only, combined with the already-tracked
IndexedDB-reliability question, meant a crash or forced tab-kill could lose
an entire visit's tending with zero mitigation — a real design gap for a
NOT-punishing game, not just an engineering risk. `creative-director` ruled
(user-confirmed): also write on `visibilitychange`/`pagehide`, without
changing what counts as a "visit" — `last_visit_timestamp` still only
updates at true session end, per `time-drift.md`'s own Core Rule 8. AC10
previously asserted the opposite ("no save write fires" on backgrounding)
and has been rewritten to match, not silently left contradicting the new
rule. **`save_blob_validity` formula gaps closed**: `systems-designer` and
`qa-lead` independently found the formula didn't gate two things Core Rule 1
already claims are saved — the object's position (zero clause, zero AC,
unlike every other field) and full plant/creature/object `type_id`
resolution (Edge Cases and AC8 already claimed this was checked, but the
formula couldn't produce that behavior, and AC8 only ever tested a plant
`type_id`). New clauses added reusing `object-placement.md`'s own
`in_bounds` check; new ACs 8a/8b/8c added. `last_visit_timestamp` was
considered for a similar clause and deliberately excluded — see Formulas —
since `time-drift.md`'s own Edge Cases already sanitize it more precisely
than an all-or-nothing blob discard would. **Boundary-pair ACs added**
(`qa-lead`, recommended not blocking): AC4/4a/5 previously asserted only
grossly-invalid values, unlike this project's own established pattern
elsewhere (e.g. `content-data.md`'s AC2a) — paired exact-boundary valid/
invalid clauses added to each.)*

*(Re-reviewed via `/design-review` on 2026-08-04 — round 11, full
specialist round across content-data.md, ecosystem-simulation.md,
persistence-save.md, object-placement.md as a set: `game-designer`,
`systems-designer`, `qa-lead`, `godot-specialist`, `creative-director`.
Verdict: NEEDS REVISION → 5 blockers resolved below (user selected "revise
now" and confirmed both open design-decision points). **Blob completeness
principle added (Core Rule 1)**: three rounds running, a new field carried
across a tick boundary by an upstream system shipped without a matching
blob field until an audit caught it (`light_level`/`light_direction` last
round; `optimal_hold_ticks`/`condition_streak_ticks` this round). User
confirmed adopting `creative-director`'s structural fix over patching the
known fields alone — Core Rule 1 now states the general obligation, with
the field enumeration as its current instantiation, plus a new generic
round-trip AC (2a) that tests the principle directly rather than only its
named instances. **`optimal_hold_ticks`/`condition_streak_ticks` persisted**:
both are real per-instance Ecosystem Simulation state that was silently
reset at every session boundary — for `optimal_hold_ticks` this
systematically suppressed the Pillar 4 rare-bloom event specifically for
players on the game's own intended daily cadence; for `condition_streak_ticks`
(the newly-named debounce counter behind `N_spawn_ticks`/`N_departure_ticks`)
this made creature spawn/departure permanently unreachable for a
frequent-short-visit cadence, not just delayed. `creative-director` ruled
both persisted, resolving a `game-designer`/`systems-designer` severity
disagreement on the debounce counter specifically in `systems-designer`'s
favor (permanent lockout for a real persona outweighs "usually fine for the
daily-visitor persona"). New blob fields, two `save_blob_validity` clauses,
two new corruption-gate constants (`OPTIMAL_HOLD_TICKS_MAX`,
`CONDITION_STREAK_MAX`), and new boundary-pair ACs 5a/5b added.
**Creature position validity gap closed**: `qa-lead` found the object's
position got a dedicated `object_in_bounds` clause + AC last round
specifically because it was "unlike every other saved field" in having
none — the same gap existed for creature position (presence-when-PRESENT
was checked, sanity never was) and was never fixed alongside it. New
`creature_in_bounds` clause (reusing the same ellipse check with `fp=0`,
matching `creature-behavior.md`'s own reuse pattern) and new AC7a added —
this became load-bearing this round specifically because a restored
PRESENT creature now becomes a live wander origin on frame one (see
`creature-behavior.md`'s companion edit). **`schema_version` boundary pair
added** (AC9, recommended not blocking, folded into this pass per creative-
director's sequencing note). **Backgrounding-write reachability flagged,
not reverted**: `godot-specialist` found `visibilitychange`/`pagehide` have
no native Godot Web-export notification and may never fire the engine's
frame loop while a tab is hidden — if true, Core Rule 5/AC1a/10/10a
currently assert a data-loss mitigation that silently isn't reachable, more
severe than an ordinary gap since the documents would be actively
misleading rather than merely incomplete. User selected "verify first,
keep both rules drafted" over switching immediately or reverting — Core
Rule 5 is unchanged and flagged, a verification plan and a pre-drafted
write-on-mutation fallback are recorded in Open Questions for
`/architecture-decision` to resolve. **IndexedDB Open Question
strengthened** with `godot-specialist`'s WebSearch-verified detail
(Emscripten IDBFS behavior, `FS.syncfs()` requirement, two named
implementation paths) and `creative-director`'s constraint on that future
decision (prefer removing the race over mitigating it) — kept open per
user decision, not resolved in this document.)*

*(Reviewed via `/design-review` on 2026-08-05 — round 12, first full
specialist round dedicated solely to this document (prior rounds were
part of a joint content-data/ecosystem-simulation/persistence-save/
object-placement pass): `game-designer`, `systems-designer`, `qa-lead`,
`godot-specialist`, `creative-director`. Verdict: NEEDS REVISION → all 5
blockers resolved below. **`schema_version` blob-write gap closed**
(`systems-designer` and `qa-lead` independently convergent finding):
Core Rule 1's blob enumeration and AC1 both omitted `schema_version`
despite it being `save_blob_validity`'s first clause and having its own
Edge Cases prose and AC9 — added to both. **Validity-formula
evaluation-order bug fixed** (`systems-designer` finding, independently
confirmed by `qa-lead`): the `growth_stage` clause depended on resolving
`type_id` via `plant_type.max_stage`, but the type_id-existence clause sat
later in the same AND-chain — a corrupted `type_id` would crash instead
of failing gracefully, making AC8 unimplementable as specified. Reordered
so the type_id-existence clause runs second, immediately after
`schema_version`; an explicit evaluation-order note added to Formulas.
**Header BLOCKED gate propagated** (`godot-specialist` finding): this
document's own Open Questions already marked `visibilitychange`/
`pagehide` reachability BLOCKING, but the header didn't reflect it, unlike
the established `time-drift.md`/`object-placement.md` precedent — header
corrected. **Last-known-good fallback added** (`game-designer` finding,
`creative-director` ruling, user selected this option over documenting
the tradeoff unchanged or splitting fallback by cause): a single
full-discard-to-defaults on any validity failure was found to conflict
with the Anti-Pillar (NOT punishing), applying the same total loss to one
corrupted field as to intentional tampering. New Core Rule 7 retains a
last-known-good blob as a second fallback tier before default-init,
bounding worst-case loss to one visit's tending rather than the entire
save history, without weakening the all-or-nothing validity gate itself.
New ACs 12/12a/12b. **Save-confirmation signal added** (`game-designer`
finding, `creative-director` ruling, user selected locking the
requirement while deferring its visual treatment): UI Requirements
previously read "N/A" despite save-commit reliability being an open
technical question with zero player-facing confirmation of success — a
silent-failure risk directly against this system's own stated Player
Fantasy. New Core Rule 8 requires a non-intrusive save-confirmation cue
after every successful write (never on a failed one); UI Requirements and
Dependencies updated; new ACs 13/13a. **Recommended items folded in,
cheap/text-only, already specialist-vetted this round**: stale "10-tick"
rare-bloom threshold reference corrected to 6, matching
`ecosystem-simulation.md`'s own round-12 correction (`qa-lead`);
`OPTIMAL_HOLD_TICKS_MAX`'s "no natural cap" rationale corrected to match
that same document's proof of a 9-tick achievable ceiling, constant value
unchanged (`systems-designer`); AC2a given a testability note clarifying
it exercises save/load functions directly, not the live trigger path
(`qa-lead`); new AC10b closing the gap where AC1/AC1a/AC10/AC10a each
individually miss a backgrounding-write-then-session-end sequence
(`qa-lead`); AC4b/AC6 extended into full valid-side/invalid-side enum
pairs (`qa-lead`); a new Edge Case stating that legitimate content
updates and actual corruption are indistinguishable at load time, cross-
referenced to the schema-migration Open Question (`game-designer`);
schema-migration Open Question given a hardened pre-launch-update target
instead of an open-ended one, downgraded from a candidate MVP blocker to
RECOMMENDED since MVP itself ships to zero existing players
(`game-designer`, `creative-director`); reachability Open Question
re-scoped to its actually-uncertain narrower claim, plus a new
JS-mirrored-blob mitigation option surfaced for `/architecture-decision`
(`godot-specialist`); a new Open Question flagging the frequent-
backgrounder persona's Time & Drift catch-up gap forward to that
document's own owner, not resolved here (`game-designer`). **Disagreement
surfaced, not silently resolved**: `qa-lead` rated AC2a's
trigger-unreachability RECOMMENDED; `systems-designer` rated it
NICE-TO-HAVE; `creative-director` sided with `qa-lead` since AC2a is the
sole generic test of Core Rule 1's own blob-completeness principle.
Separately, `godot-specialist`'s JS-mirrored-blob idea was confirmed to
*mitigate*, not *resolve*, the save-confirmation-signal gap — the two
are recorded as needing to be decided together once `/architecture-
decision` picks a storage path, since only the synchronous `localStorage`
path would make a "saved" cue genuinely honest rather than optimistic.)*

*(Reviewed via `/review-all-gdds` on 2026-08-05 — round 13, holistic
cross-GDD consistency and design-theory pass across all 8 approved MVP
GDDs (this same-day revision was the direct cause of 3 of the 6 blocking
findings). Verdict on the pass: FAIL; this document's own 3 blockers
resolved below, same session, no formal specialist re-review round (user
decision). **Save-confirmation cue moved from write to restore** (Core
Rule 8, States and Transitions, UI Requirements, AC13/13a —
`game-designer`/`systems-designer` independently convergent finding): the
round-12 version fired the cue exclusively at true session-end or
tab-backgrounding, the two moments the player can never actually see it
(page unloading, tab hidden) — unobservable at both its own trigger
points, defeating its stated purpose. `creative-director` ruled: fire
once on successful restore at the next session start instead
("welcome back — your jar was saved"), which is always live and rendered,
over adopting a new in-session write-on-mutation trigger. **Last-known-good
fallback's scope corrected** (Core Rule 7, Edge Cases, new AC12c):
Core Rule 7 was justified partly against "a renamed `type_id`, a narrowed
`max_stage`" — `systems-designer` found this false, since both the
current and last-known-good blobs are validated against the *same
current* Content Data registry and fail identically for that cause; the
fallback only ever helps against tampering/corruption introduced after
the last-known-good blob was itself validated. Rationale narrowed
accordingly; the content-edit cause is now stated as fully and only owned
by the Save Schema Migration Open Question, not silently mis-attributed
to a mechanism that can't address it. **Detail-event flag confirmed
transient, not a blob gap** (Core Rule 1, Formulas — new exclusion note;
companion edit to `ecosystem-simulation.md` Core Rule 10): a detail event
can only trigger on a tick, and ticks only ever fire inside Time & Drift's
non-rendering catch-up batch — so a triggered flag is always generated and
shown to the player within the same session, before any save write can
occur, and never has a reason to survive a save/load boundary. User
confirmed this reading over adding persistent detail-event state; excluded
explicitly, the same category of exclusion as `last_visit_timestamp`
already documented above, for a different underlying reason. **Two
additional cheap fixes folded in from the same review pass, already
diagnosed, text-only**: the `OPTIMAL_HOLD_TICKS_MAX` Variables-table row
still read "no natural upper bound," seven lines below the round-12 prose
correcting exactly that claim — propagated; `CONDITION_STREAK_MAX`'s
unenforced coupling to `ecosystem-simulation.md`'s own `N_departure_ticks`
safe-tuning range (4–8, vs. this constant's pinned value of 5) flagged as
a new Open Question, same class as `content-data.md`'s already-tracked
`FOOTPRINT_MAX` coupling. **Missing reciprocal dependency added**:
`creature-behavior.md` has listed Persistence/Save as a soft dependency
since round 11; this document's own Dependencies section never listed it
back — added.)*

## Open Questions

- ~~**HTML5/IndexedDB write reliability**~~ / ~~**`visibilitychange`/`pagehide`
  reachability on Web export**~~ — **RESOLVED 2026-08-10** by
  `docs/architecture/adr-0005-persistence-save-web-storage-strategy.md`,
  from the Web Export Spike's Gate B evidence. **Scope: desktop Chrome
  only** — WebKit (desktop Safari, iOS Safari) was not tested; see below
  for exactly what that leaves open.

  **What was observed (Chrome desktop, Gate B):** B1 (does a
  `JavaScriptBridge` callback execute while the tab is hidden) PASS —
  same-frame delivery, ~0.5ms lag. B2 (IDBFS/`FileAccess` survival) 2/3
  without `FS.syncfs()` (one demonstrated failure), 5/5 with it. B3 (pure-JS
  `localStorage` survival) PASS. B4 (iOS-specific `pagehide`/bfcache
  behavior) untested.

  **What was decided, and why it isn't simply "option (c) because the
  evidence favored it":** ADR-0005 drops `FileAccess`/IDBFS entirely for
  Web (previously drafted option (a)) and adopts the JS-mirrored-blob +
  pure-JS-listener design (previously drafted option (c)) over the
  GDScript-triggered `localStorage` write (previously drafted option (b)).
  Options (a) and (b) both depend on B1 — GDScript executing during the
  hide event — which is verified only on Chromium, the browser family
  independently expected to be *most* permissive about background-tab
  execution; WebKit is independently expected to be the most restrictive,
  which is why the verification plan named it highest-risk before any
  testing occurred. Option (c) removes that dependency from the
  hide-triggered write by construction — the only GDScript-dependent step
  happens while the tab is foregrounded, not hidden — so it does not rest
  on Chrome's B1 result generalizing to browsers it was never measured on.
  Full reasoning: ADR-0005 Decision and Alternatives Considered.

  **What remains explicitly open, not silently treated as universal:**
  WebKit/iOS Safari is unverified for this entire decision. ADR-0005
  documents this as a named residual risk, architecturally hedged (the
  chosen design specifically avoids the failure mode WebKit is expected to
  exhibit, and a defensive `pageshow`/bfcache-reload guard covers the
  specific unverified iOS behavior in B4) but **not closed**. If a WebKit
  device becomes available, re-run Gate B (B1–B4) against the production
  implementation, not the now-superseded spike code.

  **Gap found and closed independent of the raw spike evidence**: the
  originally-drafted option (c) only refreshed the JS-side mirror at
  true-session-end, which would have silently defeated Core Rule 5's actual
  purpose (a crash mid-visit still costs that visit's tending, since the
  hide-triggered write would just re-persist stale session-end data).
  ADR-0005 closes this — the mirror also refreshes on Input Abstraction's
  existing `tap`/`drag_end` signals, a cheap in-memory update, not a
  storage write, so AC11 (no periodic autosave) is unaffected.

  **The write-on-mutation fallback drafted below was NOT adopted** — B1
  passed on Chrome, so the hide-triggered write is viable; write-on-mutation
  remains documented in ADR-0005 as a rejected alternative for this round,
  not a fallback still in play. AC11's wording does **not** need the
  conditional clause that would have been required if it had been adopted.

  **Storage ceiling, unchanged and still relevant**: a JSON-stringified
  single-jar blob (ints, short `type_id` strings, small arrays) sits
  comfortably under typical per-origin `localStorage` quotas (~5MB
  Safari, ~10MB Chrome/Firefox) — confirmed safe for MVP's single-jar
  scope. Reassess when Multi-Jar Management (Alpha tier) extends this
  schema to multiple jars; not a concern today.
- **Save schema migration strategy**: MVP has no migration path — an
  older `schema_version` simply invalidates the whole blob (Edge Cases).
  Is that acceptable for the first post-launch content update, or does a
  real migration strategy need designing before schema changes ship?
  Owner: technical-director. Target: before the first save-schema-changing
  update.

  **Priority raised 2026-08-05 `/design-review`, round 12 (`game-designer`
  finding, `creative-director` ruling — RECOMMENDED, not blocking for MVP
  itself):** MVP ships a single schema version to zero existing players,
  so this does not block MVP implementation. But for a live "return day
  after day" retention product, the first schema-changing post-launch
  update is a near-certain event, not a hypothetical — under the current
  no-migration design it discards every existing player's save (now
  somewhat softened by the last-known-good fallback, Core Rule 7, but that
  only protects against a single bad write, not a deliberate version
  bump). **Hardened target**: must be resolved — even a minimal one-time
  best-effort field-carryover, or an explicit player-facing "this update
  resets your jar" notice — before the first schema-changing update
  ships, not left open indefinitely.
- ~~**Frequent-backgrounder persona never sees Time & Drift catch-up**~~ —
  **RESOLVED 2026-08-10**, as a direct consequence of
  `docs/architecture/adr-0006-time-drift-session-lifecycle.md` (written for
  a different reason — resolving `time-drift.md`'s own inherited BLOCKING
  gate on close-vs-background detection). That ADR rewrote Time & Drift's
  Core Rule 8 so `last_visit_timestamp` updates on every hide event, not
  only true session end — which means a habitual tab-switcher's catch-up is
  now measured from their most recent hide, not from a true-close event
  that may never fire for them at all. No separate fix needed here.
- ~~**`CONDITION_STREAK_MAX` cross-GDD coupling**~~ — **RESOLVED
  2026-08-09**: `ecosystem-simulation.md`'s required pre-implementation
  tuning pass picked `N_departure_ticks=25` (within its widened 10–30
  range; full trace in that document's Open Questions and Tuning Knobs).
  `CONDITION_STREAK_MAX` re-derived per its own definition,
  `max(N_spawn_ticks, N_departure_ticks) = max(3, 25) = 25` — updated
  throughout this document (Formulas, blob field table, AC5b's boundary
  pair). Nothing currently enforces this coupling automatically (still no
  `spawn_debounce_validity`-style gate, same unenforced-coupling class
  `content-data.md` tracks for `FOOTPRINT_MAX`) — if `N_departure_ticks`
  is ever retuned again, this constant must be manually re-derived again.
  Owner: systems-designer.
