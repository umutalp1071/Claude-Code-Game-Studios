extends Control
# Gate A — Input Abstraction verification probe. See
# docs/technical-setup/web-export-verification-plan.md §1 for the full
# procedure (A1-A5) and pass/fail criteria.
# ponytail: throwaway spike code — minimal error handling, no doc comments.

var _indicator: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Doubles as the A5 "fixed on-screen marker".
	_indicator = ColorRect.new()
	_indicator.size = Vector2(60, 60)
	_indicator.position = Vector2(20, 20)
	_indicator.color = Color(0.3, 0.3, 0.3)
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_indicator)

	var label := Label.new()
	label.position = Vector2(100, 20)
	label.text = "Gate A — tap/click/drag anywhere.\nA1: 20 taps + 5 slow drags.\nA2/A3: start a drag, then background the tab/app, wait 5s, return.\nA4: drag off the canvas edge."
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var a5_btn := Button.new()
	a5_btn.text = "Log A5 metrics (zoom/DPI)"
	a5_btn.position = Vector2(20, 140)
	a5_btn.pressed.connect(_log_a5)
	add_child(a5_btn)

	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(20, 180)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn"))
	add_child(back)

	get_window().focus_exited.connect(func(): ProbeLog.line("[WINDOW] focus_exited frame=%d ms=%d" % [Engine.get_frames_drawn(), Time.get_ticks_msec()]))
	get_window().focus_entered.connect(func(): ProbeLog.line("[WINDOW] focus_entered frame=%d ms=%d" % [Engine.get_frames_drawn(), Time.get_ticks_msec()]))

	HideBridge.hide_detected.connect(_on_hide_detected)

	ProbeLog.line("--- Gate A ready ---")

func _on_hide_detected(js_ts: float, gd_now: float, frame: int) -> void:
	ProbeLog.line("[A2] hide_detected while InputProbe active: frame=%d gd_now=%.1f js_ts=%.1f" % [frame, gd_now, js_ts])

func _log_a5() -> void:
	ProbeLog.line("[A5] visible_rect=%s window_size=%s content_scale_factor=%s marker_global_pos=%s" % [
		get_viewport().get_visible_rect().size,
		DisplayServer.window_get_size(),
		get_window().content_scale_factor,
		_indicator.global_position,
	])

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion \
		or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return

	var device := "?"
	var idx := ""
	var pos := Vector2.ZERO
	var pressed_str := ""

	if event is InputEventMouseButton:
		device = "MOUSE" if event.device == InputEvent.DEVICE_ID_MOUSE else "dev%d" % event.device
		pos = event.position
		pressed_str = str(event.pressed)
		_indicator.color = Color(0, 1, 0) if event.pressed else Color(0.3, 0.3, 0.3)
	elif event is InputEventMouseMotion:
		device = "MOUSE" if event.device == InputEvent.DEVICE_ID_MOUSE else "dev%d" % event.device
		pos = event.position
	elif event is InputEventScreenTouch:
		device = "TOUCH"
		idx = "idx%d" % event.index
		pos = event.position
		pressed_str = str(event.pressed)
		_indicator.color = Color(0, 1, 0) if event.pressed else Color(0.3, 0.3, 0.3)
	elif event is InputEventScreenDrag:
		device = "TOUCH"
		idx = "idx%d" % event.index
		pos = event.position

	ProbeLog.line("%d %d %s dev=%s %s pos=%s pressed=%s" % [
		Engine.get_frames_drawn(), Time.get_ticks_msec(),
		event.get_class(), device, idx, pos, pressed_str,
	])

func _notification(what: int) -> void:
	var names := {
		NOTIFICATION_APPLICATION_FOCUS_IN: "APPLICATION_FOCUS_IN",
		NOTIFICATION_APPLICATION_FOCUS_OUT: "APPLICATION_FOCUS_OUT",
		NOTIFICATION_WM_WINDOW_FOCUS_IN: "WM_WINDOW_FOCUS_IN",
		NOTIFICATION_WM_WINDOW_FOCUS_OUT: "WM_WINDOW_FOCUS_OUT",
		NOTIFICATION_APPLICATION_PAUSED: "APPLICATION_PAUSED",
		NOTIFICATION_APPLICATION_RESUMED: "APPLICATION_RESUMED",
	}
	if names.has(what):
		ProbeLog.line("[NOTIFY] %s frame=%d ms=%d" % [names[what], Engine.get_frames_drawn(), Time.get_ticks_msec()])
