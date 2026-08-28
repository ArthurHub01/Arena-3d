class_name ElementType
extends RefCounted

enum Type {
	NONE,
	FIRE,
	WATER,
	EARTH,
	AIR,
	LIGHTNING,
}

static func display_name(type: Type) -> String:
	match type:
		Type.FIRE: return "Fogo"
		Type.WATER: return "Água"
		Type.EARTH: return "Terra"
		Type.AIR: return "Ar"
		Type.LIGHTNING: return "Raios"
		_: return "Nenhum"
