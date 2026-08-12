# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# DiscoverySurfacingMath — separate non-autoload pure script — source:
# ADR-0010. Queue ordering/timing formulas from discovery-surfacing.md
# Formulas/Core Rule 8. sort_queue()'s comparator takes registration_index
# as a caller-supplied parameter, never looks it up internally (ADR-0010
# Required Pattern).
extends RefCounted
class_name DiscoverySurfacingMath

const PACING_DELAY := 4.0        # recommended: 4.0s
const CUE_FADE_DURATION := 6.0   # recommended: 6.0s — must stay > PACING_DELAY

static func activation_time(index: int, pacing_delay: float = PACING_DELAY) -> float:
	return index * pacing_delay

static func fade_end_time(index: int, pacing_delay: float = PACING_DELAY, cue_fade_duration: float = CUE_FADE_DURATION) -> float:
	return activation_time(index, pacing_delay) + cue_fade_duration

static func total_reveal_duration(n: int, pacing_delay: float = PACING_DELAY, cue_fade_duration: float = CUE_FADE_DURATION) -> float:
	if n <= 0:
		return 0.0
	return (n - 1) * pacing_delay + cue_fade_duration

static func is_visible(index: int, elapsed: float, pacing_delay: float = PACING_DELAY, cue_fade_duration: float = CUE_FADE_DURATION) -> bool:
	var t0 := activation_time(index, pacing_delay)
	var t1 := fade_end_time(index, pacing_delay, cue_fade_duration)
	return elapsed >= t0 and elapsed < t1

## Core Rule 8 — Growth -> Departure -> Detail Event -> Arrival.
static func category_tier(category: int) -> int:
	match category:
		DiscoveryItem.Category.GROWTH:
			return 0
		DiscoveryItem.Category.DEPARTURE:
			return 1
		DiscoveryItem.Category.DETAIL_EVENT:
			return 2
		DiscoveryItem.Category.ARRIVAL:
			return 3
		_:
			return 99

## Deterministic queue order: tier ascending, then registration_index
## ascending within a tier. registration_index is supplied by the caller
## (EcosystemSimulation's registration order), never derived here.
static func sort_queue(items: Array[DiscoveryItem], registration_index: Dictionary) -> Array[DiscoveryItem]:
	var sorted_items: Array[DiscoveryItem] = items.duplicate()
	sorted_items.sort_custom(func(a: DiscoveryItem, b: DiscoveryItem) -> bool:
		var ta := category_tier(a.category)
		var tb := category_tier(b.category)
		if ta != tb:
			return ta < tb
		var ra: int = registration_index.get(a.target_id, 0)
		var rb: int = registration_index.get(b.target_id, 0)
		return ra < rb
	)
	return sorted_items
