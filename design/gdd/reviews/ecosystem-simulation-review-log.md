# Review Log: Ecosystem Simulation

> This file tracks formal `/design-review` verdicts. The GDD itself
> (`design/gdd/ecosystem-simulation.md`) additionally embeds detailed
> inline review history for all 15 rounds, including specialist findings
> and the specific text changes each round made — this log is a summary
> index, not a replacement for that detail.

## Review — 2026-08-04 — Verdict: APPROVED
Scope signal: XL
Specialists: game-designer, systems-designer, qa-lead, creative-director
Blocking items: 0 | Recommended: 4
Summary: Round 15 closed the sole blocking item carried from the prior pass — the per-plant STALLED visual cue was a declared hard blocking dependency with no enforcement (Visual/Audio Requirements said "N/A", no Acceptance Criterion covered it). Fixed via a rewritten Visual/Audio Requirements section and new AC26 (ADVISORY-gate, screenshot-evidence). All three specialists independently verified the fix holds and introduces no new formula or consistency defects; creative-director's synthesis confirmed the residual `/story-done` per-AC gating gap is a project-tooling limitation, not a defect in this document, and does not block approval.
Prior verdict resolved: Yes — NEEDS REVISION (2026-08-04, round 14) → APPROVED (2026-08-04, round 15)

## Review — 2026-08-05 — Verdict: FAIL → resolved same session → APPROVED
Scope signal: XL
Specialists: (via `/review-all-gdds`) game-designer, systems-designer — holistic cross-GDD pass, not a dedicated single-doc specialist round
Blocking items: 2 | Recommended: 0
Summary: `/review-all-gdds` found two blockers here. (1) Overview's "watering visibly raises moisture and nudges growth" was stale against Core Rule 5's own round-14 fix decoupling watering from ticks — growth only ever changes on a tick, and ticks never fire live during an ACTIVE session, so watering's live payoff is moisture-only; corrected. (2) `N_departure_ticks=5` guaranteed both MVP creatures depart on nearly any multi-day absence (moisture exits its band in ~7–12 ticks, departure debounce resolves shortly after) — a repeatable, unavoidable outcome that tripped the Anti-Pillar (NOT punishing) despite Core Rule 7's "moving on" framing. Fixed structurally: safe range widened 4–8 → 10–30, exact value deferred to a new required tuning pass (Open Questions) rather than guessed; ACs 12/16/22 rewritten symbolically pending that pass. No formal single-document specialist re-review round; user decision.
Prior verdict resolved: Yes — APPROVED (2026-08-04, round 15) → FAIL (2026-08-05, `/review-all-gdds`) → APPROVED (2026-08-05, round 16, same-session fix)
