# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# ContentData — autoload, Foundation layer. Follows control-manifest.md
# Foundation Layer Required Patterns (source: ADR-0001):
#   - scans each category directory, sorts paths ordinally (not uid://)
#   - loads with ResourceLoader.load(), runs definition_validity() before
#     registry admission (reject + push_warning() on failure)
#   - registry keyed by the definition's own `id`, never file path
#   - fully loaded before any other system initializes (first autoload,
#     synchronous _ready(), no await/call_deferred/Thread)
# Must be declared FIRST in Project Settings autoload order.
extends Node

const CATEGORY_DIRS: Array[String] = [
	"res://data/content/plants",
	"res://data/content/creatures",
	"res://data/content/objects",
]

# content-data.md Formulas — definition_validity constants.
const BAND_MIN_WIDTH := 15
const LIGHT_BAND_MIN_WIDTH := 15
const FOOTPRINT_MAX := 20.0
const MOVEMENT_SPEED_MAX := 50.0
const PAUSE_DURATION_MAX := 30.0
const RATE_MAX := 10
const GROWTH_PATTERNS := ["carpet", "clump", "climb"]

var _registry: Dictionary = {} # id (String) -> Resource, insertion order == sorted load order

func _ready() -> void:
	for dir_path in CATEGORY_DIRS:
		_load_category(dir_path)
	_spawn_reference_validity_fixpoint()

func get_definition(id: String) -> Resource:
	return _registry.get(id, null)

## Registry ids in sorted-load (registration) order — content-data.md Core
## Rule 7. Consumers (e.g. EcosystemSimulation) filter by type themselves.
func get_registry_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _registry.keys():
		ids.append(id)
	return ids

func _load_category(dir_path: String) -> void:
	var paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[ContentData] could not open directory: %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			paths.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort() # ordinal/case-sensitive — content-data.md Core Rule 7

	for path in paths:
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			push_warning("[ContentData] %s: failed to load" % path)
			continue
		if not res.get("id"):
			push_warning("[ContentData] %s: missing id, skipped" % path)
			continue
		if not _definition_validity(res):
			push_warning("[ContentData] %s: failed definition_validity, excluded" % res.id)
			continue
		if _registry.has(res.id):
			push_warning("[ContentData] %s: duplicate id (source: %s), first-loaded wins" % [res.id, path])
			continue
		_registry[res.id] = res

func _definition_validity(def: Resource) -> bool:
	if def is PlantTypeDef:
		return _plant_validity(def)
	if def is CreatureTypeDef:
		return _creature_validity(def)
	if def is ObjectTypeDef:
		return _object_validity(def)
	return false

func _plant_validity(d: PlantTypeDef) -> bool:
	if not (d.moisture_tolerance_min >= 0 and d.moisture_tolerance_min < d.moisture_tolerance_max and d.moisture_tolerance_max <= 100):
		return false
	if d.moisture_tolerance_max - d.moisture_tolerance_min < BAND_MIN_WIDTH:
		return false
	if not (d.light_tolerance_min >= 0 and d.light_tolerance_min < d.light_tolerance_max and d.light_tolerance_max <= 100):
		return false
	if d.light_tolerance_max - d.light_tolerance_min < LIGHT_BAND_MIN_WIDTH:
		return false
	if d.growth_rate < 0 or d.growth_rate > RATE_MAX:
		return false
	if d.decay_rate < 0 or d.decay_rate > RATE_MAX:
		return false
	if not GROWTH_PATTERNS.has(d.growth_pattern):
		return false
	if d.visual_stages.size() < 2:
		return false
	return true

func _creature_validity(d: CreatureTypeDef) -> bool:
	if d.movement_speed < 0.0 or d.movement_speed > MOVEMENT_SPEED_MAX:
		return false
	if d.pause_duration_min < 0.0 or d.pause_duration_max < 0.0:
		return false
	if d.pause_duration_min > d.pause_duration_max:
		return false
	if d.pause_duration_max > PAUSE_DURATION_MAX:
		return false
	if d.visual_ref == "":
		return false
	return true

func _object_validity(d: ObjectTypeDef) -> bool:
	if d.footprint_size <= 0.0 or d.footprint_size > FOOTPRINT_MAX:
		return false
	if d.visual_ref == "":
		return false
	return true

## content-data.md Formulas "spawn_reference_validity" — iterative fixpoint,
## excludes any CreatureTypeDef whose required_ids names a missing/excluded id.
func _spawn_reference_validity_fixpoint() -> void:
	var changed := true
	while changed:
		changed = false
		for id in _registry.keys().duplicate():
			var def: Resource = _registry[id]
			if def is CreatureTypeDef:
				for req_id in def.required_ids:
					if not _registry.has(req_id):
						push_warning("[ContentData] %s: required_id '%s' missing/excluded, excluding creature" % [id, req_id])
						_registry.erase(id)
						changed = true
						break
