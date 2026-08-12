# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# ObjectPlacement — autoload, Core layer. Follows control-manifest.md Core
# Layer Required Patterns (source: ADR-0003):
#   - single autoload holding Dictionary(object_id -> ObjectState)
#   - zero scene-tree nodes of its own beyond the autoload Node itself
#   - footprint/repositionable read once from Content Data at population
#   - restore() called exactly once, only by SessionBootstrap
#   - no public runtime write API beyond restore() — every position change
#     flows through Input Abstraction's signals
extends Node

signal object_position_committed(object_id: String, position: Vector2)
signal object_wobbled(object_id: String)

var _objects: Dictionary = {} # object_id -> ObjectState
var _held_object_id: String = ""
var _grab_offset: Vector2 = Vector2.ZERO
var _held_visual_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	InputAbstraction.drag_start.connect(_on_drag_start)
	InputAbstraction.drag_move.connect(_on_drag_move)
	InputAbstraction.drag_end.connect(_on_drag_end)
	InputAbstraction.tap.connect(_on_tap)

## Called exactly once, only by SessionBootstrap — ADR-0003.
func restore(restored_blob: Dictionary) -> void:
	_objects.clear()
	_held_object_id = ""
	var objs: Array = restored_blob.get("objects", [])
	for entry in objs:
		var def: ObjectTypeDef = ContentData.get_definition(entry.get("type_id", ""))
		if def == null:
			continue
		var oid: String = entry.get("object_id", "")
		_objects[oid] = ObjectState.new(oid, def.id, entry.get("position", Vector2.ZERO), def.footprint_size, def.repositionable)

## ponytail: this slice has no real save file (see README), so the MVP's
## single rock is seeded here on the very first-ever session rather than
## restored from a blob — mirrors time-drift.md's "first session, authored
## initial state, not pre-decayed" convention.
func register_default_objects() -> void:
	if _objects.has("rock"):
		return
	var def: ObjectTypeDef = ContentData.get_definition("rock")
	if def == null:
		return
	_objects["rock"] = ObjectState.new("rock", "rock", Vector2(30, 10), def.footprint_size, def.repositionable)

func get_snapshot() -> Array:
	var out := []
	for id in _objects:
		var o: ObjectState = _objects[id]
		out.append({"object_id": o.object_id, "type_id": o.type_id, "position": o.position})
	return out

func get_object_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _objects:
		ids.append(id)
	return ids

func get_position(object_id: String) -> Vector2:
	return _objects[object_id].position if _objects.has(object_id) else Vector2.ZERO

func get_footprint(object_id: String) -> float:
	return _objects[object_id].footprint_size if _objects.has(object_id) else 0.0

## Live/committed position for rendering — reflects the in-progress drag
## position while HELD, the committed position otherwise.
func get_visual_position(object_id: String) -> Vector2:
	if object_id == _held_object_id:
		return _held_visual_pos
	return get_position(object_id)

## object-placement.md Core Rule "is_within_any_footprint iterates the
## registry internally" — keeps footprint_size private to this system.
func is_within_any_footprint(point: Vector2) -> bool:
	for id in _objects:
		var o: ObjectState = _objects[id]
		if ObjectPlacementMath.footprint_hit(point, o.position, o.footprint_size):
			return true
	return false

func _find_hit_object(point: Vector2) -> String:
	for id in _objects:
		var o: ObjectState = _objects[id]
		if o.repositionable and ObjectPlacementMath.footprint_hit(point, o.position, o.footprint_size):
			return id
	return ""

func _on_drag_start(position: Vector2, _device_id: int) -> void:
	if _held_object_id != "":
		return # Core Rule 5 — only one object held at a time.
	var hit_id := _find_hit_object(position)
	if hit_id == "":
		return # Core Rule 6 — passes through untouched.
	_held_object_id = hit_id
	var obj: ObjectState = _objects[hit_id]
	_grab_offset = position - obj.position
	_held_visual_pos = obj.position

func _on_drag_move(position: Vector2, _delta: Vector2, _device_id: int) -> void:
	if _held_object_id == "":
		return
	_held_visual_pos = ObjectPlacementMath.drag_follow_position(position, _grab_offset)

func _on_drag_end(position: Vector2, _delta: Vector2, canceled: bool, _device_id: int) -> void:
	if _held_object_id == "":
		return
	var obj: ObjectState = _objects[_held_object_id]
	var pending := ObjectPlacementMath.drag_follow_position(position, _grab_offset)
	var commit := false
	if not canceled and ObjectPlacementMath.in_bounds(pending, obj.footprint_size):
		commit = true
		for other_id in _objects:
			if other_id == _held_object_id:
				continue
			var other: ObjectState = _objects[other_id]
			if not ObjectPlacementMath.no_overlap(pending, obj.footprint_size, other.position, other.footprint_size):
				commit = false
				break
	if commit:
		obj.position = pending
		object_position_committed.emit(_held_object_id, obj.position)
	# else: gentle snap-back — obj.position (the last committed value) was
	# never touched, only _held_visual_pos was; releasing _held_object_id
	# below makes get_visual_position() fall back to it automatically.
	_held_object_id = ""

func _on_tap(position: Vector2, _device_id: int) -> void:
	var hit_id := _find_hit_object(position)
	if hit_id != "":
		object_wobbled.emit(hit_id) # Core Rule 7 — non-committal wobble ack.
