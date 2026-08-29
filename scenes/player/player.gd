extends CharacterBody3D
class_name Player

signal damaged(current_hp: int)
signal died()

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

var stats: CombatStats = CombatStats.new()
var is_local_player: bool = true
var is_ai_controlled: bool = false
var opponent: Player = null
var match_active: bool = false
var equipped_element: ElementType.Type = ElementType.Type.FIRE
var basic_ability: AbilityData = AbilityLibrary.get_basic_ability(ElementType.Type.FIRE)
var attack_ready: bool = true
var last_hit_element: ElementType.Type = ElementType.Type.NONE
var stagger_timer: float = 0.0
var _model_yaw_offset: float = 0.0
var _target_model_yaw_offset: float = 0.0

var projectile_scene: PackedScene = preload("res://scenes/player/Projectile.tscn")

func set_element(element: ElementType.Type) -> void:
	equipped_element = element
	basic_ability = AbilityLibrary.get_basic_ability(element)

@rpc("unreliable_ordered", "call_remote")
func _remote_update_transform(pos: Vector3, rot_y: float) -> void:
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
	if event.is_action_pressed("ability_basic") and attack_ready:
		_do_basic_attack()

func _physics_process(delta: float) -> void:
	if not (is_local_player or is_ai_controlled) or not match_active:
		return

	if stagger_timer > 0.0:
		stagger_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, SPEED * delta * 4.0)
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		_play_locomotion_anim(false)
		if is_multiplayer_authority() and multiplayer.has_multiplayer_peer():
			_remote_update_transform.rpc(global_position, rotation.y)
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
		_remote_update_transform.rpc(global_position, rotation.y)

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
		_do_basic_attack()

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

func _do_basic_attack() -> void:
	attack_ready = false
	var anim := basic_ability.anim_name if not basic_ability.anim_name.is_empty() else ANIM_PUNCH
	anim_player.play(anim)
	if multiplayer.has_multiplayer_peer():
		_show_attack_anim.rpc(anim)

	if not (is_ai_controlled and randf() < AI_MISS_CHANCE):
		match basic_ability.delivery:
			AbilityData.Delivery.MELEE:
				_execute_melee()
			AbilityData.Delivery.PROJECTILE:
				_execute_projectile()
			AbilityData.Delivery.HITSCAN:
				_execute_hitscan()

	get_tree().create_timer(basic_ability.cooldown).timeout.connect(func(): attack_ready = true)

func _ai_aim_spread_rad() -> float:
	return deg_to_rad(randf_range(-AI_AIM_SPREAD_DEGREES, AI_AIM_SPREAD_DEGREES))

@rpc("unreliable_ordered", "call_remote")
func _show_attack_anim(anim: String) -> void:
	anim_player.play(anim)

func _execute_melee() -> void:
	melee_area.get_child(0).shape.radius = basic_ability.melee_range
	for body in melee_area.get_overlapping_bodies():
		if body is Player and body != self:
			var dir := (body.global_position - global_position)
			body.take_damage(basic_ability.damage, basic_ability.element, dir, basic_ability.knockback_force, basic_ability.stagger_duration)

func _execute_projectile() -> void:
	var projectile: Projectile = projectile_scene.instantiate()
	projectile.damage = basic_ability.damage
	projectile.element = basic_ability.element
	projectile.speed = basic_ability.projectile_speed
	projectile.lifetime = basic_ability.projectile_lifetime
	projectile.knockback_force = basic_ability.knockback_force
	projectile.stagger_duration = basic_ability.stagger_duration
	projectile.shooter = self
	get_parent().add_child(projectile)
	projectile.global_transform = muzzle_point.global_transform
	if is_ai_controlled:
		projectile.rotate_y(_ai_aim_spread_rad())

func _execute_hitscan() -> void:
	var from := muzzle_point.global_position
	var aim_dir := -global_transform.basis.z
	if is_ai_controlled:
		aim_dir = aim_dir.rotated(Vector3.UP, _ai_aim_spread_rad())
	var to := from + aim_dir * basic_ability.hitscan_range

	if basic_ability.hitscan_delay > 0.0:
		await get_tree().create_timer(basic_ability.hitscan_delay).timeout
	if not is_instance_valid(self) or is_queued_for_deletion():
		return

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 2)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result and result.collider is Player and result.collider != self:
		var target: Player = result.collider
		var dir := (target.global_position - global_position)
		target.take_damage(basic_ability.damage, basic_ability.element, dir, basic_ability.knockback_force, basic_ability.stagger_duration)

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
	last_hit_element = element
	stats.apply_damage(amount)
	damaged.emit(stats.current_hp)
	VFX.spawn_impact(get_parent(), global_position + Vector3(0, 1.0, 0), ElementType.get_color(element))
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
	damaged.emit(stats.current_hp)
	anim_player.play(ANIM_IDLE)
