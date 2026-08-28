extends Control
class_name ChevronBar

@export var mirrored: bool = false
@export var fill_color: Color = Color(0.85, 0.16, 0.16, 1.0)
@export var bg_color: Color = Color(0.05, 0.05, 0.06, 1.0)
@export var border_color: Color = Color(0.6, 0.6, 0.65, 1.0)

var max_value: float = 100.0:
	set(v):
		max_value = v
		queue_redraw()
var value: float = 100.0:
	set(v):
		value = v
		queue_redraw()

func _get_ratio() -> float:
	if max_value <= 0.0:
		return 0.0
	return clamp(value / max_value, 0.0, 1.0)

func _mirror_x(points: PackedVector2Array, w: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(Vector2(w - p.x, p.y))
	return out

func _draw() -> void:
	var w := size.x
	var h := size.y
	var point := h * 0.55

	var bg_points := PackedVector2Array([
		Vector2(0, 1), Vector2(w - point, 1), Vector2(w - 1, h * 0.5), Vector2(w - point, h - 1), Vector2(0, h - 1)
	])
	if mirrored:
		bg_points = _mirror_x(bg_points, w)

	# soft outer glow
	for i in range(3):
		var glow_alpha := 0.10 - i * 0.03
		var pad := float(i + 1) * 2.0
		var glow_points := PackedVector2Array([
			Vector2(-pad, 1 - pad), Vector2(w - point, 1 - pad), Vector2(w - 1 + pad, h * 0.5), Vector2(w - point, h - 1 + pad), Vector2(-pad, h - 1 + pad)
		])
		if mirrored:
			glow_points = _mirror_x(glow_points, w)
		draw_colored_polygon(glow_points, Color(fill_color.r, fill_color.g, fill_color.b, glow_alpha))

	draw_colored_polygon(bg_points, bg_color)
	draw_polyline(bg_points + PackedVector2Array([bg_points[0]]), border_color, 1.5, true)

	var ratio := _get_ratio()
	if ratio <= 0.0:
		return

	var track := w - point
	var fill_w := track * ratio
	var skew := h * 0.3

	var fill_points: PackedVector2Array
	if not mirrored:
		fill_points = PackedVector2Array([
			Vector2(0, 2), Vector2(fill_w + skew, 2), Vector2(fill_w - skew, h - 2), Vector2(0, h - 2)
		])
	else:
		fill_points = PackedVector2Array([
			Vector2(w, 2), Vector2(w - fill_w - skew, 2), Vector2(w - fill_w + skew, h - 2), Vector2(w, h - 2)
		])
	draw_colored_polygon(fill_points, fill_color)

	var highlight_color := Color(1, 0.7, 0.7, 0.5)
	if not mirrored:
		draw_line(Vector2(2, h * 0.32), Vector2(fill_w - skew * 0.5, h * 0.32), highlight_color, 1.5)
	else:
		draw_line(Vector2(w - 2, h * 0.32), Vector2(w - fill_w + skew * 0.5, h * 0.32), highlight_color, 1.5)
