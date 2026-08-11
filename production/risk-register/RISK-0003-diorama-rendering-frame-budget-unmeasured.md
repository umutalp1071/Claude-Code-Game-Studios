# Risk: Diorama Rendering Frame Budget Unmeasured (Gate C4)

## Identification

- **ID**: RISK-0003
- **Identified By**: technical-director (ADR-0009 Risks section), carried forward by producer at PR-PHASE-GATE
- **Date Identified**: 2026-08-10 (ADR-0009 authoring); formally registered 2026-08-11
- **Category**: Technical

## Assessment

- **Probability**: Medium
- **Impact**: Major — per the GDD's own C1 FAIL criterion, a failure here is "a design escalation, not a fix"
- **Risk Score**: High

## Description

`docs/technical-setup/web-export-verification-plan.md`'s Gate C1 (Light2D/normal-map lighting response under the Compatibility/WebGL2 renderer) passed only provisionally, on placeholder art. Gate C4 — the actual frame-cost question, under the worst-case 8-concurrent-`Light2D` scenario (1–3 ambient + up to 5 Discovery-cue-driven) — has **zero measurements on any device, including the mobile hardware the verification plan itself names as the likeliest failure point**. ADR-0009 (Diorama Rendering) is deliberately held at `Status: Proposed` rather than promoted alongside the other 11 ADRs specifically because of this — accepting it now would ratify a performance budget nobody has measured, on the one system with genuinely unbounded per-frame cost.

## Trigger Conditions

- Gate C4 measurement, once actually run, exceeds the 16.6ms frame budget or ≤500 draw call ceiling (`technical-preferences.md`) on a mid-range mobile reference device
- Gate C1 re-verification against the real jar normal-map asset (not the current placeholder dome) shows the lighting response doesn't hold at production fidelity

## Impact Analysis

### If This Risk Materializes

- **Schedule Impact**: Diorama Rendering's implementation would need to restart from a different technique (baked/painted specular instead of Light2D accents) — costly if discovered after implementation has already begun against ADR-0009's current design
- **Quality Impact**: The Diorama Realism visual identity (this project's co-primary "Sensation" pillar) could lose its lighting-driven mood system, requiring a real design escalation per the GDD's own explicit framing
- **Scope Impact**: Discovery Surfacing's own cue-concurrency cap (currently ≤5 concurrent) is the most likely tuning knob to need reduction if C4 fails on the ambient+cue combination
- **Cost Impact**: A profiling pass with the real jar asset on a mobile reference device — bounded, mostly a scheduling/access cost, not new design work

### Affected Systems/Features

- Diorama Rendering (ADR-0009) — directly
- Discovery Surfacing (ADR-0010) — its cue-concurrency tuning knob is the primary lever if C4 fails

## Mitigation Strategy

### Prevention (reduce probability)

- Schedule Gate C4 measurement (real jar asset, 8 concurrent lights, a genuine mid-range mobile reference device — not desktop Chrome) as an early Pre-Production task, before Diorama Rendering implementation begins. Named by the Technical Director this session as "the only number in this project that could still force a design change" and the first technical task worth scheduling in Pre-Production.
- Owner: technical-director. Deadline: before Diorama Rendering implementation starts.

### Contingency (reduce impact if it occurs)

- Reduce the concurrent-`Light2D` cap (ambient count and/or Discovery's cue-driven count) — a design decision for creative-director/art-director/game-designer per the verification plan's own governance, not an architecture rework
- Fall back to baked-only lighting (no per-element `Light2D` accents) for the cue categories most affected — the Diorama Realism direction itself doesn't change, per `design/art/art-bible.md`'s own Platform Reality Check, only the technique achieving it
- Owner: technical-director for the technical fallback; creative-director/art-director for any resulting cue-treatment redesign

## Current Status

- **Status**: Open — actively hedged by holding ADR-0009 at Proposed rather than falsely Accepting it
- **Last Reviewed**: 2026-08-11
- **Trend**: Stable — no new measurement has been taken since ADR-0009 was authored (2026-08-10)
- **Notes**: This is the one ADR-level exception in an otherwise fully-Accepted architecture (see `docs/architecture/architecture.md` Document Status) — its Proposed status is itself the correct, honest signal of this risk, not an oversight to fix.
