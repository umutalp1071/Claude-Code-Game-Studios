# Cross-GDD Review Report

Date: 2026-08-05
GDDs Reviewed: 8
Systems Covered: Content Data, Input Abstraction, Object Placement, Ecosystem Simulation, Tending Input, Time & Drift, Creature Behavior, Persistence/Save

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

🔴 **Save-confirmation cue is specified to fire only at the two moments nothing can render it**
`persistence-save.md` (Core Rule 8, States and Transitions, UI Requirements, AC13/13a) vs `time-drift.md` (Core Rule 8, Edge Cases) and `persistence-save.md`'s own Open Questions.

Core Rule 8 requires the cue after every successful save write. Core Rule 5's only two write triggers are (a) true session end — the page tearing down — and (b) tab backgrounded — the tab not visible. There is no third trigger (AC11 explicitly forbids one). The cue is mandated to fire exclusively when the player is either not looking at the tab or has already closed it — compounded by this document's own Open Question that the WASM main loop may be suspended before the hidden-tab write (and thus the cue) ever executes. AC13 passes on a signal nobody can perceive; the States table also only attaches the cue to `SAVING`, not the backgrounding-write row, so the document is internally split on whether backgrounding cues at all.

**Fix direction**: either add an observable in-session trigger (the pre-drafted write-on-mutation fallback already in Open Questions would give one), or re-scope Core Rule 8 to a *deferred* confirmation shown on the next session start ("your jar was saved") — observable, fires once per visit, matches Pillar 2 directly.

🔴 **Last-known-good fallback provides zero protection against the failure causes it was written to cover**
`persistence-save.md` (Core Rule 7, Formulas, AC12/12a) vs `content-data.md` (Edge Cases exclusion rules).

Core Rule 7 justifies itself against "devtools tampering, real corruption, **or an ordinary future content-balance edit** (a renamed `type_id`, a narrowed `max_stage`) that this system cannot distinguish from corruption." But `save_blob_validity`'s type_id-existence and growth_stage/max_stage clauses are evaluated against the **current** Content Data registry — so a renamed/removed `type_id` or a narrowed `max_stage` fails the current blob *and* the last-known-good blob identically, since both were written against the same now-stale content. AC12's precondition ("last-known-good blob exists and itself passes validity") can never be satisfied for exactly the class Core Rule 7 was added to protect against — the system always falls through to full default-init, the very outcome the fallback exists to prevent. The exposure is broader than rename/remove: any definition Content Data excludes at load (a malformed content file in a future patch) silently wipes every player's jar through both tiers at once.

**Fix direction**: either restrict Core Rule 7's stated scope to corruption/tampering only (moving the content-edit case fully under the Save Schema Migration open question), or make type_id/max_stage resolution failures a distinct, non-blob-discarding failure class.

🔴 **Creature spawn/departure can only occur inside Time & Drift's unobservable catch-up batch — Creature Behavior's SPAWNING/DEPARTING rules and ACs are unreachable as specified**
`time-drift.md` (Core Rules 5/6, AC11) vs `creature-behavior.md` (Core Rules 1/4/7, AC1/2/10/11/12/15) and `ecosystem-simulation.md` (Core Rules 6/7).

Every PRESENT/ABSENT transition happens on a tick, and every tick fires only inside Time & Drift's atomic, non-rendering catch-up batch ("no intermediate/partial state is observable... the full batch completes before the jar is rendered," AC11). But Creature Behavior specifies a **live, animated** response to every such transition — SPAWNING placement, a "moves toward a jar edge and fades out" DEPARTING exit, mid-state interrupt semantics — none of which can complete instantaneously inside an atomic invisible batch. Creature Behavior's own Core Rule 8 companion note even calls away-departure "**more common** than the live, in-session DEPARTING case," when under Time & Drift's locked model the live case has *zero* frequency, not lower frequency. AC15 (a restored PRESENT creature enters WANDERING at the first live frame) is not sequenced against the catch-up batch either — if that same batch resolves the creature's departure debounce (very plausible at a typical 8–12 tick daily batch against `N_departure_ticks=5`), the creature is ABSENT by the first live frame and AC15 cannot pass.

**Fix direction**: `creature-behavior.md` must state explicitly how batch-resolved transitions present at the first live frame (snap to final state with animations skipped, most likely — the same mechanism Core Rule 8 already uses for restore-entry, just needs its scope widened to "state once session-start processing fully resolves," not "the raw pre-catchup blob value").

