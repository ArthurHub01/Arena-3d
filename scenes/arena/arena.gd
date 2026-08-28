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
var players_by_id: Dictionary = {}

func _ready() -> void:
	winner_label.hide()
	if NetworkState.is_host:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(NetworkState.PORT, NetworkState.MAX_PLAYERS)
		if err != OK:
			winner_label.text = "Falha ao hospedar (erro %d)" % err
			winner_label.show()
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_spawn_player(1, spawn_p1.global_position, true)
	else:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(NetworkState.host_ip, NetworkState.PORT)
		if err != OK:
			winner_label.text = "Falha ao conectar (erro %d)" % err
			winner_label.show()
			return
		multiplayer.multiplayer_peer = peer

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawn_player(id, spawn_p2.global_position, false)
	_spawn_player_rpc.rpc_id(id, 1, spawn_p1.global_position, true)
	_spawn_player_rpc.rpc_id(id, id, spawn_p2.global_position, false)

func _on_peer_disconnected(id: int) -> void:
	if players_by_id.has(id):
		players_by_id[id].queue_free()
		players_by_id.erase(id)

@rpc("any_peer", "reliable")
func _spawn_player_rpc(id: int, spawn_position: Vector3, is_first: bool) -> void:
	_spawn_player(id, spawn_position, is_first)

func _spawn_player(id: int, spawn_position: Vector3, is_first: bool) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	add_child(player)
	player.global_position = spawn_position
	player.is_local_player = (id == multiplayer.get_unique_id())
	player.set_multiplayer_authority(id)
	players_by_id[id] = player
	var hp_bar := hp_bar_p1 if is_first else hp_bar_p2
	_wire_player(player, hp_bar)
	if is_first:
		player_one = player
	else:
		player_two = player

func _wire_player(player: Player, hp_bar: ProgressBar) -> void:
	hp_bar.value = player.stats.current_hp
	player.damaged.connect(func(current_hp): hp_bar.value = current_hp)
	player.died.connect(_check_round_end)

func _check_round_end() -> void:
	if round_over:
		return
	if player_one == null or player_two == null:
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
	if not multiplayer.is_server():
		return
	_do_reset.rpc()

@rpc("call_local", "reliable")
func _do_reset() -> void:
	player_one.reset_player(spawn_p1.global_position)
	player_two.reset_player(spawn_p2.global_position)
	round_over = false
	winner_label.hide()
