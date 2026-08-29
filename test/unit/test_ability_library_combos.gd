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

func test_special_deals_double_basic_damage():
	var base = AbilityLibrary.get_basic_ability(ElementType.Type.EARTH)
	var special = AbilityLibrary.get_special(ElementType.Type.EARTH)
	assert_eq(special.damage, base.damage * 2)
	assert_eq(special.combo_slot, 0)
