# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# CreatureTypeDef — content-data.md Core Rule 5. `spawn_conditions` itself is
# NOT stored here: the GDD explicitly leaves its authoring/evaluation an
# implementation concern owned by Ecosystem Simulation ("how this expression
# is authored and evaluated is... not specified here"). This slice hardcodes
# the two MVP creatures' concrete conditions directly in EcosystemFormulas,
# matching the GDD's own worked formulas (Snail/Moth tables in
# ecosystem-simulation.md Formulas). `required_ids` is still authored here —
# it's ContentData's own spawn_reference_validity input, independent of how
# the expression itself is evaluated.
extends Resource
class_name CreatureTypeDef

@export var id: String = ""
@export var display_name: String = ""
## Every plant-type/creature-type id spawn_conditions references — see class
## comment above and content-data.md Formulas "spawn_reference_validity".
@export var required_ids: Array[String] = []
@export var movement_speed: float = 6.0
@export var pause_duration_min: float = 2.0
@export var pause_duration_max: float = 5.0
@export var visual_ref: String = ""
