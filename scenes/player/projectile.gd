extends Area3D
class_name Projectile

var speed: float = 15.0
var damage: int = 10
var element: ElementType.Type = ElementType.Type.NONE
var knockback_force: float = 0.0
var stagger_duration: float = 0.0
var shooter: Player = null
var lifetime: float = 3.0
var vfx_key: String = ""

## True for the purely-visual replica spawned on the other peer's screen
## (see Player._show_projectile_vfx) — flies and looks identical, but
## never applies damage/knockback/special-meter itself since the real
## projectile on the caster's machine already did that via take_damage's RPC.
var cosmetic_only: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail_particles: GPUParticles3D = $TrailParticles

func _ready() -> void:
	if cosmetic_only:
		monitoring = false
	else:
		body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	_apply_element_look()
	if vfx_key == "earth_basic":
		_rise_from_ground()

## Bursts up out of the ground into its normal flight height instead of
## just appearing in the air — the forward flight in _physics_process runs
## unaffected since it never touches the Y axis on flat throws.
func _rise_from_ground() -> void:
	var target_y := global_position.y
	global_position.y -= 1.1
	var tree := get_tree()
	if tree == null:
		global_position.y = target_y
		return
	VFX._spawn_particle_layer(get_parent(), Vector3(global_position.x, target_y - 1.0, global_position.z), ElementType.get_color(ElementType.Type.EARTH).darkened(0.2), {
		"amount": 10, "lifetime": 0.4, "explosiveness": 1.0,
		"mesh_radius": 0.07, "energy": 0.4, "start_alpha": 0.55,
		"spread": 100.0, "velocity_min": 0.7, "velocity_max": 1.6,
		"gravity": Vector3(0, -1.0, 0), "scale_min": 0.6, "scale_max": 1.2,
	})
	var tween := tree.create_tween()
	tween.tween_property(self, "global_position:y", target_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A stony javelin assembled from jagged rock shards (see AbilityVFX's
## chunk helpers) instead of a single smooth mesh, tapering to a point in
## the travel direction (local -Z).
func _build_earth_spike(color: Color) -> void:
	mesh_instance.visible = false
	var chunk_specs := [
		[Vector3(0.0, 0.0, 0.4), 0.3], [Vector3(0.12, 0.06, 0.22), 0.28], [Vector3(-0.12, -0.05, 0.2), 0.28],
		[Vector3(0.09, -0.08, 0.0), 0.25], [Vector3(-0.1, 0.07, -0.02), 0.24], [Vector3(0.0, 0.0, -0.22), 0.2],
		[Vector3(0.05, 0.03, -0.42), 0.15], [Vector3(-0.04, -0.03, -0.44), 0.14], [Vector3(0.0, 0.01, -0.6), 0.09],
	]
	for spec in chunk_specs:
		var local_pos: Vector3 = spec[0]
		var size: float = spec[1]
		var chunk := MeshInstance3D.new()
		var mesh := AbilityVFX._random_rock_mesh(size)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = AbilityVFX._random_rock_color(color)
		mat.roughness = 0.9
		mat.metallic = 0.0
		mesh.material = mat
		chunk.mesh = mesh
		chunk.position = local_pos
		chunk.rotation = Vector3(randf_range(-0.5, 0.5), randf_range(-PI, PI), randf_range(-0.5, 0.5))
		add_child(chunk)

func _apply_element_look() -> void:
	var color := ElementType.get_color(element)

	if vfx_key == "earth_basic":
		_build_earth_spike(color)
		var dust_mesh := SphereMesh.new()
		dust_mesh.radius = 0.09
		dust_mesh.height = 0.18
		var dust_mat := StandardMaterial3D.new()
		dust_mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
		dust_mat.roughness = 1.0
		dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dust_mesh.material = dust_mat
		trail_particles.draw_pass_1 = dust_mesh
		trail_particles.amount = 22
		trail_particles.lifetime = 0.5
		var dust_process := ParticleProcessMaterial.new()
		dust_process.direction = Vector3(0, 0, 1)
		dust_process.spread = 20.0
		dust_process.initial_velocity_min = 0.3
		dust_process.initial_velocity_max = 1.0
		dust_process.gravity = Vector3(0, -0.6, 0)
		dust_process.scale_min = 0.5
		dust_process.scale_max = 1.4
		var dust_fade := Gradient.new()
		dust_fade.set_color(0, Color(color.r, color.g, color.b, 0.5))
		dust_fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
		var dust_fade_tex := GradientTexture1D.new()
		dust_fade_tex.gradient = dust_fade
		dust_process.color_ramp = dust_fade_tex
		trail_particles.process_material = dust_process
		trail_particles.emitting = true
		return

	if vfx_key == "water_h2":
		var ice_color := Color(0.75, 0.92, 1.0, 1.0)
		var ice_mesh := PrismMesh.new()
		ice_mesh.size = Vector3(0.22, 0.4, 0.22)
		var ice_mat := StandardMaterial3D.new()
		ice_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ice_mat.albedo_color = Color(ice_color.r, ice_color.g, ice_color.b, 0.85)
		ice_mat.emission_enabled = true
		ice_mat.emission = ice_color
		ice_mat.emission_energy_multiplier = 2.0
		ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ice_mesh.material = ice_mat
		mesh_instance.mesh = ice_mesh
		mesh_instance.rotation_degrees.x = 90.0
		color = ice_color
	else:
		var mat: StandardMaterial3D = mesh_instance.mesh.material.duplicate()
		mat.albedo_color = color
		mat.emission = color
		mesh_instance.mesh.material = mat

	var trail_mesh := SphereMesh.new()
	trail_mesh.radius = 0.05
	trail_mesh.height = 0.1
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.albedo_color = color
	trail_mat.emission_enabled = true
	trail_mat.emission = color
	trail_mat.emission_energy_multiplier = 2.0
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mesh.material = trail_mat
	trail_particles.draw_pass_1 = trail_mesh

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3.ZERO
	process_mat.spread = 10.0
	process_mat.initial_velocity_min = 0.0
	process_mat.initial_velocity_max = 0.3
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.3
	process_mat.scale_max = 0.7
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, 0.9))
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	process_mat.color_ramp = fade_tex
	trail_particles.process_material = process_mat
	trail_particles.emitting = true

func _physics_process(delta: float) -> void:
	global_translate(-global_transform.basis.z * speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and body != shooter:
		var dir := -global_transform.basis.z
		body.take_damage(damage, element, dir, knockback_force, stagger_duration)
		if vfx_key == "water_h2":
			var ice_color := Color(0.75, 0.92, 1.0)
			VFX.spawn_light_flash(get_parent(), global_position, ice_color, 4.0, 2.5, 0.2)
			AbilityVFX._spawn_ring(get_parent(), AbilityVFX._ground(global_position), ice_color, 1.4, 0.3, 0.15)
		if is_instance_valid(shooter):
			shooter._gain_special_meter()
		queue_free()
