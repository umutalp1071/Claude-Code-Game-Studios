# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# TendingInput — autoload, Core layer. Follows control-manifest.md Core
# Layer Required Patterns (source: ADR-0011):
#   - single stateless autoload, zero scene-tree nodes, zero persisted fields
#   - connects to InputAbstraction.tap once, direct (non-deferred) Callable
#   - on tap: reject via in_bounds(fp=0), reject via
#     is_within_any_footprint(), else apply_watering() exactly once
#   - no call_deferred/await/CONNECT_DEFERRED anywhere in this chain
#   - connects ONLY to tap, never drag_*
# Autoload order: EcosystemSimulation and InputAbstraction must be declared
# before this autoload in project.godot (they are).
extends Node

func _ready() -> void:
	InputAbstraction.tap.connect(_on_tap)

func _on_tap(position: Vector2, _device_id: int) -> void:
	if not ObjectPlacementMath.in_bounds(position, 0.0):
		return
	if ObjectPlacement.is_within_any_footprint(position):
		return # Object Placement's own AC13 wobble covers this tap's feedback.
	EcosystemSimulation.apply_watering(EcosystemSimulation.get_watering_amount())
