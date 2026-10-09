extends Node2D
class_name CarJamLevel

## Production-quality Car Jam single-level gameplay scene.
## Pure Godot 2D architecture with 2.5D pseudo-3D layered buses,
## exactly 4 parking slots, swept-footprint collision, and ordered passenger queue.

const CarJamLevelData := preload("res://data/level_data.gd")
const CarJamLevelFactory := preload("res://scripts/gameplay/level_factory.gd")
const CarJamController := preload("res://scripts/gameplay/car_jam_controller.gd")
const BoardView := preload("res://scripts/gameplay/board_view.gd")
const VehicleView := preload("res://scripts/gameplay/vehicle_view.gd")
const ParkingSlotView := preload("res://scripts/gameplay/parking_slot_view.gd")
const PassengerView := preload("res://scripts/gameplay/passenger_view.gd")
const VehicleMovement := preload("res://scripts/gameplay/vehicle_movement.gd")
const SimpleStyle := preload("res://scripts/ui/style_helpers.gd")

# Metrics
const CELL_SIZE: float = 78.0
const BOARD_Y: float = 720.0
const PARKING_Y: float = 405.0
const PASSENGER_TRACK_Y: float = 195.0
const FUNNEL_Y: float = 315.0

# Hierarchy Nodes
var world_root: Node2D
var board_root: Node2D
var board_bg: BoardView
var platform_bg: Node2D
var vehicle_layer: Node2D
var board_effects: Node2D

var parking_root: Node2D
var parking_slots_node: Node2D
var parked_vehicles_node: Node2D

var passenger_track_root: Node2D
var passenger_visuals: Node2D
var boarding_paths_root: Node2D
var boarding_effects: Node2D

var transit_layer: Node2D
var camera_2d: Camera2D

# HUD Nodes
var hud: CanvasLayer
var safe_area_root: Control
var top_bar: Control
var booster_bar: Control
var pause_overlay: Control
var result_overlay: Control

var level_title_label: Label
var result_title_label: Label
var result_btn: TextureButton

var _toast_panel: PanelContainer
var _toast_tween: Tween

# Authoritative Controller
var controller: CarJamController
var vehicle_views: Dictionary = {} # int id -> VehicleView
var slot_views: Array[ParkingSlotView] = []

# Continuous Passenger Track State
var passenger_track: Path2D
var all_passengers: Dictionary = {}
var circulating_ids: Array[int] = []
var _speed_logged: bool = false
var slot_boarding_points: Dictionary = {}
var _waiting_label: Label
var track_time: float = 0.0
const PASSENGER_SPACING := 50.0
@export var passenger_normal_speed: float = 150.0
@export var passenger_sprint_speed: float = 250.0
@export var bus_movement_duration_multiplier: float = 3.0
const TRACK_SPEED := 40.0


var _anim_clock: float = 0.0


func _process(delta: float) -> void:
	if passenger_track == null: return
	if controller.state != CarJamController.GameState.PLAYING: return
	
	var track_len = passenger_track.curve.get_baked_length()
	if not _speed_logged and circulating_ids.size() > 0:
		_speed_logged = true
		print("[QA] Loop length: ", track_len, " px")
		print("[QA] Normal lap: ", track_len / passenger_normal_speed, " s")
		print("[QA] Sprint lap: ", track_len / passenger_sprint_speed, " s")
		print("[QA] Normal delta/frame (60Hz): ", passenger_normal_speed / 60.0, " px")
		print("[QA] Sprint delta/frame (60Hz): ", passenger_sprint_speed / 60.0, " px")

	var to_remove = []
	
	for i in circulating_ids.size():
		var pid = circulating_ids[i]
		var p = all_passengers[pid]
		if p["state"] != "CIRCULATING": continue
		
		# ---------------------------------------------
		# GAP CLOSING LOGIC
		# ---------------------------------------------
		var speed = passenger_normal_speed
		if circulating_ids.size() > 1:
			var ahead_idx = (i + 1) % circulating_ids.size()
			var ahead_id = circulating_ids[ahead_idx]
			var p_ahead = all_passengers[ahead_id]
			
			var diff = p_ahead["progress"] - p["progress"]
			if diff < 0: diff += track_len
			
			# If the gap is larger than the ideal spacing, smoothly speed up to catch up!
			if diff > PASSENGER_SPACING * 1.2:
				speed = passenger_sprint_speed
		# ---------------------------------------------
		
		var old_prog = p["progress"]
		var dist_moved = speed * delta
		
		# Build a sorted list of crossing events
		var crossings = []
		for slot_idx in slot_boarding_points:
			var trigger_prog = slot_boarding_points[slot_idx]
			var dist_to_gate = trigger_prog - old_prog
			if dist_to_gate < 0:
				dist_to_gate += track_len
				
			# Passenger could loop multiple times in one frame at extreme speeds.
			# We find EVERY time they cross this gate within dist_moved.
			var d = dist_to_gate
			while d <= dist_moved:
				crossings.append({ "dist": d, "slot": slot_idx, "trigger": trigger_prog })
				d += track_len
				
		crossings.sort_custom(func(a, b): return a["dist"] < b["dist"])
		
		var boarded = false
		for cross in crossings:
			var slot_idx = cross["slot"]
			var trigger_prog = cross["trigger"]
			var slot = controller.parking.get_slot(slot_idx)
			
			if slot and slot.state == CarJamParkingManager.SlotState.OCCUPIED and slot.vehicle_id != -1:
				if controller.try_reserve_boarding(slot.vehicle_id, p["color_id"]):
					p["state"] = "BOARDING"
					to_remove.append(pid)
					# DO NOT snap visual progress to trigger_prog; use real position!
					p["progress"] = fmod(old_prog + dist_moved, track_len)
					p["follower"].progress = p["progress"]
					_animate_individual_boarding(p, slot.vehicle_id, slot_idx, trigger_prog)
					boarded = true
					break
					
		if not boarded:
			p["progress"] = fmod(old_prog + dist_moved, track_len)
			p["follower"].progress = p["progress"]
						
	# Remove boarded passengers from active loop array so gaps are recognized
	for pid in to_remove:
		circulating_ids.erase(pid)

