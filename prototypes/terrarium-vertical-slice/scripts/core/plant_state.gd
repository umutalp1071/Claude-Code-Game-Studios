# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# PlantState — RefCounted per-plant-instance state, owned by
# EcosystemSimulation's _plants registry (ecosystem-simulation.md Core Rules
# 1-2, ADR-0004).
extends RefCounted
class_name PlantState

var type_id: String
var growth_stage: int = 0
var optimal_hold_ticks: int = 0

func _init(p_type_id: String, p_growth_stage: int = 0, p_optimal_hold_ticks: int = 0) -> void:
	type_id = p_type_id
	growth_stage = p_growth_stage
	optimal_hold_ticks = p_optimal_hold_ticks
