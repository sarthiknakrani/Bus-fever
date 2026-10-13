extends Node2D
class_name CarJamLevel

## Production-quality Car Jam single-level gameplay scene.
## Pure Godot 2D architecture with 2.5D pseudo-3D layered buses,
## exactly 4 parking slots, swept-footprint collision, and ordered passenger queue.


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
var passenger_track_bg: Node2D
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
var restart_confirm_overlay: Control
var _was_paused_before_confirm: bool = false

var level_title_label: Label
var result_title_label: Label
var result_btn: TextureButton
var result_btn_label: Label
var result_retry_btn: TextureButton
var result_subtitle_label: Label
var _result_outcome: String = ""  # "victory" or "failure" — guards which buttons are shown

var _toast_container: CenterContainer
var _toast_panel: PanelContainer
var _toast_tween: Tween
var _last_toast_time: float = -999.0

# Authoritative Controller
var controller: CarJamController
var vehicle_views: Dictionary = {} # int id -> VehicleView
var slot_views: Array[ParkingSlotView] = []

# Continuous Passenger Track State (4-Across Formation)
class PassengerRow extends RefCounted:
	var row_id: int = 0
	var progress: float = 0.0
	var is_feeder: bool = false
	var passengers: Array[Dictionary] = [] # {"id": int, "color_id": String, "lane": int, "view": PassengerView, "state": String}

const LANE_SPACING := 24.2
const ROW_SPACING := 35.33
const NUM_LANES := 4
const PASSENGER_SPACING := 35.33
const MAX_INITIAL_LOOP_PASSENGERS := 152

var passenger_track: Path2D
var feeder_track: Path2D
var all_passengers: Dictionary = {}
var circulating_ids: Array[int] = []
var _feeder_passengers: Array[Dictionary] = []
var _pending_feeder_passengers: Array[Dictionary] = []
var _circulating_rows: Array[PassengerRow] = []
var _feeder_rows: Array[PassengerRow] = []
var _pending_feeder_rows: Array[PassengerRow] = []
var _speed_logged: bool = false
var slot_boarding_points: Dictionary = {}
var _platform_start_prog: float = 160.0
var _platform_end_prog: float = 510.0
var _waiting_label: Label
var track_time: float = 0.0
var _last_board_landing_time: float = 0.0
var _oval_freed_capacity: int = 0

@export var passenger_normal_speed: float = 335.0
@export var passenger_sprint_speed: float = 380.0
@export var bus_movement_duration_multiplier: float = 1.0
const TRACK_SPEED := 40.0

func _get_curve_point_and_normal(c: Curve2D, offset: float, is_loop: bool = false) -> Dictionary:
	var curve_len := c.get_baked_length()
	var clamped_offset: float = fmod(offset, curve_len) if is_loop else clampf(offset, 0.0, curve_len)
	if clamped_offset < 0.0: clamped_offset += curve_len
	var p0 := c.sample_baked(clamped_offset)
	var next_offset: float = fmod(clamped_offset + 1.0, curve_len) if is_loop else minf(clamped_offset + 1.0, curve_len)
	var p1 := c.sample_baked(next_offset)
	if p1.distance_squared_to(p0) < 0.0001:
		var prev_offset = maxf(clamped_offset - 1.0, 0.0)
		p1 = p0
		p0 = c.sample_baked(prev_offset)
	var tangent := (p1 - p0).normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	return {"pos": p0, "tangent": tangent, "normal": normal}

func _calc_lane_pos(center_pos: Vector2, normal: Vector2, lane: int) -> Vector2:
	var lane_offset: float = (float(lane) - 1.5) * LANE_SPACING
	return center_pos + normal * lane_offset

func _process(delta: float) -> void:
	if passenger_track == null or controller == null: return
	if controller.state != CarJamController.GameState.PLAYING: return
	
	var track_len = passenger_track.curve.get_baked_length()
	if not _speed_logged and circulating_ids.size() > 0:
		_speed_logged = true
		print("[QA] Loop length: ", track_len, " px")
		print("[QA] Normal lap: ", track_len / passenger_normal_speed, " s")
		print("[QA] Sprint lap: ", track_len / passenger_sprint_speed, " s")

	# ---------------------------------------------
	# 1. CONTINUOUS FEEDER LOGIC (4-across Rows)
	# ---------------------------------------------
	if feeder_track != null and is_instance_valid(feeder_track):
		var f_len = feeder_track.curve.get_baked_length()
		
		# A. Spawn pending row at feeder entrance (s = 0) if entrance is clear
		if not _pending_feeder_rows.is_empty():
			var entrance_clear := true
			if not _feeder_rows.is_empty():
				var last_feeder = _feeder_rows.back()
				if last_feeder.progress < ROW_SPACING:
					entrance_clear = false
			
			if entrance_clear:
				var next_row: PassengerRow = _pending_feeder_rows.pop_front()
				next_row.progress = 0.0
				next_row.is_feeder = true
				var f_pt_info = _get_curve_point_and_normal(feeder_track.curve, 0.0, false)
				for p in next_row.passengers:
					var pv := PassengerView.new()
					pv.setup(p["color_id"], p["id"], p["lane"])
					passenger_visuals.add_child(pv)
					p["view"] = pv
					p["state"] = "FEEDER"
					controller.set_passenger_state(p["id"], "FEEDER")
					var lpos = _calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], p["lane"])
					pv.position = lpos
					all_passengers[p["id"]] = p
					_feeder_passengers.append(p)
					_pending_feeder_passengers.erase(p)
				_feeder_rows.append(next_row)
				
		# B. Advance feeder rows forward towards stop line / row ahead
		var feeder_stop_pos: float = f_len - 110.0
		for j in range(_feeder_rows.size()):
			var f_row = _feeder_rows[j]
			var max_prog: float = feeder_stop_pos
			if j == 0 and _oval_freed_capacity >= f_row.passengers.size():
				var junction_clear := true
				for cr in _circulating_rows:
					if cr.progress > (track_len - 140.0) or cr.progress < 60.0:
						junction_clear = false
						break
				if junction_clear:
					max_prog = f_len
				else:
					max_prog = maxf(feeder_stop_pos, f_row.progress)
			elif j > 0:
				max_prog = _feeder_rows[j - 1].progress - ROW_SPACING
			var dist_ahead: float = max_prog - f_row.progress
			var speed: float = passenger_normal_speed
			if dist_ahead > ROW_SPACING * 1.25:
				speed = passenger_sprint_speed
			elif dist_ahead < ROW_SPACING * 0.95:
				speed = passenger_normal_speed * 0.85
			var dist_moved: float = speed * delta
			dist_moved = minf(dist_moved, maxf(dist_ahead, 0.0))
			f_row.progress += dist_moved
			
		# C. Merge lead feeder row onto main loop if:
		#    1. Enough capacity has been freed on the loop by boarded passengers (_oval_freed_capacity >= row.size)
		#    2. Lead row has arrived at or past merge threshold (f_len - 2.0)
		#    3. Merge zone on the oval is clear
		if not _feeder_rows.is_empty():
			var lead_row = _feeder_rows.front()
			var needed_cap: int = lead_row.passengers.size()
			if _oval_freed_capacity >= needed_cap and lead_row.progress >= f_len - 2.0:
				var merge_clear := true
				var clearance_buffer := ROW_SPACING * 1.35
				for cr in _circulating_rows:
					if cr.progress < clearance_buffer or cr.progress > (track_len - clearance_buffer):
						merge_clear = false
						break
				if merge_clear:
					_feeder_rows.pop_front()
					lead_row.progress = 0.0
					lead_row.is_feeder = false
					for p in lead_row.passengers:
						p["state"] = "CIRCULATING"
						controller.set_passenger_state(p["id"], "CIRCULATING")
						circulating_ids.append(p["id"])
						_feeder_passengers.erase(p)
						if is_instance_valid(p.get("view")):
							p["view"].set_waiting(false)
					_circulating_rows.append(lead_row)
					_oval_freed_capacity -= needed_cap
					controller.check_terminal_states()

		# D. Update positions of passengers in active feeder rows
		for f_row in _feeder_rows:
			var f_pt_info = _get_curve_point_and_normal(feeder_track.curve, f_row.progress, false)
			var is_row_stopped: bool = f_row.progress >= feeder_stop_pos - 0.5 and _oval_freed_capacity < f_row.passengers.size()
			for p in f_row.passengers:
				if p["state"] == "FEEDER" and is_instance_valid(p.get("view")):
					var lpos = _calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], p["lane"])
					p["view"].position = lpos
					p["view"].set_waiting(is_row_stopped)

	# ---------------------------------------------
	# 2. CIRCULATING ROWS ON MAIN TRACK
	# ---------------------------------------------
	_circulating_rows.sort_custom(func(a, b): return a.progress > b.progress)

	var empty_rows: Array[PassengerRow] = []

	for i in range(_circulating_rows.size()):
		var row = _circulating_rows[i]
		if row.passengers.is_empty():
			empty_rows.append(row)
			continue

		# Gap closing: check distance to row ahead
		var speed = passenger_normal_speed
		var dist_ahead = track_len
		if _circulating_rows.size() > 1:
			var ahead_row: PassengerRow
			if i == 0:
				ahead_row = _circulating_rows.back()
				dist_ahead = (ahead_row.progress + track_len) - row.progress
			else:
				ahead_row = _circulating_rows[i - 1]
				dist_ahead = ahead_row.progress - row.progress

			if dist_ahead > ROW_SPACING * 1.25:
				speed = passenger_sprint_speed
			elif dist_ahead < ROW_SPACING * 0.95:
				speed = passenger_normal_speed * 0.85

		var old_prog = row.progress
		var dist_moved = speed * delta
		var min_gap: float = ROW_SPACING
		if _circulating_rows.size() > 1:
			if dist_ahead <= min_gap:
				dist_moved = 0.0
			else:
				dist_moved = minf(dist_moved, dist_ahead - min_gap)

		# Boarding checks across parking slots
		var to_board_from_row: Array[Dictionary] = []
		for slot_idx in slot_boarding_points:
			var trigger_prog: float = slot_boarding_points[slot_idx]
			var dist_to_trigger = trigger_prog - old_prog
			if dist_to_trigger < 0: dist_to_trigger += track_len
			
			var in_boarding_zone: bool
			if _platform_start_prog <= _platform_end_prog:
				in_boarding_zone = (old_prog >= (_platform_start_prog - 20.0) and old_prog <= (_platform_end_prog + 20.0))
			else:
				in_boarding_zone = (old_prog >= (_platform_start_prog - 20.0) or old_prog <= (_platform_end_prog + 20.0))
			var reached: bool = in_boarding_zone and ((dist_to_trigger <= dist_moved) or (abs(old_prog - trigger_prog) < 15.0))
			if reached:
				var slot = controller.parking.get_slot(slot_idx)
				if slot != null and slot.state == CarJamParkingManager.SlotState.OCCUPIED and slot.vehicle_id != -1:
					var v = controller.vehicles.get(slot.vehicle_id, null)
					if v != null and v.remaining_capacity() > 0:
						for p in row.passengers:
							if p["state"] == "CIRCULATING" and p["color_id"] == v.color_id:
								if controller.try_reserve_boarding(p["id"], v.id, p["color_id"], p.get("group_id", -1)):
									_board_circulating_passenger(p, v.id, slot_idx, trigger_prog)
									to_board_from_row.append(p)
									if v.remaining_capacity() <= 0:
										break

		for bp in to_board_from_row:
			row.passengers.erase(bp)

		if row.passengers.is_empty():
			empty_rows.append(row)
		else:
			row.progress = fmod(old_prog + dist_moved, track_len)

	for er in empty_rows:
		_circulating_rows.erase(er)

	# Update visual positions of all circulating passengers
	for row in _circulating_rows:
		var pt_info = _get_curve_point_and_normal(passenger_track.curve, row.progress, true)
		for p in row.passengers:
			if p["state"] == "CIRCULATING" and is_instance_valid(p.get("view")):
				var lpos = _calc_lane_pos(pt_info["pos"], pt_info["normal"], p["lane"])
				p["view"].position = lpos

	
	# Isometric manual Y-sorting for buses based on global screen Y
	if vehicle_layer != null:
		var views = []
		for i in vehicle_layer.get_child_count():
			var c = vehicle_layer.get_child(i)
			if c is VehicleView:
				views.append(c)
		views.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
		for i in range(views.size()):
			if views[i].get_index() != i:
				vehicle_layer.move_child(views[i], i)