func _ready() -> void:
	_build_scene_hierarchy()
	_setup_controller()
	_load_level_1()

	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_update_layout)
	_update_layout()



func _build_scene_hierarchy() -> void:
	# 1. WorldRoot
	world_root = Node2D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)

	# World Background
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	var bg := ColorRect.new()
	bg.color = Color("87CEEB") # Sharp sky blue
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)
	add_child(bg_layer)


	# 1.1 BoardRoot
	board_root = Node2D.new()
	board_root.name = "BoardRoot"
	board_root.rotation = deg_to_rad(45)
	board_root.scale = Vector2(1.0, 0.6) # Isometric-ish tilt
	
	board_root.position = Vector2(0, BOARD_Y)
	world_root.add_child(board_root)
	
	boarding_paths_root = Node2D.new()
	boarding_paths_root.name = "BoardingPaths"
	# Ensure it renders below the parking and passengers
	world_root.add_child(boarding_paths_root)
	world_root.move_child(boarding_paths_root, 0)


	platform_bg = load("res://scripts/gameplay/platform_view.gd").new()
	platform_bg.name = "PlatformBackground"
	platform_bg.z_index = -5
	world_root.add_child(platform_bg)

	board_bg = BoardView.new()
	board_bg.name = "BoardBackground"
	board_root.add_child(board_bg)

	vehicle_layer = Node2D.new()
	vehicle_layer.name = "VehicleLayer"
	board_root.add_child(vehicle_layer)

	board_effects = Node2D.new()
	board_effects.name = "BoardEffects"
	board_root.add_child(board_effects)

	# 1.2 ParkingRoot
	parking_root = Node2D.new()
	parking_root.name = "ParkingRoot"
	parking_root.position = Vector2(0, PARKING_Y)
	world_root.add_child(parking_root)

	parking_slots_node = Node2D.new()
	parking_slots_node.name = "ParkingSlots"
	parking_root.add_child(parking_slots_node)

	parked_vehicles_node = Node2D.new()
	parked_vehicles_node.name = "ParkedVehicles"
	parking_root.add_child(parked_vehicles_node)

	# 1.3 PassengerTrack
	passenger_track_root = Node2D.new()
	passenger_track_root.name = "PassengerTrack"
	passenger_track_root.position = Vector2(0, PASSENGER_TRACK_Y)
	world_root.add_child(passenger_track_root)

	passenger_visuals = Node2D.new()
	passenger_visuals.name = "PassengerVisuals"
	passenger_track_root.add_child(passenger_visuals)

	boarding_effects = Node2D.new()
	boarding_effects.name = "BoardingEffects"
	world_root.add_child(boarding_effects)

	# 1.4 TransitLayer
	transit_layer = Node2D.new()
	transit_layer.name = "TransitLayer"
	world_root.add_child(transit_layer)

	# 2. Camera2D
	camera_2d = Camera2D.new()
	camera_2d.name = "Camera2D"
	add_child(camera_2d)

	# 3. HUD
	_build_hud()

func _setup_controller() -> void:
	controller = CarJamController.new()
	controller.name = "CarJamController"
	add_child(controller)

	controller.vehicle_dispatch_started.connect(_on_vehicle_dispatch_started)
	controller.vehicle_parked.connect(_on_vehicle_parked)
	controller.vehicle_blocked.connect(_on_vehicle_blocked)
	controller.boarding_started.connect(_on_boarding_started)
	controller.vehicle_filled.connect(_on_vehicle_filled)
	controller.vehicle_departed.connect(_on_vehicle_departed)
	controller.parking_updated.connect(_on_parking_updated)
	controller.parking_full_warning.connect(_show_parking_full_toast)
	controller.queue_updated.connect(_on_queue_updated)
	controller.level_completed.connect(_on_level_completed)
	controller.puzzle_failed.connect(_on_puzzle_failed)

func _load_level_1() -> void:
	var lvl: CarJamLevelData = null
	if ResourceLoader.exists("res://levels/level_001.tres"):
		lvl = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	if lvl == null:
		lvl = CarJamLevelFactory.create_level_1()

	controller.load_level(lvl)
	_setup_visuals(lvl)

