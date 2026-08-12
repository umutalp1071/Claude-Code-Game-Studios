# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# CreatureMovementMath — separate non-autoload script, static/pure funcs —
# source: ADR-0007. Reuses ObjectPlacementMath.in_bounds() rather than
# reinventing jar-ellipse math (creature-behavior.md Formulas).
extends RefCounted
class_name CreatureMovementMath

const CREATURE_CLEARANCE := 4.0   # default 4, creature-behavior.md Tuning Knobs
const MAX_SAMPLE_ATTEMPTS := 20   # default 20
const ARRIVAL_THRESHOLD := 2.0    # default 2.0 jar-space units

## Destination sampling — rejection sampling over the jar's bounding box,
## rejecting candidates inside any obstacle's footprint + CREATURE_CLEARANCE.
## Falls back to dropping the clearance term after MAX_SAMPLE_ATTEMPTS
## (documented fallback, not an infinite loop) — Formulas.
static func sample_destination(rng: RandomNumberGenerator, cx: float, cy: float, rx: float, ry: float, obstacle_positions: Array[Vector2], obstacle_radii: Array[float]) -> Vector2:
	for _attempt in range(MAX_SAMPLE_ATTEMPTS):
		var candidate := Vector2(rng.randf_range(cx - rx, cx + rx), rng.randf_range(cy - ry, cy + ry))
		if not ObjectPlacementMath.in_bounds(candidate, 0.0, cx, cy, rx, ry):
			continue
		if _clears_all_obstacles(candidate, obstacle_positions, obstacle_radii):
			return candidate
	for _attempt in range(MAX_SAMPLE_ATTEMPTS):
		var candidate := Vector2(rng.randf_range(cx - rx, cx + rx), rng.randf_range(cy - ry, cy + ry))
		if ObjectPlacementMath.in_bounds(candidate, 0.0, cx, cy, rx, ry):
			return candidate
	return Vector2(cx, cy)

static func _clears_all_obstacles(candidate: Vector2, obstacle_positions: Array[Vector2], obstacle_radii: Array[float]) -> bool:
	for i in range(obstacle_positions.size()):
		if candidate.distance_to(obstacle_positions[i]) < obstacle_radii[i] + CREATURE_CLEARANCE:
			return false
	return true

## Movement/arrival — clamps the step to the remaining distance so pos'
## never overshoots dest, regardless of movement_speed or frame-time size.
static func step_position(pos: Vector2, dest: Vector2, movement_speed: float, delta_time: float) -> Vector2:
	var remaining := pos.distance_to(dest)
	if remaining <= 0.0001:
		return pos
	var step := minf(movement_speed * delta_time, remaining)
	return pos + (dest - pos).normalized() * step

static func has_arrived(pos: Vector2, dest: Vector2) -> bool:
	return pos.distance_to(dest) <= ARRIVAL_THRESHOLD
