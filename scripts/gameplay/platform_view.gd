extends Node2D
class_name PlatformView

# Compatibility properties
var p_top: float = -500.0
var p_bottom: float = 2000.0
var p_width: float = 2000.0
var p_partition_y: float = 0.0
var p_separator_y: float = -9999.0
var p_deck_w: float = 580.0

# Unified upper gameplay platform properties
var p_track_y: float = -330.0
var p_parking_y: float = -60.0
var p_parking_h: float = 94.0
var p_slot_spacing: float = 65.0
var p_slots_count: int = 7
var is_unified: bool = false

## Sets up the authoritative unified upper gameplay platform deck encompassing
## the oval passenger track, central plaza island, feeder overpass, boarding concourse,
## and parking bay platform in one continuous lavender-grey architectural structure.
func setup_unified(
	track_y: float,
	parking_y: float,
	parking_h: float,
	bottom_y: float,
	w: float,
	partition_y: float,
	separator_y: float = -9999.0,
	slot_spacing: float = 65.0,
	slots_count: int = 7
) -> void:
	p_track_y = track_y
	p_parking_y = parking_y
	p_parking_h = parking_h
	p_bottom = bottom_y
	p_width = w
	p_partition_y = partition_y
	p_separator_y = separator_y
	p_slot_spacing = slot_spacing
	p_slots_count = slots_count
	is_unified = true
	
	# Maintain legacy properties for external inspection / compatibility
	p_top = track_y - 225.0
	p_deck_w = maxf(500.0, float(slots_count - 1) * slot_spacing + 53.0 + 45.0)
	queue_redraw()

## Legacy initialization wrapper preserved for backwards compatibility and test suites
func setup_full(top_y: float, bottom_y: float, w: float, partition_y: float, separator_y: float = -9999.0, deck_w: float = 580.0) -> void:
	p_top = top_y
	p_bottom = bottom_y
	p_width = w
	p_partition_y = partition_y
	p_separator_y = separator_y
	p_deck_w = deck_w
	is_unified = false
	queue_redraw()

