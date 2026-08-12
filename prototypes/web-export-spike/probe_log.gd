extends Node
# ProbeLog — autoload. On-screen ring-buffer log + "Copy log" button, shared
# by all 3 probe scenes. Bottom-of-screen overlay so it never blocks the
# probes' own controls above it.
# ponytail: throwaway spike code — no doc comments, minimal error handling.

const MAX_LINES := 400

var _lines: Array[String] = []
var _label: Label
var _scroll: ScrollContainer

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var panel := PanelContainer.new()
	# ponytail: set_anchors_preset(PRESET_BOTTOM_WIDE) before the panel has a
	# real size computes zero-height offsets pinned at the bottom edge; the
	# later custom_minimum_size then grows the panel DOWNWARD, off-screen.
	# Setting anchors + offsets explicitly avoids depending on call order.
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = -220.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size = Vector2(0, 220)
	panel.modulate = Color(1, 1, 1, 0.92)
	layer.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var copy_btn := Button.new()
	copy_btn.text = "Copy log"
	copy_btn.pressed.connect(_on_copy_pressed)
	vbox.add_child(copy_btn)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(_scroll)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_scroll.add_child(_label)

func line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > MAX_LINES:
		_lines.pop_front()
	if _label:
		_label.text = "\n".join(_lines)
		call_deferred("_scroll_to_bottom")
	print(text)

func get_text() -> String:
	return "\n".join(_lines)

func _scroll_to_bottom() -> void:
	if _scroll and _scroll.get_v_scroll_bar():
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(get_text())
	line("[log copied to clipboard]")
