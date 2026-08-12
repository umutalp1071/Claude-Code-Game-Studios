# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# ObjectState — standalone RefCounted, own file (not a Resource) — source:
# ADR-0003. Owned exclusively by the ObjectPlacement autoload.
extends RefCounted
class_name ObjectState

var object_id: String
var type_id: String
var position: Vector2
var footprint_size: float
var repositionable: bool

func _init(p_object_id: String, p_type_id: String, p_position: Vector2, p_footprint_size: float, p_repositionable: bool) -> void:
	object_id = p_object_id
	type_id = p_type_id
	position = p_position
	footprint_size = p_footprint_size
	repositionable = p_repositionable