func _draw() -> void:
	# 1. Authoritative material palette (cohesive lavender-grey road & platform system)
	var base_grey := Color("d1d5e6") # Approved lavender-grey base material
	var concourse_grey := Color("cbd0e2") # Pedestrian concourse pavement
	var island_grey := Color("c2c7da") # Central plaza island fill
	var curb_highlight := Color("ffffff", 0.85) # Top specular edge
	var curb_shadow := Color("a5abc2") # Subtle outer shadow bevel
	var curb_deep := Color("8c93a8") # Crisp recessed border
	var drop_shadow := Color(0.12, 0.16, 0.26, 0.20) # Soft 3D deck elevation shadow

	var hw: float = p_width / 2.0
	var sep_y: float = p_separator_y
	var gy: float = p_partition_y

	if not is_unified:
		# Fallback legacy drawing
		_draw_legacy(base_grey, curb_highlight, curb_shadow, curb_deep, hw, gy, sep_y)
		return

	# 2. Unified Geometry Calculations
	var top_y: float = p_track_y - 225.0
	var track_hw: float = 380.0 # Platform half-width around oval track (760px total, enclosing 702px track)
	var corner_r: float = 38.0 # Rounded top platform corners
	
	var parking_hw: float = float(p_slots_count - 1) * p_slot_spacing / 2.0 + 53.0 / 2.0 + 20.0 # ~242px
	var parking_top: float = p_parking_y - (p_parking_h / 2.0) - 15.0
	var parking_bottom: float = p_parking_y + (p_parking_h / 2.0) + 12.0
	var corridor_y_start: float = p_track_y + 160.0
	var slope_w: float = 75.0
	var feeder_reach_x: float = maxf(hw + 80.0, 750.0)

	# 3. Feeder Overpass Ramp Polygon (branches offscreen to upper-right)
	var feeder_ramp_pts := PackedVector2Array([
		Vector2(260.0, p_track_y + 40.0),
		Vector2(330.0, p_track_y - 15.0),
		Vector2(410.0, p_track_y - 120.0),
		Vector2(520.0, p_track_y - 250.0),
		Vector2(feeder_reach_x, p_track_y - 520.0),
		Vector2(feeder_reach_x, p_track_y - 320.0),
		Vector2(490.0, p_track_y - 70.0),
		Vector2(380.0, p_track_y + 60.0)
	])

	# 4. Main Continuous Platform Polygon
	var main_deck_pts := PackedVector2Array()
	# Screen bottom-left & left horizon partition
	main_deck_pts.append(Vector2(-hw, p_bottom))
	main_deck_pts.append(Vector2(-hw, gy))
	main_deck_pts.append(Vector2(-parking_hw - slope_w, gy))
	main_deck_pts.append(Vector2(-parking_hw, parking_bottom))
	main_deck_pts.append(Vector2(-parking_hw, parking_top))
	
	# Concourse expansion up to track deck
	main_deck_pts.append(Vector2(-track_hw, corridor_y_start))
	main_deck_pts.append(Vector2(-track_hw, top_y + corner_r))
	
	# Rounded Top-Left Corner
	for step in range(1, 8):
		var ang := PI + float(step) / 8.0 * (PI / 2.0)
		var cx := -track_hw + corner_r + cos(ang) * corner_r
		var cy := top_y + corner_r + sin(ang) * corner_r
		main_deck_pts.append(Vector2(cx, cy))
		
	# Top Horizontal Edge
	main_deck_pts.append(Vector2(track_hw - corner_r, top_y))
	
	# Rounded Top-Right Corner
	for step in range(1, 8):
		var ang := 1.5 * PI + float(step) / 8.0 * (PI / 2.0)
		var cx := track_hw - corner_r + cos(ang) * corner_r
		var cy := top_y + corner_r + sin(ang) * corner_r
		main_deck_pts.append(Vector2(cx, cy))
		
	# Right track deck edge down to concourse
	main_deck_pts.append(Vector2(track_hw, corridor_y_start))
	main_deck_pts.append(Vector2(parking_hw, parking_top))
	main_deck_pts.append(Vector2(parking_hw, parking_bottom))
	main_deck_pts.append(Vector2(parking_hw + slope_w, gy))
	main_deck_pts.append(Vector2(hw, gy))
	main_deck_pts.append(Vector2(hw, p_bottom))

	# 5. Draw Shadows FIRST (ensures no shadow overlaps platform fills)
	var f_shadow := PackedVector2Array()
	for pt in feeder_ramp_pts:
		f_shadow.append(pt + Vector2(0, 8))
	draw_colored_polygon(f_shadow, drop_shadow)

	var shadow_deck_pts := PackedVector2Array()
	for pt in main_deck_pts:
		shadow_deck_pts.append(pt + Vector2(0, 8))
	draw_colored_polygon(shadow_deck_pts, drop_shadow)

	# 6. Draw Base Grey Fills SECOND
	draw_colored_polygon(feeder_ramp_pts, base_grey)
	draw_colored_polygon(main_deck_pts, base_grey)

	# 7. Central Plaza Island (fills the hollow inner hole inside the oval track)
	# Oval inner hole is a capsule from x=-155 to +155 with R=34 semicircular ends at y=p_track_y
	var island_r := 36.0
	var island_cx := 155.0
	var island_pts := PackedVector2Array()
	# Top edge
	island_pts.append(Vector2(-island_cx, p_track_y - island_r))
	island_pts.append(Vector2(island_cx, p_track_y - island_r))
	# Right cap
	for step in range(1, 12):
		var ang := -PI / 2.0 + float(step) / 12.0 * PI
		island_pts.append(Vector2(island_cx + cos(ang) * island_r, p_track_y + sin(ang) * island_r))
	# Bottom edge
	island_pts.append(Vector2(island_cx, p_track_y + island_r))
	island_pts.append(Vector2(-island_cx, p_track_y + island_r))
	# Left cap
	for step in range(1, 12):
		var ang := PI / 2.0 + float(step) / 12.0 * PI
		island_pts.append(Vector2(-island_cx + cos(ang) * island_r, p_track_y + sin(ang) * island_r))
		
	# Fill Central Plaza Island
	draw_colored_polygon(island_pts, island_grey)
	# Central Island 3D Curb Inner Bevel
	draw_polyline(island_pts, curb_deep, 2.5, true)
	draw_polyline(island_pts, curb_shadow, 1.5, true)

	# 8. Boarding Concourse Apron & Passenger-to-Parking Walkways
	var concourse_top: float = p_track_y + 190.0
	var concourse_bot: float = p_parking_y - (p_parking_h / 2.0) - 2.0
	if concourse_bot > concourse_top:
		var apron_w: float = (parking_hw - 8.0) * 2.0
		var apron_rect := Rect2(-parking_hw + 8.0, concourse_top, apron_w, concourse_bot - concourse_top)
		
		# Concourse Pavement Background
		var sb_apron = StyleBoxFlat.new()
		sb_apron.bg_color = concourse_grey
		sb_apron.set_corner_radius_all(10)
		sb_apron.border_width_top = 2
		sb_apron.border_width_bottom = 2
		sb_apron.border_color = curb_shadow
		sb_apron.draw(get_canvas_item(), apron_rect)

		# Distinct Passenger Boarding Corridor for Each Slot
		for i in range(p_slots_count):
			var slot_x: float = -float(p_slots_count - 1) * p_slot_spacing / 2.0 + float(i) * p_slot_spacing
			var path_w: float = 34.0
			var path_h: float = concourse_bot - concourse_top - 4.0
			var path_rect := Rect2(slot_x - path_w / 2.0, concourse_top + 2.0, path_w, path_h)
			
			# Walkway strip
			draw_rect(path_rect, Color("ffffff", 0.12))
			
			# Clean dashed zebra pedestrian crossing stripes leading straight into each bay
			var stripe_y: float = concourse_top + 7.0
			while stripe_y < concourse_bot - 4.0:
				draw_line(
					Vector2(slot_x - 12.0, stripe_y),
					Vector2(slot_x + 12.0, stripe_y),
					Color("ffffff", 0.42),
					2.5
				)
				stripe_y += 8.0
				
			# Boarding Entrance Indicator Marker at track disembarkation point
			var indicator_y = concourse_top + 2.5
			var arrow_pts = PackedVector2Array([
				Vector2(slot_x - 5.0, indicator_y),
				Vector2(slot_x + 5.0, indicator_y),
				Vector2(slot_x, indicator_y + 4.0)
			])
			draw_colored_polygon(arrow_pts, Color("ffffff", 0.70))

	# 9. 3D Beveled Curb Perimeter outlining the upper platform
	var top_edge := PackedVector2Array()
	top_edge.append(Vector2(-hw, gy))
	top_edge.append(Vector2(-parking_hw - slope_w, gy))
	top_edge.append(Vector2(-parking_hw, parking_bottom))
	top_edge.append(Vector2(-parking_hw, parking_top))
	top_edge.append(Vector2(-track_hw, corridor_y_start))
	top_edge.append(Vector2(-track_hw, top_y + corner_r))
	for step in range(1, 8):
		var ang := PI + float(step) / 8.0 * (PI / 2.0)
		top_edge.append(Vector2(-track_hw + corner_r + cos(ang) * corner_r, top_y + corner_r + sin(ang) * corner_r))
	top_edge.append(Vector2(track_hw - corner_r, top_y))
	for step in range(1, 8):
		var ang := 1.5 * PI + float(step) / 8.0 * (PI / 2.0)
		top_edge.append(Vector2(track_hw - corner_r + cos(ang) * corner_r, top_y + corner_r + sin(ang) * corner_r))
	
	# Upper feeder ramp curb
	top_edge.append(Vector2(410.0, p_track_y - 120.0))
	top_edge.append(Vector2(520.0, p_track_y - 250.0))
	top_edge.append(Vector2(feeder_reach_x, p_track_y - 520.0))

	# Lower feeder ramp curb returning into deck
	var lower_feeder_edge := PackedVector2Array()
	lower_feeder_edge.append(Vector2(feeder_reach_x, p_track_y - 320.0))
	lower_feeder_edge.append(Vector2(490.0, p_track_y - 70.0))
	lower_feeder_edge.append(Vector2(380.0, p_track_y + 60.0))
	lower_feeder_edge.append(Vector2(track_hw, corridor_y_start))
	lower_feeder_edge.append(Vector2(parking_hw, parking_top))
	lower_feeder_edge.append(Vector2(parking_hw, parking_bottom))
	lower_feeder_edge.append(Vector2(parking_hw + slope_w, gy))
	lower_feeder_edge.append(Vector2(hw, gy))

	draw_polyline(top_edge, curb_shadow, 4.0, true)
	draw_polyline(top_edge, curb_deep, 2.5, true)
	draw_polyline(top_edge, curb_highlight, 1.5, true)

	draw_polyline(lower_feeder_edge, curb_shadow, 4.0, true)
	draw_polyline(lower_feeder_edge, curb_deep, 2.5, true)
	draw_polyline(lower_feeder_edge, curb_highlight, 1.5, true)

	# 10. Subtle road turning corridor shading below parking bays
	if sep_y > gy:
		draw_rect(Rect2(-hw, gy, p_width, sep_y - gy), Color(0.79, 0.81, 0.88, 0.22))

	# 11. Authoritative Road Divider / Separator line (clean division above puzzle board)
	if sep_y > -9000.0:
		draw_rect(Rect2(-hw, sep_y, p_width, 2.5), curb_shadow)
		draw_rect(Rect2(-hw, sep_y + 2.5, p_width, 2.0), curb_deep)
		draw_rect(Rect2(-hw, sep_y + 4.5, p_width, 2.0), curb_highlight)