🔴 **Detail-event state has no home in the save blob — a live violation of Persistence/Save's own blob-completeness principle**
`ecosystem-simulation.md` (Core Rule 10, Interactions with Other Systems) vs `persistence-save.md` (Core Rule 1, AC1, AC2a).

Persistence/Save's own Core Rule 1 states the standing obligation: the blob must contain "any counter, accumulator, or direction flag whose value on tick N depends on tick N-1." Ecosystem Simulation's Interactions table lists a per-plant detail-event flag as state Diorama Rendering and Discovery Surfacing both read — but it appears in neither Core Rule 1's enumeration, `save_blob_validity`, nor AC1/AC2a. Ecosystem Simulation never specifies the flag's lifetime, so either it's silently zeroed at every session boundary (the exact failure class Core Rule 1 exists to prevent — it has already happened twice before, per this document's own history) or it never persists at all, meaning the Pillar 4 rare-bloom ("a real MVP mechanic, not decoration") can only ever be shown once per catch-up batch. AC2a claims to be a generic round-trip test that would "fail generically" on any such omission — it is written as a fixed field enumeration, so it does not actually do this.

**Fix direction**: `ecosystem-simulation.md` defines the detail-event flag's persistence lifetime; `persistence-save.md` adds it to Core Rule 1, the validity formula, and AC1.

### Warnings (should resolve, but won't block)

⚠️ **Entity registry (`design/registry/entities.yaml`) is stale in 5 places** — `jar_moisture_tick`'s combined formula (now two independent operations per Core Rule 5's round-14 correction), `save_blob_validity`'s clause order (pre-reorder), `OPTIMAL_HOLD_TICKS_MAX`'s notes (still cite the old 10-tick threshold and "no cap" claim), every plant entity's `max_stage` field (Content Data explicitly states no such field exists — it's derived from `visual_stages.length`), and missing `pause_duration_min/max` entries for Snail/Moth.

⚠️ **`persistence-save.md`'s own Variables table row for `OPTIMAL_HOLD_TICKS_MAX` still reads "no natural upper bound in legitimate play"** — seven lines below the prose paragraph that was corrected today to say the achievable ceiling is 9 ticks. The correction didn't propagate to the table.

⚠️ **`CONDITION_STREAK_MAX=5` is pinned as a literal in AC5b, but Ecosystem Simulation's own documented safe tuning range for `N_departure_ticks` (4–8) can legally exceed it.** A retune to 7 or 8 (fully legal in its own GDD) makes `condition_streak_ticks` legitimately reach values `save_blob_validity` would reject, discarding every player's save at every future load. Only the derived form (`max(N_spawn_ticks, N_departure_ticks)`) is safe to pin against.

⚠️ **Content Data's minimum light-band width (15) admits plants for which Ecosystem Simulation's detail event is mathematically unreachable** (achievable streak caps at 4 ticks at that width, below the stated safe-range floor of 5) — not live in MVP data, no validity check spans the two constants.

