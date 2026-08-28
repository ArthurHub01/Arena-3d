extends Area3D
class_name Projectile

var speed: float = 15.0
var damage: int = 10
var shooter: Player = null
var lifetime: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_translate(-global_transform.basis.z * speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body is Player and body != shooter:
		body.take_damage(damage)
		queue_free()
