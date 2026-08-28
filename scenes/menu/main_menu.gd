extends Control
class_name MainMenu

const PORT := 8910
const ARENA_SCENE_PATH := "res://scenes/arena/Arena.tscn"

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var ip_input: LineEdit = $VBoxContainer/HBoxContainer/IpInput
@onready var join_button: Button = $VBoxContainer/HBoxContainer/JoinButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed() -> void:
	status_label.text = "Hospedando na porta %d..." % PORT
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)

func _on_join_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Digite o IP do host."
		return
	status_label.text = "Conectando a %s..." % ip
	get_tree().change_scene_to_file(ARENA_SCENE_PATH)
