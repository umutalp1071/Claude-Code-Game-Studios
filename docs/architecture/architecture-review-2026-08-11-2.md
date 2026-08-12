# Architecture Review Report (Fifth Pass)

Date: 2026-08-11
Engine: Godot 4.7.1 (Web export, Compatibility/OpenGL ES3/WebGL2)
GDDs Reviewed: 11 MVP systems (all Approved)
ADRs Reviewed: 12 (ADR-0001 through ADR-0012, all still `Status: Proposed`)

This is the fifth `/architecture-review` pass, and the first run against
ADR-0011 (Tending Input) and ADR-0012 (Ambient Audio) — both written since
pass 4 (also dated 2026-08-11, same day), closing the two Feature/
Presentation-layer gaps that pass 4 flagged as the last un-ADR'd systems.
All 11 MVP systems now have architectural coverage for the first time.

---

## Traceability Summary

Total requirements: **96** (up from 83 — 13 new: 6 for Tending Input, 7 for
Ambient Audio, newly ID-registered this pass since their ADRs now exist)

- ✅ Covered: **68** (70.8%) — up from 57 (68.7%)
- ⚠️ Partial: **13** (13.5%) — up from 11 (13.3%)
- ❌ Gaps: **15** (15.6%) — unchanged in count, down as a share (18.1%→15.6%)

Full per-requirement detail: `docs/architecture/architecture-traceability-index.md`
(updated alongside this report).

### New TR-IDs this pass

**Tending Input — ADR-0011 (6/6 Covered)**

| ID | Requirement | Status |
|---|---|---|
| TR-tending-input-001 | Core Rule 1 — tap in jar bounds, not on object footprint, triggers watering | ✅ Covered — `_on_tap()`'s two guard checks |
| TR-tending-input-002 | Core Rules 2/3 — exactly-once call, no batching, no `call_deferred`/`await`/`CONNECT_DEFERRED` anywhere in chain | ✅ Covered — direct signal connection, single call site |
| TR-tending-input-003 | Core Rule 4 — stateless, no cooldown | ✅ Covered — zero persisted fields |
| TR-tending-input-004 | AC1 — `watering_amount` read from configured value, never hardcoded | ✅ Covered — new `EcosystemSimulation.get_watering_amount()` companion getter |
| TR-tending-input-005 | Edge Cases — no-objects-placed degrades gracefully; boundary-inclusive footprint exclusion, no error | ✅ Covered — `is_within_any_footprint()` handles both via existing `footprint_hit` semantics |
| TR-tending-input-006 | Structural init-order guarantee (input not enabled before Ecosystem Simulation ready) | ✅ Covered — named explicitly as an autoload-declaration-order requirement (Risks/Mitigation), same documentation-only pattern as ADR-0008's `register_jar()` precedent |

**Ambient Audio — ADR-0012 (5/7 Covered, 2 Partial)**

| ID | Requirement | Status |
|---|---|---|
| TR-ambient-audio-001 | Core Rule 1/1a — zero-delay session-start `play()`, `PENDING_GESTURE` browser-autoplay handling | ✅ Covered — `_process()` edge-detect + dedicated self-disabling `_input()` hook, engine-source-verified |
| TR-ambient-audio-002 | Core Rules 3/4 — reactive layer triggers (watering notification, discovery-cue polling) | ✅ Covered — new `EcosystemSimulation.watering_applied` signal + `DiscoverySurfacing.get_active_items()` poll |
| TR-ambient-audio-003 | Core Rule 7 — persisted `ambient_volume`/`muted`, read/write path | ✅ Covered — first-`_process()` poll of `get_restored_blob()`; new `PersistenceSave.refresh_mirror()` write path |
| TR-ambient-audio-004 | Formulas — dB math/fade envelope/reactive boosts as pure functions, `t` as explicit parameter | ✅ Covered — `AmbientAudioMath`, manual per-frame accumulation (not `Tween`), matches GDD's own testability ACs directly |
| TR-ambient-audio-005 | Core Rule 6 — never blocks/gates gameplay input | ✅ Covered — no blocking call or error path gated on audio state |
| TR-ambient-audio-006 | UI Requirements — locked mute/volume control box (fixed corner, ≤4% viewport, persistent visibility, ≥44×44px, diegetic-adjacent styling) | ⚠️ Partial — ADR-0012 wires `set_volume()`/`toggle_mute()` and confirms the Control-claims-input-first ordering, but explicitly defers the control's actual construction to a future `/ux-design` pass; the box's own locked constraints have no architectural decision yet |
| TR-ambient-audio-007 | Recommended Gate D — pre-gesture `play()` catch-up behavior, empirically unverified | ⚠️ Partial — ADR-0012 recommends the gate and ships a defensive re-trigger as a hedge, but `docs/technical-setup/web-export-verification-plan.md` (which tracks Gates A/B/C) has not been updated to include it |

