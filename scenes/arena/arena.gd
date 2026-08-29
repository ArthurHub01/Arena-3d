extends Node3D
class_name Arena

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")

@onready var spawn_p1: Marker3D = $SpawnP1
@onready var spawn_p2: Marker3D = $SpawnP2
@onready var hud_root: Control = $HUD/HUDRoot
@onready var hp_bar_p1: ChevronBar = $HUD/HUDRoot/HpGroupP1/HpBarWrapP1/HpBarP1
@onready var hp_bar_p2: ChevronBar = $HUD/HUDRoot/HpGroupP2/HpBarWrapP2/HpBarP2
@onready var special_bar_p1: ChevronBar = $HUD/HUDRoot/SpecialBarP1
@onready var special_bar_p2: ChevronBar = $HUD/HUDRoot/SpecialBarP2
@onready var hp_label_p1: Label = $HUD/HUDRoot/HpGroupP1/HpLabelP1
@onready var hp_label_p2: Label = $HUD/HUDRoot/HpGroupP2/HpLabelP2
@onready var element_label_p1: Label = $HUD/HUDRoot/ElementLabelP1
@onready var element_label_p2: Label = $HUD/HUDRoot/ElementLabelP2
@onready var winner_label: Label = $HUD/HUDRoot/WinnerLabel
@onready var score_label: Label = $HUD/HUDRoot/ScoreLabel
@onready var restart_button: Button = $HUD/HUDRoot/RestartButton
@onready var menu_text_button: Button = $HUD/HUDRoot/MenuTextButton
@onready var menu_button: Button = $HUD/HUDRoot/MenuButton
@onready var waiting_label: Label = $HUD/HUDRoot/WaitingLabel
@onready var loading_overlay: Control = $HUD/LoadingOverlay
@onready var loading_tip_label: Label = $HUD/LoadingOverlay/CenterContainer/Panel/Content/TipLabel
@onready var loading_countdown_label: Label = $HUD/LoadingOverlay/CenterContainer/Panel/Content/CountdownLabel

const MAIN_MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"
const ROUNDS_TO_WIN := 2
const ROUND_TRANSITION_DELAY := 2.5
const PRE_MATCH_DURATION := 4.0
const PRE_MATCH_TIP_INTERVAL := 2.0
const PRE_MATCH_TIPS := [
	"Mova-se com WASD e pule com Espaço.",
	"Clique esquerdo ataca. Segure W/A/S/D e clique de novo em seguida para um golpe combinado mais forte.",
	"Clique direito com uma direção segurada esquiva com um instante de invencibilidade.",
	"Segure o clique direito sem direção para bloquear e reduzir o dano recebido.",
	"O clique do meio lança o especial quando a barrinha dourada estiver cheia.",
	"O nome do elemento de cada jogador aparece abaixo da barra de vida.",
	"Ataques de Raio têm um pequeno atraso — desvie se movendo para o lado!",
	"Vença 2 rodadas para ganhar a partida.",
	"Depois do combate, aperte R para jogar novamente rapidinho.",
]

var round_manager: RoundManager = RoundManager.new()
var player_one: Player
var player_two: Player
var round_over: bool = false
var match_over: bool = false
var pending_round_continue: bool = false
var match_score_p1: int = 0
var match_score_p2: int = 0
var players_by_id: Dictionary = {}
var lan_discovery: LanDiscovery