func _ready() -> void:
	_build_scene_hierarchy()
	_setup_controller()
	_load_current_level()

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
	board_root.scale = Vector2(1.0, 0.72) # Isometric 2.5D toy depth
	
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

	passenger_track_bg = Node2D.new()
	passenger_track_bg.name = "PassengerTrackBg"
	passenger_track_bg.z_index = -2
	passenger_track_root.add_child(passenger_track_bg)

	passenger_visuals = Node2D.new()
	passenger_visuals.name = "PassengerVisuals"
	passenger_visuals.y_sort_enabled = true
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
	controller.track_snapshot_provider = Callable(self, "get_runtime_track_snapshot")
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

func _load_current_level() -> void:
	var lvl_num = 1
	var gc = null
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		lvl_num = gc.current_level_number

	var lvl: CarJamLevelData = null
	var path = "res://levels/level_%03d.tres" % lvl_num
	if ResourceLoader.exists(path):
		lvl = ResourceLoader.load(path) as CarJamLevelData

	if lvl == null:
		push_error("Level resource not found: " + path)
		if ResourceLoader.exists("res://levels/level_001.tres"):
			lvl = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
		else:
			lvl = CarJamLevelFactory.create_level_1()

	# Reset result overlay state for this fresh level run.
	_result_outcome = ""
	if result_overlay != null:
		result_overlay.visible = false
	if result_btn != null:
		result_btn.visible = false
	if result_retry_btn != null:
		result_retry_btn.visible = false
	if result_subtitle_label != null:
		result_subtitle_label.visible = false
		result_subtitle_label.text = ""
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false

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
		if is_instance_valid(p.get("view", null)): p["view"].queue_free()
		var pf = p.get("follower", null)
		if is_instance_valid(pf): pf.queue_free()
	all_passengers.clear()
	circulating_ids.clear()
	_feeder_passengers.clear()
	_pending_feeder_passengers.clear()
	_circulating_rows.clear()
	_feeder_rows.clear()
	_pending_feeder_rows.clear()
	if is_instance_valid(passenger_track):
		passenger_track.queue_free()
		passenger_track = null
	if is_instance_valid(feeder_track):
		feeder_track.queue_free()
		feeder_track = null
	
	if is_instance_valid(passenger_track_bg):
		for c in passenger_track_bg.get_children():
			c.queue_free()

	if is_instance_valid(passenger_visuals):
		for c in passenger_visuals.get_children():
			c.queue_free()

	# 1. Board Background
	board_bg.setup(lvl.board_size)

	# 2. Parking Slots
	var slot_spacing := 65.0
	var total_span: float = float(lvl.parking_slots_count - 1) * slot_spacing
	
	# Draw a thick rounded asphalt background for parking
	var parking_bg = Node2D.new()
	parking_bg.name = "ParkingBase"
	parking_bg.z_index = -1
	

	var bg_w = total_span + ParkingSlotView.SLOT_WIDTH + 32.0 # total_span + SLOT_WIDTH + padding
	var bg_h = ParkingSlotView.SLOT_HEIGHT + 20.0 # SLOT_HEIGHT + padding
	
	parking_bg.draw.connect(func():
		var style = StyleBoxFlat.new()
		style.bg_color = Color("c5c9db") # Seamlessly cohesive grey apron matching platform and road
		style.set_corner_radius_all(12)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color("a5abc2") # Clean subtle apron border matching platform curb shadow
		style.shadow_color = Color(0, 0, 0, 0.08) # Soft integrated depth, no harsh floating-card look
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
		style.draw(parking_bg.get_canvas_item(), Rect2(-bg_w/2.0, -bg_h/2.0, bg_w, bg_h))
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
		# Compensate board_root's 0.72 Y-scaling so buses render at uniform BUS_VISUAL_SCALE (0.85) global scale
		# across all orientations (eliminates the 28% size difference between vertical and horizontal buses)
		var board_scale_y = board_root.scale.y if board_root != null and board_root.scale.y != 0.0 else 0.72
		vv.scale = Vector2(VehicleView.BUS_VISUAL_SCALE, VehicleView.BUS_VISUAL_SCALE / board_scale_y)
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
	return parking_root.position if parking_root != null else Vector2(0, PARKING_Y)

## Build the flat per-passenger color sequence from the universal
## PassengerSequence. Returns [] if the universal layer cannot produce a
## valid plan for this level (caller falls back to the legacy RNG
## generator). Output shape mirrors the legacy mixed generator so the
## downstream 4-lane row / feeder logic is unchanged.
##
## The universal layer (scripts/universal/) is the authoritative source
## of color, identity, quantity, sequence, and boarding eligibility.
## This function is the only adapter between that logic and the visual
## track / feeder layout.
func _build_universal_passenger_queue() -> Array[Dictionary]:
	if controller == null or controller.level_data == null:
		return []
	var UniversalIntegration = load("res://scripts/universal/level_integration.gd")
	var UniversalSequence = load("res://scripts/universal/passenger_sequence.gd")
	if UniversalIntegration == null or UniversalSequence == null:
		return []
	var lvl = controller.level_data
	var slot_count = controller.parking.get_unlocked_slot_count() if controller.parking != null else 3
	var runtime = UniversalIntegration.build_runtime(lvl, MAX_INITIAL_LOOP_PASSENGERS, slot_count)
	var validation = runtime.get("validation", null)
	if validation == null or not validation.solvable:
		return []
	var seq = runtime["sequence"]
	if seq == null:
		return []
	var out: Array[Dictionary] = []
	for p in seq.all():
		out.append({"id": int(p.id), "color_id": String(p.color), "group_id": int(p.group_id)})
	return out

func _generate_mixed_passenger_sequence(groups: Array[PassengerGroupData]) -> Array[Dictionary]:
	var total_counts := {}
	var total_passengers := 0
	var group_rem: Array[int] = []
	for g in groups:
		total_counts[g.color_id] = total_counts.get(g.color_id, 0) + g.initial_count
		total_passengers += g.initial_count
		group_rem.append(g.initial_count)

	var colors: Array[String] = []
	for c in total_counts:
		colors.append(c)

	var rng := RandomNumberGenerator.new()
	var lvl_id: int = 1
	if controller != null and controller.level_data != null:
		lvl_id = controller.level_data.level_id
	rng.seed = 202610 + lvl_id * 100

	var remaining := total_counts.duplicate()
	var result: Array[Dictionary] = []
	var last_color := ""
	var run_count := 0

	for pid in total_passengers:
		var candidates: Array[String] = []
		for c in colors:
			if remaining[c] > 0:
				if c != last_color or run_count < 3:
					candidates.append(c)
		if candidates.is_empty():
			for c in colors:
				if remaining[c] > 0:
					candidates.append(c)

		var pick_idx := rng.randi() % candidates.size()
		var chosen := candidates[pick_idx]
		
		# Map to the earliest matching group with remaining capacity
		var chosen_gid := 0
		for g_i in groups.size():
			if groups[g_i].color_id == chosen and group_rem[g_i] > 0:
				chosen_gid = g_i
				group_rem[g_i] -= 1
				break

		result.append({"id": pid, "color_id": chosen, "group_id": chosen_gid})
		remaining[chosen] -= 1
		if chosen == last_color:
			run_count += 1
		else:
			last_color = chosen
			run_count = 1

	return result

func _init_passenger_track() -> void:
	passenger_track = Path2D.new()
	var curve := Curve2D.new()
	var h := 63.51 # R=115.0 * 0.552285
	# Start at merge point (270, 0)
	curve.add_point(Vector2(270, 0), Vector2(0, -h), Vector2(0, h))
	# Bottom right arc into bottom straight
	curve.add_point(Vector2(155, 115), Vector2(h, 0), Vector2.ZERO)
	# Bottom straight (above parking)
	curve.add_point(Vector2(-155, 115), Vector2.ZERO, Vector2(-h, 0))
	# Left semicircle apex
	curve.add_point(Vector2(-270, 0), Vector2(0, h), Vector2(0, -h))
	# Top left arc into top straight
	curve.add_point(Vector2(-155, -115), Vector2(-h, 0), Vector2.ZERO)
	# Top straight
	curve.add_point(Vector2(155, -115), Vector2.ZERO, Vector2(h, 0))
	# Close loop back to (270, 0)
	curve.add_point(Vector2(270, 0), Vector2(0, -h), Vector2(0, h))
	passenger_track.curve = curve
	_platform_start_prog = curve.get_closest_offset(curve.get_point_position(1))
	_platform_end_prog = curve.get_closest_offset(curve.get_point_position(2))
	
	# CONTINUOUS FEEDER TRACK
	feeder_track = Path2D.new()
	feeder_track.name = "FeederTrack"
	var f_curve := Curve2D.new()
	# Smooth, continuous curve from deep offscreen entrance merging into loop tangentially at (270, 0)
	# Stays well clear of the main oval until the intentional merge approach
	f_curve.add_point(Vector2(650, -420), Vector2.ZERO, Vector2(-80, 80))
	f_curve.add_point(Vector2(440, -180), Vector2(60, -70), Vector2(-50, 60))
	f_curve.add_point(Vector2(350, -70), Vector2(30, -45), Vector2(-25, 35))
	f_curve.add_point(Vector2(270, 0), Vector2(-15, -45), Vector2.ZERO)
	feeder_track.curve = f_curve

	# PREMIUM PLAZA INTEGRATION
	var plaza = preload("res://scripts/gameplay/plaza_environment.gd").new()
	plaza.name = "PlazaEnvironment"
	passenger_track_bg.add_child(plaza)

	# Dedicated background track renderer (z_index = -2) so it NEVER occludes passengers
	var track_renderer = preload("res://scripts/gameplay/track_renderer.gd").new()
	track_renderer.name = "TrackRenderer"
	track_renderer.curve = curve
	track_renderer.feeder_curve = f_curve
	track_renderer.z_index = -2
	passenger_track_bg.add_child(track_renderer)

	_waiting_label = Label.new()
	_waiting_label.add_theme_font_size_override("font_size", 20)
	_waiting_label.add_theme_color_override("font_color", Color("94a3b8"))
	_waiting_label.add_theme_color_override("font_outline_color", Color.WHITE)
	_waiting_label.add_theme_constant_override("outline_size", 4)
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.visible = false
	passenger_visuals.add_child(_waiting_label)

	passenger_track_root.add_child(feeder_track)
	passenger_track_root.add_child(passenger_track)
	
	# Precalculate boarding crossing points for ALL parking slots
	slot_boarding_points.clear()
	var slot_spacing := 65.0
	var total_span: float = float(controller.level_data.parking_slots_count - 1) * slot_spacing
	var min_trig: float = 999999.0
	var max_trig: float = -999999.0
	for i in controller.level_data.parking_slots_count:
		var slot_x: float = slot_views[i].position.x if i < slot_views.size() else (-total_span / 2.0 + float(i) * slot_spacing)
		var trig_x: float = clampf(slot_x, -75.0, 75.0)
		var closest: float = passenger_track.curve.get_closest_offset(Vector2(trig_x, 115.0))
		slot_boarding_points[i] = closest
		min_trig = minf(min_trig, closest)
		max_trig = maxf(max_trig, closest)

	if not slot_boarding_points.is_empty():
		_platform_start_prog = min_trig - 25.0
		_platform_end_prog = max_trig + 25.0

	_last_board_landing_time = 0.0
	_oval_freed_capacity = 0
	all_passengers.clear()
	circulating_ids.clear()
	_feeder_passengers.clear()
	_pending_feeder_passengers.clear()
	_circulating_rows.clear()
	_feeder_rows.clear()
	_pending_feeder_rows.clear()

	# Universal authoritative source: prefer the wave-plan-driven
	# PassengerSequence. The legacy mixed RNG generator is only used as a
	# fallback if the universal layer refuses the level (e.g. malformed).
	var all_queue_p: Array[Dictionary] = _build_universal_passenger_queue()
	if all_queue_p.is_empty():
		all_queue_p = _generate_mixed_passenger_sequence(controller.queue.get_all_groups())

	var total_rows = int(ceil(float(all_queue_p.size()) / float(NUM_LANES)))
	var all_rows: Array[PassengerRow] = []
	for r in total_rows:
		var row = PassengerRow.new()
		row.row_id = r
		for k in NUM_LANES:
			var idx = r * NUM_LANES + k
			if idx < all_queue_p.size():
				var p_info = all_queue_p[idx]
				var p_obj = {
					"id": p_info["id"],
					"color_id": p_info["color_id"],
					"group_id": p_info.get("group_id", 0),
					"lane": k,
					"view": null,
					"state": "PENDING"
				}
				row.passengers.append(p_obj)
				all_passengers[p_obj["id"]] = p_obj
		all_rows.append(row)

	controller.register_passengers(all_queue_p)

	# Main oval starts densely packed (38 rows = 152 passengers)
	var track_len = passenger_track.curve.get_baked_length()
	var initial_rows_count = mini(all_rows.size(), int(MAX_INITIAL_LOOP_PASSENGERS / NUM_LANES))
	var loop_pitch: float = (track_len / float(initial_rows_count)) if initial_rows_count > 0 else ROW_SPACING
	for r in initial_rows_count:
		var row = all_rows[r]
		row.is_feeder = false
		row.progress = fmod(track_len - float(r) * loop_pitch, track_len)
		if row.progress < 0.0: row.progress += track_len
		
		var pt_info = _get_curve_point_and_normal(passenger_track.curve, row.progress, true)
		for p in row.passengers:
			var pv := PassengerView.new()
			pv.setup(p["color_id"], p["id"], p["lane"])
			passenger_visuals.add_child(pv)
			p["view"] = pv
			p["state"] = "CIRCULATING"
			controller.set_passenger_state(p["id"], "CIRCULATING")
			var lpos = _calc_lane_pos(pt_info["pos"], pt_info["normal"], p["lane"])
			pv.position = lpos
			
			circulating_ids.append(p["id"])
		_circulating_rows.append(row)

	# Remaining rows form a separate dense waiting queue on feeder cross-track
	var f_len = feeder_track.curve.get_baked_length()
	var feeder_stop_pos: float = f_len - 110.0 # Queue stop line rests 110px before junction, completely clear of oval (41.5px clearance)
	for r in range(initial_rows_count, all_rows.size()):
		var row = all_rows[r]
		var feeder_idx = r - initial_rows_count
		var target_f_prog = feeder_stop_pos - float(feeder_idx) * ROW_SPACING
		if target_f_prog >= 0.0:
			row.is_feeder = true
			row.progress = target_f_prog
			var f_pt_info = _get_curve_point_and_normal(feeder_track.curve, row.progress, false)
			for p in row.passengers:
				var pv := PassengerView.new()
				pv.setup(p["color_id"], p["id"], p["lane"])
				pv.set_waiting(true)
				passenger_visuals.add_child(pv)
				p["view"] = pv
				p["state"] = "FEEDER"
				controller.set_passenger_state(p["id"], "FEEDER")
				var lpos = _calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], p["lane"])
				pv.position = lpos
				_feeder_passengers.append(p)
			_feeder_rows.append(row)
		else:
			row.is_feeder = true
			row.progress = 0.0
			_pending_feeder_rows.append(row)
			for p in row.passengers:
				p["state"] = "PENDING"
				controller.set_passenger_state(p["id"], "PENDING")
				_pending_feeder_passengers.append(p)

