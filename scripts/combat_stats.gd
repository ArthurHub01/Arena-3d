class_name CombatStats
extends RefCounted

var max_hp: int = 100
var current_hp: int

func _init() -> void:
	current_hp = max_hp

func apply_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)

func is_dead() -> bool:
	return current_hp <= 0

func reset() -> void:
	current_hp = max_hp
