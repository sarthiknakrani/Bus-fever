extends Control
class_name GardenBackgroundView

## Stylized 3D Tropical Beach & Ocean Environment
## Recreates the exact aesthetic of User Reference Images 1 & 2:
## Directional transition from DOWN (bottom) to UP (top) in 2.5D / 3D perspective:
## - DOWN: Warm golden sand beach, wet sand shoreline, and cute 2.5D footprints
## - SURF: Animated breaking wave with rich frothy seafoam, bubbling spray, and tide surge
## - SHALLOWS: Crystal-clear turquoise water revealing golden sand beneath & caustic shimmer
## - UP: Deep tropical Caribbean cerulean/azure ocean with 2.5D perspective wave bands
## - ACCENTS: Sparkling diamond sun glints & charming 3D nautical lifebuoys

# Beach Sand Palette (Warm tropical Caribbean sand)
const COLOR_SAND_DRY := Color("f6deaf")       # Sunlit dry beach sand
const COLOR_SAND_MID := Color("eac996")       # Golden mid-tone beach sand
const COLOR_SAND_SHADOW := Color("d2a870")    # Sand dune ripple trough shadow
const COLOR_SAND_WET := Color("ba8f58")       # Saturated glossy wet sand where waves recede
const COLOR_SAND_DEEP_WET := Color("9c7441")  # Tide contact line wet sand
const COLOR_FOOTPRINT_SHADOW := Color(0.48, 0.32, 0.16, 0.48) # 3D depressed footprint shadow
const COLOR_FOOTPRINT_RIM := Color(1.0, 0.95, 0.84, 0.65)    # Footprint sunlit sand rim

# Ocean & Water Palette (Emerald shallows to deep Caribbean azure)
const COLOR_OCEAN_DEEP := Color("0369a1")     # Deep Caribbean azure ocean
const COLOR_OCEAN_MID := Color("0284c7")      # Vibrant cerulean mid-water
const COLOR_OCEAN_CYAN := Color("0ea5e9")     # Sunlit tropical cyan
const COLOR_WATER_SHALLOW := Color("14b8a6")  # Clear turquoise shallow water
const COLOR_WATER_AQUA := Color("2dd4bf")     # Sunlit aqua shallows
const COLOR_WATER_EMERALD := Color("34d399")  # Emerald-turquoise shallow over sand

# Foam & Surf Palette (Crisp white froth, bubbling lace & spray)
const COLOR_FOAM_CREST := Color(1.0, 1.0, 1.0, 0.98)     # Brilliant white breaking wave crest
const COLOR_FOAM_BODY := Color(0.94, 0.99, 1.0, 0.90)     # Aerated bubbling seafoam body
const COLOR_FOAM_LACE := Color(0.80, 0.95, 1.0, 0.55)     # Organic seafoam backwash lace
const COLOR_FOAM_SPRAY := Color(1.0, 1.0, 1.0, 0.82)    # Froth spray droplets
const COLOR_GLINT := Color(1.0, 1.0, 1.0, 0.94)         # Diamond sun glints
const COLOR_PLAYFIELD := Color("d2d5e4")                  # Swatch 1 lavender playfield below divider

var vp_size := Vector2.ZERO
var track_screen_y: float = -1.0
var scale_factor: float = 1.0
var divider_screen_y: float = -1.0
var _water_time: float = 2.5

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	# Animated tropical water flow with dynamic wave surges and shimmering caustics
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_water_time += delta
	queue_redraw()

