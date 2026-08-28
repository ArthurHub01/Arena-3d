extends Control
class_name HeartbeatIcon

@export var icon_color: Color = Color(0.85, 0.16, 0.16, 1.0)
@export var frame_color: Color = Color(0.55, 0.55, 0.6, 1.0)

func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - 2.0

	for i in range(4):
		var pad := float(i + 1) * 2.5
		var glow_alpha := 0.14 - i * 0.03
		draw_colored_polygon(_diamond(c, r + pad), Color(icon_color.r, icon_color.g, icon_color.b, glow_alpha))

	draw_colored_polygon(_diamond(c, r * 0.86), Color(0.04, 0.03, 0.03, 1.0))

	var outer := _diamond(c, r)
	var inner := _diamond(c, r * 0.86)
	draw_polyline(outer + PackedVector2Array([outer[0]]), frame_color, 2.5, true)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(icon_color.r, icon_color.g, icon_color.b, 0.8), 1.5, true)

	var w := r * 0.9
	var pulse := PackedVector2Array([
		c + Vector2(-w * 0.5, 0),
		c + Vector2(-w * 0.22, 0),
		c + Vector2(-w * 0.08, -w * 0.42),
		c + Vector2(w * 0.05, w * 0.42),
		c + Vector2(w * 0.16, -w * 0.14),
		c + Vector2(w * 0.5, -w * 0.14),
	])
	draw_polyline(pulse, Color(1, 0.55, 0.55, 0.5), 4.0, true)
	draw_polyline(pulse, icon_color, 2.0, true)