func _draw_legacy(base_grey: Color, curb_highlight: Color, curb_shadow: Color, curb_deep: Color, hw: float, gy: float, sep_y: float) -> void:
	var hill_w: float = p_deck_w
	var slope_w: float = 75.0
	var points = PackedVector2Array([
		Vector2(-hw, p_bottom),
		Vector2(-hw, gy),
		Vector2(-hill_w / 2.0 - slope_w, gy),
		Vector2(-hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0 + slope_w, gy),
		Vector2(hw, gy),
		Vector2(hw, p_bottom)
	])
	draw_colored_polygon(points, base_grey)
	if sep_y > gy:
		draw_rect(Rect2(-hw, gy, p_width, sep_y - gy), Color(0.79, 0.81, 0.88, 0.22))
	var top_edge = PackedVector2Array([
		Vector2(-hw, gy),
		Vector2(-hill_w / 2.0 - slope_w, gy),
		Vector2(-hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0, p_top),
		Vector2(hill_w / 2.0 + slope_w, gy),
		Vector2(hw, gy)
	])
	draw_polyline(top_edge, curb_shadow, 4.0, true)
	draw_polyline(top_edge, curb_deep, 2.5, true)
	draw_polyline(top_edge, curb_highlight, 1.5, true)
	if sep_y > -9000.0:
		draw_rect(Rect2(-hw, sep_y, p_width, 2.5), curb_shadow)
		draw_rect(Rect2(-hw, sep_y + 2.5, p_width, 2.0), curb_deep)
		draw_rect(Rect2(-hw, sep_y + 4.5, p_width, 2.0), curb_highlight)
