# Architecture Review Report — Pass 3

Date: 2026-08-10
Engine: Godot 4.7.1 (Web export, Compatibility renderer / OpenGL ES3 /
WebGL2)
GDDs Reviewed: 11 (+ `game-concept.md`, `systems-index.md`)
ADRs Reviewed: 10 (ADR-0001 through ADR-0010, all `Status: Proposed`)

This is the third `/architecture-review` pass, run the same day as passes 1
and 2. Since pass 2, three ADRs were newly written: ADR-0008 (Input Gesture
Abstraction), ADR-0009 (Diorama Rendering Light2D/Web strategy), ADR-0010
(Discovery Surfacing reveal-queue architecture).

---

## Traceability Summary

Total requirements: 83
✅ Covered: 55 (66.3%)
⚠️ Partial: 13 (15.7%)
❌ Gaps: 15 (18.1%)

Up from pass 2 (80 total, 45% / 7.5% / 47.5%). Real, measurable progress —
Input Abstraction, Diorama Rendering, and Discovery Surfacing's
reveal-queue half all moved from pure Gap to mostly Covered. The full
per-requirement matrix is in `docs/architecture/architecture-traceability-index.md`
(updated this pass); this report covers the delta and the blocking findings.

**Correction to the working assumption going into this pass**: not every
system that needs an ADR has one. `architecture.md`'s own Required ADRs
list still names two more systems that were never written or folded
elsewhere:

### Coverage Gaps (no ADR exists)

❌ **Tending Input** (6 requirements — tap-to-water routing, footprint
exclusion, single-trigger-per-tap guarantee, no cooldown, tap-precedence
vs. Object Placement, downstream cue-trigger exposure)
  Suggested ADR: `/architecture-decision tending-input`
  Domain: Gameplay routing
  Engine Risk: LOW
  Note: `architecture.md` itself suggested this "may fold into the
  cross-cutting signal-architecture ADR (ADR-0002)" — checked ADR-0002's
  GDD Requirements Addressed table directly: `tending-input.md` is never
  mentioned. It was not folded in. This should be an explicit decision
  (fold in vs. stand alone), not a silently-dropped suggestion.

