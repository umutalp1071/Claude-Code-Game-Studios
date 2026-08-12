# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# AmbientAudio — autoload, Presentation layer. SCOPE CUT (see README
# "Ambient Audio simplification"): only Core Rule 1's base loop (starts at
# session-ACTIVE, stops at INACTIVE) is implemented. The watering-swell and
# discovery-bed-shift reactive layers (ambient-audio.md Core Rules 2-3) are
# skipped entirely, not stubbed — ambient-audio.md's own dependency list
# already states the base loop must degrade gracefully with all of those
# absent, so this is a documented-safe subset, not a broken partial system.
#
# Follows the one control-manifest.md Presentation Layer rule this reduced
# scope still exercises (source: ADR-0012): one real scene-tree node
# (AudioStreamPlayer), created programmatically in _ready(); session state
# detected by polling TimeDrift.get_state() every _process() frame with
# edge detection; INACTIVE->ACTIVE plays unconditionally, ACTIVE->INACTIVE
# stops immediately with no fade-out.
extends Node

var _player: AudioStreamPlayer
var _was_active: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.bus = "Master"
	# ponytail: no ambient loop asset ships with this slice (see README) —
	# _player.stream stays null. play()/stop() below are still exercised on
	# every session-state edge so the code path is real; drop an
	# AudioStream (e.g. an .ogg) onto _player.stream (or load one here via
	# preload()) to make this audible.

func _process(_delta: float) -> void:
	var active := TimeDrift.get_state() == TimeDrift.SessionState.ACTIVE
	if active and not _was_active:
		if _player.stream != null:
			_player.play()
	elif not active and _was_active:
		_player.stop()
	_was_active = active
