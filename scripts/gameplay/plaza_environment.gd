extends Node2D
class_name PlazaEnvironment

## 3D Tropical Water Lagoon (Inside Passenger Oval Loop)
## Renders a vibrant, crystal-clear 3D lagoon water body inside the elevated track:
## - Deep tropical turquoise water fill matching the surrounding ocean
## - Pristine white contact foam ring hugging the inner concrete retaining curb
## - Gentle undulating lagoon ripples with sunlit highlights and caustics
## - Subtle sparkling diamond sun glints dancing on the water surface

var _island_draw_node: Node2D
var _water_time: float = 2.5

func _ready() -> void:
	z_index = -1
	visible = true
	# Animated lagoon water flow matching the surrounding ocean waves
	set_process(true)
	_build_lagoon_accents()

func _process(delta: float) -> void:
	_water_time += delta
	if _island_draw_node != null:
		_island_draw_node.queue_redraw()

func _build_lagoon_accents() -> void:
	for c in get_children():
		c.queue_free()

	_island_draw_node = Node2D.new()
	_island_draw_node.name = "LagoonWaterBed"
	_island_draw_node.draw.connect(_on_draw_lagoon)
	add_child(_island_draw_node)

func _on_draw_lagoon() -> void:
	var sx: float = 105.0
	var r: float = 70.0 # Matches r_inner = r_center (115.0) - ROAD_HALF_WIDTH (45.0) = 70.0
	var cl := Vector2(-sx, 0.0)
	var cr := Vector2(sx, 0.0)
	var n_arc := 36

	var island_pts := PackedVector2Array()
	island_pts.append(Vector2(sx, -r))
	island_pts.append(Vector2(-sx, -r))
	for i in range(1, n_arc):
		var a = -PI / 2.0 - (float(i) / float(n_arc)) * PI
		island_pts.append(cl + Vector2(cos(a), sin(a)) * r)
	island_pts.append(Vector2(-sx, r))
	island_pts.append(Vector2(sx, r))
	for i in range(1, n_arc):
		var a = PI / 2.0 - (float(i) / float(n_arc)) * PI
		island_pts.append(cr + Vector2(cos(a), sin(a)) * r)

	# 1. Clear crystal shallow water tint near inner concrete pier foundation
	# Translucent so the continuous background ocean waves show right through seamlessly!
	_island_draw_node.draw_colored_polygon(island_pts, Color(0.12, 0.72, 0.92, 0.12))

	# 2. Inner shoreline contact foam hugging the elevated track's retaining wall
	var foam_pulse = sin(_water_time * 2.2) * 1.0
	_island_draw_node.draw_polyline(island_pts, Color(0.68, 0.92, 1.0, 0.35), 4.5 + foam_pulse, true)
	_island_draw_node.draw_polyline(island_pts, Color(1.0, 1.0, 1.0, 0.65), 2.0, true)

	# 3. Sparkling diamond sun glints on the wave crests inside the lagoon
	var glint_pulse = maxf(0.0, sin(_water_time * 2.8))
	if glint_pulse > 0.15:
		_draw_diamond_glint(Vector2(-15.0, -8.0), 4.5 * glint_pulse, Color(1.0, 1.0, 1.0, glint_pulse * 0.85))
	var glint2_pulse = maxf(0.0, sin(_water_time * 2.6 + 1.8))
	if glint2_pulse > 0.15:
		_draw_diamond_glint(Vector2(35.0, 12.0), 3.8 * glint2_pulse, Color(1.0, 1.0, 1.0, glint2_pulse * 0.80))

func _draw_diamond_glint(pos: Vector2, sz: float, col: Color) -> void:
	var pts = PackedVector2Array([
		pos + Vector2(0, -sz),
		pos + Vector2(sz * 0.35, 0),
		pos + Vector2(0, sz),
		pos + Vector2(-sz * 0.35, 0)
	])
	_island_draw_node.draw_colored_polygon(pts, col)
	var pts2 = PackedVector2Array([
		pos + Vector2(-sz, 0),
		pos + Vector2(0, sz * 0.35),
		pos + Vector2(sz, 0),
		pos + Vector2(0, -sz * 0.35)
	])
	_island_draw_node.draw_colored_polygon(pts2, col)
	_island_draw_node.draw_circle(pos, sz * 0.22, Color.WHITE)
