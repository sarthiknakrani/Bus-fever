extends Control
class_name GardenBackgroundView

## Stylized 3D Tropical Water Environment
## Renders a vibrant, casual-mobile 3D ocean/lagoon water surface behind the elevated track:
## - Deep tropical Caribbean turquoise & azure gradient water
## - 2.5D perspective wave bands with sunlit crest highlights and trough shadows
## - Dynamic animated wave drift, organic caustics, and sparkling diamond sun glints
## - Shoreline contact foam hugging the elevated concrete track and platform walls
## - Charming 3D toy nautical lifebuoys bobbing with water physics
## - 100% clean, crisp casual puzzle game art style, zero clutter.

# Water Color Palette
const COLOR_OCEAN_DEEP := Color("0369a1")       # Deep Caribbean ocean blue
const COLOR_OCEAN_MID := Color("0284c7")        # Vibrant cerulean mid-water
const COLOR_OCEAN_CYAN := Color("0ea5e9")       # Sunlit tropical cyan
const COLOR_OCEAN_SHALLOW := Color("38bdf8")    # Sunlit shallow aqua
const COLOR_OCEAN_DARK_BASE := Color("024e75")  # Deep base near bottom divider
const COLOR_WAVE_CREST := Color(0.90, 0.98, 1.0, 0.65) # Bright wave foam crest
const COLOR_WAVE_SHADOW := Color(0.01, 0.12, 0.30, 0.28) # Trough drop shadow
const COLOR_GLINT := Color(1.0, 1.0, 1.0, 0.90) # Sparkling sun glint
const COLOR_PLAYFIELD := Color("d2d5e4")        # Swatch 1 lavender playfield below 44%

var vp_size := Vector2.ZERO
var track_screen_y: float = -1.0
var scale_factor: float = 1.0
var divider_screen_y: float = -1.0
var _water_time: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	set_process(true)

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

	# 1. Base 3D Tropical Ocean Gradient Polygon
	var base_pts = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0),
		Vector2(w, div_y), Vector2(0, div_y)
	])
	var base_cols = PackedColorArray([
		COLOR_OCEAN_MID, COLOR_OCEAN_CYAN,
		COLOR_OCEAN_DEEP, COLOR_OCEAN_DARK_BASE
	])
	draw_polygon(base_pts, base_cols)

	# 2. Diagonal Sunlit Caustic Shimmer Overlay (top-left sunlight)
	var sun_pts = PackedVector2Array([
		Vector2(0, 0), Vector2(w * 0.72, 0),
		Vector2(w * 0.38, div_y), Vector2(0, div_y)
	])
	var sun_cols = PackedColorArray([
		Color(0.24, 0.88, 0.98, 0.30), Color(0.18, 0.78, 0.95, 0.16),
		Color(0.04, 0.52, 0.78, 0.06), Color(0.10, 0.65, 0.85, 0.22)
	])
	draw_polygon(sun_pts, sun_cols)

	# 3. 2.5D Perspective Wave Bands
	var num_bands: int = 28
	var t = _water_time
	for k in range(num_bands):
		var norm_k: float = float(k) / float(num_bands)
		# Power-based perspective compression toward top horizon
		var y_base: float = div_y * pow(norm_k, 1.32) + 5.0
		var wave_amp: float = lerpf(2.2, 7.5, norm_k)
		var k_speed: float = lerpf(1.4, 0.8, norm_k)
		var k_phase: float = k * 1.35 + t * k_speed

		var pts := PackedVector2Array()
		var shadow_pts := PackedVector2Array()
		var steps: int = 40

		for s in range(steps + 1):
			var x: float = (float(s) / float(steps)) * w
			var y_off: float = sin(x * 0.022 + k_phase) * wave_amp + cos(x * 0.013 - k_phase * 0.7) * (wave_amp * 0.45)
			var pt := Vector2(x, y_base + y_off)
			pts.append(pt)
			shadow_pts.append(Vector2(x, y_base + y_off + lerpf(2.0, 4.5, norm_k)))

		# Volumetric wave trough shadow
		var shadow_alpha = lerpf(0.12, 0.30, norm_k)
		draw_polyline(shadow_pts, Color(0.01, 0.14, 0.32, shadow_alpha), lerpf(3.5, 7.5, norm_k), true)

		# Sunlit wave crest highlight
		var crest_alpha = lerpf(0.35, 0.75, norm_k)
		draw_polyline(pts, Color(0.88, 0.98, 1.0, crest_alpha), lerpf(1.8, 3.8, norm_k), true)

	# 4. Shoreline Contact Foam Lapping Around Track & Pier
	var track_left_x = (w / 2.0) - (207.0 * sc)
	var foam_pulse = sin(t * 2.4) * 2.0
	var pier_foam_pts := PackedVector2Array()
	var n_foam := 24
	for i in range(n_foam + 1):
		var ang = lerpf(-PI * 0.45, PI * 0.45, float(i) / float(n_foam))
		var fx = (w / 2.0) + cos(ang + PI) * (185.0 * sc + foam_pulse)
		var fy = tr_y + sin(ang) * (135.0 * sc + foam_pulse * 0.8)
		pier_foam_pts.append(Vector2(fx, fy))
	draw_polyline(pier_foam_pts, Color(0.70, 0.92, 1.0, 0.35), 10.0 * sc, false)
	draw_polyline(pier_foam_pts, Color(1.0, 1.0, 1.0, 0.65), 3.5 * sc, false)

	# 5. Sparkling Diamond Sun Glints
	var glint_seeds = [
		Vector2(w * 0.16, div_y * 0.22),
		Vector2(w * 0.31, div_y * 0.15),
		Vector2(w * 0.12, div_y * 0.68),
		Vector2(w * 0.22, div_y * 0.82),
		Vector2(w * 0.84, div_y * 0.25),
		Vector2(w * 0.88, div_y * 0.72),
		Vector2(w * 0.72, div_y * 0.86)
	]
	for idx in range(glint_seeds.size()):
		var gp = glint_seeds[idx]
		var phase = idx * 1.7 + t * 3.2
		var pulse = maxf(0.0, sin(phase))
		if pulse > 0.15:
			_draw_diamond_glint(gp, 6.0 * pulse * sc, Color(1.0, 1.0, 1.0, pulse * 0.85))

	# 6. Charming 3D Toy Nautical Lifebuoys Bobbing in Water
	# Buoy A: Foreground Left
	var buoy_y_bob = sin(t * 2.2) * 4.0
	var buoy_pos = Vector2(maxf(50.0, track_left_x * 0.40), clampf(tr_y + 15.0 * sc + buoy_y_bob, 130.0, div_y - 60.0))
	var buoy_rot = sin(t * 2.2) * 0.08
	_draw_3d_lifebuoy(buoy_pos, 27.0 * sc, buoy_rot, buoy_y_bob)

	# Buoy B: Distant Background Upper-Left
	var buoy2_y_bob = sin(t * 2.5 + 1.2) * 2.5
	var buoy2_pos = Vector2(maxf(75.0, track_left_x * 0.68), clampf(tr_y - 95.0 * sc + buoy2_y_bob, 70.0, div_y - 120.0))
	var buoy2_rot = sin(t * 2.5 + 1.2) * 0.06
	_draw_3d_lifebuoy(buoy2_pos, 16.0 * sc, buoy2_rot, buoy2_y_bob)

	# 7. Solid Clean Lavender Playfield below the 44% Divider
	if h > div_y:
		draw_rect(Rect2(0, div_y, w, h - div_y), COLOR_PLAYFIELD)