❌ **Ambient Audio** (7 requirements — single-`AudioStreamPlayer`
loop architecture + browser autoplay-gesture handling, reactive layer
boosts, persisted `ambient_volume`/`muted` explicitly excluded from
`save_blob_validity`'s all-or-nothing gate, mute/volume UI control)
  Suggested ADR: `/architecture-decision ambient-audio`
  Domain: Audio
  Engine Risk: LOW-MEDIUM (AudioServer bus setup, Web autoplay policy)

❌ **TR-discovery-surfacing-010** — `pacing_delay`/`cue_fade_duration`
must be data-driven per `coding-standards.md`'s "gameplay values must be
data-driven" rule; ADR-0010 doesn't address storage/config at all.
  Suggested fix: small addendum to ADR-0010, not a new ADR.
  Domain: Config
  Engine Risk: LOW

---

## Cross-ADR Conflicts

### 🔴 Conflict 1 (TR-crosscutting-003) — BLOCKING, still open, 3rd pass flagging this unchanged

ADR-0002's `SessionBootstrap._ready()` pseudocode has not been revised
since pass 1. Re-verified this pass against the *current* Key Interfaces
of all 6 systems it calls into:

| # | ADR-0002 pseudocode call | Actual declared Key Interface (this pass) | Status |
|---|---|---|---|
| 1 | `ContentData.load_registry()` | ADR-0001: only `get_definition(id) -> Resource` | Undeclared |
| 2 | `PersistenceSave.load_blob()` | ADR-0005: `load() -> bool` + `get_restored_blob() -> Dictionary` (pull-based, two calls) | Nonexistent — and structurally incompatible: ADR-0002's single push-style assignment can't express ADR-0005's two-call pull pattern |
| 3 | `EcosystemSimulation.restore(restored)` | ADR-0004: no `restore()` anywhere in its Key Interfaces | Undeclared |
| 4 | `ObjectPlacement.restore(restored)` | ADR-0003, verbatim: *"No public write API — driven entirely by Input Abstraction's signals (ADR-0002)."* | **Directly contradicted** |
| 5 | `TimeDrift.run_catchup_and_activate()` | ADR-0006: only `get_state() -> SessionState` and `get_day_night_phase() -> float` | Undeclared |
| 6 | `CreatureBehavior.settle_from_ecosystem_state()` | ADR-0007: the real method is `resolve_session_start() -> void` | Misnamed |

5 of 6 calls are broken, identical severity to pass 2. None of the three
new ADRs (0008/0009/0010) touch or amend ADR-0002. `docs/registry/architecture.yaml`'s
`state_ownership` section independently lists the real interfaces for all
five owning systems and matches the Key Interfaces above — not ADR-0002's
pseudocode — confirming the registry itself was never reconciled against
ADR-0002 either.

**Impact**: Any implementation of `SessionBootstrap` as currently
specified will call 5 methods that don't exist. This is a Foundation-layer
integration contract failure, not a cosmetic doc gap.

**Resolution options** (unchanged from pass 2, still not acted on):
1. Amend ADR-0002's pseudocode to call the methods that actually exist
   (`get_restored_blob()`, `resolve_session_start()`, etc.) and add the 3
   genuinely-missing methods (`load_registry()`-equivalent, `restore()`
   on Ecosystem Simulation, a catch-up entry point on Time & Drift) to
   their owning ADRs' own Key Interfaces sections, in one coordinated
   revision pass across all 6 ADRs.
2. Split the difference: leave read-heavy systems (Content Data,
   Ecosystem Simulation, Time & Drift) to expose the missing method in
   their own ADR, but have ADR-0002 itself adopt each system's already-
   settled pattern (pull for Persistence/Save, the renamed
   `resolve_session_start()` for Creature Behavior) rather than
   re-litigating those.

Given this has now survived three passes unresolved, recommend treating
the ADR-0002 revision as a named, owned action item — not another
"flag and move on."

### Minor — Conflict A: SessionBootstrap step-number drift

ADR-0002 refers to "steps 6-7" for Time & Drift's catch-up, ADR-0006 says
"step 6," ADR-0007 says "step 7" for Creature Behavior's
`resolve_session_start()` (ADR-0002 calls it step 8). None of these
numbers are enforced anywhere except in prose. Symptom of the same root
cause as Conflict 1 — fold into the same revision pass. Low severity on
its own.

### Minor — Conflict D: ADR-0009's stale "provisional" language

ADR-0009 (Diorama Rendering) still describes its `get_active_items()`
assumption as "provisional... if that system's own ADR settles on a
different shape, this ADR's entity scripts need a follow-up pass." ADR-0010
(Discovery Surfacing, written after) ratified that exact shape and its own
text says *"ADR-0009 should be revisited once this ADR is Accepted to
replace its provisional assumption with this ADR's ratified signature."*
That revisit never happened. Small text-only fix: drop the "provisional"
qualifier from ADR-0009 now that ADR-0010 confirms it matched.

### No new conflicts found on the direct-call/no-event-bus convention

Checked ADR-0008, ADR-0009, ADR-0010 (the three newest) against ADR-0002's
established convention (direct calls for commands/queries, signals for
notifications, no event bus/mediator — a registered `forbidden_pattern`).
All three explicitly cite and comply; no violations found.

### No dependency cycles

Full 10-ADR dependency graph is a DAG (see ordering below). ADR-0009↔ADR-0010's
mutual reference (Conflict D) is a soft prose cross-reference, not a hard
blocking cycle — same direction, not circular.

### No new state-ownership, performance-budget, or pattern conflicts

Checked all 5 `state_ownership` registry entries against all 10 ADRs — one
owner, one `write_access` value each, no contradictions except the
SessionBootstrap write-access violation already covered under Conflict 1.
No ADR registers a numeric performance budget, so nothing to conflict
there.

---

## ADR Dependency Order (topologically sorted)

**Foundation (no dependencies):**
1. ADR-0001 (Content Data)
2. ADR-0002 (Cross-cutting signal/init-order/snapshot) — *see blocking caveat below*

**Depends on Foundation:**
3. ADR-0003 (Object Placement) — requires 0001, 0002
4. ADR-0005 (Persistence/Save) — requires 0001, 0002
5. ADR-0008 (Input Abstraction) — requires 0002

**Core / Feature layer:**
6. ADR-0004 (Ecosystem Simulation) — requires 0001, 0002, 0003
7. ADR-0006 (Time & Drift) — requires 0004, 0005
8. ADR-0007 (Creature Behavior) — requires 0003, 0004, 0006

**Presentation layer:**
9. ADR-0010 (Discovery Surfacing) — requires 0002, 0003, 0004
10. ADR-0009 (Diorama Rendering) — requires 0001, 0002, 0003, 0008, 0010 (correctly a pure leaf, no downstream dependents)

No cycles detected.

**Blocking caveat**: ADR-0002 sits at position 2 as a formal dependency
root for nearly everything, but cannot be implemented as currently written
(Conflict 1). Its revision needs to happen before or concurrently with
ADR-0003/0004/0005/0006/0007's implementation, even though its own "ADR
Dependencies" field carries no formal blocker.

**Project-wide gate, distinct from any single conflict**: all 10 ADRs are
`Status: Proposed`. Per `docs/CLAUDE.md`'s lifecycle rule — *"Never skip
Accepted — stories referencing a Proposed ADR are auto-blocked"* — **no
story can currently be created against any of the 10 systems.** This
applies uniformly regardless of the conflicts above and should be resolved
(move ADRs to Accepted per this project's own lifecycle policy) before
`/create-epics`/`/create-stories` work begins.

---

## GDD Revision Flags

None. The godot-specialist consultation this pass re-confirmed (as pass
2's specialist did) that Diorama Rendering's Light2D/Compatibility-renderer
assumption is sound and does not contradict verified engine behavior — no
GDD assumption needs revision.

---

## Engine Compatibility Issues

Full audit + godot-specialist second opinion, in agreement on all points:

- **Version consistency**: ✅ all 10 ADRs declare Engine: Godot 4.7.1,
  matching `VERSION.md`'s pinned version. No drift.
- **Deprecated API references**: ✅ none found. Grepped all 10 ADRs
  against every pattern in `deprecated-apis.md` — zero hits. ADR-0008
  correctly uses `DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD` (the 4.7
  device-ID change) instead of literal `0`.
- **Post-cutoff API conflicts between ADRs**: ✅ none. Each post-cutoff
  API claim (typed `Array[String]` in ADR-0001, `FileAccess.store_*` bool
  return in ADR-0005, device-ID constants in ADR-0008, the 4.6 glow
  reorder/4.7 `LinearToSRGB` clamp removal correctly scoped as
  Mobile/Forward+-only-not-Compatibility in ADR-0009) is claimed by
  exactly one ADR, no contradictions. Specialist additionally confirmed a
  consistent "no untyped Dictionary/Array bags" discipline running through
  ADR-0002, ADR-0004, and ADR-0007 — broader than the automated audit
  sampled.
- **Missing Engine Compatibility sections**: ✅ none — all 10 ADRs have a
  complete section.
- **Real, non-blocking gap**: `docs/engine-reference/godot/modules/{input,ui,physics,rendering}.md`
  are all stamped "Last verified: 2026-02-12 | Engine: Godot 4.6" — a full
  version stale, mentioning none of 4.7's changes (device-ID constants,
  `LinearToSRGB` clamp removal, `CanvasItem` line-AA removal, shader
  preprocessor tightening, Jolt `SoftBody3D`/`WorldBoundaryShape3D`
  changes). No ADR was actually misled by this — every ADR citing a stale
  module doc also cited the current `breaking-changes.md`/`deprecated-apis.md`/
  `current-best-practices.md`, which carried the real answer. Still
  recommend refreshing the 4 module docs to 4.7.1, since a future agent
  doing a quick lookup against `modules/input.md` alone (rather than the
  full chain ADR-0008 used) would miss the device-ID change entirely.

### Engine Specialist Findings

- **Light2D under Compatibility renderer** (Diorama Rendering's central
  open question, TR-diorama-rendering-011): confirmed favorably a second
  time. `Light2D` + normal-mapped 2D sprites are core 2D canvas features,
  not Forward+-gated, and have worked under GLES3/Compatibility since
  before the training cutoff. ADR-0009's C1/C4 caution is correctly framed
  as an asset-fidelity/frame-budget question, not a feature-availability
  one. **New nuance not yet in the ADR**: if any of the ≤8 concurrent
  `Light2D` nodes use `shadow_enabled = true`, that's meaningfully more
  expensive under Compatibility (extra draw pass per light per occluder,
  no clustered/tiled optimization) — recommend adding this as an explicit
  Gate C4 re-verification line item.
- **ADR-0008's dual-focus system**: correctly out of scope (the project's
  gesture system uses raw `InputEvent`s via `_unhandled_input()`, not
  `Control.grab_focus()`, and this project has no gamepad/keyboard-focus
  navigation), but only by the shape of the design, not by an explicit
  ruling in the ADR. Recommend a one-line note in ADR-0008's Engine
  Compatibility table stating the 4.6 dual-focus split was checked and
  ruled N/A — currently reads as a gap for an ADR flagged "Domain: Input,
  HIGH knowledge risk."
- **ADR-0003's physics-free claim**: re-confirmed under inspection. Every
  operation (`footprint_hit`, `in_bounds`, `no_overlap`, drag-follow) is
  pure `Vector2` arithmetic; no `Area2D`/`CollisionShape2D`/`PhysicsServer2D`/
  `move_and_slide()` anywhere. No hidden physics dependency.
- **ADR-0007's session-ordering guarantee**: `_ready()` completing before
  the first `_process()` is a correct, well-hedged Godot execution-order
  fact used to structurally prevent CATCHING_UP-batch creature animations
  from leaking into live `_process()`. Confirmed true for Godot's main-loop
  model, unaffected by any 4.4–4.7 change — but the ADR already documents
  (correctly) that this breaks if `await`/`call_deferred()`/`Thread` ever
  enters `SessionBootstrap._ready()`. Praiseworthy, not a defect.
- **Minor**: `ObjectPlacementMath`/`CreatureBehaviorFormulas` both extend
  `RefCounted` despite being static-only utility scripts — harmless
  (Godot requires *some* base class), but never actually instantiated;
  worth an implementer note, not an ADR amendment.

---

## Architecture Document Coverage

`architecture.md` (Last Updated: 2026-08-09) is now **severely stale** —
worse than pass 2 flagged, and actively misleading to anyone consulting it
instead of the traceability index:

1. **Document Status header**: still says *"ADRs Referenced: none yet"* —
   10 exist, all Proposed.
2. **ADR Audit section**: still asserts *"contains no ADRs yet... Nothing
   to audit"* with a per-system table marking all 11 systems + crosscutting
   as ❌ GAP, 0% coverage — directly contradicted by this pass's real
   finding of 66.3% Covered.
3. **Required ADRs section**: only ADR-0005 and ADR-0006 are struck
   through as written — 8 of the 10 that actually exist (0001, 0002, 0003,
   0004, 0007, 0008, 0009, 0010) still show as undecided/needed.
4. **Technical Director Sign-Off block**: names 3 Foundation-layer ADRs
   (Content Data, cross-cutting, Input Abstraction) as conditions that
   "must be written before implementation begins" — all 3 now exist
   (ADR-0001, ADR-0002, ADR-0008) but the block doesn't reflect this.

**No orphaned or missing systems otherwise** — `systems-index.md`'s 11 MVP
systems and `architecture.md`'s System Layer Map are fully consistent, no
system appears in one but not the other.

**Recommendation**: architecture.md needs a full refresh pass before
Pre-Production gate-check — this is not cosmetic. A reader consulting it
alone would currently conclude zero architectural coverage exists, a
55-requirement discrepancy from reality.

---

## Verdict: FAIL

Third consecutive FAIL, same root blocking cause as pass 2. Real,
measurable progress was made this pass (coverage 45%→66.3%, three systems
unblocked), but the verdict does not change because:

### Blocking Issues (must resolve before PASS)

1. **TR-crosscutting-003 / Conflict 1** — ADR-0002's `SessionBootstrap`
   pseudocode calls 5 of 6 methods that don't match any downstream ADR's
   declared Key Interfaces. Unaddressed across 3 passes. Needs a dedicated
   revision pass, not another flag-and-wait.
2. **Tending Input and Ambient Audio have no ADR** — 13 requirements with
   zero architectural coverage; `architecture.md`'s own Required ADRs list
   was never fully closed out.
3. **All 10 ADRs remain Status: Proposed** — per this project's own ADR
   lifecycle rule, this blocks all story creation project-wide,
   independent of the conflicts above.
4. **`architecture.md` is severely stale/self-contradictory** — actively
   misleading (claims 0% ADR coverage against an actual 66.3%).

### Required ADRs (priority order)

1. **ADR-0002 revision pass** (not a new ADR — reconcile SessionBootstrap's
   pseudocode against all 6 downstream ADRs' actual Key Interfaces)
2. **Tending Input** — small, decide fold-into-ADR-0002 vs. stand-alone
   explicitly
3. **Ambient Audio** — bus/volume architecture, autoplay-gesture handling

---

## Pre-Gate Checklist

- `tests/unit/` and `tests/integration/` directories — ✅ exist (scaffolded
  by `/test-setup` in Technical Setup)
- `.github/workflows/tests.yml` — ✅ exists
- `design/accessibility-requirements.md` — ⚠️ exists at
  `design/ux/accessibility-requirements.md` instead (path mismatch flagged
  by the 2026-08-10 `/gate-check pre-production` run — content is correct,
  location doesn't match what the gate expects)
- `design/ux/interaction-patterns.md` — ✅ exists

## Immediate Actions (top 3, highest-impact first)

1. Revise ADR-0002's `SessionBootstrap` pseudocode against ADR-0001/0003/0004/0005/0006/0007's
   actual Key Interfaces (closes the 3-pass-old blocking conflict)
2. Write the Tending Input ADR (small — resolve the fold-in-vs-standalone
   question explicitly first)
3. Write the Ambient Audio ADR

Re-run `/architecture-review` after each new/revised ADR to verify coverage
improves and Conflict 1 finally closes.
