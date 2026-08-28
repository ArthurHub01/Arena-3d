extends Control
class_name DiamondMenuIcon

@export var icon_color: Color = Color(0.85, 0.16, 0.16, 1.0)
@export var frame_color: Color = Color(0.55, 0.55, 0.6, 1.0)

func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 2.0

	# soft red glow behind the frame
	for i in range(4):
		var pad := float(i + 1) * 2.5
		var glow_alpha := 0.14 - i * 0.03
		var glow := _diamond(c, r + pad)
		draw_colored_polygon(glow, Color(icon_color.r, icon_color.g, icon_color.b, glow_alpha))

	# dark interior fill
	draw_colored_polygon(_diamond(c, r * 0.86), Color(0.04, 0.03, 0.03, 1.0))

	# beveled metal frame: two nested outlines
	var outer := _diamond(c, r)
	var inner := _diamond(c, r * 0.86)
	draw_polyline(outer + PackedVector2Array([outer[0]]), frame_color, 2.5, true)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(icon_color.r, icon_color.g, icon_color.b, 0.8), 1.5, true)

	# 3 glowing bars
	var bar_width := r * 0.95
	var bar_height := r * 0.16
	var gap := r * 0.34
	for i in range(3):
		var y := c.y + (i - 1) * gap
		var rect := Rect2(c.x - bar_width / 2.0, y - bar_height / 2.0, bar_width, bar_height)
		draw_rect(rect.grow(2.0), Color(icon_color.r, icon_color.g, icon_color.b, 0.35), true)
		draw_rect(rect, icon_color, true)
		draw_line(Vector2(rect.position.x + 2, y - bar_height * 0.15), Vector2(rect.position.x + rect.size.x - 2, y - bar_height * 0.15), Color(1, 0.75, 0.75, 0.6), 1.0)
