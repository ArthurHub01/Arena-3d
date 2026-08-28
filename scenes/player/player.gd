extends CharacterBody3D
class_name Player

signal damaged(current_hp: int)
signal died()

const SPEED := 6.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 9.8
const ARENA_RADIUS := 13.4
const MELEE_DAMAGE := 15
const MELEE_COOLDOWN := 0.6
const PROJECTILE_DAMAGE := 10
const PROJECTILE_COOLDOWN := 1.0

const CAMERA_DISTANCE := 5.0
const CAMERA_HEIGHT := 2.4
const LOOK_HEIGHT := 1.3
const CAMERA_LERP_SPEED := 6.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var melee_area: Area3D = $MeleeHitPoint/MeleeArea

var stats: CombatStats = CombatStats.new()
var is_local_player: bool = true
var opponent: Player = null
var melee_ready: bool = true
var projectile_ready: bool = true

var projectile_scene: PackedScene = preload("res://scenes/player/Projectile.tscn")

@rpc("unreliable_ordered", "call_remote")
func _remote_update_transform(pos: Vector3, rot_y: float) -> void:
	global_position = pos
	rotation.y = rot_y

func _ready() -> void:
	camera.current = is_local_player

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if event.is_action_pressed("attack_melee") and melee_ready:
		_do_melee_attack()
	if event.is_action_pressed("attack_ranged") and projectile_ready:
		_do_ranged_attack()

func _physics_process(delta: float) -> void:
	if not is_local_player:
		return

	var has_opponent := is_instance_valid(opponent)

	if has_opponent:
		var flat_target := Vector3(opponent.global_position.x, global_position.y, opponent.global_position.z)
		if flat_target.distance_to(global_position) > 0.01:
			look_at(flat_target, Vector3.UP)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()

	var horizontal := Vector2(global_position.x, global_position.z)
	if horizontal.length() > ARENA_RADIUS:
		horizontal = horizontal.normalized() * ARENA_RADIUS
		global_position.x = horizontal.x
		global_position.z = horizontal.y

	if has_opponent:
		_update_combat_camera(delta)

	if is_multiplayer_authority():
		_remote_update_transform.rpc(global_position, rotation.y)

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

func _do_melee_attack() -> void:
	melee_ready = false
	for body in melee_area.get_overlapping_bodies():
		if body is Player and body != self:
			body.take_damage(MELEE_DAMAGE)
	get_tree().create_timer(MELEE_COOLDOWN).timeout.connect(func(): melee_ready = true)

func _do_ranged_attack() -> void:
	projectile_ready = false
	var projectile: Projectile = projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_transform = muzzle_point.global_transform
	projectile.damage = PROJECTILE_DAMAGE
	projectile.shooter = self
	get_tree().create_timer(PROJECTILE_COOLDOWN).timeout.connect(func(): projectile_ready = true)

func take_damage(amount: int) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_apply_damage.rpc(amount)
	else:
		_apply_damage(amount)

@rpc("call_local", "reliable", "any_peer")
func _apply_damage(amount: int) -> void:
	stats.apply_damage(amount)
	damaged.emit(stats.current_hp)
	if stats.is_dead():
		died.emit()

func reset_player(spawn_position: Vector3) -> void:
	stats.reset()
	global_position = spawn_position
	velocity = Vector3.ZERO
	damaged.emit(stats.current_hp)
