class_name AbilityData
extends Resource

enum Delivery {
	MELEE,
	PROJECTILE,
}

@export var ability_name: String = "Ability"
@export var element: ElementType.Type = ElementType.Type.NONE
@export var damage: int = 10
@export var cooldown: float = 1.0
@export var delivery: Delivery = Delivery.MELEE
@export var anim_name: String = ""

## MELEE only: radius of the hit check around MeleeHitPoint.
@export var melee_range: float = 1.0

## PROJECTILE only: travel speed and lifetime before despawning.
@export var projectile_speed: float = 15.0
@export var projectile_lifetime: float = 3.0
