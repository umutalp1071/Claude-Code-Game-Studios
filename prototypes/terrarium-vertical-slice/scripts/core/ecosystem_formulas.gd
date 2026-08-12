# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# EcosystemFormulas — separate non-autoload script, static funcs taking all
# inputs as parameters — no reads of internal state, no engine RNG calls —
# source: ADR-0004. All values/formulas below are transcribed from
# ecosystem-simulation.md Formulas (moisture/light/growth are two
# independent write paths, per round-14's watering/decay decoupling fix).
extends RefCounted
class_name EcosystemFormulas

const LIGHT_STEP_PER_TICK := 5
const DETAIL_HOLD_THRESHOLD_TICKS := 6
const DETAIL_PROBABILITY := 0.05
## Snail: moss.growth_stage + fern.growth_stage >= 6 (ecosystem-simulation.md
## Formulas, Creature Spawn Conditions table).
const SNAIL_SPAWN_MOSS_FERN_THRESHOLD := 6

## Live, immediate — Core Rule 5. Independent of tick_moisture_decay().
static func apply_watering(jar_moisture: int, watering_amount: int) -> int:
	return clampi(jar_moisture + watering_amount, 0, 100)

## Tick-driven only, fires inside advance_tick() — Core Rule 5.
static func tick_moisture_decay(jar_moisture: int, moisture_decay_rate: int) -> int:
	return clampi(jar_moisture - moisture_decay_rate, 0, 100)

## Deterministic triangle wave — Core Rule 9. Returns (light_level, light_direction).
static func tick_light(light_level: int, light_direction: int) -> Vector2i:
	var new_level := light_level + light_direction * LIGHT_STEP_PER_TICK
	var new_direction := light_direction
	if new_level >= 100:
		new_level = 100
		new_direction = -1
	elif new_level <= 0:
		new_level = 0
		new_direction = 1
	return Vector2i(new_level, new_direction)

## Three-state Plant Growth Delta (GROWING/STALLED/DECAYING) — Core Rule 9's
## round-12 correction. `detail_roll` is externally supplied (injected, not
## read from engine RNG here) — Detail Event Probability formula.
static func plant_tick(growth_stage: int, optimal_hold_ticks: int, max_stage: int, growth_rate: int, decay_rate: int, moisture_ok: bool, light_ok: bool, detail_roll: float) -> PlantTickResult:
	var new_stage := growth_stage
	var growth_state: int
	if moisture_ok and light_ok:
		new_stage = clampi(growth_stage + growth_rate, 0, max_stage)
		growth_state = PlantTickResult.GrowthState.GROWING
	elif moisture_ok and not light_ok:
		growth_state = PlantTickResult.GrowthState.STALLED
	else:
		new_stage = clampi(growth_stage - decay_rate, 0, max_stage)
		growth_state = PlantTickResult.GrowthState.DECAYING

	var new_hold := optimal_hold_ticks
	var detail_triggered := false
	if growth_state == PlantTickResult.GrowthState.GROWING:
		new_hold += 1
		if new_hold >= DETAIL_HOLD_THRESHOLD_TICKS and detail_roll < DETAIL_PROBABILITY:
			detail_triggered = true
	else:
		new_hold = 0

	return PlantTickResult.new(new_stage, new_hold, growth_state, detail_triggered)

static func snail_spawn_condition_met(moss_stage: int, fern_stage: int) -> bool:
	return moss_stage + fern_stage >= SNAIL_SPAWN_MOSS_FERN_THRESHOLD

static func moth_spawn_condition_met(flower_stage: int, flower_max_stage: int, snail_present: bool) -> bool:
	return flower_stage == flower_max_stage and snail_present

## Shared debounce-streak step for both spawn (condition_active = condition
## met while ABSENT) and departure (condition_active = condition NOT met
## while PRESENT) — Core Rules 6/7/7a.
static func debounce_streak_step(streak: int, condition_active: bool) -> int:
	return streak + 1 if condition_active else 0
