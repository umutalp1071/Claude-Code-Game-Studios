# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# DiscoverySurfacing — autoload, Feature/Presentation-adjacent layer.
# Follows control-manifest.md Feature Layer Required Patterns (source:
# ADR-0010):
#   - holds _queue: Array[DiscoveryItem], _state: State {IDLE, REVEALING},
#     _focused_elapsed: float
#   - two entry points only, called exclusively by SessionBootstrap:
#     capture_pre_batch_snapshot() (step 5), compute_delta() (step 9)
#   - queue ordering/timing formulas live in DiscoverySurfacingMath
#   - focus-pause timing connects directly to Window signals in its own
#     _ready(), independent of Input Abstraction
#   - _process(delta) only advances _focused_elapsed while
#     REVEALING and not paused
#
# DELIBERATE SIMPLIFICATION: Core Rule 4a's pause-on-backgrounding is real
# (connects Window.focus_exited/focus_entered directly, per the rule), but
# this slice's simplified persistence means there is no real background/
# resume Web lifecycle to exercise it against beyond the editor window
# losing OS focus — see README.
extends Node

enum State { IDLE, REVEALING }

var _state: int = State.IDLE
var _queue: Array[DiscoveryItem] = []
var _focused_elapsed: float = 0.0
var _paused: bool = false

var _pre_batch_plant_stages: Dictionary = {}
var _pre_batch_creature_present: Dictionary = {}

func _ready() -> void:
	get_window().focus_exited.connect(func() -> void: _paused = true)
	get_window().focus_entered.connect(func() -> void: _paused = false)

## Called by SessionBootstrap, step 5 — before TimeDrift's catch-up batch runs.
func capture_pre_batch_snapshot() -> void:
	_pre_batch_plant_stages.clear()
	for id in EcosystemSimulation.get_plant_ids():
		_pre_batch_plant_stages[id] = EcosystemSimulation.get_plant_growth_stage(id)
	_pre_batch_creature_present.clear()
	for id in EcosystemSimulation.get_creature_ids():
		_pre_batch_creature_present[id] = EcosystemSimulation.get_creature_state(id) == CreatureState.Presence.PRESENT

## Called by SessionBootstrap, step 9 — after TimeDrift reaches ACTIVE.
## Core Rule 2: no item for "nothing changed." Core Rule 2a: the full_cycle
## exception (ABSENT at both ends, but present at some point mid-batch)
## still produces a Departure item.
func compute_delta() -> void:
	var items: Array[DiscoveryItem] = []
	var registration_index: Dictionary = {}
	var idx := 0

	for id in EcosystemSimulation.get_plant_ids():
		registration_index[id] = idx
		idx += 1
		var before: int = _pre_batch_plant_stages.get(id, 0)
		var after := EcosystemSimulation.get_plant_growth_stage(id)
		if before != after:
			var item := DiscoveryItem.new(DiscoveryItem.Category.GROWTH, id, Vector2.ZERO)
			item.from_stage = before
			item.to_stage = after
			items.append(item)

	for id in EcosystemSimulation.get_creature_ids():
		registration_index[id] = idx
		idx += 1
		var before: bool = _pre_batch_creature_present.get(id, false)
		var after: bool = EcosystemSimulation.get_creature_state(id) == CreatureState.Presence.PRESENT
		var pos := EcosystemSimulation.get_creature_last_known_position(id)
		if not before and after:
			items.append(DiscoveryItem.new(DiscoveryItem.Category.ARRIVAL, id, pos))
		elif before and not after:
			items.append(DiscoveryItem.new(DiscoveryItem.Category.DEPARTURE, id, pos))
		elif not before and not after and EcosystemSimulation.get_was_present_during_batch(id):
			var item := DiscoveryItem.new(DiscoveryItem.Category.DEPARTURE, id, pos)
			item.full_cycle = true
			items.append(item)

	_queue = DiscoverySurfacingMath.sort_queue(items, registration_index)
	_focused_elapsed = 0.0
	_state = State.REVEALING if _queue.size() > 0 else State.IDLE

func _process(delta: float) -> void:
	if _state != State.REVEALING or _paused:
		return
	_focused_elapsed += delta
	var total := DiscoverySurfacingMath.total_reveal_duration(_queue.size())
	if _focused_elapsed >= total:
		_state = State.IDLE

## Per-element cues only, never a global banner — Core Rule 5/9. Never
## blocks gameplay input; this system is read-only from the outside.
func get_active_items() -> Array[DiscoveryItem]:
	var active: Array[DiscoveryItem] = []
	if _state != State.REVEALING:
		return active
	for i in range(_queue.size()):
		if DiscoverySurfacingMath.is_visible(i, _focused_elapsed):
			active.append(_queue[i])
	return active
