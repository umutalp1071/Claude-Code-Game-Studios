# Architecture Review Report (Fourth Pass)

Date: 2026-08-11
Engine: Godot 4.7.1 (Web export, Compatibility/OpenGL ES3/WebGL2)
GDDs Reviewed: 11 MVP systems (all Approved)
ADRs Reviewed: 10 (ADR-0001 through ADR-0010, all still `Status: Proposed`)

This is the fourth consecutive full-mode `/architecture-review` pass. Passes
1–3 (all dated 2026-08-10) each ended FAIL. This pass verifies whether the
standing blocking conflict from passes 1–3 was actually resolved, rather than
re-flagged a fourth time, and re-runs the full traceability/conflict/engine
audit against current state.

---

## Traceability Summary

Total requirements: 83 (unchanged from pass 3 — no new ADRs were written
between pass 3 and this pass)

- ✅ Covered: 57 (68.7%) — up from 55 (66.3%)
- ⚠️ Partial: 11 (13.3%) — down from 13 (15.7%)
- ❌ Gaps: 15 (18.1%) — unchanged

The coverage gain is entirely attributable to TR-crosscutting-003's
resolution (see Cross-ADR Conflicts below), which also flips its direct
downstream companion, TR-persistence-save-004 (cross-system restore
sequencing/API), and TR-diorama-rendering-009 (first-frame guarantee, which
depended on the same SessionBootstrap ordering gap) from Partial to Covered.

Full per-requirement detail: `docs/architecture/architecture-traceability-index.md`
(updated alongside this report).

## Coverage Gaps (no ADR exists)

❌ **Tending Input** (~6 registered-but-un-ID'd requirement areas per the
registry's anti-renumbering policy; ~16 per `architecture.md`'s own count)
- Suggested ADR: `/architecture-decision tending-input command-routing`
- Domain: Feature/Gameplay
- Engine Risk: LOW — pure GDScript routing layer, no engine API surface,
  fully specified formulas-free GDD
- Note: `architecture.md`'s own Required ADRs list flags this may fold into
  ADR-0002 rather than stand alone — worth deciding explicitly. Neither
  Open Question in `tending-input.md` is architecturally blocking.

