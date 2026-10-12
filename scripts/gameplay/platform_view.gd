extends Node2D
class_name PlatformView

# Compatibility properties preserved for external inspection and tests
var p_top: float = -2000.0
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
var is_unified: bool = true

## Sets up the authoritative unified grey upper gameplay ground encompassing
## the entire upper environment: behind Level title, surrounding oval track,
## central plaza island, feeder roadway foundation, connecting boarding forecourt,
## parking bays, and the turning road corridor down to the separator line.
func setup_unified(
	track_y: float,
	parking_y: float,
	parking_h: float,
	bottom_y: float,
	w: float,
	partition_y: float,
	separator_y: float = -9999.0,
	slot_spacing: float = 65.0,
	slots_count: int = 7,
	top_y: float = -99999.0
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
	
	# Full viewport-responsive top coverage (extends above top of screen behind HUD)
	if top_y > -90000.0:
		p_top = top_y
	else:
		p_top = track_y - 450.0 # Safe default extending well above the track
		
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
	# Authoritative slate-grey material palette matching the track road system
	var ground_grey := Color("cbd5e1")     # Slate 300: Unified upper ground tarmac
	var forecourt_grey := Color("bfc9d8")  # Slate 350: Connecting boarding forecourt pavement
	var plaza_grey := Color("c5cee0")      # Slate 325: Central plaza island surface
	var feeder_deck := Color("b8c4d4")     # Slate 375: Feeder roadway foundation
	var border_slate := Color("8c93a8")    # Slate 500: Crisp architectural curb bevel
	var guide_line := Color("94a3b8", 0.35) # Subtle bay guide incisions
	var divider_shadow := Color("334155")  # Slate 700: 3D divider shadow
	var divider_mid := Color("64748b")     # Slate 500: 3D divider body
	var divider_light := Color(1, 1, 1, 0.75) # 3D divider specular rim

	var hw: float = p_width / 2.0
	var sep_y: float = p_separator_y
	var gy: float = p_partition_y
	var eff_sep_y: float = sep_y if sep_y > -9000.0 else (gy + 15.0)

	if not is_unified:
		# Fallback legacy drawing
		_draw_legacy(ground_grey, divider_light, border_slate, divider_shadow, hw, gy, sep_y)
		return

	# =========================================================================
	# 1. UPPER GREY GROUND (Full-width viewport-responsive ground)
	# Spans from left (-hw) to right (+hw) and from p_top down to eff_sep_y.
	# Covers behind Level title, HUD buttons, surrounding the track, and sides of bays.
	# Zero sky-blue gaps in the entire upper area!
	# =========================================================================
	var upper_ground_rect := Rect2(-hw, p_top, p_width, eff_sep_y - p_top)
	draw_rect(upper_ground_rect, ground_grey)

	# =========================================================================
	# 2. FEEDER ROADWAY FOUNDATION
	# Continuous pavement deck supporting the feeder overpass merging into the track
	# =========================================================================
	var feeder_reach_x: float = maxf(hw + 40.0, 720.0)
	var feeder_pts := PackedVector2Array([
		Vector2(260.0, p_track_y + 40.0),
		Vector2(330.0, p_track_y - 15.0),
		Vector2(410.0, p_track_y - 120.0),
		Vector2(520.0, p_track_y - 250.0),
		Vector2(feeder_reach_x, p_track_y - 520.0),
		Vector2(feeder_reach_x, p_track_y - 320.0),
		Vector2(490.0, p_track_y - 70.0),
		Vector2(380.0, p_track_y + 60.0)
	])
	draw_colored_polygon(feeder_pts, feeder_deck)

	# =========================================================================
	# 3. CENTRAL PLAZA ISLAND
	# Finished architectural plaza island filling the inner hole of the oval track
	# Oval inner hole capsule: x in [-155, 155], R=36 semicircular ends at y=p_track_y
	# =========================================================================
	var island_r := 36.0
	var island_cx := 155.0
	var island_pts := PackedVector2Array()
	island_pts.append(Vector2(-island_cx, p_track_y - island_r))
	island_pts.append(Vector2(island_cx, p_track_y - island_r))
	for step in range(1, 12):
		var ang := -PI / 2.0 + float(step) / 12.0 * PI
		island_pts.append(Vector2(island_cx + cos(ang) * island_r, p_track_y + sin(ang) * island_r))
	island_pts.append(Vector2(island_cx, p_track_y + island_r))
	island_pts.append(Vector2(-island_cx, p_track_y + island_r))
	for step in range(1, 12):
		var ang := PI / 2.0 + float(step) / 12.0 * PI
		island_pts.append(Vector2(-island_cx + cos(ang) * island_r, p_track_y + sin(ang) * island_r))

	draw_colored_polygon(island_pts, plaza_grey)
	draw_polyline(island_pts, border_slate, 2.0, true)

	# =========================================================================
	# 4. CONNECTING BOARDING FORECOURT
	# Physically joins the lower edge of the passenger oval toward the parking platform.
	# Tucks seamlessly under the track road (top) and under the parking apron (bottom).
	# Spans all 7 parking bays. Clean, smooth geometric edges with no weird double borders.
	# =========================================================================
	var fc_top: float = p_track_y + 135.0  # Tucked under the oval track road brush
	var fc_bot: float = p_parking_y - 48.0 # Seamlessly joins top of parking bays
	var fc_top_hw: float = 265.0           # Half-width at track bottom disembarkation edge
	var fc_bot_hw: float = float(p_slots_count - 1) * p_slot_spacing / 2.0 + 53.0 / 2.0 + 20.0 # ~242px

	var forecourt_pts := PackedVector2Array([
		Vector2(-fc_top_hw, fc_top),
		Vector2(fc_top_hw, fc_top),
		Vector2(fc_bot_hw, fc_bot),
		Vector2(-fc_bot_hw, fc_bot)
	])
	draw_colored_polygon(forecourt_pts, forecourt_grey)

	# Subtle side curb definition
	draw_line(Vector2(-fc_top_hw, fc_top), Vector2(-fc_bot_hw, fc_bot), border_slate, 2.0)
	draw_line(Vector2(fc_top_hw, fc_top), Vector2(fc_bot_hw, fc_bot), border_slate, 2.0)

	# Subtle longitudinal route definition for each parking bay (subtle pavement bands, NO arrows, NO zebra stripes)
	var track_exit_y: float = p_track_y + 196.0 # Visible disembarkation line below track road
	if fc_bot > track_exit_y:
		# Pavement transition threshold line at the track disembarkation boundary
		draw_line(Vector2(-fc_top_hw + 15.0, track_exit_y), Vector2(fc_top_hw - 15.0, track_exit_y), guide_line, 1.5)

		for i in range(p_slots_count):
			var slot_x: float = -float(p_slots_count - 1) * p_slot_spacing / 2.0 + float(i) * p_slot_spacing
			var band_hw := 19.0
			var band_rect := Rect2(slot_x - band_hw, track_exit_y + 2.0, band_hw * 2.0, fc_bot - track_exit_y - 2.0)
			# Subtle architectural pavement tone guiding to this bay
			draw_rect(band_rect, Color("ffffff", 0.07))
			draw_line(Vector2(slot_x - band_hw, track_exit_y + 2.0), Vector2(slot_x - band_hw, fc_bot), guide_line, 1.0)
			draw_line(Vector2(slot_x + band_hw, track_exit_y + 2.0), Vector2(slot_x + band_hw, fc_bot), guide_line, 1.0)

	# =========================================================================
	# 5. TURNING ROAD CORRIDOR SHADING
	# Pavement shading between parking bays and separator line where buses turn
	# =========================================================================
	var corridor_top: float = p_parking_y + (p_parking_h / 2.0) + 8.0
	if eff_sep_y > corridor_top:
		draw_rect(Rect2(-hw, corridor_top, p_width, eff_sep_y - corridor_top), Color("b8c4d4", 0.35))

	# =========================================================================
	# 6. AUTHORITATIVE 3D ROAD DIVIDER LINE
	# Clean, crisp division line separating the upper grey terminal ground from
	# the distinct lower puzzle-board environment.
	# =========================================================================
	if sep_y > -9000.0:
		draw_rect(Rect2(-hw, sep_y, p_width, 2.5), divider_shadow)
		draw_rect(Rect2(-hw, sep_y + 2.5, p_width, 2.0), divider_mid)
		draw_rect(Rect2(-hw, sep_y + 4.5, p_width, 1.5), divider_light)

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