func _setup_visuals(lvl: CarJamLevelData) -> void:
	# Clear previous visuals
	for v in vehicle_views.values():
		if is_instance_valid(v): v.queue_free()
	vehicle_views.clear()
	for c in boarding_effects.get_children():
		c.queue_free()
	for c in transit_layer.get_children():
		c.queue_free()


	for s in slot_views:
		if is_instance_valid(s): s.queue_free()
	slot_views.clear()

	for pid in all_passengers:
		var p = all_passengers[pid]
		if is_instance_valid(p["view"]): p["view"].queue_free()
		if is_instance_valid(p["follower"]): p["follower"].queue_free()
	all_passengers.clear()
	if is_instance_valid(passenger_track):
		passenger_track.queue_free()
		passenger_track = null
	
	if is_instance_valid(passenger_visuals):
		for c in passenger_visuals.get_children():
			c.queue_free()

	# 1. Board Background
	board_bg.setup(lvl.board_size)

	# 2. Parking Slots
	var slot_spacing := 76.0
	var total_span: float = float(lvl.parking_slots_count - 1) * slot_spacing
	
	# Draw a thick rounded asphalt background for parking
	var parking_bg = Node2D.new()
	parking_bg.name = "ParkingBase"
	parking_bg.z_index = -1
	

	var bg_w = total_span + 62.0 + 32.0 # total_span + SLOT_WIDTH + padding
	var bg_h = 104.0 + 32.0 # SLOT_HEIGHT + padding
	
	parking_bg.draw.connect(func():
		var style = StyleBoxFlat.new()
		style.bg_color = Color("94a3b8") # Light grey concrete surrounding
		style.set_corner_radius_all(16)
		style.shadow_color = Color(0,0,0,0.2)
		style.shadow_size = 10
		style.shadow_offset = Vector2(0, 8)
		style.draw(parking_bg.get_canvas_item(), Rect2(-bg_w/2.0 - 6, -bg_h/2.0 - 6, bg_w + 12, bg_h + 12))
	)
	parking_slots_node.add_child(parking_bg)

	for i in lvl.parking_slots_count:
		var slot_view := ParkingSlotView.new()
		slot_view.setup(i)
		slot_view.position = Vector2(-total_span / 2.0 + float(i) * slot_spacing, 0)
		parking_slots_node.add_child(slot_view)
		slot_views.append(slot_view)

	# 3. Vehicles
	for vd in lvl.vehicles:
		var vv := VehicleView.new()
		vv.setup(vd.id, vd.code, vd.color_id, vd.direction, vd.capacity, vd.footprint)
		var center_offset = _calc_footprint_center_offset(vd.footprint)
		vv.position = _cell_to_board_local(vd.anchor, lvl.board_size) + center_offset
		vv.tapped.connect(_on_vehicle_tapped)
		vehicle_layer.add_child(vv)
		vehicle_views[vd.id] = vv

	# 4. Passenger Queue
	_init_passenger_track()

func _calc_footprint_center_offset(footprint: Array[Vector2i]) -> Vector2:
	if footprint.size() <= 1: return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in footprint:
		sum += Vector2(p)
	var avg = sum / float(footprint.size())
	return avg * CELL_SIZE

func _cell_to_board_local(c: Vector2i, b_size: Vector2i) -> Vector2:
	var lx = float(c.x) - float(b_size.x - 1) / 2.0
	var ly = float(c.y) - float(b_size.y - 1) / 2.0
	
	return Vector2(lx * CELL_SIZE, ly * CELL_SIZE)

func _get_slot_world_pos(slot_id: int) -> Vector2:
	if slot_id >= 0 and slot_id < slot_views.size():
		return parking_root.position + slot_views[slot_id].position
	return Vector2(0, PARKING_Y)

func _init_passenger_track() -> void:
	passenger_track = Path2D.new()
	var curve := Curve2D.new()
	var points = 32
	for i in points:
		var t = float(i) / points * TAU
		curve.add_point(Vector2(cos(t) * 270, sin(t) * 90))
	curve.add_point(Vector2(270, 0)) # Close loop
	passenger_track.curve = curve
	
	# PREMIUM PLAZA INTEGRATION
	var plaza = preload("res://scripts/gameplay/plaza_environment.gd").new()
	plaza.name = "PlazaEnvironment"
	passenger_visuals.add_child(plaza)

	# Use custom robust track renderer instead of Godot 4 Line2D nodes
	var track_renderer = preload("res://scripts/gameplay/track_renderer.gd").new()
	track_renderer.name = "TrackRenderer"
	track_renderer.curve = curve
	passenger_visuals.add_child(track_renderer)

	_waiting_label = Label.new()
	_waiting_label.add_theme_font_size_override("font_size", 20)
	_waiting_label.add_theme_color_override("font_color", Color("94a3b8"))
	_waiting_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_waiting_label.add_theme_constant_override("outline_size", 4)
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.visible = false
	passenger_visuals.add_child(_waiting_label)

	passenger_visuals.add_child(passenger_track)
	
	# Precalculate boarding crossing points
	slot_boarding_points.clear()
	for i in 5:
		var slot_pos = _get_slot_world_pos(i)
		# Approximate the X-coordinate on the track curve
		var closest = passenger_track.curve.get_closest_offset(Vector2((i - 2) * 80.0, 90))
		slot_boarding_points[i] = closest

	all_passengers.clear()
	circulating_ids.clear()
	var pid = 0
	for g in controller.queue.get_all_groups():
		for j in g.initial_count:
			var pv := PassengerView.new()
			pv.setup(g.color_id)
			var pf := PathFollow2D.new()
			pf.loop = true
			pf.rotates = false
			pf.add_child(pv)
			passenger_track.add_child(pf)
			
			var start_prog = pid * PASSENGER_SPACING
			pf.progress = start_prog
			
			all_passengers[pid] = {
				"id": pid,
				"view": pv,
				"follower": pf,
				"color_id": g.color_id,
				"progress": float(start_prog),
				"state": "CIRCULATING"
			}
			circulating_ids.append(pid)
			pid += 1

func _fill_passenger_track() -> void:
	pass # Disabled. We initialized all passengers once.

func _on_vehicle_tapped(vehicle_id: int) -> void:
	_play_sfx("select")
	controller.tap_vehicle(vehicle_id)