## Draws an authentic 3D toy lifebuoy with realistic water shadow, red quadrants, and glossy specular
func _draw_3d_lifebuoy(pos: Vector2, rad: float, rot: float, bob: float) -> void:
	# 1. Soft underwater contact shadow
	var shadow_offset = Vector2(2.0, 9.0 + bob * 0.4)
	draw_circle(pos + shadow_offset, rad * 1.06, Color(0.01, 0.10, 0.24, 0.38))

	# 2. Main white torus base
	draw_circle(pos, rad, Color.WHITE)

	# 3. Vibrant red sectors (4 quadrants)
	for base_ang in [0.0, 90.0, 180.0, 270.0]:
		var a0 = rot + deg_to_rad(base_ang - 18.0)
		var a1 = rot + deg_to_rad(base_ang + 18.0)
		var stripe_pts := PackedVector2Array([pos])
		for st in 8:
			var a = lerpf(a0, a1, float(st) / 7.0)
			stripe_pts.append(pos + Vector2(cos(a), sin(a)) * (rad + 0.5))
		draw_colored_polygon(stripe_pts, Color("eb3241"))

	# 4. Center hole revealing the blue ocean beneath
	draw_circle(pos, rad * 0.48, COLOR_OCEAN_MID)

	# 5. Volumetric 3D Shading:
	# Inner shadow rim
	draw_arc(pos, rad * 0.48, 0, TAU, 32, Color(0.0, 0.0, 0.0, 0.22), 2.2)
	# Outer subtle bevel rim
	draw_arc(pos, rad - 0.8, 0, TAU, 32, Color(0.0, 0.0, 0.0, 0.14), 1.5)
	# Sunlit glossy top-left specular highlight
	draw_circle(pos + Vector2(-rad * 0.42, -rad * 0.42), rad * 0.24, Color(1.0, 1.0, 1.0, 0.75))

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
	# Center bright pin
	draw_circle(pos, sz * 0.22, Color.WHITE)
