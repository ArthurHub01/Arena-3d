extends Control
class_name OrnateFrame

@export var accent_color: Color = Color(0.85, 0.63, 0.30, 1.0)
@export var corner_size: float = 16.0
@export var corner_inset: float = 6.0

func _draw() -> void:
	var r := Rect2(Vector2(corner_inset, corner_inset), size - Vector2(corner_inset, corner_inset) * 2.0)
	_corner(r.position, Vector2(1, 1))
	_corner(r.position + Vector2(r.size.x, 0), Vector2(-1, 1))
	_corner(r.position + Vector2(0, r.size.y), Vector2(1, -1))
	_corner(r.position + r.size, Vector2(-1, -1))

func _corner(p: Vector2, dir: Vector2) -> void:
	draw_line(p, p + Vector2(corner_size * dir.x, 0), accent_color, 1.5)
	draw_line(p, p + Vector2(0, corner_size * dir.y), accent_color, 1.5)
	draw_circle(p, 1.6, accent_color)
