# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# SessionBootstrap — autoload, LAST in Project Settings autoload order
# (source: ADR-0002). Drives the fixed call order:
#   PersistenceSave.load()/get_restored_blob()
#     -> EcosystemSimulation.restore()/ObjectPlacement.restore()
#     -> DiscoverySurfacing.capture_pre_batch_snapshot()
#     -> TimeDrift.run_catchup_and_activate()
#     -> CreatureBehavior.resolve_session_start()
#     -> DiscoverySurfacing.compute_delta()
# _ready() contains only this documented sequence — no unrelated startup
# logic (ADR-0002 Required Pattern).
#
# DELIBERATE SIMPLIFICATION (see README "Persistence simplification"): step
# 1 (PersistenceSave.load()) does not exist in this slice — there is no
# real ADR-0005 localStorage/JS-mirror implementation. In its place, an
# in-memory `_blob` Dictionary stands in for "the restored save," and the
# debug "Advance Session" control (wired from the Main scene) calls
# advance_session(elapsed_seconds), which snapshots current live state into
# `_blob` and re-runs the exact same restore -> catch-up -> compute_delta
# sequence a real session boundary would run — just with elapsed_seconds
# supplied directly instead of a real wall-clock/localStorage round trip.
extends Node

var _blob: Dictionary = {}
var _has_seeded_objects: bool = false

func _ready() -> void:
	start_session(0.0)

func start_session(elapsed_seconds: float) -> void:
	EcosystemSimulation.restore(_blob)
	ObjectPlacement.restore(_blob)
	if not _has_seeded_objects:
		ObjectPlacement.register_default_objects()
		_has_seeded_objects = true
	DiscoverySurfacing.capture_pre_batch_snapshot()
	TimeDrift.run_catchup_and_activate(elapsed_seconds)
	CreatureBehavior.resolve_session_start()
	DiscoverySurfacing.compute_delta()

## Debug-only entry point (see Main scene's "Advance Session" buttons).
## Stands in for a real session boundary (tab close + reopen after
## elapsed_seconds of real time) using in-memory state only.
func advance_session(elapsed_seconds: float) -> void:
	_blob = EcosystemSimulation.get_snapshot()
	_blob["objects"] = ObjectPlacement.get_snapshot()
	start_session(elapsed_seconds)