func get_runtime_track_snapshot() -> Dictionary:
	var circ_rows: Array = []
	for row in _circulating_rows:
		if row.passengers.is_empty():
			continue
		var r_pass: Array = []
		for p in row.passengers:
			r_pass.append({
				"id": p["id"],
				"color_id": p["color_id"],
				"state": p.get("state", "CIRCULATING")
			})
		circ_rows.append({
			"progress": row.progress,
			"passengers": r_pass
		})

	var f_rows: Array = []
	for row in _feeder_rows:
		if row.passengers.is_empty():
			continue
		var r_pass: Array = []
		for p in row.passengers:
			r_pass.append({
				"id": p["id"],
				"color_id": p["color_id"],
				"state": p.get("state", "FEEDER")
			})
		f_rows.append({
			"progress": row.progress,
			"passengers": r_pass
		})

	var p_rows: Array = []
	for row in _pending_feeder_rows:
		if row.passengers.is_empty():
			continue
		var r_pass: Array = []
		for p in row.passengers:
			r_pass.append({
				"id": p["id"],
				"color_id": p["color_id"],
				"state": p.get("state", "PENDING")
			})
		p_rows.append({
			"progress": row.progress,
			"passengers": r_pass
		})

	return {
		"circulating_rows": circ_rows,
		"feeder_rows": f_rows,
		"pending_rows": p_rows,
		"oval_freed_capacity": _oval_freed_capacity
	}

func _board_circulating_passenger(p: Dictionary, vehicle_id: int, slot_idx: int, trigger_prog: float) -> void:
	p["state"] = "BOARDING_RESERVED"
	_animate_individual_boarding(p, vehicle_id, slot_idx, trigger_prog)
	circulating_ids.erase(p["id"])

func _try_board_passenger(p: Dictionary, slot_idx: int) -> bool:
	if p.get("state", "") != "CIRCULATING":
		return false
	var slot = controller.parking.get_slot(slot_idx)
	if slot == null or slot.state != CarJamParkingManager.SlotState.OCCUPIED or slot.vehicle_id == -1:
		return false
	var v = controller.vehicles.get(slot.vehicle_id, null)
	if v == null or v.color_id != p["color_id"]:
		return false
		
	if controller.try_reserve_boarding(p["id"], slot.vehicle_id, p["color_id"], p.get("group_id", -1)):
		var trigger_prog = slot_boarding_points.get(slot_idx, p.get("progress", 0.0))
		_board_circulating_passenger(p, slot.vehicle_id, slot_idx, trigger_prog)
		return true
	return false

func _fill_passenger_track() -> void:
	pass # Managed continuously by feeder logic

