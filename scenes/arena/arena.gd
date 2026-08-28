extends Node3D
class_name Arena

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")

@onready var spawn_p1: Marker3D = $SpawnP1
@onready var spawn_p2: Marker3D = $SpawnP2
@onready var hud_root: Control = $HUD/HUDRoot
@onready var hp_bar_p1: ChevronBar = $HUD/HUDRoot/HpGroupP1/HpBarWrapP1/HpBarP1
@onready var hp_bar_p2: ChevronBar = $HUD/HUDRoot/HpGroupP2/HpBarWrapP2/HpBarP2
@onready var hp_label_p1: Label = $HUD/HUDRoot/HpGroupP1/HpLabelP1
@onready var hp_label_p2: Label = $HUD/HUDRoot/HpGroupP2/HpLabelP2
@onready var element_label_p1: Label = $HUD/HUDRoot/ElementLabelP1
@onready var element_label_p2: Label = $HUD/HUDRoot/ElementLabelP2
@onready var winner_label: Label = $HUD/HUDRoot/WinnerLabel
@onready var menu_button: Button = $HUD/HUDRoot/MenuButton
@onready var waiting_label: Label = $HUD/HUDRoot/WaitingLabel

const MAIN_MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"

var round_manager: RoundManager = RoundManager.new()
var player_one: Player
var player_two: Player
var round_over: bool = false
var players_by_id: Dictionary = {}

func _ready() -> void:
	hud_root.theme = UiTheme.build()
	winner_label.hide()
	waiting_label.hide()
	menu_button.pressed.connect(_on_menu_button_pressed)
	if NetworkState.vs_computer:
		_start_vs_computer()
	elif NetworkState.is_host:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(NetworkState.PORT, NetworkState.MAX_PLAYERS)
		if err != OK:
			winner_label.text = "Falha ao hospedar (erro %d)" % err
			winner_label.show()
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_spawn_player(1, spawn_p1.global_position, true, NetworkState.selected_element)
		waiting_label.show()
	else:
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(NetworkState.host_ip, NetworkState.PORT)
		if err != OK:
			winner_label.text = "Falha ao conectar (erro %d)" % err
			winner_label.show()
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.connected_to_server.connect(_on_connected_to_server)

func _start_vs_computer() -> void:
	_spawn_player(1, spawn_p1.global_position, true, NetworkState.selected_element)
	var ai_elements := [ElementType.Type.FIRE, ElementType.Type.WATER, ElementType.Type.EARTH, ElementType.Type.AIR, ElementType.Type.LIGHTNING]
	ai_elements.erase(NetworkState.selected_element)
	var ai_element: ElementType.Type = ai_elements[randi() % ai_elements.size()] if not ai_elements.is_empty() else NetworkState.selected_element
	_spawn_player(2, spawn_p2.global_position, false, ai_element)
	player_two.is_ai_controlled = true

func _on_connected_to_server() -> void:
	_report_element.rpc_id(1, NetworkState.selected_element)

@rpc("any_peer", "reliable")
func _report_element(element: ElementType.Type) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_spawn_player(sender_id, spawn_p2.global_position, false, element)
	_spawn_player_rpc.rpc_id(sender_id, 1, spawn_p1.global_position, true, NetworkState.selected_element)
	_spawn_player_rpc.rpc_id(sender_id, sender_id, spawn_p2.global_position, false, element)

func _on_peer_disconnected(id: int) -> void:
	if players_by_id.has(id):
		var disconnected_player: Player = players_by_id[id]
		if player_one == disconnected_player:
			player_one = null
		elif player_two == disconnected_player:
			player_two = null
		if is_instance_valid(player_one):
			player_one.opponent = null
			player_one.match_active = false
		if is_instance_valid(player_two):
			player_two.opponent = null
			player_two.match_active = false
		disconnected_player.queue_free()
		players_by_id.erase(id)
		waiting_label.show()

@rpc("any_peer", "reliable")
func _spawn_player_rpc(id: int, spawn_position: Vector3, is_first: bool, element: ElementType.Type) -> void:
	_spawn_player(id, spawn_position, is_first, element)

func _spawn_player(id: int, spawn_position: Vector3, is_first: bool, element: ElementType.Type) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.is_local_player = (id == multiplayer.get_unique_id())
	player.set_element(element)
	add_child(player)
	player.global_position = spawn_position
	player.set_multiplayer_authority(id)
	players_by_id[id] = player
	var hp_bar := hp_bar_p1 if is_first else hp_bar_p2
	var hp_label := hp_label_p1 if is_first else hp_label_p2
	_wire_player(player, hp_bar, hp_label)
	var element_label := element_label_p1 if is_first else element_label_p2
	element_label.text = ElementType.display_name(element)
	if is_first:
		player_one = player
	else:
		player_two = player

	if player_one != null and player_two != null:
		player_one.opponent = player_two
		player_two.opponent = player_one
		player_one.match_active = true
		player_two.match_active = true
		waiting_label.hide()

func _wire_player(player: Player, hp_bar: ChevronBar, hp_label: Label) -> void:
	hp_bar.max_value = player.stats.max_hp
	hp_bar.value = player.stats.current_hp
	hp_label.text = "%d/%d" % [player.stats.current_hp, player.stats.max_hp]
	player.damaged.connect(func(current_hp):
		hp_bar.value = current_hp
		hp_label.text = "%d/%d" % [current_hp, player.stats.max_hp]
	)
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
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		_do_reset.rpc()
	else:
		_do_reset()

@rpc("call_local", "reliable")
func _do_reset() -> void:
	player_one.reset_player(spawn_p1.global_position)
	player_two.reset_player(spawn_p2.global_position)
	round_over = false
	winner_label.hide()

func _on_menu_button_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	NetworkState.vs_computer = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
