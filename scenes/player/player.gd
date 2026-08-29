extends CharacterBody3D
class_name Player

signal damaged(current_hp: int)
signal died()
signal special_meter_changed(current: float, max_value: float)

const SPEED := 9.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const ARENA_RADIUS := 19.4

const CAMERA_DISTANCE := 5.0
const CAMERA_HEIGHT := 2.4
const LOOK_HEIGHT := 1.3
const CAMERA_LERP_SPEED := 6.0

const MODEL_BASE_ROTATION := PI
const MODEL_TURN_LERP_SPEED := 10.0

const WALK_ANIM_THRESHOLD := 0.3

const AI_MELEE_PREFERRED_RANGE := 2.0
const AI_RANGED_PREFERRED_RANGE := 8.0
const AI_RANGE_BUFFER := 1.5
const AI_MISS_CHANCE := 0.3
const AI_AIM_SPREAD_DEGREES := 14.0

const ATTACK_COMBO_WINDOW := 0.8
const ATTACK_SLOT_MAP := {
	"W": {"first": 1, "second": 2},
	"A": {"first": 3, "second": 4},
	"S": {"first": 5, "second": 6},
	"D": {"first": 7, "second": 8},
	"": {"first": 9, "second": 10},
}
const DODGE_INDEX_MAP := {"W": 1, "A": 2, "S": 3, "D": 4}
const DODGE_LOCAL_DIR := {
	"W": Vector3(0, 0, -1),
	"A": Vector3(-1, 0, 0),
	"S": Vector3(0, 0, 1),
	"D": Vector3(1, 0, 0),
}

const SPECIAL_METER_MAX := 100.0
const SPECIAL_METER_PER_HIT := 12.5

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_RUN := "run"
const ANIM_PUNCH := "punch"
const ANIM_DEATH := "death"
const RUN_SPEED_RATIO_THRESHOLD := 1.1

const HIT_ANIMS := {
	"front": "hit_front",
	"back": "hit_back",
	"left": "hit_left",
	"right": "hit_right",
}

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var melee_area: Area3D = $MeleeHitPoint/MeleeArea
@onready var anim_player: AnimationPlayer = $ModelRoot/CharacterModel/AnimationPlayer
@onready var model_root: Node3D = $ModelRoot
@onready var nickname_label: Label3D = $NicknameLabel
@onready var body_mesh: MeshInstance3D = $ModelRoot/CharacterModel/Skeleton3D/Beta_Surface
@onready var joints_mesh: MeshInstance3D = $ModelRoot/CharacterModel/Skeleton3D/Beta_Joints

var stats: CombatStats = CombatStats.new()
var is_local_player: bool = true
var is_ai_controlled: bool = false
var opponent: Player = null
var match_active: bool = false
var equipped_element: ElementType.Type = ElementType.Type.FIRE
var basic_ability: AbilityData = AbilityLibrary.get_basic_ability(ElementType.Type.FIRE)
var block_ability: DodgeData = AbilityLibrary.get_dodge(ElementType.Type.FIRE, 5)
var attack_ready: bool = true
var last_hit_element: ElementType.Type = ElementType.Type.NONE
var stagger_timer: float = 0.0
var _model_yaw_offset: float = 0.0
var _target_model_yaw_offset: float = 0.0

var _last_attack_family: String = ""
var _attack_awaiting_second: bool = false
var _combo_window_timer: float = 0.0

var is_blocking: bool = false
var is_invincible: bool = false
var _invincible_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _dodge_timer: float = 0.0
var _dodge_speed: float = 0.0

var is_shielded: bool = false
var _shield_timer: float = 0.0

var damage_mitigation: float = 0.0
var _mitigation_timer: float = 0.0

var cc_immune: bool = false
var _cc_immune_timer: float = 0.0

var is_repulsing: bool = false
var _repulse_timer: float = 0.0
var _repulse_force: float = 0.0
var _repulse_cooldown_timer: float = 0.0
const REPULSE_RADIUS := 3.5
const REPULSE_INTERVAL := 0.5

var special_meter: float = 0.0

var projectile_scene: PackedScene = preload("res://scenes/player/Projectile.tscn")

func set_element(element: ElementType.Type) -> void:
	equipped_element = element
	basic_ability = AbilityLibrary.get_basic_ability(element)
	block_ability = AbilityLibrary.get_dodge(element, 5)

