extends GutTest

func test_starts_at_max_hp():
	var stats = CombatStats.new()
	assert_eq(stats.current_hp, 100)

func test_apply_damage_reduces_hp():
	var stats = CombatStats.new()
	stats.apply_damage(30)
	assert_eq(stats.current_hp, 70)

func test_hp_does_not_go_below_zero():
	var stats = CombatStats.new()
	stats.apply_damage(150)
	assert_eq(stats.current_hp, 0)

func test_is_dead_when_hp_zero():
	var stats = CombatStats.new()
	stats.apply_damage(100)
	assert_true(stats.is_dead())

func test_is_dead_false_when_hp_positive():
	var stats = CombatStats.new()
	stats.apply_damage(10)
	assert_false(stats.is_dead())

func test_reset_restores_max_hp():
	var stats = CombatStats.new()
	stats.apply_damage(100)
	stats.reset()
	assert_eq(stats.current_hp, 100)
	assert_false(stats.is_dead())
