extends GutTest

func test_attack_slot_map_pairs_match_spec():
	assert_eq(Player.ATTACK_SLOT_MAP["W"], {"first": 1, "second": 2})
	assert_eq(Player.ATTACK_SLOT_MAP["A"], {"first": 3, "second": 4})
	assert_eq(Player.ATTACK_SLOT_MAP["S"], {"first": 5, "second": 6})
	assert_eq(Player.ATTACK_SLOT_MAP["D"], {"first": 7, "second": 8})
	assert_eq(Player.ATTACK_SLOT_MAP[""], {"first": 9, "second": 10})

func test_dodge_index_map_matches_spec():
	assert_eq(Player.DODGE_INDEX_MAP["W"], 1)
	assert_eq(Player.DODGE_INDEX_MAP["A"], 2)
	assert_eq(Player.DODGE_INDEX_MAP["S"], 3)
	assert_eq(Player.DODGE_INDEX_MAP["D"], 4)