func _on_vehicle_dispatch_started(vehicle_id: int, slot_id: int, corridor: Array[Vector2i]) -> void:
	_play_sfx("move")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv == null:
		return

	# Reparent to TransitLayer preserving global position
	var global_start := vv.global_position
	var global_rot := vv.global_rotation
	var global_scale := vv.global_scale
	vv.get_parent().remove_child(vv)
	transit_layer.add_child(vv)
	vv.global_position = global_start
	vv.global_rotation = global_rot
	vv.global_scale = global_scale

	var target_slot_pos := _get_slot_world_pos(slot_id)
	var exit_cell: Vector2i = corridor.back() if not corridor.is_empty() else vv.vehicle_footprint[0]
	
	# Calculate exactly how many cells to push forward to clear the board
	var push_cells = float(vv.vehicle_footprint.size()) + 0.6
	var dir_vec = CarJamVehicleData.dir_to_vector(vv.vehicle_dir)
	var final_exit_coord = Vector2(exit_cell) + Vector2(dir_vec) * push_cells
	
	# Calculate local position on the board
	var lx = final_exit_coord.x - float(controller.level_data.board_size.x - 1) / 2.0
	var ly = final_exit_coord.y - float(controller.level_data.board_size.y - 1) / 2.0
	var exit_local = Vector2(lx, ly) * CELL_SIZE
	
	# Convert to world_root space (which is transit_layer's space)
	var exit_pos = board_root.transform * exit_local

	# Dynamically calculate the parking scale to perfectly fit the slot bounds
	var max_w = 88.0
	var max_h = 180.0
	var cells_w: float = float(vv.vehicle_footprint.size()) if vv.vehicle_dir == CarJamVehicleData.Direction.RIGHT or vv.vehicle_dir == CarJamVehicleData.Direction.LEFT else 1.0
	var cells_h: float = float(vv.vehicle_footprint.size()) if vv.vehicle_dir == CarJamVehicleData.Direction.UP or vv.vehicle_dir == CarJamVehicleData.Direction.DOWN else 1.0
	var pixel_w = cells_w * 78.0 - 10.0
	var pixel_h = cells_h * 78.0 - 10.0
	
	# WIDE buses (LEFT/RIGHT) will be rotated 90 degrees in parking!
	# So their visual width becomes pixel_h and visual height becomes pixel_w
	var parked_pixel_w = pixel_w
	var parked_pixel_h = pixel_h
	if vv.vehicle_dir == CarJamVehicleData.Direction.LEFT or vv.vehicle_dir == CarJamVehicleData.Direction.RIGHT:
		parked_pixel_w = pixel_h
		parked_pixel_h = pixel_w
		
	var scale_w = max_w / parked_pixel_w
	var scale_h = max_h / parked_pixel_h
	var final_scale = clampf(min(scale_w, scale_h), 0.35, 0.9)
	var final_scale_vec = Vector2(final_scale, final_scale)

	VehicleMovement.animate_dispatch(
		vv,
		vv.position,
		exit_pos,
		target_slot_pos,
		controller.session_token,
		controller,
		vehicle_id,
		slot_id,
		final_scale_vec
	)

func _on_vehicle_parked(vehicle_id: int, slot_id: int) -> void:
	_play_sfx("parking")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null and slot_id < slot_views.size():
		# Reparent to ParkedVehicles
		var global_xform := vv.global_transform
		vv.get_parent().remove_child(vv)
		parked_vehicles_node.add_child(vv)
		vv.global_transform = global_xform
		slot_views[slot_id].set_state(CarJamParkingManager.SlotState.OCCUPIED)

func _on_vehicle_blocked(vehicle_id: int, _blocker_id: int) -> void:
	_play_sfx("blocked")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		vv.play_blocked_shake()

func _on_boarding_started(vehicle_id: int, color_id: String, count: int, slot_id: int) -> void:
	_play_sfx("board")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		var v_model: VehicleModel = controller.vehicles.get(vehicle_id, null)
		if v_model != null:
			vv.set_occupancy(v_model.passenger_occupancy)
		vv.play_badge_pulse()

func _on_vehicle_filled(vehicle_id: int, slot_id: int) -> void:
	print("[QA %d] Bus %d boarding completed." % [Time.get_ticks_msec(), vehicle_id])
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv == null:
		return

	# Schedule departure after brief acknowledgment
	var tw := create_tween()
	tw.tween_interval(0.40)
	tw.tween_callback(func():
		_play_sfx("depart")
		var slot_pos := _get_slot_world_pos(slot_id)
		VehicleMovement.animate_departure(
			vv,
			slot_pos,
			controller.session_token,
			controller,
			vehicle_id,
			slot_id
		)
	)

func _on_vehicle_departed(_vehicle_id: int, slot_id: int) -> void:
	if slot_id < slot_views.size():
		slot_views[slot_id].set_state(CarJamParkingManager.SlotState.EMPTY)

func _on_parking_updated() -> void:
	for i in slot_views.size():
		var slot := controller.parking.get_slot(i)
		if slot != null:
			slot_views[i].set_state(slot.state)

func _on_queue_updated() -> void:
	_fill_passenger_track()

func _on_level_completed() -> void:
	_play_sfx("victory")
	result_title_label.text = "🏆 LEVEL CLEAR!"
	result_title_label.add_theme_color_override("font_color", Color("facc15"))
	result_overlay.visible = true

func _on_puzzle_failed() -> void:
	_play_sfx("failure")
	result_title_label.text = "⚠️ NO MOVES LEFT!"
	result_title_label.add_theme_color_override("font_color", Color("ef4444"))
	result_overlay.visible = true

