extends Control
# Gate B — Persistence verification probe. See
# docs/technical-setup/web-export-verification-plan.md §2 for the full
# procedure (soft/medium/hard-kill teardown severities) and pass/fail
# criteria. probe_js is written entirely by HideBridge's JS listener;
# probe_fs/probe_gd are this probe's own job, triggered by hide_detected
# while this screen is the active one (matching the plan's own procedure,
# which has the tester on this screen when triggering each teardown).
# ponytail: throwaway spike code.

var _label: Label
var _syncfs_checkbox: CheckBox

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	add_child(vbox)

	var title := Label.new()
	title.text = "Gate B — background/kill the tab, then return and press Refresh.\nRun 5x per browser at each teardown severity (soft/medium/hard-kill)."
	vbox.add_child(title)

	_syncfs_checkbox = CheckBox.new()
	_syncfs_checkbox.text = "Call FS.syncfs() after writing probe_fs (this is the B2 with/without variant)"
	_syncfs_checkbox.button_pressed = true
	vbox.add_child(_syncfs_checkbox)

	_label = Label.new()
	vbox.add_child(_label)

	var refresh := Button.new()
	refresh.text = "Refresh counters"
	refresh.pressed.connect(_refresh)
	vbox.add_child(refresh)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn"))
	vbox.add_child(back)

	HideBridge.hide_detected.connect(_on_hide_detected)
	_refresh()
	ProbeLog.line("--- Gate B ready ---")

func _on_hide_detected(_js_ts: float, _gd_now: float, frame: int) -> void:
	var current := 0
	var f := FileAccess.open("user://probe.txt", FileAccess.READ)
	if f:
		current = f.get_as_text().to_int()
		f.close()
	current += 1

	var fw := FileAccess.open("user://probe.txt", FileAccess.WRITE)
	fw.store_string(str(current))
	fw.close()

	if OS.has_feature("web"):
		if _syncfs_checkbox.button_pressed:
			JavaScriptBridge.eval("FS.syncfs(false, function(e){ console.log('syncfs', e); })", true)
		JavaScriptBridge.eval("localStorage.setItem('probe_gd', '%d')" % current, true)

	ProbeLog.line("[B] wrote probe_fs=%d probe_gd=%d syncfs=%s frame=%d" % [
		current, current, str(_syncfs_checkbox.button_pressed), frame,
	])

func _refresh() -> void:
	var fs_val := "n/a"
	var f := FileAccess.open("user://probe.txt", FileAccess.READ)
	if f:
		fs_val = f.get_as_text()
		f.close()

	var gd_val := "n/a"
	var js_val := "n/a"
	if OS.has_feature("web"):
		gd_val = str(JavaScriptBridge.eval("localStorage.getItem('probe_gd')", true))
		js_val = HideBridge.probe_js_value()

	_label.text = "probe_fs=%s   probe_gd=%s   probe_js=%s" % [fs_val, gd_val, js_val]
	ProbeLog.line("[B] refresh: %s" % _label.text)
