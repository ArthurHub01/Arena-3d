extends Node

const PORT := 8910
const MAX_PLAYERS := 2
const SETTINGS_PATH := "user://player_settings.cfg"
const DEFAULT_NICKNAME := "Jogador"
const DEFAULT_COLOR := Color(0.837638, 0.528975, 0.496618, 1)

var is_host: bool = false
var host_ip: String = ""
var selected_element: ElementType.Type = ElementType.Type.FIRE
var vs_computer: bool = false
var player_nickname: String = DEFAULT_NICKNAME
var player_color: Color = DEFAULT_COLOR
var selected_character_id: String = "default"

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		player_nickname = config.get_value("player", "nickname", DEFAULT_NICKNAME)
		player_color = config.get_value("player", "color", DEFAULT_COLOR)
		selected_character_id = config.get_value("player", "character_id", "default")

func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("player", "nickname", player_nickname)
	config.set_value("player", "color", player_color)
	config.set_value("player", "character_id", selected_character_id)
	config.save(SETTINGS_PATH)
