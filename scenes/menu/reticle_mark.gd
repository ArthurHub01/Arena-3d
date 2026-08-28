extends Control
class_name ReticleMark

@export var ring_color: Color = Color(0.85, 0.63, 0.30, 1.0)
@export var line_width: float = 1.5
@export var pulse: bool = true

var _t := 0.0

func _process(delta: float) -> void:
	if not pulse:
		return
	_t += delta
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0
	var r: float = min(size.x, size.y) / 2.0 - line_width
	var pulse_alpha := 1.0
	if pulse:
		pulse_alpha = 0.65 + 0.35 * sin(_t * 1.4)
	var col := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * pulse_alpha)

	draw_arc(c, r, 0, TAU, 48, col, line_width, true)

	var tick: float = r * 0.32
	draw_line(c + Vector2(0, -r - line_width), c + Vector2(0, -r + tick), col, line_width)
	draw_line(c + Vector2(0, r + line_width), c + Vector2(0, r - tick), col, line_width)
	draw_line(c + Vector2(-r - line_width, 0), c + Vector2(-r + tick, 0), col, line_width)
	draw_line(c + Vector2(r + line_width, 0), c + Vector2(r - tick, 0), col, line_width)

	var d: float = r * 0.12
	var points := PackedVector2Array([
		c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)
	])
	draw_colored_polygon(points, col)
