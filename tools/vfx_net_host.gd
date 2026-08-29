extends Node3D

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")

var arena: Node3D
var shots_dir := "user://vfx_shots_host"
var sequence: Array = []
var seq_index: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	NetworkState.is_host = true
	NetworkState.vs_computer = false
	arena = ARENA_SCENE.instantiate()
	add_child(arena)

	var elements := [ElementType.Type.FIRE, ElementType.Type.WATER, ElementType.Type.EARTH, ElementType.Type.AIR, ElementType.Type.LIGHTNING]
	for element in elements:
		sequence.append(["H1", element])
	for element in elements:
		sequence.append(["H2", element])
	for element in elements:
		sequence.append(["Suprema", element])

	_wait_for_match()

func _wait_for_match() -> void:
	if not is_instance_valid(arena) or not is_instance_valid(arena.player_one) or not is_instance_valid(arena.player_two) or not arena.player_one.match_active:
		await get_tree().create_timer(0.3).timeout
		_wait_for_match()
		return
	print("HOST: match active, starting showcase.")
	_next_ability()

func _next_ability() -> void:
	if seq_index >= sequence.size():
		print("HOST_SHOWCASE_DONE")
		await get_tree().create_timer(2.0).timeout
		get_tree().quit()
		return
	var entry = sequence[seq_index]
	var tier: String = entry[0]
	var element = entry[1]
	var p1: Player = arena.player_one
	var p2: Player = arena.player_two
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		await get_tree().create_timer(0.2).timeout
		_next_ability()
		return

	p1.set_element(element)
	p1.global_position = p2.global_position + Vector3(0, 0, 4)
	p1.look_at(Vector3(p2.global_position.x, p1.global_position.y, p2.global_position.z), Vector3.UP)
	p1.stats.reset()
	p2.stats.reset()

	var ability: AbilityData
	match tier:
		"H1": ability = AbilityLibrary.get_habilidade_1(element)
		"H2": ability = AbilityLibrary.get_habilidade_2(element)
		"Suprema": ability = AbilityLibrary.get_special(element)

	print("HOST firing ", tier, " ", ElementType.display_name(element), " (", ability.vfx_key, ")")
	p1._fire_attack(ability)

	await get_tree().create_timer(0.35).timeout
	var img := get_viewport().get_texture().get_image()
	var fname := "%s/%02d_%s_%s.png" % [shots_dir, seq_index, tier, ElementType.display_name(element)]
	img.save_png(fname)

	seq_index += 1
	await get_tree().create_timer(0.8).timeout
	_next_ability()