func _on_vehicle_tapped(vehicle_id: int) -> void:
	_play_sfx("select")
	var accepted := controller.tap_vehicle(vehicle_id)
	if not accepted:
		var vv: VehicleView = vehicle_views.get(vehicle_id, null)
		if vv != null:
			vv.play_blocked_shake()

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

	# CORRIDOR WAYPOINT — directly below the assigned parking slot, in
	# the clear approach zone BELOW the parking strip. The bus drives
	# straight along its puzzle arrow to this waypoint, then makes its
	# full turn inside the corridor before entering the bay vertically.
	# This guarantees the bus never sweeps sideways across VIP or other
	# parking slots.
	var corridor_pos := Vector2(target_slot_pos.x, target_slot_pos.y + ParkingSlotView.SLOT_HEIGHT)

	# Authoritative parking slot dimensions from ParkingSlotView (SLOT_WIDTH = 53.0, SLOT_HEIGHT = 94.0)
	# All normalized short buses have canonical canvas 62x110 and body 48x102 (V) / 46x102 (H).
	# Visual scale is uniform 0.85 everywhere (board, transit, parking) with zero size popping or distortion.
	var parked_size: Vector2 = vv.get_unscaled_parked_size()
	var final_scale: float = VehicleView.BUS_VISUAL_SCALE
	if parked_size.x > 0.0 and parked_size.y > 0.0 and (absf(parked_size.x - VehicleView.CANONICAL_CANVAS_WIDTH) > 1.0 or absf(parked_size.y - VehicleView.CANONICAL_CANVAS_HEIGHT) > 1.0):
		var scale_w: float = ParkingSlotView.SLOT_WIDTH / parked_size.x
		var scale_h: float = ParkingSlotView.SLOT_HEIGHT / parked_size.y
		final_scale = minf(scale_w, scale_h)
	var final_scale_vec := Vector2(final_scale, final_scale)

	VehicleMovement.animate_dispatch(
		vv,
		vv.position,
		exit_pos,
		corridor_pos,
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

	# EVENT-DRIVEN BOARDING RECOVERY:
	# Immediately launch boarding for matching circulating passengers on the platform
	_recover_boarding_for_slot(slot_id)

func _recover_boarding_for_slot(slot_id: int) -> void:
	if passenger_track == null or controller == null: return
	var slot = controller.parking.get_slot(slot_id)
	if slot == null or slot.state != CarJamParkingManager.SlotState.OCCUPIED or slot.vehicle_id == -1:
		return
	var v = controller.vehicles.get(slot.vehicle_id, null)
	if v == null or v.remaining_capacity() <= 0: return
	
	var track_len = passenger_track.curve.get_baked_length()
	var trigger_prog: float = slot_boarding_points.get(slot_id, 0.0)
	
	# Find matching rows and sort by proximity to trigger_prog
	var rows_to_check = _circulating_rows.duplicate()
	rows_to_check.sort_custom(func(a, b):
		var da = trigger_prog - a.progress
		if da < 0: da += track_len
		var db = trigger_prog - b.progress
		if db < 0: db += track_len
		return da < db
	)
	
	var empty_rows: Array[PassengerRow] = []
	for row in rows_to_check:
		if v.remaining_capacity() <= 0: break
		# Only board rows physically AT the slot's boarding trigger zone
		var dist_to_trig = trigger_prog - row.progress
		if dist_to_trig < 0: dist_to_trig += track_len
		var is_at_boarding_exit: bool = (dist_to_trig <= 25.0 or abs(row.progress - trigger_prog) <= 25.0)
		if not is_at_boarding_exit:
			continue

		var to_remove: Array[Dictionary] = []
		for p in row.passengers:
			if p["state"] == "CIRCULATING" and p["color_id"] == v.color_id:
				if controller.try_reserve_boarding(p["id"], v.id, p["color_id"], p.get("group_id", -1)):
					_board_circulating_passenger(p, v.id, slot_id, trigger_prog)
					to_remove.append(p)
					if v.remaining_capacity() <= 0:
						break
		for p in to_remove:
			row.passengers.erase(p)
		if row.passengers.is_empty():
			empty_rows.append(row)
			
	for er in empty_rows:
		_circulating_rows.erase(er)

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
	# Guard: the win flow must only run once per session, AND must never override
	# a failure outcome (a stray late signal can't resurrect victory UI).
	if _result_outcome == "victory":
		return
	if _result_outcome == "failure":
		# Failure is terminal for this attempt; do not flip to victory.
		return
	_result_outcome = "victory"
	_play_sfx("victory")

	var gc = get_tree().root.get_node_or_null("GameController")
	var current_num: int = 1
	if gc != null:
		current_num = int(gc.current_level_number)

	# Persist legitimate completion — but never unlock levels on a failure path.
	var save_mgr = get_tree().root.get_node_or_null("SaveManager")
	if save_mgr != null:
		# Save per-level completion + raise max unlocked to current+1 if next exists.
		if current_num == 1:
			save_mgr.set_level_1_done(true)
		var next_num: int = current_num + 1
		if gc != null and gc.has_level(next_num):
			save_mgr.unlock_level(next_num)

	result_title_label.text = "LEVEL %d CLEAR!" % current_num
	result_title_label.add_theme_color_override("font_color", Color("facc15"))

	# Configure the next-level button based on actual authored levels.
	var next_num: int = current_num + 1
	if gc != null and gc.has_level(next_num):
		result_btn_label.text = "Level %d" % next_num
		result_btn.visible = true
		result_subtitle_label.visible = false
		result_subtitle_label.text = ""
	else:
		# No further level — don't pretend the player can advance.
		result_btn.visible = false
		result_subtitle_label.text = "More Levels Coming Soon"
		result_subtitle_label.visible = true

	# Failure-only button is never shown on victory.
	result_retry_btn.visible = false

	result_overlay.visible = true

func _on_puzzle_failed() -> void:
	# Guard: failure flow runs once per session.
	if _result_outcome == "failure":
		return
	_result_outcome = "failure"
	_play_sfx("failure")

	# CRITICAL: failure must NEVER enable level progression or unlock the next level.
	# Only the retry/home actions are exposed — no victory-style next-level button.
	result_title_label.text = "OUT OF SPACE!"
	result_title_label.add_theme_color_override("font_color", Color("ef4444"))

	# Hide the victory-only progression action.
	result_btn.visible = false
	result_subtitle_label.text = ""
	result_subtitle_label.visible = false
	result_retry_btn.visible = true

	result_overlay.visible = true

func _on_result_next_pressed() -> void:
	# Defensive: if the user somehow taps this button outside a victory state,
	# do nothing rather than silently advancing levels.
	if _result_outcome != "victory":
		return
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc != null:
		var next_num: int = gc.current_level_number + 1
		if gc.has_level(next_num):
			gc.start_level(next_num)
		else:
			# Belt-and-braces: if no next level exists, send home instead of looping.
			gc.goto_scene("res://scenes/main.tscn")

func _on_result_retry_pressed() -> void:
	if _result_outcome != "failure":
		return
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc != null:
		gc.start_level(gc.current_level_number)
	else:
		get_tree().reload_current_scene()

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

	var btn_restart := TextureButton.new()
	btn_restart.texture_normal = load("res://assets/ui/gameplay_buttons/restart_normal.svg")
	btn_restart.texture_pressed = load("res://assets/ui/gameplay_buttons/restart_pressed.svg")
	btn_restart.ignore_texture_size = true
	btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_restart.custom_minimum_size = Vector2(50, 50)
	btn_restart.button_down.connect(func():
		var tw = btn_restart.create_tween()
		tw.tween_property(btn_restart, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn_restart.button_up.connect(func():
		var tw = btn_restart.create_tween()
		tw.tween_property(btn_restart, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	btn_restart.pivot_offset = Vector2(25, 25)
	btn_restart.pressed.connect(_on_restart_pressed)
	top_bar.add_child(btn_restart)

	level_title_label = Label.new()
	var top_gc = get_tree().root.get_node_or_null("GameController") if is_inside_tree() and get_tree() and get_tree().root else null
	level_title_label.text = "Level " + str(top_gc.current_level_number if top_gc else 1)
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

	var btn_pause := TextureButton.new()
	btn_pause.texture_normal = load("res://assets/ui/gameplay_buttons/pause_normal.svg")
	btn_pause.texture_pressed = load("res://assets/ui/gameplay_buttons/pause_pressed.svg")
	btn_pause.ignore_texture_size = true
	btn_pause.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_pause.custom_minimum_size = Vector2(50, 50)
	btn_pause.button_down.connect(func():
		var tw = btn_pause.create_tween()
		tw.tween_property(btn_pause, "scale", Vector2(0.9, 0.9), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn_pause.button_up.connect(func():
		var tw = btn_pause.create_tween()
		tw.tween_property(btn_pause, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_QUAD)
	)
	btn_pause.pivot_offset = Vector2(25, 25)
	btn_pause.anchor_left = 1.0
	btn_pause.offset_left = -50.0
	btn_pause.pressed.connect(_on_pause_pressed)
	top_bar.add_child(btn_pause)

	# BoosterBar (VIP, Arrange, Jumble) with original Premium 3D PNGs
	booster_bar = Control.new()
	booster_bar.name = "BoosterBar"
	booster_bar.anchor_left = 0.0
	booster_bar.anchor_right = 1.0
	booster_bar.anchor_top = 1.0
	booster_bar.anchor_bottom = 1.0
	booster_bar.offset_left = 20.0
	booster_bar.offset_right = -20.0
	booster_bar.offset_top = -102.0
	booster_bar.offset_bottom = -18.0
	safe_area_root.add_child(booster_bar)

	var b_hbox := HBoxContainer.new()
	b_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_theme_constant_override("separation", 24)
	booster_bar.add_child(b_hbox)

	var boosters = [
		{"name": "VIP", "icon": "res://assets/ui/booster_icons/vip_icon.png"},
		{"name": "Arrange", "icon": "res://assets/ui/booster_icons/arrange_icon.png"},
		{"name": "Jumble", "icon": "res://assets/ui/booster_icons/jumble_icon.png"}
	]

	for b_info in boosters:
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)

		var btn_container = Control.new()
		btn_container.custom_minimum_size = Vector2(56, 56)

		var btn := TextureButton.new()
		btn.texture_normal = load("res://assets/ui/gameplay_buttons/base_booster_normal.svg")
		btn.texture_pressed = load("res://assets/ui/gameplay_buttons/base_booster_pressed.svg")
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# Add the illustration PNG on top
		var icon_rect = TextureRect.new()
		icon_rect.texture = load(b_info["icon"])
		icon_rect.ignore_texture_size = true
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# slight padding inside the SVG base
		icon_rect.offset_left = 10
		icon_rect.offset_right = -10
		icon_rect.offset_top = 8
		icon_rect.offset_bottom = -14
		btn.add_child(icon_rect)
		
		# Premium glossy pressed effect
		btn.button_down.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "position:y", 4.0, 0.05).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(btn, "modulate", Color(0.85, 0.85, 0.85), 0.05)
		)
		btn.button_up.connect(func():
			var tw = btn.create_tween()
			tw.tween_property(btn, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(btn, "modulate", Color.WHITE, 0.1)
		)
		
		btn_container.add_child(btn)

		# Add a premium 3D green '+' circle badge
		var plus := Label.new()
		plus.text = "+"
		plus.add_theme_font_size_override("font_size", 14)
		plus.add_theme_color_override("font_color", Color("ffffff"))
		plus.add_theme_color_override("font_outline_color", Color("064e3b"))
		plus.add_theme_constant_override("outline_size", 2)
		
		var p_style = StyleBoxFlat.new()
		p_style.bg_color = Color("22c55e")
		p_style.corner_radius_top_left = 9
		p_style.corner_radius_top_right = 9
		p_style.corner_radius_bottom_left = 9
		p_style.corner_radius_bottom_right = 9
		p_style.border_width_bottom = 2
		p_style.border_color = Color("14532d")
		p_style.border_blend = false
		p_style.shadow_color = Color(0, 0, 0, 0.5)
		p_style.shadow_size = 1
		p_style.shadow_offset = Vector2(0, 1)
		plus.add_theme_stylebox_override("normal", p_style)
		
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.size = Vector2(18, 18)
		plus.position = Vector2(40, -4)
		btn_container.add_child(plus)
		
		vbox.add_child(btn_container)
		
		var lbl = Label.new()
		lbl.text = b_info["name"]
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color("ffffff"))
		lbl.add_theme_color_override("font_outline_color", Color("1e293b"))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)
		
		b_hbox.add_child(vbox)

	# PauseOverlay (Settings Popup Redesign)
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_overlay)

	var p_bg := ColorRect.new()
	p_bg.name = "PauseBg"
	p_bg.color = Color(0, 0, 0, 0.7)
	p_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(p_bg)

	var p_center := CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(p_center)

	var p_wrapper := Control.new()
	p_wrapper.custom_minimum_size = Vector2(280, 315)
	p_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_center.add_child(p_wrapper)

	var p_panel := PanelContainer.new()
	p_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p_style_panel = StyleBoxFlat.new()
	p_style_panel.bg_color = Color("fcf8ef")
	p_style_panel.corner_radius_top_left = 24
	p_style_panel.corner_radius_top_right = 24
	p_style_panel.corner_radius_bottom_left = 24
	p_style_panel.corner_radius_bottom_right = 24
	p_style_panel.shadow_color = Color(0,0,0,0.3)
	p_style_panel.shadow_size = 9
	p_style_panel.shadow_offset = Vector2(0, 6)
	p_style_panel.border_width_bottom = 4
	p_style_panel.border_color = Color("e0d2b8")
	p_panel.add_theme_stylebox_override("panel", p_style_panel)
	p_wrapper.add_child(p_panel)

	# Glossy top
	var pop_gloss = Panel.new()
	pop_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_gloss.anchor_bottom = 0.5
	pop_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pg_style = StyleBoxFlat.new()
	pg_style.bg_color = Color(1, 1, 1, 0.18) # Clean subtle gloss, does not wash out title
	pg_style.corner_radius_top_left = 24
	pg_style.corner_radius_top_right = 24
	pop_gloss.add_theme_stylebox_override("panel", pg_style)
	p_wrapper.add_child(pop_gloss)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	p_panel.add_child(margin)

	var pb_vbox := VBoxContainer.new()
	pb_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pb_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(pb_vbox)

	# A. Top area with Title
	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("4a2810")) # High contrast warm brown (WCAG AAA)
	pb_vbox.add_child(title)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color("d4c3ad")
	pb_vbox.add_child(line)

	# C. Separate inner container (Toggles)
	var toggles := VBoxContainer.new()
	toggles.add_theme_constant_override("separation", 10)
	pb_vbox.add_child(toggles)
	
	var sm_sfx = true
	var sm_music = true
	var sm_haptics = true
	if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
		var sm = get_tree().root.get_node("SettingsManager")
		sm_sfx = sm.sfx_enabled()
		sm_music = sm.music_enabled()
		sm_haptics = sm.haptics_enabled()

	toggles.add_child(_create_custom_toggle("Sound", "res://assets/ui/icons/sound.svg", sm_sfx, func(on):
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_sfx(on)
	))
	toggles.add_child(_create_custom_toggle("Music", "res://assets/ui/icons/music.svg", sm_music, func(on): 
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_music(on)
		if is_inside_tree() and get_tree().root.has_node("AudioManager"):
			var am = get_tree().root.get_node("AudioManager")
			if on: am.play_music()
			else: am.stop_music()
	))
	toggles.add_child(_create_custom_toggle("Vibration", "res://assets/ui/icons/vibration.svg", sm_haptics, func(on):
		if is_inside_tree() and get_tree().root.has_node("SettingsManager"):
			get_tree().root.get_node("SettingsManager").set_haptics(on)
	))

	# D. Bottom buttons
	var btm_hbox = HBoxContainer.new()
	btm_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btm_hbox.add_theme_constant_override("separation", 12)
	pb_vbox.add_child(btm_hbox)

	var p_btn_restart := TextureButton.new()
	p_btn_restart.texture_normal = load("res://assets/ui/settings_buttons/restart_normal.svg")
	p_btn_restart.texture_pressed = load("res://assets/ui/settings_buttons/restart_pressed.svg")
	p_btn_restart.ignore_texture_size = true
	p_btn_restart.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_restart.custom_minimum_size = Vector2(98, 42)
	
	var r_lbl = Label.new()
	r_lbl.text = "Restart"
	r_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r_lbl.add_theme_font_size_override("font_size", 15)
	r_lbl.add_theme_color_override("font_color", Color.WHITE)
	r_lbl.add_theme_color_override("font_outline_color", Color("14532d"))
	r_lbl.add_theme_constant_override("outline_size", 4)
	r_lbl.offset_top = -4
	r_lbl.offset_bottom = -4
	p_btn_restart.add_child(r_lbl)
	
	p_btn_restart.button_down.connect(func():
		r_lbl.offset_top = 2
		r_lbl.offset_bottom = 2
		var tw = p_btn_restart.create_tween()
		tw.tween_property(p_btn_restart, "scale", Vector2(0.96, 0.96), 0.05)
	)
	p_btn_restart.button_up.connect(func():
		r_lbl.offset_top = -4
		r_lbl.offset_bottom = -4
		var tw = p_btn_restart.create_tween()
		tw.tween_property(p_btn_restart, "scale", Vector2.ONE, 0.1)
	)
	p_btn_restart.pivot_offset = Vector2(49, 21)
	p_btn_restart.pressed.connect(_direct_restart)
	btm_hbox.add_child(p_btn_restart)

	var p_btn_home := TextureButton.new()
	p_btn_home.texture_normal = load("res://assets/ui/settings_buttons/home_normal.svg")
	p_btn_home.texture_pressed = load("res://assets/ui/settings_buttons/home_pressed.svg")
	p_btn_home.ignore_texture_size = true
	p_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	p_btn_home.custom_minimum_size = Vector2(98, 42)
	
	var h_lbl = Label.new()
	h_lbl.text = "Home"
	h_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h_lbl.add_theme_font_size_override("font_size", 15)
	h_lbl.add_theme_color_override("font_color", Color.WHITE)
	h_lbl.add_theme_color_override("font_outline_color", Color("9a3412"))
	h_lbl.add_theme_constant_override("outline_size", 4)
	h_lbl.offset_top = -4
	h_lbl.offset_bottom = -4
	p_btn_home.add_child(h_lbl)
	
	p_btn_home.button_down.connect(func():
		h_lbl.offset_top = 2
		h_lbl.offset_bottom = 2
		var tw = p_btn_home.create_tween()
		tw.tween_property(p_btn_home, "scale", Vector2(0.96, 0.96), 0.05)
	)
	p_btn_home.button_up.connect(func():
		h_lbl.offset_top = -4
		h_lbl.offset_bottom = -4
		var tw = p_btn_home.create_tween()
		tw.tween_property(p_btn_home, "scale", Vector2.ONE, 0.1)
	)
	p_btn_home.pivot_offset = Vector2(49, 21)
	p_btn_home.pressed.connect(func():
		get_tree().paused = false
		var p_gc = get_tree().root.get_node_or_null("GameController") if get_tree() and get_tree().root else null
		if p_gc: p_gc.goto_scene("res://scenes/main.tscn")
	)
	btm_hbox.add_child(p_btn_home)

	# B. Close button (top-right)
	var close_btn := _create_close_button(_on_resume_pressed)
	close_btn.anchor_left = 1.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -22.0
	close_btn.offset_top = -14.0
	close_btn.offset_right = 22.0
	close_btn.offset_bottom = 30.0
	p_wrapper.add_child(close_btn)

	# ResultOverlay
	result_overlay = Control.new()
	result_overlay.name = "ResultOverlay"
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(result_overlay)

	var res_bg := ColorRect.new()
	res_bg.color = Color(0, 0, 0, 0.8)
	res_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	res_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.add_child(res_bg)
	
	var res_center := CenterContainer.new()
	res_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(res_center)
	
	var res_panel := PanelContainer.new()
	res_panel.custom_minimum_size = Vector2(300, 320)
	
	# Create a warm glowing panel style specifically for the victory screen
	var res_style = StyleBoxFlat.new()
	res_style.bg_color = Color("fffdf5") # warm white
	res_style.corner_radius_top_left = 32
	res_style.corner_radius_top_right = 32
	res_style.corner_radius_bottom_left = 32
	res_style.corner_radius_bottom_right = 32
	res_style.shadow_color = Color(1.0, 0.85, 0.4, 0.25) # soft golden glow
	res_style.shadow_size = 20
	res_style.shadow_offset = Vector2(0, 4)
	res_style.border_width_bottom = 6
	res_style.border_color = Color("e5d3b3")
	res_panel.add_theme_stylebox_override("panel", res_style)
	res_center.add_child(res_panel)
	
	var res_margin = MarginContainer.new()
	res_margin.add_theme_constant_override("margin_left", 24)
	res_margin.add_theme_constant_override("margin_right", 24)
	res_margin.add_theme_constant_override("margin_top", 32)
	res_margin.add_theme_constant_override("margin_bottom", 32)
	res_panel.add_child(res_margin)
	
	var res_vbox := VBoxContainer.new()
	res_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_vbox.add_theme_constant_override("separation", 20)
	res_margin.add_child(res_vbox)
	
	# Header with Trophy and Title
	var header_vbox = VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 8)
	res_vbox.add_child(header_vbox)
	
	var trophy_icon = TextureRect.new()
	trophy_icon.texture = load("res://assets/ui/icons/trophy.svg")
	trophy_icon.ignore_texture_size = true
	trophy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy_icon.custom_minimum_size = Vector2(64, 64)
	trophy_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header_vbox.add_child(trophy_icon)
	
	result_title_label = Label.new()
	result_title_label.text = "LEVEL CLEAR!"
	result_title_label.add_theme_font_size_override("font_size", 28)
	result_title_label.add_theme_color_override("font_color", Color("4a2810"))
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_vbox.add_child(result_title_label)
	
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 16)
	res_vbox.add_child(btn_vbox)
	
	# --- Button 1: Next Level (text + callback configured at show time) ---
	var res_btn_level2 := TextureButton.new()
	res_btn_level2.texture_normal = load("res://assets/ui/settings_buttons/next_normal.svg")
	res_btn_level2.texture_pressed = load("res://assets/ui/settings_buttons/next_pressed.svg")
	res_btn_level2.ignore_texture_size = true
	res_btn_level2.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_level2.custom_minimum_size = Vector2(160, 56)
	res_btn_level2.visible = false  # shown only on victory, text set per-level

	var l2_lbl = Label.new()
	l2_lbl.text = "Next"
	l2_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	l2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l2_lbl.add_theme_font_size_override("font_size", 20)
	l2_lbl.add_theme_color_override("font_color", Color.WHITE)
	l2_lbl.add_theme_color_override("font_outline_color", Color("1e3a8a"))
	l2_lbl.add_theme_constant_override("outline_size", 6)
	l2_lbl.offset_top = -4
	l2_lbl.offset_bottom = -4
	res_btn_level2.add_child(l2_lbl)

	res_btn_level2.button_down.connect(func():
		l2_lbl.offset_top = 2
		l2_lbl.offset_bottom = 2
		var tw = res_btn_level2.create_tween()
		tw.tween_property(res_btn_level2, "scale", Vector2(0.94, 0.94), 0.05)
	)
	res_btn_level2.button_up.connect(func():
		l2_lbl.offset_top = -4
		l2_lbl.offset_bottom = -4
		var tw = res_btn_level2.create_tween()
		tw.tween_property(res_btn_level2, "scale", Vector2.ONE, 0.1)
	)
	res_btn_level2.pivot_offset = Vector2(80, 28)
	res_btn_level2.pressed.connect(_on_result_next_pressed)
	btn_vbox.add_child(res_btn_level2)
	result_btn = res_btn_level2
	result_btn_label = l2_lbl

	# --- Button 1b: Retry (shown only on failure) ---
	var res_btn_retry := TextureButton.new()
	res_btn_retry.texture_normal = load("res://assets/ui/settings_buttons/restart_normal.svg")
	res_btn_retry.texture_pressed = load("res://assets/ui/settings_buttons/restart_pressed.svg")
	res_btn_retry.ignore_texture_size = true
	res_btn_retry.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_retry.custom_minimum_size = Vector2(160, 56)
	res_btn_retry.visible = false

	var retry_lbl = Label.new()
	retry_lbl.text = "Retry"
	retry_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	retry_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	retry_lbl.add_theme_font_size_override("font_size", 20)
	retry_lbl.add_theme_color_override("font_color", Color.WHITE)
	retry_lbl.add_theme_color_override("font_outline_color", Color("7c2d12"))
	retry_lbl.add_theme_constant_override("outline_size", 6)
	retry_lbl.offset_top = -4
	retry_lbl.offset_bottom = -4
	res_btn_retry.add_child(retry_lbl)

	res_btn_retry.button_down.connect(func():
		retry_lbl.offset_top = 2
		retry_lbl.offset_bottom = 2
		var tw = res_btn_retry.create_tween()
		tw.tween_property(res_btn_retry, "scale", Vector2(0.94, 0.94), 0.05)
	)
	res_btn_retry.button_up.connect(func():
		retry_lbl.offset_top = -4
		retry_lbl.offset_bottom = -4
		var tw = res_btn_retry.create_tween()
		tw.tween_property(res_btn_retry, "scale", Vector2.ONE, 0.1)
	)
	res_btn_retry.pivot_offset = Vector2(80, 28)
	res_btn_retry.pressed.connect(_on_result_retry_pressed)
	btn_vbox.add_child(res_btn_retry)
	result_retry_btn = res_btn_retry

	# --- Subtitle for "More Levels Coming Soon" state ---
	result_subtitle_label = Label.new()
	result_subtitle_label.text = ""
	result_subtitle_label.add_theme_font_size_override("font_size", 16)
	result_subtitle_label.add_theme_color_override("font_color", Color("475569"))
	result_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_subtitle_label.visible = false
	btn_vbox.add_child(result_subtitle_label)
	
	# --- Button 2: Home ---
	var res_btn_home := TextureButton.new()
	res_btn_home.texture_normal = load("res://assets/ui/settings_buttons/home_normal.svg")
	res_btn_home.texture_pressed = load("res://assets/ui/settings_buttons/home_pressed.svg")
	res_btn_home.ignore_texture_size = true
	res_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_home.custom_minimum_size = Vector2(160, 56)
	
	var rh_lbl = Label.new()
	rh_lbl.text = "Home"
	rh_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rh_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rh_lbl.add_theme_font_size_override("font_size", 20)
	rh_lbl.add_theme_color_override("font_color", Color.WHITE)
	rh_lbl.add_theme_color_override("font_outline_color", Color("9a3412"))
	rh_lbl.add_theme_constant_override("outline_size", 6)
	rh_lbl.offset_top = -4
	rh_lbl.offset_bottom = -4
	res_btn_home.add_child(rh_lbl)
	
	res_btn_home.button_down.connect(func():
		rh_lbl.offset_top = 2
		rh_lbl.offset_bottom = 2
		var tw = res_btn_home.create_tween()
		tw.tween_property(res_btn_home, "scale", Vector2(0.94, 0.94), 0.05)
	)
	res_btn_home.button_up.connect(func():
		rh_lbl.offset_top = -4
		rh_lbl.offset_bottom = -4
		var tw = res_btn_home.create_tween()
		tw.tween_property(res_btn_home, "scale", Vector2.ONE, 0.1)
	)
	res_btn_home.pivot_offset = Vector2(80, 28)
	res_btn_home.pressed.connect(func():
		_play_sfx("ui")
		get_tree().paused = false
		var gc = get_tree().root.get_node_or_null("GameController")
		if gc:
			gc.goto_scene("res://scenes/main.tscn")
	)
	btn_vbox.add_child(res_btn_home)

	# --- Restart Confirmation Popup ---
	restart_confirm_overlay = Control.new()
	restart_confirm_overlay.name = "RestartConfirmOverlay"
	restart_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	restart_confirm_overlay.visible = false
	restart_confirm_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(restart_confirm_overlay)

	var rc_bg := ColorRect.new()
	rc_bg.color = Color(0, 0, 0, 0.7)
	rc_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	rc_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	restart_confirm_overlay.add_child(rc_bg)

	var rc_center := CenterContainer.new()
	rc_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	restart_confirm_overlay.add_child(rc_center)

	var rc_wrapper := Control.new()
	rc_wrapper.custom_minimum_size = Vector2(280, 210)
	rc_center.add_child(rc_wrapper)

	var rc_panel := PanelContainer.new()
	rc_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rc_style = StyleBoxFlat.new()
	rc_style.bg_color = Color("fcf8ef")
	rc_style.corner_radius_top_left = 32
	rc_style.corner_radius_top_right = 32
	rc_style.corner_radius_bottom_left = 32
	rc_style.corner_radius_bottom_right = 32
	rc_style.shadow_color = Color(0, 0, 0, 0.3)
	rc_style.shadow_size = 14
	rc_style.shadow_offset = Vector2(0, 8)
	rc_style.border_width_bottom = 6
	rc_style.border_color = Color("e0d2b8")
	rc_panel.add_theme_stylebox_override("panel", rc_style)
	rc_wrapper.add_child(rc_panel)

	var rc_gloss = Panel.new()
	rc_gloss.set_anchors_preset(Control.PRESET_FULL_RECT)
	rc_gloss.anchor_bottom = 0.5
	rc_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rcg_style = StyleBoxFlat.new()
	rcg_style.bg_color = Color(1, 1, 1, 0.18)
	rcg_style.corner_radius_top_left = 32
	rcg_style.corner_radius_top_right = 32
	rc_gloss.add_theme_stylebox_override("panel", rcg_style)
	rc_wrapper.add_child(rc_gloss)

	var rc_margin := MarginContainer.new()
	rc_margin.add_theme_constant_override("margin_left", 24)
	rc_margin.add_theme_constant_override("margin_right", 24)
	rc_margin.add_theme_constant_override("margin_top", 20)
	rc_margin.add_theme_constant_override("margin_bottom", 20)
	rc_panel.add_child(rc_margin)

	var rc_vbox := VBoxContainer.new()
	rc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rc_vbox.add_theme_constant_override("separation", 14)
	rc_margin.add_child(rc_vbox)

	var rc_title := Label.new()
	rc_title.text = "Restart"
	rc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc_title.add_theme_font_size_override("font_size", 22)
	rc_title.add_theme_color_override("font_color", Color("4a2810"))
	rc_vbox.add_child(rc_title)

	var rc_line := ColorRect.new()
	rc_line.custom_minimum_size = Vector2(0, 2)
	rc_line.color = Color("d4c3ad")
	rc_vbox.add_child(rc_line)

	var rc_lbl = Label.new()
	rc_lbl.text = "Restart this level?"
	rc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc_lbl.add_theme_font_size_override("font_size", 16)
	rc_lbl.add_theme_color_override("font_color", Color("5c3d2e"))
	rc_vbox.add_child(rc_lbl)

	# YES / NO buttons
	var rc_btns = HBoxContainer.new()
	rc_btns.alignment = BoxContainer.ALIGNMENT_CENTER
	rc_btns.add_theme_constant_override("separation", 16)
	rc_vbox.add_child(rc_btns)

	rc_btns.add_child(_create_procedural_glossy_button("Yes", Color("22c55e"), Color("166534"), _confirm_restart_yes, Vector2(104, 44)))
	rc_btns.add_child(_create_procedural_glossy_button("No", Color("f97316"), Color("9a3412"), _confirm_restart_no, Vector2(104, 44)))

	# Close button (top right)
	var rc_close_btn := _create_close_button(_confirm_restart_no)
	rc_close_btn.anchor_left = 1.0
	rc_close_btn.anchor_right = 1.0
	rc_close_btn.anchor_top = 0.0
	rc_close_btn.anchor_bottom = 0.0
	rc_close_btn.offset_left = -22.0
	rc_close_btn.offset_top = -14.0
	rc_close_btn.offset_right = 22.0
	rc_close_btn.offset_bottom = 30.0
	rc_wrapper.add_child(rc_close_btn)

	# 8. Parking Full Toast Popup
	_setup_toast_ui()


