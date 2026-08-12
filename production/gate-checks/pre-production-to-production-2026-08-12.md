# Gate Check: Pre-Production → Production

**Date**: 2026-08-12
**Checked by**: `/gate-check pre-production` (lean review mode — full 4-director panel run, since phase gates always run in lean mode)
**Prior gate**: Technical Setup → Pre-Production PASSED 2026-08-11 (`production/gate-checks/technical-setup-to-pre-production-2026-08-11-final.md`)

---

## Required Artifacts: 8/16 present, 1 explicit content-failure, 7 missing

| Artifact | Status |
|---|---|
| Vertical slice with REPORT.md | ✅ `prototypes/terrarium-vertical-slice/REPORT.md` — PROCEED verdict |
| First sprint plan (`production/sprints/`) | ❌ Does not exist |
| Art bible complete (9 sections) + AD-ART-BIBLE sign-off | ❌ Sections 5–9 are explicit deferred stubs; no sign-off recorded anywhere in `design/art/art-bible.md` (confirmed by grep) |
| Entity inventory (`design/assets/entity-inventory.md`) | ❌ Missing (recommended, not blocking) |
| All 11 MVP-tier GDDs complete | ✅ All Approved |
| Master architecture document | ✅ `docs/architecture/architecture.md` |
| ≥3 Foundation-layer ADRs | ✅ ADR-0001, 0002, 0008 — all Accepted |
| All Foundation + Core ADRs Accepted | ✅ Verified directly by Technical Director |
| Control manifest | ✅ `docs/architecture/control-manifest.md` |
| Epics (`production/epics/`) | ❌ Does not exist |
| Vertical slice build playable | ✅ Confirmed by user testing (watering, dragging, all 3 "Advance Session" controls) |
| Vertical slice playtested, ≥1 session | ✅ 1 session, PROCEED |
| Playtest report location | ⚠️ Exists but at `prototypes/terrarium-vertical-slice/REPORT.md`, not `production/playtests/` — path mismatch, content substantively present, not blocking |
| UX specs: main menu / core HUD / pause menu | ❌ None exist. Game's "zero UI chrome" design may mean these don't apply — never formally ruled on (flagged across 3 consecutive gate-checks now) |
| HUD design doc (`design/ux/hud.md`) | ❌ Missing (conditional — game likely has no traditional HUD, but undocumented) |
| Key screen UX specs passed `/ux-review` | ❌ Not run — `interaction-patterns.md`'s own header says "pending `/ux-review`" |

## Quality Checks

- **Core loop fun**: Mechanically validated (zero fun-blocker bugs, near-immediate onboarding, full independent completion). Core fantasy explicitly not yet delivered — Creative Director's sharper framing: Sensation (a co-primary aesthetic) was never *tested* by this slice by design, not *failed*.
- **Vertical Slice Validation, 4th required item — "core mechanic feels good to interact with"**: User's direct answer — **"neutral / functional but not satisfying."** Does not trigger the checklist's automatic-FAIL condition (that requires an explicit "no"), but is real, distinct signal: separate from the art/atmosphere gap, the tending mechanic itself needs "juice" (feedback, animation, audio response) it doesn't yet have. Record this as its own tracked item, not folded into the art-fidelity finding.
- **Vertical Slice complete, not just scoped**: ✅
- **All ADRs have Engine Compatibility + ADR Dependencies sections**: ✅
- **`.claude/docs/technical-preferences.md` is stale**: claims "no ADRs yet" and empty Forbidden Patterns/Allowed Libraries while 11 ADRs are Accepted and `control-manifest.md` lists a dozen forbidden patterns. This file is `@`-imported into every session's context via `CLAUDE.md` — flagged by Technical Director as the highest-leverage, lowest-cost fix on this entire report.
- **Manual coherence check (GDDs + architecture + epics)**: Not verifiable — no epics exist.

---

## Director Panel Assessment

```
Creative Director:  CONCERNS
Technical Director: CONCERNS
Producer:           CONCERNS
Art Director:       NOT READY
```

