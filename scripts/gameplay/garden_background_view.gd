extends Control
class_name GardenBackgroundView

## Stylized Cartoon Garden Background
## Renders a polished mobile-game park/garden surface with soft grass tonal variation,
## subtle manicured lawn striping, and clean vector cartoon bushes/planted borders.
## 100% procedural/vector — zero photo collages, zero stickers, zero clutter.

const COLOR_GRASS_TOP := Color("6bb22b") # Sunlit meadow green
const COLOR_GRASS_MID := Color("62a226") # Primary lush park green
const COLOR_GRASS_BTM := Color("589420") # Grounding depth green

const COLOR_STRIPE_LIGHT := Color(1.0, 1.0, 1.0, 0.035) # Subtle lawn mower stripe
const COLOR_BUSH_SHADOW := Color("2d520e") # Cartoon bush dark base/crevice
const COLOR_BUSH_BODY := Color("4f8c19")   # Cartoon bush rich foliage
const COLOR_BUSH_LIGHT := Color("6eb226")  # Cartoon bush sunlit top lobe
const COLOR_FLOWER_CREAM := Color("fffde6") # Tiny daisy petal
const COLOR_FLOWER_GOLD := Color("ffd13b")  # Tiny daisy core

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	if w <= 0.0 or h <= 0.0:
		return

	# 1. Base Grass Fill with smooth tonal gradient
	var steps = 16
	var step_h = h / float(steps)
	for i in range(steps):
		var t = float(i) / float(steps - 1)
		var c = COLOR_GRASS_TOP.lerp(COLOR_GRASS_BTM, t)
		draw_rect(Rect2(0, float(i) * step_h, w, step_h + 1.0), c)

	# 2. Subtle Manicured Lawn Striping (soft diagonal bands)
	var stripe_w: float = 46.0
	var total_diag = w + h
	var num_stripes = int(total_diag / stripe_w) + 2
	for i in range(0, num_stripes, 2):
		var x_start = float(i) * stripe_w - h * 0.45
		var stripe_pts = PackedVector2Array([
			Vector2(x_start, 0),
			Vector2(x_start + stripe_w, 0),
			Vector2(x_start + stripe_w + h * 0.45, h),
			Vector2(x_start + h * 0.45, h)
		])
		draw_colored_polygon(stripe_pts, COLOR_STRIPE_LIGHT)

	# 3. Stylized Cartoon Hedge & Bush Clusters in Upper Perimeter
	# Top-Left park corner (stylized rounded cartoon lobes)
	_draw_cartoon_bush_cluster(Vector2(w * 0.08, h * 0.12), 48.0, 5)
	_draw_cartoon_bush_cluster(Vector2(w * 0.02, h * 0.22), 42.0, 4)
	_draw_cartoon_bush_cluster(Vector2(w * 0.05, h * 0.32), 36.0, 3)

	# Top-Right park corner (behind top straight & upper curve)
	_draw_cartoon_bush_cluster(Vector2(w * 0.94, h * 0.08), 44.0, 4)
	_draw_cartoon_bush_cluster(Vector2(w * 0.98, h * 0.18), 38.0, 3)

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
	draw_circle(center + Vector2(0, radius * 0.45), radius * 0.85, Color(0, 0, 0, 0.08))

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

	# Phase E: Tiny stylized flower accents (2-3 tiny daisies)
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
