extends Node2D
class_name CarJamLevel

## Production-quality Car Jam single-level gameplay scene.
## Pure Godot 2D architecture with 2.5D pseudo-3D layered buses,
## exactly 4 parking slots, swept-footprint collision, and ordered passenger queue.


signal level_completed()
signal level_failed()

var _is_level_ending: bool = false

# Metrics
const CELL_SIZE: float = 78.0
const BOARD_Y: float = 720.0
const PARKING_Y: float = 405.0
const PASSENGER_TRACK_Y: float = 195.0
const FUNNEL_Y: float = 315.0

# Colors
const COLOR_WORLD_BG := Color("d2d5e4") # Authoritative background fill sampled directly from swatch 1 (#D2D5E4)
const COLOR_GARDEN_BG := Color("69a827") # Lush vibrant green garden background matching track center opening

# Hierarchy Nodes
var world_root: Node2D
var board_root: Node2D
var board_bg: BoardView
var platform_bg: Node2D
var parking_strip: Node2D
var vehicle_layer: Node2D
var board_effects: Node2D
var garden_bg: GardenBackgroundView

var parking_root: Node2D
var parking_slots_node: Node2D
var parked_vehicles_node: Node2D
var departure_road_y: float = 0.0

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

# Feature C: VIP Slot Booster UI. Created programmatically in _setup_vip_overlay();
# visible only when the controller's vip_available_changed(true) signal fires.
var vip_overlay: Control
var vip_button: TextureButton

# Bottom power-up bar: Arrange (bus-swap) + Jumble (random-permute) + VIP together.
# Created as a separate canvas layer anchored to the bottom of the screen; matches the
# layout seen in user's gameplay video where all 3 boosters sit in a row at the bottom.
var powerup_overlay: Control
var arrange_button: TextureButton
var jumble_button: TextureButton

# Arrange state: when the player has tapped Arrange, they're in "select pair" mode and
# the next two bus taps swap them. We track _arrange_pending + the first picked vid.
var _arrange_pending: bool = false
var _arrange_first_vehicle_id: int = -1

# Per-level star rating row + moves/ideal subtitle on the victory result panel.
# Created lazily by _render_star_row() so a level that fails before the stars signal
# fires never adds stray labels.
var _star_row_label: Label
var _star_subtitle_label: Label
var restart_confirm_overlay: Control
var _was_paused_before_confirm: bool = false

var level_title_label: Label
var result_title_label: Label
var result_btn: TextureButton
var result_btn_label: Label
var result_retry_btn: TextureButton
var result_home_btn: TextureButton
var result_subtitle_label: Label
var result_icon: TextureRect
var _result_outcome: String = ""  # "victory" or "failure" — guards which buttons are shown

var coin_counter_wrapper: PanelContainer
var coin_counter_icon: TextureRect
var coin_balance_label: Label
var reward_badge: PanelContainer
var reward_badge_label: Label
var _session_run_id: String = ""
var _reward_claimed_for_session: bool = false
var _next_pressed: bool = false
var _celebration_tweens: Array[Tween] = []
var _firework_nodes: Array[Node] = []

var _result_panel: PanelContainer
var _result_scrim: ColorRect
var _victory_panel_style: StyleBoxFlat
var _failure_panel_style: StyleBoxFlat
var _failure_tweens: Array[Tween] = []
var _failure_temp_nodes: Array[Node] = []

var _toast_container: CenterContainer
var _toast_panel: PanelContainer
var _toast_tween: Tween
var _last_toast_time: float = -999.0

# Authoritative Controller
var controller: CarJamController
var vehicle_views: Dictionary = {} # int id -> VehicleView
var slot_views: Array[ParkingSlotView] = []

# Strict Passenger State Machine
enum PassengerState {
	PENDING,
	CIRCULATING,
	RESERVED,
	BOARDING,
	BOARDED
}

# Continuous Passenger Track State (4-Across Formation)
class PassengerRow extends RefCounted:
	var row_id: int = 0
	var progress: float = 0.0
	var target_dist: float = 0.0
	var is_feeder: bool = false
	var current_speed: float = 190.0
	var passengers: Array[Dictionary] = [] # {"id": int, "color_id": String, "lane": int, "view": PassengerView, "state": String}

func get_passenger_state(pid: int) -> String:
	var p = all_passengers.get(pid, null)
	return p.get("state", "") if p != null else ""

func set_passenger_state_local(pid: int, new_state: String) -> void:
	var p = all_passengers.get(pid, null)
	if p != null:
		p["state"] = new_state

const LANE_SPACING := 17.5
const LANE_SPACING_CURVE := 16.0
const ROW_SPACING := 29.0
const MIN_ROW_GAP := 28.5
const NUM_LANES := 4
const PASSENGER_SPACING := 17.5
const MAX_INITIAL_LOOP_PASSENGERS := 144
const SLOT_SPACING := 72.0

var passenger_track: Path2D
var feeder_track: Path2D
var all_passengers: Dictionary = {}
var circulating_ids: Array[int] = []
var _feeder_passengers: Array[Dictionary] = []
var _pending_feeder_passengers: Array[Dictionary] = []
var _circulating_rows: Array[PassengerRow] = []
var _feeder_rows: Array[PassengerRow] = []
var _pending_feeder_rows: Array[PassengerRow] = []
var _lead_feeder_committed: bool = false
var _speed_logged: bool = false
var slot_boarding_points: Dictionary = {}
var _platform_start_prog: float = 160.0
var _platform_end_prog: float = 510.0
var _merge_prog: float = 0.0
var _waiting_label: Label
var track_time: float = 0.0
var _last_board_landing_time: float = 0.0
var _oval_freed_capacity: int = 0
var _feeder_starvation_timer: float = 0.0
var _last_starvation_diagnostic: Dictionary = {}
var _vehicle_incoming_runners: Dictionary = {} # vehicle_id -> int
var _runner_spawn_timer: float = 0.0
const RUNNER_SPAWN_INTERVAL: float = 0.035

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
	var curve_fac: float = clampf((absf(center_pos.x) - 75.0) / 30.0, 0.0, 1.0)
	var dynamic_spacing: float = lerpf(LANE_SPACING, LANE_SPACING_CURVE, curve_fac)
	# Natural gentle convergence near gateway neck (x in [-60, 60] and y > 80.0)
	if absf(center_pos.x) < 60.0 and center_pos.y > 80.0:
		var neck_factor: float = clampf(1.0 - (absf(center_pos.x) / 60.0), 0.0, 1.0)
		dynamic_spacing = lerpf(dynamic_spacing, 23.5, neck_factor * 0.25)
	var lane_offset: float = (float(lane) - 1.5) * dynamic_spacing
	return center_pos + normal * lane_offset

func _find_leftmost_matching_slot(color_id: String) -> int:
	if controller == null or controller.parking == null:
		return -1
	for slot_idx in range(slot_views.size()):
		var slot = controller.parking.get_slot(slot_idx)
		if slot == null or slot.state != CarJamParkingManager.SlotState.OCCUPIED or slot.vehicle_id == -1:
			continue
		var v = controller.vehicles.get(slot.vehicle_id, null)
		if v == null or v.state != VehicleModel.VehicleState.PARKED:
			continue
		if v.color_id != color_id:
			continue
		var incoming: int = _vehicle_incoming_runners.get(v.id, 0)
		var remaining_seats: int = v.capacity - v.passenger_occupancy
		if (remaining_seats - incoming) > 0:
			return slot_idx
	return -1

