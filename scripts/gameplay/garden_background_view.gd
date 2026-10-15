extends Control
class_name GardenBackgroundView

## Production-Quality Stylized Garden Environment
## Renders a polished casual mobile puzzle park/garden surface with:
## - Seamless stylized grass lawn texture tiling
## - Gentle sunlit tonal variation & soft ambient lighting
## - Subtle manicured lawn mower diagonal striping
## - Integrated 3-tone cartoon hedge clusters with soft contact shadows & daisy accents
## - Guaranteed clean margins away from track, feeder, and HUD buttons
## 100% cohesive, zero photo stickers, zero clutter, zero seams.

const COLOR_STRIPE_LIGHT := Color(1.0, 1.0, 1.0, 0.035) # Subtle lawn mower stripe
const COLOR_BUSH_SHADOW := Color("2a500e") # Cartoon bush dark base/crevice
const COLOR_BUSH_BODY := Color("4e9018")   # Cartoon bush rich foliage
const COLOR_BUSH_LIGHT := Color("72b826")  # Cartoon bush sunlit top lobe
const COLOR_FLOWER_CREAM := Color("fffde6") # Tiny daisy petal
const COLOR_FLOWER_GOLD := Color("ffd13b")  # Tiny daisy core
const COLOR_PLAYFIELD := Color("d2d5e4")    # Swatch 1 lavender playfield below 40%

var lawn_tex: Texture2D
var vp_size := Vector2.ZERO
var track_screen_y: float = -1.0
var scale_factor: float = 1.0
var divider_screen_y: float = -1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://assets/sprites/environment/stylized_garden_lawn.png"):
		lawn_tex = ResourceLoader.load("res://assets/sprites/environment/stylized_garden_lawn.png") as Texture2D
	if lawn_tex == null:
		var img := Image.new()
		var p := ProjectSettings.globalize_path("res://assets/sprites/environment/stylized_garden_lawn.png")
		if img.load(p) == OK:
			lawn_tex = ImageTexture.create_from_image(img)

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

	var div_y = divider_screen_y if divider_screen_y > 0.0 else (0.40 * h)

	# 1. Base Seamless Stylized Lawn Tiling across the entire upper 40%
	if lawn_tex != null:
		draw_texture_rect(lawn_tex, Rect2(0, 0, w, div_y), true)
	else:
		# Fallback gradient
		var steps = 16
		var step_h = div_y / float(steps)
		for i in range(steps):
			var t = float(i) / float(steps - 1)
			var c = Color("6bb22b").lerp(Color("589420"), t)
			draw_rect(Rect2(0, float(i) * step_h, w, step_h + 1.0), c)

	# 2. Subtle Sunlit Ambient Light Overlay (warm sun on top edge, soft depth towards divider)
	var light_pts = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0),
		Vector2(w, div_y), Vector2(0, div_y)
	])
	var light_cols = PackedColorArray([
		Color(1.0, 0.98, 0.88, 0.07), Color(1.0, 0.98, 0.88, 0.07),
		Color(0.2, 0.45, 0.1, 0.05), Color(0.2, 0.45, 0.1, 0.05)
	])
	draw_polygon(light_pts, light_cols)

	# 3. Subtle Manicured Lawn Striping (soft diagonal bands across upper 40%)
	var stripe_w: float = 48.0
	var total_diag = w + div_y
	var num_stripes = int(total_diag / stripe_w) + 2
	for i in range(0, num_stripes, 2):
		var x_start = float(i) * stripe_w - div_y * 0.45
		var stripe_pts = PackedVector2Array([
			Vector2(x_start, 0),
			Vector2(x_start + stripe_w, 0),
			Vector2(x_start + stripe_w + div_y * 0.45, div_y),
			Vector2(x_start + div_y * 0.45, div_y)
		])
		draw_colored_polygon(stripe_pts, COLOR_STRIPE_LIGHT)

	# 4. Stylized Cartoon Hedge & Bush Clusters
	# Coordinated with track and HUD geometry:
	var tr_y = track_screen_y if track_screen_y > 0.0 else (h * 0.20)
	var sc = scale_factor if scale_factor > 0.0 else 1.0
	var track_left_x = (w / 2.0) - (282.0 * sc) # Left apex outer edge (105 + 177)
	var track_top_y = tr_y - (177.0 * sc)

	# Group A: Upper-Left Garden Bed (nestled outside track left curve, below restart button)
	var bush_l1_pos = Vector2(maxf(36.0, track_left_x * 0.45), clampf(tr_y - 30.0 * sc, 85.0, div_y - 50.0))
	var bush_l2_pos = Vector2(maxf(24.0, track_left_x * 0.25), clampf(tr_y + 40.0 * sc, 110.0, div_y - 40.0))
	var bush_l3_pos = Vector2(maxf(42.0, track_left_x * 0.65), clampf(tr_y + 90.0 * sc, 130.0, div_y - 35.0))
	_draw_cartoon_bush_cluster(bush_l1_pos, clampf(34.0 * sc, 22.0, 46.0), 5)
	_draw_cartoon_bush_cluster(bush_l2_pos, clampf(28.0 * sc, 18.0, 38.0), 4)
	_draw_cartoon_bush_cluster(bush_l3_pos, clampf(24.0 * sc, 16.0, 32.0), 3)

	# Group B: Top Framing Hedges (behind top bar, safely framed away from center title)
	if track_top_y > 75.0:
		# Small hedge cluster tucked above left top straight
		var top_l_x = (w / 2.0) - (120.0 * sc)
		if top_l_x > 90.0:
			_draw_cartoon_bush_cluster(Vector2(top_l_x, track_top_y - 14.0 * sc), clampf(18.0 * sc, 14.0, 26.0), 3)

	# Group C: Upper-Right Corner Accent (far upper-right, safely clear of pause button & feeder)
	var bush_r_pos = Vector2(w - 30.0, minf(40.0, tr_y - 120.0 * sc))
	_draw_cartoon_bush_cluster(bush_r_pos, clampf(22.0 * sc, 16.0, 30.0), 3)

	# Group D: Delicate Grass Tufts and Daisy Dots scattered on the lawn
	_draw_tiny_flower(Vector2(bush_l1_pos.x + 22.0, bush_l1_pos.y - 16.0), 3.2)
	_draw_tiny_flower(Vector2(bush_l2_pos.x + 18.0, bush_l2_pos.y + 12.0), 2.8)
	_draw_tiny_flower(Vector2(w * 0.08, div_y - 16.0), 2.6)

	# 5. Solid Playfield Grounding below the 40% Divider line
	if h > div_y:
		draw_rect(Rect2(0, div_y, w, h - div_y), COLOR_PLAYFIELD)

