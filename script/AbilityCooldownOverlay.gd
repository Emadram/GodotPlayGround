extends Control
class_name AbilityCooldownRing
## Radial darkening for ability cooldown (remaining fraction of circle, clockwise from 12 o'clock).

var _remaining_ratio: float = 0.0


func set_remaining_ratio(ratio: float) -> void:
	_remaining_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _remaining_ratio <= 0.001:
		return
	var center := size * 0.5
	var radius: float = minf(center.x, center.y) - 2.0
	if radius < 2.0:
		return
	var from := -PI * 0.5
	var to := from + _remaining_ratio * TAU
	var poly := _arc_wedge(center, radius, from, to, 28)
	if poly.size() >= 3:
		draw_colored_polygon(poly, Color(0.05, 0.05, 0.08, 0.62))


func _arc_wedge(center: Vector2, radius: float, from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(center)
	var span: float = to_angle - from_angle
	var n: int = maxi(steps, 3)
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var a: float = from_angle + span * t
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
