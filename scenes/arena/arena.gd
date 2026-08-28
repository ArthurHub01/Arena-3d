extends Node3D
class_name Arena

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")

@onready var spawn_p1: Marker3D = $SpawnP1
@onready var spawn_p2: Marker3D = $SpawnP2
@onready var hp_bar_p1: ProgressBar = $HUD/HpBarP1
@onready var hp_bar_p2: ProgressBar = $HUD/HpBarP2
@onready var winner_label: Label = $HUD/WinnerLabel

var round_manager: RoundManager = RoundManager.new()
var player_one: Player
var player_two: Player
var round_over: bool = false

func _ready() -> void:
	winner_label.hide()
	_spawn_local_test_players()

func _spawn_local_test_players() -> void:
	player_one = PLAYER_SCENE.instantiate()
	add_child(player_one)
	player_one.global_position = spawn_p1.global_position
	player_one.is_local_player = true

	player_two = PLAYER_SCENE.instantiate()
	add_child(player_two)
	player_two.global_position = spawn_p2.global_position
	player_two.is_local_player = false

	_wire_player(player_one, hp_bar_p1)
	_wire_player(player_two, hp_bar_p2)

func _wire_player(player: Player, hp_bar: ProgressBar) -> void:
	hp_bar.value = player.stats.current_hp
	player.damaged.connect(func(current_hp): hp_bar.value = current_hp)
	player.died.connect(_check_round_end)

func _check_round_end() -> void:
	if round_over:
		return
	var winner := round_manager.get_winner(player_one.stats, player_two.stats)
	if winner == "":
		return
	round_over = true
	if winner == "draw":
		winner_label.text = "Empate! Aperte R para reiniciar"
	else:
		winner_label.text = ("Jogador 1" if winner == "p1" else "Jogador 2") + " venceu! Aperte R para reiniciar"
	winner_label.show()

func _unhandled_input(event: InputEvent) -> void:
	if round_over and event.is_action_pressed("reset_round"):
		_reset_round()

func _reset_round() -> void:
	player_one.reset_player(spawn_p1.global_position)
	player_two.reset_player(spawn_p2.global_position)
	round_over = false
	winner_label.hide()
