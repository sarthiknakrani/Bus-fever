class_name PlatformLayoutGenerator
extends RefCounted

## Deterministic Platform Layout Generator.
## Implements all 7 Reference-Inspired Formation Templates:
##  A. Rectangular Packed
##  B. Concentric Rings
##  C. Nested Rounded Rectangles
##  D. U-Shaped / C-Shaped
##  E. Spiral-Like
##  F. Diagonal Bands
##  G. Irregular Clusters
## Uses arc-length Curve2D sampling, local tangent orientation, and SAT collision validation.

const DEFAULT_BUS_LEN: float = BusCollisionGeometry.DEFAULT_BUS_LENGTH # 86.0
const DEFAULT_BUS_WID: float = BusCollisionGeometry.DEFAULT_BUS_WIDTH  # 42.0
const DEFAULT_GAP: float = BusCollisionGeometry.DEFAULT_MIN_CLEARANCE   # 5.0

## Master entry point: generates a complete, physically validated PlatformGeometry.
static func generate_layout(
	type: int, # PlatformGeometry.LayoutType
	params: Dictionary = {},
	seed_val: int = 12345
) -> PlatformGeometry:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var plat := PlatformGeometry.new()
	plat.mode = PlatformGeometry.Mode.FREEFORM
	plat.layout_type = type
	plat.deterministic_seed = seed_val
	plat.bus_length = params.get("bus_length", DEFAULT_BUS_LEN)
	plat.bus_width = params.get("bus_width", DEFAULT_BUS_WID)
	plat.min_clearance = params.get("min_clearance", DEFAULT_GAP)
	plat.playable_bounds = params.get("playable_bounds", Rect2(-240.0, -240.0, 480.0, 480.0))
	plat.setup_default_boundary()

	match type:
		PlatformGeometry.LayoutType.RECTANGULAR_PACKED:
			_build_rectangular_packed(plat, params, rng)
		PlatformGeometry.LayoutType.CONCENTRIC_RINGS:
			_build_concentric_rings(plat, params, rng)
		PlatformGeometry.LayoutType.NESTED_RECTANGLES:
			_build_nested_rectangles(plat, params, rng)
		PlatformGeometry.LayoutType.U_SHAPED:
			_build_u_shaped(plat, params, rng)
		PlatformGeometry.LayoutType.SPIRAL:
			_build_spiral(plat, params, rng)
		PlatformGeometry.LayoutType.DIAGONAL_BANDS:
			_build_diagonal_bands(plat, params, rng)
		PlatformGeometry.LayoutType.IRREGULAR_CLUSTERS:
			_build_irregular_clusters(plat, params, rng)
		_:
			_build_rectangular_packed(plat, params, rng)

	# Assign slot IDs and sequential default vehicle IDs
	for i in range(plat.slots.size()):
		var s := plat.slots[i]
		s.slot_id = i + 1
		s.assigned_vehicle_id = i + 1

	return plat