func _calc_highest_bus_visual_y() -> float:
	var highest_y := 999999.0
	if board_root == null or vehicle_views == null:
		return highest_y
	for vid in vehicle_views:
		var vv: VehicleView = vehicle_views[vid]
		if not is_instance_valid(vv) or not vv.visible:
			continue
		if vv.is_in_parking:
			continue
		
		var tw := 62.0
		var th := 110.0
		for c in vv.get_children():
			if c is Sprite2D and c.texture != null:
				tw = c.texture.get_size().x
				th = c.texture.get_size().y
				break
		
		var hw := tw / 2.0
		var hh := th / 2.0
		var corners = [
			Vector2(-hw, -hh), Vector2(hw, -hh),
			Vector2(hw, hh), Vector2(-hw, hh)
		]
		for corner in corners:
			var world_pt: Vector2 = board_root.transform * (vv.transform * corner)
			highest_y = minf(highest_y, world_pt.y)
			
	return highest_y


func _update_layout(override_vp_size: Vector2 = Vector2.ZERO) -> void:
	if world_root == null:
		return
	var vp := get_viewport()
	var vp_size: Vector2 = override_vp_size if override_vp_size != Vector2.ZERO else (vp.get_visible_rect().size if vp != null else Vector2.ZERO)
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(720, 1280)

	# 1. Determine local bounding sizes
	var track_h = 392.0 # Authoritative track envelope (R=115, border 162px: -196 to +196)
	var parking_h = ParkingSlotView.SLOT_HEIGHT # 94.0 Authoritative ParkingSlotView height
	var board_cells_w = float(controller.level_data.board_size.x) if controller != null and controller.level_data != null else 7.0
	var board_cells_h = float(controller.level_data.board_size.y) if controller != null and controller.level_data != null else 7.0
	var board_local_size = max(board_cells_w, board_cells_h) * CELL_SIZE
	# Rotated 45 deg, scale (1.0, 0.72)
	var board_pixel_w = board_local_size * sqrt(2.0)
	var board_pixel_h = board_pixel_w * 0.72
	
	# 2. Determine required margins and total logical dimensions
	# Top safe area (~110px: TopBar), bottom safe area (~140px: booster bar + padding)
	var screen_safe_w = vp_size.x * 0.94
	var safe_upper_screen_h = (vp_size.y / 2.0) - 110.0
	var safe_lower_screen_h = (vp_size.y / 2.0) - 140.0

	# Ensure we fit parking strip, board clearance, and track system with feeder
	var slot_spacing = 65.0 # MATCHES what we set earlier
	var slots_count: int = controller.level_data.parking_slots_count if controller != null and controller.level_data != null else 4
	var parking_w = float(max(1, slots_count - 1)) * slot_spacing + 35.0
	var board_padded_w = board_pixel_w + 100.0
	var track_system_w = 702.0 # Full track system span (R=115, apex=270, border 162px)
	var required_w = maxf(maxf(parking_w, board_padded_w), track_system_w)
	
	# Minimum essential dimensions for upper and lower screen halves
	var min_gap_tp = 60.0
	var min_corridor = 40.0
	var essential_upper_h = track_h + min_gap_tp + parking_h + min_corridor
	
	var min_sep_to_board = 60.0
	var min_btm_pad = 20.0
	var essential_lower_h = min_sep_to_board + board_pixel_h + min_btm_pad

	var scale_w = screen_safe_w / required_w
	var scale_h_upper = safe_upper_screen_h / (essential_upper_h + 10.0)
	var scale_h_lower = safe_lower_screen_h / (essential_lower_h + 10.0)
	var scale_factor = clampf(minf(scale_w, minf(scale_h_upper, scale_h_lower)), 0.42, 2.20)

	# Apply scale to world root
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO
	
	# In world_root coordinates, local Y = 0.0 corresponds to exact vertical screen center:
	# separator_line_global_y = (vp_size.y / 2.0) + (0.0 * scale_factor) = H / 2.0
	var separator_y: float = 0.0
	
	var half_h = (vp_size.y / 2.0) / scale_factor
	var top_safe_y = -half_h + (110.0 / scale_factor)
	var btm_safe_y = half_h - (140.0 / scale_factor)

	# Distribute extra upper space gracefully above separator line
	var avail_upper_h = -top_safe_y
	var extra_upper_h = maxf(0.0, avail_upper_h - essential_upper_h)
	var gap_tp = clampf(min_gap_tp + extra_upper_h * 0.40, 60.0, 95.0)
	var corridor_to_sep = clampf(min_corridor + extra_upper_h * 0.35, 40.0, 75.0)

	# Position upper elements strictly above separator line (y < 0.0)
	var parking_bottom = -corridor_to_sep
	var parking_y = parking_bottom - (parking_h / 2.0)
	var track_y = parking_y - (parking_h / 2.0) - gap_tp - (track_h / 2.0)

	# Distribute extra lower space gracefully below separator line
	var avail_lower_h = btm_safe_y
	var extra_lower_h = maxf(0.0, avail_lower_h - essential_lower_h)
	var sep_to_board = clampf(min_sep_to_board + extra_lower_h * 0.45, 60.0, 110.0)
	var board_y = sep_to_board + (board_pixel_h / 2.0)

	# Passenger track prominent in upper section
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, track_y)

	# Parking strip positioned lower with clear visual separation
	if parking_root != null:
		parking_root.position = Vector2(0, parking_y)

	# Puzzle board in the lower middle area
	if board_root != null:
		board_root.position = Vector2(0, board_y)
		
	var plat_top = parking_y - (parking_h / 2.0) - 20.0

	if platform_bg != null:
		platform_bg.position = Vector2.ZERO # drawn relative to world_root
		
		# Full screen bounds in local space
		var local_bottom = (vp_size.y / scale_factor) + 1000.0 # extend way down
		
		# Partition gap (where parking bays end and road corridor begins)
		var partition_y = parking_bottom + 10.0
		
		# Deck plateau width (comfortably frames parking slots with padding)
		var deck_w = maxf(500.0, parking_w + 45.0)
		
		# Width needs to cover entire screen width
		var full_w = (vp_size.x / scale_factor) + 200.0
		
		platform_bg.setup_full(plat_top, local_bottom, full_w, partition_y, separator_y, deck_w)

	if passenger_track_bg != null:
		var tr = passenger_track_bg.get_node_or_null("TrackRenderer") as CarJamTrackRenderer
		if tr != null:
			tr.plat_top_local = plat_top - track_y
			tr.queue_redraw()