# -----------------------------------------------------------------
# RESPONSIVE HUD & SAFE AREA
# -----------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	safe_area_root = Control.new()
	safe_area_root.name = "SafeAreaRoot"
	safe_area_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(safe_area_root)

	# TopBar: Level 1, Restart, Pause
	top_bar = Control.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 20.0
	top_bar.offset_right = -20.0
	top_bar.offset_top = 24.0
	top_bar.offset_bottom = 68.0
	safe_area_root.add_child(top_bar)

	# Restart (←) — simple 3D blue button in top-left
	var btn_restart := Button.new()
	btn_restart.text = "↻"
	btn_restart.add_theme_font_size_override("font_size", 24)
	btn_restart.add_theme_color_override("font_color", Color.WHITE)
	btn_restart.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
		Color("60a5fa"), Color("1e3a8a"), 12, 4, 2))
	btn_restart.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
		Color("93c5fd"), Color("1e3a8a"), 12, 4, 2))
	btn_restart.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
		Color("3b82f6"), Color("1e3a8a"), 12, 2, 1, 2))
	btn_restart.custom_minimum_size = Vector2(44, 44)
	btn_restart.button_down.connect(func(): btn_restart.position.y += 4)
	btn_restart.button_up.connect(func(): btn_restart.position.y -= 4)
	btn_restart.pressed.connect(_on_restart_pressed)
	top_bar.add_child(btn_restart)

	level_title_label = Label.new()
	level_title_label.text = "Level 1"
	level_title_label.add_theme_font_size_override("font_size", 30)
	level_title_label.add_theme_color_override("font_color", Color("ffffff"))
	level_title_label.add_theme_color_override("font_outline_color", Color("1e293b"))
	level_title_label.add_theme_constant_override("outline_size", 6)
	level_title_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.5))
	level_title_label.add_theme_constant_override("shadow_offset_y", 4)
	level_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_title_label.anchor_left = 0.25
	level_title_label.anchor_right = 0.75
	level_title_label.anchor_top = 0.0
	level_title_label.anchor_bottom = 1.0
	top_bar.add_child(level_title_label)

	var btn_pause := Button.new()
	btn_pause.text = "❚❚"
	btn_pause.add_theme_font_size_override("font_size", 18)
	btn_pause.add_theme_color_override("font_color", Color.WHITE)
	btn_pause.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
		Color("60a5fa"), Color("1e3a8a"), 12, 4, 2))
	btn_pause.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
		Color("93c5fd"), Color("1e3a8a"), 12, 4, 2))
	btn_pause.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
		Color("3b82f6"), Color("1e3a8a"), 12, 2, 1, 2))
	btn_pause.custom_minimum_size = Vector2(44, 44)
	btn_pause.button_down.connect(func(): btn_pause.position.y += 4)
	btn_pause.button_up.connect(func(): btn_pause.position.y -= 4)
	btn_pause.anchor_left = 1.0
	btn_pause.offset_left = -44.0
	btn_pause.pressed.connect(_on_pause_pressed)
	top_bar.add_child(btn_pause)

	# BoosterBar (VIP, Arrange, Jumble) marked locked/unavailable as per Phase 7
	booster_bar = Control.new()
	booster_bar.name = "BoosterBar"
	booster_bar.anchor_left = 0.0
	booster_bar.anchor_right = 1.0
	booster_bar.anchor_top = 1.0
	booster_bar.anchor_bottom = 1.0
	booster_bar.offset_left = 20.0
	booster_bar.offset_right = -20.0
	booster_bar.offset_top = -90.0
	booster_bar.offset_bottom = -10.0
	safe_area_root.add_child(booster_bar)

	var b_hbox := HBoxContainer.new()
	b_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_theme_constant_override("separation", 24)
	booster_bar.add_child(b_hbox)

	var bst_style := SimpleStyle.make_extruded_style(
		Color("38bdf8"), Color("1e3a8a"), 16, 7, 0)
	var bst_pressed := SimpleStyle.make_extruded_style(
		Color("38bdf8"), Color("1e3a8a"), 16, 3, 4, 3)

	for b_name in ["VIP", "Arrange", "Jumble"]:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		# Base button uses procedural style to remain crisp and clean
		var btn := Button.new()
		btn.add_theme_stylebox_override("normal", bst_style)
		btn.add_theme_stylebox_override("hover", bst_style)
		btn.add_theme_stylebox_override("pressed", bst_pressed)
		btn.add_theme_stylebox_override("disabled", bst_style)
		btn.disabled = true
		btn.custom_minimum_size = Vector2(52, 52)
		

		
		# Add a green '+' circle
		var plus := Label.new()
		plus.text = "✚"
		plus.add_theme_font_size_override("font_size", 14)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("166534"))
		plus.add_theme_constant_override("outline_size", 4)
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 12
		p_style.corner_radius_top_right = 12
		p_style.corner_radius_bottom_left = 12
		p_style.corner_radius_bottom_right = 12
		p_style.border_width_bottom = 2
		p_style.border_color = Color("16a34a")
		plus.add_theme_stylebox_override("normal", p_style)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(21, 21)
		plus.position = Vector2(41, -6)
		btn.add_child(plus)
		
		vbox.add_child(btn)
		
		var lbl = Label.new()
		lbl.text = b_name
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color("ffffff"))
		lbl.add_theme_color_override("font_outline_color", Color("1e293b"))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		
		b_hbox.add_child(vbox)

	# PauseOverlay
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_overlay)

	var p_bg := ColorRect.new()
	p_bg.color = Color(0, 0, 0, 0.7)
	p_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(p_bg)

	var p_center := CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(p_center)
	
	var p_main := Control.new()
	p_main.custom_minimum_size = Vector2(225, 360)
	p_center.add_child(p_main)
	
	var p_vbox := VBoxContainer.new()
	p_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_vbox.add_theme_constant_override("separation", 0)
	p_main.add_child(p_vbox)

	# Blue Header
	var p_header := PanelContainer.new()
	var ph_style := StyleBoxFlat.new()
	ph_style.bg_color = Color("4b7bec")
	ph_style.corner_radius_top_left = 24
	ph_style.corner_radius_top_right = 24
	p_header.add_theme_stylebox_override("panel", ph_style)
	p_header.custom_minimum_size = Vector2(225, 45)
	p_vbox.add_child(p_header)
	
	var ph_lbl := Label.new()
	ph_lbl.text = "SETTINGS"
	ph_lbl.add_theme_font_size_override("font_size", 12)
	ph_lbl.add_theme_color_override("font_color", Color("ffffff"))
	ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p_header.add_child(ph_lbl)
	
	# Close button inside header
	var p_close := Button.new()
	p_close.text = "✖"
	p_close.add_theme_font_size_override("font_size", 20)
	p_close.add_theme_color_override("font_color", Color.WHITE)
	p_close.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
		Color("ef4444"), Color("991b1b"), 16, 6, 0))
	p_close.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
		Color("f87171"), Color("991b1b"), 16, 6, 0))
	p_close.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
		Color("dc2626"), Color("7f1d1d"), 16, 3, 4, 3))
	p_close.custom_minimum_size = Vector2(33, 33)
	p_close.anchor_left = 1.0
	p_close.anchor_right = 1.0
	p_close.offset_left = -39.0
	p_close.offset_top = 6.0
	p_close.pressed.connect(_on_resume_pressed)
	p_main.add_child(p_close)

	# White/Light Blue Body
	var p_body := PanelContainer.new()
	var pb_style := StyleBoxFlat.new()
	pb_style.bg_color = Color("e8f4fa")
	pb_style.corner_radius_bottom_left = 24
	pb_style.corner_radius_bottom_right = 24
	p_body.add_theme_stylebox_override("panel", pb_style)
	p_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p_vbox.add_child(p_body)
	
	var pb_margin := MarginContainer.new()
	pb_margin.add_theme_constant_override("margin_left", 24)
	pb_margin.add_theme_constant_override("margin_right", 24)
	pb_margin.add_theme_constant_override("margin_top", 24)
	pb_margin.add_theme_constant_override("margin_bottom", 18)
	p_body.add_child(pb_margin)
	
	var pb_vbox := VBoxContainer.new()
	pb_vbox.add_theme_constant_override("separation", 18)
	pb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pb_margin.add_child(pb_vbox)

	# Icons Row
	var p_icons := HBoxContainer.new()
	p_icons.add_theme_constant_override("separation", 18)
	p_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	pb_vbox.add_child(p_icons)
	
	var sm_sfx = true
	var sm_music = true
	var sm_haptics = true
	if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
		var sm = get_tree().root.get_node("SettingsManager")
		sm_sfx = sm.sfx_enabled()
		sm_music = sm.music_enabled()
		sm_haptics = sm.haptics_enabled()

	p_icons.add_child(_create_settings_icon_button("Sound", "🔊", sm_sfx, func(on):
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_sfx(on)
	))
	p_icons.add_child(_create_settings_icon_button("Music", "🎵", sm_music, func(on): 
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_music(on)
		if is_inside_tree() and get_tree().root.has_node("AudioManager"):
			var am = get_tree().root.get_node("AudioManager")
			if on: am.play_music()
			else: am.stop_music()
	))
	p_icons.add_child(_create_settings_icon_button("Vibrate", "📳", sm_haptics, func(on):
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_haptics(on)
	))
	
	# Action Buttons — simple 3D-styled (orange Home, green Restart)
	var p_btn_home := Button.new()
	p_btn_home.text = "Home"
	p_btn_home.add_theme_font_size_override("font_size", 20)
	p_btn_home.add_theme_color_override("font_color", Color.WHITE)
	p_btn_home.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
		Color("f97316"), Color("9a3412"), 16, 7, 0))
	p_btn_home.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
		Color("fb923c"), Color("9a3412"), 16, 7, 0))
	p_btn_home.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
		Color("ea580c"), Color("7c2d12"), 16, 3, 4, 3))
	p_btn_home.custom_minimum_size = Vector2(180, 45)
	p_btn_home.button_down.connect(func(): p_btn_home.position.y += 3)
	p_btn_home.button_up.connect(func(): p_btn_home.position.y -= 3)
	p_btn_home.pressed.connect(_on_home_pressed)
	pb_vbox.add_child(p_btn_home)

	var p_btn_restart := Button.new()
	p_btn_restart.text = "Restart"
	p_btn_restart.add_theme_font_size_override("font_size", 20)
	p_btn_restart.add_theme_color_override("font_color", Color.WHITE)
	p_btn_restart.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
		Color("22c55e"), Color("14532d"), 16, 7, 0))
	p_btn_restart.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
		Color("4ade80"), Color("14532d"), 16, 7, 0))
	p_btn_restart.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
		Color("16a34a"), Color("14532d"), 16, 3, 4, 3))
	p_btn_restart.custom_minimum_size = Vector2(180, 45)
	p_btn_restart.button_down.connect(func(): p_btn_restart.position.y += 3)
	p_btn_restart.button_up.connect(func(): p_btn_restart.position.y -= 3)
	p_btn_restart.pressed.connect(_on_restart_pressed)
	pb_vbox.add_child(p_btn_restart)
	
	var p_spacer2 := Control.new()
	p_spacer2.custom_minimum_size = Vector2(0, 4)
	pb_vbox.add_child(p_spacer2)
	
	var p_footer := Label.new()
	p_footer.text = "Terms of Service  &  Privacy Policy"
	p_footer.add_theme_font_size_override("font_size", 13)
	p_footer.add_theme_color_override("font_color", Color("3b82f6"))
	p_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_vbox.add_child(p_footer)


	# ResultOverlay
	result_overlay = Control.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(result_overlay)

	var r_bg := ColorRect.new()
	r_bg.color = Color(0, 0, 0, 0.7)
	r_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(r_bg)

	var r_center := CenterContainer.new()
	r_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(r_center)
	
	var r_panel := PanelContainer.new()
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color("e8f4fa")
	r_style.border_width_top = 8
	r_style.border_color = Color("4b7bec")
	r_style.corner_radius_top_left = 24
	r_style.corner_radius_top_right = 24
	r_style.corner_radius_bottom_left = 24
	r_style.corner_radius_bottom_right = 24
	r_panel.add_theme_stylebox_override("panel", r_style)
	r_panel.custom_minimum_size = Vector2(460, 320)
	r_center.add_child(r_panel)
	
	var r_margin := MarginContainer.new()
	r_margin.add_theme_constant_override("margin_left", 32)
	r_margin.add_theme_constant_override("margin_right", 32)
	r_margin.add_theme_constant_override("margin_top", 40)
	r_margin.add_theme_constant_override("margin_bottom", 40)
	r_panel.add_child(r_margin)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 24)
	r_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r_margin.add_child(r_vbox)

	result_title_label = Label.new()
	result_title_label.text = "LEVEL CLEAR!"
	result_title_label.add_theme_font_size_override("font_size", 42)
	result_title_label.add_theme_color_override("font_color", Color("4b7bec"))
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_vbox.add_child(result_title_label)
	
	# Action Buttons (Home and Restart)
	var r_btn_home := Button.new()
	r_btn_home.text = "Home"
	r_btn_home.add_theme_font_size_override("font_size", 36)
	r_btn_home.add_theme_color_override("font_color", Color.WHITE)
	r_btn_home.add_theme_stylebox_override("normal", SimpleStyle.make_extruded_style(
		Color("f97316"), Color("9a3412"), 16, 7, 0))
	r_btn_home.add_theme_stylebox_override("hover", SimpleStyle.make_extruded_style(
		Color("fb923c"), Color("9a3412"), 16, 7, 0))
	r_btn_home.add_theme_stylebox_override("pressed", SimpleStyle.make_extruded_style(
		Color("ea580c"), Color("7c2d12"), 16, 3, 4, 3))
	r_btn_home.custom_minimum_size = Vector2(260, 100)
	r_btn_home.button_down.connect(func(): r_btn_home.position.y += 6)
	r_btn_home.button_up.connect(func(): r_btn_home.position.y -= 6)
	r_btn_home.pressed.connect(_on_home_pressed)
	r_vbox.add_child(r_btn_home)
	
	result_btn = TextureButton.new()
	result_btn.stretch_mode = TextureButton.STRETCH_SCALE
	result_btn.custom_minimum_size = Vector2(296, 102)
	result_btn.button_down.connect(func(): result_btn.position.y += 8)
	result_btn.button_up.connect(func(): result_btn.position.y -= 8)
	result_btn.pressed.connect(_on_restart_pressed)
	
	var r_restart_center = CenterContainer.new()
	r_restart_center.custom_minimum_size = Vector2(300, 110)
	var rrc_wrap = Control.new()
	rrc_wrap.custom_minimum_size = result_btn.custom_minimum_size
	rrc_wrap.add_child(result_btn)
	r_restart_center.add_child(rrc_wrap)
	r_vbox.add_child(r_restart_center)