func _process(delta: float) -> void:
	if passenger_track == null or passenger_track.curve == null or controller == null or controller.parking == null: return
	if controller.state != CarJamController.GameState.PLAYING: return
	
	var track_len = passenger_track.curve.get_baked_length()
	track_time += delta
	if not _speed_logged and circulating_ids.size() > 0:
		_speed_logged = true
		print("[QA] Loop length: ", track_len, " px")
		print("[QA] Normal lap: ", track_len / passenger_normal_speed, " s")
		print("[QA] Sprint lap: ", track_len / passenger_sprint_speed, " s")

	# ---------------------------------------------
	# 1. CONTINUOUS FEEDER LOGIC (4-across Rows)
	# ---------------------------------------------
	if feeder_track != null and is_instance_valid(feeder_track) and feeder_track.curve != null:
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
					pv.set_movement_direction(f_pt_info["tangent"])
					all_passengers[p["id"]] = p
					_feeder_passengers.append(p)
					_pending_feeder_passengers.erase(p)
				_feeder_rows.append(next_row)
				
		# B. Dynamic Continuous Feeder Admission Scheduler
		var feeder_stop_pos: float = f_len - 240.0
		
		# 1. Determine how many feeder rows are authorized by freed loop capacity
		var running_cap: int = _oval_freed_capacity
		var authorized_count: int = 0
		for r in _feeder_rows:
			var req: int = r.passengers.size()
			if running_cap >= req:
				authorized_count += 1
				running_cap -= req
			else:
				break
				
		# 2. Advance active feeder rows
		var lead_row_stopped: bool = false
		for j in range(_feeder_rows.size()):
			var f_row = _feeder_rows[j]
			var is_authorized: bool = (j < authorized_count)
			var target_prog: float = feeder_stop_pos
			
			if is_authorized:
				if j == 0:
					target_prog = f_len
					# Signal intent to oncoming traffic when within merge approach zone (45px)
					_lead_feeder_committed = (f_row.progress >= f_len - 45.0)
				else:
					target_prog = _feeder_rows[j - 1].progress - ROW_SPACING
			else:
				var queue_slot: float = feeder_stop_pos - float(j - authorized_count) * ROW_SPACING
				if j == 0:
					target_prog = feeder_stop_pos
				else:
					target_prog = minf(_feeder_rows[j - 1].progress - ROW_SPACING, queue_slot)
			
			var dist_ahead: float = maxf(0.0, target_prog - f_row.progress)
			var speed: float = passenger_normal_speed
			if j > 0:
				var gap_to_prev: float = _feeder_rows[j - 1].progress - f_row.progress
				if gap_to_prev > ROW_SPACING * 1.25:
					speed = passenger_sprint_speed
				elif gap_to_prev < ROW_SPACING * 0.90:
					speed = passenger_normal_speed * 0.85
					
			var dist_moved: float = speed * delta
			dist_moved = minf(dist_moved, dist_ahead)
			f_row.progress += dist_moved
			
			if j == 0 and dist_moved < 0.1 and dist_ahead < 0.5:
				lead_row_stopped = true

		# C. Merge lead feeder row onto main loop if:
		#    1. Lead row is authorized (_oval_freed_capacity >= needed_cap)
		#    2. Lead row has arrived at merge threshold (f_len - 2.0)
		#    3. Merge zone on the oval is clear of conflicting oncoming traffic
		if authorized_count > 0 and not _feeder_rows.is_empty():
			_feeder_starvation_timer += delta
			if _feeder_starvation_timer >= 5.0:
				var lead_r = _feeder_rows.front()
				var wait_reason = "Advancing to merge threshold"
				if lead_r.progress >= f_len - 2.0:
					wait_reason = "Waiting for merge clearance gap in oncoming traffic"
				_last_starvation_diagnostic = {
					"timestamp": track_time,
					"wait_duration": _feeder_starvation_timer,
					"lead_progress": lead_r.progress,
					"dist_to_merge": f_len - lead_r.progress,
					"authorized_count": authorized_count,
					"freed_capacity": _oval_freed_capacity,
					"reason": wait_reason
				}
				_feeder_starvation_timer = 0.0

		if not _feeder_rows.is_empty():
			var lead_row = _feeder_rows.front()
			var needed_cap: int = lead_row.passengers.size()
			if _oval_freed_capacity >= needed_cap and lead_row.progress >= f_len - 2.0:
				var merge_clear := true
				var clearance_buffer: float = ROW_SPACING * 0.85
				for cr in _circulating_rows:
					var d = absf(cr.progress - _merge_prog)
					if d > track_len * 0.5:
						d = track_len - d
					if d < clearance_buffer:
						merge_clear = false
						break
				if merge_clear:
					_feeder_rows.pop_front()
					_lead_feeder_committed = false
					_feeder_starvation_timer = 0.0
					_last_starvation_diagnostic.clear()
					lead_row.progress = _merge_prog
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

		# D. Update positions and animation states of passengers in active feeder rows
		for j in range(_feeder_rows.size()):
			var f_row = _feeder_rows[j]
			var f_pt_info = _get_curve_point_and_normal(feeder_track.curve, f_row.progress, false)
			var is_row_waiting: bool = false
			if j >= authorized_count:
				is_row_waiting = (f_row.progress >= (feeder_stop_pos - float(j - authorized_count) * ROW_SPACING) - 1.0)
			else:
				if j == 0:
					is_row_waiting = lead_row_stopped
			for p in f_row.passengers:
				if p["state"] == "FEEDER" and is_instance_valid(p.get("view")):
					var lpos = _calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], p["lane"])
					p["view"].position = lpos
					p["view"].set_movement_direction(f_pt_info["tangent"])
					p["view"].set_waiting(is_row_waiting)

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

			if dist_ahead < 0.0:
				dist_ahead += track_len

			if dist_ahead > ROW_SPACING * 1.25:
				speed = passenger_sprint_speed
			elif dist_ahead < ROW_SPACING * 0.90:
				speed = passenger_normal_speed * 0.85

		# Trailing row yielding for merging lead feeder row
		if _lead_feeder_committed:
			var d_merge = row.progress - _merge_prog
			if d_merge < 0.0: d_merge += track_len
			var dist_to_merge = track_len - d_merge
			if dist_to_merge >= ROW_SPACING and dist_to_merge <= 85.0:
				var yield_dist = (dist_to_merge - ROW_SPACING) + MIN_ROW_GAP
				dist_ahead = minf(dist_ahead, yield_dist)

		var old_prog = row.progress
		var dist_moved = speed * delta
		var min_gap: float = MIN_ROW_GAP
		if _circulating_rows.size() > 1:
			if dist_ahead <= min_gap:
				dist_moved = 0.0
			else:
				dist_moved = minf(dist_moved, dist_ahead - min_gap)

		# Boarding check at Gate / Platform Zone (bottom straight around x = 0)
		var gate_prog: float = passenger_track.curve.get_closest_offset(Vector2(0, 115))
		var dist_to_gate: float = gate_prog - old_prog
		if dist_to_gate < 0.0: dist_to_gate += track_len
		var reached_gate: bool = (dist_to_gate <= dist_moved + 2.0) or (absf(old_prog - gate_prog) < 12.0)

		if reached_gate:
			var to_board_from_row: Array[Dictionary] = []
			for p in row.passengers:
				if p["state"] == "CIRCULATING":
					var slot_idx: int = _find_leftmost_matching_slot(p["color_id"])
					if slot_idx != -1:
						var slot = controller.parking.get_slot(slot_idx)
						var v = controller.vehicles.get(slot.vehicle_id, null)
						if controller.try_reserve_boarding(p["id"], v.id, p["color_id"], p.get("group_id", -1)):
							_vehicle_incoming_runners[v.id] = _vehicle_incoming_runners.get(v.id, 0) + 1
							_board_circulating_passenger(p, v.id, slot_idx, gate_prog)
							to_board_from_row.append(p)
			for bp in to_board_from_row:
				row.passengers.erase(bp)

		if row.passengers.is_empty():
			empty_rows.append(row)
		else:
			row.progress = fposmod(old_prog + dist_moved, track_len)

	for er in empty_rows:
		_circulating_rows.erase(er)

	# Update visual positions of all circulating passengers
	for row in _circulating_rows:
		var pt_info = _get_curve_point_and_normal(passenger_track.curve, row.progress, true)
		for p in row.passengers:
			if p["state"] == "CIRCULATING" and is_instance_valid(p.get("view")):
				var lpos = _calc_lane_pos(pt_info["pos"], pt_info["normal"], p["lane"])
				p["view"].position = lpos
				p["view"].set_movement_direction(pt_info["tangent"])
				p["view"].set_waiting(false)

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


var _is_initialized: bool = false

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true
	_build_scene_hierarchy()
	_setup_controller()
	_load_current_level()
	_setup_vip_overlay()

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
	garden_bg = GardenBackgroundView.new()
	garden_bg.name = "GardenBackground"
	bg_layer.add_child(garden_bg)
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
	platform_bg.z_index = -3
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
	parking_slots_node.z_index = -1
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
	controller.mystery_revealed.connect(_on_mystery_revealed)
	controller.vip_available_changed.connect(_on_vip_available_changed)
	controller.level_scored.connect(_on_level_scored)

# Feature C: build the VIP booster overlay (Button + Container) and parent it to a
# canvas layer so it floats above the gameplay. Hidden by default — only surfaced
# when the controller's vip_available_changed(true) signal fires.
func _setup_vip_overlay() -> void:
	if vip_overlay != null and is_instance_valid(vip_overlay):
		vip_overlay.queue_free()
	var vip_layer := CanvasLayer.new()
	vip_layer.name = "VIPLayer"
	vip_layer.layer = 25  # Above the gameplay layer; below the pause/result overlays.
	add_child(vip_layer)

	vip_overlay = Control.new()
	vip_overlay.name = "VIPOverlay"
	vip_overlay.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vip_overlay.custom_minimum_size = Vector2(0, 96)
	vip_overlay.offset_top = 24
	vip_overlay.offset_bottom = 120
	vip_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vip_layer.add_child(vip_overlay)

	var vip_panel := PanelContainer.new()
	vip_panel.name = "VIPPanel"
	vip_panel.anchor_left = 0.5
	vip_panel.anchor_right = 0.5
	vip_panel.anchor_top = 0.0
	vip_panel.anchor_bottom = 0.0
	vip_panel.offset_left = -110.0
	vip_panel.offset_right = 110.0
	vip_panel.offset_top = 0.0
	vip_panel.offset_bottom = 78.0
	vip_overlay.add_child(vip_panel)

	var vip_panel_style := StyleBoxFlat.new()
	vip_panel_style.bg_color = Color("facc15")  # gold accent
	vip_panel_style.border_width_left = 3
	vip_panel_style.border_width_top = 3
	vip_panel_style.border_width_right = 3
	vip_panel_style.border_width_bottom = 3
	vip_panel_style.border_color = Color("854d0e")
	vip_panel_style.set_corner_radius_all(14)
	vip_panel_style.shadow_color = Color(0, 0, 0, 0.35)
	vip_panel_style.shadow_size = 6
	vip_panel_style.content_margin_left = 18
	vip_panel_style.content_margin_right = 18
	vip_panel_style.content_margin_top = 10
	vip_panel_style.content_margin_bottom = 10
	vip_panel.add_theme_stylebox_override("panel", vip_panel_style)

	# The VIP button itself is now created in _setup_powerup_overlay() alongside the
	# Arrange + Jumble buttons. The top-level overlay stays (the controller's signal
	# still drives vip_overlay.visible) so external listeners keep working.
	vip_overlay.visible = false

## Handler: controller tells us the VIP booster is available or used. Toggle the overlay.
func _on_vip_available_changed(available: bool) -> void:
	if vip_overlay == null or not is_instance_valid(vip_overlay):
		return
	vip_overlay.visible = available
	if available:
		_play_audio("ui")

## Handler: player tapped the VIP button. Try to extract a stuck matching-color
## parked bus via the controller. If nothing is parked, show a brief toast.
func _on_vip_button_pressed() -> void:
	if controller == null:
		return
	var stuck_bus_id: int = _find_stuck_parked_bus()
	if stuck_bus_id == -1:
		_show_parking_full_toast()
		return
	var ok: bool = controller.try_extract_vip(stuck_bus_id)
	if ok:
		_play_audio("booster")
	else:
		_show_parking_full_toast()

## Resolve the AudioManager autoload and play a sound effect by name. No-op if the
## autoload isn't reachable (e.g., running outside the main scene tree).
func _play_audio(sfx_name: String) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return
	var am = get_tree().root.get_node_or_null("AudioManager")

	if am != null and am.has_method("play"):
		am.call("play", sfx_name)

## Arrange button handler: sets the controller's arrange-pending state. The
## _on_vehicle_tapped handler routes the next two bus taps through _handle_arrange_pick
## to commit the swap. Cancelled by tapping the same bus twice.
func _on_arrange_button_pressed() -> void:
	if not controller.is_arrange_available():
		return
	_arrange_pending = true
	_arrange_first_vehicle_id = -1
	_play_audio("ui")

## Jumble button handler: triggers a random permutation of ON_BOARD buses.
func _on_jumble_button_pressed() -> void:
	if not controller.is_jumble_available():
		return
	if controller.try_jumble_buses():
		_play_audio("booster")
	else:
		# No ON_BOARD buses to permute (e.g. all parked already); surface a toast.
		_show_parking_full_toast()

## Pick any PARKED vehicle whose color matches the queue head color (the "stuck"
## bus the VIP booster is designed to free). Falls back to the first PARKED bus
## if no color match exists — useful in degenerate cases.
func _find_stuck_parked_bus() -> int:
	if controller == null or controller.queue == null:
		return -1
	var head_color: String = controller.queue.get_head_color()
	var first_parked: int = -1
	for vid in controller.vehicles:
		var v = controller.vehicles[vid]
		if v == null:
			continue
		if v.state != VehicleModel.VehicleState.PARKED:
			continue
		if first_parked == -1:
			first_parked = int(vid)
		if head_color != "" and v.color_id == head_color:
			return int(vid)
	return first_parked