func _ready() -> void:
	hud_root.theme = UiTheme.build()
	winner_label.hide()
	waiting_label.hide()
	restart_button.hide()
	menu_text_button.hide()
	menu_button.pressed.connect(_on_menu_button_pressed)
	menu_text_button.pressed.connect(_on_menu_button_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
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
		_spawn_player(1, spawn_p1.global_position, true, NetworkState.selected_element, NetworkState.player_nickname)
		waiting_label.show()
		lan_discovery = LanDiscovery.new()
		add_child(lan_discovery)
		lan_discovery.start_broadcasting()
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
	_spawn_player(1, spawn_p1.global_position, true, NetworkState.selected_element, NetworkState.player_nickname)
	var ai_elements := [ElementType.Type.FIRE, ElementType.Type.WATER, ElementType.Type.EARTH, ElementType.Type.AIR, ElementType.Type.LIGHTNING]
	ai_elements.erase(NetworkState.selected_element)
	var ai_element: ElementType.Type = ai_elements[randi() % ai_elements.size()] if not ai_elements.is_empty() else NetworkState.selected_element
	_spawn_player(2, spawn_p2.global_position, false, ai_element, "CPU")
	player_two.is_ai_controlled = true

func _on_connected_to_server() -> void:
	_report_element.rpc_id(1, NetworkState.selected_element, NetworkState.player_nickname)

@rpc("any_peer", "reliable")
func _report_element(element: ElementType.Type, nickname: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_spawn_player(sender_id, spawn_p2.global_position, false, element, nickname)
	_spawn_player_rpc.rpc_id(sender_id, 1, spawn_p1.global_position, true, NetworkState.selected_element, NetworkState.player_nickname)
	_spawn_player_rpc.rpc_id(sender_id, sender_id, spawn_p2.global_position, false, element, nickname)

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
func _spawn_player_rpc(id: int, spawn_position: Vector3, is_first: bool, element: ElementType.Type, nickname: String) -> void:
	_spawn_player(id, spawn_position, is_first, element, nickname)

func _spawn_player(id: int, spawn_position: Vector3, is_first: bool, element: ElementType.Type, nickname: String) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	player.is_local_player = (id == multiplayer.get_unique_id())
	player.set_element(element)
	player.set_nickname(nickname)
	add_child(player)
	player.global_position = spawn_position
	player.set_multiplayer_authority(id)
	players_by_id[id] = player
	var hp_bar := hp_bar_p1 if is_first else hp_bar_p2
	var hp_label := hp_label_p1 if is_first else hp_label_p2
	var special_bar := special_bar_p1 if is_first else special_bar_p2
	_wire_player(player, hp_bar, hp_label, special_bar)
	var element_label := element_label_p1 if is_first else element_label_p2
	element_label.text = ElementType.display_name(element)
	if is_first:
		player_one = player
	else:
		player_two = player

	if player_one != null and player_two != null:
		player_one.opponent = player_two
		player_two.opponent = player_one
		waiting_label.hide()
		if lan_discovery:
			lan_discovery.stop()
		_begin_pre_match_sequence()

func _begin_pre_match_sequence() -> void:
	var tips := PRE_MATCH_TIPS.duplicate()
	tips.shuffle()
	var tip_index := 0
	loading_tip_label.text = tips[tip_index]
	var remaining := PRE_MATCH_DURATION
	loading_countdown_label.text = "Começando em %d..." % int(ceil(remaining))
	loading_overlay.show()

	while remaining > 0.0:
		var step: float = min(PRE_MATCH_TIP_INTERVAL, remaining)
		await get_tree().create_timer(step).timeout
		remaining -= step
		if not is_instance_valid(self):
			return
		loading_countdown_label.text = "Começando em %d..." % int(ceil(remaining))
		if remaining > 0.0:
			tip_index = (tip_index + 1) % tips.size()
			loading_tip_label.text = tips[tip_index]

	loading_overlay.hide()
	if is_instance_valid(player_one):
		player_one.match_active = true
	if is_instance_valid(player_two):
		player_two.match_active = true

func _wire_player(player: Player, hp_bar: ChevronBar, hp_label: Label, special_bar: ChevronBar) -> void:
	hp_bar.max_value = player.stats.max_hp
	hp_bar.value = player.stats.current_hp
	hp_label.text = "%d/%d" % [player.stats.current_hp, player.stats.max_hp]
	player.damaged.connect(func(current_hp):
		hp_bar.value = current_hp
		hp_label.text = "%d/%d" % [current_hp, player.stats.max_hp]
	)
	player.died.connect(_check_round_end)
	special_bar.max_value = 100.0
	special_bar.value = player.special_meter
	player.special_meter_changed.connect(func(current, max_value):
		special_bar.max_value = max_value
		special_bar.value = current
	)

func _check_round_end() -> void:
	if round_over or match_over:
		return
	if player_one == null or player_two == null:
		return
	var winner := round_manager.get_winner(player_one.stats, player_two.stats)
	if winner == "":
		return
	round_over = true

	if winner == "draw":
		winner_label.text = "Empate na rodada! Próxima rodada..."
		winner_label.show()
		_schedule_round_continue()
		return

	if winner == "p1":
		match_score_p1 += 1
	else:
		match_score_p2 += 1
	score_label.text = "%d - %d" % [match_score_p1, match_score_p2]

	if match_score_p1 >= ROUNDS_TO_WIN or match_score_p2 >= ROUNDS_TO_WIN:
		_end_match(winner)
	else:
		var round_winner_name := "Jogador 1" if winner == "p1" else "Jogador 2"
		winner_label.text = "%s venceu a rodada! Placar %d - %d" % [round_winner_name, match_score_p1, match_score_p2]
		winner_label.show()
		_schedule_round_continue()

func _end_match(winner: String) -> void:
	match_over = true
	var local_side := "p1" if (is_instance_valid(player_one) and player_one.is_local_player) else "p2"
	if winner == local_side:
		winner_label.text = "VITÓRIA! Placar final %d - %d" % [match_score_p1, match_score_p2]
	else:
		winner_label.text = "DERROTA. Placar final %d - %d" % [match_score_p1, match_score_p2]
	winner_label.show()
	restart_button.show()
	menu_text_button.show()

func _schedule_round_continue() -> void:
	pending_round_continue = true
	get_tree().create_timer(ROUND_TRANSITION_DELAY).timeout.connect(func():
		if not pending_round_continue or match_over:
			return
		pending_round_continue = false
		_reset_round()
	)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("reset_round"):
		return
	if match_over:
		_restart_match()
	elif round_over:
		_reset_round()

func _reset_round() -> void:
	pending_round_continue = false
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

func _on_restart_pressed() -> void:
	_restart_match()

func _restart_match() -> void:
	pending_round_continue = false
	if multiplayer.has_multiplayer_peer():
		if not multiplayer.is_server():
			return
		_do_restart_match.rpc()
	else:
		_do_restart_match()

@rpc("call_local", "reliable")
func _do_restart_match() -> void:
	match_score_p1 = 0
	match_score_p2 = 0
	match_over = false
	round_over = false
	score_label.text = "0 - 0"
	restart_button.hide()
	menu_text_button.hide()
	winner_label.hide()
	player_one.reset_player(spawn_p1.global_position)
	player_two.reset_player(spawn_p2.global_position)

func _on_menu_button_pressed() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	NetworkState.vs_computer = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
