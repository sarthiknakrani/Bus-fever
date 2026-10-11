extends Node2D
class_name CarJamTrackRenderer

var curve: Curve2D
var feeder_curve: Curve2D

func _draw() -> void:
	# 1. Background Shadows (Solid dark tone for clean shadow without excessive alpha buildup)
	var bg_shadow = Color("0284c7").darkened(0.55)
	
	if feeder_curve != null:
		var f_pts = feeder_curve.get_baked_points()
		var f_shadow = f_pts.duplicate()
		for i in f_shadow.size():
			f_shadow[i] += Vector2(0, 8)
		_draw_thick_path(f_shadow, bg_shadow, 168.0)
		
	if curve != null:
		var points = curve.get_baked_points()
		var shadow_pts = points.duplicate()
		for i in shadow_pts.size():
			shadow_pts[i] += Vector2(0, 8)
		_draw_thick_path(shadow_pts, bg_shadow, 168.0)

	# 2. Feeder Track Layers (drawn first so loop overlays cleanly at merge point)
	if feeder_curve != null:
		var f_pts = feeder_curve.get_baked_points()
		_draw_thick_path(f_pts, Color("475569"), 162.0) # Dark slate border
		_draw_thick_path(f_pts, Color("64748b"), 150.0) # Medium grey track
		_draw_thick_path(f_pts, Color("94a3b8"), 140.0) # Light inner highlight
		
		# Entrance Gate at feeder start point
		if f_pts.size() > 0:
			var entrance_pt = f_pts[0]
			# Stylish entrance threshold arch / pill matching 150px track width
			draw_circle(entrance_pt + Vector2(0, 6), 56.0, Color(0, 0, 0, 0.3))
			draw_circle(entrance_pt, 54.0, Color("334155"))
			draw_circle(entrance_pt, 48.0, Color("64748b"))
			draw_circle(entrance_pt, 40.0, Color("f8fafc"))
			# Direction arrow pointing down-left into the track
			var arrow_col = Color("38bdf8")
			var p1 = entrance_pt + Vector2(16, -16)
			var p2 = entrance_pt + Vector2(-12, 12)
			draw_line(p1, p2, arrow_col, 6.0)
			draw_line(p2, p2 + Vector2(18, 0), arrow_col, 6.0)
			draw_line(p2, p2 + Vector2(0, -18), arrow_col, 6.0)

	# 3. Main Circular Loop Layers
	if curve != null:
		var points = curve.get_baked_points()
		_draw_thick_path(points, Color("475569"), 162.0) # Dark slate border
		_draw_thick_path(points, Color("64748b"), 150.0) # Medium grey track
		_draw_thick_path(points, Color("94a3b8"), 140.0) # Light inner highlight

func _draw_thick_path(pts: PackedVector2Array, color: Color, width: float) -> void:
	var radius = width / 2.0
	# Draw circles at vertices for perfect rounded joints
	for pt in pts:
		draw_circle(pt, radius, color)
	
	# Draw thick lines between vertices
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i+1], color, width)

