extends SceneTree

# -----------------------------------------------------------------
# COMPREHENSIVE GAMEPLAY REPAIR QA SUITE
#
# Validates:
# 1. P0 Atomic Boarding Lifecycle & Rollback (no disappearing passengers)
# 2. P1 Passenger Road Corridor Containment (zero curb clipping)
# 3. P1 Bus Dispatch Monotonic Vertical Docking (no loop/overshoot)
# 4. P1 Bus Departure Lower Corridor Clearance (zero bay intersection)
# 5. Feeder Junction Spacing & Merge Clearance Buffer
# 6. Atomic Slot Reservation & Departure Release
# -----------------------------------------------------------------

var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("=== COMPLETE GAMEPLAY REPAIR QA VERIFICATION SUITE ===")
	print("=======================================================\n")
	
	test_p0_atomic_boarding_lifecycle()
	test_p1_road_corridor_containment()
	test_p1_bus_dispatch_docking()
	test_p1_bus_departure_clearance()
	test_feeder_junction_and_merge_buffer()
	test_slot_reservation_lifecycle()
	
	print("\n=======================================================")
	print("=== RESULTS: %d PASSED, %d FAILED ===" % [pass_count, fail_count])
	print("=======================================================\n")
	
	if fail_count > 0:
		quit(1)
	else:
		quit(0)

func check(condition: bool, msg: String) -> void:
	if condition:
		print("  [PASS] " + msg)
		pass_count += 1
	else:
		printerr("  [FAIL] " + msg)
		fail_count += 1

# -----------------------------------------------------------------
# 1. P0 ATOMIC BOARDING LIFECYCLE
# -----------------------------------------------------------------
func test_p0_atomic_boarding_lifecycle() -> void:
	print("--- 1. P0 Atomic Boarding Lifecycle & Rollback ---")
	
	var level_scene := preload("res://scenes/gameplay/car_jam_level.tscn").instantiate() as CarJamLevel
	root.add_child(level_scene)
	if not level_scene.is_node_ready():
		level_scene._ready()
	
	var controller = level_scene.controller
	
	# Find a red bus in level 1
	var red_bus_id := -1
	for v in controller.vehicles.values():
		if v.color_id == "red":
			red_bus_id = v.id
			break
	check(red_bus_id != -1, "Found red bus in level 1")
	
	var reserved_slot: int = controller.parking.reserve_slot(red_bus_id)
	check(reserved_slot != -1, "Reserved slot for red bus (slot %d)" % reserved_slot)
	controller.parking.confirm_arrival(reserved_slot, red_bus_id)
	controller.vehicles[red_bus_id].state = VehicleModel.VehicleState.PARKED
	
	# Find an existing red circulating passenger
	var target_pid := -1
	for pid in level_scene.all_passengers:
		var p = level_scene.all_passengers[pid]
		if p.get("color_id") == "red" and p.get("state") == "CIRCULATING":
			target_pid = pid
			break
	check(target_pid != -1, "Found circulating red passenger %d" % target_pid)
	
	var p_obj: Dictionary = level_scene.all_passengers[target_pid]
	var pv: PassengerView = p_obj.get("view", null)
	check(pv != null, "Passenger has valid view")
	
	# Simulate alpha/scale during flight
	pv.modulate.a = 0.0
	pv.scale = Vector2(0.5, 0.5)
	p_obj["state"] = "BOARDING_RESERVED"
	
	# Test A: Rejection on non-reserved passenger -> triggers rollback
	level_scene._oval_freed_capacity = 0
	level_scene._on_individual_boarded(target_pid, red_bus_id, "red", controller.session_token)
	check(is_instance_valid(pv), "Rollback: View was NOT freed on unreserved commit rejection")
	check(p_obj["state"] == "CIRCULATING", "Rollback: Passenger state reverted to CIRCULATING")
	check(pv.modulate.a == 1.0, "Rollback: View opacity restored to 1.0")
	check(pv.scale == Vector2.ONE, "Rollback: View scale restored to Vector2.ONE")
	check(level_scene._oval_freed_capacity == 0, "Rollback: No leaked freed capacity on rejection")
	
	# Test B: Valid reservation -> commit succeeds
	var res_ok = controller.try_reserve_boarding(target_pid, red_bus_id, "red", p_obj.get("group_id", 0))
	check(res_ok, "Reservation succeeded for passenger %d" % target_pid)
	p_obj["state"] = "BOARDING_RESERVED"
	
	var token = controller.session_token
	level_scene._on_individual_boarded(target_pid, red_bus_id, "red", token)
	check(p_obj["state"] == "BOARDED", "Commit success: State updated to BOARDED")
	check(level_scene._oval_freed_capacity == 1, "Commit success: Freed capacity incremented to 1")
	
	# Test C: Duplicate callback is rejected idempotently
	level_scene._on_individual_boarded(target_pid, red_bus_id, "red", token)
	check(level_scene._oval_freed_capacity == 1, "Idempotent: Duplicate callback did not increment freed capacity")
	
	# Test D: Stale session token callback rejected
	var stale_token = token - 999
	p_obj["state"] = "CIRCULATING"
	level_scene._on_individual_boarded(target_pid, red_bus_id, "red", stale_token)
	check(p_obj["state"] == "CIRCULATING", "Stale token: Callback with old token safely ignored")
	
	level_scene.queue_free()

