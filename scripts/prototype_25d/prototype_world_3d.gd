extends Node3D

## Prototype 2.5D World for Bus Fever
## Demonstrates a true 3D scene viewed through an angled Camera3D (25° - 30° tilt)
## with orthographic and perspective projections, soft lighting, modular 3D buses,
## chibi 3D passengers, 3D raised oval track, parking bays, and 3D puzzle board.

@export var camera_tilt_degrees: float = 28.0
@export var use_orthographic: bool = true

var camera: Camera3D
var sun_light: DirectionalLight3D
var world_env: WorldEnvironment

# 3D scale: 1 world unit = 32 pixels
const SCALE_3D: float = 1.0 / 32.0

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_build_ground()
	_build_track()
	_build_parking_platform()
	_build_puzzle_board()
	_spawn_sample_buses()
	_spawn_sample_passengers()

func _setup_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	add_child(world_env)
	
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5a9244") # Stylized garden background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d1e5c8")
	env.ambient_light_energy = 0.55
	
	# Tonemap and soft glow for mobile puzzle look
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.1
	world_env.environment = env
	
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.light_color = Color("fff8eb") # Warm sunlight
	sun_light.light_energy = 1.15
	sun_light.shadow_enabled = true
	sun_light.shadow_blur = 1.5
	sun_light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	add_child(sun_light)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	set_camera_angle(camera_tilt_degrees, use_orthographic)

func set_camera_angle(tilt_deg: float, is_ortho: bool = true) -> void:
	camera_tilt_degrees = tilt_deg
	use_orthographic = is_ortho
	if camera == null:
		return
	
	var rad_tilt = deg_to_rad(tilt_deg)
	var cam_dist = 22.0
	var cam_y = cam_dist * sin(rad_tilt)
	var cam_z = cam_dist * cos(rad_tilt)
	
	# Target screen center slightly shifted to frame both top 40% (track/parking) and bottom 60% (board)
	var target_look := Vector3(0.0, 0.0, 0.5)
	
	camera.position = target_look + Vector3(0.0, cam_y, cam_z)
	camera.rotation_degrees = Vector3(-tilt_deg, 0.0, 0.0)
	
	if is_ortho:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 14.5
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 32.0

