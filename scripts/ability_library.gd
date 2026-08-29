class_name AbilityLibrary
extends RefCounted

const BASIC_ABILITY_PATHS := {
	ElementType.Type.FIRE: "res://assets/abilities/fire_basic.tres",
	ElementType.Type.WATER: "res://assets/abilities/water_basic.tres",
	ElementType.Type.EARTH: "res://assets/abilities/earth_basic.tres",
	ElementType.Type.AIR: "res://assets/abilities/air_basic.tres",
	ElementType.Type.LIGHTNING: "res://assets/abilities/lightning_basic.tres",
}

const ATTACK_SLOT_POWER_MULTIPLIER := {1: 1.0, 2: 1.4}

static func get_basic_ability(element: ElementType.Type) -> AbilityData:
	var path: String = BASIC_ABILITY_PATHS.get(element, BASIC_ABILITY_PATHS[ElementType.Type.FIRE])
	return load(path)

static func get_attack(element: ElementType.Type, slot: int) -> AbilityData:
	var base := get_basic_ability(element)
	var power_level: int = 2 if slot % 2 == 0 else 1
	var data := AbilityData.new()
	data.ability_name = "%s — Golpe %d" % [ElementType.display_name(element), slot]
	data.element = element
	data.damage = int(round(base.damage * ATTACK_SLOT_POWER_MULTIPLIER[power_level]))
	data.cooldown = base.cooldown
	data.delivery = base.delivery
	data.anim_name = base.anim_name
	data.melee_range = base.melee_range
	data.projectile_speed = base.projectile_speed
	data.projectile_lifetime = base.projectile_lifetime
	data.hitscan_range = base.hitscan_range
	data.hitscan_delay = base.hitscan_delay
	data.knockback_force = base.knockback_force
	data.stagger_duration = base.stagger_duration
	data.combo_slot = slot
	return data

static func get_dodge(element: ElementType.Type, index: int) -> DodgeData:
	var data := DodgeData.new()
	data.element = element
	data.dodge_index = index
	if index == 5:
		data.dodge_name = "%s — Bloqueio" % ElementType.display_name(element)
		data.is_block = true
		data.block_damage_reduction = 0.7
	else:
		data.dodge_name = "%s — Esquiva %d" % [ElementType.display_name(element), index]
		data.dash_speed = 18.0
		data.dash_duration = 0.18
		data.iframe_duration = 0.2
	return data

static func get_special(element: ElementType.Type) -> AbilityData:
	var base := get_basic_ability(element)
	var data := AbilityData.new()
	data.ability_name = "%s — Especial" % ElementType.display_name(element)
	data.element = element
	data.damage = base.damage * 2
	data.cooldown = base.cooldown
	data.delivery = base.delivery
	data.anim_name = base.anim_name
	data.melee_range = base.melee_range
	data.projectile_speed = base.projectile_speed
	data.projectile_lifetime = base.projectile_lifetime
	data.hitscan_range = base.hitscan_range
	data.hitscan_delay = base.hitscan_delay
	data.knockback_force = base.knockback_force * 1.5
	data.stagger_duration = base.stagger_duration
	data.combo_slot = 0
	return data