func set_nickname(nickname: String) -> void:
	nickname_label.text = nickname

func set_color(color: Color) -> void:
	for mesh_instance in [body_mesh, joints_mesh]:
		var mat: StandardMaterial3D = mesh_instance.mesh.surface_get_material(0).duplicate()
		mat.vertex_color_use_as_albedo = false
		mat.albedo_color = color
		mesh_instance.set_surface_override_material(0, mat)

@rpc("unreliable_ordered", "call_remote")
func _remote_update_transform(pos: Vector3, rot_y: float, blocking: bool, invincible: bool) -> void:
	var delta_pos := pos - global_position
	var moved := delta_pos.length()
	if moved > 0.01:
		var speed_ratio: float = clamp(moved / (SPEED / 60.0), 0.5, 2.0)
		_play_locomotion_anim(true, speed_ratio)
		var local_delta := delta_pos.rotated(Vector3.UP, -rot_y)
		_target_model_yaw_offset = _model_yaw_from_local_dir(Vector2(local_delta.x, local_delta.z))
	else:
		_play_locomotion_anim(false)
		_target_model_yaw_offset = 0.0
	global_position = pos
	rotation.y = rot_y
	is_blocking = blocking
	is_invincible = invincible

func _ready() -> void:
	camera.current = is_local_player
	anim_player.play(ANIM_IDLE)
	var melee_shape: CollisionShape3D = melee_area.get_child(0)
	melee_shape.shape = melee_shape.shape.duplicate()

func _process(delta: float) -> void:
	var lerp_amount: float = clamp(MODEL_TURN_LERP_SPEED * delta, 0.0, 1.0)
	_model_yaw_offset = lerp_angle(_model_yaw_offset, _target_model_yaw_offset, lerp_amount)
	model_root.rotation.y = MODEL_BASE_ROTATION + _model_yaw_offset

func _model_yaw_from_local_dir(local_dir: Vector2) -> float:
	if local_dir.length() < 0.001:
		return 0.0
	return atan2(-local_dir.x, -local_dir.y)

func _is_action_anim_playing() -> bool:
	var current := anim_player.current_animation
	return anim_player.is_playing() and (current == ANIM_PUNCH or current == ANIM_DEATH or HIT_ANIMS.values().has(current) or current.begins_with("cast_"))

func _play_locomotion_anim(is_moving: bool, speed_ratio: float = 1.0) -> void:
	if _is_action_anim_playing():
		return
	if not is_moving:
		if anim_player.current_animation != ANIM_IDLE:
			anim_player.play(ANIM_IDLE)
		anim_player.speed_scale = 1.0
		return
	var target_anim := ANIM_RUN if speed_ratio > RUN_SPEED_RATIO_THRESHOLD else ANIM_WALK
	if anim_player.current_animation != target_anim:
		anim_player.play(target_anim)
	anim_player.speed_scale = clamp(speed_ratio, 0.6, 1.8)

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player or not match_active or stagger_timer > 0.0:
		return
	if event.is_action_pressed("attack_button"):
		_try_attack()
	elif event.is_action_pressed("dodge_button"):
		_try_dodge()
	elif event.is_action_released("dodge_button"):
		is_blocking = false
	elif event.is_action_pressed("special_button"):
		_try_special()

func _get_held_direction_family() -> String:
	if Input.is_action_pressed("move_forward"):
		return "W"
	if Input.is_action_pressed("move_left"):
		return "A"
	if Input.is_action_pressed("move_back"):
		return "S"
	if Input.is_action_pressed("move_right"):
		return "D"
	return ""

func _try_attack() -> void:
	if not attack_ready:
		return
	var family := _get_held_direction_family()
	var slot: int
	if family == _last_attack_family and _attack_awaiting_second and _combo_window_timer > 0.0:
		slot = ATTACK_SLOT_MAP[family]["second"]
		_last_attack_family = ""
		_attack_awaiting_second = false
		_combo_window_timer = 0.0
	else:
		slot = ATTACK_SLOT_MAP[family]["first"]
		_last_attack_family = family
		_attack_awaiting_second = true
		_combo_window_timer = ATTACK_COMBO_WINDOW
	var ability: AbilityData
	if family == "W":
		ability = AbilityLibrary.get_habilidade_1(equipped_element)
	elif family == "A":
		ability = AbilityLibrary.get_habilidade_2(equipped_element)
	else:
		ability = AbilityLibrary.get_attack(equipped_element, slot)
	_fire_attack(ability)