## Bottom power-up bar: three buttons in a row mirroring the user's gameplay video.
## Arrange: enters "pick a pair" mode (next two bus taps are swapped). Jumble: random-
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

	# Generate a unique run ID for this gameplay attempt
	_session_run_id = "%d_%d_%d" % [lvl_num, Time.get_ticks_msec(), randi()]
	_reward_claimed_for_session = false
	_next_pressed = false

	# Reset result overlay state for this fresh level run.
	_result_outcome = ""
	_stop_failure_animations()
	_stop_celebration_effects()
	if result_overlay != null:
		result_overlay.visible = false
	if result_btn != null:
		result_btn.visible = false
	if result_retry_btn != null:
		result_retry_btn.visible = false
	if result_home_btn != null:
		result_home_btn.visible = false
	if reward_badge != null:
		reward_badge.visible = false
	if coin_counter_wrapper != null:
		coin_counter_wrapper.visible = false
	if result_subtitle_label != null:
		result_subtitle_label.visible = false
		result_subtitle_label.text = ""
	if result_icon != null:
		result_icon.texture = load("res://assets/ui/icons/trophy.svg")
		result_icon.scale = Vector2.ONE
		result_icon.position = Vector2.ZERO
	if _result_panel != null and _victory_panel_style != null:
		_result_panel.add_theme_stylebox_override("panel", _victory_panel_style)
	if is_inside_tree() and get_tree() != null:
		get_tree().paused = false

	controller.load_level(lvl)
	_setup_visuals(lvl)

func _setup_visuals(lvl: CarJamLevelData) -> void:
	if level_title_label != null:
		level_title_label.text = "Level %d" % lvl.level_id
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
	_lead_feeder_committed = false
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
	var slot_spacing := SLOT_SPACING
	var total_span: float = float(lvl.parking_slots_count - 1) * slot_spacing

	for i in lvl.parking_slots_count:
		var slot_view := ParkingSlotView.new()
		var is_unl: bool = controller.parking.is_slot_unlocked(i) if controller and controller.parking else (i >= 1)
		slot_view.setup(i, is_unl)
		slot_view.rotation_degrees = -22.0
		slot_view.position = Vector2(-total_span / 2.0 + float(i) * slot_spacing, 0)
		parking_slots_node.add_child(slot_view)
		slot_views.append(slot_view)

	# 3. Vehicles
	for vd in lvl.vehicles:
		var vv := VehicleView.new()
		vv.setup(vd.id, vd.code, vd.color_id, vd.direction, vd.capacity, vd.footprint)
		var center_offset = _calc_footprint_center_offset(vd.footprint)
		vv.position = _cell_to_board_local(vd.anchor, lvl.board_size) + center_offset
		# Compensate board_root's 0.72 Y-scaling so buses render with square aspect ratio across all orientations
		var board_scale_y = board_root.scale.y if board_root != null and board_root.scale.y != 0.0 else 0.72
		vv.scale = Vector2(1.0, 1.0 / board_scale_y)
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
	var vehicle_caps: Dictionary = {}
	var total_vehicle_capacity := 0
	if controller != null and controller.level_data != null and controller.level_data.vehicles != null:
		for v in controller.level_data.vehicles:
			vehicle_caps[v.color_id] = vehicle_caps.get(v.color_id, 0) + v.capacity
			total_vehicle_capacity += v.capacity

	var total_counts := {}
	var total_passengers := 0
	var group_rem: Array[int] = []
	for g in groups:
		total_counts[g.color_id] = total_counts.get(g.color_id, 0) + g.initial_count
		total_passengers += g.initial_count
		group_rem.append(g.initial_count)

	# Strictly enforce that total spawned passenger colors match total vehicle capacities
	if total_vehicle_capacity > 0:
		total_counts = vehicle_caps.duplicate()
		total_passengers = total_vehicle_capacity

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
	var pid := 0

	while pid < total_passengers:
		var candidates: Array[String] = []
		for c in colors:
			if remaining[c] > 0 and c != last_color:
				candidates.append(c)
		if candidates.is_empty():
			for c in colors:
				if remaining[c] > 0:
					candidates.append(c)
		if candidates.is_empty():
			break

		var pick_idx := rng.randi() % candidates.size()
		var chosen := candidates[pick_idx]
		
		# Coherent wave length in rows (2 to 4 rows = 8 to 16 passengers, capped by remaining capacity)
		var max_rows = mini(4, int(ceil(float(remaining[chosen]) / float(NUM_LANES))))
		var chosen_rows = 1
		if max_rows >= 2:
			chosen_rows = 2 + (rng.randi() % (max_rows - 1))
		var wave_count = mini(chosen_rows * NUM_LANES, remaining[chosen])

		for _w in wave_count:
			# Map to the earliest matching group with remaining capacity
			var chosen_gid := 0
			for g_i in groups.size():
				if groups[g_i].color_id == chosen and group_rem[g_i] > 0:
					chosen_gid = g_i
					group_rem[g_i] -= 1
					break

			result.append({"id": pid, "color_id": chosen, "group_id": chosen_gid})
			remaining[chosen] -= 1
			pid += 1

		last_color = chosen

	return result

func _init_passenger_track() -> void:
	passenger_track = Path2D.new()
	var h := 63.51 # R=115.0 * 0.552285
	
	# Clean oval curve for TrackRenderer background visual geometry
	var oval_curve := Curve2D.new()
	oval_curve.add_point(Vector2(220, 0), Vector2(0, -h), Vector2(0, h))
	oval_curve.add_point(Vector2(105, 115), Vector2(h, 0), Vector2.ZERO)
	oval_curve.add_point(Vector2(-105, 115), Vector2.ZERO, Vector2(-h, 0))
	oval_curve.add_point(Vector2(-220, 0), Vector2(0, h), Vector2(0, -h))
	oval_curve.add_point(Vector2(-105, -115), Vector2(-h, 0), Vector2.ZERO)
	oval_curve.add_point(Vector2(105, -115), Vector2.ZERO, Vector2(h, 0))
	oval_curve.add_point(Vector2(220, 0), Vector2(0, -h), Vector2(0, h))

	# CONTINUOUS FEEDER TRACK background geometry
	feeder_track = Path2D.new()
	feeder_track.name = "FeederTrack"
	var f_curve := Curve2D.new()
	f_curve.add_point(Vector2(360, -950), Vector2.ZERO, Vector2(-10, 80))
	f_curve.add_point(Vector2(335, -520), Vector2(15, -120), Vector2(-15, 120))
	f_curve.add_point(Vector2(290, -280), Vector2(15, -65), Vector2(-18, 65))
	f_curve.add_point(Vector2(265, -110), Vector2(15, -65), Vector2(-18, 65))
	f_curve.add_point(Vector2(235, 20), Vector2(18, -45), Vector2(-22, 35))

	passenger_track.curve = oval_curve

	_platform_start_prog = oval_curve.get_closest_offset(Vector2(105, 115))
	_platform_end_prog = oval_curve.get_closest_offset(Vector2(-105, 115))
	_merge_prog = oval_curve.get_closest_offset(Vector2(180, 82))
	var merge_pt: Vector2 = oval_curve.sample_baked(_merge_prog)
	f_curve.add_point(merge_pt, Vector2(25, -26), Vector2.ZERO)
	feeder_track.curve = f_curve

	# PREMIUM PLAZA INTEGRATION
	var plaza = preload("res://scripts/gameplay/plaza_environment.gd").new()
	plaza.name = "PlazaEnvironment"
	passenger_track_bg.add_child(plaza)

	# Dedicated background track renderer (z_index = -2) so it NEVER occludes passengers
	var track_renderer = preload("res://scripts/gameplay/track_renderer.gd").new()
	track_renderer.name = "TrackRenderer"
	track_renderer.curve = oval_curve
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
	
	# Precalculate boarding crossing points for all parking slots
	slot_boarding_points.clear()
	var slot_spacing := SLOT_SPACING
	var total_span: float = float(controller.level_data.parking_slots_count - 1) * slot_spacing
	for i in controller.level_data.parking_slots_count:
		var slot_x: float = slot_views[i].position.x if i < slot_views.size() else (-total_span / 2.0 + float(i) * slot_spacing)
		var trig_x: float = clampf(slot_x * 0.35, -55.0, 55.0)
		var closest: float = passenger_track.curve.get_closest_offset(Vector2(trig_x, 115.0))
		slot_boarding_points[i] = closest

	_last_board_landing_time = 0.0
	_oval_freed_capacity = 0
	_vehicle_incoming_runners.clear()
	_runner_spawn_timer = 0.0
	all_passengers.clear()
	circulating_ids.clear()
	_feeder_passengers.clear()
	_pending_feeder_passengers.clear()
	_circulating_rows.clear()
	_feeder_rows.clear()
	_pending_feeder_rows.clear()
	_lead_feeder_committed = false

	# Passenger queue sequence
	var all_queue_p: Array[Dictionary] = []
	if controller != null and controller.level_data != null and controller.level_data.level_id == 1:
		# Authoritative Level 1 specification matching screenshot: 6 groups of 40 = 240 passengers
		# Sequence: Yellow at gate -> Blue on left curve -> Red on top -> Yellow -> Red -> Blue on feeder ramp
		var l1_batches: Array[Dictionary] = [
			{"color": "yellow", "count": 40, "gid": 2},
			{"color": "blue",   "count": 40, "gid": 1},
			{"color": "red",    "count": 40, "gid": 0},
			{"color": "red",    "count": 40, "gid": 3},
			{"color": "blue",   "count": 40, "gid": 4},
			{"color": "yellow", "count": 40, "gid": 5}
		]
		var pid := 0
		for b in l1_batches:
			for _k in b["count"]:
				all_queue_p.append({"id": pid, "color_id": b["color"], "group_id": b["gid"]})
				pid += 1
	else:
		all_queue_p = _build_universal_passenger_queue()
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

	# Main oval starts densely packed (36 rows = 144 passengers)
	var track_len = passenger_track.curve.get_baked_length()
	var initial_rows_count = mini(all_rows.size(), int(MAX_INITIAL_LOOP_PASSENGERS / NUM_LANES))
	var gate_prog: float = passenger_track.curve.get_closest_offset(Vector2(0, 115))

	for r in range(initial_rows_count):
		var row = all_rows[r]
		row.is_feeder = false
		# Row 0 starts at gate (0, 115), Row 1 behind Row 0, etc.
		row.progress = fposmod(gate_prog - float(r) * ROW_SPACING, track_len)
		
		var pt_info = _get_curve_point_and_normal(passenger_track.curve, row.progress, true)
		for p in row.passengers:
			var pv := PassengerView.new()
			pv.setup(p["color_id"], p["id"], p["lane"])
			pv.set_waiting(false)
			pv.set_movement_direction(pt_info["tangent"])
			passenger_visuals.add_child(pv)
			p["view"] = pv
			p["state"] = "CIRCULATING"
			controller.set_passenger_state(p["id"], "CIRCULATING")
			var lpos = _calc_lane_pos(pt_info["pos"], pt_info["normal"], p["lane"])
			pv.position = lpos
			circulating_ids.append(p["id"])
		_circulating_rows.append(row)

	# Remaining rows form a separate dense waiting queue on feeder ramp
	var f_len = feeder_track.curve.get_baked_length()
	var feeder_stop_pos: float = f_len - 240.0 # Queue stop line rests 240px before junction
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
				pv.set_movement_direction(f_pt_info["tangent"])
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
		if not r_pass.is_empty():
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

	var has_boarding_in_flight := false
	for pid in all_passengers:
		var p = all_passengers[pid]
		var st: String = p.get("state", "")
		if st == "RESERVED" or st == "BOARDING":
			has_boarding_in_flight = true
			break

	var is_any_vehicle_in_transit := false
	if transit_layer != null:
		for c in transit_layer.get_children():
			if is_instance_valid(c) and not c.is_queued_for_deletion() and c.visible:
				is_any_vehicle_in_transit = true
				break

	return {
		"circulating_rows": circ_rows,
		"feeder_rows": f_rows,
		"pending_rows": p_rows,
		"oval_freed_capacity": _oval_freed_capacity,
		"lead_feeder_committed": _lead_feeder_committed,
		"starvation_diagnostic": _last_starvation_diagnostic.duplicate(),
		"has_boarding_in_flight": has_boarding_in_flight,
		"is_any_vehicle_in_transit": is_any_vehicle_in_transit
	}

