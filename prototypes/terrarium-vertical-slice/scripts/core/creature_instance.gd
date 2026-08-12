# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# CreatureInstance — RefCounted live-instance state, owned by
# CreatureBehavior's own _instances registry. Distinct from CreatureState
# (EcosystemSimulation's PRESENT/ABSENT truth) — this only exists while a
# creature has a live, rendered instance (creature-behavior.md Core Rule 3).
extends RefCounted
class_name CreatureInstance

enum Phase { SPAWNING, WANDERING, PAUSING, DEPARTING }

var creature_id: String
var phase: int = Phase.WANDERING
var position: Vector2
var destination: Vector2
var pause_timer: float = 0.0

func _init(p_creature_id: String, p_position: Vector2) -> void:
	creature_id = p_creature_id
	position = p_position
	destination = p_position