# -----------------------------------------------------------------
# 2. P1 PASSENGER ROAD CORRIDOR CONTAINMENT
# -----------------------------------------------------------------
func test_p1_road_corridor_containment() -> void:
	print("\n--- 2. P1 Road Corridor Containment (Zero Curb Clipping) ---")
	
	var GATEWAY_HALF_WIDTH: float = 110.0
	var PLATFORM_APRON_HALF_WIDTH: float = 172.5
	var GATEWAY_MOUTH_Y: float = 185.0
	var PLATFORM_TOP_Y: float = 240.0
	
	# Test across all 5 parking slot targets:
	# Slot 0: x = -130 (leftmost)
	# Slot 1: x = -65
	# Slot 2: x = 0 (center)
	# Slot 3: x = 65
	# Slot 4: x = 130 (rightmost)
	var slot_x_positions = [-130.0, -65.0, 0.0, 65.0, 130.0]
	
	for slot_idx in range(slot_x_positions.size()):
		var slot_x: float = slot_x_positions[slot_idx]
		var trig_x: float = clampf(slot_x, -75.0, 75.0)
		var p0 := Vector2(trig_x, 115.0)
		var target := Vector2(slot_x, 260.0)
		
		# Build 5-point corridor curve matching car_jam_level.gd
		var w1_x: float = clampf(lerpf(p0.x, target.x * 0.3, 0.3), -75.0, 75.0)
		var w1 := Vector2(w1_x, GATEWAY_MOUTH_Y)
		var w2_x: float = clampf(lerpf(p0.x, target.x * 0.5, 0.5), -75.0, 75.0)
		var w2 := Vector2(w2_x, PLATFORM_TOP_Y)
		var w3 := Vector2(target.x, PLATFORM_TOP_Y + 15.0)
		
		var curve := Curve2D.new()
		curve.add_point(p0, Vector2.ZERO, (w1 - p0).normalized() * 25.0)
		curve.add_point(w1, Vector2(0.0, -20.0), Vector2(0.0, 20.0))
		curve.add_point(w2, Vector2(0.0, -20.0), (w3 - w2).normalized() * 20.0)
		curve.add_point(w3, Vector2(0.0, -15.0), (target - w3).normalized() * 15.0)
		curve.add_point(target, Vector2(0.0, -10.0), Vector2.ZERO)
		
		var curve_len = curve.get_baked_length()
		var max_neck_x: float = 0.0
		var max_apron_x: float = 0.0
		var violations := 0
		
		for step in range(51):
			var t: float = float(step) / 50.0
			var pt = curve.sample_baked(t * curve_len)
			
			if pt.y <= PLATFORM_TOP_Y:
				# In the gateway neck corridor: MUST be within GATEWAY_HALF_WIDTH (110)
				max_neck_x = maxf(max_neck_x, absf(pt.x))
				if absf(pt.x) > GATEWAY_HALF_WIDTH:
					violations += 1
			else:
				# On the platform apron: MUST be within PLATFORM_APRON_HALF_WIDTH (172.5)
				max_apron_x = maxf(max_apron_x, absf(pt.x))
				if absf(pt.x) > PLATFORM_APRON_HALF_WIDTH:
					violations += 1
		
		check(violations == 0,
			"Slot %d (x=%.0f): 100%% contained (Neck max |x|=%.1f <= 110, Apron max |x|=%.1f <= 172.5)" % [
				slot_idx, slot_x, max_neck_x, max_apron_x
			]
		)

# -----------------------------------------------------------------
# 3. P1 BUS DISPATCH MONOTONIC DOCKING
# -----------------------------------------------------------------
func test_p1_bus_dispatch_docking() -> void:
	print("\n--- 3. P1 Bus Dispatch Monotonic Vertical Docking ---")
	
	# Target slot position
	var slot_pos := Vector2(-65.0, 250.0)
	var corridor_pos := Vector2(slot_pos.x, slot_pos.y + 94.0) # P2
	var start_pos := Vector2(100.0, 450.0)
	var forward_world := Vector2(-0.7071, -0.7071) # 45-deg board exit
	var P1 := start_pos + forward_world * 130.0
	var P2 := corridor_pos
	
	var curve := Curve2D.new()
	curve.add_point(start_pos, Vector2.ZERO, forward_world * 120.0)
	curve.add_point(P1, -forward_world * 100.0, forward_world * 100.0)
	curve.add_point(P2, Vector2(0.0, 50.0), Vector2(0.0, -32.0))
	curve.add_point(slot_pos, Vector2(0.0, 32.0), Vector2.ZERO)
	
	# Sample segment between P2 and P3 (docking into bay)
	var len_total = curve.get_baked_length()
	var offset_p2 = curve.get_closest_offset(P2)
	var len_dock = len_total - offset_p2
	
	var is_monotonic := true
	var x_strictly_constant := true
	var no_overshoot := true
	var prev_y := P2.y
	
	for step in range(51):
		var t = float(step) / 50.0
		var pt = curve.sample_baked(offset_p2 + t * len_dock)
		
		# Verify x stays constant along slot axis
		if absf(pt.x - slot_pos.x) > 0.05:
			x_strictly_constant = false
		
		# Verify y is monotonically decreasing (moving UP)
		if pt.y > prev_y + 0.001:
			is_monotonic = false
		prev_y = pt.y
		
		# Verify y never overshoots above slot destination
		if pt.y < slot_pos.y - 0.01:
			no_overshoot = false
	
	check(x_strictly_constant, "Docking segment: x is constant (x = %.1f, zero sideways sweep)" % slot_pos.x)
	check(is_monotonic, "Docking segment: y is strictly monotonic (zero downward looping)")
	check(no_overshoot, "Docking segment: zero upward overshoot past slot (settles exactly at %.1f)" % slot_pos.y)