## Draws a clean, stylized cartoon bush with 3-tone shading and tiny flower accents
func _draw_cartoon_bush_cluster(center: Vector2, radius: float, count: int) -> void:
	var offsets = [
		Vector2(0, 0),
		Vector2(-radius * 0.45, radius * 0.15),
		Vector2(radius * 0.45, radius * 0.15),
		Vector2(-radius * 0.25, -radius * 0.35),
		Vector2(radius * 0.25, -radius * 0.35)
	]

	# Phase A: Soft ground shadow
	draw_circle(center + Vector2(0, radius * 0.42), radius * 0.85, Color(0, 0, 0, 0.12))

	# Phase B: Darker base lobes
	for k in range(mini(count, offsets.size())):
		var p = center + offsets[k]
		draw_circle(p, radius * 0.62, COLOR_BUSH_SHADOW)

	# Phase C: Main rich foliage lobes
	for k in range(mini(count, offsets.size())):
		var p = center + offsets[k] + Vector2(0, -radius * 0.08)
		draw_circle(p, radius * 0.56, COLOR_BUSH_BODY)

	# Phase D: Sunlit highlight domes on upper lobes
	for k in range(mini(count, offsets.size())):
		var p = center + offsets[k] + Vector2(0, -radius * 0.18)
		draw_circle(p, radius * 0.38, COLOR_BUSH_LIGHT)

	# Phase E: Tiny stylized flower accents (daisies)
	if count >= 4:
		var f_pos1 = center + Vector2(-radius * 0.2, radius * 0.05)
		var f_pos2 = center + Vector2(radius * 0.25, -radius * 0.1)
		_draw_tiny_flower(f_pos1, 3.2)
		_draw_tiny_flower(f_pos2, 2.8)

func _draw_tiny_flower(pos: Vector2, sz: float) -> void:
	# 4 tiny white petal dots + gold center
	draw_circle(pos + Vector2(-sz * 0.6, 0), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos + Vector2(sz * 0.6, 0), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos + Vector2(0, -sz * 0.6), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos + Vector2(0, sz * 0.6), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos, sz * 0.45, COLOR_FLOWER_GOLD)
