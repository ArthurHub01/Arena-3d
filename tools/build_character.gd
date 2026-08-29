@tool
extends SceneTree

const RAW := "res://assets/models/mixamo_raw/"
const OUT_SCENE := "res://assets/models/human_character_rigged.tscn"

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

func _initialize() -> void:
	var char_scene: PackedScene = load(RAW + "character.fbx")
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

	var packed := PackedScene.new()
	var result := packed.pack(char_inst)
	if result != OK:
		push_error("pack failed: %s" % result)
		quit(1)
		return
	var save_result := ResourceSaver.save(packed, OUT_SCENE)
	if save_result != OK:
		push_error("save failed: %s" % save_result)
		quit(1)
		return
	print("Saved ", OUT_SCENE)
	char_inst.free()
	quit()