func _update_layout() -> void:
	if world_root == null:
		return
	var vp := get_viewport()
	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(720, 1280)
	if DisplayServer.get_name() == "headless": vp_size = Vector2(720, 1280)
	if vp_size.x <= 0 or vp_size.y <= 0:
		return

	# 1. Determine local bounding sizes
	var track_h = 180.0
	var parking_h = 200.0
	var board_cells_w = float(controller.level_data.board_size.x)
	var board_cells_h = float(controller.level_data.board_size.y)
	var board_local_size = max(board_cells_w, board_cells_h) * CELL_SIZE
	# Rotated 45 deg, scale (1.0, 0.6)
	var board_pixel_w = board_local_size * sqrt(2.0)
	var board_pixel_h = board_pixel_w * 0.6
	
	# 2. Determine required margins and total logical dimensions
	# Safe areas on screen (top header, bottom boosters)
	var screen_safe_h = vp_size.y - 450.0 # leave 150 top, 300 bottom
	var screen_safe_w = vp_size.x * 0.95

	# Ensure we fit the parking strip which might be wider than the board
	var slot_spacing = 76.0 # MATCHES what we set earlier
	var parking_w = float(max(1, controller.level_data.parking_slots_count - 1)) * slot_spacing + 40.0
	
	# We need some extra width for buses to exit the board cleanly without clipping
	var board_padded_w = board_pixel_w + 120.0 
	
	var required_w = maxf(parking_w, board_padded_w)
	required_w = maxf(required_w, 600.0) # minimum width to ensure UI fits
	
	# Stack vertically with comfortable gaps
	var scale_w = screen_safe_w / required_w
	var scale_h = screen_safe_h / (track_h + 120.0 + parking_h + board_pixel_h)
	var scale_factor = clampf(min(scale_w, scale_h), 0.4, 2.0)
	
	# Compute how much logical vertical space we have available with this scale
	var available_local_h = screen_safe_h / scale_factor
	
	# Distribute the remaining vertical space evenly into the 2 gaps
	var remaining_h = available_local_h - (track_h + parking_h + board_pixel_h)
	# But cap the gaps so they don't look completely ridiculous
	var gap = clampf(remaining_h / 2.5, 60.0, 350.0)
	
	var total_content_h = track_h + gap + parking_h + gap + board_pixel_h
	
	
	# Scale factor was calculated above for dynamic gap
	
	# Apply scale to world root
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO
	
	# 4. Center the stacked layout around the middle of the safe area
	var half_h = (vp_size.y / 2.0) / scale_factor
	var top_y = -half_h + (150.0 / scale_factor) # Start drawing below the header
	
	# Or dynamically center the content block vertically in the available space:
	available_local_h = (screen_safe_h / scale_factor)
	var start_y = top_y + (available_local_h - total_content_h) / 2.0 + (track_h / 2.0)
	
	var track_y = start_y
	var parking_y = track_y + (track_h / 2.0) + gap + (parking_h / 2.0)
	var bottom_ui_top_y = half_h - (120.0 / scale_factor)
	var parking_bottom_y = parking_y + (parking_h / 2.0)
	var board_y = (parking_bottom_y + bottom_ui_top_y) / 2.0
	
	# Passenger track prominent in upper section
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, track_y)

	# Parking strip right below the track
	if parking_root != null:
		parking_root.position = Vector2(0, parking_y)

	# Puzzle board in the lower middle area
	if board_root != null:
		board_root.position = Vector2(0, board_y)
		
	if platform_bg != null:
		platform_bg.position = Vector2.ZERO # drawn relative to world_root
		
		# Full screen bounds in local space
		var local_bottom = (vp_size.y / scale_factor) + 1000.0 # extend way down
		
		# Start platform slightly above the parking slots
		var plat_top = parking_y - (parking_h / 2.0) - 40.0
		
		# Partition gap
		var partition_y = parking_y + (parking_h / 2.0) + (gap / 2.0)
		
		# Width needs to cover entire screen width
		var full_w = (vp_size.x / scale_factor) + 200.0
		
		platform_bg.setup_full(plat_top, local_bottom, full_w, partition_y)




