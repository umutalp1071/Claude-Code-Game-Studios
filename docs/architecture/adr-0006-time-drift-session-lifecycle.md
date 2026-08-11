# ADR-0006: Time & Drift — Session Lifecycle and Tick-Batching Model

## Status
Accepted (2026-08-11 — gate-check re-run, Technical Setup → Pre-Production)

## Date
2026-08-10

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (session state machine; no dedicated engine-reference module exists for this — closest touchpoints are `Time`/`OS` singletons and the Web-export lifecycle bridging already covered by ADR-0005) |
| **Knowledge Risk** | HIGH per `VERSION.md` in general — but this ADR's specific dependency (distinguishing a true tab close from mere backgrounding) turns out not to be an engine-version question at all; see Decision. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` (no entries for `Time`/`OS.get_unix_time_from_system()`/`Engine.get_frames_drawn()` in either — confirmed empty, not skipped); `docs/architecture/adr-0002-signal-init-order-snapshot-architecture.md` (SessionBootstrap sequencing), `adr-0004-ecosystem-simulation-tick-architecture.md` (`advance_tick()`, pure-formula-script convention), `adr-0005-persistence-save-web-storage-strategy.md` (the pure-JS hide handler this ADR extends) |
| **Post-Cutoff APIs Used** | None. `Time.get_unix_time_from_system()`, `OS.has_feature()` are stable pre-cutoff APIs. |
| **Verification Required** | None new. This ADR resolves its own inherited BLOCKING gate architecturally (see Decision) rather than by testing — the underlying platform limitation (no reliable close-vs-background signal) is not something further browser testing would resolve. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (`EcosystemSimulation.advance_tick()`, called only by Time & Drift); ADR-0005 (Persistence/Save owns `last_visit_timestamp` storage; this ADR's Decision extends ADR-0005's pure-JS hide handler with one field). All three Proposed, same as this ADR. |
| **Enables** | Creature Behavior's ADR (depends on Time & Drift's CATCHING_UP/ACTIVE state, per `time-drift.md` Dependencies and `architecture.md`'s init-order step 7). |
| **Blocks** | Creature Behavior implementation — not yet epic'd. |
| **Ordering Note** | This ADR resolves `time-drift.md`'s own header BLOCKING gate ("empirical verification of close/unload vs. backgrounding detection"), inherited from `input-abstraction.md`. It is resolved architecturally, not by the verification spike — see Decision for why further testing would not have closed it. |

## Context

### Problem Statement

Two decisions are needed: (1) the mechanical tick-batching model — `architecture.md`'s Data Flow §3/§4 and API Boundaries already sketch this in outline (`get_state()`, `get_day_night_phase()`, `advance_tick()` called only by Time & Drift), and this ADR confirms and details it; (2) `time-drift.md`'s own inherited BLOCKING gate — Core Rule 8 requires updating `last_visit_timestamp` **only** on a true session end, never on mere backgrounding, and that distinction was flagged as depending on the same unverified Web-export browser-bridging class as Input Abstraction's Open Question (Gate A of the verification spike).