func _board_circulating_passenger(p: Dictionary, vehicle_id: int, slot_idx: int, trigger_prog: float) -> void:
	p["state"] = "RESERVED"
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

func _lock_gameplay_inputs() -> void:
	for vid in vehicle_views.keys():
		if is_instance_valid(vehicle_views[vid]):
			var vv = vehicle_views[vid]
			if vv._touch_area != null:
				vv._touch_area.input_pickable = false

func _on_vehicle_tapped(vehicle_id: int) -> void:
	if _result_outcome != "" or _is_level_ending or controller.state != CarJamController.GameState.PLAYING:
		return
	_play_sfx("select")
	# Arrange / Jumble intercept: when Arrange is pending, taps are interpreted as a
	# 2-pick swap selection instead of normal dispatch.
	if _arrange_pending:
		_handle_arrange_pick(vehicle_id)
		return
	var accepted_ctrl: bool = controller.tap_vehicle(vehicle_id)
	if not accepted_ctrl:
		var vv: VehicleView = vehicle_views.get(vehicle_id, null)
		if vv != null and not vv._is_shaking:
			vv.play_blocked_shake()

## Pick-pair flow for the Arrange booster. First valid pick stores vehicle_id;
## second valid pick triggers try_arrange_swap with both ids and clears pending state.
func _handle_arrange_pick(vehicle_id: int) -> void:
	var v: VehicleModel = controller.vehicles.get(vehicle_id, null)
	if v == null or v.state != VehicleModel.VehicleState.ON_BOARD:
		# Only ON_BOARD vehicles can be rearranged; shake and stay pending.
		var vv: VehicleView = vehicle_views.get(vehicle_id, null)
		if vv != null:
			vv.play_blocked_shake()
		_play_audio("blocked")
		return
	if _arrange_first_vehicle_id == -1:
		_arrange_first_vehicle_id = vehicle_id
		_play_audio("select")
		return
	if _arrange_first_vehicle_id == vehicle_id:
		# Same bus tapped twice — treat as cancel and reset.
		_arrange_pending = false
		_arrange_first_vehicle_id = -1
		return
	# Second pick — perform the swap and exit arrange mode.
	var a: int = _arrange_first_vehicle_id
	var b: int = vehicle_id
	var ok: bool = controller.try_arrange_swap(a, b)
	_arrange_pending = false
	_arrange_first_vehicle_id = -1
	if ok:
		_play_audio("booster")
	else:
		_show_parking_full_toast()

func _on_vehicle_dispatch_started(vehicle_id: int, slot_id: int, corridor: Array[Vector2i]) -> void:
	_play_sfx("move")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv == null:
		return
	vv.is_dispatched = true
	vv.set_arrow_visible(false)
	if vv._touch_area != null:
		vv._touch_area.input_pickable = false

	# Reparent to TransitLayer preserving global position
	var global_start := vv.global_position
	var global_rot := vv.global_rotation
	var orig_global_scale := vv.global_scale
	vv.get_parent().remove_child(vv)
	transit_layer.add_child(vv)
	vv.global_position = global_start
	vv.global_rotation = global_rot
	vv.global_scale = orig_global_scale

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

	var slot_rot: float = slot_views[slot_id].rotation if slot_id < slot_views.size() else deg_to_rad(-22.0)

	# CORRIDOR WAYPOINT — positioned along the -22.0° entry axis directly behind the
	# assigned parking bay. The vehicle drives along its puzzle exit corridor, curves
	# cleanly through this approach waypoint, and drives into the bay aligned at -22.0°.
	var approach_offset := Vector2(0.0, ParkingSlotView.SLOT_HEIGHT + 16.0).rotated(slot_rot)
	var corridor_pos := target_slot_pos + approach_offset

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
		final_scale_vec,
		bus_movement_duration_multiplier,
		slot_rot
	)

func _on_vehicle_parked(vehicle_id: int, slot_id: int) -> void:
	_play_sfx("parking")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null and slot_id < slot_views.size():
		vv.set_arrow_visible(false)
		# Reparent to ParkedVehicles
		var global_xform := vv.global_transform
		vv.get_parent().remove_child(vv)
		parked_vehicles_node.add_child(vv)
		vv.global_transform = global_xform
		slot_views[slot_id].set_state(CarJamParkingManager.SlotState.OCCUPIED)

	_recover_boarding_for_slot(slot_id)

func _recover_boarding_for_slot(_slot_id: int) -> void:
	# Handled uniformly in strict FIFO order at exit gate in _process
	pass

func _on_vehicle_blocked(vehicle_id: int, blocker_id: int) -> void:
	_play_sfx("blocked")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		vv.play_blocked_shake()
	if blocker_id != -1:
		var blocker_vv: VehicleView = vehicle_views.get(blocker_id, null)
		if blocker_vv != null:
			blocker_vv.play_blocked_shake()

# Feature B handler: mystery reveal animation. The controller has already flipped
# is_mystery=false on the model; we drive the visual "?" fade-out on the matching view.
func _on_mystery_revealed(vehicle_id: int) -> void:
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null and is_instance_valid(vv):
		vv.reveal_mystery()

# Scoring handler: render the 3-tier star row above the title when a level completes.
# Stored locally so the result panel can re-read it if dismissed + recalled.
var _last_level_stars: int = 0
var _last_level_moves: int = 0
var _last_level_ideal_moves: int = 0

func _on_level_scored(stars: int, move_count: int, ideal_moves: int) -> void:
	_last_level_stars = stars
	_last_level_moves = move_count
	_last_level_ideal_moves = ideal_moves
	# The actual rendering happens inside _show_result_panel once the result overlay is up.
	# Keeping the storage here ensures scores are preserved across the panel reveal/pop.

func _on_boarding_started(vehicle_id: int, _color_id: String, _count: int, _slot_id: int) -> void:
	_play_sfx("board")
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv != null:
		var v_model: VehicleModel = controller.vehicles.get(vehicle_id, null)
		if v_model != null:
			vv.set_occupancy(v_model.passenger_occupancy)
		vv.play_boarding_pop()

func _on_vehicle_filled(vehicle_id: int, slot_id: int) -> void:
	print("[QA %d] Bus %d boarding completed." % [Time.get_ticks_msec(), vehicle_id])
	var vv: VehicleView = vehicle_views.get(vehicle_id, null)
	if vv == null:
		return

	_play_sfx("depart")

	# Reparent to transit_layer preserving exact global transform so vehicle operates
	# in world_root space (same coordinate frame as dispatch) with zero coordinate jump
	if transit_layer != null and vv.get_parent() != transit_layer:
		var gx := vv.global_transform
		if vv.get_parent() != null:
			vv.get_parent().remove_child(vv)
		transit_layer.add_child(vv)
		vv.global_transform = gx

	vv.z_index = 200

	var slot_pos := _get_slot_world_pos(slot_id)
	var slot_rot: float = slot_views[slot_id].rotation if slot_id < slot_views.size() else 0.0
	var road_y: float = departure_road_y
	if is_zero_approx(road_y):
		road_y = slot_pos.y + 110.0

	VehicleMovement.animate_departure(
		vv,
		slot_pos,
		controller.session_token,
		controller,
		vehicle_id,
		slot_id,
		bus_movement_duration_multiplier,
		slot_rot,
		road_y
	)

func _on_vehicle_departed(vehicle_id: int, slot_id: int) -> void:
	if slot_id < slot_views.size():
		slot_views[slot_id].set_state(CarJamParkingManager.SlotState.EMPTY)
	if is_instance_valid(vehicle_views.get(vehicle_id, null)):
		var vv = vehicle_views[vehicle_id]
		if vv.get_parent() != null:
			vv.get_parent().remove_child(vv)
		vv.queue_free()
	_re_evaluate_waiting_queues()

func _re_evaluate_waiting_queues() -> void:
	# Re-evaluate all currently docked buses to claim newly accessible circulating passengers
	for i in range(slot_views.size()):
		var slot = controller.parking.get_slot(i)
		if slot != null and slot.state == CarJamParkingManager.SlotState.OCCUPIED and slot.vehicle_id != -1:
			_recover_boarding_for_slot(i)