func update_layout(p_vp_size: Vector2, p_track_screen_y: float, p_scale_factor: float, p_divider_screen_y: float) -> void:
	vp_size = p_vp_size
	track_screen_y = p_track_screen_y
	scale_factor = p_scale_factor
	divider_screen_y = p_divider_screen_y
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w = size.x if size.x > 0.0 else (vp_size.x if vp_size.x > 0.0 else 720.0)
	var h = size.y if size.y > 0.0 else (vp_size.y if vp_size.y > 0.0 else 1280.0)
	if w <= 0.0 or h <= 0.0:
		return

	var div_y = divider_screen_y if divider_screen_y > 0.0 else (0.44 * h)
	var sc = scale_factor if scale_factor > 0.0 else 1.0
	var tr_y = track_screen_y if track_screen_y > 0.0 else (h * 0.20)
	var t = _water_time

	# =========================================================================
	# CALIBRATED VERTICAL ZONES (DOWN TO UP IN 2.5D PERSPECTIVE)
	# =========================================================================
	# Tide surge: water washes in and out smoothly
	var tide_surge = sin(t * 1.5) * 13.0 + cos(t * 0.7) * 4.0
	var shore_base_y = (div_y * 0.62) + tide_surge

	# 1. BASE BACKGROUND: OCEAN GRADIENT (UP) TO SHALLOW TURQUOISE (DOWN)
	var ocean_pts = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0),
		Vector2(w, div_y), Vector2(0, div_y)
	])
	var ocean_cols = PackedColorArray([
		COLOR_OCEAN_DEEP, COLOR_OCEAN_MID,
		COLOR_WATER_AQUA, COLOR_WATER_SHALLOW
	])
	draw_polygon(ocean_pts, ocean_cols)

	# 2. DIAGONAL SUNLIT SHIMMER OVERLAY (Top-Left Sunlight Direction)
	var sun_pts = PackedVector2Array([
		Vector2(0, 0), Vector2(w * 0.70, 0),
		Vector2(w * 0.35, div_y), Vector2(0, div_y)
	])
	var sun_cols = PackedColorArray([
		Color(0.30, 0.92, 1.0, 0.26), Color(0.20, 0.82, 0.98, 0.14),
		Color(0.08, 0.60, 0.85, 0.05), Color(0.14, 0.72, 0.92, 0.18)
	])
	draw_polygon(sun_pts, sun_cols)

	# 3. 2.5D PERSPECTIVE WAVE BANDS (Open Ocean down to Shallows)
	var num_bands: int = 16
	for k in range(num_bands):
		var norm_k: float = float(k) / float(num_bands)
		# Perspective spacing: denser at top horizon, wider towards shore
		var y_base: float = (shore_base_y - 15.0) * pow(norm_k, 1.40) + 5.0
		var wave_amp: float = lerpf(2.0, 6.0, norm_k)
		var k_speed: float = lerpf(1.3, 0.75, norm_k)
		var k_phase: float = k * 1.45 + t * k_speed

		var pts := PackedVector2Array()
		var shadow_pts := PackedVector2Array()
		var steps: int = 36

		for s in range(steps + 1):
			var x: float = (float(s) / float(steps)) * w
			var y_off: float = sin(x * 0.024 + k_phase) * wave_amp + cos(x * 0.014 - k_phase * 0.65) * (wave_amp * 0.40)
			var pt := Vector2(x, y_base + y_off)
			pts.append(pt)
			shadow_pts.append(Vector2(x, y_base + y_off + lerpf(1.8, 3.8, norm_k)))

		var shadow_alpha = lerpf(0.10, 0.24, norm_k)
		draw_polyline(shadow_pts, Color(0.01, 0.12, 0.30, shadow_alpha), lerpf(3.0, 5.5, norm_k), true)

		var crest_alpha = lerpf(0.30, 0.70, norm_k)
		draw_polyline(pts, Color(0.90, 0.98, 1.0, crest_alpha), lerpf(1.6, 3.0, norm_k), true)

	# 4. ORGANIC CAUSTIC LIGHT WEBS ON SHALLOW SEABED
	_draw_shallow_caustics(w, shore_base_y, t)

	# 5. THE BEACH (DOWN): WARM GOLDEN SAND, WET SAND & BREAKING FOAM SURF
	# 5A. Golden Sand Base Polygon covering the bottom beach zone from shore_base_y down to div_y
	_draw_sandy_beach(w, div_y, shore_base_y, t)

	# 5B. Wet Sand Shoreline Ribbon (glossy tide-washed sand)
	_draw_wet_sand_ribbon(w, div_y, shore_base_y, t)

	# 5C. Breaking White Seafoam Wave (crashing onto the sand from down to up!)
	_draw_breaking_wave_foam(w, shore_base_y, t)

	# 5D. 2.5D Footprints on the Dry Beach Sand
	_draw_beach_footprints(w, div_y, shore_base_y)

	# 6. SHORELINE CONTACT FOAM AROUND TRACK PIER
	var track_left_x = (w / 2.0) - (207.0 * sc)
	var pier_foam_pulse = sin(t * 2.4) * 2.0
	var pier_foam_pts := PackedVector2Array()
	var n_foam := 24
	for i in range(n_foam + 1):
		var ang = lerpf(-PI * 0.45, PI * 0.45, float(i) / float(n_foam))
		var fx = (w / 2.0) + cos(ang + PI) * (185.0 * sc + pier_foam_pulse)
		var fy = tr_y + sin(ang) * (135.0 * sc + pier_foam_pulse * 0.8)
		pier_foam_pts.append(Vector2(fx, fy))
	draw_polyline(pier_foam_pts, Color(0.70, 0.92, 1.0, 0.35), 10.0 * sc, false)
	draw_polyline(pier_foam_pts, Color(1.0, 1.0, 1.0, 0.65), 3.5 * sc, false)

	# 7. SPARKLING DIAMOND SUN GLINTS
	var glint_seeds = [
		Vector2(w * 0.15, div_y * 0.18),
		Vector2(w * 0.32, div_y * 0.12),
		Vector2(w * 0.10, div_y * 0.42),
		Vector2(w * 0.82, div_y * 0.16),
		Vector2(w * 0.88, div_y * 0.48),
		Vector2(w * 0.70, div_y * 0.52)
	]
	for idx in range(glint_seeds.size()):
		var gp = glint_seeds[idx]
		var phase = idx * 1.7 + t * 3.2
		var pulse = maxf(0.0, sin(phase))
		if pulse > 0.15:
			_draw_diamond_glint(gp, 6.0 * pulse * sc, Color(1.0, 1.0, 1.0, pulse * 0.85))

	# 8. CHARMING 3D TOY NAUTICAL LIFEBUOYS BOBBING IN WATER
	var buoy_y_bob = sin(t * 1.4) * 1.2
	var buoy_x_bob = cos(t * 1.0) * 0.8
	var buoy_pos = Vector2(maxf(50.0, track_left_x * 0.40) + buoy_x_bob, clampf(tr_y + 10.0 * sc + buoy_y_bob, 120.0, shore_base_y - 45.0))
	var buoy_rot = sin(t * 1.2) * 0.04
	_draw_3d_lifebuoy(buoy_pos, 26.0 * sc, buoy_rot, t)

	var buoy2_y_bob = sin(t * 1.5 + 1.4) * 0.9
	var buoy2_x_bob = cos(t * 1.1 + 0.8) * 0.6
	var buoy2_pos = Vector2(maxf(75.0, track_left_x * 0.68) + buoy2_x_bob, clampf(tr_y - 95.0 * sc + buoy2_y_bob, 65.0, shore_base_y - 120.0))
	var buoy2_rot = sin(t * 1.3 + 1.0) * 0.03
	_draw_3d_lifebuoy(buoy2_pos, 16.0 * sc, buoy2_rot, t + 1.2)

	# 9. SOLID CLEAN LAVENDER PLAYFIELD BELOW 44% DIVIDER
	if h > div_y:
		draw_rect(Rect2(0, div_y, w, h - div_y), COLOR_PLAYFIELD)