func _build_ground() -> void:
	# Main garden lawn
	var ground = CSGBox3D.new()
	ground.name = "GroundLawn"
	ground.size = Vector3(30.0, 0.2, 40.0)
	ground.position = Vector3(0.0, -0.1, 0.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("60993e") # Rich stylized green
	ground_mat.roughness = 0.85
	ground.material = ground_mat
	add_child(ground)
	
	# Stylized decorative garden shrubs framing outer perimeter
	var shrub_coords = [
		Vector3(-5.5, 0.2, -4.5), Vector3(5.5, 0.2, -4.5),
		Vector3(-5.8, 0.2, -1.0), Vector3(6.0, 0.2, 0.5),
		Vector3(-5.5, 0.2, 3.5), Vector3(5.5, 0.2, 4.0),
		Vector3(-4.8, 0.2, 6.0), Vector3(4.8, 0.2, 6.0)
	]
	for sc in shrub_coords:
		var shrub = CSGSphere3D.new()
		shrub.radius = 0.55
		shrub.radial_segments = 16
		shrub.rings = 12
		shrub.position = sc
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color("417326")
		s_mat.roughness = 0.8
		shrub.material = s_mat
		add_child(shrub)

func _build_track() -> void:
	var track_parent = Node3D.new()
	track_parent.name = "Track3D"
	track_parent.position = Vector3(0.0, 0.0, -2.6) # Upper 40% area
	add_child(track_parent)
	
	# Raised track base (Asphalt grey)
	# Oval dimensions in 3D: width ~ 14.0, height ~ 7.5
	var track_w := 14.0
	var track_h := 7.5
	var road_width := 3.8
	
	# Straight segments and curve arcs represented via CSG Combiner
	var road_combiner = CSGCombiner3D.new()
	road_combiner.name = "RoadCombiner"
	track_parent.add_child(road_combiner)
	
	# Outer loop shape
	var outer_box = CSGBox3D.new()
	outer_box.size = Vector3(track_w, 0.15, track_h)
	outer_box.position = Vector3(0.0, 0.075, 0.0)
	road_combiner.add_child(outer_box)
	
	# Inner opening (the 30% inner grass court)
	var inner_cut = CSGBox3D.new()
	inner_cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	inner_cut.size = Vector3(track_w - road_width * 2.0, 0.3, track_h - road_width * 2.0)
	inner_cut.position = Vector3(0.0, 0.1, 0.0)
	road_combiner.add_child(inner_cut)
	
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color("3e4c59") # Dark road grey
	road_mat.roughness = 0.7
	road_combiner.material_override = road_mat
	
	# Feeder Chute (joining from top right off-screen)
	var feeder_road = CSGBox3D.new()
	feeder_road.name = "FeederRoad"
	feeder_road.size = Vector3(road_width, 0.15, 6.0)
	feeder_road.position = Vector3(5.8, 0.075, -4.5)
	feeder_road.rotation_degrees = Vector3(0.0, -28.0, 0.0)
	feeder_road.material = road_mat
	track_parent.add_child(feeder_road)
	
	# White curbs and stone borders
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color("f1f5f9")
	curb_mat.roughness = 0.5
	
	var outer_curb = CSGBox3D.new()
	outer_curb.size = Vector3(track_w + 0.3, 0.22, 0.15)
	outer_curb.position = Vector3(0.0, 0.11, -track_h / 2.0 - 0.075)
	outer_curb.material = curb_mat
	track_parent.add_child(outer_curb)
	
	var outer_curb_bottom = CSGBox3D.new()
	outer_curb_bottom.size = Vector3(track_w + 0.3, 0.22, 0.15)
	outer_curb_bottom.position = Vector3(0.0, 0.11, track_h / 2.0 + 0.075)
	outer_curb_bottom.material = curb_mat
	track_parent.add_child(outer_curb_bottom)

func _build_parking_platform() -> void:
	var plat = Node3D.new()
	plat.name = "ParkingPlatform3D"
	# Positioned right below the track bottom straight
	plat.position = Vector3(0.0, 0.0, 1.3)
	add_child(plat)
	
	# Platform deck
	var deck = CSGBox3D.new()
	deck.name = "Deck"
	deck.size = Vector3(12.5, 0.25, 2.4)
	deck.position = Vector3(0.0, 0.125, 0.0)
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color("475569") # Elevated platform stone
	deck_mat.roughness = 0.6
	deck.material = deck_mat
	plat.add_child(deck)
	
	# White platform boundary curb
	var p_curb = CSGBox3D.new()
	p_curb.size = Vector3(12.7, 0.32, 0.15)
	p_curb.position = Vector3(0.0, 0.16, -1.2)
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color("f8fafc")
	p_curb.material = curb_mat
	plat.add_child(p_curb)
	
	# 7 Parking Bays (Slots 0 to 6)
	var slot_spacing := 1.7
	var start_x := -3.0 * slot_spacing
	
	for i in 7:
		var slot_x = start_x + float(i) * slot_spacing
		var bay = CSGBox3D.new()
		bay.name = "Bay_%d" % i
		bay.size = Vector3(1.35, 0.02, 2.0)
		bay.position = Vector3(slot_x, 0.26, 0.0)
		bay.rotation_degrees = Vector3(0.0, -22.0, 0.0) # 22° slant matching 2D design
		
		var bay_mat := StandardMaterial3D.new()
		if i == 0:
			# VIP slot (amber/gold)
			bay_mat.albedo_color = Color("ca8a04")
		elif i >= 5:
			# Locked slots (darker with lock marker)
			bay_mat.albedo_color = Color("334155")
		else:
			# Normal unlocked slots (neutral clean bay)
			bay_mat.albedo_color = Color("64748b")
		bay.material = bay_mat
		plat.add_child(bay)
		
		# For locked slots 5 and 6, add 3D padlock indicator
		if i >= 5:
			var lock_pillar = CSGCylinder3D.new()
			lock_pillar.radius = 0.12
			lock_pillar.height = 0.4
			lock_pillar.position = Vector3(slot_x, 0.45, 0.0)
			var lock_mat := StandardMaterial3D.new()
			lock_mat.albedo_color = Color("e2e8f0")
			lock_pillar.material = lock_mat
			plat.add_child(lock_pillar)

func _build_puzzle_board() -> void:
	var board = Node3D.new()
	board.name = "PuzzleBoard3D"
	# Positioned in the lower 60% of the screen
	board.position = Vector3(0.0, 0.0, 4.8)
	add_child(board)
	
	# Board tray
	var tray = CSGBox3D.new()
	tray.name = "Tray"
	tray.size = Vector3(8.5, 0.20, 8.5)
	tray.position = Vector3(0.0, 0.10, 0.0)
	var tray_mat := StandardMaterial3D.new()
	tray_mat.albedo_color = Color("1e293b") # Deep puzzle board frame
	tray_mat.roughness = 0.6
	tray.material = tray_mat
	board.add_child(tray)
	
	# Grid surface
	var grid_surface = CSGBox3D.new()
	grid_surface.name = "GridSurface"
	grid_surface.size = Vector3(7.8, 0.22, 7.8)
	grid_surface.position = Vector3(0.0, 0.11, 0.0)
	var surf_mat := StandardMaterial3D.new()
	surf_mat.albedo_color = Color("334155")
	grid_surface.material = surf_mat
	board.add_child(grid_surface)
	
	# Grid cell dividers
	var cell_size := 1.25
	for x in range(-2, 3):
		for z in range(-2, 3):
			var cell = CSGBox3D.new()
			cell.size = Vector3(cell_size - 0.08, 0.02, cell_size - 0.08)
			cell.position = Vector3(float(x) * cell_size, 0.23, float(z) * cell_size)
			var c_mat := StandardMaterial3D.new()
			c_mat.albedo_color = Color("475569")
			cell.material = c_mat
			board.add_child(cell)

func _spawn_sample_buses() -> void:
	# 1. Parked buses in Bays 1, 2, 3
	var slot_spacing := 1.7
	var start_x := -3.0 * slot_spacing
	
	var parked_buses = [
		{"slot": 1, "color": Color("ef4444"), "cap": 40, "code": "v2"}, # Red
		{"slot": 2, "color": Color("3b82f6"), "cap": 40, "code": "v1"}, # Blue
		{"slot": 3, "color": Color("eab308"), "cap": 40, "code": "v3"}, # Yellow
	]
	
	for pb in parked_buses:
		var slot_x = start_x + float(pb["slot"]) * slot_spacing
		var pos = Vector3(slot_x, 0.25, 1.3)
		var bus = _create_bus_model(pb["color"], pb["cap"], pb["code"])
		bus.position = pos
		bus.rotation_degrees = Vector3(0.0, -22.0, 0.0)
		add_child(bus)
	
	# 2. Board puzzle buses
	var board_buses = [
		{"pos": Vector3(-1.25, 0.22, 3.55), "dir": 0.0, "color": Color("ef4444"), "cap": 40, "code": "v4"},
		{"pos": Vector3(1.25, 0.22, 4.8), "dir": 90.0, "color": Color("3b82f6"), "cap": 40, "code": "v6"},
		{"pos": Vector3(-1.25, 0.22, 6.05), "dir": 180.0, "color": Color("eab308"), "cap": 40, "code": "v5"},
		{"pos": Vector3(1.25, 0.22, 6.05), "dir": -90.0, "color": Color("ef4444"), "cap": 40, "code": "v7"},
	]
	for bb in board_buses:
		var bus = _create_bus_model(bb["color"], bb["cap"], bb["code"])
		bus.position = bb["pos"]
		bus.rotation_degrees = Vector3(0.0, bb["dir"], 0.0)
		add_child(bus)

func _create_bus_model(body_color: Color, capacity: int, code: String) -> Node3D:
	var bus = Node3D.new()
	bus.name = "Bus3D_%s" % code
	
	var combiner = CSGCombiner3D.new()
	bus.add_child(combiner)
	
	# Main body (chubby toy-like proportions)
	var body = CSGBox3D.new()
	body.size = Vector3(1.05, 0.65, 1.85)
	body.position = Vector3(0.0, 0.42, 0.0)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.25
	body_mat.metallic = 0.1
	body.material = body_mat
	combiner.add_child(body)
	
	# White roof
	var roof = CSGBox3D.new()
	roof.size = Vector3(0.95, 0.12, 1.65)
	roof.position = Vector3(0.0, 0.78, 0.0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color("ffffff")
	roof_mat.roughness = 0.3
	roof.material = roof_mat
	combiner.add_child(roof)
	
	# Dark tinted windshield / windows
	var glass = CSGBox3D.new()
	glass.size = Vector3(1.07, 0.26, 1.35)
	glass.position = Vector3(0.0, 0.52, 0.15)
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color("1e293b") # Deep tinted glass
	glass_mat.roughness = 0.1
	glass.material = glass_mat
	combiner.add_child(glass)
	
	# 4 Wheels
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color("0f172a") # Rubber black
	wheel_mat.roughness = 0.8
	
	var wheel_offsets = [
		Vector3(-0.54, 0.16, -0.55), Vector3(0.54, 0.16, -0.55),
		Vector3(-0.54, 0.16, 0.55), Vector3(0.54, 0.16, 0.55)
	]
	for wo in wheel_offsets:
		var wheel = CSGCylinder3D.new()
		wheel.radius = 0.16
		wheel.height = 0.12
		wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		wheel.position = wo
		wheel.material = wheel_mat
		combiner.add_child(wheel)
	
	# Floating 3D capacity badge billboard
	var badge = _create_badge_billboard(capacity, body_color)
	badge.position = Vector3(0.0, 1.15, 0.0)
	bus.add_child(badge)
	
	return bus

func _create_badge_billboard(cap: int, col: Color) -> Node3D:
	var b_node = Node3D.new()
	b_node.name = "Badge"
	
	# Pill capsule
	var pill = CSGBox3D.new()
	pill.size = Vector3(0.65, 0.32, 0.10)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = col
	p_mat.roughness = 0.3
	pill.material = p_mat
	b_node.add_child(pill)
	
	# Floating 3D label
	var lbl = Label3D.new()
	lbl.text = str(cap)
	lbl.font_size = 32
	lbl.pixel_size = 0.007
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.modulate = Color.WHITE
	lbl.outline_modulate = Color("1e293b")
	lbl.outline_size = 8
	lbl.position = Vector3(0.0, 0.0, 0.06)
	b_node.add_child(lbl)
	
	return b_node

func _spawn_sample_passengers() -> void:
	# 4-across dense rows on track and feeder
	var track_center := Vector3(0.0, 0.0, -2.6)
	
	# Bottom straight circulating rows (moving towards parking)
	var colors = [Color("ef4444"), Color("ef4444"), Color("3b82f6"), Color("eab308")]
	for row_idx in 4:
		var row_z = track_center.z + 2.5 - float(row_idx) * 0.75
		var col = colors[row_idx]
		for lane in 4:
			var lane_x = -1.2 + float(lane) * 0.8
			var p = _create_chibi_passenger(col)
			p.position = Vector3(lane_x, 0.15, row_z)
			add_child(p)
	
	# Feeder chute rows (queued 4-across)
	for f_row in 3:
		var f_z = track_center.z - 3.2 - float(f_row) * 0.75
		var f_x = 5.2 - float(f_row) * 0.35
		var col = Color("eab308") if f_row == 0 else (Color("3b82f6") if f_row == 1 else Color("ef4444"))
		for lane in 4:
			var p = _create_chibi_passenger(col)
			p.position = Vector3(f_x + (float(lane) - 1.5) * 0.7, 0.15, f_z)
			add_child(p)

func _create_chibi_passenger(col: Color) -> Node3D:
	var p = Node3D.new()
	p.name = "Passenger3D"
	
	# Ground contact shadow disk
	var shadow = CSGCylinder3D.new()
	shadow.radius = 0.22
	shadow.height = 0.01
	shadow.position = Vector3(0.0, 0.005, 0.0)
	var sh_mat := StandardMaterial3D.new()
	sh_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.45)
	sh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material = sh_mat
	p.add_child(shadow)
	
	# Torso (colored hoodie / body)
	var body = CSGCylinder3D.new()
	body.radius = 0.18
	body.height = 0.35
	body.position = Vector3(0.0, 0.22, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = col
	b_mat.roughness = 0.5
	body.material = b_mat
	p.add_child(body)
	
	# Cute spherical head
	var head = CSGSphere3D.new()
	head.radius = 0.17
	head.position = Vector3(0.0, 0.48, 0.0)
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color("ffdfba") # Warm peach skin
	h_mat.roughness = 0.4
	head.material = h_mat
	p.add_child(head)
	
	# Cap / hair on top matching body color
	var cap = CSGSphere3D.new()
	cap.radius = 0.175
	cap.position = Vector3(0.0, 0.52, -0.02)
	cap.material = b_mat
	p.add_child(cap)
	
	return p
