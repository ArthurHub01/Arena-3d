extends Area3D
class_name Projectile

var speed: float = 15.0
var damage: int = 10
var element: ElementType.Type = ElementType.Type.NONE
var knockback_force: float = 0.0
var stagger_duration: float = 0.0
var shooter: Player = null
var lifetime: float = 3.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var trail_particles: GPUParticles3D = $TrailParticles

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	_apply_element_look()

func _apply_element_look() -> void:
	var color := ElementType.get_color(element)

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
		if is_instance_valid(shooter):
			shooter._gain_special_meter()
		queue_free()