# -----------------------------------------------------------------------------
# BEACH RENDERING SUBROUTINES
# -----------------------------------------------------------------------------

## Computes the organic, natural curved shoreline y-position across width w
func _get_shore_y(x: float, w: float, base_y: float, t: float) -> float:
	var swell1 = sin(x * 0.016 + t * 0.5) * 8.5
	var swell2 = cos(x * 0.034 - t * 0.35) * 4.2
	var macro_curve = sin((x / w) * PI) * -12.0
	return base_y + macro_curve + swell1 + swell2

## Draws the warm golden sand beach polygon from the shoreline down to div_y
func _draw_sandy_beach(w: float, div_y: float, base_shore_y: float, t: float) -> void:
	var n_pts := 48
	var shore_pts := PackedVector2Array()

	for i in range(n_pts + 1):
		var x = (float(i) / float(n_pts)) * w
		var sy = _get_shore_y(x, w, base_shore_y, t)
		shore_pts.append(Vector2(x, sy))

	var beach_poly := PackedVector2Array()
	for pt in shore_pts:
		beach_poly.append(pt)
	beach_poly.append(Vector2(w, div_y))
	beach_poly.append(Vector2(0, div_y))

	var beach_cols := PackedColorArray()
	for pt in shore_pts:
		beach_cols.append(COLOR_SAND_WET)
	beach_cols.append(COLOR_SAND_DRY)
	beach_cols.append(COLOR_SAND_MID)
	draw_polygon(beach_poly, beach_cols)

	# Gentle 2.5D sand ripples on the dry beach
	var n_ripples := 5
	for r in range(n_ripples):
		var ry = lerpf(base_shore_y + 25.0, div_y - 10.0, float(r) / float(n_ripples))
		if ry < div_y:
			var rip_pts := PackedVector2Array()
			for i in range(32 + 1):
				var rx = (float(i) / 32.0) * w
				var r_off = sin(rx * 0.045 + r * 1.8) * 2.2
				rip_pts.append(Vector2(rx, ry + r_off))
			draw_polyline(rip_pts, Color(0.78, 0.60, 0.38, 0.24), 2.2, true)
			var crest_pts := PackedVector2Array()
			for pt in rip_pts:
				crest_pts.append(pt + Vector2(0, -1.0))
			draw_polyline(crest_pts, Color(1.0, 0.95, 0.82, 0.28), 1.2, true)

