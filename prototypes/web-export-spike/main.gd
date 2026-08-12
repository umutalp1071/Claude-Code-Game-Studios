extends Control
# Main — 3 buttons to the 3 probe scenes, plus the §0.2 boot diagnostics
# that prove which renderer is actually active. Runs once per app launch
# regardless of which probe gets opened.
# ponytail: throwaway spike code.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	ProbeLog.line("=== Web Export Spike boot ===")
	ProbeLog.line("method=%s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	ProbeLog.line("rendering_device=%s" % str(RenderingServer.get_rendering_device()))
	ProbeLog.line("adapter=%s" % RenderingServer.get_video_adapter_name())
	ProbeLog.line("os=%s feature_web=%s" % [OS.get_name(), OS.has_feature("web")])
	ProbeLog.line("emulate_mouse_from_touch=%s emulate_touch_from_mouse=%s" % [
		ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),
		ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"),
	])

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	add_child(vbox)

	var title := Label.new()
	title.text = "Web Export Spike — pick a probe"
	vbox.add_child(title)

	var input_btn := Button.new()
	input_btn.text = "Gate A — Input Probe"
	input_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://InputProbe.tscn"))
	vbox.add_child(input_btn)

	var persist_btn := Button.new()
	persist_btn.text = "Gate B — Persist Probe"
	persist_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://PersistProbe.tscn"))
	vbox.add_child(persist_btn)

	var render_btn := Button.new()
	render_btn.text = "Gate C — Render Probe"
	render_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://RenderProbe.tscn"))
	vbox.add_child(render_btn)
