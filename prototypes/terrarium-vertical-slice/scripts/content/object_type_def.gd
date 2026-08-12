# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the calm caretaker fantasy —
# noticing what changed, tending the jar, and seeing a session boundary
# produce visible drift — within 5 minutes, without guidance?
# Date: 2026-08-12
#
# ObjectTypeDef — content-data.md Core Rule 6.
extends Resource
class_name ObjectTypeDef

@export var id: String = ""
@export var display_name: String = ""
@export var visual_ref: String = ""
@export var repositionable: bool = true
## Radius, jar-space units — object-placement.md Formulas treats this as a
## circle centered on the object's origin.
@export var footprint_size: float = 8.0
