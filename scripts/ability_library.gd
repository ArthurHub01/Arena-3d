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
	data.cast_time = 0.2 if power_level == 1 else 0.3
	data.vfx_key = base.vfx_key
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
		data.cooldown = 0.6
	return data

static func _base_ability(name: String, element: ElementType.Type, delivery: AbilityData.Delivery, anim_name: String) -> AbilityData:
	var data := AbilityData.new()
	data.ability_name = "%s — %s" % [ElementType.display_name(element), name]
	data.element = element
	data.delivery = delivery
	data.anim_name = anim_name
	return data

static func get_habilidade_1(element: ElementType.Type) -> AbilityData:
	var anim := get_basic_ability(element).anim_name
	match element:
		ElementType.Type.FIRE:
			var data := _base_ability("Onda de Calor", element, AbilityData.Delivery.CONE, anim)
			data.damage = 10
			data.cone_angle_degrees = 70.0
			data.aoe_range = 4.0
			data.burn_damage_per_tick = 3
			data.burn_ticks = 4
			data.burn_tick_interval = 1.0
			data.knockback_force = 4.0
			data.cooldown = 1.6
			data.cast_time = 0.3
			data.vfx_key = "fire_h1"
			return data
		ElementType.Type.WATER:
			var data := _base_ability("Escudo de Névoa", element, AbilityData.Delivery.SELF_BUFF, anim)
			data.self_buff_type = "shield"
			data.self_buff_duration = 3.0
			data.cooldown = 4.0
			data.cast_time = 0.0
			data.vfx_key = "water_h1"
			return data
		ElementType.Type.EARTH:
			var data := _base_ability("Parede de Pedra", element, AbilityData.Delivery.WALL, anim)
			data.wall_duration = 6.0
			data.cooldown = 5.0
			data.cast_time = 0.0
			data.vfx_key = "earth_h1"
			return data
		ElementType.Type.AIR:
			var data := _base_ability("Impulso de Ar", element, AbilityData.Delivery.SELF_BUFF, anim)
			data.self_buff_type = "extra_dash"
			data.cooldown = 1.5
			data.cast_time = 0.0
			data.vfx_key = "air_h1"
			return data
		ElementType.Type.LIGHTNING:
			var data := _base_ability("Teletransporte Elétrico", element, AbilityData.Delivery.TELEPORT_STRIKE, anim)
			data.damage = 8
			data.stagger_duration = 0.3
			data.knockback_force = 3.0
			data.cooldown = 2.5
			data.cast_time = 0.3
			data.vfx_key = "lightning_h1"
			return data
		_:
			return get_basic_ability(element)

static func get_habilidade_2(element: ElementType.Type) -> AbilityData:
	var anim := get_basic_ability(element).anim_name
	match element:
		ElementType.Type.FIRE:
			var data := _base_ability("Investida Flamejante", element, AbilityData.Delivery.MELEE, anim)
			data.damage = 14
			data.melee_range = 1.8
			data.breaks_guard = true
			data.knockback_force = 8.0
			data.cooldown = 1.8
			data.cast_time = 0.35
			data.vfx_key = "fire_h2"
			return data
		ElementType.Type.WATER:
			var data := _base_ability("Prisão de Gelo", element, AbilityData.Delivery.PROJECTILE, anim)
			data.damage = 10
			data.stagger_duration = 2.2
			data.projectile_speed = 16.0
			data.projectile_lifetime = 2.5
			data.cooldown = 1.8
			data.cast_time = 0.35
			data.vfx_key = "water_h2"
			return data
		ElementType.Type.EARTH:
			var data := _base_ability("Terremoto", element, AbilityData.Delivery.LINE, anim)
			data.damage = 18
			data.aoe_range = 6.0
			data.stagger_duration = 1.5
			data.knockback_force = 5.0
			data.cooldown = 2.0
			data.cast_time = 0.35
			data.vfx_key = "earth_h2"
			return data
		ElementType.Type.AIR:
			var data := _base_ability("Tornado Repulsor", element, AbilityData.Delivery.SELF_BUFF, anim)
			data.self_buff_type = "repulse_aura"
			data.self_buff_value = 8.0
			data.self_buff_duration = 3.0
			data.cooldown = 4.0
			data.cast_time = 0.0
			data.vfx_key = "air_h2"
			return data
		ElementType.Type.LIGHTNING:
			var data := _base_ability("Corrente de Choque", element, AbilityData.Delivery.HITSCAN, anim)
			data.damage = 8
			data.stagger_duration = 0.6
			data.hitscan_range = 25.0
			data.cooldown = 1.4
			data.cast_time = 0.35
			data.vfx_key = "lightning_h2"
			return data
		_:
			return get_basic_ability(element)

static func get_special(element: ElementType.Type) -> AbilityData:
	var anim := get_basic_ability(element).anim_name
	match element:
		ElementType.Type.FIRE:
			var data := _base_ability("Impacto de Meteoro", element, AbilityData.Delivery.CONE, anim)
			data.damage = 30
			data.cone_angle_degrees = 360.0
			data.aoe_range = 5.0
			data.knockback_force = 10.0
			data.cast_time = 0.5
			data.vfx_key = "fire_supreme"
			return data
		ElementType.Type.WATER:
			var data := _base_ability("Tsunami", element, AbilityData.Delivery.LINE, anim)
			data.damage = 28
			data.aoe_range = 8.0
			data.pull_instead_of_push = true
			data.knockback_force = 6.0
			data.cast_time = 0.5
			data.vfx_key = "water_supreme"
			return data
		ElementType.Type.EARTH:
			var data := _base_ability("Armadura de Rocha", element, AbilityData.Delivery.SELF_BUFF, anim)
			data.self_buff_type = "damage_mitigation"
			data.self_buff_value = 0.8
			data.self_buff_duration = 4.0
			data.cast_time = 0.0
			data.vfx_key = "earth_supreme"
			return data
		ElementType.Type.AIR:
			var data := _base_ability("Furacão Aprisionador", element, AbilityData.Delivery.CONE, anim)
			data.damage = 20
			data.cone_angle_degrees = 360.0
			data.aoe_range = 6.0
			data.pull_instead_of_push = true
			data.stagger_duration = 2.0
			data.knockback_force = 3.0
			data.cast_time = 0.5
			data.vfx_key = "air_supreme"
			return data
		ElementType.Type.LIGHTNING:
			var data := _base_ability("Tempestade de Raios", element, AbilityData.Delivery.MULTI_HITSCAN, anim)
			data.damage = 12
			data.multi_hit_count = 3
			data.multi_hit_interval = 0.3
			data.hitscan_range = 25.0
			data.cast_time = 0.35
			data.vfx_key = "lightning_supreme"
			return data
		_:
			return get_basic_ability(element)
