extends GutTest

func test_no_winner_when_both_alive():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	assert_eq(rm.get_winner(p1, p2), "")

func test_p1_wins_when_p2_dead():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	p2.apply_damage(100)
	assert_eq(rm.get_winner(p1, p2), "p1")

func test_p2_wins_when_p1_dead():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	p1.apply_damage(100)
	assert_eq(rm.get_winner(p1, p2), "p2")

func test_draw_when_both_dead():
	var rm = RoundManager.new()
	var p1 = CombatStats.new()
	var p2 = CombatStats.new()
	p1.apply_damage(100)
	p2.apply_damage(100)
	assert_eq(rm.get_winner(p1, p2), "draw")