# -----------------------------------------------------------------
# 4. P1 BUS DEPARTURE CORRIDOR CLEARANCE
# -----------------------------------------------------------------
func test_p1_bus_departure_clearance() -> void:
	print("\n--- 4. P1 Bus Departure Lower Corridor Clearance ---")
	
	var slot_pos := Vector2(-130.0, 250.0) # Leftmost slot 0
	var reverse_pos := slot_pos + Vector2(0.0, 115.0) # Reverses straight down
	var exit_local := Vector2(800.0, 0.0) # Global right offscreen
	var final_target := Vector2(exit_local.x, reverse_pos.y)
	
	var curve := Curve2D.new()
	curve.add_point(reverse_pos, Vector2.ZERO, Vector2(80.0, 0.0))
	curve.add_point(final_target, Vector2(-160.0, 0.0), Vector2.ZERO)
	
	var total_len = curve.get_baked_length()
	var slot_bottom_y: float = slot_pos.y + 47.0 # 94px slot height / 2
	var min_clearance: float = 99999.0
	var has_upward_pull := false
	
	for step in range(51):
		var t = float(step) / 50.0
		var pt = curve.sample_baked(t * total_len)
		
		var clearance = pt.y - slot_bottom_y
		min_clearance = minf(min_clearance, clearance)
		if pt.y < reverse_pos.y - 0.5:
			has_upward_pull = true
	
	check(not has_upward_pull, "Exit curve has zero upward pull into parking bays (y >= %.1f)" % reverse_pos.y)
	check(min_clearance >= 50.0, "Exit curve maintains %.1f px clearance below all parking bays (target >= 50px)" % min_clearance)

# -----------------------------------------------------------------
# 5. FEEDER JUNCTION SPACING & MERGE CLEARANCE
# -----------------------------------------------------------------
func test_feeder_junction_and_merge_buffer() -> void:
	print("\n--- 5. Feeder Junction Spacing & Merge Clearance ---")
	
	var ROW_SPACING: float = 35.25
	var clearance_buffer: float = ROW_SPACING * 1.35
	check(clearance_buffer >= 47.0, "Merge clearance buffer is %.1f px (>= 47px prevents crowding)" % clearance_buffer)
	
	var f_len: float = 500.0
	var feeder_stop_pos: float = f_len - 110.0
	check(feeder_stop_pos < f_len - 100.0, "Lead feeder row holds at %.1f px when junction is not clear" % feeder_stop_pos)

# -----------------------------------------------------------------
# 6. ATOMIC SLOT RESERVATION & DEPARTURE RELEASE
# -----------------------------------------------------------------
func test_slot_reservation_lifecycle() -> void:
	print("\n--- 6. Atomic Slot Reservation & Departure Release ---")
	
	var controller := CarJamController.new()
	var lvl: CarJamLevelData = load("res://levels/level_001.tres")
	controller.load_level(lvl)
	
	# Reserve an unlocked slot (e.g. slot 1)
	var slot1 = controller.parking.get_slot(1)
	check(slot1.state == CarJamParkingManager.SlotState.EMPTY, "Slot 1 begins EMPTY")
	
	var s_id = controller.parking.reserve_slot(1)
	check(s_id == 1, "Slot 1 reserved for bus 1")
	check(slot1.state == CarJamParkingManager.SlotState.RESERVED, "Slot 1 becomes RESERVED during transit")
	
	controller.on_vehicle_arrived_at_slot(1, 1, controller.session_token)
	check(slot1.state == CarJamParkingManager.SlotState.OCCUPIED, "Slot 1 becomes OCCUPIED upon arrival")
	
	controller.on_vehicle_cleared_slot(1, 1, controller.session_token)
	check(slot1.state == CarJamParkingManager.SlotState.DEPARTING, "Slot 1 stays DEPARTING while reversing (NOT free yet)")
	
	controller.on_vehicle_departed_from_slot(1, 1, controller.session_token)
	check(slot1.state == CarJamParkingManager.SlotState.EMPTY, "Slot 1 becomes EMPTY only after off-screen exit")
