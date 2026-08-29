extends StaticBody3D
class_name StoneWall

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	mesh_instance.mesh = mesh_instance.mesh.duplicate()
	mesh_instance.mesh.material = AbilityVFX.rock_material()

func setup(duration: float) -> void:
	get_tree().create_timer(duration).timeout.connect(queue_free)
