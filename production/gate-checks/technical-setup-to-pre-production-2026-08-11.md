# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-08-11
**Checked by**: gate-check skill (lean mode — all four Phase Gates run)
**Prior gate check**: `technical-setup-to-pre-production-2026-08-10.md` (verdict not carried forward verbatim — re-run fresh against current state)

---

## Required Artifacts: 11/13 present

- [x] Engine chosen — Godot 4.7.1
- [x] Technical preferences configured (`.claude/docs/technical-preferences.md`)
- [ ] **Art bible** — `design/art/art-bible.md` does not exist (gate requires Sections 1–4, Visual Identity Foundation)
- [x] ≥3 Foundation-layer ADRs — 12 ADRs total (ADR-0001–0012), Foundation covered by ADR-0001 (Content Data) and ADR-0002 (cross-cutting signal/init-order/snapshot)
- [x] Engine reference docs exist — `docs/engine-reference/godot/` (VERSION.md, breaking-changes.md, deprecated-apis.md, current-best-practices.md all current; `modules/*.md` sub-files stale at 4.6, flagged non-blocking across 3 review passes since no ADR relies on them)
- [x] Test framework directories exist — `tests/unit/`, `tests/integration/`
- [x] CI workflow exists — `.github/workflows/tests.yml`, correctly configured (triggers on push/PR to main, runs `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`)
- [ ] **Example test file** — verified via direct directory listing: both `tests/unit/` and `tests/integration/` contain only `.gdignore_placeholder`, zero real test files. CI has never had anything to execute.
- [x] Master architecture document exists — `docs/architecture/architecture.md` (content present, though its own Document Status/ADR Audit sections are stale — see Recommendations)
- [~] Architecture traceability index — `docs/architecture/requirements-traceability.md` (exact filename this gate's checklist names) does not exist, but `docs/architecture/architecture-traceability-index.md` is functionally equivalent, current, and tracks all 96 requirements. Treated as satisfied — the Technical Director's review recommended fixing this gate's own checklist to point at the real file rather than generating a duplicate to keep in sync.
- [x] `/architecture-review` has been run — 5 passes to date, most recent (`architecture-review-2026-08-11-2.md`) completed today, verdict CONCERNS
- [x] Accessibility requirements — `design/ux/accessibility-requirements.md` (Target Tier: Standard)
- [x] Interaction pattern library — `design/ux/interaction-patterns.md`

## Quality Checks

- [x] Architecture decisions cover core systems (rendering: ADR-0009; input: ADR-0008; state management: ADR-0002/0004)
- [x] Naming conventions + performance budgets set in `technical-preferences.md` (60fps/16.6ms, ≤500 draw calls, ≤256MB)
- [x] Accessibility tier defined (Standard — full input coverage, adjustable text size, colorblind treatment, reduced-motion option)
- [ ] **No screen-level UX spec started** — no main-menu or HUD spec exists yet. Lower-risk than usual for this project: the design intent across every GDD is zero non-diegetic UI chrome ("UI Requirements: None" in Discovery Surfacing and Diorama Rendering; only Ambient Audio needs a real control). Creative Director's review notes this has never been formally *ruled* as policy, only arrived at by omission — worth one paragraph of explicit ruling before Production, not blocking Pre-Production entry.
- [x] All 12 ADRs have Engine Compatibility sections with engine version stamped
- [x] All 12 ADRs have GDD Requirements Addressed sections with explicit GDD linkage
- [x] No ADR references a deprecated API (confirmed by `/architecture-review` pass 5 engine audit)
- [x] HIGH RISK engine domains addressed or explicitly flagged as open questions — Input (Gate A, mostly resolved), Persistence (Gate B, resolved on Chromium, WebKit named residual risk), Rendering (Gate C, the weakest — C1 provisional on placeholder art, C4 has zero numeric measurements on any device)
- [x] Architecture traceability matrix has zero Foundation-layer **Gap**-status requirements (some Partial items exist, no Gap)

**ADR Circular Dependency Check**: 12 ADRs, full topological order built from each ADR's own "Depends On" field (see `architecture-review-2026-08-11-2.md`). No cycles detected.

**Engine Validation**:
- [x] ADRs touching post-cutoff APIs correctly flagged Knowledge Risk HIGH/MEDIUM (ADR-0005, ADR-0009 HIGH; ADR-0012 MEDIUM)
- [x] Engine audit shows no deprecated API usage across all 12 ADRs
- [x] All 12 ADRs agree on engine version (Godot 4.7.1)

---

## Director Panel Assessment

Creative Director:  CONCERNS
  Pillars are faithfully and explicitly represented across all 11 MVP GDDs (every GDD carries an `Implements Pillar` header; anti-pillars have demonstrably killed real designs — the light duty-cycle decay bias was fixed structurally, not tuned around). Core fantasy is preserved and was actively defended — a stale "watering nudges growth live" claim was caught and corrected in both the concept doc and the GDD. No design decision across GDDs or architecture compromises the intended player experience. Recommends advancing, with three items attached as Pre-Production *exit* criteria rather than entry blockers: (1) Sensation is a co-primary MDA aesthetic backed only by a 15-line Visual Identity Anchor with no art bible and no MVP fidelity floor — risks per-asset drift into generic "cozy" without one; (2) "no non-diegetic UI" has been decided by omission, not ruling — a Production-time moisture bar would puncture the diegetic frame the whole aesthetic rests on; (3) cross-session care attribution ("act today, see an undifferentiated change bundle tomorrow") is the load-bearing claim of Pillar 3 and is asserted, not validated at session-boundary scale — should be named the Vertical Slice's primary falsifiable hypothesis with a concrete pass/fail criterion.

Technical Director: CONCERNS
  Architecture is sound and the strongest it has been across 5 review passes — 12 ADRs, clean dependency order, no cycles, zero Foundation/Core coverage gaps, and pass 5 independently verified all 5 cross-ADR companion-edit claims against their target files rather than trusting the claiming ADR (first clean batch in this project's history, breaking a pattern that caused a 3-pass blocking conflict earlier). Explicitly frames the state as "Not READY today, but hours not days" — two mechanical items stand between here and READY: one passing test (proves the CI/GUT pipeline is real, not just configured) and ADR promotion. On promotion specifically: recommends promoting 10 of 12 ADRs to Accepted now (all content-complete and verification-unblocked) while holding ADR-0009 (Diorama Rendering) as Proposed until Gate C4 produces real frame-budget numbers — accepting it today would ratify a performance budget nobody has measured, on the one system with genuinely unbounded per-frame cost. `performance_budgets: []` remains empty in the architecture registry, echoing an unactioned 2026-08-10 finding. Non-blocking but flagged: `architecture.md` is now off by 12 ADRs against its own "no ADRs yet" claim (4 consecutive passes), ADR-0008's false "already Accepted" claim about ADR-0003 (recommended twice, unfixed), and Gate D (from ADR-0012) missing from the verification plan tracking doc.

Producer:           CONCERNS
  Game scope is realistic for a solo/small-team MVP (11 systems, 1×L/4×M/6×S effort distribution) — but the *phase itself* has no schedule artifacts: `production/milestones/` and `production/risk-register/` do not exist (confirmed via direct directory check), so `/sprint-plan`, the terminal step of this project's own stated Pre-Production sequence, has no required input yet. One hard dependency-ordering break identified: all 12 ADRs remain Proposed, and per `docs/CLAUDE.md` stories referencing a Proposed ADR are auto-blocked — this does not block entering Pre-Production (the first four steps of the stated sequence don't need Accepted ADRs) but will silently break `/create-stories` three to five weeks in if not addressed; recommends inserting an explicit ADR-acceptance gate after the vertical-slice playtest, before `/create-epics`. The genuinely hardware-gated risk, not resolvable by more effort or time: touch-input (Gate A probes A1/A3/A4) and Safari/iOS persistence (Gate B) are both entirely untested for lack of physical device access, and touch is a co-primary input per this project's own platform standard — the vertical slice cannot validate half its input surface without resolving this. Recommends either arranging device access before the slice or making an explicit desktop-first scoping decision. This is the one finding elevated closest to NOT READY, though still returned as CONCERNS since Pre-Production work can proceed around it for several weeks.

Art Director:       CONCERNS
  The Visual Identity Anchor and most of what Sections 1-4 of a standard art bible would cover already exist and are locked — `game-concept.md`'s "Diorama Realism" anchor (one-line rule, three supporting principles each with a concrete design test, color philosophy), operationalized further in `diorama-rendering.md` and `discovery-surfacing.md`'s Visual/Audio Requirements sections (baked-light convention, day/night gradient stops, STALLED tint value, vignette-as-composition rule, cue treatments). But `design/art/art-bible.md` itself is zero bytes — material correct-but-scattered across four GDDs is not the same artifact as a document visual teams can open and work from, and this is exactly the kind of gap that causes inconsistent early assets and costly rework. Confirms this is the latest responsible moment for Sections 1-4 specifically (compositional/mood decisions, independent of the still-open Light2D verification) but not for the whole bible — Lighting Direction and Material/VFX budget sections correctly should stay deferred until Gate C4 produces real mobile performance numbers, consistent with the prior 2026-08-09 guidance for those *specific* sections. Recommends authoring Sections 1-4 now as primarily a compilation task (few new creative calls), explicitly flagging the lighting-technique section as pending Gate C4 data rather than silently asserting an unconfirmed technique.

**Escalation applied**: all four directors returned CONCERNS, none returned NOT READY — verdict floor is CONCERNS per the parallel gate protocol.

---

## Blockers (from the gate's own required-artifact list)

1. **No art bible** — `design/art/art-bible.md` does not exist. Run `/art-bible` (Sections 1–4 minimum required for this specific gate transition).
2. **No example test** — `tests/unit/`/`tests/integration/` contain only placeholder files; the CI workflow has never executed a real test. One passing GUT test closes this.

## Recommendations (non-blocking, surfaced by 2+ directors independently)

- Promote 10/12 ADRs to `Accepted` now; hold ADR-0009 (Diorama Rendering) until Gate C4 produces real frame-budget numbers on a mobile reference device
- Resolve or explicitly defer touch-input and Safari/iOS persistence device testing before finalizing vertical-slice scope (hardware-access risk, not effort-resolvable)
- Write `production/milestones/` and start a `production/risk-register/` — needed before `/sprint-plan` regardless of phase, currently absent entirely
- Refresh `docs/architecture/architecture.md`'s Document Status and ADR Audit sections (now off by 12 ADRs — 4 consecutive review passes flagging this)
- Text-only fix to ADR-0008 — drop the false "already Accepted" claim about ADR-0003 (recommended twice, still unapplied)
- Add "Gate D" (ADR-0012's recommended browser-audio-unlock verification) to `docs/technical-setup/web-export-verification-plan.md`
- Record an explicit "no non-diegetic UI" ruling before Production (Creative Director finding — currently policy-by-omission, not policy-by-decision)
- Name cross-session care attribution as the Vertical Slice's primary falsifiable hypothesis, with a concrete pass/fail criterion (Creative Director finding)

## Chain-of-Verification

5 challenge questions checked against a CONCERNS draft; 2 answered via direct tool re-check (re-listed `tests/unit/`/`tests/integration/` contents and CI workflow YAML directly; Globbed `production/milestones/` and `production/risk-register/` directly) rather than trusting agent-reported summaries. No FAIL condition was found to have been softened into a CONCERNS. One additional finding surfaced (missing milestone/risk-register artifacts) but it is a Producer-domain recommendation, not a required artifact for this specific gate transition, so it does not change the verdict. **Verdict unchanged: CONCERNS.**

---

## Verdict: **CONCERNS**

Required artifacts: 11/13 present. Quality checks: passing except one (no screen-level UX spec). Director panel: 4/4 CONCERNS, 0/4 NOT READY. All four directors independently converged on the same two mechanical items (art bible Sections 1-4, one passing test) as the actual path to a clean PASS — a strong convergence signal, not noise.

**`production/stage.txt` not updated** — remains `Technical Setup`. Only a PASS verdict advances the stage per this skill's own rules.
