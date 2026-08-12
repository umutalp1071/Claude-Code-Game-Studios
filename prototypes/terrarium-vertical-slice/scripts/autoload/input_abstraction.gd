# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# InputAbstraction — autoload, Foundation layer. Follows control-manifest.md
# Foundation Layer Required Patterns (source: ADR-0008):
#   - _unhandled_input(event) entry point, never _input()
#   - device identity tagged (source: MOUSE|TOUCH, id), compared against
#     InputEvent.DEVICE_ID_MOUSE, never literal 0
#   - position converted to jar-local space at emission time only
#   - drag_active threshold check uses pre-conversion viewport-space position
#   - jar wired via explicit register_jar(self), never lazy %UniqueName
#   - focus_exited/focus_entered force IDLE + drag_end(canceled=true)
#   - restartable watchdog Timer (PROCESS_MODE_ALWAYS) as a defensive backstop
#
# Known risk (see README "Known Risks"): input-abstraction.md's own Open
# Questions flag the touch-index-vs-DEVICE_ID_MOUSE collision space and the
# real focus_exited/touch-cancel Web-export behavior as UNVERIFIED even in
# the source GDD — this implementation follows the documented working
# hypothesis, not a confirmed engine behavior.
extends Node

signal tap(position: Vector2, device_id: int)
signal drag_start(position: Vector2, device_id: int)
signal drag_move(position: Vector2, delta: Vector2, device_id: int)
signal drag_end(position: Vector2, delta: Vector2, canceled: bool, device_id: int)

const THRESHOLD_MOUSE := 8.0
const THRESHOLD_TOUCH := 16.0
const WATCHDOG_TIMEOUT_SEC := 8.0
const NO_ACTIVE_DEVICE := -9999

enum PointerState { IDLE, PRESSED, DRAGGING }

var _jar: Node2D = null
var _state: int = PointerState.IDLE
var _active_device_id: int = NO_ACTIVE_DEVICE
var _press_pos: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO
var _last_move_pos: Vector2 = Vector2.ZERO
var _watchdog: Timer

func _ready() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_TIMEOUT_SEC
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.timeout.connect(_on_watchdog_timeout)
	add_child(_watchdog)
	get_window().focus_exited.connect(_on_focus_exited)

## Called from the jar scene's own _ready() — ADR-0008 Required Pattern.
func register_jar(jar: Node2D) -> void:
	_jar = jar

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_press_release(InputEvent.DEVICE_ID_MOUSE, event.position, event.pressed)
	elif event is InputEventMouseMotion:
		_handle_motion(InputEvent.DEVICE_ID_MOUSE, event.position)
	elif event is InputEventScreenTouch:
		_handle_press_release(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_motion(event.index, event.position)

func _handle_press_release(device_id: int, viewport_pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _state != PointerState.IDLE:
			if device_id != _active_device_id:
				return # Core Rule 7 — a second device is ignored while one is active.
			# Core Rule 7a — same-device re-press: implicit release-then-press.
			if _state == PointerState.DRAGGING:
				_emit_drag_end(_current_pos, true)
		_state = PointerState.PRESSED
		_active_device_id = device_id
		_press_pos = viewport_pos
		_current_pos = viewport_pos
		_restart_watchdog()
		return

	if device_id != _active_device_id or _state == PointerState.IDLE:
		return
	if _state == PointerState.PRESSED:
		tap.emit(_to_jar_local(viewport_pos), device_id)
		_reset_to_idle()
	elif _state == PointerState.DRAGGING:
		_emit_drag_end(viewport_pos, false)
		_reset_to_idle()

func _handle_motion(device_id: int, viewport_pos: Vector2) -> void:
	if _state == PointerState.IDLE or device_id != _active_device_id:
		return
	_restart_watchdog()
	var clamped := _clamp_to_viewport(viewport_pos)
	if _state == PointerState.PRESSED:
		_current_pos = clamped
		# Threshold check uses the pre-conversion viewport-space reading —
		# input-abstraction.md Core Rule 4's load-bearing distinction.
		if _press_pos.distance_to(clamped) > _threshold_for(device_id):
			_state = PointerState.DRAGGING
			_last_move_pos = clamped
			drag_start.emit(_to_jar_local(clamped), device_id)
	elif _state == PointerState.DRAGGING:
		var d := clamped - _last_move_pos
		_last_move_pos = clamped
		_current_pos = clamped
		drag_move.emit(_to_jar_local(clamped), d, device_id)

func _threshold_for(device_id: int) -> float:
	return THRESHOLD_MOUSE if device_id == InputEvent.DEVICE_ID_MOUSE else THRESHOLD_TOUCH

func _clamp_to_viewport(pos: Vector2) -> Vector2:
	var size := get_viewport().get_visible_rect().size
	return Vector2(clampf(pos.x, 0.0, size.x), clampf(pos.y, 0.0, size.y))

func _to_jar_local(viewport_pos: Vector2) -> Vector2:
	if _jar == null:
		return viewport_pos
	return _jar.to_local(viewport_pos)

func _emit_drag_end(viewport_pos: Vector2, canceled: bool) -> void:
	var clamped := _clamp_to_viewport(viewport_pos)
	drag_end.emit(_to_jar_local(clamped), Vector2.ZERO, canceled, _active_device_id)

func _reset_to_idle() -> void:
	_state = PointerState.IDLE
	_active_device_id = NO_ACTIVE_DEVICE
	_watchdog.stop()

func _restart_watchdog() -> void:
	_watchdog.stop()
	_watchdog.start()

func _on_focus_exited() -> void:
	if _state == PointerState.DRAGGING:
		_emit_drag_end(_current_pos, true)
	_reset_to_idle()

func _on_watchdog_timeout() -> void:
	if _state == PointerState.DRAGGING:
		_emit_drag_end(_current_pos, true)
	_reset_to_idle()