## Draws the glossy, dark wet-sand band immediately following the receding tide
func _draw_wet_sand_ribbon(w: float, div_y: float, base_shore_y: float, t: float) -> void:
	var n_pts := 40
	var wet_pts := PackedVector2Array()
	var dry_pts := PackedVector2Array()

	for i in range(n_pts + 1):
		var x = (float(i) / float(n_pts)) * w
		var sy = _get_shore_y(x, w, base_shore_y, t)
		wet_pts.append(Vector2(x, sy))
		dry_pts.append(Vector2(x, minf(div_y, sy + 18.0 + sin(x * 0.05 + t * 0.8) * 3.5)))

	var wet_strip := PackedVector2Array()
	for pt in wet_pts:
		wet_strip.append(pt)
	for i in range(dry_pts.size() - 1, -1, -1):
		wet_strip.append(dry_pts[i])

	draw_colored_polygon(wet_strip, Color(0.68, 0.50, 0.30, 0.45))
	draw_polyline(wet_pts, Color(1.0, 1.0, 1.0, 0.32), 3.0, true)

## Draws the authentic breaking wave seafoam with thick white froth and bubbling lace
func _draw_breaking_wave_foam(w: float, base_shore_y: float, t: float) -> void:
	var n_pts := 56
	var wave_front := PackedVector2Array()
	var wave_back := PackedVector2Array()
	var lace_outer := PackedVector2Array()

	for i in range(n_pts + 1):
		var x = (float(i) / float(n_pts)) * w
		var sy = _get_shore_y(x, w, base_shore_y, t)
		var foam_thick = 14.0 + sin(x * 0.06 + t * 1.8) * 5.0 + cos(x * 0.12 - t * 2.2) * 3.0

		wave_front.append(Vector2(x, sy))
		wave_back.append(Vector2(x, sy - foam_thick))
		lace_outer.append(Vector2(x, sy - foam_thick - 8.0 - sin(x * 0.08) * 4.0))

	# 1. Translucent bubbling seafoam lace trailing behind the wave
	var lace_poly := PackedVector2Array()
	for pt in wave_back:
		lace_poly.append(pt)
	for i in range(lace_outer.size() - 1, -1, -1):
		lace_poly.append(lace_outer[i])
	draw_colored_polygon(lace_poly, COLOR_FOAM_LACE)

	# 2. Main thick aerated white seafoam body
	var foam_poly := PackedVector2Array()
	for pt in wave_front:
		foam_poly.append(pt)
	for i in range(wave_back.size() - 1, -1, -1):
		foam_poly.append(wave_back[i])
	draw_colored_polygon(foam_poly, COLOR_FOAM_BODY)

	# 3. Brilliant pure white crest line on the leading edge of the breaking wave
	draw_polyline(wave_front, COLOR_FOAM_CREST, 3.8, true)

	# 4. Bubbling seafoam clusters / froth scallops along the crest
	var n_clusters := 28
	for c in range(n_clusters):
		var cx = (float(c) + 0.5) / float(n_clusters) * w
		var cy = _get_shore_y(cx, w, base_shore_y, t)
		var bubble_r = 4.0 + sin(c * 2.1 + t * 3.0) * 1.8
		var bubble_off = Vector2(sin(c * 1.4) * 2.0, -bubble_r * 0.4)
		draw_circle(Vector2(cx, cy) + bubble_off, bubble_r, COLOR_FOAM_CREST)

	# 5. Fine seafoam spray droplets dancing in the air / water
	for s in range(22):
		var sx = fmod(s * 33.7 + t * 45.0, w)
		var sy = _get_shore_y(sx, w, base_shore_y, t) - (6.0 + fmod(s * 7.3, 16.0))
		var sr = 1.2 + fmod(s * 0.7, 1.6)
		draw_circle(Vector2(sx, sy), sr, COLOR_FOAM_SPRAY)

