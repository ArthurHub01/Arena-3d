class_name DodgeData
extends Resource

@export var dodge_name: String = "Dodge"
@export var element: ElementType.Type = ElementType.Type.NONE
@export var dodge_index: int = 1

## Directional dodges (index 1-4) only.
@export var dash_speed: float = 18.0
@export var dash_duration: float = 0.18
@export var iframe_duration: float = 0.2

## Block (index 5) only.
@export var is_block: bool = false
@export var block_damage_reduction: float = 0.7
