class_name VFX
extends RefCounted

const HITSTOP_STRENGTH := 0.04
const HITSTOP_DURATION := 0.07
const IMPACT_SHAKE_STRENGTH := 0.09
const IMPACT_SHAKE_DURATION := 0.22

static func _make_unshaded_material(color: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

static func _fade_ramp(color: Color, start_alpha: float = 1.0) -> GradientTexture1D:
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, start_alpha))
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = fade
	return tex

static func _spawn_particle_layer(parent: Node, position: Vector3, color: Color, config: Dictionary) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	parent.add_child(particles)
	particles.global_position = position
	particles.amount = config.get("amount", 20)
	particles.lifetime = config.get("lifetime", 0.5)
	particles.one_shot = true
	particles.explosiveness = config.get("explosiveness", 0.9)
	particles.emitting = true

	var mesh := SphereMesh.new()
	mesh.radius = config.get("mesh_radius", 0.06)
	mesh.height = mesh.radius * 2.0
	mesh.material = _make_unshaded_material(color, config.get("energy", 2.0))
	particles.draw_pass_1 = mesh

	var process_mat := ParticleProcessMaterial.new()
	process_mat.direction = config.get("direction", Vector3(0, 1, 0))
	process_mat.spread = config.get("spread", 180.0)
	process_mat.initial_velocity_min = config.get("velocity_min", 2.0)
	process_mat.initial_velocity_max = config.get("velocity_max", 4.5)
	process_mat.gravity = config.get("gravity", Vector3(0, -4.0, 0))
	process_mat.scale_min = config.get("scale_min", 0.4)
	process_mat.scale_max = config.get("scale_max", 1.0)
	process_mat.damping_min = config.get("damping", 0.0)
	process_mat.damping_max = config.get("damping", 0.0)
	process_mat.color_ramp = _fade_ramp(color, config.get("start_alpha", 1.0))
	particles.process_material = process_mat

	var tree := parent.get_tree()
	if tree:
		tree.create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)
	return particles

## Bright flash of light at a point, quickly fading. Cheap way to sell "impact".
static func spawn_light_flash(parent: Node, world_position: Vector3, color: Color, energy: float = 6.0, size: float = 4.0, duration: float = 0.18) -> void:
	var light := OmniLight3D.new()
	parent.add_child(light)
	light.global_position = world_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = size
	var tree := parent.get_tree()
	if tree == null:
		light.queue_free()
		return
	var tween := tree.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)

## Shakes the given camera briefly using its lens offset (no effect on
## actual transform, so it's safe to call regardless of who drives the rig).
static func shake_camera(camera: Camera3D, strength: float = IMPACT_SHAKE_STRENGTH, duration: float = IMPACT_SHAKE_DURATION) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var tree := camera.get_tree()
	if tree == null:
		return
	var tween := tree.create_tween()
	var steps := 6
	for i in range(steps):
		var falloff := 1.0 - float(i) / float(steps)
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		tween.tween_property(camera, "h_offset", offset.x, duration / steps)
		tween.parallel().tween_property(camera, "v_offset", offset.y, duration / steps)
	tween.tween_property(camera, "h_offset", 0.0, 0.04)
	tween.parallel().tween_property(camera, "v_offset", 0.0, 0.04)

## Freezes gameplay for a few frames on a big hit to sell impact weight.
## Global (Engine.time_scale), so it affects both players in online matches.
static func hitstop(tree: SceneTree, strength: float = HITSTOP_STRENGTH, duration: float = HITSTOP_DURATION) -> void:
	if tree == null:
		return
	Engine.time_scale = strength
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)

## Spawns a layered particle burst at world_position: a bright core flash,
## a spark shower, and a lingering smoke/dust layer, plus a light flash,
## camera shake on the active viewport camera, and a short hitstop.
static func spawn_impact(parent: Node, world_position: Vector3, color: Color) -> void:
	_spawn_particle_layer(parent, world_position, color.lightened(0.5), {
		"amount": 10, "lifetime": 0.18, "explosiveness": 1.0,
		"mesh_radius": 0.1, "energy": 4.0,
		"spread": 180.0, "velocity_min": 0.5, "velocity_max": 1.5,
		"gravity": Vector3.ZERO, "scale_min": 0.8, "scale_max": 1.6,
	})
	_spawn_particle_layer(parent, world_position, color, {
		"amount": 28, "lifetime": 0.45, "explosiveness": 0.95,
		"mesh_radius": 0.05, "energy": 2.5,
		"spread": 180.0, "velocity_min": 3.0, "velocity_max": 6.5,
		"gravity": Vector3(0, -3.0, 0), "scale_min": 0.3, "scale_max": 0.8,
	})
	_spawn_particle_layer(parent, world_position, color.darkened(0.2), {
		"amount": 12, "lifetime": 0.7, "explosiveness": 0.7,
		"mesh_radius": 0.14, "energy": 0.8, "start_alpha": 0.55,
		"spread": 100.0, "velocity_min": 0.6, "velocity_max": 1.6,
		"gravity": Vector3(0, 0.6, 0), "scale_min": 1.0, "scale_max": 2.0,
	})
	spawn_light_flash(parent, world_position, color)
	hitstop(parent.get_tree())
	var viewport := parent.get_viewport()
	if viewport:
		shake_camera(viewport.get_camera_3d())

