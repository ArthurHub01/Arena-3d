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

## Spawns a brief burst of particles at the caster's hand when an ability
## is launched (melee swing, projectile release, hitscan cast).
static func spawn_cast_burst(parent: Node, world_position: Vector3, forward: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	parent.add_child(particles)
	particles.global_position = world_position

	particles.amount = 18
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.emitting = true

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = forward
	process_mat.spread = 25.0
	process_mat.initial_velocity_min = 1.5
	process_mat.initial_velocity_max = 3.5
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.5
	process_mat.scale_max = 1.1
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

## Draws a short-lived glowing beam between two world points (hitscan attacks).
static func spawn_beam(parent: Node, from: Vector3, to: Vector3, color: Color, thickness: float = 0.035, duration: float = 0.18) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var mesh_inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness
	mesh.bottom_radius = thickness
	mesh.height = length
	mesh.radial_segments = 8

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	mesh_inst.mesh = mesh

	parent.add_child(mesh_inst)
	mesh_inst.look_at_from_position((from + to) / 2.0, to, Vector3.UP)
	mesh_inst.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	var tree := parent.get_tree()
	if tree:
		var tween := tree.create_tween()
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, duration)
		tween.tween_callback(mesh_inst.queue_free)
