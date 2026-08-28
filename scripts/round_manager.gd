class_name RoundManager
extends RefCounted

func get_winner(p1_stats: CombatStats, p2_stats: CombatStats) -> String:
	var p1_dead = p1_stats.is_dead()
	var p2_dead = p2_stats.is_dead()
	if p1_dead and p2_dead:
		return "draw"
	if p2_dead:
		return "p1"
	if p1_dead:
		return "p2"
	return ""
