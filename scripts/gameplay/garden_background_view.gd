extends Control
class_name GardenBackgroundView

## Production-Quality 2.5D Stylized Garden Environment
## Renders a polished casual mobile puzzle park/garden surface with:
## - Manicured lawn mower diagonal striping with sunlit ambient gradient
## - Volumetric 2.5D green cartoon trees & lush hedge clusters
## - Clean stone garden accents and contact drop shadows
## 100% cohesive, clean green casual game art style, zero clutter.

const COLOR_LAWN_LIGHT := Color("6cbf4b") # Light grass green #6CBF4B matching reference
const COLOR_LAWN_DARK := Color("61b241")  # Medium lawn green #61B241 matching reference
const COLOR_TREE_SHADOW := Color("1b3607")# Deep shadow under tree canopy
const COLOR_TREE_BODY := Color("3b7512")  # Lush green tree foliage
const COLOR_TREE_LIGHT := Color("6dc220") # Sunlit tree highlight
const COLOR_TREE_TIP := Color("9ae63c")   # Brightest top-left sun specular
const COLOR_BUSH_SHADOW := Color("23420b")# Dark base shadow
const COLOR_BUSH_BODY := Color("468615")  # Rich foliage body
const COLOR_BUSH_LIGHT := Color("78d428") # Sunlit foliage highlight
const COLOR_STONE_DARK := Color("475569") # Stone base
const COLOR_STONE_MID := Color("64748b")  # Stone body
const COLOR_STONE_LIGHT := Color("cbd5e1")# Stone rim highlight
const COLOR_FLOWER_CREAM := Color("fffde6")# Tiny daisy petal
const COLOR_FLOWER_GOLD := Color("ffd13b")# Tiny daisy core
const COLOR_PLAYFIELD := Color("d2d5e4")  # Swatch 1 lavender playfield below 44%

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

	var div_y = divider_screen_y if divider_screen_y > 0.0 else (0.44 * h)

	# 1. Base 45-Degree Diagonal Striped Manicured Lawn
	if lawn_tex != null:
		draw_texture_rect(lawn_tex, Rect2(0, 0, w, div_y), true)
	else:
		draw_rect(Rect2(0, 0, w, div_y), COLOR_LAWN_DARK)
		var stripe_w: float = 56.5
		var num_stripes: int = int((w + div_y) / stripe_w) + 4
		for i in range(-2, num_stripes, 2):
			var x0 = float(i) * stripe_w
			var pts = PackedVector2Array([
				Vector2(x0, 0),
				Vector2(x0 + stripe_w, 0),
				Vector2(x0 + stripe_w + div_y, div_y),
				Vector2(x0 + div_y, div_y)
			])
			draw_colored_polygon(pts, COLOR_LAWN_LIGHT)

	# 2. Sunlit Ambient Gradient Overlay
	var light_pts = PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0),
		Vector2(w, div_y), Vector2(0, div_y)
	])
	var light_cols = PackedColorArray([
		Color(1.0, 0.98, 0.88, 0.06), Color(1.0, 0.98, 0.88, 0.06),
		Color(0.1, 0.35, 0.08, 0.05), Color(0.1, 0.35, 0.08, 0.05)
	])
	draw_polygon(light_pts, light_cols)

	# 3. 2.5D Volumetric Green Trees & Garden Hedges
	var tr_y = track_screen_y if track_screen_y > 0.0 else (h * 0.20)
	var sc = scale_factor if scale_factor > 0.0 else 1.0
	var track_left_x = (w / 2.0) - (207.0 * sc) # Left apex outer edge (105 + 167.5)
	var track_top_y = tr_y - (167.5 * sc)

	# Group A: Left Garden Grove (Clean Volumetric Green Tree & Shrub Cluster)
	var tree_l_pos = Vector2(maxf(44.0, track_left_x * 0.42), clampf(tr_y - 25.0 * sc, 90.0, div_y - 55.0))
	var bush_l1_pos = Vector2(maxf(32.0, track_left_x * 0.26), clampf(tr_y + 45.0 * sc, 115.0, div_y - 42.0))
	var bush_l2_pos = Vector2(maxf(48.0, track_left_x * 0.65), clampf(tr_y + 85.0 * sc, 135.0, div_y - 36.0))

	_draw_volumetric_tree(tree_l_pos, clampf(36.0 * sc, 24.0, 48.0))
	_draw_cartoon_bush_cluster(bush_l1_pos, clampf(28.0 * sc, 18.0, 38.0), 4)
	_draw_cartoon_bush_cluster(bush_l2_pos, clampf(24.0 * sc, 16.0, 32.0), 3)

	# Group B: Top-Left Garden Bed
	if track_top_y > 75.0:
		var top_l_x = (w / 2.0) - (130.0 * sc)
		if top_l_x > 95.0:
			_draw_volumetric_tree(Vector2(top_l_x, track_top_y - 12.0 * sc), clampf(24.0 * sc, 16.0, 32.0))

	# Group C: Upper-Right Corner Accent (near screen edge, clear of pause button & feeder chute)
	var bush_r_pos = Vector2(w - 32.0, minf(45.0, tr_y - 125.0 * sc))
	_draw_cartoon_bush_cluster(bush_r_pos, clampf(24.0 * sc, 16.0, 32.0), 3)

	# Group D: Delicate daisy dots scattered on the lawn
	_draw_tiny_flower(Vector2(tree_l_pos.x + 24.0, tree_l_pos.y + 28.0), 3.2)
	_draw_tiny_flower(Vector2(bush_l1_pos.x + 20.0, bush_l1_pos.y - 14.0), 2.8)
	_draw_tiny_flower(Vector2(bush_l2_pos.x - 12.0, bush_l2_pos.y + 16.0), 2.6)

	# 4. Solid Playfield Grounding below the 44% Divider line
	if h > div_y:
		draw_rect(Rect2(0, div_y, w, h - div_y), COLOR_PLAYFIELD)