## --- TEMPLATE A: RECTANGULAR PACKED ---
static func _build_rectangular_packed(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "Rectangular Packed Formation"
	var rows: int = params.get("rows", 3)
	var cols: int = params.get("cols", 3)
	var stagger: bool = params.get("stagger", false)
	# For vertical escaping columns, Y spacing accommodates bus length, X spacing accommodates bus width
	var spacing_x: float = plat.bus_width + plat.min_clearance + 14.0
	var spacing_y: float = plat.bus_length + plat.min_clearance + 14.0

	var origin_x: float = -float(cols - 1) * spacing_x * 0.5
	var origin_y: float = -float(rows - 1) * spacing_y * 0.5

	var colors: Array[String] = ["blue", "red", "yellow", "green", "purple"]

	for r in range(rows):
		var row_offset_x := (spacing_x * 0.45) if (stagger and (r % 2 == 1)) else 0.0
		for c in range(cols):
			var pos := Vector2(origin_x + float(c) * spacing_x + row_offset_x, origin_y + float(r) * spacing_y)
			var escape_dir := Vector2(0, -1) if r <= 1 else Vector2(0, 1)
			var heading := escape_dir.angle()
			_try_add_candidate_slot(plat, pos, heading, escape_dir, colors[rng.randi() % colors.size()])

## --- TEMPLATE B: CONCENTRIC RINGS ---
static func _build_concentric_rings(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "Concentric Rings Formation"
	var radii: Array = params.get("radii", [95.0, 175.0])
	var colors: Array[String] = ["blue", "red", "yellow", "green", "purple", "orange"]

	for ring_idx in range(radii.size()):
		var radius: float = radii[ring_idx]
		var circle_curve := _create_closed_circle_curve(radius)
		var curve_len := circle_curve.get_baked_length()
		var step_dist: float = plat.bus_length + plat.min_clearance + 12.0
		var count: int = int(floor(curve_len / step_dist))
		if count < 3: count = 3
		var actual_spacing: float = curve_len / float(count)

		for i in range(count):
			var s: float = float(i) * actual_spacing
			var pos := circle_curve.sample_baked(s)

			var s_ahead := fposmod(s + 2.0, curve_len)
			var s_back := fposmod(s - 2.0, curve_len)
			var pos_ahead := circle_curve.sample_baked(s_ahead)
			var pos_back := circle_curve.sample_baked(s_back)
			var tangent := (pos_ahead - pos_back).normalized()
			var radial_out := pos.normalized()

			# Outer ring escapes outward radially; inner ring can escape tangential or outward
			var escape_dir := radial_out if (ring_idx == radii.size() - 1 or rng.randf() > 0.4) else tangent
			var heading := tangent.angle() if rng.randf() > 0.3 else radial_out.angle()

			_try_add_candidate_slot(plat, pos, heading, escape_dir, colors[rng.randi() % colors.size()])

## --- TEMPLATE C: NESTED ROUNDED RECTANGLES ---
static func _build_nested_rectangles(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "Nested Rounded Rectangles Formation"
	var layers: Array = params.get("layers", [
		{"w": 220.0, "h": 150.0, "r": 28.0},
		{"w": 380.0, "h": 280.0, "r": 45.0}
	])
	var colors: Array[String] = ["red", "blue", "yellow", "orange", "green"]

	for l_idx in range(layers.size()):
		var lyr: Dictionary = layers[l_idx]
		var curve := _create_rounded_rect_curve(lyr["w"], lyr["h"], lyr["r"])
		var total_len := curve.get_baked_length()
		var step_dist: float = plat.bus_length + plat.min_clearance + 10.0
		var count: int = int(floor(total_len / step_dist))
		var actual_spacing := total_len / float(maxi(1, count))

		for i in range(count):
			var s := float(i) * actual_spacing
			var pos := curve.sample_baked(s)
			var pos_ahead := curve.sample_baked(fposmod(s + 2.0, total_len))
			var pos_back := curve.sample_baked(fposmod(s - 2.0, total_len))
			var tangent := (pos_ahead - pos_back).normalized()
			var normal := Vector2(-tangent.y, tangent.x).normalized()
			if normal.dot(pos) < 0.0:
				normal = -normal # Outward facing normal

			var escape_dir := normal if (l_idx == layers.size() - 1 or rng.randf() > 0.35) else tangent
			var heading := tangent.angle()
			_try_add_candidate_slot(plat, pos, heading, escape_dir, colors[rng.randi() % colors.size()])

## --- TEMPLATE D: U-SHAPED / C-SHAPED FORMATIONS ---
static func _build_u_shaped(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "U-Shaped Horseshoe Formation"
	var curve := Curve2D.new()
	# Open top horseshoe: Left arm down, rounded bottom, right arm up
	curve.add_point(Vector2(-130.0, -140.0), Vector2.ZERO, Vector2(0.0, 60.0))
	curve.add_point(Vector2(-130.0, 70.0), Vector2(0.0, -40.0), Vector2(0.0, 50.0))
	curve.add_point(Vector2(0.0, 160.0), Vector2(-60.0, 0.0), Vector2(60.0, 0.0))
	curve.add_point(Vector2(130.0, 70.0), Vector2(0.0, 50.0), Vector2(0.0, -40.0))
	curve.add_point(Vector2(130.0, -140.0), Vector2(0.0, 60.0), Vector2.ZERO)

	var total_len := curve.get_baked_length()
	var step_dist: float = plat.bus_length + plat.min_clearance + 6.0
	var count: int = int(floor(total_len / step_dist))
	var colors: Array[String] = ["yellow", "red", "blue", "green"]

	for i in range(count):
		var s := float(i) * (total_len / float(maxi(1, count - 1)))
		var pos := curve.sample_baked(s)
		var pos_ahead := curve.sample_baked(minf(total_len, s + 2.0))
		var pos_back := curve.sample_baked(maxf(0.0, s - 2.0))
		var tangent := (pos_ahead - pos_back).normalized()
		var outward := Vector2(-tangent.y, tangent.x).normalized()
		if outward.dot(pos) < 0.0:
			outward = -outward

		var escape_dir := outward if rng.randf() > 0.4 else tangent
		_try_add_candidate_slot(plat, pos, tangent.angle(), escape_dir, colors[rng.randi() % colors.size()])

## --- TEMPLATE E: SPIRAL-LIKE FORMATIONS ---
static func _build_spiral(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "Spiral Formation"
	var curve := Curve2D.new()
	var num_pts := 32
	var max_theta: float = 3.5 * PI
	var r0: float = 40.0
	var k: float = 14.0

	for i in range(num_pts):
		var th: float = (float(i) / float(num_pts - 1)) * max_theta
		var r: float = r0 + (k * th)
		var pt := Vector2(cos(th), sin(th)) * r
		curve.add_point(pt)

	var total_len := curve.get_baked_length()
	var step_dist: float = plat.bus_length + plat.min_clearance + 8.0
	var count: int = int(floor(total_len / step_dist))
	var colors: Array[String] = ["purple", "yellow", "blue", "red", "green"]

	for i in range(count):
		var s := float(i) * (total_len / float(maxi(1, count - 1)))
		var pos := curve.sample_baked(s)
		var pos_ahead := curve.sample_baked(minf(total_len, s + 2.0))
		var pos_back := curve.sample_baked(maxf(0.0, s - 2.0))
		var tangent := (pos_ahead - pos_back).normalized()
		var radial_out := pos.normalized()

		# Outer slots escape outward; inner slots follow tangent winding outwards
		var escape_dir := radial_out if (i >= count - 4) else tangent
		_try_add_candidate_slot(plat, pos, tangent.angle(), escape_dir, colors[rng.randi() % colors.size()])

## --- TEMPLATE F: DIAGONAL BANDS ---
static func _build_diagonal_bands(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "Diagonal Bands Formation"
	var angle_deg: float = params.get("angle_degrees", 35.0)
	var angle_rad: float = deg_to_rad(angle_deg)
	var dir_u := Vector2(cos(angle_rad), sin(angle_rad))       # Along band
	var dir_v := Vector2(-sin(angle_rad), cos(angle_rad))     # Across bands

	var num_bands: int = params.get("num_bands", 3)
	var buses_per_band: int = params.get("buses_per_band", 3)
	var spacing_u: float = plat.bus_length + plat.min_clearance + 8.0
	var spacing_v: float = plat.bus_width + plat.min_clearance + 12.0

	var origin := Vector2.ZERO - (dir_v * (float(num_bands - 1) * spacing_v * 0.5)) - (dir_u * (float(buses_per_band - 1) * spacing_u * 0.5))
	var colors: Array[String] = ["blue", "yellow", "red", "pink", "green"]

	for b in range(num_bands):
		var band_base := origin + (dir_v * (float(b) * spacing_v))
		for i in range(buses_per_band):
			var pos := band_base + (dir_u * (float(i) * spacing_u))
			var escape_dir := dir_u if i >= buses_per_band / 2 else -dir_u
			if b == 0: escape_dir = -dir_v
			elif b == num_bands - 1: escape_dir = dir_v

			_try_add_candidate_slot(plat, pos, dir_u.angle(), escape_dir, colors[rng.randi() % colors.size()])

## --- TEMPLATE G: IRREGULAR CLUSTERS ---
static func _build_irregular_clusters(plat: PlatformGeometry, params: Dictionary, rng: RandomNumberGenerator) -> void:
	plat.title = "Irregular Cluster Formation"
	var colors: Array[String] = ["blue", "red", "yellow", "green", "purple"]

	# Central core arc
	var core_pts := [
		{"pos": Vector2(-70, -20), "rot": deg_to_rad(-15), "esc": Vector2(-1, 0)},
		{"pos": Vector2(0, -35),   "rot": 0.0,              "esc": Vector2(0, -1)},
		{"pos": Vector2(70, -20),  "rot": deg_to_rad(15),  "esc": Vector2(1, 0)},
		{"pos": Vector2(-38, 45),  "rot": deg_to_rad(90),  "esc": Vector2(0, 1)},
		{"pos": Vector2(38, 45),   "rot": deg_to_rad(90),  "esc": Vector2(0, 1)},
	]
	# Satellite flanking clusters
	var satellite_pts := [
		{"pos": Vector2(-155, -80), "rot": deg_to_rad(-45), "esc": Vector2(-1, -1).normalized()},
		{"pos": Vector2(155, -80),  "rot": deg_to_rad(45),  "esc": Vector2(1, -1).normalized()},
		{"pos": Vector2(-150, 95),  "rot": deg_to_rad(135), "esc": Vector2(-1, 1).normalized()},
		{"pos": Vector2(150, 95),   "rot": deg_to_rad(45),  "esc": Vector2(1, 1).normalized()},
	]

	for cfg in core_pts:
		_try_add_candidate_slot(plat, cfg["pos"], cfg["rot"], cfg["esc"], colors[rng.randi() % colors.size()])
	for cfg in satellite_pts:
		_try_add_candidate_slot(plat, cfg["pos"], cfg["rot"], cfg["esc"], colors[rng.randi() % colors.size()])

## Internal helper: attempts to place a slot, rejecting collisions via SAT.
static func _try_add_candidate_slot(
	plat: PlatformGeometry,
	pos: Vector2,
	heading_rad: float,
	escape_dir: Vector2,
	color_id: String
) -> bool:
	# 1. Bounds check
	if not plat.boundary_polygon.is_empty():
		if not BusCollisionGeometry.is_obb_inside_bounds(pos, heading_rad, plat.bus_length, plat.bus_width, plat.boundary_polygon):
			return false

	# 2. Collision check against already accepted slots
	for s in plat.slots:
		var overlap := BusCollisionGeometry.test_obb_overlap(
			pos, heading_rad, plat.bus_length, plat.bus_width,
			s.position, s.rotation, s.length, s.width,
			plat.min_clearance
		)
		if overlap:
			return false

	# 3. Create and add slot
	var slot := PlatformSlotDef.new()
	slot.position = pos
	slot.rotation = heading_rad
	slot.escape_direction = escape_dir.normalized()
	slot.length = plat.bus_length
	slot.width = plat.bus_width
	slot.assigned_color_id = color_id
	slot.assigned_capacity = 40
	plat.add_slot(slot)
	return true

## Generates a smooth closed Curve2D approximating a circle.
static func _create_closed_circle_curve(radius: float) -> Curve2D:
	var curve := Curve2D.new()
	var n_pts := 12
	var handle_len := radius * (4.0 / 3.0) * tan(PI / float(2 * n_pts))

	for i in range(n_pts):
		var th := float(i) * (2.0 * PI / float(n_pts))
		var pt := Vector2(cos(th), sin(th)) * radius
		var tan_unit := Vector2(-sin(th), cos(th))
		var in_tan := -tan_unit * handle_len
		var out_tan := tan_unit * handle_len
		curve.add_point(pt, in_tan, out_tan)

	# Close loop
	var pt0 := Vector2(radius, 0.0)
	var tan0 := Vector2(0.0, 1.0)
	curve.add_point(pt0, -tan0 * handle_len, tan0 * handle_len)
	return curve

## Generates a smooth rounded rectangular Curve2D.
static func _create_rounded_rect_curve(w: float, h: float, r: float) -> Curve2D:
	var curve := Curve2D.new()
	var hx := w * 0.5 - r
	var hy := h * 0.5 - r
	var handle := r * 0.55228

	# Top right corner to bottom right, bottom left, top left
	curve.add_point(Vector2(hx, -hy - r), Vector2.ZERO, Vector2.ZERO)
	curve.add_point(Vector2(hx + r, -hy), Vector2(0, -handle), Vector2(0, handle))
	curve.add_point(Vector2(hx + r, hy), Vector2.ZERO, Vector2.ZERO)
	curve.add_point(Vector2(hx, hy + r), Vector2(handle, 0), Vector2(-handle, 0))
	curve.add_point(Vector2(-hx, hy + r), Vector2.ZERO, Vector2.ZERO)
	curve.add_point(Vector2(-hx - r, hy), Vector2(0, handle), Vector2(0, -handle))
	curve.add_point(Vector2(-hx - r, -hy), Vector2.ZERO, Vector2.ZERO)
	curve.add_point(Vector2(-hx, -hy - r), Vector2(-handle, 0), Vector2(handle, 0))
	# Close
	curve.add_point(Vector2(hx, -hy - r), Vector2.ZERO, Vector2.ZERO)
	return curve
