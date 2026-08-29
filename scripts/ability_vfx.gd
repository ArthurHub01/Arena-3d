class_name AbilityVFX
extends RefCounted

## Bespoke cast/impact/self-buff visuals for the 15 named Habilidade 1/2/
## Suprema moves (see scripts/ability_library.gd's `vfx_key` field). Ataque
## Básico and the S/D/no-direction combo slots leave `vfx_key` empty and
## keep using the generic VFX.spawn_* helpers untouched.

static func _mat(color: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

## Procedural mottled rock look (noise-driven albedo) so stone surfaces
## aren't a single flat gray — no external texture files needed.
static func rock_material(base_color: Color = Color(0.45, 0.4, 0.36)) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.18
	noise.fractal_octaves = 3
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.width = 128
	noise_tex.height = 128
	noise_tex.noise = noise
	mat.albedo_texture = noise_tex
	mat.roughness = 0.95
	mat.metallic = 0.0
	return mat

# ---------------------------------------------------------------------------
# Shared primitives
# ---------------------------------------------------------------------------

## Ground level for a ring/shockwave placed under a chest-height reference
## point (body_pos/target_pos are passed in at +1.0 above the feet).
static func _ground(pos: Vector3) -> Vector3:
	return Vector3(pos.x, pos.y - 0.95, pos.z)

## Flat expanding ring (shockwave / heat wave / ground crack rim). Radius is
## capped so it can't balloon past the combat camera and warp the view.
static func _spawn_ring(parent: Node, position: Vector3, color: Color, end_radius: float, duration: float = 0.35, thickness: float = 0.12) -> void:
	end_radius = min(end_radius, 3.0)
	var mesh_inst := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.05
	mesh.outer_radius = 0.05 + thickness
	mesh.material = _mat(color, 3.0, 0.8)
	mesh_inst.mesh = mesh
	parent.add_child(mesh_inst)
	mesh_inst.global_position = position
	mesh_inst.scale = Vector3(0.05, 0.05, 0.05)

	var tree := parent.get_tree()
	if tree == null:
		mesh_inst.queue_free()
		return
	var scale_target := end_radius / (0.05 + thickness)
	var tween := tree.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3.ONE * scale_target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_inst.mesh.material, "albedo_color:a", 0.0, duration)
	tween.tween_property(mesh_inst.mesh.material, "emission_energy_multiplier", 0.0, duration)
	tween.chain().tween_callback(func():
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)

## Swirling ring of particles orbiting a point — tornado / repulse aura /
## floating rock shards, depending on color + mesh + orbit speed.
static func _spawn_vortex(parent: Node, position: Vector3, color: Color, radius: float, orbit_speed: float, duration: float, mesh_radius: float = 0.06, rise_speed: float = 0.4) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	parent.add_child(particles)
	particles.global_position = position
	particles.amount = 26
	particles.lifetime = 1.2
	particles.one_shot = false
	particles.emitting = true

	var mesh := SphereMesh.new()
	mesh.radius = mesh_radius
	mesh.height = mesh_radius * 2.0
	mesh.material = _mat(color, 2.0, 0.85)
	particles.draw_pass_1 = mesh

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process_mat.emission_ring_axis = Vector3.UP
	process_mat.emission_ring_radius = radius
	process_mat.emission_ring_inner_radius = radius * 0.7
	process_mat.emission_ring_height = 0.1
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 0.0
	process_mat.initial_velocity_min = rise_speed
	process_mat.initial_velocity_max = rise_speed * 1.5
	process_mat.orbit_velocity_min = orbit_speed
	process_mat.orbit_velocity_max = orbit_speed
	process_mat.gravity = Vector3.ZERO
	process_mat.scale_min = 0.6
	process_mat.scale_max = 1.1
	var fade := Gradient.new()
	fade.set_color(0, Color(color.r, color.g, color.b, 0.0))
	fade.add_point(0.15, Color(color.r, color.g, color.b, 0.9))
	fade.add_point(0.8, Color(color.r, color.g, color.b, 0.7))
	fade.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	process_mat.color_ramp = fade_tex
	particles.process_material = process_mat

	var tree := parent.get_tree()
	if tree:
		tree.create_timer(duration).timeout.connect(func():
			if is_instance_valid(particles):
				particles.emitting = false
				tree.create_timer(particles.lifetime + 0.1).timeout.connect(func():
					if is_instance_valid(particles):
						particles.queue_free()
				)
		)
	return particles

