# Vertical Slice Report: Terrarium

> **Date**: 2026-08-12
> **Slice Duration**: 1 day (2 agent build passes + 1 bug-fix cycle, same session)
> **Target Scope**: 3–5 minutes of polished, continuous gameplay
> **Source GDD**: design/gdd/game-concept.md

---

## Validation Question

Does a player, starting from nothing, experience the calm caretaker fantasy —
noticing what changed via the discovery reveal, tending the jar (water +
reposition), and seeing a session boundary produce visible drift — within 5
minutes, without developer guidance? And can we build one such loop at
representative *mechanical* quality (not final art) in the scoped time?

---

## Scope Built

**Systems included (full mechanical implementation, against each system's
GDD formulas and `docs/architecture/control-manifest.md`'s rules):**
- Content Data — 3 plant types + 2 creature types + 1 object, hand-authored `.tres` fixtures
- Input Abstraction — mouse + touch → tap/drag signals, device tagging, focus-loss interruption, watchdog
- Object Placement — drag/drop, in-bounds + overlap validity, footprint hit-test
- Ecosystem Simulation — two-axis moisture/light drift, three-state plant growth, spawn/departure debounce
- Tending Input — tap-to-water router with footprint exclusion
- Time & Drift — tick-batching math, cosmetic day/night phase
- Creature Behavior — SPAWNING/WANDERING/PAUSING/DEPARTING state machine
- Discovery Surfacing — delta computation, 4-category staggered reveal queue

**Art/audio quality level:** Placeholder (2D primitives, no shaders/lighting; silent/unassigned ambient stream)

**Shortcuts taken deliberately (agreed before build, documented in the slice's own README):**
- **Persistence** — the real ADR-0005 `localStorage`/JS-mirror/hide-listener design was not
  re-implemented (already validated separately via `prototypes/web-export-spike/`). Replaced
  with an in-memory `SessionBootstrap.advance_session(elapsed_seconds)` debug trigger that
  runs the identical restore → catch-up → compute-delta sequence a real session boundary
  would, just fed elapsed time directly instead of a real wall-clock/storage round trip.
- **Ambient Audio** — only Core Rule 1's base loop; the watering-swell and discovery-bed-shift
  reactive layers were cut entirely, not stubbed.
- **Diorama Rendering** — plain 2D placeholder shapes (no Accepted ADR exists yet — ADR-0009
  is still Proposed, pending Gate C4 frame-budget data; no art assets exist).

**What was cut from original scope:** Nothing from the core loop itself — every MVP system
has a live representation. Only the three items above were descoped from full fidelity.

---

## Build Velocity Log

| Day | Completed |
|-----|-----------|
| Day 1 (2026-08-12), pass 1 | `prototyper` agent built Content Data, Input Abstraction, Object Placement, Ecosystem Simulation, Tending Input — 21 files. Stopped mid-task (agent turn/token budget), not a real blocker — caught by inspecting its actual file diffs rather than trusting the "completed" status, then resumed from the same transcript. |
| Day 1, pass 2 | Same agent, resumed, finished Time & Drift, Creature Behavior, Discovery Surfacing, a `SessionBootstrap`-equivalent, minimal Ambient Audio, placeholder `jar_view.gd` rendering, the Main scene, and the README — 11 more files, 32 total. |
| Day 1, bug-fix cycle | User opened the project in Godot 4.7.1 for the first time. One real parse error: GDScript couldn't statically infer the type of a `:=`-declared variable whose expression chained an untyped-Dictionary-subscript `Variant` through a property access into a boolean comparison. Fixed with an explicit `: bool` annotation; grepped the rest of the codebase for the same pattern (none found elsewhere). Re-ran — clean. |

**Total elapsed:** 1 day (same session) for 8 fully-implemented interconnected MVP systems.

**Velocity estimate:** Not representative of human production velocity — see "Lessons Learned."
This slice was authored by an AI agent working directly from already-fully-specified GDDs and
the control-manifest's extracted ADR rules, which is a fundamentally different task than a human
implementer building from the same specs. **Do not feed this timeline into `/sprint-plan` or
`/estimate` as a production velocity figure** — a real `/estimate` pass against actual epics/stories
is still the correct source for that, as already carried forward as an open item from the
Pre-Production gate.

---

## Playtest Results

| Attribute | Value |
|-----------|-------|
| Total sessions | 1 |
| Internal testers | 1 (project owner) |
| External testers | 0 |
| Avg session length | Not precisely timed — one full start→challenge→resolution pass, single sitting |
| Time to first meaningful action | Reported as "almost immediate" — felt like playing, not testing UI, once interacting with the jar began |

---

## Observations

**Where the tester succeeded without guidance:**
- Understood the intended action (tend the jar) without external help
- Completed the full start → challenge → resolution cycle independently, no developer shortcuts
- All tested interactions worked as expected: watering, dragging the rock, and all three
  "Advance Session" debug controls (+2h / +1d / +1w)
- Displayed debug state values updated correctly; no runtime, parse, or visual errors observed

**Where the tester was confused or stuck:**
- None reported.

**Emotional reactions observed:**
- The tester explicitly did **not** feel the target core fantasy ("quiet caretaker of a tiny
  living world in a jar") yet — attributed directly to placeholder art, not to the mechanics,
  pacing, or loop structure. Quote: *"I didn't fully feel the 'quiet caretaker' fantasy yet,
  mainly because the current slice uses placeholder art. However, I like the core idea and I
  believe the feeling can come through once the art direction and assets are properly
  implemented."*
- The tester's developer-perspective read was more positive: confidence that the interconnected
  systems work together, with the remaining risk concentrated in art/presentation/polish rather
  than the core technical concept.

---

## Metrics

| Metric | Target | Actual |
|--------|--------|--------|
| Time to first meaningful action | ≤ 5 min | Near-immediate (qualitative — not stopwatched) |
| Session length | 3–5 min | Not precisely timed; one full loop pass, single sitting |
| Critical fun blockers found | 0 | 0 (no confusion, no stuck points) |
| Pipeline blockers found | 0 | 0 (all 8 systems integrated and ran together on first successful launch) |
| Architecture surprises | 0 | 0 — the one bug found was a GDScript static-typing quirk, not an architectural or control-manifest violation |

**Feel assessment:** Mechanically clear and functional — tending, dragging, and the session-boundary
drift all read correctly to a first-time player with zero guidance. The "calm caretaker" emotional
target is **not yet delivered**, but this reads as an expected consequence of the explicit
placeholder-art scope cut, not a defect in the loop, pacing, or system design — no fun-blocking
issue was found in the mechanics themselves, and the tester's own read agrees the gap is
specifically visual/atmospheric.

---

## Recommendation: PROCEED

The full game loop is mechanically sound: all 8 core MVP systems integrate and run together, the
tester completed the complete start → challenge → resolution cycle independently and near-immediately
with zero confusion or blockers, and the one real bug found was a small GDScript typing issue, not
an architectural problem. The core fantasy did not land in this pass, but the tester's own
assessment — corroborated by the fact that Diorama Rendering (this game's central Sensation-pillar
system) was deliberately placeholder-only and has no Accepted ADR yet — attributes this specifically
to the missing art/atmosphere layer, not to the loop or systems underneath it. Per the project's own
KILL-verdict checklist (loop >5 min for an experienced player? No. No emotional high point in *any*
session? Too early to call from one session, and the gap has a named, expected cause. 50%+ of testers
stuck at the same point after 2+ attempts? No testers were stuck at all. Architecture requiring >50%
rebuild? No — zero architecture surprises. Third vertical-slice attempt on this concept? No, first.),
none of the KILL conditions apply, and PROCEED is the sound call.

---

## If Proceeding

**Production requirements** (what must change from slice to production):
- Replace all placeholder 2D shapes with real Diorama Realism art once ADR-0009 is Accepted
  (currently Proposed, blocked on Gate C4 frame-budget data)
- Implement the real ADR-0005 Persistence/Save mechanism (localStorage/JS-mirror/hide-listener),
  replacing this slice's in-memory "Advance Session" debug stand-in
- Implement Ambient Audio's two reactive layers (watering swell, discovery bed-shift) and source
  a real ambient loop asset
- Add the per-category diegetic Discovery Surfacing cue treatments (subsurface glow, specular
  catch-light, etc.) in place of this slice's single generic yellow-ring placeholder

**Architecture adjustments needed:**
- None identified — all 11 Accepted ADRs held up against a real (if placeholder-visual) integration
  test with zero architectural rework required

**Sprint velocity estimate based on slice data:**
- Not usable as a production velocity figure — see Build Velocity Log. Run a real `/estimate` pass
  against actual epics/stories instead, as already carried forward from the Pre-Production gate's
  own entry condition.

**Scope adjustments from original design:**
- None — the slice validated the MVP system boundaries as scoped; no system needed splitting,
  merging, or descoping beyond the three deliberate, already-documented cuts

**Performance targets:** Not measured this pass. This session's testing was functional/interaction
validation only (does it run, do interactions work), not performance profiling — draw calls, memory
ceiling, and 60fps targets from `technical-preferences.md` still need real validation once actual
art/audio assets replace the placeholders.

**Playtest note:** Only 1 session, 1 internal tester, 0 external testers. `/gate-check pre-production`
only requires 1 documented PROCEED session at minimum, so this clears that bar — but 3+ sessions
(ideally including an external, unbiased tester per this skill's own playtesting guidance) would
give meaningfully more reliable signal before committing the full team to Production.

**Next steps:**
1. `/gate-check pre-production` — formally advance to Production
2. `/create-epics layer:foundation` — plan Foundation layer epics
3. `/create-epics layer:core` — plan Core layer epics
4. `/sprint-plan` — once a real `/estimate` pass exists; do not use this report's velocity log for that

---

## Lessons Learned

- **What assumptions were broken by building to near-production quality?** None architecturally —
  the 11 Accepted ADRs and control-manifest.md's extracted rules were detailed enough that a
  first-ever Godot open of 8 fully-implemented interconnected systems produced exactly one bug,
  and it was a GDScript static-typing quirk (inferring a type through an untyped-Dictionary-subscript
  `Variant` → property → boolean-comparison chain inside a `:=` declaration), not a design or
  architecture defect. Worth a coding-standards note: prefer an explicit type annotation over `:=`
  when the right-hand side indexes one of this project's several intentionally-untyped `Dictionary`
  registries (Object Placement, Ecosystem Simulation, etc. — untyped by explicit ADR decision) and
  then chains a property access into a comparison.
- **What surprised us about the pipeline or architecture?** How cleanly the "pure formula script +
  autoload registry of RefCounted state" convention (established by ADR-0003, reused by every
  subsequent Core/Feature-layer ADR) held up across 8 independently-specified systems without any
  cross-system integration friction. Also: a background implementation agent's own "completed" status
  was misleading twice in this project now (first flagged in an earlier Technical Setup session, now
  confirmed again here) — the agent silently stopped mid-build at a turn/token limit and had to be
  resumed from its own transcript once its actual file diffs were checked, rather than the summary
  it initially reported. Verifying actual file output before trusting a "done" claim remains necessary.
- **What would we change about the slice scope if we ran this again?** Nothing about the system
  scope — it was right-sized and validated cleanly. If art/atmosphere assets become available before
  the next slice iteration, even a rough pass (not final Diorama Realism fidelity) at Diorama
  Rendering would let a re-run playtest actually test the core fantasy question this pass could not.

---

> *Vertical slice code location: `prototypes/terrarium-vertical-slice/`*
> *This code is reference material only. Production implementation is written from scratch.*
> *Never import or refactor this code into production.*
