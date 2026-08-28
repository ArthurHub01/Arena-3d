extends Control
class_name ElementIcon

@export var element: ElementType.Type = ElementType.Type.FIRE
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()

func _get_element_color() -> Color:
	match element:
		ElementType.Type.FIRE:
			return Color(0.95, 0.38, 0.12, 1.0)
		ElementType.Type.WATER:
			return Color(0.28, 0.56, 0.92, 1.0)
		ElementType.Type.EARTH:
			return Color(0.55, 0.40, 0.20, 1.0)
		ElementType.Type.AIR:
			return Color(0.80, 0.88, 0.86, 1.0)
		ElementType.Type.LIGHTNING:
			return Color(0.95, 0.85, 0.28, 1.0)
		_:
			return Color(0.7, 0.7, 0.7, 1.0)

func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 2.0
	var col := _get_element_color()
	var frame_color := col if selected else Color(0.4, 0.34, 0.26, 1.0)
	var glow_layers := 4 if selected else 1

	for i in range(glow_layers):
		var pad := float(i + 1) * 2.5
		var glow_alpha := 0.16 - i * 0.03
		draw_colored_polygon(_diamond(c, r + pad), Color(col.r, col.g, col.b, glow_alpha))

	draw_colored_polygon(_diamond(c, r * 0.86), Color(0.05, 0.04, 0.03, 1.0))

	var outer := _diamond(c, r)
	var inner := _diamond(c, r * 0.82)
	draw_polyline(outer + PackedVector2Array([outer[0]]), frame_color, 2.5 if selected else 1.5, true)

	_draw_glyph(c, r * 0.5, col)

func _draw_glyph(c: Vector2, r: float, col: Color) -> void:
	match element:
		ElementType.Type.FIRE:
			var flame := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.55, -r * 0.1), c + Vector2(r * 0.3, r * 0.3),
				c + Vector2(0, r), c + Vector2(-r * 0.3, r * 0.3), c + Vector2(-r * 0.55, -r * 0.1),
			])
			draw_colored_polygon(flame, col)
		ElementType.Type.WATER:
			var drop := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.3), c + Vector2(r * 0.4, r),
				c + Vector2(-r * 0.4, r), c + Vector2(-r * 0.7, r * 0.3),
			])
			draw_colored_polygon(drop, col)
		ElementType.Type.EARTH:
			var mountain := PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.85, r * 0.85), c + Vector2(-r * 0.85, r * 0.85),
			])
			draw_colored_polygon(mountain, col)
		ElementType.Type.AIR:
			for i in range(3):
				var yy := c.y + (i - 1) * r * 0.45
				var start_x := c.x - r * (0.9 - i * 0.15)
				var end_x := c.x + r * (0.6 - i * 0.1)
				draw_line(Vector2(start_x, yy), Vector2(end_x, yy), col, 2.0)
				draw_line(Vector2(end_x, yy), Vector2(end_x - r * 0.15, yy - r * 0.15), col, 2.0)
		ElementType.Type.LIGHTNING:
			var bolt := PackedVector2Array([
				c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.35, r * 0.1), c + Vector2(r * 0.05, r * 0.1),
				c + Vector2(-r * 0.15, r), c + Vector2(r * 0.35, -r * 0.1), c + Vector2(-r * 0.05, -r * 0.1),
			])
			draw_colored_polygon(bolt, col)
