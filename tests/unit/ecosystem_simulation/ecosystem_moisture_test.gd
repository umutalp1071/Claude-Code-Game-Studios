extends GutTest

## Unit tests for EcosystemFormulas.moisture_after_watering() — the pure
## watering formula locked in ecosystem-simulation.md Formulas (a) and
## ADR-0004 Decision §2. First real test in this project: proves the
## GUT/CI pipeline is actually wired, per the 2026-08-11 gate-check finding
## that tests/unit/ contained no example test and CI had no GUT-install step.
##
## EcosystemFormulas is referenced unqualified below — its own
## `class_name EcosystemFormulas` (ecosystem_formulas.gd) already makes it
## globally available; a local preload/const under the same name would
## shadow that global class_name and risks a redeclaration error under
## Godot 4.7's stricter type checking.


func test_watering_raises_moisture_immediately() -> void:
	# Arrange
	var jar_moisture := 50
	var watering_amount := 25

	# Act
	var result := EcosystemFormulas.moisture_after_watering(jar_moisture, watering_amount)

	# Assert
	assert_eq(result, 75)


func test_watering_clamps_at_moisture_ceiling() -> void:
	# Arrange — a jar already near-saturated, watered past the 0-100 range
	var jar_moisture := 90
	var watering_amount := 25

	# Act
	var result := EcosystemFormulas.moisture_after_watering(jar_moisture, watering_amount)

	# Assert — clamp(115, 0, 100) never overshoots 100
	assert_eq(result, 100)


func test_watering_amount_zero_is_a_no_op() -> void:
	# Arrange
	var jar_moisture := 42
	var watering_amount := 0

	# Act
	var result := EcosystemFormulas.moisture_after_watering(jar_moisture, watering_amount)

	# Assert
	assert_eq(result, 42)
