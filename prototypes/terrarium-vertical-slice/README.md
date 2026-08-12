# Terrarium — Vertical Slice (Pre-Production Gate)

**VERTICAL SLICE — NOT FOR PRODUCTION.** This is throwaway, near-production-
quality reference code for the `/vertical-slice` gate, not a codebase to
extend. If this validates the core loop, Production is written from scratch
against the real GDDs and `docs/architecture/control-manifest.md`, using this
only as a working reference — never migrated directly.

**Validation question**: Does a player experience the calm caretaker
fantasy — noticing what changed, tending the jar, and seeing a session
boundary produce visible drift — within 5 minutes, without guidance?

**This build is UNTESTED against a real Godot engine.** It was written by an
agent with no Godot binary available in its environment. Nobody has opened
this in the Godot editor yet. Expect first-run errors — see "Known Risks"
below for the specific places most likely to need a fix.

---

## How to open and run

1. Open Godot **4.7.1**, "Import" this folder
   (`prototypes/terrarium-vertical-slice/`) as a project.
2. Let the editor finish its first import pass (this registers the
   `class_name` scripts — `PlantTypeDef`, `ObjectPlacementMath`, etc. — in
   its global script-class cache; several scripts reference each other by
   class name and won't resolve correctly until this has run once).
3. Run the project (F5). It should open directly into `scenes/Main.tscn`.
4. You'll see a placeholder jar (a brown ellipse) with three plant markers,
   a gray rock, and a debug panel in the top-left corner.
5. **Tap/click** open jar space (not on the rock) to water — `jar_moisture`
   rises immediately in the debug label.
6. **Drag** the rock to reposition it.
7. Use the **"Advance Session"** buttons (see below) to see day/night
   drift, plant growth, and creature spawn/departure.

## The "Advance Session" debug control

The real design (`persistence-save.md`, ADR-0005) saves to browser
`localStorage` on tab-hide/close and restores on the next real page load —
so in production, "a visit" is however long you're actually away. That's
correct for the real game but useless for a single sitting in the editor.

This slice's **scope simplification**: `SessionBootstrap.advance_session(elapsed_seconds)`
is an in-memory stand-in for that real session boundary. When you press one
of the three buttons ("+2 hours" / "+1 day" / "+1 week"), it:

1. Snapshots current live state (`EcosystemSimulation.get_snapshot()` +
   `ObjectPlacement.get_snapshot()`) into an in-memory `_blob` — standing in
   for "what got saved."
2. Re-runs `SessionBootstrap.start_session()` — the *exact same*
   restore → `TimeDrift.run_catchup_and_activate(elapsed_seconds)` →
   `CreatureBehavior.resolve_session_start()` → `DiscoverySurfacing.compute_delta()`
   sequence a real session boundary would run — just fed `elapsed_seconds`
   directly instead of computing it from a real wall clock and a
   `localStorage`-persisted `last_visit_timestamp`.

Everything downstream of that call is real, unmodified game logic: tick
count, moisture/light decay, growth/decay/stall, creature spawn/departure
debounce, and the Discovery Surfacing reveal queue all run for real. Only
the *source* of "how much time passed" is fake.

---

## Scope simplifications (agreed up front, not silent cuts)

### 1. Persistence
**Not implemented**: ADR-0005's real Web `localStorage`/JS-mirror/hide-listener
design (already validated separately as a spike — see
`prototypes/web-export-spike/`). **Implemented instead**: the in-memory
"Advance Session" debug control described above. `PersistenceSave` does not
exist as an autoload in this project at all — `SessionBootstrap` reads/writes
a plain in-memory `Dictionary` instead of calling into it. Why: this lets a
playtester see day/night drift and creature spawn/departure within one
sitting instead of literally closing the browser tab and waiting hours/days.

### 2. Ambient Audio
**Implemented**: only Core Rule 1's base loop — starts on session-ACTIVE,
stops on session-INACTIVE, one real `AudioStreamPlayer` node, no fade.
**Not implemented**: the watering-swell and discovery-bed-shift reactive
audio layers (`ambient-audio.md` Core Rules 2-3). No audio *asset* ships
with this slice either — `AmbientAudio._player.stream` is left `null`, so
`play()`/`stop()` are exercised on every session-state transition (the code
path is real) but nothing is actually audible until a real `AudioStream`
(e.g. an `.ogg`) is assigned to it. Drop one in and set `_player.stream` in
`scripts/autoload/ambient_audio.gd` to hear it.

### 3. Diorama Rendering
**Not implemented**: no Accepted ADR exists for Diorama Rendering (ADR-0009
is still Status: Proposed) and no diorama-realism art assets exist yet.
**Implemented instead**: `scripts/jar_view.gd` — plain 2D primitives only
(`draw_circle`/`draw_colored_polygon`, no sprites, no shaders, no lighting):
a hand-drawn ellipse for the jar and a background wash, colored circles for
the 3 plants sized/colored loosely by `growth_stage`, a gray circle for the
rock, and a colored circle per creature visible only while
`CreatureBehavior` holds a live instance for it. A background tint shifts
with `TimeDrift.get_day_night_phase()` and `EcosystemSimulation.light_level`.
Discovery Surfacing's active cues render as a plain yellow ring — no
per-category diegetic light/material treatment (`discovery-surfacing.md`'s
Visual/Audio Requirements describe a much richer, category-specific
treatment; this is a single generic placeholder covering all four
categories). **This is explicitly not representative of final art or final
UX polish.**

---

## What's real (full mechanical implementation, not simplified)

All formulas and state machines below are transcribed directly from their
GDDs and follow `docs/architecture/control-manifest.md`'s Required Patterns
per layer — see the final report for the per-system rule mapping.

- **Content Data** — `.tres`-authored `PlantTypeDef`/`CreatureTypeDef`/
  `ObjectTypeDef`, load-time `definition_validity` + iterative
  `spawn_reference_validity` fixpoint (3 plants, 2 creatures, 1 object).
- **Input Abstraction** — mouse+touch → `tap`/`drag_start`/`drag_move`/
  `drag_end`, per-device thresholds, watchdog timer, focus-loss interruption.
- **Object Placement** — drag/drop the rock, in-bounds + overlap validity,
  tap-on-footprint wobble.
- **Ecosystem Simulation** — `jar_moisture`/`light_level` two-axis drift,
  three-state (GROWING/STALLED/DECAYING) plant growth, sequential
  Snail→Moth spawn conditions, spawn/departure debounce
  (`N_spawn_ticks=3`, `N_departure_ticks=25`), `last_known_position`/
  `was_present_during_batch` for the unwitnessed-full-cycle case.
- **Tending Input** — tap-to-water, footprint exclusion, no cooldown.
- **Time & Drift** — real tick-conversion math (`seconds_per_tick=7200`,
  `max_catchup_ticks=84`), cosmetic day/night phase — only the *source* of
  `elapsed_seconds` is simplified (see above).
- **Creature Behavior** — SPAWNING/WANDERING/PAUSING/DEPARTING, rejection-
  sampled destinations, session-start "settle directly into WANDERING/
  nothing, never an animation for a batch-internal transition."
- **Discovery Surfacing** — delta computation, 4-category staggered reveal
  queue with deliberate overlap, `full_cycle` departure exception.

---

## Known risks (honest, specific — not fully confident these are clean)

1. **`.tres` text-resource syntax is a best guess, unverified against a real
   engine.** Specifically the typed-array literal
   `Array[String](["a", "b"])` inside `[resource]` blocks (all 6 `.tres`
   files under `data/content/`) and the `script_class="PlantTypeDef"`
   header attribute. If Godot 4.7.1 rejects either on first open, the fix
   is almost certainly small (adjust the array literal syntax, or convert
   `visual_stages`/`required_ids` to untyped `Array` as a fallback) — but
   it is not confirmed correct.
2. **Autoload class-name resolution order.** Several autoload scripts
   reference other `class_name`-registered scripts (`PlantTypeDef`,
   `ObjectPlacementMath`, `CreatureState`, etc.) that are not themselves
   autoloads. This depends on Godot having already built its global script
   class cache (normally happens automatically on first editor import — see
   "How to open and run" step 2). If it hasn't, expect "Identifier not
   declared" parse errors on first run that clear up after a
   re-import/reload.
3. **Touch `device_id` vs. `DEVICE_ID_MOUSE` collision space is genuinely
   unverified even in the source GDD.** `input-abstraction.md`'s own Open
   Questions flag this as unresolved; this implementation uses raw
   `event.index` as the touch device id with no collision guard. Mouse-only
   testing (editor Play, desktop browser) is unaffected either way.
4. **`Window.focus_exited`/`focus_entered` firing reliably on Web export**
   is flagged BLOCKED/unverified in `input-abstraction.md`,
   `time-drift.md`, and `discovery-surfacing.md` themselves — this
   implementation follows the documented working hypothesis. Editor/desktop
   testing exercises a real `focus_exited` signal (alt-tab); real Web-export
   behavior is untested here (that's `prototypes/web-export-spike/`'s job,
   not this slice's).
5. **`Node2D.to_local()` coordinate-space assumption.** `jar_view.gd`'s Jar
   node has no `Camera2D` and no parent transform beyond `Main`'s own
   (identity) transform, so viewport-space and the jar's parent-global-space
   should coincide — but this hasn't been confirmed to actually behave that
   way at runtime, only reasoned through.
6. **No automated tests.** There is no Godot binary in the authoring
   environment to run GUT (or even headless-import the project) to catch
   any of the above before hand-off. Every acceptance criterion in the
   source GDDs is implemented against, but none is mechanically verified.
7. **Plant screen positions are presentation-only placeholders**, not part
   of any GDD (no MVP system assigns plants an `(x,y)`) — hardcoded in
   `jar_view.gd`'s `PLANT_LAYOUT`, purely so this placeholder renderer has
   somewhere to draw them.

## Judgment calls made on spec ambiguity

- **`spawn_conditions` evaluation**: `content-data.md` explicitly leaves
  "how this expression is authored and evaluated" as Ecosystem Simulation's
  implementation concern. This slice hardcodes Snail's and Moth's two
  concrete conditions as named static functions in `EcosystemFormulas`
  (`snail_spawn_condition_met`/`moth_spawn_condition_met`) rather than
  building a generic expression parser — matches the GDD's own worked
  Formulas tables exactly, and a 2-creature MVP has no real need for a
  general parser.
- **Discovery Surfacing's `registration_index`** is derived from
  `EcosystemSimulation.get_plant_ids()`/`get_creature_ids()`, which in turn
  reflect `ContentData`'s insertion order. `ContentData` scans and sorts
  paths *within* each of the 3 category directories separately (plants,
  then creatures, then objects), not as one merged global sort — a
  reasonable, still fully deterministic reading of `content-data.md` Core
  Rule 7, but categories are never actually compared against each other in
  practice (Growth items only ever come from plants, Arrival/Departure only
  from creatures), so this distinction is not currently observable anyway.
- **Ambient Audio's reactive layers were cut entirely** rather than stubbed
  with empty no-op methods, per the brief's explicit scope cut — there is
  no `_on_watering_applied()`/discovery-cue-poll code path to re-enable
  later, it would need to be added fresh from `ambient-audio.md`.

---

## File list

See the parent orchestrator's final report for the full annotated file list
and control-manifest.md rule mapping per system.
