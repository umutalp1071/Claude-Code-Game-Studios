# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# PlantTickResult — typed return value for EcosystemFormulas.plant_tick().
# control-manifest.md: "Formula functions return typed results... never an
# ad-hoc Dictionary return bag" (source: ADR-0004).
extends RefCounted
class_name PlantTickResult

enum GrowthState { GROWING, STALLED, DECAYING }

var growth_stage: int
var optimal_hold_ticks: int
var growth_state: int
var detail_triggered: bool

func _init(p_growth_stage: int, p_optimal_hold_ticks: int, p_growth_state: int, p_detail_triggered: bool) -> void:
	growth_stage = p_growth_stage
	optimal_hold_ticks = p_optimal_hold_ticks
	growth_state = p_growth_state
	detail_triggered = p_detail_triggered