### Coverage Gaps — unchanged from pass 4 (15, all pre-existing)

No new gaps this pass. The 15 gaps carried forward are the same Input
Abstraction/Diorama Rendering/Discovery Surfacing partial items and the
`TR-discovery-surfacing-010` tuning-knobs gap already tracked in the
traceability index — see that file for the full list; not re-derived here
since ADR-0011/0012 don't touch those systems.

---

## Cross-ADR Conflicts

### Verified clean this pass: all 5 companion-edit claims actually landed

This project's standing failure pattern across passes 1–4 was a
cross-cutting ADR *claiming* a companion edit to another ADR that the
target document never actually received (the `SessionBootstrap`
restore-write-path saga, TR-crosscutting-003, open for 3 consecutive
passes). ADR-0011 and ADR-0012 make five such claims. Each was checked
directly against the target ADR's own file content, not taken on the
claiming ADR's word:

| Claimed companion edit | Target ADR | Verified present in target's own Key Interfaces / Decision / GDD Requirements table? |
|---|---|---|
| `ObjectPlacement.is_within_any_footprint()` + `ObjectState.footprint_size` | ADR-0003 | ✅ Yes — full Decision subsection, Key Interfaces entry, Architecture Diagram, GDD Requirements row, Related Decisions cross-reference |
| `EcosystemSimulation.get_watering_amount()` + `WATERING_AMOUNT` const | ADR-0004 | ✅ Yes — Decision subsection, Key Interfaces entry, GDD Requirements row |
| `EcosystemSimulation.watering_applied` signal | ADR-0004 | ✅ Yes — Decision subsection, Key Interfaces entry, GDD Requirements row |
| `PersistenceSave.refresh_mirror()` public wrapper | ADR-0005 | ✅ Yes — Key Interfaces entry (both the public signature and the internal `_mirror_to_js()` call-site list) |
| Cross-reference note (watering trigger) | ADR-0009 | ✅ Yes — Related Decisions entry naming the new signal |
| `persistence-save.md` blob field list (GDD text, not an ADR) | persistence-save.md Core Rule 1 | ✅ Yes — `ambient_volume`/`muted` now listed in the field enumeration, dated 2026-08-11, explicitly citing the ADR-0012 finding |

**No conflicts found.** All five claims are real, not just narrated. This
is the first pass in this project's history where a batch of companion
edits was fully self-consistent on first check — worth naming as a
positive pattern-break, not just an absence of findings.

### Registry cross-check

`docs/registry/architecture.yaml` (already at v3, dated 2026-08-11) is
consistent with all of the above: `object_position_held_grab_offset` and
`jar_moisture_light_growth_creature_state` both carry `revised: 2026-08-11`
entries matching the new methods; two new entries exist
(`ambient_volume_muted_setting` state ownership, `watering_notification`
and `save_mirror_refresh_trigger` interface contracts) with correct
single-owner `write_access` and `referenced_by` lists. No two ADRs claim
ownership of the same state; no interface contract is described two
different ways by two different ADRs.

### No other conflicts found

Checked and clear this pass: data ownership (single owner per state,
confirmed above), integration contracts (no ADR assumes an interface shape
another ADR contradicts), performance budgets (registry still empty,
nothing to conflict against), architecture pattern conflicts (both new
ADRs correctly use direct calls for commands / signals for notifications
per the registered `inter_system_communication_pattern`, and neither
introduces an event bus — `forbidden_patterns` registry unchanged), state
management conflicts (none).

### Still open, unchanged from pass 4 (not re-flagged, just carried forward)

**ADR-0008 still incorrectly states ADR-0003 is "already Accepted."**
Re-checked directly against the file (`adr-0008-input-gesture-abstraction-web-touch-focus.md`
line 44): *"`adr-0003-object-placement-collision-approach.md` is already
Accepted and already consumes this system's signals as an assumed
contract."* All 12 ADRs, including ADR-0003, remain `Status: Proposed` —
confirmed via direct grep of every `## Status` field. Flagged as a
text-only fix in pass 4's report; still unfixed one pass later. Not
blocking, but this is now the second consecutive pass this exact one-line
fix has been recommended and not applied.

