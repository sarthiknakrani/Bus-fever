extends Node2D
class_name PlazaEnvironment

## 3D Tropical Water Lagoon (Inside Passenger Oval Loop)
## Renders a vibrant, crystal-clear 3D lagoon water body inside the elevated track:
## - Deep tropical turquoise water fill matching the surrounding ocean
## - Pristine white contact foam ring hugging the inner concrete retaining curb
## - Gentle undulating lagoon ripples with sunlit highlights and caustics
## - Subtle sparkling diamond sun glints dancing on the water surface

var _island_draw_node: Node2D
var _water_time: float = 0.0

func _ready() -> void:
	z_index = -1
	visible = true
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
	var r: float = 62.0
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

	# 1. Base vibrant lagoon water fill matching surrounding Caribbean ocean
	_island_draw_node.draw_colored_polygon(island_pts, Color("0284c7"))

	# 2. Sunlit diagonal caustic wash across lagoon
	var sun_wash := PackedVector2Array([
		cl + Vector2(-r * 0.8, -r * 0.8),
		Vector2(sx * 0.5, -r),
		Vector2(-sx * 0.2, r),
		cl + Vector2(-r * 0.8, r * 0.5)
	])
	_island_draw_node.draw_colored_polygon(sun_wash, Color(0.24, 0.88, 0.98, 0.18))

	# 3. Inner Shoreline Contact Foam hugging the elevated track's inner retaining wall
	var foam_pulse = sin(_water_time * 2.5) * 1.2
	_island_draw_node.draw_polyline(island_pts, Color(0.68, 0.92, 1.0, 0.40), 6.0 + foam_pulse, true)
	_island_draw_node.draw_polyline(island_pts, Color(1.0, 1.0, 1.0, 0.75), 2.4, true)

	# 4. Concentric & Lateral Lagoon Ripples with sunlit crest highlights
	var ripple_y_bands = [-32.0, -10.0, 14.0, 36.0]
	for idx in range(ripple_y_bands.size()):
		var base_y = ripple_y_bands[idx]
		var rip_phase = idx * 1.5 + _water_time * 1.6
		var rip_pts := PackedVector2Array()
		var steps = 24
		for st in range(steps + 1):
			var norm = float(st) / float(steps)
			var rx = lerpf(-sx * 0.82, sx * 0.82, norm)
			# Bound within lagoon curve
			var ry = base_y + sin(rx * 0.045 + rip_phase) * 3.5 + cos(rx * 0.02 - rip_phase * 0.8) * 1.8
			rip_pts.append(Vector2(rx, ry))

		# Ripple shadow & crest
		_island_draw_node.draw_polyline(rip_pts, Color(0.01, 0.14, 0.32, 0.22), 3.5, false)
		_island_draw_node.draw_polyline(rip_pts, Color(0.88, 0.98, 1.0, 0.55), 2.0, false)

	# 5. Sparkling Diamond Sun Glint in Center Lagoon
	var glint_pulse = maxf(0.0, sin(_water_time * 3.0))
	if glint_pulse > 0.15:
		_draw_diamond_glint(Vector2(-15.0, -8.0), 5.5 * glint_pulse, Color(1.0, 1.0, 1.0, glint_pulse * 0.85))
	var glint2_pulse = maxf(0.0, sin(_water_time * 2.8 + 1.8))
	if glint2_pulse > 0.15:
		_draw_diamond_glint(Vector2(45.0, 18.0), 4.5 * glint2_pulse, Color(1.0, 1.0, 1.0, glint2_pulse * 0.80))

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
