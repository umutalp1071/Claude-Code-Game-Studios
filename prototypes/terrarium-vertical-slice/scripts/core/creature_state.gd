# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# CreatureState — RefCounted per-creature state, owned by
# EcosystemSimulation's _creatures registry. `state` is a real enum
# (Presence), not an int with a comment — ADR-0004 Required Pattern.
extends RefCounted
class_name CreatureState

enum Presence { ABSENT, PRESENT }

var type_id: String
var state: int = Presence.ABSENT
var condition_streak_ticks: int = 0
var last_known_position: Vector2 = Vector2.ZERO
## Transient, per-batch — ecosystem-simulation.md Core Rule 13. Never
## persisted (see EcosystemSimulation.restore()/get_snapshot()).
var was_present_during_batch: bool = false

func _init(p_type_id: String) -> void:
	type_id = p_type_id