func _on_parking_updated() -> void:
	for i in slot_views.size():
		var slot := controller.parking.get_slot(i)
		if slot != null:
			slot_views[i].set_unlocked(slot.is_unlocked)
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
	_is_level_ending = true
	_lock_gameplay_inputs()
	_stop_failure_animations()
	_play_sfx("victory")
	level_completed.emit()

	if _result_panel != null and _victory_panel_style != null:
		_result_panel.add_theme_stylebox_override("panel", _victory_panel_style)
	if _result_scrim != null:
		_result_scrim.color = Color(0, 0, 0, 0.8)

	var gc = get_tree().root.get_node_or_null("GameController")
	var current_num: int = 1
	if gc != null:
		current_num = int(gc.current_level_number)
	var next_num: int = current_num + 1

	# 1. Authoritative Currency Award (Approved +50 Coins for all completed levels)
	var award_amount: int = 50
	var old_coins: int = 0
	var new_coins: int = award_amount
	var save_mgr = get_tree().root.get_node_or_null("SaveManager")
	if save_mgr != null:
		old_coins = save_mgr.get_coins()
		if not _reward_claimed_for_session:
			var awarded: bool = save_mgr.award_level_completion_reward(current_num, _session_run_id, award_amount)
			if awarded:
				_reward_claimed_for_session = true
		new_coins = save_mgr.get_coins()

		# Persist legitimate completion — but never unlock levels on a failure path.
		if current_num == 1:
			save_mgr.set_level_1_done(true)
		if gc != null and gc.has_level(next_num):
			save_mgr.unlock_level(next_num)

	if result_icon != null:
		result_icon.texture = load("res://assets/ui/icons/trophy.svg")
		result_icon.scale = Vector2.ONE
		result_icon.position = Vector2.ZERO

	result_title_label.text = "GREAT JOB!" if current_num == 1 else ("LEVEL %d CLEAR!" % current_num)
	result_title_label.add_theme_color_override("font_color", Color("facc15"))
	result_title_label.scale = Vector2.ONE
	result_title_label.rotation = 0.0

	# Ensure score and moves are available before rendering stars
	if _last_level_moves == 0 and controller != null:
		_last_level_moves = controller.move_count
		var ideal: int = controller.level_data.ideal_moves if controller.level_data != null else 0
		_last_level_ideal_moves = ideal
		var _st: int = 1
		if ideal > 0:
			if _last_level_moves <= ideal:
				_st = 3
			elif _last_level_moves <= int(ceil(float(ideal) * 1.5)):
				_st = 2
		_last_level_stars = _st

	# Star row (1..3 earned based on move_count vs ideal_moves).
	_render_star_row()

	# Show reward badge
	if reward_badge != null:
		reward_badge.visible = true
	if reward_badge_label != null:
		reward_badge_label.text = "+%d" % award_amount

	# Configure the next-level button based on actual authored levels.
	if gc != null and gc.has_level(next_num):
		result_btn_label.text = "NEXT"
		result_btn.visible = true
		result_subtitle_label.visible = false
		result_subtitle_label.text = ""
	else:
		# No further level — don't pretend the player can advance.
		result_btn.visible = false
		result_subtitle_label.text = "More Levels Coming Soon"
		result_subtitle_label.visible = true

	# STRICT NON-BREAK: Victory screen contains ONLY ONE action button: NEXT.
	# Failure-only and home buttons are hidden on victory.
	if result_retry_btn != null:
		result_retry_btn.visible = false
	if result_home_btn != null:
		result_home_btn.visible = false

	result_overlay.visible = true

	# Start celebratory fireworks, flying coins and balance roll
	_start_victory_celebration(old_coins, new_coins)

## Draws 3 fixed star slots under the title, coloring earned stars gold and the rest
## grey. Uses unicode star characters (★ filled, ☆ empty) for portability.
func _render_star_row() -> void:
	var label: Label = _star_row_label
	if label == null:
		label = Label.new()
		label.name = "StarRow"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 56)
		label.add_theme_color_override("font_color", Color("facc15"))
		label.add_theme_color_override("font_outline_color", Color("0f172a"))
		label.add_theme_constant_override("outline_size", 4)
		result_overlay.add_child(label)
		_star_row_label = label
	var st: int = maxi(0, mini(3, _last_level_stars))
	var row_str: String = ""
	for i in 3:
		row_str += "★" if i < st else "☆"
		row_str += "  " if i < 2 else ""
	label.text = row_str
	var tl_size: Vector2 = result_title_label.size if result_title_label != null else Vector2(0, 0)
	var tl_y: float = result_title_label.position.y if result_title_label != null else 100.0
	label.custom_minimum_size = Vector2(result_overlay.size.x, 60.0)
	label.position = Vector2(0.0, tl_y + tl_size.y + 20.0)
	# Subtitle showing moves vs ideal
	var sub_label: Label = _star_subtitle_label
	if sub_label == null:
		sub_label = Label.new()
		sub_label.name = "StarSubtitle"
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 22)
		sub_label.add_theme_color_override("font_color", Color("fef3c7"))
		result_overlay.add_child(sub_label)
		_star_subtitle_label = sub_label
	if _last_level_ideal_moves > 0:
		sub_label.text = "Moves: %d  /  Ideal: %d" % [_last_level_moves, _last_level_ideal_moves]
	else:
		sub_label.text = "Moves: %d" % _last_level_moves
	sub_label.custom_minimum_size = Vector2(result_overlay.size.x, 30.0)
	sub_label.position = Vector2(0.0, label.position.y + 65.0)

func _on_puzzle_failed() -> void:
	# Guard: failure flow runs once per session.
	if _result_outcome == "failure":
		return
	if _result_outcome == "victory":
		return
	_result_outcome = "failure"
	_is_level_ending = true
	_lock_gameplay_inputs()
	_stop_celebration_effects()
	_stop_failure_animations()
	_play_sfx("failure")
	level_failed.emit()

	# Dismiss any active toast immediately so it doesn't overlap failure popup
	if _toast_panel != null:
		if _toast_tween != null and _toast_tween.is_valid():
			_toast_tween.kill()
		_toast_panel.visible = false

	# 1. Switch panel to alarm theme (Requirement 1)
	if _result_panel != null and _failure_panel_style != null:
		_result_panel.add_theme_stylebox_override("panel", _failure_panel_style)

	# 2. Setup labels and icons
	result_title_label.text = "OUT OF SPACE!"
	result_title_label.add_theme_color_override("font_color", Color("ef4444"))

	if result_icon != null:
		result_icon.texture = load("res://assets/ui/icons/warning_icon.svg")

	# Hide the victory-only progression action and reward elements.
	result_btn.visible = false
	if reward_badge != null:
		reward_badge.visible = false
	if coin_counter_wrapper != null:
		coin_counter_wrapper.visible = false
	result_subtitle_label.text = "No parking spaces left!"
	result_subtitle_label.visible = true
	result_retry_btn.visible = true
	if result_home_btn != null:
		result_home_btn.visible = true

	result_overlay.visible = true

	# 3. Start failure animations & audio
	_start_failure_animations()

