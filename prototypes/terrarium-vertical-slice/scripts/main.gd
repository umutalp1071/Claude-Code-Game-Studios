# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# Main — presentation root. Builds the jar view and the debug "Advance
# Session" UI entirely in code (no hand-authored multi-node .tscn tree),
# mirroring this project's existing prototypes/web-export-spike pattern —
# the lowest-risk way to get a runnable scene without guessing at Godot
# 4.7's .tscn node-tree text format for a nontrivial tree.
#
# The "Advance Session" buttons are this slice's stand-in for a real
# session boundary (see session_bootstrap.gd) — they simulate closing and
# reopening the jar after a chosen amount of real time, so day/night drift,
# growth, and creature spawn/departure are all observable within one
# sitting instead of requiring an actual multi-hour wait.
extends Node2D

const JAR_SCREEN_POS := Vector2(480, 340)
const JAR_SCALE := 3.0

var _info_label: Label

func _ready() -> void:
	var jar := Node2D.new()
	jar.set_script(preload("res://scripts/jar_view.gd"))
	jar.position = JAR_SCREEN_POS
	jar.scale = Vector2(JAR_SCALE, JAR_SCALE)
	add_child(jar) # triggers jar_view.gd's _ready(), incl. register_jar()

	_build_debug_ui()

func _build_debug_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 10
	panel.offset_top = 10
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Terrarium — Vertical Slice (debug)"
	vbox.add_child(title)

	_info_label = Label.new()
	vbox.add_child(_info_label)

	var hint := Label.new()
	hint.text = "Tap open jar space to water. Drag the rock to reposition."
	vbox.add_child(hint)

	_add_advance_button(vbox, "Advance Session +2 hours", 2.0 * 3600.0)
	_add_advance_button(vbox, "Advance Session +1 day", 24.0 * 3600.0)
	_add_advance_button(vbox, "Advance Session +1 week", 7.0 * 24.0 * 3600.0)

func _add_advance_button(parent: VBoxContainer, label: String, seconds: float) -> void:
	var btn := Button.new()
	btn.text = label
	btn.pressed.connect(func() -> void: SessionBootstrap.advance_session(seconds))
	parent.add_child(btn)

func _process(_delta: float) -> void:
	if _info_label == null:
		return
	_info_label.text = "moisture=%d  light=%d  day_night=%.2f\nsnail=%s  moth=%s" % [
		EcosystemSimulation.jar_moisture,
		EcosystemSimulation.light_level,
		TimeDrift.get_day_night_phase(),
		CreatureState.Presence.keys()[EcosystemSimulation.get_creature_state("snail")],
		CreatureState.Presence.keys()[EcosystemSimulation.get_creature_state("moth")],
	]
