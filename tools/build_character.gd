@tool
extends SceneTree

const RAW := "res://assets/models/mixamo_raw/"
const DEFAULT_BODY := "character.fbx"
const DEFAULT_OUT_SCENE := "res://assets/models/human_character_rigged.tscn"

const ANIM_SOURCES := {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"jump": "jump",
	"death": "death",
	"punch": "punch",
	"hit_front": "hit_front",
	"hit_back": "hit_back",
	"hit_left": "hit_left",
	"hit_right": "hit_right",
	"cast_fire": "cast_fire",
	"cast_water": "cast_water",
	"cast_earth": "cast_earth",
	"cast_air": "cast_air",
	"cast_lightning": "cast_lightning",
}

func _load_clip(file_key: String) -> Animation:
	var scene: PackedScene = load(RAW + file_key + ".fbx")
	var inst := scene.instantiate()
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var lib: AnimationLibrary = ap.get_animation_library("")
	var anim_name: String = "mixamo_com" if lib.has_animation("mixamo_com") else lib.get_animation_list()[0]
	var anim: Animation = lib.get_animation(anim_name).duplicate(true)
	inst.free()
	return anim

func _fix_ownership(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		if child.owner != owner_node:
			child.owner = owner_node
		_fix_ownership(child, owner_node)

func _get_arg(prefix: String, default_value: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.substr(prefix.length())
	return default_value

func _initialize() -> void:
	var body_file := _get_arg("--body=", DEFAULT_BODY)
	var out_scene := _get_arg("--out=", DEFAULT_OUT_SCENE)

	var char_scene: PackedScene = load(RAW + body_file)
	var char_inst := char_scene.instantiate()

	var ap: AnimationPlayer = char_inst.get_node("AnimationPlayer")
	var new_lib := AnimationLibrary.new()
	for out_name in ANIM_SOURCES.keys():
		var clip: Animation = _load_clip(ANIM_SOURCES[out_name])
		clip.resource_name = out_name
		if out_name in ["idle", "cast_fire", "cast_water", "cast_earth", "cast_air", "cast_lightning", "punch", "hit_front", "hit_back", "hit_left", "hit_right", "death"]:
			clip.loop_mode = Animation.LOOP_NONE if out_name != "idle" else Animation.LOOP_LINEAR
		if out_name in ["walk", "run"]:
			clip.loop_mode = Animation.LOOP_LINEAR
		new_lib.add_animation(out_name, clip)
		print("added animation: ", out_name, " length=", clip.length)

	ap.remove_animation_library("")
	ap.add_animation_library("", new_lib)
	ap.autoplay = "idle"

	_fix_ownership(char_inst, char_inst)

	var packed := PackedScene.new()
	var result := packed.pack(char_inst)
	if result != OK:
		push_error("pack failed: %s" % result)
		quit(1)
		return
	var save_result := ResourceSaver.save(packed, out_scene)
	if save_result != OK:
		push_error("save failed: %s" % save_result)
		quit(1)
		return
	print("Saved ", out_scene)
	char_inst.free()
	quit()