## 2.5D Volumetric Green Cartoon Tree with layered spherical lobes
func _draw_volumetric_tree(center: Vector2, radius: float) -> void:
	# Ground contact shadow
	draw_circle(center + Vector2(0, radius * 0.48), radius * 0.90, Color(0.04, 0.12, 0.04, 0.22))

	var lobes = [
		Vector2(0, 0),
		Vector2(-radius * 0.45, radius * 0.12),
		Vector2(radius * 0.45, radius * 0.12),
		Vector2(-radius * 0.25, -radius * 0.38),
		Vector2(radius * 0.25, -radius * 0.38),
		Vector2(0, -radius * 0.25)
	]

	# Deep base shadow lobes
	for p in lobes:
		draw_circle(center + p, radius * 0.60, COLOR_TREE_SHADOW)

	# Main rich green foliage body
	for p in lobes:
		draw_circle(center + p + Vector2(-1.0, -radius * 0.08), radius * 0.54, COLOR_TREE_BODY)

	# Sunlit highlight domes
	for p in lobes:
		draw_circle(center + p + Vector2(-radius * 0.12, -radius * 0.18), radius * 0.38, COLOR_TREE_LIGHT)

	# Brightest sunlit glint
	draw_circle(center + Vector2(-radius * 0.18, -radius * 0.32), radius * 0.22, COLOR_TREE_TIP)

## Stylized 3-tone foliage bush
func _draw_cartoon_bush_cluster(center: Vector2, radius: float, count: int) -> void:
	var offsets = [
		Vector2(0, 0),
		Vector2(-radius * 0.45, radius * 0.15),
		Vector2(radius * 0.45, radius * 0.15),
		Vector2(-radius * 0.25, -radius * 0.35),
		Vector2(radius * 0.25, -radius * 0.35)
	]

	draw_circle(center + Vector2(0, radius * 0.42), radius * 0.85, Color(0.04, 0.12, 0.04, 0.22))

	for k in range(mini(count, offsets.size())):
		var p = center + offsets[k]
		draw_circle(p, radius * 0.62, COLOR_BUSH_SHADOW)

	for k in range(mini(count, offsets.size())):
		var p = center + offsets[k] + Vector2(-1.0, -radius * 0.08)
		draw_circle(p, radius * 0.56, COLOR_BUSH_BODY)

	for k in range(mini(count, offsets.size())):
		var p = center + offsets[k] + Vector2(-radius * 0.12, -radius * 0.18)
		draw_circle(p, radius * 0.38, COLOR_BUSH_LIGHT)

func _draw_tiny_flower(pos: Vector2, sz: float) -> void:
	draw_circle(pos + Vector2(-sz * 0.6, 0), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos + Vector2(sz * 0.6, 0), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos + Vector2(0, -sz * 0.6), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos + Vector2(0, sz * 0.6), sz * 0.45, COLOR_FLOWER_CREAM)
	draw_circle(pos, sz * 0.45, COLOR_FLOWER_GOLD)
