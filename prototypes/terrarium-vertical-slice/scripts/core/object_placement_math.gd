# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# ObjectPlacementMath — separate non-autoload script, static funcs only —
# source: ADR-0003. No Area2D/CollisionShape2D/physics — pure Vector2 math,
# per object-placement.md Formulas. Jar geometry is this slice's fixed scene
# layout, reused verbatim by CreatureBehavior's own destination sampling
# (object-placement.md's own stated cross-system reuse pattern).
extends RefCounted
class_name ObjectPlacementMath

const JAR_CX := 0.0
const JAR_CY := 0.0
const JAR_RX := 100.0
const JAR_RY := 60.0
const LENIENCY := 0.8 # object-placement.md Tuning Knobs, safe range 0.7-0.9

## object-placement.md Formulas — in-bounds check. Domain precondition:
## fp < min(rx, ry); outside that domain this returns false outright rather
## than computing a misleading value.
static func in_bounds(pos: Vector2, fp: float, cx: float = JAR_CX, cy: float = JAR_CY, rx: float = JAR_RX, ry: float = JAR_RY) -> bool:
	if fp >= minf(rx, ry):
		return false
	var dx := (pos.x - cx) / (rx - fp)
	var dy := (pos.y - cy) / (ry - fp)
	return dx * dx + dy * dy <= 1.0

## object-placement.md Formulas — overlap check (pairwise).
static func no_overlap(pos_a: Vector2, fp_a: float, pos_b: Vector2, fp_b: float, leniency: float = LENIENCY) -> bool:
	return pos_a.distance_to(pos_b) >= (fp_a + fp_b) * leniency

## object-placement.md Formulas — footprint hit-test, inclusive boundary.
static func footprint_hit(point: Vector2, obj_pos: Vector2, fp: float) -> bool:
	return point.distance_to(obj_pos) <= fp

## object-placement.md Formulas — drag-follow position.
static func drag_follow_position(pointer_pos: Vector2, grab_offset: Vector2) -> Vector2:
	return pointer_pos - grab_offset
