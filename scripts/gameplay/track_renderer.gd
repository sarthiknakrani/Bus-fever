extends Node2D
class_name CarJamTrackRenderer

var curve: Curve2D

func _draw() -> void:
	if curve == null: return
	
	# Generate high-res points for smooth drawing
	var points = curve.get_baked_points()
	
	var shadow_pts = points.duplicate()
	for i in shadow_pts.size():
		shadow_pts[i] += Vector2(0, 8)
		
	# Helper to draw a bulletproof thick line (handles overlapping joints safely)
	# Use SOLID colors to avoid extreme brightening from overlapping alpha joints
	var bg_shadow = Color("0284c7").darkened(0.5) # Solid dark tone for shadow
	_draw_thick_path(shadow_pts, bg_shadow, 68.0)
	_draw_thick_path(points, Color("475569"), 66.0) # Dark slate border
	_draw_thick_path(points, Color("64748b"), 58.0) # Medium grey track
	_draw_thick_path(points, Color("94a3b8"), 52.0) # Light inner highlight

func _draw_thick_path(pts: PackedVector2Array, color: Color, width: float) -> void:
	var radius = width / 2.0
	# Draw circles at vertices for perfect rounded joints
	for pt in pts:
		draw_circle(pt, radius, color)
	
	# Draw thick lines between vertices
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i+1], color, width)