⚠️ **Persistence/Save doesn't reciprocate Creature Behavior's declared dependency** — `creature-behavior.md` lists Persistence/Save as a soft dependency; `persistence-save.md`'s own Dependencies/Interactions sections don't list Creature Behavior back, violating this project's own bidirectionality rule. The coupling is load-bearing on Persistence's side (its `creature_in_bounds` clause exists specifically because of Creature Behavior's restore-entry rule).

⚠️ **`systems-index.md`'s dependency map and "Circular Dependencies: None found" claim are both stale** — Persistence/Save's and Diorama Rendering's rows are missing dependencies several GDDs already declare, and a genuine implementation-gating cycle now exists (Ecosystem Simulation ↔ Diorama Rendering: Ecosystem Simulation is "not implementation-complete" until Diorama Rendering renders `light_level`, while Diorama Rendering depends on Ecosystem Simulation).

⚠️ **`creature-behavior.md` asserts a systems-index gap (Diorama Rendering row missing Creature Behavior) that no longer exists** — already corrected in `systems-index.md` row 10; both stale notes should be struck.

⚠️ **`content-data.md` describes the `pause_duration` per-type companion edit as still outstanding in five places** — `creature-behavior.md` already landed it. Separately, ownership of the concrete Snail/Moth values is now circular: Creature Behavior sources them from Content Data's "illustrative fixture," while Content Data's own AC7 note disclaims those same values as illustrative-only, not real tuning data. Values agree today; nobody actually owns them.

⚠️ **Jar ellipse geometry `(cx,cy,rx,ry)` is load-bearing across four GDDs but explicitly disclaimed as owned by none** — Object Placement calls it "fixed scene geometry... not a designer-facing gameplay knob" while Content Data, Creature Behavior, and Persistence/Save all derive hard constants or reused formulas from it. Only plausible owner (Diorama Rendering) is unauthored.

⚠️ **Object Placement's AC6a (4 simultaneous objects) cannot be built from the pinned MVP content set (1 repositionable object) and cannot be persisted** — Persistence/Save's blob serializes a single object position, not an array, so `no_overlap`'s "generalizes to any number of objects" claim has no corresponding save schema today.

---

## Game Design Issues

### Blocking

🔴 **Every multi-day absence returns the player to an empty jar — the one guaranteed, repeatable outcome, and it reads as punishment, not "different"**
`ecosystem-simulation.md` (Creature Spawn Conditions, plant moisture bands) + `time-drift.md` (Formulas' "Honest limitation," Open Questions).

Traced from the documented baseline (`jar_moisture=75`, `-3`/tick): Moss and Fern both exit their moisture bands by tick ~12-14, so `moss.growth_stage + fern.growth_stage ≥ 6` fails and Snail departs ~5 ticks later; Flower drops off `max_stage` even sooner, taking Moth with it. A weekend away (~40-46 real hours at the documented `seconds_per_tick`) costs **both** creatures, every single time, with no player action able to prevent it. This directly fails Pillar 2's own design test ("a decay mechanic that punishes neglect" vs. "just looks different") and Pillar 1's "alive enough to keep surprising you" — the jar converges to the *same* empty state on every return. Time & Drift's existing Open Question scopes convergence to plants only and rules it non-blocking for Pillar 1; the creature consequence is traced nowhere and owned by nobody.

**Recommendation**: give creature departure a longer floor than plant dormancy, or a dormancy-tolerant spawn clause, so absence changes the jar without emptying it of both residents.

🔴 **The save-confirmation cue cannot be seen at either moment it's specified to fire** — same root cause as the consistency finding above; recorded here too because it's independently a design-intent failure (the stated purpose, letting the player trust Pillar 2's promise, isn't delivered by the mechanism as designed), not just a spec inconsistency.

### Warnings

⚠️ **One risk-free moisture optimum with no counterbalancing cost** — `jar_moisture` held at 75 (the intersection of all three plants' bands) uniquely maximizes growth for all three plants with zero tradeoff between them; over-watering to 100 is worse but a single "right answer" exists at 75 with nothing pulling against it. `tending-input.md`'s own open question about whether 100 is optimal is already answerable "no" from these bands and should be closed.

⚠️ **Attention budget is under-filled for a 5-15 minute session, not overloaded** — only 2 active systems (Tending Input, Object Placement) against passive/tick-gated everything else; `time-drift.md`'s own Player Fantasy already concedes the back half of a session "would read as inert."

⚠️ **Four GDDs each independently describe themselves as carrying the game's core hypothesis** (Ecosystem Simulation, Creature Behavior, Time & Drift, Tending Input) — not competing loops (all point at the same "notice what changed" hook), but nothing indicates priority order if scope needs to be cut.

⚠️ **Pillar 4's only MVP expression (the rare-bloom detail event) has a structural frequency ceiling (~1 per 3.3 real days jar-wide under perfect care) and no tuning-pass exit criterion for bloom frequency specifically** — only for net growth and Snail reachability.

---

## Cross-System Scenario Issues

Scenarios walked: 3

1. Session start: Persistence/Save restore → Time & Drift catch-up batch → Creature Behavior state resolution
2. Live tending: watering (Tending Input) → Ecosystem Simulation moisture/growth response, evaluated against both documents' own Player Fantasy claims
3. Discovery Surfacing's accumulating cross-GDD obligations (process risk, not a mechanical scenario)

### Blockers

🔴 **Scenario 1 — Time & Drift catch-up batch vs. Creature Behavior's animated transitions** — same root cause as, and independently confirmed by, the consistency-pass finding above (both discovered this from different reading paths, which strengthens confidence it's real). No further detail beyond what's recorded there.

🔴 **Scenario 2 — Watering's stated live-growth feedback is structurally impossible under the locked tick model** — `ecosystem-simulation.md`. Its own Overview claims "watering visibly raises moisture and **nudges growth**," and `tending-input.md`'s Player Fantasy claims "moisture rises, and **within a tick or two the plants' condition visibly shifts**." But `growth_stage` changes are exclusively tick-driven (Ecosystem Simulation Core Rule 3), and ticks *never* fire live during an ACTIVE session (Time & Drift Core Rule 6: "no live ticking during an open session"). No amount of watering during a live session can ever visibly move a plant's `growth_stage` — only `jar_moisture` itself changes live. This is stale language, not a design intent: it predates Ecosystem Simulation's own round-14 correction that fully decoupled watering from ticks (Core Rule 5), and neither document's Overview/Player Fantasy was updated to match afterward. **Fix direction**: correct both documents' framing to describe what's actually true — watering's live payoff is moisture-only; growth is a *next-visit* payoff, which is a legitimate design (matches the "morning coffee, check what changed" loop) but should be described as such rather than promising same-session growth feedback the mechanics don't deliver.

### Warnings

⚠️ **Scenario 3 — Discovery Surfacing (unauthored) has already accumulated three separate cross-GDD "must deliver X" obligations** (Time & Drift's experiential ACs, Creature Behavior's departure-while-away framing, Ecosystem Simulation's state-delta surfacing) before it exists. Recommend its eventual GDD open with a consolidated checklist of these inherited requirements pulled from the other documents' Open Questions, so none is dropped during authoring.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `persistence-save.md` | Save-confirmation cue unobservable at both its trigger points | Consistency + Design | Blocking |
| `persistence-save.md` | Last-known-good fallback doesn't protect against its own stated failure causes | Consistency | Blocking |
| `persistence-save.md` | Detail-event state missing from blob | Consistency | Blocking |
| `persistence-save.md` | Stale `OPTIMAL_HOLD_TICKS_MAX` Variables-table row | Consistency | Warning |
| `persistence-save.md` | `CONDITION_STREAK_MAX` pinned as unsafe literal | Consistency | Warning |
| `persistence-save.md` | Missing reciprocal Creature Behavior dependency | Consistency | Warning |
| `creature-behavior.md` | SPAWNING/DEPARTING animations unreachable as specified; AC15 not sequenced against catch-up batch | Consistency | Blocking |
| `creature-behavior.md` | Stale "systems-index gap" notes (already fixed) | Consistency | Warning |
| `ecosystem-simulation.md` | Creature departure math empties the jar on every multi-day absence | Design | Blocking |
| `ecosystem-simulation.md` | Overview's "watering... nudges growth" is stale vs. round-14 tick decoupling | Consistency | Blocking |
| `tending-input.md` | Player Fantasy's "within a tick or two... visibly shifts" is stale vs. locked tick model | Consistency | Blocking |
| `tending-input.md` | Open question about `jar_moisture=100` optimality already answerable from locked band data | Design | Warning |
| `content-data.md` | Describes already-landed `pause_duration` companion edit as outstanding in 5 places | Consistency | Warning |
| `content-data.md` | Light-band minimum width admits detail-event-unreachable plants | Consistency | Warning |
| `object-placement.md` | AC6a unbuildable/unpersistable at current MVP + Persistence/Save scope | Consistency | Warning |
| `systems-index.md` | Stale dependency map; "no circular dependencies" now false | Consistency | Warning |
| `design/registry/entities.yaml` | Stale in 5 places | Consistency | Warning |

---

### Verdict: FAIL

Four blocking consistency issues and two blocking design issues, several concentrated in `persistence-save.md`'s same-day revision. None require a large redesign — every blocker has a stated one-document (or two-document) fix direction above — but architecture should not begin against these until resolved.

### Required actions before re-running:
1. `persistence-save.md`: rescope the save-confirmation cue trigger (deferred-to-next-load, or add an observable in-session trigger); narrow or fix the last-known-good fallback's stated scope; add detail-event state to the blob.
2. `ecosystem-simulation.md`: define the detail-event flag's persistence lifetime; correct the Overview's stale "watering nudges growth" claim; address (or explicitly accept and document) the creature-departure-on-absence punishing pattern.
3. `creature-behavior.md`: state how batch-resolved SPAWNING/DEPARTING transitions present at the first live frame; sequence AC15 against the catch-up batch.
4. `tending-input.md`: correct the Player Fantasy's stale same-session growth claim.