func _direct_restart() -> void:
	_play_sfx("ui")
	if pause_overlay and pause_overlay.visible:
		pause_overlay.visible = false
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		if gc.current_level_number > 0:
			gc.start_level(gc.current_level_number)
		else:
			gc.goto_scene("res://scenes/main.tscn")

func _on_restart_pressed() -> void:
	_play_sfx("ui")
	_was_paused_before_confirm = get_tree().paused
	get_tree().paused = true
	restart_confirm_overlay.visible = true

func _confirm_restart_yes() -> void:
	if not restart_confirm_overlay.visible: return
	_play_sfx("ui")
	restart_confirm_overlay.visible = false
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc:
		gc.start_level(gc.current_level_number)
	else:
		get_tree().reload_current_scene()

func _confirm_restart_no() -> void:
	if not restart_confirm_overlay.visible: return
	_play_sfx("ui")
	restart_confirm_overlay.visible = false
	get_tree().paused = _was_paused_before_confirm

func _create_procedural_glossy_button(btn_text: String, bg_color: Color, border_color: Color, on_click: Callable, min_size: Vector2 = Vector2(104, 44)) -> Control:
	var wrapper = Control.new()
	wrapper.custom_minimum_size = min_size
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_bottom = 4
	style.border_color = border_color
	style.shadow_color = Color(0,0,0,0.2)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	wrapper.add_child(panel)
	
	var gloss = Panel.new()
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.anchor_bottom = 0.5
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g_style = StyleBoxFlat.new()
	g_style.bg_color = Color(1, 1, 1, 0.3)
	g_style.corner_radius_top_left = 12
	g_style.corner_radius_top_right = 12
	gloss.add_theme_stylebox_override("panel", g_style)
	wrapper.add_child(gloss)
	
	var lbl = Label.new()
	lbl.text = btn_text
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", border_color)
	lbl.add_theme_constant_override("outline_size", 3)
	wrapper.add_child(lbl)
	
	var btn = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.modulate = Color(1,1,1,0.01)
	btn.button_down.connect(func():
		var tw = wrapper.create_tween()
		tw.tween_property(wrapper, "position:y", 3.0, 0.05)
		tw.parallel().tween_property(panel, "theme_override_styles/panel:border_width_bottom", 1, 0.05)
		tw.parallel().tween_property(panel, "theme_override_styles/panel:shadow_size", 0, 0.05)
		tw.parallel().tween_property(panel, "theme_override_styles/panel:shadow_offset", Vector2(0,0), 0.05)
	)
	btn.button_up.connect(func():
		var tw = wrapper.create_tween()
		tw.tween_property(wrapper, "position:y", 0.0, 0.1)
		tw.parallel().tween_property(panel, "theme_override_styles/panel:border_width_bottom", 4, 0.1)
		tw.parallel().tween_property(panel, "theme_override_styles/panel:shadow_size", 3, 0.1)
		tw.parallel().tween_property(panel, "theme_override_styles/panel:shadow_offset", Vector2(0,3), 0.1)
	)
	btn.pressed.connect(on_click)
	wrapper.add_child(btn)
	
	return wrapper