**Gate A's actual evidence does not close this gate.** A2 (the only Gate A result that reached PASS) tested whether `focus_exited` fires and its timing — it never tested, and structurally could not test, whether a real tab close is distinguishable from a tab switch. Checking this against the Page Lifecycle API's own documented behavior (not project-specific, not version-specific): **no reliable close-vs-background signal exists on the modern web platform in general.** `visibilitychange`→hidden and `pagehide` both fire in either case; `unload`/`beforeunload` are unreliable-to-absent on mobile Safari specifically (already noted in `time-drift.md`'s own Edge Cases) and are actively discouraged by browsers for bfcache-eligibility reasons. This is not a gap further browser testing would close — it is a documented platform limitation.

### Constraints

- No further browser/device testing is available (per explicit user decision, same constraint ADR-0005 operated under).
- Godot's autoload `_ready()` chain — and therefore `SessionBootstrap`'s entire session-start sequence (ADR-0002) — runs exactly once per actual page **load**. A backgrounding-then-refocus of the same tab never re-triggers it, regardless of duration. This is a hard engine fact, not a heuristic. **This fact is contingent on ADR-0005's `pageshow`/`event.persisted` reload guard remaining in place** — a bfcache restore without that guard would resurrect a frozen page without a real reload, and this ADR's whole catch-up mechanism would silently stop firing for that session with no compile-time or obvious runtime signal (godot-specialist review finding). Any future change touching ADR-0005's JS layer must preserve that guard or this ADR must be revisited.
- `last_visit_timestamp` has no UI presence (`time-drift.md` UI Requirements: N/A) and is read exactly once per session, at session start — it is pure internal bookkeeping, never observed mid-session.
- `persistence-save.md`'s own Open Questions already flag a related, previously-unresolved risk: "a player who habitually switches tabs/apps rather than closing... never triggers a true session end, so `last_visit_timestamp` never advances and Time & Drift's catch-up batch never fires for them." This ADR's Decision resolves that risk as a side effect, not a separate fix.

### Requirements

- Must compute `ticks_to_apply` correctly regardless of how the previous session actually ended (explicit close, silent OS-kill of a backgrounded tab, or a real close event that did fire).
- Must not regress the already-specified behavior for a quick tab-switch-and-return within the same still-open tab: no catch-up batch, `day_night_phase` unaffected (`time-drift.md` AC6, mostly preserved — see Decision for the one wording change).
- Must integrate with `SessionBootstrap`'s existing 11-step sequence (ADR-0002) without renumbering or reordering it.
- Must not reintroduce ADR-0005's B1 risk (GDScript executing during a hide event) for the timestamp update specifically.

## Decision

**Tick-batching model**: confirmed as sketched in `architecture.md`, no changes. `TimeDrift` (autoload, Feature) holds `_state: SessionState` (`{INACTIVE, CATCHING_UP, ACTIVE}`) and `_session_start_unix: int`. At `SessionBootstrap`'s steps 6-7 (Data Flow §3 — catch-up is step 6, the `CATCHING_UP → ACTIVE` transition is step 7, both performed by one atomic call), it reads `Persistence/Save.get_last_visit_timestamp()`, computes `elapsed_seconds`/`ticks_to_apply` via a pure formula script (below), calls `EcosystemSimulation.advance_tick()` exactly `ticks_to_apply` times as one atomic batch, then transitions `CATCHING_UP → ACTIVE`. `day_night_phase` is computed continuously during `ACTIVE` from wall-clock time since `_session_start_unix`, per `time-drift.md`'s own formula — no engine-version risk here, `Time.get_unix_time_from_system()` is stable pre-cutoff.

**Entry point (companion edit, ADR-0002 revision, 2026-08-10)**: the
sequence above was described narratively but never exposed as a callable
`SessionBootstrap` could actually invoke — `docs/consistency-failures.md`'s
TR-crosscutting-003 flagged this against ADR-0002's pseudocode, which
already assumed a method by this name. Formalized here:

```gdscript
func run_catchup_and_activate() -> void
```

Called exactly once, only by `SessionBootstrap`, spanning steps 6-7 as
described above. No change to the sequence itself — this is the name for
what already existed in prose.

**Session-boundary timestamp update — the substantive decision, made with explicit user sign-off, not unilaterally**: `last_visit_timestamp` updates on **every hide event** (`visibilitychange`→hidden or `pagehide`), not gated on distinguishing a true close from backgrounding. This is deliberately not what `time-drift.md` Core Rule 8 currently specifies — see GDD Requirements Addressed for the exact rewrite this ADR requires.

**Why this is correct, not just expedient:**
- The close-vs-background distinction is unnecessary for correctness, once you notice **what actually needs detecting is never "session end" — it's "the start of the next real page load,"** which Godot's own `_ready()`-runs-once-per-load behavior already gives for free, with zero ambiguity. The only genuinely underspecified thing was which timestamp to measure the NEXT session's elapsed time from. Stamping it on every hide (the last moment execution was still guaranteed) is a strictly better proxy for "the player was last known to be here" than trying to catch a close event that may never fire at all.
- **No regression against AC6's actual player-facing intent**: a quick tab-switch-and-return still produces `ticks_to_apply≈0`, because `elapsed_seconds` between two hide-stamps close together in time stays well under `seconds_per_tick` (7200s recommended). The *value* of `last_visit_timestamp` now changes on every hide, but nothing reads it again until the next real page load — there is no mid-session observable difference.
- **Fixes a previously-separate, already-flagged risk**: `persistence-save.md`'s "frequent-backgrounder never sees catch-up" Open Question is resolved as a direct consequence, not a separate patch — a player who backgrounds and resumes the same tab all day, then eventually loses that tab (OS-killed or genuinely closed) without a clean `unload`, now still gets a correct catch-up computation on their next real visit, measured from the last hide, not from a close event that may never have fired.
- **Does not reintroduce ADR-0005's B1 risk**: the hide-time stamp is written by ADR-0005's existing pure-JS listener (`Date.now()`, a plain JS call, zero engine involvement), not by a new GDScript hide hook. See Key Interfaces for the exact one-line extension to that already-written code.

### Architecture Diagram

```
SessionBootstrap steps 6-7 ──run_catchup_and_activate()──▶ TimeDrift (CATCHING_UP)
   now_unix: int = int(Time.get_unix_time_from_system())   # float -> int cast, see Key Interfaces
   elapsed_seconds: int = now_unix - PersistenceSave.get_last_visit_timestamp()
   ticks_to_apply = TimeDriftFormulas.ticks_to_apply(elapsed_seconds, seconds_per_tick, max_catchup_ticks)
   EcosystemSimulation.advance_tick() × ticks_to_apply   (one atomic batch)
   ──▶ ACTIVE (day_night_phase now runs continuously, cosmetic only)

True session end (foregrounded, GDScript-safe):
   TimeDrift sets last_visit_timestamp = int(Time.get_unix_time_from_system())
   ──▶ PersistenceSave.save() (ADR-0005, foreground path)

Hide event (visibilitychange/pagehide) — zero GDScript execution, extends ADR-0005's HideBridge:
   pure JS: blob.last_visit_timestamp = Math.floor(Date.now() / 1000);
            (then ADR-0005's existing promote + localStorage.setItem() logic, unchanged)
```

### Key Interfaces

`architecture.md`'s existing sketch for Time & Drift is **confirmed unchanged**:

```gdscript
# Time & Drift (autoload) — Feature. get_state()/get_day_night_phase() unchanged from architecture.md.
func get_state() -> SessionState  # enum {INACTIVE, CATCHING_UP, ACTIVE}
func get_day_night_phase() -> float  # 0.0–1.0
func run_catchup_and_activate() -> void  # companion edit, ADR-0002 revision (2026-08-10) — see Decision above. Called ONLY by SessionBootstrap, steps 6-7.

# godot-specialist review: Time.get_unix_time_from_system() returns float, not int — every
# call site feeding it into an int-typed slot (elapsed_seconds computation, _session_start_unix,
# set_last_visit_timestamp()'s argument) MUST cast explicitly:
#   var now_unix: int = int(Time.get_unix_time_from_system())
# Omitting this cast is a GDScript static-typing compile error, not a runtime bug — caught here,
# not left as an implementation trap. Both sides of the JS/GDScript timestamp comparison (Key
# Interfaces below) are whole-second Unix time once this cast is applied — same epoch, same
# underlying OS clock, no timezone concern.
```

```gdscript
# TimeDriftFormulas (new, non-autoload script — reuses ADR-0003's testable-pure-formula
# convention, registered as api_decision: testable_pure_formula_placement)
static func ticks_to_apply(elapsed_seconds: int, seconds_per_tick: int, max_catchup_ticks: int) -> int:
    if elapsed_seconds <= 0:
        return 0  # Edge Case: negative/zero elapsed (clock rollback) clamps to 0, no error
    return min(floori(float(elapsed_seconds) / seconds_per_tick), max_catchup_ticks)

static func day_night_phase(session_elapsed_seconds: float, cycle_duration_seconds: int) -> float:
    return fmod(session_elapsed_seconds, float(cycle_duration_seconds)) / cycle_duration_seconds
```

**One-line extension to ADR-0005's already-written pure-JS `HideBridge` handler** (not a new mechanism — see that ADR's Key Interfaces for the surrounding code, unchanged otherwise):

