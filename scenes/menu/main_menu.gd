extends Control
class_name MainMenu

const PORT := 8910
const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"
const SETTINGS_PATH := "user://player_settings.cfg"
const DEFAULT_NICKNAME := "Jogador"

@onready var host_button: Button = $CenterContainer/Columns/LeftPanel/LeftContent/HostButton
@onready var vs_computer_button: Button = $CenterContainer/Columns/LeftPanel/LeftContent/VsComputerButton
@onready var ip_input: LineEdit = $CenterContainer/Columns/LeftPanel/LeftContent/HBoxContainer/IpInput
@onready var join_button: Button = $CenterContainer/Columns/LeftPanel/LeftContent/HBoxContainer/JoinButton
@onready var status_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/StatusLabel
@onready var version_label: Label = $VersionLabel
@onready var update_button: Button = $CenterContainer/Columns/LeftPanel/LeftContent/UpdateButton
@onready var title_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/Title
@onready var eyebrow_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/Eyebrow
@onready var divider_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/Divider
@onready var element_label: Label = $CenterContainer/Columns/RightPanel/RightContent/ElementEyebrow
@onready var element_name_label: Label = $CenterContainer/Columns/RightPanel/RightContent/ElementNameLabel
@onready var element_list: VBoxContainer = $CenterContainer/Columns/RightPanel/RightContent/ElementScroll/ElementList
@onready var discovered_list: VBoxContainer = $CenterContainer/Columns/LeftPanel/LeftContent/DiscoveredList
@onready var nickname_input: LineEdit = $CenterContainer/Columns/LeftPanel/LeftContent/NicknameInput

var updater: GameUpdater
var pending_download_url := ""
var element_buttons: Dictionary = {}
var lan_discovery: LanDiscovery

func _ready() -> void:
	theme = UiTheme.build()
	title_label.add_theme_font_override("font", UiTheme.title_font())
	eyebrow_label.add_theme_font_override("font", UiTheme.eyebrow_font())
	divider_label.add_theme_font_override("font", UiTheme.eyebrow_font())
	element_label.add_theme_font_override("font", UiTheme.eyebrow_font())

	host_button.pressed.connect(_on_host_pressed)
	vs_computer_button.pressed.connect(_on_vs_computer_pressed)
	join_button.pressed.connect(_on_join_pressed)
	update_button.pressed.connect(_on_update_button_pressed)

	_setup_element_buttons()
	_load_nickname()
	nickname_input.text_changed.connect(_on_nickname_changed)

	version_label.text = GameVersion.DISPLAY_NAME
	get_window().title = "Arena 3D - %s" % GameVersion.DISPLAY_NAME

	updater = GameUpdater.new()
	add_child(updater)
	updater.up_to_date.connect(_on_up_to_date)
	updater.update_available.connect(_on_update_available)
	updater.check_failed.connect(_on_check_failed)
	updater.download_complete.connect(_on_download_complete)
	updater.download_failed.connect(_on_download_failed)

	update_button.text = "Verificar atualização"
	updater.check_for_update()

	lan_discovery = LanDiscovery.new()
	add_child(lan_discovery)
	lan_discovery.host_found.connect(_on_lan_host_found)
	lan_discovery.start_listening()

	_check_cmdline_autoconnect()

func _on_lan_host_found(ip: String) -> void:
	var button := Button.new()
	button.text = "Entrar na partida encontrada (%s)" % ip
	button.pressed.connect(func():
		ip_input.text = ip
		_on_join_pressed()
	)
	discovered_list.add_child(button)

func _setup_element_buttons() -> void:
	for button in element_list.get_children():
		var row: HBoxContainer = button.get_node("Row")
		var icon: ElementIcon = row.get_node("ElementIcon")
		var name_label: Label = row.get_node("Name")
		element_buttons[icon.element] = {"icon": icon, "label": name_label}
		button.pressed.connect(_on_element_selected.bind(icon.element))
	_on_element_selected(NetworkState.selected_element)

func _on_element_selected(element: ElementType.Type) -> void:
	NetworkState.selected_element = element
	for el in element_buttons:
		var entry: Dictionary = element_buttons[el]
		var is_selected: bool = (el == element)
		entry["icon"].selected = is_selected
		entry["label"].add_theme_color_override("font_color", UiTheme.COL_SIGNAL if is_selected else UiTheme.COL_INK_DIM)
	element_name_label.text = ElementType.display_name(element)

func _load_nickname() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		NetworkState.player_nickname = config.get_value("player", "nickname", DEFAULT_NICKNAME)
	nickname_input.text = NetworkState.player_nickname

func _on_nickname_changed(new_text: String) -> void:
	var nickname := new_text.strip_edges()
	if nickname.is_empty():
		nickname = DEFAULT_NICKNAME
	NetworkState.player_nickname = nickname
	var config := ConfigFile.new()
	config.set_value("player", "nickname", nickname)
	config.save(SETTINGS_PATH)

func _check_cmdline_autoconnect() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--element="):
			var name := arg.split("=", true, 1)[1]
			match name:
				"water": _on_element_selected(ElementType.Type.WATER)
				"earth": _on_element_selected(ElementType.Type.EARTH)
				"air": _on_element_selected(ElementType.Type.AIR)
				"lightning": _on_element_selected(ElementType.Type.LIGHTNING)
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto-host":
			_on_host_pressed()
		elif arg.begins_with("--auto-join="):
			ip_input.text = arg.split("=", true, 1)[1]
			_on_join_pressed()
		elif arg == "--vs-computer":
			_on_vs_computer_pressed()

func _on_host_pressed() -> void:
	NetworkState.is_host = true
	status_label.text = "Hospedando na porta %d..." % PORT
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_vs_computer_pressed() -> void:
	NetworkState.vs_computer = true
	NetworkState.is_host = false
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Digite o IP do host."
		return
	NetworkState.is_host = false
	NetworkState.host_ip = ip
	status_label.text = "Conectando a %s..." % ip
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_update_button_pressed() -> void:
	if not pending_download_url.is_empty():
		update_button.disabled = true
		update_button.text = "Baixando..."
		updater.download_update(pending_download_url)
	else:
		update_button.disabled = true
		update_button.text = "Verificando..."
		updater.check_for_update()

func _on_up_to_date() -> void:
	update_button.text = "Já atualizado"
	update_button.disabled = true

func _on_update_available(version: String, download_url: String) -> void:
	pending_download_url = download_url
	update_button.text = "Atualizar (%s disponível)" % version
	update_button.disabled = false

func _on_check_failed(reason: String) -> void:
	update_button.text = "Verificar atualização"
	update_button.disabled = false
	status_label.text = reason

func _on_download_complete() -> void:
	status_label.text = "Atualização baixada, reiniciando..."
	updater.apply_update_and_restart()

func _on_download_failed(reason: String) -> void:
	update_button.text = "Tentar atualizar de novo"
	update_button.disabled = false
	status_label.text = reason
