# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# CreatureBehavior — autoload, Feature layer. Follows control-manifest.md
# Feature Layer Required Patterns (source: ADR-0007):
#   - polls EcosystemSimulation.get_creature_state(id) once per _process()
#     frame per creature, diffing against last-observed value — pull-based
#   - resolve_session_start() called directly by SessionBootstrap, exactly
#     once, before any _process() frame
#   - _instances Dictionary entries exist only while a live instance exists
#   - private RandomNumberGenerator, randomize()'d once, no public setter
#   - movement/destination/pause formulas live in CreatureMovementMath
#
# creature-behavior.md Core Rule 8 (session-start entry point): a creature
# whose settled state is PRESENT once TimeDrift reaches ACTIVE enters
# WANDERING directly (never a visible SPAWNING placement for a transition
# that happened inside the invisible catch-up batch). resolve_session_start()
# implements exactly this — called by SessionBootstrap after
# TimeDrift.run_catchup_and_activate() returns.
extends Node

const PAUSE_MIN_FALLBACK := 2.0
const PAUSE_MAX_FALLBACK := 5.0

var _instances: Dictionary = {} # creature_id -> CreatureInstance
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

## Called exactly once by SessionBootstrap, after TimeDrift reaches ACTIVE —
## Core Rule 8. Any creature settled PRESENT enters WANDERING directly at
## its settled (last-known) position; ABSENT creatures get no instance and
## therefore no DEPARTING animation for an unwitnessed departure.
func resolve_session_start() -> void:
	_instances.clear()
	for id in EcosystemSimulation.get_creature_ids():
		if EcosystemSimulation.get_creature_state(id) == CreatureState.Presence.PRESENT:
			var pos := EcosystemSimulation.get_creature_last_known_position(id)
			var inst := CreatureInstance.new(id, pos)
			inst.phase = CreatureInstance.Phase.WANDERING
			inst.destination = _sample_destination_for(pos)
			_instances[id] = inst

func get_instance_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _instances:
		ids.append(id)
	return ids

func get_instance_position(id: String) -> Vector2:
	return _instances[id].position if _instances.has(id) else Vector2.ZERO

func get_instance_phase(id: String) -> int:
	return _instances[id].phase if _instances.has(id) else -1

func _sample_destination_for(_from: Vector2) -> Vector2:
	var obstacle_positions: Array[Vector2] = []
	var obstacle_radii: Array[float] = []
	for oid in ObjectPlacement.get_object_ids():
		obstacle_positions.append(ObjectPlacement.get_position(oid))
		obstacle_radii.append(ObjectPlacement.get_footprint(oid))
	return CreatureMovementMath.sample_destination(_rng, ObjectPlacementMath.JAR_CX, ObjectPlacementMath.JAR_CY, ObjectPlacementMath.JAR_RX, ObjectPlacementMath.JAR_RY, obstacle_positions, obstacle_radii)

func _pause_range(creature_id: String) -> Vector2:
	var def: CreatureTypeDef = ContentData.get_definition(creature_id)
	if def == null:
		return Vector2(PAUSE_MIN_FALLBACK, PAUSE_MAX_FALLBACK)
	return Vector2(def.pause_duration_min, def.pause_duration_max)

func _process(delta: float) -> void:
	if TimeDrift.get_state() != TimeDrift.SessionState.ACTIVE:
		return # Core Rule 8 — no reaction to transitions while CATCHING_UP.

	_sync_live_transitions()

	var to_remove: Array[String] = []
	for id in _instances:
		var inst: CreatureInstance = _instances[id]
		var def: CreatureTypeDef = ContentData.get_definition(id)
		var speed: float = def.movement_speed if def else 6.0

		match inst.phase:
			CreatureInstance.Phase.SPAWNING:
				inst.phase = CreatureInstance.Phase.WANDERING
			CreatureInstance.Phase.WANDERING:
				inst.position = CreatureMovementMath.step_position(inst.position, inst.destination, speed, delta)
				if CreatureMovementMath.has_arrived(inst.position, inst.destination):
					var pause_range := _pause_range(id)
					inst.pause_timer = _rng.randf_range(pause_range.x, pause_range.y)
					inst.phase = CreatureInstance.Phase.PAUSING
			CreatureInstance.Phase.PAUSING:
				inst.pause_timer -= delta
				if inst.pause_timer <= 0.0:
					inst.destination = _sample_destination_for(inst.position)
					inst.phase = CreatureInstance.Phase.WANDERING
			CreatureInstance.Phase.DEPARTING:
				inst.position = CreatureMovementMath.step_position(inst.position, inst.destination, speed, delta)
				if CreatureMovementMath.has_arrived(inst.position, inst.destination):
					to_remove.append(id)

		# Core Rule 9 — same value, same frame, every frame a live instance exists.
		EcosystemSimulation.set_last_known_position(id, inst.position)

	for id in to_remove:
		_instances.erase(id)

## Reacts to LIVE ABSENT<->PRESENT transitions only (post-ACTIVE) — Core
## Rules 1/4/7. Session-start settlement is resolve_session_start()'s job,
## not this one's.
func _sync_live_transitions() -> void:
	for id in EcosystemSimulation.get_creature_ids():
		var live_present := EcosystemSimulation.get_creature_state(id) == CreatureState.Presence.PRESENT
		var has_instance := _instances.has(id)
		if live_present and not has_instance:
			var pos := Vector2(ObjectPlacementMath.JAR_CX, ObjectPlacementMath.JAR_CY)
			var inst := CreatureInstance.new(id, pos)
			inst.phase = CreatureInstance.Phase.SPAWNING
			inst.destination = _sample_destination_for(pos)
			_instances[id] = inst
		elif not live_present and has_instance:
			var inst: CreatureInstance = _instances[id]
			if inst.phase != CreatureInstance.Phase.DEPARTING:
				inst.phase = CreatureInstance.Phase.DEPARTING
				inst.destination = _nearest_edge_point(inst.position)

func _nearest_edge_point(pos: Vector2) -> Vector2:
	var center := Vector2(ObjectPlacementMath.JAR_CX, ObjectPlacementMath.JAR_CY)
	var dir := pos - center
	if dir.length() < 0.01:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	return center + dir * Vector2(ObjectPlacementMath.JAR_RX, ObjectPlacementMath.JAR_RY)