```javascript
window.__persist_hide = function () {
  if (document.visibilityState !== 'hidden') return;
  var blob = JSON.parse(window.__persist_mirror);
  blob.last_visit_timestamp = Math.floor(Date.now() / 1000);  // ADDED by ADR-0006
  window.__persist_mirror = JSON.stringify(blob);
  if (window.__persist_current_valid) {
    localStorage.setItem('save_last_known_good', localStorage.getItem('save_current'));
  }
  localStorage.setItem('save_current', window.__persist_mirror);
};
```

`Persistence/Save.set_last_visit_timestamp(ts: int) -> void` (architecture.md's existing sketch) is **unaffected** — it remains called only by Time & Drift, only at true session end (the foreground path). The hide-time update never goes through this GDScript function at all; it writes the persisted representation directly in JS, which is the entire point of avoiding the B1 dependency.

## Alternatives Considered

### Alternative: Best-effort close detection via `pagehide`/`beforeunload`, Core Rule 8 unchanged
- **Description**: Treat `pagehide` (or `beforeunload` where available) as a "probably a real close" signal, update `last_visit_timestamp` only there, accept it may simply not fire on some browsers (documented residual risk, same shape as ADR-0005's WebKit risk).
- **Pros**: Matches `time-drift.md`'s Core Rule 8/AC6/AC7 exactly as currently written — no GDD rewrite needed.
- **Cons**: Doesn't actually solve the problem, because the failure mode isn't rare — mobile Safari's OS-level app-switcher kill (the single most common way a mobile session actually ends) fires no JS event at all, ever. This isn't a residual edge case the way WebKit-vs-Chromium was for ADR-0005 (where Chromium data at least gave partial confidence); here, the primary target platform's most common termination path is structurally unreachable by this alternative's own mechanism, not just untested.
- **Rejection Reason**: Optimizes for GDD-text stability over actually working for the plurality of real sessions on the primary mobile target. Rejected with explicit user confirmation (this session).

## Consequences

### Positive
- Resolves `time-drift.md`'s own inherited BLOCKING gate architecturally — the underlying platform ambiguity is designed around, not left waiting on unavailable data.
- Fixes `persistence-save.md`'s "frequent-backgrounder never sees catch-up" Open Question as a side effect.
- No new GDScript-side hide hook, no new signal, no reintroduced B1 dependency — the fix is a one-line addition to an already-written, already-validated pure-JS handler.
- `architecture.md`'s public API sketch for Time & Drift needs zero changes.

### Negative
- `time-drift.md`'s Core Rule 8 and AC6/AC7 must be rewritten (see GDD Requirements Addressed) — this is a real, tested-behavior change, not a documentation clarification. Any story or test already written against the old AC6/AC7 wording would need updating (none exist yet — Time & Drift has no epic).
- `last_visit_timestamp`'s semantics are now "last known hidden moment," not "last true close" — a subtly different concept from what `time-drift.md`'s Overview describes. Future readers of the GDD need the Core Rule 8 rewrite to understand this, not infer it from the old wording.

### Risks
- **The gesture-triggered mirror refresh (ADR-0005) and this ADR's hide-time timestamp stamp both read/write the same JS-side `window.__persist_mirror` object.** If a future change to either mechanism changes the mirror's shape without updating both call sites, they could silently diverge. Mitigation: both are now documented in one place each (ADR-0005 Key Interfaces for the mirror structure, this ADR for the one field it adds) — any future ADR touching the mirror must check both.
- **No further verification is possible for the underlying platform behavior** (that no close-vs-background signal exists) — but unlike ADR-0005's WebKit gap, this isn't something a WebKit device would resolve either; it's a documented, cross-browser Page Lifecycle API characteristic, not a per-browser unknown. Confidence in this specific claim doesn't come from the (untested) verification spike at all.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| time-drift.md | Core Rules 1–6 (tick-batching, catch-up, cosmetic day/night cycle) | Confirmed unchanged — `TimeDriftFormulas` implements the Formulas section directly. |
| time-drift.md | **Core Rule 8 — REWRITE REQUIRED**: currently "`last_visit_timestamp` updates to the current time whenever a session truly ends (app close/unload — not backgrounding)". Must become: "`last_visit_timestamp` updates on every hide event (`visibilitychange`→hidden or `pagehide`) as well as true session end — there is no reliable way to distinguish the two on the Web platform, and gating the update on an undetectable signal leaves it permanently stale for sessions that end via an untrapped OS-level tab kill (the common case on mobile). This has no mid-session observable effect (see Edge Cases)." | This ADR's Decision. |
| time-drift.md | **AC6 — REWRITE REQUIRED**: currently asserts `last_visit_timestamp` is unchanged on backgrounding-then-refocus. Must become: `last_visit_timestamp` **may** update to the hide-moment's timestamp, but no new catch-up batch runs (Godot's `_ready()` chain does not re-execute for the same still-open tab) and `day_night_phase` is unaffected. | This ADR's Decision — the observable half of AC6 (no catch-up, no day/night discontinuity) is preserved; only the internal-bookkeeping half changes. |
| time-drift.md | **AC7 — wording note**: "session truly ends... last_visit_timestamp updates to the current time" remains true for the foreground path; add that the same update also happens (via the JS mechanism) on any hide, not exclusively at true end. | This ADR's Decision. |
| time-drift.md | Edge Cases (negative elapsed, first session, invalid/future timestamp) | `TimeDriftFormulas.ticks_to_apply()` clamps negative elapsed to 0; invalid/future-timestamp handling remains Persistence/Save's `save_blob_validity` responsibility (unchanged, per ADR-0005/persistence-save.md — this ADR does not duplicate that gate). |
| architecture.md | Data Flow §3/§4 steps 6–7, API Boundaries (`get_state()`, `get_day_night_phase()`) | Confirmed unchanged; this ADR is the detailed decision the sketch already implied. |
| persistence-save.md | Open Question: "frequent-backgrounder persona never sees Time & Drift catch-up" | Resolved as a consequence of this ADR's Decision, not a separate fix — see Consequences → Positive. |

## Performance Implications
- **CPU**: `TimeDriftFormulas.ticks_to_apply()` is O(1); the catch-up batch itself is `EcosystemSimulation.advance_tick()` × ≤84, already budgeted under ADR-0004. `day_night_phase` is one `fmod` per frame during ACTIVE — negligible.
- **Memory**: No new state beyond `_state`/`_session_start_unix` (two scalars).
- **Load Time**: Catch-up batch runs once at session start, before first render (per `time-drift.md` AC11/Core Rule 5) — bounded by `max_catchup_ticks=84` × `EcosystemSimulation.advance_tick()`'s own per-tick cost.
- **Network**: N/A.

## Migration Plan
No existing implementation. `time-drift.md`'s Core Rule 8/AC6/AC7 must be updated before or alongside this ADR's write (see GDD Requirements Addressed) to avoid a developer implementing against the stale wording.

## Validation Criteria
- Unit-level: `TimeDriftFormulas.ticks_to_apply()` against `time-drift.md`'s AC1/AC2/AC3/AC3a/AC4/AC5/AC9 (all pure-logic, already testable without any trigger plumbing).
- Integration-level: AC10/AC11 (no re-firing during ACTIVE, batch atomicity) against a real `SessionBootstrap` sequence.
- The hide-time timestamp stamp (AC6's rewritten form) is validated the same way ADR-0005's own mirror mechanism is — Web build required, not unit-testable in isolation, since it's pure JS.

## Related Decisions
- Extends `docs/architecture/adr-0005-persistence-save-web-storage-strategy.md`'s `HideBridge` JS handler with one field (`last_visit_timestamp`) — that ADR's Key Interfaces code block is updated alongside this one to keep a single authoritative version, not two diverging copies.
- Depends on ADR-0002 (SessionBootstrap sequencing), ADR-0004 (`advance_tick()`).
  **Companion-edited by ADR-0002's 2026-08-10 revision** to add
  `run_catchup_and_activate()` to Key Interfaces — see Decision, "Entry
  point (companion edit, ADR-0002 revision, 2026-08-10)."
- Resolves `time-drift.md`'s inherited BLOCKING gate (originally from `input-abstraction.md`'s Open Question) — architecturally, not via the verification spike, which never tested and structurally could not have tested this specific claim.