### New minor finding this pass

**Gate D was recommended by ADR-0012 but never added to the tracking
document.** `docs/technical-setup/web-export-verification-plan.md` tracks
Gates A (Input Abstraction), B (Persistence/Save), and C (Diorama
Rendering) by name throughout. ADR-0012 explicitly proposes "Gate D... a
real Web build, real-browser check of the pre-gesture `play()` →
first-input → audible-output path, mirroring this project's existing Gate
A/B/C structure" — but grepping the verification plan file for "Gate D"
finds no matches; the document still only enumerates A/B/C. Not blocking
(ADR-0012's own defensive re-trigger already hedges the unverified case,
and the gate is explicitly non-blocking-to-implementation per that ADR's
own Validation Criteria), but the plan document is now out of sync with
an ADR that references it by name.

---

## ADR Dependency Order

Extends pass 4's topological sort with ADR-0011 and ADR-0012, using the
same "Depends On" fields. No unresolved dependencies, no cycles.

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
  9. ADR-0011 — Tending Input watering router                  (needs 0003, 0004, 0008)  [NEW]

Tier 4:
  10. ADR-0007 — Creature Behavior wander state machine          (needs 0003, 0004, 0006)
  11. ADR-0009 — Diorama Rendering Light2D/Web strategy          (needs 0001, 0002, 0003, 0008, 0010)
  12. ADR-0012 — Ambient Audio Godot implementation strategy     (needs 0002, 0004, 0005, 0006, 0010)  [NEW]