## Spawns a brief burst of particles at the caster's hand when an ability
## is launched (melee swing, projectile release, hitscan cast).
static func spawn_cast_burst(parent: Node, world_position: Vector3, forward: Vector3, color: Color) -> void:
	_spawn_particle_layer(parent, world_position, color.lightened(0.4), {
		"amount": 8, "lifetime": 0.2, "explosiveness": 1.0,
		"mesh_radius": 0.06, "energy": 3.5,
		"direction": forward, "spread": 15.0,
		"velocity_min": 2.0, "velocity_max": 4.0,
		"gravity": Vector3.ZERO, "scale_min": 0.6, "scale_max": 1.0,
	})
	_spawn_particle_layer(parent, world_position, color, {
		"amount": 22, "lifetime": 0.4, "explosiveness": 0.9,
		"mesh_radius": 0.045, "energy": 2.5,
		"direction": forward, "spread": 30.0,
		"velocity_min": 1.5, "velocity_max": 3.8,
		"gravity": Vector3.ZERO, "scale_min": 0.5, "scale_max": 1.1,
	})
	spawn_light_flash(parent, world_position, color, 4.0, 2.5, 0.12)

## Continuous-feeling aura of particles rising off the caster's body while
## they channel an ability. Call once; it free itself after `duration`.
static func spawn_body_aura(parent: Node, body_position: Vector3, color: Color, radius: float = 0.5, duration: float = 0.6) -> void:
	var particles := GPUParticles3D.new()
	parent.add_child(particles)
	particles.global_position = body_position
	particles.amount = 30
	particles.lifetime = 0.6
	particles.one_shot = false
	particles.emitting = true

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.material = _make_unshaded_material(color, 2.0)
	particles.draw_pass_1 = mesh

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_mat.emission_sphere_radius = radius
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 20.0
	process_mat.initial_velocity_min = 0.6
	process_mat.initial_velocity_max = 1.4
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.3
	process_mat.scale_max = 0.7
	process_mat.color_ramp = _fade_ramp(color, 0.8)
	particles.process_material = process_mat

	var tree := parent.get_tree()
	if tree:
		tree.create_timer(duration).timeout.connect(func():
			particles.emitting = false
			tree.create_timer(particles.lifetime + 0.1).timeout.connect(particles.queue_free)
		)

## Draws a short-lived glowing beam between two world points (hitscan attacks).
static func spawn_beam(parent: Node, from: Vector3, to: Vector3, color: Color, thickness: float = 0.045, duration: float = 0.2) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return

	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = thickness
	core_mesh.bottom_radius = thickness
	core_mesh.height = length
	core_mesh.radial_segments = 8
	core_mesh.material = _make_unshaded_material(color.lightened(0.6), 5.0, 0.9)
	core.mesh = core_mesh

	var glow := MeshInstance3D.new()
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = thickness * 2.5
	glow_mesh.bottom_radius = thickness * 2.5
	glow_mesh.height = length
	glow_mesh.radial_segments = 8
	glow_mesh.material = _make_unshaded_material(color, 3.0, 0.35)
	glow.mesh = glow_mesh

	parent.add_child(core)
	parent.add_child(glow)
	for mesh_inst in [core, glow]:
		mesh_inst.look_at_from_position((from + to) / 2.0, to, Vector3.UP)
		mesh_inst.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	spawn_light_flash(parent, to, color, 5.0, 3.0, 0.15)

	var tree := parent.get_tree()
	if tree:
		var tween := tree.create_tween()
		tween.tween_property(core.mesh.material, "emission_energy_multiplier", 0.0, duration)
		tween.parallel().tween_property(core.mesh.material, "albedo_color:a", 0.0, duration)
		tween.parallel().tween_property(glow.mesh.material, "emission_energy_multiplier", 0.0, duration)
		tween.parallel().tween_property(glow.mesh.material, "albedo_color:a", 0.0, duration)
		tween.tween_callback(core.queue_free)
		tween.tween_callback(glow.queue_free)
