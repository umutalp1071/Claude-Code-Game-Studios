# Risk: WebKit/iOS Safari Persistence Reliability Untested

## Identification

- **ID**: RISK-0002
- **Identified By**: technical-director (ADR-0005 Consequences → Risks), carried forward by producer at PR-PHASE-GATE
- **Date Identified**: 2026-08-10 (ADR-0005 authoring); formally registered 2026-08-11
- **Category**: Technical

## Assessment

- **Probability**: Medium — ADR-0005's design specifically targets the failure mode WebKit is most likely to exhibit (aggressive background-tab throttling), which lowers but does not eliminate the risk
- **Impact**: Critical — a failed save directly breaks Pillar 2 ("the terrarium waits for you exactly as you left it") on the very first affected return visit; Persistence/Save's own Player Fantasy names this exact failure mode as catastrophic, not degraded
- **Risk Score**: High

## Description

`docs/technical-setup/web-export-verification-plan.md`'s Web Export Spike (Gate B) ran **desktop Chrome only**, per an explicit user decision not to pursue mobile/physical-device testing. ADR-0005 chose a JS-side mirror + pure-JS `visibilitychange`/`pagehide` listener specifically because it removes the highest-risk axis (GDScript executing while a tab is hidden) from the critical path entirely — sound engineering under uncertainty — but WebKit/iOS Safari's actual behavior under this design remains completely unverified. ADR-0005 itself names this as an explicit, accepted residual risk, not a closed question.

## Trigger Conditions

- No Mac/iOS Safari device (or WebKit-capable remote testing) becomes available before Persistence/Save implementation stories begin
- Post-implementation testing or player reports show save/state loss specific to iOS Safari or desktop Safari

## Impact Analysis

### If This Risk Materializes

- **Schedule Impact**: Re-architecting the persistence write path after Persistence/Save (and everything that depends on its restore sequencing — Ecosystem Simulation, Object Placement, Time & Drift) is already implemented against the current design
- **Quality Impact**: Total loss of a session's tending on affected browsers — the single most severe failure mode this game can have, per its own Player Fantasy section
- **Scope Impact**: Could force dropping Safari/iOS support entirely for MVP if unfixable, or require a different storage mechanism
- **Cost Impact**: A Mac or iOS device / remote WebKit testing service — low direct cost, blocker is access

### Affected Systems/Features

- Persistence/Save (ADR-0005) — directly
- Every system whose state the save blob carries (Ecosystem Simulation, Object Placement, Time & Drift) — transitively, via the restore sequence

## Mitigation Strategy

### Prevention (reduce probability)

- Arrange Mac/iOS Safari device access (or a WebKit-capable remote testing service) before Persistence/Save implementation stories are scheduled
- Owner: technical-director. Deadline: before Persistence/Save enters implementation.

### Contingency (reduce impact if it occurs)

- ADR-0005's design already hedges structurally — re-run Gate B's B1/B2/B3/B4 checks against the *production* implementation specifically (not the throwaway spike, which is explicitly not migrated per `.claude/rules/prototype-code.md`) the moment WebKit access exists
- If a real WebKit failure is confirmed: this decision would need revisiting, not just re-tuning — flagged in ADR-0005's own Consequences as a "would need revisiting rather than extending" scenario
- Owner: technical-director

## Current Status

- **Status**: Open — Accepted residual risk per ADR-0005 (architecturally hedged, not closed)
- **Last Reviewed**: 2026-08-11
- **Trend**: Stable — named in ADR-0005 at authoring time (2026-08-10), unresolved since; not resolvable by more effort or time alone
- **Notes**: Distinct from RISK-0001 in that this one already has a considered engineering hedge in place (ADR-0005's zero-GDScript-during-hide design); RISK-0001 does not yet have an equivalent architectural mitigation.