**Creative Director — CONCERNS.** Pillars are faithfully represented across every MVP GDD, and the direction is unusually well-enforced across departments (e.g., the art bible's decay-silhouette rule is Anti-Pillar "NOT punishing" enforced as a shape-authoring constraint, not just design prose). New finding, not previously surfaced: **Pillar 3 ("Care, Not Control") may satisfy its letter while hollowing out its intent** — every GDD correctly chooses indirect mechanics over direct control, but Discovery Surfacing has no mechanism letting a player attribute a change to their own past action versus the world's autonomous drift. Recommends this become a named Production exit criterion, answered before Discovery Surfacing's implementation is locked — not a phase-entry blocker.

Also pushes back on the vertical-slice report's own framing: attributing the missed core fantasy to "placeholder art" is a hypothesis from a non-blind n=1 internal tester, not a finding. Sensation is a co-primary aesthetic that was deliberately excluded from the slice's scope — the correct reading is "not tested," not "failed."

Recommended conditions if advancing: (C1) no Diorama Rendering or Light2D-dependent story until Gate C4 + ADR-0009 Accepted + AD-ART-BIBLE sign-off; (C2) author art bible §9 (Reference Direction) now — not blocked by C4, cheapest insurance against per-asset drift; (C3) name both the fantasy-delivery and care-attribution hypotheses as Production exit criteria with pass/fail defined before testing; (C4) formally record the "no non-diegetic UI" ruling — raised at 3 consecutive gate-checks now, still undocumented.

**Technical Director — CONCERNS.** Architecture is sound; Foundation is implementable immediately. ADR-0009 remaining Proposed is the *correct* signal, not a gap — accepting it would ratify a frame budget with zero real measurements (Gate C4 has never produced an ms/draw-call number on any device). The WebKit/iOS persistence gap is safe to carry into Production without blocking — ADR-0005's design specifically deletes the untestable axis (GDScript executing on a hidden tab) from the critical path by construction, which is what makes an unverified assumption safe here.

Reframes the actual risk: **RISK-0001 (touch input), not the WebKit gap, is the weaker of the two** — it has no architectural hedge, and touch is a co-primary input feeding both of this game's only two interactions (placement, watering). Needs a dated decision early in Production: procure a device, or make an explicit desktop-first scope cut.

Additional concerns: `technical-preferences.md` staleness (above); test coverage minimum left unconfigured (`[TO BE CONFIGURED]`) while CI is a BLOCKING gate, meaning the gate currently can't fail; performance budgets (60fps/16.6ms/≤500 draw calls/≤256MB) are documented but entirely unmeasured — the slice's own report confirms functional-only testing, no profiling.

**Producer — CONCERNS.** Dependency ordering is correct and now *empirically* validated — the slice proved the Foundation → Core → Feature → Presentation layering holds across 8 independently-specified systems with zero architectural rework. But every date field in `production/milestones/vertical-slice.md` is still TBD (independently re-verified by reading the file directly) — and this was explicitly named as this gate's own entry condition by the 2026-08-11 gate-check. Epics/stories being deferred to Production's first days is defensible; leaving every date TBD is not, because it removes the ability to ever detect schedule slippage.

Sharpest recommendation: **pull real Persistence/Save into sprint 1**, ahead of its natural Feature-layer dependency position — the game's central cross-session-attribution hypothesis can't be tested at all until real save/load ships, and calendar time (multi-day playtests) is the one resource that can't be compressed or parallelized. Landing it late means discovering whether the core premise works with the least remaining budget to react.

Also flags: the vertical slice's own negative finding (placeholder art) directly falsifies an earlier scope decision — `game-concept.md` deferred full art fidelity to post-MVP, but the slice just showed the MVP hypothesis can't be validated without *some* real art. No `assets/` directory exists yet, no asset list, no effort sizing, no authoring-pipeline decision (hand-author / buy / commission). This is the single most likely thing to derail production, and it won't surface in sprint 1 — it surfaces in sprint 4 when the code is done and the game still doesn't feel like anything.

**Art Director — NOT READY.** Sections 1–4 of the art bible are genuinely strong and production-ready — authored against already-locked GDD decisions, with honest risk-flagging rather than papered-over gaps. The blocker is specifically Diorama Rendering, this game's central visual-pillar system: no `AD-ART-BIBLE` sign-off exists anywhere in the document (confirmed by grep); Sections 5, 6, and 8 are deferred pending Gate C4, which has produced zero ms/draw-call numbers on any device, mobile included, despite this game's mouse-and-touch-equal input model; Gate C1 (normal-map lighting) only passed provisionally against a placeholder dome, never the real jar asset the ADR itself calls "the highest-value asset in the whole scene"; Gate C2 (glow) surfaced an unresolved design consequence (possible forced fallback from point-light bloom to a painted halo) that still needs a creative-director/art-director ruling.

This isn't hypothetical — it's the one thing the actual playtest already surfaced as missing. Recommends: Diorama Rendering hero-asset production should not begin until Gate C4 produces real numbers on a mid-range mobile device, Gate C1 is re-run against the real jar asset, and Gate C2's glow question is resolved — then ADR-0009 can move to Accepted, Sections 5/6/8 can be authored against real numbers, and a sign-off can be recorded. Non-Diorama-Rendering workstreams (Content Data asset pipeline, general asset scaffolding) are not blocked and can proceed in parallel.

**Escalation applied**: one NOT READY overrides all CONCERNS → overall verdict floor is FAIL.

---

## Chain-of-Verification

Five challenge questions checked against a draft FAIL verdict, per this skill's own Section 5a:

1. **Have I accurately separated hard blockers from strong recommendations?** [TOOL ACTION] Re-read `production/milestones/vertical-slice.md` directly — confirmed every date field really is TBD, exactly as the Producer reported. The one true structural blocker is the Art Director's: Diorama Rendering cannot reach Accepted without real Gate C4 data. Missing epics/stories are real gaps but more legitimately deferrable — the Producer's own analysis argues they're Production's first task, not a phase-entry blocker.
2. **Are there any PASS items I was too lenient about?** Yes — re-flagged `technical-preferences.md`'s staleness as a real (if cheap) concern rather than letting "ADRs are genuinely Accepted" cover for the file that claims otherwise.
3. **Am I missing any additional blockers the user should know about?** Added: no `production/qa/` exists at all, while automated test evidence is a BLOCKING gate per `coding-standards.md` — this will be hit by the very first Production story, not a someday problem.
4. **Can I provide a minimal path to PASS?** Yes, three items: (a) real Gate C4 numbers on a mobile-equivalent device → ADR-0009 Accepted → AD-ART-BIBLE sign-off recorded; (b) `/estimate` against real epics/stories → fill in the milestone's TBD dates; (c) author the missing UX specs, or formally document the "no non-diegetic UI, no traditional menus" ruling the Creative Director has now flagged across 3 consecutive gate-checks.
5. **Is the fail condition resolvable, or does it indicate a deeper design problem?** Resolvable. All four directors and the vertical slice independently confirm the underlying architecture and design are sound — this is a sequencing/measurement/documentation FAIL, not a "the concept doesn't work" FAIL.

`Chain-of-Verification: 5 questions checked — verdict unchanged (FAIL)`

---

## Blockers

1. **Diorama Rendering / ADR-0009 / Gate C4** (Art Director NOT READY) — no real frame-budget measurement exists on any device; the ADR cannot reach Accepted, and the art bible's own Sections 5/6/8 cannot be honestly written, without it. This is the one true phase-entry blocker.
2. **Every milestone date is TBD**, which was the prior gate's own explicit entry condition for this one. Run `/estimate` against real epics/stories.
3. **No `production/epics/` or `production/sprints/` exist** — defensible to formalize as Production's literal first task, per Producer's analysis, but currently zero.
4. **No `production/qa/` / bug tracker** — will be hit by the first Production story, since automated test evidence is a BLOCKING gate per `coding-standards.md`.

## Recommendations (non-blocking, but load-bearing)

- Pull real Persistence/Save implementation into sprint 1, ahead of its natural dependency-order position (Producer) — the core cross-session-attribution hypothesis can't be tested until it ships, and that requires real calendar time to accrue.
- Author an asset list with effort sizing and pick an authoring approach (hand-author / buy / commission) before sprint 1 locks (Producer) — the vertical slice's placeholder-art finding falsifies the earlier "defer full art fidelity" scope decision.
- Author art bible §9 (Reference Direction) now — not blocked by Gate C4 (Creative Director).
- Formally record a "no non-diegetic UI" ruling in `game-concept.md` — raised 3 gate-checks running, still undocumented, one paragraph to close (Creative Director + Producer).
- Fix `technical-preferences.md`'s stale ADR/forbidden-patterns/allowed-libraries sections — cheap, high-leverage, read by every future session (Technical Director).
- Make a dated decision on RISK-0001 (touch input): procure a device or make an explicit desktop-first scope cut (Technical Director) — flagged as the weaker-hedged of the two open hardware risks, ahead of the WebKit gap everyone's been watching.
- Set the test-coverage minimum in `technical-preferences.md` (currently `[TO BE CONFIGURED]`) — CI's BLOCKING gate can't actually fail against an unset threshold.
- Name both the fantasy-delivery and Pillar-3 care-attribution questions as explicit Production exit criteria with pass/fail defined before the next slice re-run tests them (Creative Director).
- Track separately from the art-fidelity gap: the core tending mechanic itself reads as "functional but not yet satisfying" per direct user report — likely a feedback/animation/audio "juice" gap distinct from the missing atmosphere layer.

## Verdict: FAIL

Expected, not alarming. This gate was run mid-sequence — before epics, stories, `/estimate`, and the remaining UX screens, exactly where the project's own stated Pre-Production order places this check — and the Art Director surfaced one genuine, previously-under-weighted blocker (Diorama Rendering) that needed naming regardless of timing. All four directors and the vertical slice itself independently agree the underlying architecture and design are sound; nothing here indicates a deeper design or technical problem.

`production/stage.txt` is unchanged — remains `Pre-Production`.