func _setup_toast_ui() -> void:
	if _toast_container != null:
		return
	_toast_container = CenterContainer.new()
	_toast_container.name = "ToastContainer"
	_toast_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_container.offset_left = 0.0
	_toast_container.offset_top = 0.0
	_toast_container.offset_right = 0.0
	_toast_container.offset_bottom = 0.0
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_container.z_index = 10
	if hud != null:
		hud.add_child(_toast_container)
	elif safe_area_root != null:
		safe_area_root.add_child(_toast_container)
	else:
		add_child(_toast_container)

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.visible = false
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.22, 0.94)
	sb.set_corner_radius_all(12)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 2
	sb.border_color = Color(0.95, 0.35, 0.35, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	_toast_panel.add_theme_stylebox_override("panel", sb)
	
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	_toast_panel.add_child(m)
	
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(hb)
	
	var icon_rect = TextureRect.new()
	icon_rect.texture = load("res://assets/ui/icons/warning_icon.svg")
	icon_rect.ignore_texture_size = true
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(16, 16)
	hb.add_child(icon_rect)
	
	var lbl = Label.new()
	lbl.text = "PARKING FULL"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color("fef2f2"))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("outline_size", 2)
	hb.add_child(lbl)
	
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_toast_panel.resized.connect(func():
		if is_instance_valid(_toast_panel):
			_toast_panel.pivot_offset = _toast_panel.size / 2.0
	)
	
	_toast_container.add_child(_toast_panel)

