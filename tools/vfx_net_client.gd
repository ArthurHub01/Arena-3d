extends Node3D

const ARENA_SCENE := preload("res://scenes/arena/Arena.tscn")

var arena: Node3D
var shots_dir := "user://vfx_shots_client"
var shot_index: int = 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(shots_dir)
	NetworkState.is_host = false
	NetworkState.host_ip = "127.0.0.1"
	NetworkState.vs_computer = false
	arena = ARENA_SCENE.instantiate()
	add_child(arena)
	_snapshot_loop()

func _snapshot_loop() -> void:
	await get_tree().create_timer(0.5).timeout
	while shot_index < 40:
		var img := get_viewport().get_texture().get_image()
		var fname := "%s/%03d.png" % [shots_dir, shot_index]
		img.save_png(fname)
		shot_index += 1
		await get_tree().create_timer(0.5).timeout
	print("CLIENT_SHOWCASE_DONE")
	get_tree().quit()