func _on_restart_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		gc.start_level(1)

func _show_parking_full_toast() -> void:
	if _toast_panel == null:
		_toast_panel = PanelContainer.new()
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.7)
		sb.set_corner_radius_all(20)
		_toast_panel.add_theme_stylebox_override("panel", sb)
		
		var m = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 20)
		m.add_theme_constant_override("margin_right", 20)
		m.add_theme_constant_override("margin_top", 10)
		m.add_theme_constant_override("margin_bottom", 10)
		_toast_panel.add_child(m)
		
		var hb = HBoxContainer.new()
		m.add_child(hb)
		
		var icon = Label.new()
		icon.text = "!"
		icon.add_theme_font_size_override("font_size", 24)
		icon.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		hb.add_child(icon)
		
		var lbl = Label.new()
		lbl.text = "NO SPOT AVAILABLE"
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		hb.add_child(lbl)
		
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		hud.add_child(_toast_panel)
		
	# Center it visually on screen
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Push it slightly up so it's not strictly covering center interaction
	_toast_panel.position.y -= 150
	
	if _toast_tween:
		_toast_tween.kill()
		
	_toast_panel.visible = true
	
	_toast_tween = create_tween()
	# Only fade in if it's not already fully visible
	if _toast_panel.modulate.a < 1.0:
		_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)