func _show_parking_full_toast() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Strict debounce: if toast is already active or triggered within 1.4s, don't re-trigger or spam
	if (_toast_panel != null and _toast_panel.visible) or (now - _last_toast_time < 1.4):
		return
	_last_toast_time = now

	if _toast_container == null:
		_setup_toast_ui()
		
	if _toast_tween:
		_toast_tween.kill()
		
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.reset_size()
	_toast_panel.pivot_offset = _toast_panel.size / 2.0
	_toast_panel.scale = Vector2(0.92, 0.92)
	
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.10).set_trans(Tween.TRANS_SINE)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var tw_seq = create_tween()
	tw_seq.tween_interval(0.70)
	tw_seq.tween_property(_toast_panel, "modulate:a", 0.0, 0.20).set_trans(Tween.TRANS_SINE)
	tw_seq.tween_callback(func(): _toast_panel.visible = false)

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
	lbl.add_theme_font_size_override("font_size", 12)
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
	var pf: PathFollow2D = p.get("follower", null)
	
	# Preserve exact live position to prevent snapping
	var gpos = pv.global_position
	if pf != null and is_instance_valid(pf):
		pf.remove_child(pv)
		pf.queue_free()
		p["follower"] = null
	if pv.get_parent() != passenger_visuals:
		if pv.get_parent() != null:
			pv.get_parent().remove_child(pv)
		passenger_visuals.add_child(pv)
	pv.global_position = gpos
	
	var target_pos: Vector2
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	var final_local = _get_slot_world_pos(slot_id)
	
	if vv != null and is_instance_valid(vv) and vv.boarding_anchor != null:
		# Use the live global position of the boarding anchor, which is correctly 
		# transformed by the parked vehicle's dynamic scale and orientation.
		target_pos = vv.boarding_anchor.global_position
	else:
		target_pos = transit_layer.to_global(final_local)

	# Doorway fan-in offset to prevent multi-passenger stacking on a single point
	var lane_idx: int = p.get("lane", 0)
	var fan_offset := Vector2((float(lane_idx) - 1.5) * 6.0, 0.0)
	target_pos += fan_offset
	pv.z_index = 100
	
	# -----------------------------------------------------------------
	# ROAD-CONTAINED BOARDING CORRIDOR
	# Funnel through gateway opening into parking apron with zero curb clipping
	#
	# In passenger_track_root space:
	# - Oval track road surface is at y in [50, 180].
	# - Gateway neck opening into parking is between x = -110 and +110.
	# - At y >= 245, the wide platform apron covers all bays (x in [-172, 172]).
	#
	# Waypoints:
	#   W0: Current position on track (gpos)
	#   W1: Gateway neck mouth (y = 190, x clamped to [-80, 80])
	#   W2: Platform apron entry (y = 245, x moving towards slot_x)
	#   W3: Final doorway target (target_pos)
	# -----------------------------------------------------------------
	var p0_local: Vector2 = passenger_track_root.to_local(gpos)
	var tgt_local: Vector2 = passenger_track_root.to_local(target_pos)
	var lane_offset: float = (float(lane_idx) - 1.5) * 7.0

	# W1: Gateway neck mouth (well inside the [-110, 110] neck opening)
	var w1_x: float = clampf(lerpf(p0_local.x, tgt_local.x * 0.3, 0.3) + lane_offset, -75.0, 75.0)
	var w1_local := Vector2(w1_x, 185.0)
	var w1_global: Vector2 = passenger_track_root.to_global(w1_local)

	# W2: Gateway neck exit onto platform apron (still strictly within gateway corridor)
	var plat_y_local: float = 240.0
	if passenger_track_bg != null:
		var tr = passenger_track_bg.get_node_or_null("TrackRenderer") as CarJamTrackRenderer
		if tr != null and tr.plat_top_local > 150.0:
			plat_y_local = tr.plat_top_local
	var w2_x: float = clampf(lerpf(p0_local.x, tgt_local.x * 0.5, 0.5) + lane_offset, -75.0, 75.0)
	var w2_local := Vector2(w2_x, plat_y_local)
	var w2_global: Vector2 = passenger_track_root.to_global(w2_local)

	# W3: Platform apron fan-out (wide grey apron comfortably covers all bays x in [-172, 172])
	var w3_y: float = maxf(plat_y_local + 15.0, tgt_local.y - 15.0)
	var w3_local := Vector2(tgt_local.x + (float(lane_idx) - 1.5) * 5.0, w3_y)
	var w3_global: Vector2 = passenger_track_root.to_global(w3_local)

	# Build smooth Curve2D along the waypoints
	var board_curve := Curve2D.new()
	board_curve.add_point(gpos, Vector2.ZERO, (w1_global - gpos).normalized() * 25.0)
	board_curve.add_point(w1_global, Vector2(0.0, -20.0), Vector2(0.0, 20.0))
	board_curve.add_point(w2_global, Vector2(0.0, -20.0), (w3_global - w2_global).normalized() * 20.0)
	board_curve.add_point(w3_global, Vector2(0.0, -15.0), (target_pos - w3_global).normalized() * 15.0)
	board_curve.add_point(target_pos, Vector2(0.0, -10.0), Vector2.ZERO)

	var travel_dist = board_curve.get_baked_length()
	var flight_duration := clampf(travel_dist / 480.0, 0.18, 0.24)
	
	# Paced lane micro-stagger: Lane 0 steps out first, followed by Lane 1, 2, 3
	var start_delay: float = float(lane_idx) * 0.025
	var overlap_time = flight_duration * 0.70
	var fade_time = flight_duration * 0.30
	
	# Hop animation starts with flight
	var tw_jump = create_tween()
	if start_delay > 0.0:
		tw_jump.tween_interval(start_delay)
	tw_jump.tween_callback(func():
		if is_instance_valid(pv):
			pv.animate_jump(0.0)
	)
	
	var tw = create_tween().set_parallel(true)
	
	var curve_len = board_curve.get_baked_length()
	var path_func = func(t: float):
		if is_instance_valid(pv):
			pv.global_position = board_curve.sample_baked(t * curve_len)
	
	tw.tween_method(path_func, 0.0, 1.0, flight_duration).set_delay(start_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Shrink/fade cleanly during the final entry portion without reparenting scale pop
	var start_pv_scale: Vector2 = pv.scale
	tw.tween_property(pv, "scale", start_pv_scale * 0.6, fade_time).set_delay(start_delay + overlap_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(pv, "modulate:a", 0.0, fade_time).set_delay(start_delay + overlap_time).set_trans(Tween.TRANS_LINEAR)
	
	var token = controller.session_token
	var tw_done = create_tween()
	tw_done.tween_interval(start_delay + flight_duration)
	tw_done.tween_callback(self._on_individual_boarded.bind(p["id"], vehicle_id, p["color_id"], token))

func _on_individual_boarded(pid: int, vehicle_id: int, color_id: String, token: int) -> void:
	if token != controller.session_token:
		return
	var p = all_passengers.get(pid, null)
	if p == null:
		return
	if p.get("state", "") == "BOARDED":
		return # Idempotent rejection of duplicate callback

	# Authoritative commit FIRST
	var committed := controller.commit_boarding(pid, vehicle_id, color_id, token)
	if not committed:
		_rollback_uncommitted_passenger(p, pid)
		return

	# Atomic visual cleanup & capacity grant ONLY after successful commit
	p["state"] = "BOARDED"
	if is_instance_valid(p.get("view")):
		p["view"].queue_free()
		p["view"] = null
	_oval_freed_capacity += 1
	controller.check_terminal_states()

func _rollback_uncommitted_passenger(p: Dictionary, pid: int) -> void:
	if p == null:
		return
	# Restore visual opacity and scale
	if is_instance_valid(p.get("view")):
		var pv: PassengerView = p["view"]
		pv.modulate.a = 1.0
		pv.scale = Vector2.ONE
	p["state"] = "CIRCULATING"
	controller.set_passenger_state(pid, "CIRCULATING")
	# Put back into a circulating row if not already present
	var found := false
	for row in _circulating_rows:
		if row.passengers.has(p):
			found = true
			break
	if not found and not _circulating_rows.is_empty():
		_circulating_rows.back().passengers.append(p)
	print("[QA] Boarding commit rejected for passenger %d; safely rolled back to CIRCULATING." % pid)

func _create_custom_toggle(text: String, icon_path: String, is_on: bool, on_toggle: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(230, 38)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.size = Vector2(24, 24)
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("5c3d2e")) # High contrast chocolate brown (WCAG AAA)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	const PILL_W := 52.0
	const PILL_H := 30.0
	const KNOB := 21.0
	const PAD := 5.0

	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(PILL_W, PILL_H)
	pill.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color("22c55e") if is_on else Color("d1d5db")
	pill_style.set_corner_radius_all(int(PILL_H / 2))
	pill.add_theme_stylebox_override("panel", pill_style)
	
	var t_gloss = Panel.new()
	t_gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t_gloss.anchor_bottom = 0.5
	t_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tg_style = StyleBoxFlat.new()
	tg_style.bg_color = Color(1, 1, 1, 0.4)
	t_gloss.add_theme_stylebox_override("panel", tg_style)
	pill.add_child(t_gloss)
	
	if is_on:
		var shine = ColorRect.new()
		shine.color = Color(1, 1, 1, 0.5)
		shine.rotation_degrees = 25
		shine.size = Vector2(10, 100)
		shine.position = Vector2(-50, -20)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(shine)
		var tw = pill.create_tween().set_loops()
		tw.tween_property(shine, "position:x", 100.0, 1.2).from(-50.0).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(1.0)

	var inside := Control.new()
	inside.set_anchors_preset(Control.PRESET_FULL_RECT)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(inside)

	var knob := Panel.new()
	knob.custom_minimum_size = Vector2(KNOB, KNOB)
	knob.position = Vector2(
		(PILL_W - KNOB - PAD) if is_on else PAD,
		(PILL_H - KNOB) / 2.0
	)
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color.WHITE
	knob_style.set_corner_radius_all(int(KNOB / 2))
	knob_style.border_width_bottom = 2
	knob_style.border_color = Color("e5e7eb")
	knob_style.shadow_color = Color(0, 0, 0, 0.20)
	knob_style.shadow_size = 3
	knob_style.shadow_offset = Vector2(0, 1)
	knob.add_theme_stylebox_override("panel", knob_style)
	inside.add_child(knob)

	var hit := Button.new()
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.offset_left = -10
	hit.offset_top = -10
	hit.offset_right = 10
	hit.offset_bottom = 10
	hit.flat = true
	hit.modulate = Color(1, 1, 1, 0.01)
	pill.add_child(hit)

	var state := {"on": is_on}
	hit.pressed.connect(func():
		_play_sfx("ui")
		state["on"] = not state["on"]
		var on = state["on"]
		pill_style.bg_color = Color("22c55e") if on else Color("9ca3af")
		knob.position.x = (PILL_W - KNOB - PAD) if on else PAD
		on_toggle.call(on)
	)

	var wrap := CenterContainer.new()
	wrap.add_child(pill)
	row.add_child(wrap)
	return row


func _create_close_button(on_close: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44, 44)
	btn.size = Vector2(44, 44)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color("ef4444")
	c_style.set_corner_radius_all(22)
	c_style.shadow_color = Color(0, 0, 0, 0.35)
	c_style.shadow_size = 5
	c_style.shadow_offset = Vector2(0, 3)
	c_style.border_width_bottom = 3
	c_style.border_color = Color("b91c1c")
	btn.add_theme_stylebox_override("normal", c_style)
	
	var c_hover = c_style.duplicate()
	c_hover.bg_color = Color("f87171")
	btn.add_theme_stylebox_override("hover", c_hover)
	
	var c_pressed = c_style.duplicate()
	c_pressed.bg_color = Color("dc2626")
	c_pressed.shadow_size = 1
	c_pressed.shadow_offset = Vector2(0, 1)
	btn.add_theme_stylebox_override("pressed", c_pressed)
	
	var cg = Panel.new()
	cg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cg.anchor_bottom = 0.5
	cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cgs = StyleBoxFlat.new()
	cgs.bg_color = Color(1, 1, 1, 0.35)
	cgs.corner_radius_top_left = 22
	cgs.corner_radius_top_right = 22
	cg.add_theme_stylebox_override("panel", cgs)
	btn.add_child(cg)
	
	var icon = TextureRect.new()
	icon.texture = load("res://assets/ui/icons/close.svg")
	icon.ignore_texture_size = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size = Vector2(18, 18)
	icon.position = Vector2(13, 12)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	
	btn.pivot_offset = Vector2(22, 22)
	btn.button_down.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.05).set_trans(Tween.TRANS_QUAD)
	)
	btn.button_up.connect(func():
		var tw = btn.create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD)
	)
	btn.pressed.connect(func():
		_play_sfx("ui")
		on_close.call()
	)
	return btn
