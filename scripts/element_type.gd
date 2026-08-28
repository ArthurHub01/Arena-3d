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

static func get_color(type: Type) -> Color:
	match type:
		Type.FIRE:
			return Color(0.95, 0.38, 0.12, 1.0)
		Type.WATER:
			return Color(0.28, 0.56, 0.92, 1.0)
		Type.EARTH:
			return Color(0.55, 0.40, 0.20, 1.0)
		Type.AIR:
			return Color(0.80, 0.88, 0.86, 1.0)
		Type.LIGHTNING:
			return Color(0.95, 0.85, 0.28, 1.0)
		_:
			return Color(0.7, 0.7, 0.7, 1.0)

static func display_name(type: Type) -> String:
	match type:
		Type.FIRE: return "Fogo"
		Type.WATER: return "Água"
		Type.EARTH: return "Terra"
		Type.AIR: return "Ar"
		Type.LIGHTNING: return "Raios"
		_: return "Nenhum"
