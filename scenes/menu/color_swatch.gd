extends Control
class_name ColorSwatch

@export var swatch_color: Color = Color.WHITE
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, swatch_color, true)
	var border_color := Color(0.95, 0.72, 0.32, 1.0) if selected else Color(0.4, 0.34, 0.26, 1.0)
	draw_rect(rect, border_color, false, 2.5 if selected else 1.5)
