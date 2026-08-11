## Pure, static formula functions for Ecosystem Simulation.
##
## Lives in a separate, non-autoload script per ADR-0004 Decision §2 and the
## registered `testable_pure_formula_placement` convention
## (docs/registry/architecture.yaml) — unit tests call these functions
## directly with injected values, never loading the EcosystemSimulation
## autoload's live registry/signal-connect code just to reach a formula.
##
## Scope note: only moisture_after_watering() is implemented so far. This is
## the first real code in src/ — written to stand up the GUT/CI pipeline
## (2026-08-11 gate-check finding: tests/unit/ had no example test, and the
## CI workflow had no step installing GUT at all). The remaining formulas
## ADR-0004 specifies (moisture_after_tick_decay, light_level_tick,
## plant_growth_outcome, should_trigger_detail, spawn_departure_debounce)
## are intentionally NOT implemented here — that's real system work that
## belongs to a dev-story against an actual epic, not a CI-verification task.
class_name EcosystemFormulas
extends RefCounted


## Formula (a) from ecosystem-simulation.md Formulas — live watering, fires
## immediately on apply_watering(), decoupled from ticks:
##   jar_moisture' = clamp(jar_moisture + watering_amount, 0, 100)
static func moisture_after_watering(jar_moisture: int, watering_amount: int) -> int:
	return clampi(jar_moisture + watering_amount, 0, 100)
