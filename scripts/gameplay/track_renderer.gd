extends Node2D
class_name CarJamTrackRenderer

var curve: Curve2D

func _draw() -> void:
	if curve == null: return
	
	# Generate high-res points for smooth drawing
	var points = PackedVector2Array()
	var steps = 128
	for i in steps + 1:
		var t = float(i) / steps * TAU
		points.append(Vector2(cos(t) * 270, sin(t) * 90))
	
	var shadow_pts = points.duplicate()
	for i in shadow_pts.size():
		shadow_pts[i] += Vector2(0, 8)
		
	# Helper to draw a bulletproof thick line (handles overlapping joints safely)
	_draw_thick_path(shadow_pts, Color(0, 0, 0, 0.15), 68.0)
	_draw_thick_path(points, Color("64748b"), 66.0)
	_draw_thick_path(points, Color("94a3b8"), 58.0)
	_draw_thick_path(points, Color(1, 1, 1, 0.15), 52.0) # subtle inner highlight

func _draw_thick_path(pts: PackedVector2Array, color: Color, width: float) -> void:
	var radius = width / 2.0
	# Draw circles at vertices for perfect rounded joints
	for pt in pts:
		draw_circle(pt, radius, color)
	
	# Draw thick lines between vertices
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i+1], color, width)

