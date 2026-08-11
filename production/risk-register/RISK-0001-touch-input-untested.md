# Risk: Touch Input Untested on Real Hardware

## Identification

- **ID**: RISK-0001
- **Identified By**: producer (PR-PHASE-GATE, `/gate-check pre-production`)
- **Date Identified**: 2026-08-11
- **Category**: Technical

## Assessment

- **Probability**: Medium-High — not evidence of failure, but a real, currently-unresolvable unknown blocking half the input surface
- **Impact**: Major — touch is a co-primary input per `.claude/docs/technical-preferences.md` ("Mixed Mouse + Touch — supported equally," "No hover-only interactions or hover-dependent tooltips as the sole means of conveying information")
- **Risk Score**: High

## Description

`docs/technical-setup/web-export-verification-plan.md`'s Gate A probes (A1: touch/mouse-emulation dedup, A3, A4) are marked **UNTESTED — no touch/mobile device available**. Input Abstraction's entire single-active-pointer arbitration and tap-vs-drag classification (Core Rules 5/7/7a) is designed against assumed touch behavior, never confirmed on a real finger. The Vertical Slice's whole purpose is validating the core loop, but it cannot validate half its input surface while this gap stands.

## Trigger Conditions

- No physical touch device (or remote-device testing service) becomes available before the Vertical Slice's scope is locked
- Real-device testing reveals gesture disambiguation (the tap-vs-drag distance threshold, same-`device_id` re-press handling) behaves differently on touch than on mouse-simulated testing

## Impact Analysis

### If This Risk Materializes

- **Schedule Impact**: Re-tuning Input Abstraction's thresholds mid-Production, after Object Placement and Tending Input are already built against the untested assumptions — costlier than catching it in Pre-Production
- **Quality Impact**: A real player on mobile/touch could experience misclassified taps-as-drags or vice versa, directly breaking Tending Input (watering) and Object Placement (repositioning) — this project's only two core interactions
- **Scope Impact**: None if caught early; if caught late, could force a scoping decision (desktop-first MVP) after touch support was already assumed and built around
- **Cost Impact**: A borrowed device or a remote-device-testing service session — low cost, the blocker is access, not effort

### Affected Systems/Features

- Input Abstraction (ADR-0008)
- Object Placement (ADR-0003) — consumes Input Abstraction's gestures
- Tending Input (ADR-0011) — consumes Input Abstraction's gestures

## Mitigation Strategy

### Prevention (reduce probability)

- Arrange real touch-device access (borrowed phone, BrowserStack-class remote-device service, or similar) before the Vertical Slice's scope is finalized
- Owner: producer. Deadline: before Vertical Slice scoping locks.

### Contingency (reduce impact if it occurs)

- If no device access materializes in time: make an explicit, documented desktop-first MVP scoping decision, and amend `technical-preferences.md`'s "supported equally" claim to match — a real, honest scope cut is preferable to an unverified claim of parity
- Owner: producer / technical-director, in consultation with creative-director (platform scope is a design-facing decision, not purely technical)

## Current Status

- **Status**: Open
- **Last Reviewed**: 2026-08-11
- **Trend**: Stable — unresolved since the first `/gate-check pre-production` pass this session; not resolvable by more effort or time alone
- **Notes**: Named explicitly by the Producer director across two consecutive gate-check passes as the one risk that keeps this project short of a clean PASS despite otherwise-strong architecture. Seeded into this register per that same review's condition for advancing to Pre-Production.
