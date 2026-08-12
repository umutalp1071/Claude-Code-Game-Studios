# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# DiscoveryItem — RefCounted, never a Resource — source: ADR-0010.
extends RefCounted
class_name DiscoveryItem

enum Category { GROWTH, DEPARTURE, DETAIL_EVENT, ARRIVAL }

var category: int
var target_id: String
var position: Vector2
var from_stage: int = -1
var to_stage: int = -1
## discovery-surfacing.md Core Rule 2a — a full spawn-then-departure
## residency the player never witnessed within one catch-up batch.
var full_cycle: bool = false

func _init(p_category: int, p_target_id: String, p_position: Vector2) -> void:
	category = p_category
	target_id = p_target_id
	position = p_position
