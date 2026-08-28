class_name VFX
extends RefCounted

## Spawns a one-shot colored particle burst at world_position, parented
## under parent, and frees itself once the burst finishes.
static func spawn_impact(parent: Node, world_position: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	parent.add_child(particles)
	particles.global_position = world_position

	particles.amount = 24
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.emitting = true

	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 180.0
	process_mat.initial_velocity_min = 2.0
	process_mat.initial_velocity_max = 4.5
	process_mat.gravity = Vector3(0, -4.0, 0)
	process_mat.scale_min = 0.4
	process_mat.scale_max = 1.0
	process_mat.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, 1.0))
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	process_mat.color_ramp = fade_tex
	particles.process_material = process_mat

	var tree := parent.get_tree()
	if tree:
		tree.create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)
