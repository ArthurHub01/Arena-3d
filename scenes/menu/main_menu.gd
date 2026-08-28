extends Control
class_name MainMenu

const PORT := 8910
const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"

@onready var host_button: Button = $CenterContainer/Panel/HostButton
@onready var ip_input: LineEdit = $CenterContainer/Panel/HBoxContainer/IpInput
@onready var join_button: Button = $CenterContainer/Panel/HBoxContainer/JoinButton
@onready var status_label: Label = $CenterContainer/Panel/StatusLabel
@onready var version_label: Label = $VersionLabel
@onready var update_button: Button = $CenterContainer/Panel/UpdateButton
@onready var title_label: Label = $CenterContainer/Panel/Title
@onready var eyebrow_label: Label = $CenterContainer/Panel/Eyebrow
@onready var divider_label: Label = $CenterContainer/Panel/Divider
@onready var element_label: Label = $CenterContainer/Panel/ElementLabel
@onready var element_name_label: Label = $CenterContainer/Panel/ElementNameLabel
@onready var element_row: HBoxContainer = $CenterContainer/Panel/ElementRow

var updater: GameUpdater
var pending_download_url := ""
var element_buttons: Dictionary = {}

func _ready() -> void:
	theme = UiTheme.build()
	title_label.add_theme_font_override("font", UiTheme.title_font())
	eyebrow_label.add_theme_font_override("font", UiTheme.eyebrow_font())
	divider_label.add_theme_font_override("font", UiTheme.eyebrow_font())
	element_label.add_theme_font_override("font", UiTheme.eyebrow_font())

	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	update_button.pressed.connect(_on_update_button_pressed)

	_setup_element_buttons()

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

	_check_cmdline_autoconnect()

func _setup_element_buttons() -> void:
	for button in element_row.get_children():
		var icon: ElementIcon = button.get_child(0)
		element_buttons[icon.element] = icon
		button.pressed.connect(_on_element_selected.bind(icon.element))
	_on_element_selected(NetworkState.selected_element)

func _on_element_selected(element: ElementType.Type) -> void:
	NetworkState.selected_element = element
	for el in element_buttons:
		element_buttons[el].selected = (el == element)
	element_name_label.text = ElementType.display_name(element)

func _check_cmdline_autoconnect() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto-host":
			_on_host_pressed()
		elif arg.begins_with("--auto-join="):
			ip_input.text = arg.split("=", true, 1)[1]
			_on_join_pressed()

func _on_host_pressed() -> void:
	NetworkState.is_host = true
	status_label.text = "Hospedando na porta %d..." % PORT
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
