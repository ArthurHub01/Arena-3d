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

func _apply_element_look() -> void:
	var color := ElementType.get_color(element)

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