❌ **Ambient Audio** (~7 registered-but-un-ID'd requirement areas; ~26 per
`architecture.md`'s own count)
- Suggested ADR: `/architecture-decision ambient-audio bus-volume-architecture`
- Domain: Audio
- Engine Risk: LOW — all pre-cutoff `AudioStreamPlayer`/`AudioServer`/
  `AudioStreamOggVorbis` APIs; the GDD already corrected its one engine
  claim (no WAV-style RAM-vs-Stream import toggle for Ogg Vorbis) via a
  prior `godot-specialist` finding
- Note: has real architectural surface undecided — the `PENDING_GESTURE`
  autoplay-unlock state machine, bus-mute vs. `-80dB` floor split, and the
  reactive-layer boost combination (`min(HEADROOM_CEILING_DB, ...)`) all
  need a concrete Godot implementation shape, not just formulas.

Neither gap is Foundation/Core layer — both are Presentation/Feature leaf
systems with zero downstream dependents (`systems-index.md`), which is why
this does not push the verdict to FAIL.

---

## Cross-ADR Conflicts

### RESOLVED THIS PASS — Conflict 1 (TR-crosscutting-003, SessionBootstrap contract gap)

Flagged in passes 1, 2, and 3 (all 2026-08-10) as the project's single
standing blocking conflict — `ADR-0002`'s `SessionBootstrap._ready()`
pseudocode called 6 methods across `ADR-0001/0003/0004/0005/0006/0007`, 5 of
which didn't match any declared Key Interface.

This pass confirms `ADR-0002` was actually revised (revision note present,
dated 2026-08-10), and independently verified each claim against the target
ADR's own Key Interfaces section rather than trusting ADR-0002's own
resolution table:

| Original call | Resolution | Verified against |
|---|---|---|
| `ContentData.load_registry()` | Removed — no such method; registry population is internal to `ContentData._ready()`, complete by construction before `SessionBootstrap` fires (loads LAST) | ADR-0002 Decision §2 |
| `PersistenceSave.load_blob()` | Replaced with `load()` + `get_restored_blob()` | ADR-0005 Key Interfaces — confirmed present, unchanged |
| `EcosystemSimulation.restore(restored)` | Added as a companion edit | ADR-0004 Key Interfaces — confirmed present: `func restore(restored_blob: Dictionary) -> void` |
| `ObjectPlacement.restore(restored)` | Added as a companion edit; "No public write API" guarantee explicitly re-scoped to mean no *runtime* write API | ADR-0003 Key Interfaces — confirmed present, with the re-scoping language in the same section |
| `TimeDrift.run_catchup_and_activate()` | Added as a companion edit | ADR-0006 Key Interfaces — confirmed present |
| `CreatureBehavior.settle_from_ecosystem_state()` | Renamed to `resolve_session_start()`, ADR-0007's actual pre-existing method | ADR-0007 Key Interfaces — confirmed `resolve_session_start()` was already declared; only the caller name in ADR-0002 needed correcting |

`docs/registry/architecture.yaml` was cross-checked and is consistent with
this resolution: the `object_position_held_grab_offset`,
`jar_moisture_light_growth_creature_state`, and `time_drift_session_state`
`state_ownership` entries all list the new methods in their `interface`
field and carry `revised: "2026-08-10"`.

**This is a real fix, not a re-flag.** Recommend `docs/consistency-failures.md`'s
three prior entries for this conflict be marked resolved (see Architecture
Document Coverage below — the log's Resolution fields are currently stale).

### RESOLVED THIS PASS — Conflict D (ADR-0009 stale "provisional" wording)

Flagged in pass 3 as a minor conflict: ADR-0009 (Diorama Rendering) still
called its `get_active_items()` assumption "provisional" after ADR-0010
(Discovery Surfacing) had already ratified that exact shape and explicitly
said ADR-0009 should be revisited.

Confirmed resolved: ADR-0009's Consequences section now reads "**Resolved
2026-08-10**... ADR-0010 ratified this exact shape... the assumption
matched, no follow-up pass needed" — verified against ADR-0010's actual
`get_active_items() -> Array[DiscoveryItem]` signature, which matches
ADR-0009's usage exactly.

### NEW — Minor, non-blocking

**ADR-0008 incorrectly states ADR-0003 is "already Accepted."** Its Problem
Statement reads: *"`docs/architecture/adr-0003-object-placement-collision-approach.md`
is already Accepted and already consumes this system's signals as an
assumed contract."* Grepping every ADR's `## Status` field confirms all 10
ADRs, including ADR-0003, are `Status: Proposed` — no ADR in this project
has ever reached `Accepted`. This is a text-only inaccuracy (ADR-0003 is
still correctly *consumed* by ADR-0008 as a contract; only the status claim
is wrong) — recommend striking "already Accepted and" from that sentence.
Not blocking, but worth fixing given `docs/CLAUDE.md`'s ADR lifecycle rule
makes `Accepted` status load-bearing for story creation project-wide.

### No other conflicts found

Checked and clear this pass: data ownership (no two ADRs claim the same
state — `docs/registry/architecture.yaml`'s `state_ownership` entries are
each single-owner), integration contracts (no ADR assumes an interface
shape another ADR contradicts), performance budgets (registry
`performance_budgets: []` — nothing registered to conflict against),
dependency cycles (see below — none), architecture pattern conflicts (all
10 ADRs consistently follow the direct-call/signal split and the
no-event-bus rule), state management conflicts (none).

---

## ADR Dependency Order

Built from every ADR's own "Depends On" field. No unresolved dependencies
(every referenced ADR exists), no cycles detected.

```
Foundation (no dependencies):
  1. ADR-0001 — Content Data authoring format
  2. ADR-0002 — Cross-cutting signal/init-order/snapshot architecture

Tier 1 (depends only on Foundation):
  3. ADR-0003 — Object Placement 2D collision approach       (needs 0001, 0002)
  4. ADR-0005 — Persistence/Save Web storage strategy         (needs 0001, 0002)
  5. ADR-0008 — Input gesture abstraction & Web touch/focus    (needs 0002)

Tier 2:
  6. ADR-0004 — Ecosystem Simulation tick architecture         (needs 0001, 0002, 0003)

Tier 3:
  7. ADR-0006 — Time & Drift session lifecycle                 (needs 0004, 0005)
  8. ADR-0010 — Discovery Surfacing reveal-queue architecture   (needs 0002, 0003, 0004)

Tier 4:
  9. ADR-0007 — Creature Behavior wander state machine          (needs 0003, 0004, 0006)
  10. ADR-0009 — Diorama Rendering Light2D/Web strategy          (needs 0001, 0002, 0003, 0008, 0010)
```

Unchanged from pass 3's implied ordering — no new dependency edges were
introduced by this pass's companion edits (they added methods to existing
ADRs' Key Interfaces, not new ADR-to-ADR dependencies).

---

## GDD Revision Flags

None. Diorama Rendering's Light2D/Compatibility-renderer assumption remains
confirmed (not contradicted) by two prior engine-specialist consultations
(pass 2 and pass 3). Nothing new surfaced this pass — no GDD makes an
assumption contradicted by verified engine behavior or an Accepted ADR.

---

## Engine Compatibility Issues

### Engine Audit Results
Engine: Godot 4.7.1
ADRs with Engine Compatibility section: 10 / 10

**Deprecated API References**: None. Checked all 10 ADRs against
`deprecated-apis.md`, including the 4.7-specific
`DEVICE_ID_MOUSE`/`DEVICE_ID_KEYBOARD` entry (ADR-0008 uses these
constants correctly, comparing against them rather than literal `0`).

**Stale Version References**: None. All 10 ADRs consistently cite Godot
4.7.1.

**Post-Cutoff API Conflicts**: None. No two ADRs make contradictory
assumptions about the same post-cutoff API.

**Unchanged non-blocking gap**: `docs/engine-reference/godot/modules/
{animation,audio,input,navigation,networking,physics,rendering,ui}.md` are
all still stamped `Last verified: 2026-02-12 | Engine: Godot 4.6` — one full
version stale against the pinned 4.7.1 (confirmed via `VERSION.md`'s
`Last Docs Verified: 2026-08-02`, which does not match the module files).
No ADR was actually misled by this — every ADR's own References Consulted
field cross-references the current `breaking-changes.md`/`deprecated-apis.md`
instead of the stale module docs — so this stays advisory. Flagged in pass
3 and this pass with no action taken; if a 5th pass finds it still
unaddressed, recommend escalating past advisory.

### Missing Engine Compatibility Sections
None — all 10 ADRs have the section.

---

## Architecture Document Coverage

**Still severely stale — third consecutive pass flagging this, unchanged.**
`architecture.md`'s Document Status header still reads "ADRs Referenced:
none yet — see Required ADRs," and its own ADR Audit section still
literally states *"docs/architecture/ contains no ADRs yet... Nothing to
audit"* with every one of the 12 rows in its coverage table marked ❌ GAP
against a 0%-of-~240 baseline — despite 10 ADRs actually existing, 8 of
which (all but ADR-0005/ADR-0006) aren't reflected anywhere in this
document, including ADR-0002, which this very pass confirmed was
materially revised. This document is now actively misleading if read
instead of `architecture-traceability-index.md`. Recommend a full refresh
pass before the next `/create-epics` or `/create-stories` run, since those
skills may read this document directly.

**Also stale**: `docs/consistency-failures.md`'s two most recent entries
(Conflict 1, logged 3 times, and Conflict D) both still read "Not yet
resolved" / "Still not resolved" as their latest status, even though this
pass confirms both are now resolved. The log itself has no mechanism for
marking a past entry resolved (per the skill's own process, only new
conflicts get appended) — flagging here so a human or a future session
updates those two entries' Resolution fields directly.

**No orphaned architecture** — every system named in `systems-index.md`
appears in `architecture.md`'s System Layer Map and Module Ownership
sections; no architecture-only system without a GDD.

---

## Verdict: **CONCERNS**

*(Upgraded from FAIL — first non-FAIL verdict across 4 passes.)*

No blocking cross-ADR conflicts remain — the one standing blocker from
passes 1–3 is verified resolved, not just claimed. Foundation and Core
layers (Content Data, Input Abstraction, Object Placement, Ecosystem
Simulation) are fully covered and internally consistent. The remaining
coverage gaps are both Feature/Presentation-layer leaf systems, which does
not meet the FAIL bar of "Foundation/Core layer requirements uncovered."

CONCERNS, not PASS, because: 2 systems still have no ADR at all (Tending
Input, Ambient Audio); a handful of Partial items remain in Input
Abstraction and Diorama Rendering (mostly single-line requirements that
were implied but never explicitly cross-referenced in the ADR's own GDD
Requirements table — text-only fixes, not design gaps); and — independent
of anything architectural — every one of the 10 ADRs is still `Status:
Proposed`, which per `docs/CLAUDE.md`'s lifecycle rule blocks all story
creation project-wide regardless of how sound the content is.

### Required ADRs (priority order)
1. **Tending Input command-routing** (or an explicit decision to fold it
   into ADR-0002) — closes the last Feature-layer gap
2. **Ambient Audio bus/volume architecture** — closes the last
   Presentation-layer gap
3. Text-only fix to **ADR-0008** — drop the false "already Accepted" claim
   about ADR-0003
4. Text-only refresh of **`architecture.md`** — sync ADR Audit/Document
   Status against the 10 ADRs that actually exist
5. Text-only update to **`docs/consistency-failures.md`** — mark the
   Conflict 1 (3 entries) and Conflict D entries' Resolution fields as
   resolved, per this pass's findings

**Separately, not itself an architectural gap**: promote ADRs from
`Proposed` to `Accepted` as implementation begins on each — this project's
own lifecycle rule makes this a hard prerequisite for story creation, and
it currently blocks all 10.

---

## Related Files Updated This Pass
- `docs/architecture/architecture-traceability-index.md` — coverage
  summary, per-requirement status for TR-crosscutting-003 /
  TR-persistence-save-004 / TR-diorama-rendering-009, and a new pass-4
  history row
- `docs/architecture/tr-registry.yaml` — header comment updated to confirm
  pass-4 findings (no new TR-IDs minted — no new ADRs were written)
