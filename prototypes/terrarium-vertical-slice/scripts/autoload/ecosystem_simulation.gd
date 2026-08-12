# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# EcosystemSimulation — autoload, Core layer. Follows control-manifest.md
# Core Layer Required Patterns (source: ADR-0004):
#   - jar-wide scalars as plain fields + two Dictionary registries
#     (_plants, _creatures) of RefCounted state classes
#   - CreatureState.state is a real enum (see creature_state.gd)
#   - all formulas live in EcosystemFormulas, static, pure
#   - private _rng, randomize()'d once in _ready(), never exposed
#   - advance_tick() applies exactly one tick; per-tick order fixed:
#     moisture decay -> light tick -> plants -> creatures (Core Rule 11)
#   - set_last_known_position() called by CreatureBehavior every live frame,
#     separate from advance_tick()'s per-tick orchestration
#   - never calls outward to any other system — pure state owner
extends Node

signal watering_applied(new_moisture: int)

const WATERING_AMOUNT := 25 # ecosystem-simulation.md Formulas, "recommended: 25"
const MOISTURE_DECAY_RATE := 3
const N_SPAWN_TICKS := 3
const N_DEPARTURE_TICKS := 25

var jar_moisture: int = 50
var light_level: int = 50
var light_direction: int = 1 # ascending — first-session default, Formulas

var _plants: Dictionary = {}    # id -> PlantState
var _creatures: Dictionary = {} # id -> CreatureState
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for id in ContentData.get_registry_ids():
		var def: Resource = ContentData.get_definition(id)
		if def is PlantTypeDef:
			_plants[id] = PlantState.new(id)
		elif def is CreatureTypeDef:
			_creatures[id] = CreatureState.new(id)

## Registration (insertion) order — ADR-0004 Required Pattern.
func get_plant_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _plants:
		ids.append(id)
	return ids

func get_creature_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _creatures:
		ids.append(id)
	return ids

func get_plant_growth_stage(id: String) -> int:
	return _plants[id].growth_stage if _plants.has(id) else 0

func get_plant_max_stage(id: String) -> int:
	var def: PlantTypeDef = ContentData.get_definition(id)
	return maxi(def.visual_stages.size() - 1, 1) if def else 1

func get_creature_state(id: String) -> int:
	return _creatures[id].state if _creatures.has(id) else CreatureState.Presence.ABSENT

func get_creature_last_known_position(id: String) -> Vector2:
	return _creatures[id].last_known_position if _creatures.has(id) else Vector2.ZERO

func get_was_present_during_batch(id: String) -> bool:
	return _creatures[id].was_present_during_batch if _creatures.has(id) else false

func get_watering_amount() -> int:
	return WATERING_AMOUNT

## Tending Input's sole write entry point — live, immediate (Core Rule 5).
## watering_applied fires at the end, after jar_moisture is written.
func apply_watering(amount: int) -> void:
	jar_moisture = EcosystemFormulas.apply_watering(jar_moisture, amount)
	watering_applied.emit(jar_moisture)

## Called by CreatureBehavior every live frame it holds an instance — Core
## Rule 12. Ecosystem Simulation is still only ever called INTO, never calls
## outward.
func set_last_known_position(creature_id: String, pos: Vector2) -> void:
	if _creatures.has(creature_id):
		_creatures[creature_id].last_known_position = pos

## Reset at the start of every catch-up batch — Core Rule 13. Called by
## TimeDrift immediately before its tick loop.
func reset_batch_flags() -> void:
	for id in _creatures:
		_creatures[id].was_present_during_batch = false

## Called exactly once, only by SessionBootstrap — ADR-0004.
func restore(restored_blob: Dictionary) -> void:
	jar_moisture = restored_blob.get("jar_moisture", 50)
	light_level = restored_blob.get("light_level", 50)
	light_direction = restored_blob.get("light_direction", 1)
	var plants_blob: Dictionary = restored_blob.get("plants", {})
	for id in _plants:
		if plants_blob.has(id):
			var p: Dictionary = plants_blob[id]
			_plants[id].growth_stage = p.get("growth_stage", 0)
			_plants[id].optimal_hold_ticks = p.get("optimal_hold_ticks", 0)
	var creatures_blob: Dictionary = restored_blob.get("creatures", {})
	for id in _creatures:
		if creatures_blob.has(id):
			var c: Dictionary = creatures_blob[id]
			_creatures[id].state = c.get("state", CreatureState.Presence.ABSENT)
			_creatures[id].condition_streak_ticks = c.get("condition_streak_ticks", 0)
			_creatures[id].last_known_position = c.get("last_known_position", Vector2.ZERO)
		_creatures[id].was_present_during_batch = false