func _try_special() -> void:
	if special_meter < SPECIAL_METER_MAX or not attack_ready:
		return
	special_meter = 0.0
	special_meter_changed.emit(special_meter, SPECIAL_METER_MAX)
	_fire_attack(AbilityLibrary.get_special(equipped_element))

func _try_dodge() -> void:
	var family := _get_held_direction_family()
	if family == "":
		is_blocking = true
		return
	var dodge := AbilityLibrary.get_dodge(equipped_element, DODGE_INDEX_MAP[family])
	_perform_dodge(dodge, family)

func _perform_dodge(dodge: DodgeData, family: String) -> void:
	var local_dir: Vector3 = DODGE_LOCAL_DIR[family]
	_dodge_dir = (transform.basis * local_dir).normalized()
	_dodge_speed = dodge.dash_speed
	_dodge_timer = dodge.dash_duration
	is_invincible = true
	_invincible_timer = dodge.iframe_duration

func _gain_special_meter() -> void:
	special_meter = min(SPECIAL_METER_MAX, special_meter + SPECIAL_METER_PER_HIT)
	special_meter_changed.emit(special_meter, SPECIAL_METER_MAX)

func _physics_process(delta: float) -> void:
	if not (is_local_player or is_ai_controlled) or not match_active:
		return

	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			_attack_awaiting_second = false
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			is_invincible = false
	if _shield_timer > 0.0:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			is_shielded = false
	if _mitigation_timer > 0.0:
		_mitigation_timer -= delta
		if _mitigation_timer <= 0.0:
			damage_mitigation = 0.0
	if _cc_immune_timer > 0.0:
		_cc_immune_timer -= delta
		if _cc_immune_timer <= 0.0:
			cc_immune = false
	if _repulse_cooldown_timer > 0.0:
		_repulse_cooldown_timer -= delta
	if is_repulsing:
		_repulse_timer -= delta
		if _repulse_timer <= 0.0:
			is_repulsing = false
		elif _repulse_cooldown_timer <= 0.0 and is_instance_valid(opponent):
			var to_opponent := opponent.global_position - global_position
			if to_opponent.length() <= REPULSE_RADIUS:
				var away_dir := to_opponent.normalized()
				opponent.take_damage(0, equipped_element, away_dir, _repulse_force, 0.0)
				_repulse_cooldown_timer = REPULSE_INTERVAL

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * delta * 4.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_play_locomotion_anim(false)
		if is_multiplayer_authority() and multiplayer.has_multiplayer_peer():
			_remote_update_transform.rpc(global_position, rotation.y, is_blocking, is_invincible)
		return

	var has_opponent := is_instance_valid(opponent)

	if has_opponent:
		var flat_target := Vector3(opponent.global_position.x, global_position.y, opponent.global_position.z)
		if flat_target.distance_to(global_position) > 0.01:
			look_at(flat_target, Vector3.UP)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if not is_ai_controlled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2
	if is_ai_controlled:
		input_dir = _ai_decide_movement()
		_ai_maybe_attack()
	else:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity.x = _dodge_dir.x * _dodge_speed
		velocity.z = _dodge_dir.z * _dodge_speed
	else:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	move_and_slide()

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clamp(horizontal_speed / SPEED, 0.6, 1.8)
	var is_moving := horizontal_speed > WALK_ANIM_THRESHOLD
	_play_locomotion_anim(is_moving, speed_ratio)
	_target_model_yaw_offset = _model_yaw_from_local_dir(input_dir) if is_moving else 0.0

	var horizontal := Vector2(global_position.x, global_position.z)
	if horizontal.length() > ARENA_RADIUS:
		horizontal = horizontal.normalized() * ARENA_RADIUS
		global_position.x = horizontal.x
		global_position.z = horizontal.y

	if has_opponent and is_local_player:
		_update_combat_camera(delta)

	if is_multiplayer_authority() and multiplayer.has_multiplayer_peer():
		_remote_update_transform.rpc(global_position, rotation.y, is_blocking, is_invincible)