## Draws 2.5D cute illustrated footprints on the dry sand (matching reference image)
func _draw_beach_footprints(w: float, div_y: float, base_shore_y: float) -> void:
	var steps_data = [
		Vector2(w * 0.16, div_y - 32.0),
		Vector2(w * 0.20, div_y - 48.0),
		Vector2(w * 0.25, div_y - 30.0),
		Vector2(w * 0.29, div_y - 45.0),
		Vector2(w * 0.74, div_y - 35.0),
		Vector2(w * 0.78, div_y - 50.0),
		Vector2(w * 0.84, div_y - 32.0)
	]

	for i in range(steps_data.size()):
		var fp = steps_data[i]
		if fp.y > base_shore_y + 12.0 and fp.y < div_y - 6.0:
			var is_left = (i % 2 == 0)
			_draw_single_footprint(fp, 5.5, is_left)

## Draws a single 2.5D footprint depression in the sand with soft shadow and sunlit rim
func _draw_single_footprint(pos: Vector2, sz: float, is_left: bool) -> void:
	var tilt = 0.18 if is_left else -0.18
	draw_set_transform(pos, tilt, Vector2(0.85, 1.25))
	draw_circle(Vector2.ZERO, sz, COLOR_FOOTPRINT_SHADOW)
	draw_circle(Vector2(0, sz * 0.9), sz * 0.65, COLOR_FOOTPRINT_SHADOW)
	draw_arc(Vector2(-sz * 0.2, -sz * 0.2), sz * 0.9, PI * 0.75, PI * 1.6, 8, COLOR_FOOTPRINT_RIM, 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Draws organic caustic sunlight web ripples on the shallow turquoise water
func _draw_shallow_caustics(w: float, shore_base_y: float, t: float) -> void:
	var caustic_col = Color(1.0, 1.0, 1.0, 0.14)
	var n_caustics := 6
	for c in range(n_caustics):
		var cy = lerpf(shore_base_y * 0.50, shore_base_y * 0.88, float(c) / float(n_caustics))
		var pts := PackedVector2Array()
		for s in range(32 + 1):
			var cx = (float(s) / 32.0) * w
			var coff = sin(cx * 0.035 + c * 1.5 + t * 1.4) * 4.5 + cos(cx * 0.02 - t * 0.9) * 3.0
			pts.append(Vector2(cx, cy + coff))
		draw_polyline(pts, caustic_col, 2.5, true)

## Draws an authentic 3D toy lifebuoy naturally floating on the ocean water with subtle contact shading and ripples
func _draw_3d_lifebuoy(pos: Vector2, rad: float, rot: float, t: float) -> void:
	var r_inner := rad * 0.46
	var ring_w := rad - r_inner
	var mid_r := (rad + r_inner) * 0.5

	# 1. Gentle concentric surface ripples originating at water contact point
	var rip1_phase: float = fmod(t * 0.65, 1.0)
	var rip1_r: float = rad * (1.10 + rip1_phase * 0.32)
	var rip1_alpha: float = (1.0 - rip1_phase) * 0.28
	draw_arc(pos, rip1_r, 0, TAU, 36, Color(1.0, 1.0, 1.0, rip1_alpha), 1.4)

	var rip2_phase: float = fmod(t * 0.65 + 0.5, 1.0)
	var rip2_r: float = rad * (1.10 + rip2_phase * 0.32)
	var rip2_alpha: float = (1.0 - rip2_phase) * 0.20
	draw_arc(pos, rip2_r, 0, TAU, 36, Color(1.0, 1.0, 1.0, rip2_alpha), 1.2)

	# 2. Subtle, close water-contact shading directly under the buoyant ring (no detached hover shadow)
	var contact_offset := Vector2(0.5, 1.2)
	draw_arc(pos + contact_offset, mid_r, 0, TAU, 48, Color(0.01, 0.06, 0.18, 0.28), ring_w * 1.08)
	# Ambient water contact crease around waterline
	draw_arc(pos + Vector2(0.0, 1.0), rad, 0.1 * PI, 0.9 * PI, 36, Color(0.01, 0.05, 0.15, 0.25), 2.2)

	# 3. White doughnut ring body (hollow torus - center is 100% clear water!)
	draw_arc(pos, mid_r, 0, TAU, 48, Color.WHITE, ring_w)

	# 4. Four red quadrant stripes (drawn strictly between r_inner and rad)
	for base_ang in [0.0, 90.0, 180.0, 270.0]:
		var a0 = rot + deg_to_rad(base_ang - 16.0)
		var a1 = rot + deg_to_rad(base_ang + 16.0)
		var stripe_pts := PackedVector2Array()
		var n_step := 6
		# Outer arc
		for st in range(n_step + 1):
			var a = lerpf(a0, a1, float(st) / float(n_step))
			stripe_pts.append(pos + Vector2(cos(a), sin(a)) * (rad + 0.5))
		# Inner arc backwards
		for st in range(n_step, -1, -1):
			var a = lerpf(a0, a1, float(st) / float(n_step))
			stripe_pts.append(pos + Vector2(cos(a), sin(a)) * (r_inner - 0.5))
		draw_colored_polygon(stripe_pts, Color("eb3241"))

	# 5. 3D depth rims: inner shadow into the water hole & outer rim
	draw_arc(pos, r_inner, 0, TAU, 36, Color(0.01, 0.08, 0.22, 0.32), 2.0)
	draw_arc(pos, rad, 0, TAU, 36, Color(0.0, 0.0, 0.0, 0.16), 1.5)

	# 6. Glossy top-left 3D specular highlight glint along the torus crest
	draw_arc(pos + Vector2(-1.2, -1.2), mid_r, -PI * 0.85, -PI * 0.15, 24, Color(1.0, 1.0, 1.0, 0.82), 2.2)

	# 7. Subtle waterline occlusion wash across lower partially-submerged curve
	draw_arc(pos, mid_r, 0.18 * PI, 0.82 * PI, 24, Color(0.04, 0.32, 0.55, 0.22), ring_w * 0.95)
	# Waterline contact meniscus
	draw_arc(pos, rad, 0.25 * PI, 0.75 * PI, 24, Color(0.88, 0.96, 1.0, 0.30), 1.4)

## Draws a crisp sparkling diamond glint star
func _draw_diamond_glint(pos: Vector2, sz: float, col: Color) -> void:
	var pts = PackedVector2Array([
		pos + Vector2(0, -sz),
		pos + Vector2(sz * 0.35, 0),
		pos + Vector2(0, sz),
		pos + Vector2(-sz * 0.35, 0)
	])
	draw_colored_polygon(pts, col)
	var pts2 = PackedVector2Array([
		pos + Vector2(-sz, 0),
		pos + Vector2(0, sz * 0.35),
		pos + Vector2(sz, 0),
		pos + Vector2(0, -sz * 0.35)
	])
	draw_colored_polygon(pts2, col)
	draw_circle(pos, sz * 0.22, Color.WHITE)
