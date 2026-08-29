extends GutTest

func test_odd_combo_slots_have_short_cast_time():
	var attack1 = AbilityLibrary.get_attack(ElementType.Type.FIRE, 1)
	assert_eq(attack1.cast_time, 0.2)

func test_even_combo_slots_have_longer_cast_time():
	var attack2 = AbilityLibrary.get_attack(ElementType.Type.FIRE, 2)
	assert_eq(attack2.cast_time, 0.3)

func test_habilidade_1_attacking_moves_have_cast_time():
	var h1 = AbilityLibrary.get_habilidade_1(ElementType.Type.FIRE)
	assert_eq(h1.cast_time, 0.3)

func test_habilidade_1_self_buff_moves_have_no_cast_time():
	var h1 = AbilityLibrary.get_habilidade_1(ElementType.Type.WATER)
	assert_eq(h1.cast_time, 0.0)

func test_suprema_attacking_moves_have_longest_cast_time():
	var special = AbilityLibrary.get_special(ElementType.Type.FIRE)
	assert_eq(special.cast_time, 0.5)

func test_suprema_self_buff_has_no_cast_time():
	var special = AbilityLibrary.get_special(ElementType.Type.EARTH)
	assert_eq(special.cast_time, 0.0)

func test_basic_ability_has_short_cast_time():
	var base = AbilityLibrary.get_basic_ability(ElementType.Type.WATER)
	assert_eq(base.cast_time, 0.15)
