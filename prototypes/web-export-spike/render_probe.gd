extends Node2D
# Gate C — Diorama Rendering verification probe. See
# docs/technical-setup/web-export-verification-plan.md §3 for the full
# procedure (C1-C4) and pass/fail criteria.
#
# Uses PROCEDURALLY GENERATED placeholder art (a radial "dome" normal map,
# not the real jar asset) — per the plan's own §3.1 allowance: this
# answers C2/C3/C4, but C1 is PROVISIONAL until re-run against the real
# jar diffuse+normal from art-director/technical-artist.
#
# hdr_2d (rendering/viewport/hdr_2d in project.godot) is a project setting,
# not runtime-toggleable — per the plan, export TWO builds (on/off) and
# compare C2 between them manually. This probe only toggles glow_enabled
# at runtime, which is a separate, legitimately-runtime-toggleable knob.
#
# ponytail: throwaway spike code.

const DAY_NIGHT_STOPS := {
	"offsets": [0.0, 0.35, 0.55, 1.0],
	"colors": [
		Color(0.50, 0.58, 0.80),
		Color(0.78, 0.68, 0.75),
		Color(1.00, 0.82, 0.60),
		Color(1.00, 1.00, 1.00),
	],
}

var _jar: Sprite2D
var _sun: PointLight2D
var _cue_lights: Array[PointLight2D] = []
var _canvas_mod: CanvasModulate
var _gradient: Gradient
var _env: Environment
var _light_tex: ImageTexture
var _hud: Label
var _worst_ms := 0.0

func _ready() -> void:
	_light_tex = _make_light_texture()
	_build_scene_content()
	_build_ui()
	ProbeLog.line("--- Gate C ready --- (placeholder art — C1 result is PROVISIONAL)")

# ---------- procedural placeholder art (see file header) ----------

func _make_diffuse() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.55, 0.45, 0.30))
	return ImageTexture.create_from_image(img)

func _make_normal() -> ImageTexture:
	# Dome-shaped bump: normal points straight up at center, tilts outward
	# toward the edge. Enough shading variation for a light sweep to show
	# a visible highlight moving across the surface.
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var radius := size / 2.0
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var d: float = clamp(p.distance_to(center) / radius, 0.0, 1.0)
			var dir := (p - center).normalized() if d > 0.01 else Vector2.ZERO
			var nx := dir.x * d
			var ny := dir.y * d
			var nz := sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
			img.set_pixel(x, y, Color(nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)

func _make_light_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center) / (size / 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, clamp(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

# ---------- scene content ----------

func _build_scene_content() -> void:
	_jar = Sprite2D.new()
	var ctex := CanvasTexture.new()
	ctex.diffuse_texture = _make_diffuse()
	ctex.normal_texture = _make_normal()
	_jar.texture = ctex
	_jar.position = Vector2(300, 300)
	_jar.scale = Vector2(2, 2)
	add_child(_jar)

	var leaf := Sprite2D.new()
	var ltex := CanvasTexture.new()
	ltex.diffuse_texture = _make_diffuse()
	ltex.normal_texture = _make_normal()
	leaf.texture = ltex
	leaf.position = Vector2(420, 250)
	leaf.scale = Vector2(0.6, 0.6)
	add_child(leaf)

	_sun = PointLight2D.new()
	_sun.texture = _light_tex
	_sun.position = _jar.position + Vector2(-150, -150)
	_sun.energy = 1.0
	_sun.texture_scale = 2.0
	add_child(_sun)

	_canvas_mod = CanvasModulate.new()
	_canvas_mod.color = Color(1, 1, 1)
	add_child(_canvas_mod)

	_gradient = Gradient.new()
	_gradient.offsets = PackedFloat32Array(DAY_NIGHT_STOPS["offsets"])
	_gradient.colors = PackedColorArray(DAY_NIGHT_STOPS["colors"])

	_env = Environment.new()
	_env.background_mode = Environment.BG_CANVAS
	_env.glow_enabled = true
	_env.glow_intensity = 1.5
	_env.glow_strength = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

# ---------- UI ----------

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	add_child(vbox)

	var title := Label.new()
	title.text = "Gate C — placeholder art (dome normal map). C1 result is PROVISIONAL until re-run on the real jar asset."
	vbox.add_child(title)

	_hud = Label.new()
	vbox.add_child(_hud)

	var reset_btn := Button.new()
	reset_btn.text = "Reset worst_ms (hold 30s for C4)"
	reset_btn.pressed.connect(func(): _worst_ms = 0.0)
	vbox.add_child(reset_btn)

	vbox.add_child(_labeled(Label.new(), "C1 — sweep sun angle 0-360deg:"))
	var angle_slider := HSlider.new()
	angle_slider.min_value = 0
	angle_slider.max_value = 360
	angle_slider.step = 1
	angle_slider.custom_minimum_size = Vector2(220, 20)
	angle_slider.value_changed.connect(func(v: float):
		var rad := deg_to_rad(v)
		_sun.position = _jar.position + Vector2(cos(rad), sin(rad)) * 150
	)
	vbox.add_child(angle_slider)

	var glow_toggle := CheckBox.new()
	glow_toggle.text = "C2 — Glow enabled"
	glow_toggle.button_pressed = true
	glow_toggle.toggled.connect(func(on: bool): _env.glow_enabled = on)
	vbox.add_child(glow_toggle)

	var cue_row := HBoxContainer.new()
	vbox.add_child(cue_row)
	var minus_btn := Button.new()
	minus_btn.text = "- cue light"
	minus_btn.pressed.connect(_remove_cue_light)
	cue_row.add_child(minus_btn)
	var plus_btn := Button.new()
	plus_btn.text = "+ cue light (C4, max 5)"
	plus_btn.pressed.connect(_add_cue_light)
	cue_row.add_child(plus_btn)

	vbox.add_child(_labeled(Label.new(), "C3 — day/night t (0=night, 1=midday):"))
	var t_slider := HSlider.new()
	t_slider.min_value = 0.0
	t_slider.max_value = 1.0
	t_slider.step = 0.01
	t_slider.custom_minimum_size = Vector2(220, 20)
	t_slider.value_changed.connect(func(v: float): _canvas_mod.color = _gradient.sample(v))
	vbox.add_child(t_slider)

	var blue_btn := Button.new()
	blue_btn.text = "C3 — force strong blue"
	blue_btn.pressed.connect(func(): _canvas_mod.color = Color(0.2, 0.3, 1.0))
	vbox.add_child(blue_btn)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://Main.tscn"))
	vbox.add_child(back)

func _labeled(l: Label, text: String) -> Label:
	l.text = text
	return l

func _add_cue_light() -> void:
	if _cue_lights.size() >= 5:
		return
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.position = _jar.position + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	l.energy = 1.5
	l.color = Color(1.0, 0.9, 0.6)
	add_child(l)
	_cue_lights.append(l)
	ProbeLog.line("[C4] cue_lights=%d" % _cue_lights.size())

func _remove_cue_light() -> void:
	if _cue_lights.is_empty():
		return
	var l: PointLight2D = _cue_lights.pop_back()
	l.queue_free()
	ProbeLog.line("[C4] cue_lights=%d" % _cue_lights.size())

func _process(_delta: float) -> void:
	var frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_worst_ms = max(_worst_ms, frame_ms)
	if _hud:
		_hud.text = "FPS=%.0f  frame_ms=%.2f  worst_ms=%.2f  draw_calls=%d  objects=%d  cue_lights=%d" % [
			Engine.get_frames_per_second(),
			frame_ms,
			_worst_ms,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			_cue_lights.size(),
		]
