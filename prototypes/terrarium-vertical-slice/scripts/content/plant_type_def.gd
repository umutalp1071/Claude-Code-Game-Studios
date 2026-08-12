# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# PlantTypeDef — content-data.md Core Rule 4. Foundation-layer, read-only by
# convention (Content Data GDD Core Rule 2 — no runtime-enforced guard).
extends Resource
class_name PlantTypeDef

@export var id: String = ""
@export var display_name: String = ""
@export var moisture_tolerance_min: int = 0
@export var moisture_tolerance_max: int = 100
@export var light_tolerance_min: int = 0
@export var light_tolerance_max: int = 100
@export var growth_rate: int = 1
@export var decay_rate: int = 1
## carpet | clump | climb — see content-data.md Core Rule 4
@export var growth_pattern: String = "carpet"
## Ordered visual references, index 0..max_stage. max_stage is DERIVED
## (visual_stages.size() - 1), never stored separately — content-data.md
## Core Rule 4.
@export var visual_stages: Array[String] = []
