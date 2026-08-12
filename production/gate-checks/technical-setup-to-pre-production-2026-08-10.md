# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-08-10
**Checked by**: gate-check skill (review mode: lean — all 4 phase-gate directors run)

## Required Artifacts: 8/13 present

- [x] Engine chosen — Godot 4.7.1 (`CLAUDE.md`)
- [x] Technical preferences configured (`.claude/docs/technical-preferences.md`)
- [ ] **Art bible — MISSING entirely** (`design/art/art-bible.md` doesn't exist, 0/9 sections)
- [~] ≥3 ADRs covering Foundation-layer systems — 4 ADRs exist, but only 2 (Content Data, cross-cutting) are actually Foundation-layer; no save/load ADR exists at all
- [x] Engine reference docs exist (`docs/engine-reference/godot/`)
- [x] Test framework directories exist (`tests/unit/`, `tests/integration/`)
- [x] CI/CD workflow exists (`.github/workflows/tests.yml`)
- [ ] **No example test file** — `tests/unit/` and `tests/integration/` contain only `.gdignore_placeholder`; nothing confirms the framework actually runs
- [x] Master architecture document exists (`docs/architecture/architecture.md`)
- [ ] **`docs/architecture/requirements-traceability.md` — wrong path.** This session wrote `docs/architecture/architecture-traceability-index.md` instead — a cross-skill path inconsistency (architecture-review's own Phase 8 doesn't name this gate's expected filename), not a content gap; the traceability content exists, just not at the path this checklist looks for.
- [x] `/architecture-review` has been run (`docs/architecture/architecture-review-2026-08-10.md`)
- [ ] **`design/accessibility-requirements.md` — wrong path.** This session wrote `design/ux/accessibility-requirements.md` (per `/ux-design`'s own Phase 2g reference and `design/CLAUDE.md`'s documented convention) — same class of cross-skill path inconsistency as above.
- [x] `design/ux/interaction-patterns.md` exists (APPROVED via `/ux-review`)

## Quality Checks: 5/9 passing

- [ ] **Architecture covers rendering, input — FAILS.** State management is covered (Ecosystem Simulation, Object Placement); rendering (Diorama Rendering) and input (Input Abstraction) have zero ADR coverage.
- [x] Technical preferences have naming conventions + performance budgets set
- [x] Accessibility tier defined (Standard) — content is right even though the path is wrong
- [~] At least one screen's UX spec started — no traditional "screen" exists in this zero-UI-chrome game; the pattern library is the closest equivalent and is reviewed/APPROVED
- [x] All ADRs have Engine Compatibility sections stamped
- [x] All ADRs have GDD Requirements Addressed sections
- [x] No deprecated API usage in any ADR
- [~] HIGH RISK engine domains addressed or flagged — flagged (3 gates in `web-export-verification-plan.md`), none actually run yet
- [ ] **Zero Foundation-layer traceability gaps — FAILS.** Input Abstraction (Foundation, 17 TRs) has zero ADR coverage. This is an explicit, named blocking check in this exact gate.

**ADR circular dependency check**: none found — clean topological order (0001, 0002 → 0003 → 0004).
**Engine validation**: no deprecated APIs; all ADRs agree on Godot 4.7.1; ADR-0003/0004 rate `Knowledge Risk: LOW` while internally hedging on unconfirmed typed-Dictionary support — a real self-inconsistency flagged in the architecture review, not yet fixed.

## Director Panel Assessment

**Creative Director: CONCERNS**

Pillar fidelity is strong — pillars are demonstrably doing real work across the GDDs (e.g. Discovery Surfacing struck its own "Arrival is the payoff" climax framing; Ecosystem Simulation's departure timing was refixed against the Anti-Pillar; Content Data's `BAND_MIN_WIDTH=15` exists purely to stop plants dying punitively), not decorating headers. Core fantasy is intact; no GDD or ADR contradicts the concept.

Concerns:
1. No art bible exists for Pillar 4's most visually-dependent pillar — "Diorama Realism" lives only as a 15-line concept section while two GDDs already flag themselves as seeds for a document that doesn't exist.
2. No documented creative fallback if the Compatibility-renderer lighting approach fails verification — Diorama Realism carries the co-primary "Sensation" aesthetic and the differentiator vs. Viridi; if Gate C fails, the game loses half its aesthetic spine with nothing to fall back to.
3. `game-concept.md` is still `Status: Draft` while 11 Approved GDDs cite it as canon.
4. Advisory: Discovery Surfacing's reveal window (34s default, 66s legal ceiling) is a real Anti-Pillar risk ("reads as a wait") — make it a named Vertical Slice playtest criterion.

The architecture FAIL is a technical-gate matter, not creative — none of the above changes what game this is.

**Technical Director: NOT READY**

Two blockers:
1. All three Web-export verification spikes (pointer/focus lifecycle, IndexedDB write durability, `Light2D`/glow under Compatibility) are unrun. On a Web-only target, empirically validating the export path *is* the deliverable of Technical Setup — `architecture.md`'s own Principle 5 ("assume nothing about Web export until verified") is honored in prose and violated in practice. Gate C alone gates 36 Diorama Rendering TRs and every lighting decision.
2. The `restore()` integration-contract conflict is open and all 4 ADRs remain `Proposed` — per `docs/CLAUDE.md`, Proposed ADRs auto-block every story that references them, so carrying this into Pre-Production means the first sprint is blocked on paperwork.

Concerns (not blocking this gate): 7 missing ADRs including Input Abstraction (Foundation) — correctly read as Pre-Production *work*, not a Technical Setup exit criterion; Input Abstraction is itself gated on Gate A. Performance budgets are documented but never allocated or measured — have the Gate C probe print frame time and draw calls. `architecture.md`'s ADR Audit section is stale.

"Path to READY: run the spike, fix `restore()`, accept the 4 ADRs. Days, not weeks."

**Producer: NOT READY**

The Pre-Production sequence (control-manifest → vertical-slice → playtest → epics → stories → sprint-plan) can't start step 1 — `control-manifest.md` requires Accepted ADRs as input and zero of the 4 are Accepted. Input Abstraction's absence is the sharper problem: the vertical slice for a cozy tending sim *is* click-and-drag/tap-and-drag on Web export, and it can't be built without this system, which is itself gated on the unrun Gate A spike — the single highest-leverage item in the project right now.

Explicitly not a blocker: the other 7 ADRs — gating Pre-Production on 11/11 would be waterfall and wrong for a solo team; Ambient Audio, Discovery Surfacing, and Diorama Rendering ADRs should be written *from* what the vertical slice teaches, not before it. Gate only on the slice-critical set: Input Abstraction, Content Data, Object Placement, Tending Input, Ecosystem Simulation.

Carry forward: MVP timeline is explicitly unbaselined ("pending `/estimate`") — run `/estimate` at the epics step and expect to cut.

**Art Director: NOT READY**

`design/art/art-bible.md` does not exist — this gate's own checklist requires it with at least Sections 1–4, and this isn't a paperwork gap: Terrarium's whole visual identity exists nowhere as an authored, canonical reference. `diorama-rendering.md` already locked provisional values (STALLED_TINT, WATERING_SHEEN_TINT, a 4-stop day/night gradient, growth-scale constants, easing curves) and a full "baked lighting + budget-capped Light2D" rendering approach, with the explicit prior plan that Technical Setup would run the Light2D/Compatibility spike and consolidate these into the art bible before Pre-Production — neither happened. `interaction-patterns.md` is now citing those unverified values too, with no palette to reconcile against.

Required before re-gating: (1) run the Light2D/Compatibility-renderer spike, (2) author art bible Sections 1–4 consolidating existing GDD values per spike results, (3) reconcile `interaction-patterns.md` against the resulting canonical palette.

## Blockers

1. **All 3 Web-export verification spikes unrun** (Gate A/B/C, `docs/technical-setup/web-export-verification-plan.md`) — the single highest-leverage action available; gates Input Abstraction, Persistence/Save, and Diorama Rendering all at once.
2. **`restore()` cross-ADR integration conflict unresolved**, and all 4 existing ADRs still `Proposed` — blocks the control-manifest step, which is the actual first action of Pre-Production.
3. **Input Abstraction has zero ADR coverage** — Foundation layer, explicitly named blocking in both the architecture review and this gate's own "zero Foundation gaps" check.
4. **No art bible** — required artifact, missing entirely; `diorama-rendering.md` already made unreconciled visual decisions that need it.
5. **No example test file** confirming the test framework actually runs.
6. **Two cross-skill path mismatches** — `docs/architecture/requirements-traceability.md` and `design/accessibility-requirements.md` are the paths this gate checks; this session's content lives at `architecture-traceability-index.md` and `design/ux/accessibility-requirements.md` instead, per other skills' own conventions. Content exists, paths don't match — worth fixing the skills' cross-references, not necessarily the files.

## Recommendations

- Run the Gate A/B/C verification spikes first — every other blocker either depends on their outcome or is cheap to fix in parallel.
- Write the Input Abstraction ADR once Gate A returns.
- Resolve the `restore()` gap (amend ADR-0003/0004, or defer explicitly to the future Persistence/Save ADR) and move the 4 existing ADRs to `Accepted`.
- Author art bible Sections 1–4, consolidating (not re-deciding) the values already locked in `diorama-rendering.md`, adjusted per the Gate C result.
- Add one real example test file to `tests/unit/` or `tests/integration/`.

## Verdict: FAIL

Chain-of-Verification: 5 questions checked — verdict unchanged (confirmed FAIL). All findings trace to a specific file or director response, not inference. This reads as resolvable in days, not a deeper design problem — all four directors converged on essentially the same short punch list, and Technical/Producer both explicitly scoped what does *not* need to block (7 of 11 ADRs, all 11 systems' epics) rather than gating on everything.
