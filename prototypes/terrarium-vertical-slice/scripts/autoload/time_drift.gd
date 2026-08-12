# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# TimeDrift — autoload, Feature layer. Follows control-manifest.md Feature
# Layer Required Patterns (source: ADR-0006) for the parts this slice keeps:
#   - _state: SessionState {INACTIVE, CATCHING_UP, ACTIVE}
#   - run_catchup_and_activate() called exactly once per session, only by
#     SessionBootstrap, spanning the catch-up batch and the
#     CATCHING_UP->ACTIVE transition as one atomic call
#   - ticks_to_apply clamps negative/zero elapsed time to 0, caps at
#     max_catchup_ticks
#
# DELIBERATE SIMPLIFICATION (see README "Persistence simplification"): the
# real design reads Time.get_unix_time_from_system() against a persisted
# last_visit_timestamp (ADR-0006/Persistence — this slice has neither real
# storage nor a real wall clock round-trip). Instead, SessionBootstrap's
# debug "Advance Session" control supplies elapsed_seconds directly as an
# in-memory value, standing in for "real time since last visit." The
# tick-conversion and cosmetic day/night formulas below are the unmodified
# formulas from time-drift.md.
extends Node

enum SessionState { INACTIVE, CATCHING_UP, ACTIVE }

const SECONDS_PER_TICK := 7200      # time-drift.md Formulas, recommended: 7200 (2h)
const MAX_CATCHUP_TICKS := 84       # recommended: 84 (~7 days at this rate)
const CYCLE_DURATION_SECONDS := 1200 # recommended: 1200 (20 real minutes)

var _state: int = SessionState.INACTIVE
var _session_elapsed_seconds: float = 0.0

func get_state() -> int:
	return _state

## Cosmetic only — zero effect on jar_moisture/growth_stage/creature state
## (Core Rule 7).
func get_day_night_phase() -> float:
	return fmod(_session_elapsed_seconds, float(CYCLE_DURATION_SECONDS)) / float(CYCLE_DURATION_SECONDS)

func _process(delta: float) -> void:
	if _state == SessionState.ACTIVE:
		_session_elapsed_seconds += delta

## Called exactly once, only by SessionBootstrap — spans the catch-up batch
## and the CATCHING_UP->ACTIVE transition as one atomic call (Core Rule 5).
## Returns ticks_to_apply for debug/UI purposes.
func run_catchup_and_activate(elapsed_seconds: float) -> int:
	_state = SessionState.CATCHING_UP
	var ticks_to_apply := ticks_from_elapsed(elapsed_seconds)
	EcosystemSimulation.reset_batch_flags()
	for _i in range(ticks_to_apply):
		EcosystemSimulation.advance_tick()
	_session_elapsed_seconds = 0.0
	_state = SessionState.ACTIVE
	return ticks_to_apply

## time-drift.md Formulas — elapsed-time-to-ticks conversion.
static func ticks_from_elapsed(elapsed_seconds: float) -> int:
	var raw := int(floor(maxf(elapsed_seconds, 0.0) / float(SECONDS_PER_TICK)))
	return mini(raw, MAX_CATCHUP_TICKS)
