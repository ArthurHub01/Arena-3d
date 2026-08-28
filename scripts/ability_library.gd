class_name AbilityLibrary
extends RefCounted

const BASIC_ABILITY_PATHS := {
	ElementType.Type.FIRE: "res://assets/abilities/fire_basic.tres",
	ElementType.Type.WATER: "res://assets/abilities/water_basic.tres",
	ElementType.Type.EARTH: "res://assets/abilities/earth_basic.tres",
	ElementType.Type.AIR: "res://assets/abilities/air_basic.tres",
	ElementType.Type.LIGHTNING: "res://assets/abilities/lightning_basic.tres",
}

static func get_basic_ability(element: ElementType.Type) -> AbilityData:
	var path: String = BASIC_ABILITY_PATHS.get(element, BASIC_ABILITY_PATHS[ElementType.Type.FIRE])
	return load(path)
