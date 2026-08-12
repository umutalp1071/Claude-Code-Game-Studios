# Epic: Input Abstraction

> **Layer**: Foundation
> **GDD**: design/gdd/input-abstraction.md
> **Architecture Module**: InputAbstraction (autoload)
> **Status**: Ready (2 requirements Partial — see below)
> **Stories**: Not yet created — run `/create-stories input-abstraction`

## Overview

Input Abstraction is the unified interaction layer that converts raw mouse and touch
events into four device-agnostic gesture signals (`tap`, `drag_start`, `drag_move`,
`drag_end`) that every gameplay system consumes identically. It has zero upstream
dependencies and is a hard platform requirement (`technical-preferences.md`: mouse and
touch must work equally for every tending interaction). Per ADR-0008, it's a single
autoload using `_unhandled_input()` as its entry point, tags internal pointer identity
as `(source: MOUSE|TOUCH, id: int)` rather than a bare int (closing a real Godot 4.7
device-ID-renumbering collision risk), converts coordinates via the viewport's canvas
transform, and drives pointer interruption via `Window.focus_exited`/`focus_entered`
plus a defensive 8-second watchdog `Timer` for the OS-level touch-cancellation case
Gate A3 has never verified.

**⚠️ Known gap carried into this epic**: this GDD's own header still marks it
separately BLOCKED pending empirical verification of Core Rules 1/8's Web-export
behavior claims (TR-input-abstraction-006) — this is not resolved by ADR-0008, only
architecturally hedged. The most recent gate-check (`production/gate-checks/
pre-production-to-production-2026-08-12.md`) reframed RISK-0001 (touch input) as the
weaker-hedged of this project's two open hardware risks — no architectural mitigation
exists for it the way ADR-0005 hedges the WebKit/persistence risk. Stories touching
interruption/touch-cancel behavior specifically should be scoped and marked
accordingly — see Story Guidance below.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0008: Input Gesture Abstraction & Web Export Touch/Focus Strategy | `_unhandled_input()` entry point, tagged `(source, id)` pointer identity, canvas-transform coordinate conversion, explicit `register_jar()` DI, focus-signal + watchdog interruption | HIGH (post-cutoff) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-input-abstraction-001 | Core Rules 1-3 — raw event capture, 4-gesture translation, tap-vs-drag classification | ADR-0008 ✅ |
| TR-input-abstraction-002 | Core Rule 4 — true jar-local coordinate conversion | ADR-0008 ✅ |
| TR-input-abstraction-003 | Core Rules 5/7 — single-active-pointer arbitration, mouse/touch dedup | ADR-0008 ✅ |
| TR-input-abstraction-004 | Core Rule 7a — same-`device_id` re-press as implicit release-then-press | ⚠️ Partial — architecturally implied, not explicitly called out in the ADR |
| TR-input-abstraction-005 | Core Rule 8 — pointer interruption forces IDLE, cancels active drag | ADR-0008 ✅ |
| TR-input-abstraction-006 | Open Question [BLOCKING] — empirical Web-export focus/touch-dedup verification | ⚠️ Partial — explicitly not resolved by this ADR; the watchdog is a mitigation, not a fix |
| TR-input-abstraction-007 | Signal contract formalization for Object Placement/Tending Input consumers | ADR-0008 ✅ |

## Story Guidance for Partial-Coverage Requirements

- **TR-input-abstraction-004** (Core Rule 7a): low risk — implement per the GDD's own
  explicit resolution (implicit release-then-press, `canceled=true` if DRAGGING). Not
  blocked; the gap is documentation-only (the ADR doesn't restate it), not a design gap.
- **TR-input-abstraction-006** (empirical verification): stories covering AC10/10a/10b/
  10c/10d/10e (the interruption family) and any touch-cancel-specific behavior should be
  implemented against the documented working hypothesis and unit-tested against a
  *simulated* interruption signal (fully achievable today, per the GDD's own gate-ability
  notes) — but must **not** be marked field-verified or closed out via `/story-done`
  until Gate A1/A3/A4 actually run on real touch hardware
  (`docs/technical-setup/web-export-verification-plan.md`). Flag this explicitly in each
  such story's test-evidence notes.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/input-abstraction.md` are verified (ACs 1–19a),
  with the AC10-family interruption criteria explicitly noted as simulated-signal-verified
  only until real hardware confirms them (see Story Guidance above)
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
  (N/A here — Input Abstraction has no visual/UI surface of its own)

## Next Step

Run `/create-stories input-abstraction` to break this epic into implementable stories.