## Zigzag lightning bolt built from a chain of jittered thin cylinders,
## instead of one straight beam.
static func _spawn_jagged_beam(parent: Node, from: Vector3, to: Vector3, color: Color, segments: int = 6, jitter: float = 0.3, thickness: float = 0.05, duration: float = 0.15) -> void:
	var points: Array[Vector3] = [from]
	for i in range(1, segments):
		var t := float(i) / float(segments)
		var base := from.lerp(to, t)
		var side := Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 0.4), randf_range(-1.0, 1.0)) * jitter
		points.append(base + side)
	points.append(to)

	var meshes: Array[MeshInstance3D] = []
	for i in range(points.size() - 1):
		var seg_from: Vector3 = points[i]
		var seg_to: Vector3 = points[i + 1]
		var length := seg_from.distance_to(seg_to)
		if length < 0.001:
			continue
		var core := MeshInstance3D.new()
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = thickness
		core_mesh.bottom_radius = thickness
		core_mesh.height = length
		core_mesh.radial_segments = 5
		core_mesh.material = _mat(color.lightened(0.6), 6.0, 0.95)
		core.mesh = core_mesh
		parent.add_child(core)
		core.look_at_from_position((seg_from + seg_to) / 2.0, seg_to, Vector3.UP)
		core.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		meshes.append(core)

		var glow := MeshInstance3D.new()
		var glow_mesh := CylinderMesh.new()
		glow_mesh.top_radius = thickness * 3.0
		glow_mesh.bottom_radius = thickness * 3.0
		glow_mesh.height = length
		glow_mesh.radial_segments = 6
		glow_mesh.material = _mat(color, 3.0, 0.4)
		glow.mesh = glow_mesh
		parent.add_child(glow)
		glow.look_at_from_position((seg_from + seg_to) / 2.0, seg_to, Vector3.UP)
		glow.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		meshes.append(glow)

	VFX.spawn_light_flash(parent, to, color, 5.0, 3.0, duration)

	var tree := parent.get_tree()
	if tree == null:
		for m in meshes:
			m.queue_free()
		return
	var tween := tree.create_tween()
	tween.set_parallel(true)
	for m in meshes:
		tween.tween_property(m.mesh.material, "emission_energy_multiplier", 0.0, duration)
		tween.tween_property(m.mesh.material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(func():
		for m in meshes:
			if is_instance_valid(m):
				m.queue_free()
	)

## Translucent bubble that follows a moving node for `duration` seconds.
static func _spawn_dome_shield(follow_node: Node3D, color: Color, duration: float, radius: float = 1.15) -> void:
	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var mat := _mat(color, 1.2, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	mesh_inst.mesh = mesh
	follow_node.add_child(mesh_inst)
	mesh_inst.position = Vector3(0, 1.0, 0)

	var mist := _spawn_vortex(follow_node, Vector3(0, 1.0, 0), color, radius * 0.8, 0.6, duration, 0.03, 0.15)
	mist.position = Vector3(0, 1.0, 0)

	var tree := follow_node.get_tree()
	if tree == null:
		mesh_inst.queue_free()
		return
	var tween := tree.create_tween()
	tween.tween_interval(max(duration - 0.3, 0.0))
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(func():
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)

## Rocky orbiting shards around a moving node (Armadura de Rocha).
static func _spawn_rock_aura(follow_node: Node3D, color: Color, duration: float) -> void:
	var particles := _spawn_vortex(follow_node, Vector3(0, 1.0, 0), color, 0.9, 1.2, duration, 0.09, 0.05)
	particles.position = Vector3(0, 1.0, 0)

## Traveling translucent wave-front (Tsunami).
static func _spawn_wave(parent: Node, start_pos: Vector3, forward: Vector3, color: Color, range: float, duration: float = 0.5) -> void:
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.2, 2.0, 0.5)
	mesh.material = _mat(color, 1.5, 0.55)
	mesh_inst.mesh = mesh
	parent.add_child(mesh_inst)
	var wave_start := start_pos + Vector3(0, 1.0, 0) + forward * 0.8
	mesh_inst.look_at_from_position(wave_start, wave_start + forward, Vector3.UP)

	var foam := _spawn_vortex(parent, mesh_inst.global_position, color.lightened(0.6), 1.4, 2.0, duration, 0.05, 0.6)
	foam.reparent(mesh_inst, false)
	foam.position = Vector3.ZERO

	var tree := parent.get_tree()
	if tree == null:
		mesh_inst.queue_free()
		return
	var target_pos := start_pos + Vector3(0, 1.0, 0) + forward * range
	var tween := tree.create_tween()
	tween.tween_property(mesh_inst, "global_position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mesh_inst.mesh.material, "albedo_color:a", 0.0, duration).set_delay(duration * 0.4)
	tween.tween_callback(func():
		if is_instance_valid(mesh_inst):
			mesh_inst.queue_free()
	)

## Bolt striking down from above onto a point (Teletransporte arrival /
## Tempestade de Raios hits).
static func _spawn_falling_bolt(parent: Node, target_pos: Vector3, color: Color) -> void:
	_spawn_jagged_beam(parent, target_pos + Vector3(0, 7.0, 0), target_pos, color, 5, 0.5, 0.035, 0.16)

# ---------------------------------------------------------------------------
# Cast (launch) effects
# ---------------------------------------------------------------------------

static func play_cast(ability: AbilityData, parent: Node, muzzle_pos: Vector3, forward: Vector3, body_pos: Vector3) -> void:
	var color := ElementType.get_color(ability.element)
	match ability.vfx_key:
		"fire_h1":
			_spawn_ring(parent, _ground(body_pos), color, ability.aoe_range, 0.4, 0.2)
			VFX.spawn_cast_burst(parent, muzzle_pos, forward, color)
		"fire_h2":
			VFX.spawn_cast_burst(parent, muzzle_pos, forward, color.lightened(0.3))
			VFX.spawn_light_flash(parent, body_pos, color, 5.0, 3.0, 0.15)
		"fire_supreme":
			_spawn_ring(parent, _ground(body_pos), color, ability.aoe_range, 0.5, 0.35)
			_spawn_ring(parent, _ground(body_pos), color.lightened(0.4), ability.aoe_range * 0.6, 0.35, 0.2)
			VFX.spawn_light_flash(parent, body_pos, color, 5.5, 3.5, 0.25)
			VFX.hitstop(parent.get_tree(), 0.05, 0.09)
		"water_h1":
			VFX.spawn_light_flash(parent, body_pos, color, 3.5, 2.5, 0.2)
		"water_h2":
			VFX.spawn_cast_burst(parent, muzzle_pos, forward, color.lightened(0.3))
		"water_supreme":
			_spawn_wave(parent, body_pos, forward, color, ability.aoe_range)
			VFX.hitstop(parent.get_tree(), 0.06, 0.08)
		"earth_h1":
			_spawn_ring(parent, _ground(body_pos + forward * 3.0), color.darkened(0.1), 1.6, 0.3, 0.15)
		"earth_h2":
			_march_earthquake(parent, body_pos, forward, ability.aoe_range, color)
		"earth_supreme":
			VFX.spawn_light_flash(parent, body_pos, color, 4.0, 3.0, 0.25)
		"air_h1":
			_spawn_ring(parent, _ground(body_pos), color, 1.4, 0.25, 0.12)
		"air_h2":
			VFX.spawn_light_flash(parent, body_pos, color, 2.5, 2.0, 0.15)
		"air_supreme":
			_spawn_vortex(parent, body_pos, color, 2.2, 3.0, 0.5, 0.06, 1.2)
			VFX.spawn_light_flash(parent, body_pos, color, 5.0, min(ability.aoe_range, 3.5), 0.25)
			VFX.hitstop(parent.get_tree(), 0.06, 0.08)
		"lightning_h1":
			VFX.spawn_light_flash(parent, body_pos, color, 6.0, 3.0, 0.12)
		"lightning_h2":
			pass # beam drawn in play_beam() when the ray resolves
		"lightning_supreme":
			VFX.spawn_light_flash(parent, body_pos, color, 4.0, 3.0, 0.15)
		_:
			VFX.spawn_cast_burst(parent, muzzle_pos, forward, color)

static func _march_earthquake(parent: Node, start_pos: Vector3, forward: Vector3, range: float, color: Color) -> void:
	var tree := parent.get_tree()
	if tree == null:
		return
	var steps := 4
	for i in range(steps):
		var t := float(i) / float(steps - 1)
		var pos := start_pos + forward * range * t
		var delay := t * 0.28
		tree.create_timer(delay).timeout.connect(func():
			if is_instance_valid(parent):
				_spawn_ring(parent, _ground(pos), color, 1.3, 0.3, 0.15)
		)

# ---------------------------------------------------------------------------
# On-hit "flavor" effects — additive, layered on top of the generic
# VFX.spawn_impact already fired from Player._apply_damage.
# ---------------------------------------------------------------------------

static func play_landed(ability: AbilityData, parent: Node, target_pos: Vector3) -> void:
	var color := ElementType.get_color(ability.element)
	match ability.vfx_key:
		"fire_h1":
			VFX.spawn_light_flash(parent, target_pos, color, 4.0, 2.5, 0.2)
		"fire_h2":
			_spawn_ring(parent, _ground(target_pos), color, 1.8, 0.3, 0.25)
		"fire_supreme":
			_spawn_ring(parent, _ground(target_pos), color, 3.0, 0.4, 0.3)
			VFX.spawn_light_flash(parent, target_pos, color, 8.0, 5.0, 0.3)
		"water_h2":
			_spawn_ring(parent, _ground(target_pos), Color(0.75, 0.9, 1.0), 1.4, 0.3, 0.15)
			VFX.spawn_light_flash(parent, target_pos, Color(0.75, 0.9, 1.0), 3.0, 2.5, 0.2)
		"water_supreme":
			_spawn_ring(parent, _ground(target_pos), color.lightened(0.3), 2.2, 0.35, 0.3)
		"earth_h2":
			_spawn_ring(parent, _ground(target_pos), color.darkened(0.15), 2.0, 0.3, 0.3)
		"air_supreme":
			_spawn_vortex(parent, target_pos, color, 1.0, 2.5, 0.3, 0.05, 0.8)
		"lightning_h1":
			VFX.spawn_light_flash(parent, target_pos, color, 5.0, 3.0, 0.15)
		_:
			pass

static func play_burn_tick(parent: Node, target_pos: Vector3) -> void:
	var color := ElementType.get_color(ElementType.Type.FIRE)
	VFX._spawn_particle_layer(parent, target_pos, color, {
		"amount": 6, "lifetime": 0.3, "explosiveness": 1.0,
		"mesh_radius": 0.04, "energy": 2.0,
		"spread": 60.0, "velocity_min": 0.5, "velocity_max": 1.2,
		"gravity": Vector3(0, 1.0, 0), "scale_min": 0.4, "scale_max": 0.8,
	})

# ---------------------------------------------------------------------------
# Beams (HITSCAN / MULTI_HITSCAN)
# ---------------------------------------------------------------------------

static func play_beam(ability: AbilityData, parent: Node, from: Vector3, to: Vector3) -> void:
	var color := ElementType.get_color(ability.element)
	match ability.vfx_key:
		"lightning_h2", "lightning_supreme":
			_spawn_jagged_beam(parent, from, to, color)
			_spawn_falling_bolt(parent, to, color)
		_:
			VFX.spawn_beam(parent, from, to, color)

# ---------------------------------------------------------------------------
# Self-buffs — persistent visuals attached to the caster's own node.
# ---------------------------------------------------------------------------

static func play_self_buff(ability: AbilityData, player: Node3D) -> void:
	var color := ElementType.get_color(ability.element)
	match ability.self_buff_type:
		"shield":
			_spawn_dome_shield(player, color, ability.self_buff_duration)
		"damage_mitigation":
			_spawn_rock_aura(player, color, ability.self_buff_duration)
		"repulse_aura":
			var vortex := _spawn_vortex(player, player.global_position + Vector3(0, 0.2, 0), color, 3.0, 2.0, ability.self_buff_duration, 0.06, 0.1)
			vortex.position = Vector3(0, 0.2, 0)
		"extra_dash":
			VFX.spawn_cast_burst(player.get_parent(), player.global_position + Vector3(0, 0.2, 0), -player.global_transform.basis.z, color)
			_spawn_ring(player.get_parent(), player.global_position, color, 1.2, 0.25, 0.1)

# ---------------------------------------------------------------------------
# Wall / teleport
# ---------------------------------------------------------------------------

static func play_wall_cast(parent: Node, position: Vector3, color: Color) -> void:
	VFX._spawn_particle_layer(parent, position, color.darkened(0.2), {
		"amount": 16, "lifetime": 0.5, "explosiveness": 1.0,
		"mesh_radius": 0.12, "energy": 0.5, "start_alpha": 0.6,
		"spread": 120.0, "velocity_min": 1.0, "velocity_max": 2.5,
		"gravity": Vector3(0, -1.0, 0), "scale_min": 0.8, "scale_max": 1.6,
	})
	_spawn_ring(parent, _ground(position), color.darkened(0.1), 1.8, 0.3, 0.2)

static func play_teleport(parent: Node, old_pos: Vector3, new_pos: Vector3, color: Color) -> void:
	VFX.spawn_light_flash(parent, old_pos, color, 6.0, 2.5, 0.15)
	_spawn_ring(parent, old_pos, color, 1.3, 0.25, 0.12)
	VFX.spawn_light_flash(parent, new_pos, color, 7.0, 3.0, 0.18)
	_spawn_jagged_beam(parent, old_pos, new_pos, color, 5, 0.6, 0.025, 0.12)

# ---------------------------------------------------------------------------
# Block stance — persistent per-element visual while holding block (right
# click, no direction held). Started when blocking begins, stopped when it
# ends, regardless of how long the player holds it.
# ---------------------------------------------------------------------------

const _BLOCK_VORTEX_DURATION := 999.0  # effectively indefinite; stop_block_stance() cuts it short manually

static func _spawn_static_dome(follow_node: Node3D, color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.15
	mesh.height = 1.15 * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var mat := _mat(color, 1.2, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	mesh_inst.mesh = mesh
	follow_node.add_child(mesh_inst)
	mesh_inst.position = Vector3(0, 1.0, 0)
	return mesh_inst

## Kite-shield silhouette (local x, y offsets, feet-relative) built from
## individually jagged rock chunks — widest at the top, tapering to a point,
## echoing a hand-forged stone shield rather than a flat slab.
const _EARTH_SHIELD_CHUNKS := [
	Vector2(-0.5, 1.66), Vector2(0.0, 1.8), Vector2(0.5, 1.66),
	Vector2(-0.82, 1.34), Vector2(-0.27, 1.42), Vector2(0.27, 1.42), Vector2(0.82, 1.34),
	Vector2(-0.6, 1.0), Vector2(0.0, 1.08), Vector2(0.6, 1.0),
	Vector2(-0.33, 0.68), Vector2(0.33, 0.68),
	Vector2(0.0, 0.36),
]

## Round-topped shield of rock chunks that fly in from scattered directions
## and assemble in front of the player, as if pulled together from the
## ground — not a single flat slab.
static func _spawn_earth_shield(follow_node: Node3D, color: Color) -> Node3D:
	var root := Node3D.new()
	follow_node.add_child(root)
	root.position = Vector3(0, 0, -1.05)
	root.scale = Vector3.ONE

	var tree := follow_node.get_tree()
	VFX._spawn_particle_layer(follow_node, Vector3(0, 0.05, -1.05), color.darkened(0.2), {
		"amount": 14, "lifetime": 0.45, "explosiveness": 1.0,
		"mesh_radius": 0.08, "energy": 0.5, "start_alpha": 0.6,
		"spread": 110.0, "velocity_min": 0.8, "velocity_max": 2.0,
		"gravity": Vector3(0, -1.0, 0), "scale_min": 0.7, "scale_max": 1.3,
	})

	for slot in _EARTH_SHIELD_CHUNKS:
		var chunk := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(
			randf_range(0.55, 0.85), randf_range(0.5, 0.8), randf_range(0.35, 0.55)
		)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(randf_range(0.0, 0.3)).lightened(randf_range(0.0, 0.08))
		mat.roughness = 0.95
		mat.metallic = 0.0
		mesh.material = mat
		chunk.mesh = mesh
		root.add_child(chunk)

		var final_pos := Vector3(slot.x, slot.y, randf_range(-0.12, 0.12))
		var final_rot := Vector3(randf_range(-0.5, 0.5), randf_range(-0.6, 0.6), randf_range(-0.5, 0.5))
		var scatter_dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 0.7), randf_range(-1.0, 1.0)).normalized()
		chunk.position = final_pos + scatter_dir * randf_range(1.6, 2.6)
		chunk.rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
		chunk.scale = Vector3.ONE * 0.25

		if tree:
			var tween := tree.create_tween()
			tween.tween_interval(randf_range(0.0, 0.1))
			tween.set_parallel(true)
			tween.tween_property(chunk, "position", final_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(chunk, "rotation", final_rot, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(chunk, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root

static func _crumble_and_free_shield(root: Node3D) -> void:
	if not is_instance_valid(root):
		return
	var tree := root.get_tree()
	if tree == null:
		root.queue_free()
		return
	var tween := tree.create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 0.05, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(root, "position:y", root.position.y - 0.5, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(root):
			root.queue_free()
	)

## Returns a handle (Dictionary) to pass into stop_block_stance() later.
static func start_block_stance(element: ElementType.Type, player: Node3D) -> Dictionary:
	var color := ElementType.get_color(element)
	var handle := {"particles": null, "mesh": null, "on_stop": Callable()}
	match element:
		ElementType.Type.FIRE:
			var particles := _spawn_vortex(player, Vector3(0, 1.0, 0), color, 0.7, 2.5, _BLOCK_VORTEX_DURATION, 0.07, 0.9)
			particles.position = Vector3(0, 1.0, 0)
			handle["particles"] = particles
		ElementType.Type.WATER:
			var particles := _spawn_vortex(player, Vector3(0, 1.0, 0), color, 0.9, 0.8, _BLOCK_VORTEX_DURATION, 0.04, 0.2)
			particles.position = Vector3(0, 1.0, 0)
			handle["particles"] = particles
		ElementType.Type.EARTH:
			var shield := _spawn_earth_shield(player, color)
			handle["mesh"] = shield
			handle["on_stop"] = func(): _crumble_and_free_shield(shield)
		ElementType.Type.AIR:
			handle["mesh"] = _spawn_static_dome(player, color)
		ElementType.Type.LIGHTNING:
			var particles := _spawn_vortex(player, Vector3(0, 1.0, 0), color, 0.8, 4.0, _BLOCK_VORTEX_DURATION, 0.03, 0.6)
			particles.position = Vector3(0, 1.0, 0)
			handle["particles"] = particles
	return handle

static func stop_block_stance(handle: Dictionary) -> void:
	var particles: GPUParticles3D = handle.get("particles")
	if is_instance_valid(particles):
		particles.emitting = false
		var tree := particles.get_tree()
		if tree:
			tree.create_timer(particles.lifetime + 0.1).timeout.connect(func():
				if is_instance_valid(particles):
					particles.queue_free()
			)
		else:
			particles.queue_free()
	var on_stop: Callable = handle.get("on_stop", Callable())
	if on_stop.is_valid():
		on_stop.call()
		return
	var mesh_inst: MeshInstance3D = handle.get("mesh")
	if is_instance_valid(mesh_inst):
		mesh_inst.queue_free()
