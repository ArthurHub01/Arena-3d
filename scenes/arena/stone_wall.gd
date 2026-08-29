extends StaticBody3D
class_name StoneWall

func setup(duration: float) -> void:
	get_tree().create_timer(duration).timeout.connect(queue_free)
