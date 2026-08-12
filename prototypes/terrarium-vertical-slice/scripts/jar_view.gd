# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# JarView — Presentation layer. NOT real Diorama Rendering: no Accepted ADR
# and no diorama-realism assets exist yet (ADR-0009 still Proposed) — see
# README. This is placeholder 2D-primitive rendering only: a Polygon2D-style
# hand-drawn ellipse for the jar, colored circles for plants (size/color by
# growth_stage), a colored circle per creature (visible only while a live
# CreatureBehavior instance exists), a gray circle for the rock, a
# background tint that shifts with day_night_phase and light_level, and a
# simple ring pulse for active Discovery Surfacing cues.
#
# Registers itself with InputAbstraction from its own _ready() — ADR-0008
# Required Pattern (never a lazy %UniqueName lookup).
extends Node2D

const JAR_CX := ObjectPlacementMath.JAR_CX
const JAR_CY := ObjectPlacementMath.JAR_CY
const JAR_RX := ObjectPlacementMath.JAR_RX
const JAR_RY := ObjectPlacementMath.JAR_RY

# Presentation-only layout constants — plants have no gameplay position of
# their own (no MVP GDD assigns plants an (x,y); only creatures/objects
# have positions). Fixed here purely so this placeholder has somewhere to
# draw them; a real Diorama Rendering pass would own actual layout.
const PLANT_LAYOUT := {
	"moss": Vector2(-40, 25),
	"fern": Vector2(40, 25),
	"flower": Vector2(0, -25),
}
const PLANT_COLOR := {
	"moss": Color(0.25, 0.55, 0.2),
	"fern": Color(0.15, 0.45, 0.2),
	"flower": Color(0.75, 0.35, 0.55),
}
const CREATURE_COLOR := {
	"snail": Color(0.6, 0.5, 0.3),
	"moth": Color(0.85, 0.85, 0.6),
}

func _ready() -> void:
	InputAbstraction.register_jar(self)
	ObjectPlacement.object_wobbled.connect(func(id: String) -> void: print("[JarView] wobble: ", id))
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_background_and_jar()
	_draw_plants()
	_draw_objects()
	_draw_creatures()
	_draw_discovery_cues()

func _draw_background_and_jar() -> void:
	var phase := TimeDrift.get_day_night_phase()
	var night_amount := 0.5 - 0.5 * cos(phase * TAU) # 0 at "noon", 1 at "midnight"
	var base_tint := Color(0.85, 0.9, 0.95).lerp(Color(0.15, 0.2, 0.35), night_amount)
	var light_mix := clampf(EcosystemSimulation.light_level / 100.0, 0.0, 1.0)
	var tint := base_tint.lerp(Color(1.0, 0.95, 0.75), light_mix * 0.3)
	draw_colored_polygon(_ellipse_points(JAR_CX, JAR_CY, JAR_RX + 15.0, JAR_RY + 15.0), tint)
	draw_colored_polygon(_ellipse_points(JAR_CX, JAR_CY, JAR_RX, JAR_RY), Color(0.55, 0.45, 0.35, 0.9))

func _draw_plants() -> void:
	for plant_id in PLANT_LAYOUT:
		var def: PlantTypeDef = ContentData.get_definition(plant_id)
		if def == null:
			continue
		var pos: Vector2 = PLANT_LAYOUT[plant_id]
		var max_stage := maxi(def.visual_stages.size() - 1, 1)
		var stage := EcosystemSimulation.get_plant_growth_stage(plant_id)
		var t := float(stage) / float(max_stage)
		var radius := lerpf(3.0, 14.0, t)
		var color: Color = PLANT_COLOR.get(plant_id, Color.GREEN)
		draw_circle(pos, radius, color)

func _draw_objects() -> void:
	for object_id in ObjectPlacement.get_object_ids():
		var opos := ObjectPlacement.get_visual_position(object_id)
		var fp := ObjectPlacement.get_footprint(object_id)
		draw_circle(opos, fp, Color(0.5, 0.5, 0.5))

func _draw_creatures() -> void:
	for creature_id in CreatureBehavior.get_instance_ids():
		var cpos := CreatureBehavior.get_instance_position(creature_id)
		var ccolor: Color = CREATURE_COLOR.get(creature_id, Color.WHITE)
		draw_circle(cpos, 4.0, ccolor)

func _draw_discovery_cues() -> void:
	for item in DiscoverySurfacing.get_active_items():
		var cue_pos: Vector2 = item.position
		if item.category == DiscoveryItem.Category.GROWTH or item.category == DiscoveryItem.Category.DETAIL_EVENT:
			cue_pos = PLANT_LAYOUT.get(item.target_id, Vector2.ZERO)
		draw_arc(cue_pos, 10.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.5, 0.85), 2.0)

func _ellipse_points(cx: float, cy: float, rx: float, ry: float, segments: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := float(i) / float(segments) * TAU
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts
