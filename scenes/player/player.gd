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
const MOUSE_SENSITIVITY := 0.003

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var muzzle_point: Marker3D = $MuzzlePoint
@onready var melee_area: Area3D = $MeleeHitPoint/MeleeArea

var stats: CombatStats = CombatStats.new()
var is_local_player: bool = true
var melee_ready: bool = true
var projectile_ready: bool = true

var projectile_scene: PackedScene = preload("res://scenes/player/Projectile.tscn")

@rpc("unreliable_ordered", "call_remote")
func _remote_update_transform(pos: Vector3, rot_y: float, pivot_rot_x: float) -> void:
	global_position = pos
	rotation.y = rot_y
	camera_pivot.rotation.x = pivot_rot_x

func _ready() -> void:
	camera.current = is_local_player

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -1.2, 1.2)
	if event.is_action_pressed("attack_melee") and melee_ready:
		_do_melee_attack()
	if event.is_action_pressed("attack_ranged") and projectile_ready:
		_do_ranged_attack()

func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
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

	if is_multiplayer_authority():
		_remote_update_transform.rpc(global_position, rotation.y, camera_pivot.rotation.x)

func _do_melee_attack() -> void:
	melee_ready = false
	for body in melee_area.get_overlapping_bodies():
		if body is Player and body != self:
			body.take_damage(MELEE_DAMAGE)
	get_tree().create_timer(MELEE_COOLDOWN).timeout.connect(func(): melee_ready = true)

func _do_ranged_attack() -> void:
	projectile_ready = false
	var projectile = projectile_scene.instantiate()
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