## In-memory snapshot — this slice's stand-in for a real save blob (see
## README "Persistence simplification"). Deliberately excludes the
## transient was_present_during_batch flag, matching persistence-save.md's
## own detail-event-flag exclusion pattern for transient per-tick state.
func get_snapshot() -> Dictionary:
	var plants_out := {}
	for id in _plants:
		var p: PlantState = _plants[id]
		plants_out[id] = {"growth_stage": p.growth_stage, "optimal_hold_ticks": p.optimal_hold_ticks}
	var creatures_out := {}
	for id in _creatures:
		var c: CreatureState = _creatures[id]
		creatures_out[id] = {
			"state": c.state,
			"condition_streak_ticks": c.condition_streak_ticks,
			"last_known_position": c.last_known_position,
		}
	return {
		"jar_moisture": jar_moisture,
		"light_level": light_level,
		"light_direction": light_direction,
		"plants": plants_out,
		"creatures": creatures_out,
	}

## Applies exactly one tick's worth of change. Safe to call N times in a
## row. Fixed order: moisture decay -> light -> plants -> creatures (Core
## Rule 11).
func advance_tick() -> void:
	jar_moisture = EcosystemFormulas.tick_moisture_decay(jar_moisture, MOISTURE_DECAY_RATE)
	var light_result := EcosystemFormulas.tick_light(light_level, light_direction)
	light_level = light_result.x
	light_direction = light_result.y

	for id in _plants:
		var p: PlantState = _plants[id]
		var def: PlantTypeDef = ContentData.get_definition(p.type_id)
		if def == null:
			continue
		var max_stage := maxi(def.visual_stages.size() - 1, 1)
		var moisture_ok := jar_moisture >= def.moisture_tolerance_min and jar_moisture <= def.moisture_tolerance_max
		var light_ok := light_level >= def.light_tolerance_min and light_level <= def.light_tolerance_max
		var roll := _rng.randf()
		var result := EcosystemFormulas.plant_tick(p.growth_stage, p.optimal_hold_ticks, max_stage, def.growth_rate, def.decay_rate, moisture_ok, light_ok, roll)
		p.growth_stage = result.growth_stage
		p.optimal_hold_ticks = result.optimal_hold_ticks

	# Creatures read the state every other creature had at tick START — Core
	# Rule 11 — so creature evaluation order never changes the outcome.
	var snail_present_at_tick_start := _creatures.has("snail") and _creatures["snail"].state == CreatureState.Presence.PRESENT
	for id in _creatures:
		var c: CreatureState = _creatures[id]
		var condition_met := false
		if id == "snail":
			condition_met = EcosystemFormulas.snail_spawn_condition_met(get_plant_growth_stage("moss"), get_plant_growth_stage("fern"))
		elif id == "moth":
			condition_met = EcosystemFormulas.moth_spawn_condition_met(get_plant_growth_stage("flower"), get_plant_max_stage("flower"), snail_present_at_tick_start)

		if c.state == CreatureState.Presence.ABSENT:
			c.condition_streak_ticks = EcosystemFormulas.debounce_streak_step(c.condition_streak_ticks, condition_met)
			if c.condition_streak_ticks >= N_SPAWN_TICKS:
				c.state = CreatureState.Presence.PRESENT
				c.condition_streak_ticks = 0
		else:
			c.condition_streak_ticks = EcosystemFormulas.debounce_streak_step(c.condition_streak_ticks, not condition_met)
			if c.condition_streak_ticks >= N_DEPARTURE_TICKS:
				c.state = CreatureState.Presence.ABSENT
				c.condition_streak_ticks = 0

		if c.state == CreatureState.Presence.PRESENT:
			c.was_present_during_batch = true
