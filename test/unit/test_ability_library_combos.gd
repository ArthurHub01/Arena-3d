extends GutTest

func test_odd_attack_slots_use_base_damage():
	var base = AbilityLibrary.get_basic_ability(ElementType.Type.FIRE)
	var attack1 = AbilityLibrary.get_attack(ElementType.Type.FIRE, 1)
	assert_eq(attack1.damage, base.damage)
	assert_eq(attack1.combo_slot, 1)

func test_even_attack_slots_use_boosted_damage():
	var base = AbilityLibrary.get_basic_ability(ElementType.Type.FIRE)
	var attack2 = AbilityLibrary.get_attack(ElementType.Type.FIRE, 2)
	assert_eq(attack2.damage, int(round(base.damage * 1.4)))
	assert_eq(attack2.combo_slot, 2)

func test_attack_slots_keep_element_delivery_type():
	var base = AbilityLibrary.get_basic_ability(ElementType.Type.LIGHTNING)
	var attack7 = AbilityLibrary.get_attack(ElementType.Type.LIGHTNING, 7)
	assert_eq(attack7.delivery, base.delivery)
	assert_eq(attack7.element, ElementType.Type.LIGHTNING)

func test_dodge_indices_1_to_4_are_dashes_not_blocks():
	for i in range(1, 5):
		var dodge = AbilityLibrary.get_dodge(ElementType.Type.WATER, i)
		assert_false(dodge.is_block, "index %d should not be a block" % i)
		assert_gt(dodge.dash_speed, 0.0)

func test_dodge_index_5_is_block():
	var block = AbilityLibrary.get_dodge(ElementType.Type.WATER, 5)
	assert_true(block.is_block)
	assert_eq(block.block_damage_reduction, 0.7)

func test_special_earth_is_damage_mitigation_buff():
	var special = AbilityLibrary.get_special(ElementType.Type.EARTH)
	assert_eq(special.delivery, AbilityData.Delivery.SELF_BUFF)
	assert_eq(special.self_buff_type, "damage_mitigation")
	assert_eq(special.self_buff_value, 0.8)

func test_special_lightning_is_multi_hitscan():
	var special = AbilityLibrary.get_special(ElementType.Type.LIGHTNING)
	assert_eq(special.delivery, AbilityData.Delivery.MULTI_HITSCAN)
	assert_eq(special.multi_hit_count, 3)
	assert_eq(special.damage, 12)

func test_habilidade_1_fire_is_cone_with_burn():
	var h1 = AbilityLibrary.get_habilidade_1(ElementType.Type.FIRE)
	assert_eq(h1.delivery, AbilityData.Delivery.CONE)
	assert_eq(h1.damage, 10)
	assert_eq(h1.burn_ticks, 4)
	assert_eq(h1.burn_damage_per_tick, 3)

func test_habilidade_1_water_is_shield_self_buff():
	var h1 = AbilityLibrary.get_habilidade_1(ElementType.Type.WATER)
	assert_eq(h1.delivery, AbilityData.Delivery.SELF_BUFF)
	assert_eq(h1.self_buff_type, "shield")
	assert_eq(h1.self_buff_duration, 3.0)

func test_habilidade_1_earth_is_wall():
	var h1 = AbilityLibrary.get_habilidade_1(ElementType.Type.EARTH)
	assert_eq(h1.delivery, AbilityData.Delivery.WALL)
	assert_eq(h1.wall_duration, 6.0)

func test_habilidade_1_lightning_is_teleport_strike():
	var h1 = AbilityLibrary.get_habilidade_1(ElementType.Type.LIGHTNING)
	assert_eq(h1.delivery, AbilityData.Delivery.TELEPORT_STRIKE)
	assert_eq(h1.damage, 8)

func test_habilidade_2_fire_breaks_guard():
	var h2 = AbilityLibrary.get_habilidade_2(ElementType.Type.FIRE)
	assert_eq(h2.delivery, AbilityData.Delivery.MELEE)
	assert_true(h2.breaks_guard)
	assert_eq(h2.damage, 14)

func test_habilidade_2_water_freezes():
	var h2 = AbilityLibrary.get_habilidade_2(ElementType.Type.WATER)
	assert_eq(h2.delivery, AbilityData.Delivery.PROJECTILE)
	assert_eq(h2.stagger_duration, 2.2)

func test_habilidade_2_earth_is_line_knockdown():
	var h2 = AbilityLibrary.get_habilidade_2(ElementType.Type.EARTH)
	assert_eq(h2.delivery, AbilityData.Delivery.LINE)
	assert_eq(h2.damage, 18)
	assert_eq(h2.stagger_duration, 1.5)

func test_habilidade_2_air_is_repulse_aura():
	var h2 = AbilityLibrary.get_habilidade_2(ElementType.Type.AIR)
	assert_eq(h2.delivery, AbilityData.Delivery.SELF_BUFF)
	assert_eq(h2.self_buff_type, "repulse_aura")
	assert_eq(h2.self_buff_value, 8.0)

func test_habilidade_2_lightning_is_hitscan_stun():
	var h2 = AbilityLibrary.get_habilidade_2(ElementType.Type.LIGHTNING)
	assert_eq(h2.delivery, AbilityData.Delivery.HITSCAN)
	assert_eq(h2.stagger_duration, 0.6)
