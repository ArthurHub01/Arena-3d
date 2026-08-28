extends Control
class_name MainMenu

const PORT := 8910
const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var ip_input: LineEdit = $VBoxContainer/HBoxContainer/IpInput
@onready var join_button: Button = $VBoxContainer/HBoxContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	version_label.text = GameVersion.VERSION
	get_window().title = "Arena 3D - %s" % GameVersion.VERSION
	_check_cmdline_autoconnect()

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