func _on_home_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		gc.goto_scene("res://scenes/main.tscn")

func _on_pause_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = true
	pause_overlay.visible = true

func _on_resume_pressed() -> void:
	_play_sfx("ui")
	get_tree().paused = false
	pause_overlay.visible = false

func _play_sfx(sfx_name: String) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var am: Node = tree.root.get_node_or_null("AudioManager")
	if am != null and am.has_method("play"):
		am.play(sfx_name)

func _create_settings_icon_button(label_text: String, icon_text: String, is_on: bool, on_toggle: Callable) -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	var style = StyleBoxFlat.new()
	style.bg_color = Color("4b7bec")
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_bottom = 4
	style.border_color = Color("3867d6")
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	var icon = Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 24)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(icon)
	
	var slash = ColorRect.new()
	slash.color = Color("eb3b5a")
	slash.size = Vector2(75, 6)
	slash.pivot_offset = Vector2(37, 3)
	slash.position = Vector2(-2, 33)
	slash.rotation = deg_to_rad(45)
	slash.visible = not is_on
	btn.add_child(slash)
	
	var state = {"on": is_on}
	btn.pressed.connect(func():
		_play_sfx("ui")
		state.on = not state.on
		slash.visible = not state.on
		on_toggle.call(state.on)
	)
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("64748b"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	vbox.add_child(btn)
	vbox.add_child(lbl)
	
	return vbox

func _load_interim_sprite(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback to direct image load if not imported
	var img = Image.new()
	var err = img.load(path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	return null


func _animate_individual_boarding(p: Dictionary, vehicle_id: int, slot_id: int, exact_prog: float) -> void:
	var pv: PassengerView = p["view"]
	var pf: PathFollow2D = p["follower"]
	
	# Preserve exact live position to prevent snapping
	var gpos = pv.global_position
	pf.remove_child(pv)
	passenger_visuals.add_child(pv)
	pv.global_position = gpos
	
	pf.queue_free()
	p["follower"] = null
	
	var target_pos: Vector2
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	var final_local = _get_slot_world_pos(slot_id)
	
	if vv != null and is_instance_valid(vv) and vv.boarding_anchor != null:
		# Use the live global position of the boarding anchor, which is correctly 
		# transformed by the parked vehicle's dynamic scale and orientation.
		target_pos = vv.boarding_anchor.global_position
	else:
		target_pos = transit_layer.to_global(final_local)
	
	pv.animate_jump(0.0)
	
	var tw = create_tween().set_parallel(true)
	
	var travel_dist = gpos.distance_to(target_pos)
	var duration = clampf(travel_dist / 350.0, 0.20, 0.35)
	
	var overlap_time = duration * 0.75
	var fade_time = duration * 0.25
	
	# Travel straight to the actual bus center smoothly
	tw.tween_property(pv, "global_position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# When passenger overlaps bus, reparent it into the boarding layer
	var tw_reparent = create_tween()
	tw_reparent.tween_interval(overlap_time)
	tw_reparent.tween_callback(func():
		if is_instance_valid(pv) and is_instance_valid(vv) and vv.boarding_layer != null:
			pv.reparent(vv.boarding_layer, true)
	)
	
	# Shrink/fade ONLY during the final portion when already overlapping the bus
	tw.tween_property(pv, "scale", Vector2(0.2, 0.2), fade_time).set_delay(overlap_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pv, "modulate:a", 0.0, fade_time).set_delay(overlap_time).set_trans(Tween.TRANS_LINEAR)
	
	var token = controller.session_token
	tw.chain().tween_callback(self._on_individual_boarded.bind(p["id"], vehicle_id, p["color_id"], token))

func _on_individual_boarded(pid: int, vehicle_id: int, color_id: String, token: int) -> void:
	if token != controller.session_token: return
	var p = all_passengers.get(pid, null)
	if p != null:
		if is_instance_valid(p["view"]):
			p["view"].queue_free()
		p["state"] = "BOARDED"
	controller.commit_boarding(vehicle_id, color_id, token)