func _ai_decide_movement() -> Vector2:
	if not is_instance_valid(opponent):
		return Vector2.ZERO
	var preferred := AI_MELEE_PREFERRED_RANGE if basic_ability.delivery == AbilityData.Delivery.MELEE else AI_RANGED_PREFERRED_RANGE
	var distance := global_position.distance_to(opponent.global_position)
	if distance > preferred + AI_RANGE_BUFFER:
		return Vector2(0, -1)
	elif distance < preferred - AI_RANGE_BUFFER and basic_ability.delivery != AbilityData.Delivery.MELEE:
		return Vector2(0, 1)
	else:
		return Vector2(sin(Time.get_ticks_msec() * 0.0015), 0)

func _ai_maybe_attack() -> void:
	if not attack_ready or not is_instance_valid(opponent):
		return
	var preferred := AI_MELEE_PREFERRED_RANGE if basic_ability.delivery == AbilityData.Delivery.MELEE else AI_RANGED_PREFERRED_RANGE
	var distance := global_position.distance_to(opponent.global_position)
	if distance <= preferred + AI_RANGE_BUFFER:
		_fire_attack(basic_ability)

func _update_combat_camera(delta: float) -> void:
	var mid := (global_position + opponent.global_position) / 2.0
	var away := global_position - opponent.global_position
	away.y = 0
	if away.length() < 0.01:
		away = -global_transform.basis.z
	away = away.normalized()

	var desired_pos := global_position + away * CAMERA_DISTANCE + Vector3(0, CAMERA_HEIGHT, 0)
	var desired_look := mid + Vector3(0, LOOK_HEIGHT, 0)

	var lerp_amount: float = clamp(CAMERA_LERP_SPEED * delta, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(desired_pos, lerp_amount)
	camera.look_at(desired_look, Vector3.UP)

func _fire_attack(ability: AbilityData) -> void:
	attack_ready = false
	var anim := ability.anim_name if not ability.anim_name.is_empty() else ANIM_PUNCH
	anim_player.play(anim)
	VFX.spawn_cast_burst(get_parent(), muzzle_point.global_position, -global_transform.basis.z, ElementType.get_color(ability.element))
	if multiplayer.has_multiplayer_peer():
		_show_attack_anim.rpc(anim)

	if not (is_ai_controlled and randf() < AI_MISS_CHANCE):
		match ability.delivery:
			AbilityData.Delivery.MELEE:
				_execute_melee(ability)
			AbilityData.Delivery.PROJECTILE:
				_execute_projectile(ability)
			AbilityData.Delivery.HITSCAN:
				_execute_hitscan(ability)
			AbilityData.Delivery.CONE:
				_execute_cone(ability)
			AbilityData.Delivery.LINE:
				_execute_line(ability)
			AbilityData.Delivery.SELF_BUFF:
				_execute_self_buff(ability)
			AbilityData.Delivery.WALL:
				_execute_wall(ability)
			AbilityData.Delivery.TELEPORT_STRIKE:
				_execute_teleport_strike(ability)
			AbilityData.Delivery.MULTI_HITSCAN:
				_execute_multi_hitscan(ability)

	get_tree().create_timer(ability.cooldown).timeout.connect(func(): attack_ready = true)

func _ai_aim_spread_rad() -> float:
	return deg_to_rad(randf_range(-AI_AIM_SPREAD_DEGREES, AI_AIM_SPREAD_DEGREES))

@rpc("unreliable_ordered", "call_remote")
func _show_attack_anim(anim: String) -> void:
	anim_player.play(anim)

func _execute_melee(ability: AbilityData) -> void:
	melee_area.get_child(0).shape.radius = ability.melee_range
	for body in melee_area.get_overlapping_bodies():
		if body is Player and body != self:
			var dir := (body.global_position - global_position)
			if ability.breaks_guard:
				body.is_blocking = false
			body.take_damage(ability.damage, ability.element, dir, ability.knockback_force, ability.stagger_duration)
			_gain_special_meter()

func _execute_projectile(ability: AbilityData) -> void:
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.damage = ability.damage
	projectile.element = ability.element
	projectile.speed = ability.projectile_speed
	projectile.lifetime = ability.projectile_lifetime
	projectile.knockback_force = ability.knockback_force
	projectile.stagger_duration = ability.stagger_duration
	projectile.shooter = self
	get_parent().add_child(projectile)
	projectile.global_transform = muzzle_point.global_transform
	if is_ai_controlled:
		projectile.rotate_y(_ai_aim_spread_rad())

func _execute_hitscan(ability: AbilityData) -> void:
	var from := muzzle_point.global_position
	var aim_dir := -global_transform.basis.z
	if is_ai_controlled:
		aim_dir = aim_dir.rotated(Vector3.UP, _ai_aim_spread_rad())
	var to := from + aim_dir * ability.hitscan_range

	if ability.hitscan_delay > 0.0:
		await get_tree().create_timer(ability.hitscan_delay).timeout
	if not is_instance_valid(self) or is_queued_for_deletion():
		return

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	var beam_end: Vector3 = result.position if result else to
	VFX.spawn_beam(get_parent(), from, beam_end, ElementType.get_color(ability.element))
	if result and result.collider is Player and result.collider != self:
		var target: Player = result.collider
		var dir := (target.global_position - global_position)
		target.take_damage(ability.damage, ability.element, dir, ability.knockback_force, ability.stagger_duration)
		_gain_special_meter()

func _knockback_dir_to_opponent(target: Player, ability: AbilityData) -> Vector3:
	var dir := target.global_position - global_position
	return -dir if ability.pull_instead_of_push else dir

func _execute_cone(ability: AbilityData) -> void:
	if not is_instance_valid(opponent):
		return
	var to_opponent := opponent.global_position - global_position
	var flat := Vector3(to_opponent.x, 0, to_opponent.z)
	if flat.length() > ability.aoe_range:
		return
	var forward := -global_transform.basis.z
	var angle := rad_to_deg(forward.angle_to(flat.normalized()))
	if angle > ability.cone_angle_degrees / 2.0:
		return
	var dir := _knockback_dir_to_opponent(opponent, ability)
	opponent.take_damage(ability.damage, ability.element, dir, ability.knockback_force, ability.stagger_duration)
	_gain_special_meter()
	if ability.burn_ticks > 0:
		_apply_burn(ability, opponent)

func _execute_line(ability: AbilityData) -> void:
	if not is_instance_valid(opponent):
		return
	var to_opponent := opponent.global_position - global_position
	var forward := -global_transform.basis.z
	var forward_dist := to_opponent.dot(forward)
	if forward_dist < 0.0 or forward_dist > ability.aoe_range:
		return
	var lateral := (to_opponent - forward * forward_dist).length()
	if lateral > 1.5:
		return
	var dir := _knockback_dir_to_opponent(opponent, ability)
	opponent.take_damage(ability.damage, ability.element, dir, ability.knockback_force, ability.stagger_duration)
	_gain_special_meter()

func _execute_self_buff(ability: AbilityData) -> void:
	match ability.self_buff_type:
		"shield":
			is_shielded = true
			_shield_timer = ability.self_buff_duration
		"damage_mitigation":
			damage_mitigation = ability.self_buff_value
			_mitigation_timer = ability.self_buff_duration
			cc_immune = true
			_cc_immune_timer = ability.self_buff_duration
		"repulse_aura":
			is_repulsing = true
			_repulse_timer = ability.self_buff_duration
			_repulse_force = ability.self_buff_value
		"extra_dash":
			var family := _get_held_direction_family()
			if family == "":
				family = "W"
			var boosted := DodgeData.new()
			boosted.dash_speed = 26.0
			boosted.dash_duration = 0.3
			boosted.iframe_duration = 0.25
			_perform_dodge(boosted, family)

func _execute_wall(ability: AbilityData) -> void:
	var spawn_pos := global_position + Vector3(0, 1.0, 0) + (-global_transform.basis.z) * 3.0
	var arena := get_parent()
	if multiplayer.has_multiplayer_peer():
		arena._spawn_wall.rpc(spawn_pos, rotation.y, ability.wall_duration)
	else:
		arena._spawn_wall(spawn_pos, rotation.y, ability.wall_duration)

func _execute_teleport_strike(ability: AbilityData) -> void:
	if not is_instance_valid(opponent):
		return
	var behind_dir := (opponent.global_position - global_position).normalized()
	global_position = opponent.global_position + behind_dir * 1.2
	look_at(Vector3(opponent.global_position.x, global_position.y, opponent.global_position.z), Vector3.UP)
	var dir := opponent.global_position - global_position
	opponent.take_damage(ability.damage, ability.element, dir, ability.knockback_force, ability.stagger_duration)
	_gain_special_meter()

func _execute_multi_hitscan(ability: AbilityData) -> void:
	for i in range(ability.multi_hit_count):
		_execute_hitscan(ability)
		if i < ability.multi_hit_count - 1:
			await get_tree().create_timer(ability.multi_hit_interval).timeout
			if not is_instance_valid(self) or is_queued_for_deletion():
				return

func _apply_burn(ability: AbilityData, target: Player) -> void:
	for i in range(ability.burn_ticks):
		await get_tree().create_timer(ability.burn_tick_interval).timeout
		if not is_instance_valid(target):
			return
		target.take_damage(ability.burn_damage_per_tick, ElementType.Type.FIRE)

func take_damage(amount: int, element: ElementType.Type = ElementType.Type.NONE, knockback_dir: Vector3 = Vector3.ZERO, knockback_force: float = 0.0, stagger_duration: float = 0.0) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_apply_damage.rpc(amount, element, knockback_dir, knockback_force, stagger_duration)
		else:
			_request_damage.rpc_id(1, amount, element, knockback_dir, knockback_force, stagger_duration)
	else:
		_apply_damage(amount, element, knockback_dir, knockback_force, stagger_duration)

@rpc("any_peer", "reliable")
func _request_damage(amount: int, element: ElementType.Type = ElementType.Type.NONE, knockback_dir: Vector3 = Vector3.ZERO, knockback_force: float = 0.0, stagger_duration: float = 0.0) -> void:
	if not multiplayer.is_server():
		return
	_apply_damage.rpc(amount, element, knockback_dir, knockback_force, stagger_duration)

func _hit_direction_anim(knockback_dir: Vector3) -> String:
	if knockback_dir.length() < 0.01:
		return HIT_ANIMS["front"]
	var hit_dir := -knockback_dir
	hit_dir.y = 0.0
	hit_dir = hit_dir.normalized()
	var forward_amount := hit_dir.dot(-global_transform.basis.z)
	var right_amount := hit_dir.dot(global_transform.basis.x)
	if abs(forward_amount) >= abs(right_amount):
		return HIT_ANIMS["front"] if forward_amount >= 0.0 else HIT_ANIMS["back"]
	return HIT_ANIMS["right"] if right_amount >= 0.0 else HIT_ANIMS["left"]

@rpc("call_local", "reliable", "any_peer")
func _apply_damage(amount: int, element: ElementType.Type = ElementType.Type.NONE, knockback_dir: Vector3 = Vector3.ZERO, knockback_force: float = 0.0, stagger_duration: float = 0.0) -> void:
	if is_invincible:
		return
	if is_shielded:
		return
	if is_blocking:
		amount = int(round(amount * (1.0 - block_ability.block_damage_reduction)))
	if damage_mitigation > 0.0:
		amount = int(round(amount * (1.0 - damage_mitigation)))
	last_hit_element = element
	stats.apply_damage(amount)
	damaged.emit(stats.current_hp)
	VFX.spawn_impact(get_parent(), global_position + Vector3(0, 1.0, 0), ElementType.get_color(element))
	if not cc_immune:
		if knockback_force > 0.0 and knockback_dir.length() > 0.01:
			var flat_dir := Vector3(knockback_dir.x, 0, knockback_dir.z).normalized()
			velocity += flat_dir * knockback_force
		if stagger_duration > 0.0:
			stagger_timer = max(stagger_timer, stagger_duration)
	if stats.is_dead():
		anim_player.play(ANIM_DEATH)
		died.emit()
	else:
		anim_player.play(_hit_direction_anim(knockback_dir))

func reset_player(spawn_position: Vector3) -> void:
	stats.reset()
	global_position = spawn_position
	velocity = Vector3.ZERO
	stagger_timer = 0.0
	is_blocking = false
	is_invincible = false
	_invincible_timer = 0.0
	_dodge_timer = 0.0
	is_shielded = false
	_shield_timer = 0.0
	damage_mitigation = 0.0
	_mitigation_timer = 0.0
	cc_immune = false
	_cc_immune_timer = 0.0
	is_repulsing = false
	_repulse_timer = 0.0
	_repulse_cooldown_timer = 0.0
	_last_attack_family = ""
	_attack_awaiting_second = false
	_combo_window_timer = 0.0
	special_meter = 0.0
	special_meter_changed.emit(special_meter, SPECIAL_METER_MAX)
	damaged.emit(stats.current_hp)
	anim_player.play(ANIM_IDLE)
