class_name CharacterLibrary
extends RefCounted

const MODELS := {
	"default": {"display_name": "Padrão", "scene_path": "res://assets/models/human_character_rigged.tscn"},
	"knight": {"display_name": "Cavaleiro", "scene_path": "res://assets/models/human_character_knight_rigged.tscn"},
	"paladin": {"display_name": "Paladino", "scene_path": "res://assets/models/human_character_paladin_rigged.tscn"},
	"ch24": {"display_name": "Guerreiro", "scene_path": "res://assets/models/human_character_ch24_rigged.tscn"},
}

static func ids() -> Array:
	return MODELS.keys()

static func display_name(id: String) -> String:
	var entry: Dictionary = MODELS.get(id, MODELS["default"])
	return entry["display_name"]

static func get_scene(id: String) -> PackedScene:
	var entry: Dictionary = MODELS.get(id, MODELS["default"])
	return load(entry["scene_path"])