func _start_failure_animations() -> void:
	# 1. RED PULSING SCRIM (Requirement 4)
	if _result_scrim != null:
		_result_scrim.color = Color(0.18, 0.02, 0.02, 0.55)
		var tw_scrim := create_tween().set_loops()
		tw_scrim.tween_property(_result_scrim, "color", Color(0.24, 0.03, 0.03, 0.85), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_scrim.tween_property(_result_scrim, "color", Color(0.14, 0.02, 0.02, 0.55), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_failure_tweens.append(tw_scrim)

	# 2. TITLE TEXT ANIMATION (Requirement 3)
	if result_title_label != null:
		if result_title_label.size.x > 0:
			result_title_label.pivot_offset = result_title_label.size / 2.0
		else:
			result_title_label.pivot_offset = Vector2(126, 18)
		result_title_label.scale = Vector2(0.6, 0.6)
		result_title_label.rotation = 0.0
		var tw_punch := create_tween()
		tw_punch.tween_property(result_title_label, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_punch.tween_property(result_title_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_failure_tweens.append(tw_punch)

		var tw_wobble := create_tween().set_loops()
		var rad_3deg := deg_to_rad(3.0)
		tw_wobble.tween_property(result_title_label, "rotation", rad_3deg, 0.083).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_wobble.tween_property(result_title_label, "rotation", -rad_3deg, 0.166).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_wobble.tween_property(result_title_label, "rotation", 0.0, 0.083).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_failure_tweens.append(tw_wobble)

	# 3. WARNING ICON ANIMATION (Requirement 2)
	if result_icon != null:
		result_icon.position = Vector2.ZERO
		result_icon.scale = Vector2.ONE
		result_icon.pivot_offset = Vector2(32, 32)

		var tw_icon_shake := create_tween().set_loops()
		tw_icon_shake.tween_property(result_icon, "position:x", 4.0, 0.035).set_trans(Tween.TRANS_SINE)
		tw_icon_shake.tween_property(result_icon, "position:x", -4.0, 0.07).set_trans(Tween.TRANS_SINE)
		tw_icon_shake.tween_property(result_icon, "position:x", 0.0, 0.035).set_trans(Tween.TRANS_SINE)
		_failure_tweens.append(tw_icon_shake)

		var tw_icon_scale := create_tween().set_loops()
		tw_icon_scale.tween_property(result_icon, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_icon_scale.tween_property(result_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_failure_tweens.append(tw_icon_scale)

	# 4. SUBTITLE FLASH (Requirement 8)
	if result_subtitle_label != null:
		result_subtitle_label.add_theme_color_override("font_color", Color.WHITE)
		var tw_sub := create_tween().set_loops()
		tw_sub.tween_property(result_subtitle_label, "theme_override_colors/font_color", Color("fca5a5"), 0.165).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_sub.tween_property(result_subtitle_label, "theme_override_colors/font_color", Color.WHITE, 0.165).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_failure_tweens.append(tw_sub)

	# 5. SLOT OVERLAY (Requirement 5)
	_spawn_slot_block_overlays()

	# 6. BUS SHAKE (Requirement 6)
	for vid in vehicle_views:
		var vv: VehicleView = vehicle_views[vid]
		if is_instance_valid(vv) and vv.is_in_parking:
			vv.play_angry_shake()

	# 7. AUDIO ALARM LOOP (Requirement 7)
	if is_inside_tree() and get_tree() != null:
		var audio_timer := get_tree().create_timer(0.4)
		audio_timer.timeout.connect(func():
			if _result_outcome == "failure" and result_overlay != null and result_overlay.visible:
				var cur_am = get_tree().root.get_node_or_null("AudioManager") if (is_inside_tree() and get_tree() != null) else null
				if cur_am != null and cur_am.has_method("play_alarm_loop"):
					cur_am.play_alarm_loop()
		)

func _spawn_slot_block_overlays() -> void:
	if parking_slots_node == null or controller == null or controller.parking == null:
		return
	var cross_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/ui/icons/close.svg"):
		cross_tex = load("res://assets/ui/icons/close.svg")

	for i in slot_views.size():
		var slot = controller.parking.get_slot(i)
		if slot != null:
			var slot_st = slot.state
			var is_blocked = (slot_st == CarJamParkingManager.SlotState.OCCUPIED 
				or slot_st == CarJamParkingManager.SlotState.RESERVED 
				or slot_st == CarJamParkingManager.SlotState.DEPARTING)
			if is_blocked and i < slot_views.size():
				var slot_v: ParkingSlotView = slot_views[i]
				var x_node := Node2D.new()
				x_node.position = slot_v.position
				x_node.z_index = 30
				x_node.scale = Vector2.ZERO

				if cross_tex != null:
					var spr := Sprite2D.new()
					spr.texture = cross_tex
					spr.modulate = Color("ef4444")
					spr.scale = Vector2(1.5, 1.5)
					x_node.add_child(spr)
				else:
					var drawer := Node2D.new()
					drawer.draw.connect(func():
						drawer.draw_line(Vector2(-16, -16), Vector2(16, 16), Color("ef4444"), 4.0)
						drawer.draw_line(Vector2(16, -16), Vector2(-16, 16), Color("ef4444"), 4.0)
					)
					x_node.add_child(drawer)

				parking_slots_node.add_child(x_node)
				_failure_temp_nodes.append(x_node)

				var tw_x := create_tween()
				tw_x.tween_property(x_node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw_x.tween_property(x_node, "scale", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw_x.tween_callback(func():
					_failure_temp_nodes.erase(x_node)
					if is_instance_valid(x_node):
						x_node.queue_free()
				)
				_failure_tweens.append(tw_x)

func _stop_failure_animations() -> void:
	for tw in _failure_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_failure_tweens.clear()

	for n in _failure_temp_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_failure_temp_nodes.clear()

	var am = get_tree().root.get_node_or_null("AudioManager") if (is_inside_tree() and get_tree() != null) else null
	if am != null and am.has_method("stop_alarm_loop"):
		am.stop_alarm_loop()

	if result_title_label != null:
		result_title_label.scale = Vector2.ONE
		result_title_label.rotation = 0.0
	if result_icon != null:
		result_icon.scale = Vector2.ONE
		result_icon.position = Vector2.ZERO
	if result_subtitle_label != null:
		result_subtitle_label.add_theme_color_override("font_color", Color("475569"))
	if _result_scrim != null:
		_result_scrim.color = Color(0, 0, 0, 0.8)

func _on_result_next_pressed() -> void:
	# Defensive: if the user somehow taps this button outside a victory state,
	# do nothing rather than silently advancing levels.
	if _result_outcome != "victory":
		return
	if _next_pressed:
		return
	_next_pressed = true
	_cleanup_level_tweens()
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc != null:
		var next_num: int = gc.current_level_number + 1
		if gc.has_level(next_num):
			gc.start_level(next_num)
		else:
			# Final authored level: replay level when player taps REPLAY
			gc.start_level(gc.current_level_number)

func _on_result_retry_pressed() -> void:
	if _result_outcome != "failure":
		return
	_cleanup_level_tweens()
	_play_sfx("ui")
	get_tree().paused = false
	var gc = get_tree().root.get_node_or_null("GameController")
	if gc != null:
		gc.start_level(gc.current_level_number)
	else:
		get_tree().reload_current_scene()

func _exit_tree() -> void:
	_cleanup_level_tweens()

func _cleanup_level_tweens() -> void:
	_stop_celebration_effects()
	_stop_failure_animations()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
		_toast_tween = null
	for vid in vehicle_views.keys():
		if is_instance_valid(vehicle_views[vid]):
			var vv = vehicle_views[vid]
			if vv._shake_tween != null and vv._shake_tween.is_valid():
				vv._shake_tween.kill()
			if vv._badge_tween != null and vv._badge_tween.is_valid():
				vv._badge_tween.kill()
			if vv._pop_tween != null and vv._pop_tween.is_valid():
				vv._pop_tween.kill()

func _stop_celebration_effects() -> void:
	for tw in _celebration_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_celebration_tweens.clear()

	for n in _firework_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_firework_nodes.clear()

func _format_number(n: int) -> String:
	var s := str(abs(n))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	if n < 0:
		res = "-" + res
	return res

func _start_victory_celebration(old_coins: int, new_coins: int) -> void:
	_stop_celebration_effects()

	if coin_counter_wrapper != null:
		coin_counter_wrapper.visible = true
		coin_counter_wrapper.scale = Vector2(0.8, 0.8)
		var ctw = create_tween()
		ctw.tween_property(coin_counter_wrapper, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_celebration_tweens.append(ctw)
	if coin_balance_label != null:
		coin_balance_label.text = _format_number(old_coins)

	if _result_panel != null:
		_result_panel.scale = Vector2(0.85, 0.85)
		_result_panel.pivot_offset = _result_panel.size * 0.5
		var ptw = create_tween()
		ptw.tween_property(_result_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_celebration_tweens.append(ptw)

	if result_icon != null:
		result_icon.scale = Vector2(0.6, 0.6)
		var itw = create_tween()
		itw.tween_interval(0.1)
		itw.tween_property(result_icon, "scale", Vector2(1.25, 1.25), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		itw.tween_property(result_icon, "scale", Vector2.ONE, 0.15)
		_celebration_tweens.append(itw)

	if reward_badge != null:
		reward_badge.scale = Vector2.ZERO
		var rtw = create_tween()
		rtw.tween_interval(0.2)
		rtw.tween_property(reward_badge, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rtw.tween_property(reward_badge, "scale", Vector2.ONE, 0.15)
		_celebration_tweens.append(rtw)

	# Trigger staggered colorful celebratory fireworks bursts
	var bursts := [
		{"pos_ratio": Vector2(0.22, 0.36), "color": Color("facc15"), "delay": 0.08},
		{"pos_ratio": Vector2(0.78, 0.33), "color": Color("38bdf8"), "delay": 0.26},
		{"pos_ratio": Vector2(0.18, 0.54), "color": Color("ec4899"), "delay": 0.44},
		{"pos_ratio": Vector2(0.82, 0.56), "color": Color("a855f7"), "delay": 0.62},
		{"pos_ratio": Vector2(0.50, 0.22), "color": Color("fb923c"), "delay": 0.80}
	]
	for b in bursts:
		var ftw = create_tween()
		ftw.tween_interval(b.delay)
		ftw.tween_callback(func():
			if _result_outcome == "victory" and result_overlay != null and result_overlay.visible:
				_spawn_firework_burst(b.pos_ratio, b.color)
		)
		_celebration_tweens.append(ftw)

	# Launch flying coin animation at 0.5s
	var ltw = create_tween()
	ltw.tween_interval(0.5)
	ltw.tween_callback(func():
		if _result_outcome == "victory" and result_overlay != null and result_overlay.visible:
			_launch_coin_flight_animation(old_coins, new_coins)
	)
	_celebration_tweens.append(ltw)

func _spawn_firework_burst(pos_ratio: Vector2, burst_color: Color) -> void:
	if result_overlay == null or not is_inside_tree():
		return
	var vp_rect := get_viewport().get_visible_rect()
	var spawn_pos := Vector2(vp_rect.size.x * pos_ratio.x, vp_rect.size.y * pos_ratio.y)

	_play_sfx("firework")

	var emitter := CPUParticles2D.new()
	emitter.position = spawn_pos
	emitter.emitting = true
	emitter.one_shot = true
	emitter.explosiveness = 0.95
	emitter.lifetime = 0.9
	emitter.amount = 28
	emitter.direction = Vector2.UP
	emitter.spread = 180.0
	emitter.gravity = Vector2(0, 180.0)
	emitter.initial_velocity_min = 100.0
	emitter.initial_velocity_max = 240.0
	emitter.scale_amount_min = 3.5
	emitter.scale_amount_max = 6.5
	emitter.color = burst_color

	# Add behind the center dialog so fireworks explode around it
	if _result_scrim != null:
		var scrim_idx = _result_scrim.get_index()
		result_overlay.add_child(emitter)
		result_overlay.move_child(emitter, scrim_idx + 1)
	else:
		result_overlay.add_child(emitter)
		result_overlay.move_child(emitter, 0)

	_firework_nodes.append(emitter)

	var cleanup_tw = create_tween()
	cleanup_tw.tween_interval(1.1)
	cleanup_tw.tween_callback(func():
		if is_instance_valid(emitter):
			_firework_nodes.erase(emitter)
			emitter.queue_free()
	)
	_celebration_tweens.append(cleanup_tw)

func _launch_coin_flight_animation(old_coins: int, new_coins: int) -> void:
	if result_overlay == null or not is_inside_tree():
		if coin_balance_label != null:
			coin_balance_label.text = _format_number(new_coins)
		return

	var start_pos: Vector2 = Vector2(360, 400)
	if reward_badge != null and reward_badge.is_inside_tree():
		start_pos = reward_badge.global_position + reward_badge.size * 0.5

	var target_pos: Vector2 = Vector2(40, 40)
	if coin_counter_icon != null and coin_counter_icon.is_inside_tree():
		target_pos = coin_counter_icon.global_position + coin_counter_icon.size * 0.5

	var coin_tex = load("res://assets/ui/icons/coin.svg")
	var total_coins := 7
	for i in range(total_coins):
		var delay: float = float(i) * 0.065
		var coin_tw = create_tween()
		coin_tw.tween_interval(delay)
		coin_tw.tween_callback(func():
			if _result_outcome != "victory" or not is_inside_tree() or result_overlay == null:
				return
			var coin_sprite := TextureRect.new()
			coin_sprite.texture = coin_tex
			coin_sprite.custom_minimum_size = Vector2(24, 24)
			coin_sprite.ignore_texture_size = true
			coin_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coin_sprite.pivot_offset = Vector2(12, 12)
			coin_sprite.global_position = start_pos - Vector2(12, 12)
			coin_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			result_overlay.add_child(coin_sprite)
			_firework_nodes.append(coin_sprite)

			# Calculate quadratic control point for natural arc
			var mid: Vector2 = (start_pos + target_pos) * 0.5
			var dir: Vector2 = (target_pos - start_pos).normalized()
			var perp: Vector2 = Vector2(-dir.y, dir.x)
			var arc_dist: float = randf_range(35.0, 75.0) * (1.0 if randf() > 0.5 else -1.0)
			var ctrl: Vector2 = mid + perp * arc_dist

			var fly_tw = create_tween()
			fly_tw.tween_method(func(t: float):
				if is_instance_valid(coin_sprite):
					var p := (1.0 - t) * (1.0 - t) * start_pos + 2.0 * (1.0 - t) * t * ctrl + t * t * target_pos
					coin_sprite.global_position = p - Vector2(12, 12)
					coin_sprite.scale = Vector2.ONE * (1.0 + sin(t * PI) * 0.3)
			, 0.0, 1.0, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

			fly_tw.tween_callback(func():
				if is_instance_valid(coin_sprite):
					_firework_nodes.erase(coin_sprite)
					coin_sprite.queue_free()

				_play_sfx("coin")

				# Punch counter icon
				if coin_counter_icon != null and is_instance_valid(coin_counter_icon):
					coin_counter_icon.scale = Vector2(1.28, 1.28)
					var p_tw = create_tween()
					p_tw.tween_property(coin_counter_icon, "scale", Vector2.ONE, 0.12)
					_celebration_tweens.append(p_tw)

				# Update roll label
				var fraction: float = float(i + 1) / float(total_coins)
				var roll_val: int = int(round(lerp(float(old_coins), float(new_coins), fraction)))
				if coin_balance_label != null and is_instance_valid(coin_balance_label):
					coin_balance_label.text = _format_number(roll_val)
			)
			_celebration_tweens.append(fly_tw)
		)
		_celebration_tweens.append(coin_tw)

	# Ensure authoritative final number settled at end of animation
	var final_tw = create_tween()
	final_tw.tween_interval(0.065 * total_coins + 0.55)
	final_tw.tween_callback(func():
		if coin_balance_label != null and is_instance_valid(coin_balance_label):
			coin_balance_label.text = _format_number(new_coins)
	)
	_celebration_tweens.append(final_tw)

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

		# Wire the existing premium booster button to the controller-side logic for
		# VIP / Arrange / Jumble. Each is single-use per level; the button stays in the
		# same row so the player's existing BoosterBar UI gets real behavior.
		match b_info["name"]:
			"VIP":
				vip_button = btn
				btn.pressed.connect(_on_vip_button_pressed)
			"Arrange":
				arrange_button = btn
				btn.pressed.connect(_on_arrange_button_pressed)
			"Jumble":
				jumble_button = btn
				btn.pressed.connect(_on_jumble_button_pressed)
		
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
	_result_scrim = res_bg

	# Top-left Coin Balance Pill (Requirement 4)
	coin_counter_wrapper = PanelContainer.new()
	coin_counter_wrapper.name = "ResultCoinCounter"
	coin_counter_wrapper.anchor_left = 0.0
	coin_counter_wrapper.anchor_top = 0.0
	coin_counter_wrapper.anchor_right = 0.0
	coin_counter_wrapper.anchor_bottom = 0.0
	coin_counter_wrapper.offset_left = 24.0
	coin_counter_wrapper.offset_top = 28.0
	coin_counter_wrapper.visible = false

	var coin_pill_style := StyleBoxFlat.new()
	coin_pill_style.bg_color = Color(0.08, 0.10, 0.15, 0.92) # sleek dark glossy slate
	coin_pill_style.corner_radius_top_left = 20
	coin_pill_style.corner_radius_top_right = 20
	coin_pill_style.corner_radius_bottom_left = 20
	coin_pill_style.corner_radius_bottom_right = 20
	coin_pill_style.border_width_left = 2
	coin_pill_style.border_width_top = 2
	coin_pill_style.border_width_right = 2
	coin_pill_style.border_width_bottom = 3
	coin_pill_style.border_color = Color("f59e0b") # warm gold border
	coin_pill_style.content_margin_left = 12
	coin_pill_style.content_margin_right = 16
	coin_pill_style.content_margin_top = 6
	coin_pill_style.content_margin_bottom = 6
	coin_pill_style.shadow_color = Color(0, 0, 0, 0.4)
	coin_pill_style.shadow_size = 10
	coin_pill_style.shadow_offset = Vector2(0, 3)
	coin_counter_wrapper.add_theme_stylebox_override("panel", coin_pill_style)

	var coin_hbox := HBoxContainer.new()
	coin_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_hbox.add_theme_constant_override("separation", 8)
	coin_counter_wrapper.add_child(coin_hbox)

	coin_counter_icon = TextureRect.new()
	coin_counter_icon.texture = load("res://assets/ui/icons/coin.svg")
	coin_counter_icon.custom_minimum_size = Vector2(28, 28)
	coin_counter_icon.ignore_texture_size = true
	coin_counter_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_counter_icon.pivot_offset = Vector2(14, 14)
	coin_hbox.add_child(coin_counter_icon)

	coin_balance_label = Label.new()
	coin_balance_label.text = "0"
	coin_balance_label.add_theme_font_size_override("font_size", 20)
	coin_balance_label.add_theme_color_override("font_color", Color("fef08a")) # bright warm gold
	coin_balance_label.add_theme_color_override("font_outline_color", Color("451a03"))
	coin_balance_label.add_theme_constant_override("outline_size", 4)
	coin_hbox.add_child(coin_balance_label)

	result_overlay.add_child(coin_counter_wrapper)

	var res_center := CenterContainer.new()
	res_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(res_center)

	var res_panel := PanelContainer.new()
	res_panel.custom_minimum_size = Vector2(300, 330)
	_result_panel = res_panel

	# Create a warm glowing panel style specifically for the victory screen
	_victory_panel_style = StyleBoxFlat.new()
	_victory_panel_style.bg_color = Color("fffdf5") # warm white
	_victory_panel_style.corner_radius_top_left = 32
	_victory_panel_style.corner_radius_top_right = 32
	_victory_panel_style.corner_radius_bottom_left = 32
	_victory_panel_style.corner_radius_bottom_right = 32
	_victory_panel_style.shadow_color = Color(1.0, 0.78, 0.25, 0.40) # rich golden celebration glow
	_victory_panel_style.shadow_size = 28
	_victory_panel_style.shadow_offset = Vector2(0, 6)
	_victory_panel_style.border_width_left = 3
	_victory_panel_style.border_width_top = 3
	_victory_panel_style.border_width_right = 3
	_victory_panel_style.border_width_bottom = 6
	_victory_panel_style.border_color = Color("f59e0b")

	# Create a darker alarm-themed panel style specifically for the failure screen (Requirement 1)
	_failure_panel_style = StyleBoxFlat.new()
	_failure_panel_style.bg_color = Color("1f1b2e") # deep charcoal background
	_failure_panel_style.corner_radius_top_left = 32
	_failure_panel_style.corner_radius_top_right = 32
	_failure_panel_style.corner_radius_bottom_left = 32
	_failure_panel_style.corner_radius_bottom_right = 32
	_failure_panel_style.shadow_color = Color(0.937, 0.267, 0.267, 0.45) # red #ef4444 outer glow
	_failure_panel_style.shadow_size = 30
	_failure_panel_style.shadow_offset = Vector2(0, 4)
	_failure_panel_style.border_width_bottom = 4 # 4px red bottom border
	_failure_panel_style.border_color = Color("ef4444")

	res_panel.add_theme_stylebox_override("panel", _victory_panel_style)
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
	
	var icon_box := CenterContainer.new()
	icon_box.custom_minimum_size = Vector2(72, 72)
	header_vbox.add_child(icon_box)

	result_icon = TextureRect.new()
	result_icon.texture = load("res://assets/ui/icons/trophy.svg")
	result_icon.ignore_texture_size = true
	result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_icon.custom_minimum_size = Vector2(64, 64)
	result_icon.pivot_offset = Vector2(32, 32)
	icon_box.add_child(result_icon)
	
	result_title_label = Label.new()
	result_title_label.text = "LEVEL CLEAR!"
	result_title_label.add_theme_font_size_override("font_size", 28)
	result_title_label.add_theme_color_override("font_color", Color("4a2810"))
	result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title_label.pivot_offset = Vector2(126, 18)
	header_vbox.add_child(result_title_label)
	
	# --- Reward Badge (+50 COINS) ---
	reward_badge = PanelContainer.new()
	reward_badge.custom_minimum_size = Vector2(180, 50)
	var rb_style := StyleBoxFlat.new()
	rb_style.bg_color = Color("fef3c7") # warm amber / gold badge
	rb_style.corner_radius_top_left = 25
	rb_style.corner_radius_top_right = 25
	rb_style.corner_radius_bottom_left = 25
	rb_style.corner_radius_bottom_right = 25
	rb_style.border_width_left = 2
	rb_style.border_width_top = 2
	rb_style.border_width_right = 2
	rb_style.border_width_bottom = 4
	rb_style.border_color = Color("f59e0b")
	rb_style.shadow_color = Color(0.96, 0.62, 0.04, 0.3)
	rb_style.shadow_size = 12
	rb_style.shadow_offset = Vector2(0, 3)
	rb_style.content_margin_left = 16
	rb_style.content_margin_right = 18
	rb_style.content_margin_top = 6
	rb_style.content_margin_bottom = 6
	reward_badge.add_theme_stylebox_override("panel", rb_style)
	reward_badge.pivot_offset = Vector2(90, 25)

	var rb_hbox := HBoxContainer.new()
	rb_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	rb_hbox.add_theme_constant_override("separation", 10)
	reward_badge.add_child(rb_hbox)

	var rb_coin := TextureRect.new()
	rb_coin.texture = load("res://assets/ui/icons/coin.svg")
	rb_coin.custom_minimum_size = Vector2(32, 32)
	rb_coin.ignore_texture_size = true
	rb_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rb_coin.pivot_offset = Vector2(16, 16)
	rb_hbox.add_child(rb_coin)

	reward_badge_label = Label.new()
	reward_badge_label.text = "+50"
	reward_badge_label.add_theme_font_size_override("font_size", 24)
	reward_badge_label.add_theme_color_override("font_color", Color("78350f"))
	reward_badge_label.add_theme_color_override("font_outline_color", Color("fef3c7"))
	reward_badge_label.add_theme_constant_override("outline_size", 2)
	rb_hbox.add_child(reward_badge_label)

	var rb_center := CenterContainer.new()
	rb_center.add_child(reward_badge)
	res_vbox.add_child(rb_center)

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
	l2_lbl.text = "NEXT"
	l2_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	l2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l2_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	retry_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	
	# --- Button 2: Home (Failure only) ---
	var res_btn_home := TextureButton.new()
	res_btn_home.texture_normal = load("res://assets/ui/settings_buttons/home_normal.svg")
	res_btn_home.texture_pressed = load("res://assets/ui/settings_buttons/home_pressed.svg")
	res_btn_home.ignore_texture_size = true
	res_btn_home.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	res_btn_home.custom_minimum_size = Vector2(160, 56)
	res_btn_home.visible = false
	
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
		_stop_failure_animations()
		_play_sfx("ui")
		get_tree().paused = false
		var gc = get_tree().root.get_node_or_null("GameController")
		if gc:
			gc.goto_scene("res://scenes/main.tscn")
	)
	btn_vbox.add_child(res_btn_home)
	result_home_btn = res_btn_home

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
	
	# 2. Determine Screen Space Allocation
	# User request: Lower horizontal divider line to create ample clearance below slots/buses,
	# and shift upper section upward.
	var screen_safe_w = vp_size.x * 0.94
	var total_top_screen_h = vp_size.y * 0.44
	var total_btm_screen_h = vp_size.y * 0.56

	# Top safe margin (~75px for TopBar), bottom safe margin (~115px for BoosterBar)
	var safe_upper_screen_h = total_top_screen_h - 75.0
	var safe_lower_screen_h = total_btm_screen_h - 115.0

	# Ensure we fit parking strip, board clearance, and track system with feeder
	var slot_spacing = SLOT_SPACING
	var slots_count: int = controller.level_data.parking_slots_count if controller != null and controller.level_data != null else 4
	var parking_w = float(max(1, slots_count - 1)) * slot_spacing + 35.0
	var board_padded_w = board_pixel_w + 60.0
	var track_system_w = 640.0
	var required_w = maxf(maxf(parking_w, board_padded_w), track_system_w)

	# Essential heights: generous grey platform apron (105px) below parking slots
	var min_gap_tp = 22.0 # Platform throat gap to passenger track
	var min_band_h = 105.0 # Platform grey band below parking slots (generous margin beneath buses)
	var essential_upper_h = track_h + min_gap_tp + parking_h + min_band_h + 10.0
	var min_sep_to_board = 40.0
	var min_btm_pad = 20.0
	var essential_lower_h = min_sep_to_board + board_pixel_h + min_btm_pad

	var scale_w = screen_safe_w / required_w
	var scale_h_upper = safe_upper_screen_h / (essential_upper_h + 10.0)
	var scale_h_lower = safe_lower_screen_h / (essential_lower_h + 10.0)
	var scale_factor = clampf(minf(scale_w, minf(scale_h_upper, scale_h_lower)), 0.38, 2.20)

	# Apply scale to world root
	world_root.scale = Vector2(scale_factor, scale_factor)
	world_root.position = Vector2.ZERO

	var half_h = (vp_size.y / 2.0) / scale_factor
	var _top_safe_y = -half_h + (75.0 / scale_factor)
	var btm_safe_y = half_h - (115.0 / scale_factor)

	# In world_root coordinates, local Y = 0.0 corresponds to vertical screen center (50%).
	# 44% from top of screen means global Y = 0.44 * H.
	# Converting global Y to world_root local Y:
	# Y_local = (0.44 * H - 0.50 * H) / scale_factor = -0.06 * (H / scale_factor)
	var divider_y: float = -0.06 * (vp_size.y / scale_factor)

	# Upper elements: occupy the top 44% (between top_safe_y and divider_y)
	# Platform band bottom rests cleanly at divider_y (the 44% line):
	var band_h = min_band_h
	var partition_y = divider_y - band_h
	var parking_bottom = partition_y - 12.0
	var parking_y = parking_bottom - (parking_h / 2.0)
	var track_bottom = parking_y - (parking_h / 2.0) - min_gap_tp
	var track_y = track_bottom - (track_h / 2.0)
	var plat_top = parking_y - (parking_h / 2.0) - 18.0
	var separator_y = divider_y
	departure_road_y = divider_y - 58.5 # Centerline of the grey platform roadway apron

	# Lower elements: centered inside the 60% bottom space (between divider_y and btm_safe_y)
	var avail_lower_h = btm_safe_y - divider_y
	var board_y = divider_y + (avail_lower_h / 2.0)

	# Passenger track prominent in upper section
	if passenger_track_root != null:
		passenger_track_root.position = Vector2(0, track_y)

	# Parking strip positioned lower with clear visual separation
	if parking_root != null:
		parking_root.position = Vector2(0, parking_y)

	# Puzzle board in the lower middle area
	if board_root != null:
		board_root.position = Vector2(0, board_y)

	if platform_bg != null:
		platform_bg.position = Vector2.ZERO # drawn relative to world_root
		
		# Full screen bounds in local space
		var local_bottom = (vp_size.y / scale_factor) + 1000.0 # extend way down
		
		# Deck plateau width (comfortably frames parking slots matching user red guides)
		var deck_w = maxf(570.0, parking_w + 120.0)
		
		# Width needs to cover entire screen width
		var visible_w = vp_size.x / scale_factor
		var full_w = visible_w + 200.0
		
		var track_bottom_y = track_y + 188.0
		platform_bg.setup_full(plat_top, local_bottom, full_w, partition_y, separator_y, deck_w, visible_w, track_bottom_y, parking_y, parking_h)

	# Responsive Feeder Track Extension:
	# Calculate the top-right offscreen coordinate in passenger_track_root's local space
	var top_local_y: float = -half_h - track_y
	var feeder_top_y: float = minf(top_local_y - 120.0, -950.0)
	var feeder_top_x: float = maxf(360.0, 245.0 + (-110.0 - feeder_top_y) * 0.30)
	_update_feeder_curve(Vector2(feeder_top_x, feeder_top_y))

	if passenger_track_bg != null:
		var track_rend = passenger_track_bg.get_node_or_null("TrackRenderer") as CarJamTrackRenderer
		if track_rend != null:
			track_rend.plat_top_local = plat_top - track_y
			track_rend.queue_redraw()

	if garden_bg != null:
		var divider_screen_y = 0.44 * vp_size.y
		var track_screen_y = (vp_size.y / 2.0) + (track_y * scale_factor)
		garden_bg.update_layout(vp_size, track_screen_y, scale_factor, divider_screen_y)

	if coin_counter_wrapper != null:
		var safe_top: float = 28.0
		if DisplayServer.has_method("get_display_safe_area"):
			var safe_rect = DisplayServer.get_display_safe_area()
			if safe_rect.position.y > 0:
				safe_top = maxf(28.0, safe_rect.position.y + 8.0)
		coin_counter_wrapper.offset_top = safe_top
		coin_counter_wrapper.offset_left = 24.0

func _update_feeder_curve(p0: Vector2) -> void:
	if feeder_track == null or passenger_track == null or passenger_track.curve == null:
		return
	var old_len: float = feeder_track.curve.get_baked_length() if feeder_track.curve != null else 0.0
	var f_curve := Curve2D.new()
	var out_handle_len := (Vector2(335, -520) - p0).length() * 0.35
	var out_dir := (Vector2(335, -520) - p0).normalized()
	f_curve.add_point(p0, Vector2.ZERO, out_dir * out_handle_len)
	f_curve.add_point(Vector2(335, -520), Vector2(15, -120), Vector2(-15, 120))
	f_curve.add_point(Vector2(290, -280), Vector2(15, -65), Vector2(-18, 65))
	f_curve.add_point(Vector2(265, -110), Vector2(15, -65), Vector2(-18, 65))
	f_curve.add_point(Vector2(235, 20), Vector2(18, -45), Vector2(-22, 35))
	var merge_pt: Vector2 = passenger_track.curve.sample_baked(_merge_prog)
	f_curve.add_point(merge_pt, Vector2(25, -26), Vector2.ZERO)
	feeder_track.curve = f_curve
	var new_len: float = f_curve.get_baked_length()

	# If feeder rows already exist, shift them by the change in track length so they maintain their exact distance to the merge junction
	if old_len > 0.0 and absf(new_len - old_len) > 0.1 and not _feeder_rows.is_empty():
		var delta := new_len - old_len
		for row in _feeder_rows:
			row.progress = maxf(0.0, row.progress + delta)
			var f_pt_info = _get_curve_point_and_normal(feeder_track.curve, row.progress, false)
			for p in row.passengers:
				var pv = p.get("view")
				if pv != null and is_instance_valid(pv):
					pv.position = _calc_lane_pos(f_pt_info["pos"], f_pt_info["normal"], p["lane"])
					pv.set_movement_direction(f_pt_info["tangent"])

	if passenger_track_bg != null:
		var track_rend = passenger_track_bg.get_node_or_null("TrackRenderer") as CarJamTrackRenderer
		if track_rend != null:
			track_rend.feeder_curve = f_curve
			track_rend.queue_redraw()

func restart_level() -> void:
	_load_current_level()

func _direct_restart() -> void:
	_stop_failure_animations()
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


func _animate_individual_boarding(p: Dictionary, vehicle_id: int, slot_id: int, _exact_prog: float) -> void:
	p["state"] = "BOARDING"
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
	var fan_offset := Vector2((float(lane_idx) - 1.5) * 8.0, 0.0)
	target_pos += fan_offset
	pv.z_index = 100
	
	# -----------------------------------------------------------------
	# ROAD-CONTAINED BOARDING CORRIDOR
	# Funnel through gateway opening into parking apron with zero curb clipping
	#
	# In passenger_track_root space:
	# - Oval track road surface is at y in [50, 177].
	# - Gateway throat opening is between x in [-95, 95] down to y = 197.
	# - Safe corridor with 27px margin: x in [-68, 68].
	# - Platform apron expands below y = 215.
	# -----------------------------------------------------------------
	var p0_local: Vector2 = passenger_track_root.to_local(gpos)
	var tgt_local: Vector2 = passenger_track_root.to_local(target_pos)
	var lane_offset: float = (float(lane_idx) - 1.5) * 10.0

	var plat_y_local: float = 197.0
	if passenger_track_bg != null:
		var track_rend = passenger_track_bg.get_node_or_null("TrackRenderer") as CarJamTrackRenderer
		if track_rend != null and track_rend.plat_top_local > 150.0:
			plat_y_local = track_rend.plat_top_local

	# W1: Gateway neck mouth (y = 165, x safely inside [-36, 36])
	var w1_x: float = clampf(lerpf(p0_local.x, tgt_local.x * 0.25, 0.4) + lane_offset, -36.0, 36.0)
	var w1_local := Vector2(w1_x, 165.0)
	var w1_global: Vector2 = passenger_track_root.to_global(w1_local)

	# W2: Gateway throat center (y = plat_y_local = 197, x safely inside [-36, 36])
	var w2_x: float = clampf(lerpf(w1_x, tgt_local.x * 0.35, 0.3), -36.0, 36.0)
	var w2_local := Vector2(w2_x, plat_y_local)
	var w2_global: Vector2 = passenger_track_root.to_global(w2_local)

	# W3: Gateway throat exit into platform apron (y = plat_y_local + 18, safely inside [-42, 42])
	var w3_x: float = clampf(lerpf(w2_x, tgt_local.x * 0.5, 0.4), -42.0, 42.0)
	var w3_local := Vector2(w3_x, plat_y_local + 18.0)
	var w3_global: Vector2 = passenger_track_root.to_global(w3_local)

	# W4: Apron fan-out towards parking slot
	var w4_y: float = maxf(plat_y_local + 35.0, tgt_local.y - 15.0)
	var w4_local := Vector2(tgt_local.x + (float(lane_idx) - 1.5) * 8.0, w4_y)
	var w4_global: Vector2 = passenger_track_root.to_global(w4_local)

	# Smooth curve strictly confined to grey road surfaces
	var board_curve := Curve2D.new()
	board_curve.add_point(gpos, Vector2.ZERO, (w1_global - gpos).normalized() * 18.0)
	board_curve.add_point(w1_global, Vector2(0.0, -15.0), Vector2(0.0, 15.0))
	board_curve.add_point(w2_global, Vector2(0.0, -15.0), Vector2(0.0, 15.0))
	board_curve.add_point(w3_global, Vector2(0.0, -12.0), (w4_global - w3_global).normalized() * 15.0)
	board_curve.add_point(w4_global, Vector2(0.0, -12.0), (target_pos - w4_global).normalized() * 12.0)
	board_curve.add_point(target_pos, Vector2(0.0, -10.0), Vector2.ZERO)

	var travel_dist = board_curve.get_baked_length()
	var flight_duration := clampf(travel_dist / 480.0, 0.18, 0.24)
	
	# Paced lane micro-stagger: Lane 0 steps out first, followed by Lane 1, 2, 3
	var start_delay: float = float(lane_idx) * 0.035
	var overlap_time = flight_duration * 0.70
	var fade_time = flight_duration * 0.30
	
	# Hop animation starts with flight
	var tw_jump = pv.create_tween()
	if start_delay > 0.0:
		tw_jump.tween_interval(start_delay)
	tw_jump.tween_callback(func():
		if is_instance_valid(pv):
			pv.animate_jump(0.0)
	)
	
	var tw = pv.create_tween().set_parallel(true)
	
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
	_vehicle_incoming_runners[vehicle_id] = maxi(0, _vehicle_incoming_runners.get(vehicle_id, 0) - 1)
	_oval_freed_capacity += 1
	controller.check_terminal_states()

func _rollback_uncommitted_passenger(p: Dictionary, pid: int) -> void:
	if p == null:
		return
	if p.has("vehicle_id"):
		var vid: int = p["vehicle_id"]
		_vehicle_incoming_runners[vid] = maxi(0, _vehicle_incoming_runners.get(vid, 0) - 1)
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
	controller.check_terminal_states()

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

	var pill_center := CenterContainer.new()
	pill_center.add_child(pill)
	row.add_child(pill_center)
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