```

Every ADR in the project is now placed. No ADR has an unresolved forward
reference to a "future ADR" that doesn't exist yet — a first for this
project.

---

## GDD Revision Flags

None. No GDD assumption is contradicted by ADR-0011/0012's verified engine
behavior. Note: ADR-0012's engine-specialist source-verification (Godot's
Web runtime auto-resumes `AudioContext` on any input, with no queryable
unlock signal) *confirms* `ambient-audio.md`'s own Core Rule 1a design
rather than contradicting it — the GDD already anticipated exactly this
constraint (browser autoplay policy, fade-in on first input) before the
ADR verified the underlying mechanism. No revision needed.

---

## Engine Compatibility Issues

### Engine Audit Results
Engine: Godot 4.7.1
ADRs with Engine Compatibility section: 12 / 12

**Deprecated API References**: None in ADR-0011/0012. ADR-0012 correctly
notes the 4.7 `AudioEffectSpectrumAnalyzer.tap_back_pos` removal and
`AudioStreamPlayer.area_mask` default change don't apply (neither feature
used). Combined with the unchanged pass-4 finding (ADR-0001–0010 clean),
all 12 ADRs are clear.

**Stale Version References**: None. All 12 ADRs consistently cite Godot
4.7.1.

**Post-Cutoff API Conflicts**: None new. ADR-0012 uses no post-cutoff
audio API directly.

**Genuinely undocumented behavior, verified against engine source (not a
version-risk flag, a notable methodology point)**: ADR-0012's
`AudioContext` gesture-unlock behavior has no official Godot documentation
at all — the engine specialist consultation verified it directly against
Godot engine source (`platform/web/display_server_web.cpp`,
`audio_driver_web.cpp`, `library_godot_audio.js`) rather than the usual
docs/breaking-changes/deprecated-apis triage. This is a different and
higher-effort verification tier than every prior ADR in this project used,
appropriately reserved for a genuinely undocumented Web-runtime behavior.

**Unchanged non-blocking gap (4th consecutive pass)**: engine-reference
module docs (`modules/{animation,audio,input,navigation,networking,
physics,rendering,ui}.md`) remain stamped Godot 4.6 (2026-02-12), one full
version stale against the pinned 4.7.1. ADR-0012 explicitly flags this
itself in its own Engine Compatibility table ("flagged stale... not
misleading here, since nothing in this ADR relies on it beyond the
already-cross-referenced `breaking-changes.md`") — the individual ADR
authors continue to correctly route around the staleness rather than being
misled by it, so this stays advisory. Flagged in passes 3, 4, and now 5
with no action taken.

### Missing Engine Compatibility Sections
None — all 12 ADRs have the section.

### Engine Specialist Findings

ADR-0012's own engine-specialist consultation (source-level verification of
Web `AudioContext` unlock behavior) is already embedded in the ADR itself
and independently reviewed above — no separate specialist re-consultation
was run for this pass, since the two new ADRs' engine claims (audio API
stability, `AudioContext` unlock, no deprecated API usage) were fully
verifiable against `deprecated-apis.md`/`breaking-changes.md` plus the
ADR's own already-completed source-level verification. No new findings
beyond what's captured above.

---

## Architecture Document Coverage

**Still severely stale — now a 4th consecutive pass flagging this, and
worse than ever.** `architecture.md`'s Document Status header still reads
"ADRs Referenced: none yet," and its ADR Audit section still literally
states *"docs/architecture/ contains no ADRs yet... Nothing to audit"*
with a 0%-of-~240 baseline — against **12** ADRs that actually exist now
(up from 10 at last flag), 10 of which aren't reflected anywhere in this
document at all. This document is actively misleading if read instead of
`architecture-traceability-index.md`, and the gap between claimed and
actual state has only grown each pass. Recommend a full refresh pass
before the next `/create-epics` or `/create-stories` run.

**Also still stale**: `docs/consistency-failures.md`'s Conflict 1 (3
entries) and Conflict D still read "Not yet resolved" / "Still not
resolved," even though pass 4 confirmed both resolved and this pass found
no reason to revisit that finding. The log has no mechanism for
self-updating past entries — still needs a direct edit.

**No orphaned architecture, still true**: every system in
`systems-index.md` appears in `architecture.md`'s System Layer Map and
Module Ownership sections (including Ambient Audio and Tending Input,
which were already named there even before their ADRs existed).

---

## Verdict: **CONCERNS**

*(Unchanged tier from pass 4, but meaningfully advanced: coverage up,
zero remaining un-ADR'd systems, zero new conflicts, and — for the first
time — a full batch of companion-edit claims verified fully consistent on
first check.)*

No blocking cross-ADR conflicts exist, checked directly against every
claimed companion edit rather than trusted from the claiming ADR's own
text. Foundation and Core layers remain fully covered. **All 11 MVP
systems now have architectural coverage — the last two gaps (Tending
Input, Ambient Audio) are closed this pass.** Tending Input is fully
covered (6/6). Ambient Audio is mostly covered (5/7), with its two Partial
items both legitimately deferred (UI visual construction to `/ux-design`,
Gate D empirical verification to a future browser-testing pass) rather
than architecturally unresolved.

CONCERNS, not PASS, because: every one of the 12 ADRs is still `Status:
Proposed`, which per `docs/CLAUDE.md`'s ADR lifecycle rule blocks all
story creation project-wide, independent of how sound the content is —
this has now blocked story creation for 2 consecutive days across 5
review passes with no ADR ever promoted; `architecture.md` is now more
stale relative to reality than at any prior pass (12 real ADRs vs. a
document still claiming zero); `docs/consistency-failures.md` still
carries 4 stale "not resolved" entries for conflicts confirmed resolved a
pass ago; and one small text-only fix (ADR-0008's false "Accepted" claim)
has now been recommended twice without being applied.

### Required Actions (priority order)

1. **Promote ADRs from `Proposed` to `Accepted`** as implementation begins
   on each — this is the single highest-leverage unblock remaining; it
   affects all 12 ADRs equally and is a prerequisite for any story
   creation, independent of every other finding in this report.
2. **Full refresh pass on `architecture.md`** — sync Document Status, ADR
   Audit table, and coverage percentage against the 12 ADRs that actually
   exist. This has been recommended 3 times; the gap it's misrepresenting
   has only grown.
3. **Text-only fix to `docs/consistency-failures.md`** — mark Conflict 1
   (3 entries) and Conflict D's Resolution fields as resolved, per pass
   4's findings (unchanged this pass).
4. **Text-only fix to ADR-0008** — drop "already Accepted and" (ADR-0003
   is `Proposed`, same as every other ADR in the project).
5. **Add Gate D to `web-export-verification-plan.md`** — ADR-0012
   references it by name; the tracking document should know about it too.
6. **Future `/ux-design` pass for Ambient Audio's mute/volume control** —
   the box is locked (GDD UI Requirements), the wiring exists (ADR-0012),
   but no scene/Control structure has been designed yet.

---

## Related Files Updated This Pass
- `docs/architecture/tr-registry.yaml` — 13 new TR-IDs appended
  (TR-tending-input-001..006, TR-ambient-audio-001..007), version bumped
  to 4
- `docs/architecture/architecture-traceability-index.md` — full matrix
  update, new Tending Input/Ambient Audio sections, history row added
