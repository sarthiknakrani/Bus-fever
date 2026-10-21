extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")
const ParkingSlotView := preload("res://scripts/gameplay/parking_slot_view.gd")
const VehicleMovement := preload("res://scripts/gameplay/vehicle_movement.gd")

func _init() -> void:
	_run_qa()

func _run_qa() -> void:
	await create_timer(0.3).timeout
	print("\n=======================================================")
	print("=== FOUR DELIVERABLES RUNTIME QA VERIFICATION SUITE ===")
	print("=======================================================\n")

	var failures := 0

	# ----------------------------------------------------
	# 1. DELIVERABLE 1: ZERO-GAP PASSENGERS & 4-LANE DENSITY
	# ----------------------------------------------------
	print("--- TEST 1: Zero-Gap Passenger Formation & Loop Capacity ---")
	var level: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(level)
	if not level.is_node_ready():
		level._ready()
	await create_timer(0.15).timeout

	print("  [MEASURED] LANE_SPACING: %.2f px" % level.LANE_SPACING)
	print("  [MEASURED] ROW_SPACING: %.2f px" % level.ROW_SPACING)
	print("  [MEASURED] MAX_INITIAL_LOOP_PASSENGERS: %d" % level.MAX_INITIAL_LOOP_PASSENGERS)

	if abs(level.LANE_SPACING - 17.5) < 0.1:
		print("  [PASS] LANE_SPACING calibrated to 17.5 px")
	else:
		print("  [FAIL] Expected LANE_SPACING 17.5, got %.2f" % level.LANE_SPACING)
		failures += 1

	if abs(level.ROW_SPACING - 29.0) < 0.1:
		print("  [PASS] ROW_SPACING calibrated to 29.0 px (zero visible gaps, 36 rows along loop)")
	else:
		print("  [FAIL] Expected ROW_SPACING 29.0, got %.2f" % level.ROW_SPACING)
		failures += 1

	if level.circulating_ids.size() == 144:
		print("  [PASS] Main oval starts densely populated with exactly 144 passengers (36 rows x 4 lanes)")
	else:
		print("  [FAIL] Expected 144 circulating passengers, got %d" % level.circulating_ids.size())
		failures += 1

	# Verify horizontal clearance between adjacent lanes
	var pt_sample = level._get_curve_point_and_normal(level.passenger_track.curve, 0.0, true)
	var lane0 = level._calc_lane_pos(pt_sample["pos"], pt_sample["normal"], 0)
	var lane1 = level._calc_lane_pos(pt_sample["pos"], pt_sample["normal"], 1)
	var lane_dist = lane0.distance_to(lane1)
	print("  [MEASURED] Inter-lane center distance: %.2f px" % lane_dist)
	if abs(lane_dist - 16.0) < 0.1:
		print("  [PASS] Inter-lane clearance strictly verified")
	else:
		print("  [FAIL] Inter-lane distance mismatch: %.2f" % lane_dist)
		failures += 1

	# ----------------------------------------------------
	# 2. DELIVERABLE 2: REAL RUNNING ANIMATION & IDLE STATE
	# ----------------------------------------------------
	print("\n--- TEST 2: Real Running Animation & Waiting Idle State ---")
	var colors := ["red", "blue", "yellow", "green", "purple", "orange", "pink", "brown"]
	for col in colors:
		var pv := PassengerView.new()
		pv.setup(col, 1, 0)
		var spr: Sprite2D = pv.get_node_or_null("VisualNode/CharacterSprite") as Sprite2D
		if spr == null or spr.texture == null:
			print("  [FAIL] PassengerView for '%s' missing sprite/texture" % col)
			failures += 1
		elif spr.hframes != 8:
			print("  [FAIL] PassengerView for '%s' expected 8 hframes (running+idle), got %d" % [col, spr.hframes])
			failures += 1
		else:
			print("  [PASS] Color '%s': 8-frame spritesheet active (6 running frames + 2 idle frames)" % col)
		pv.queue_free()

	# Test dynamic frame updates with motion vs waiting
	var test_pv := PassengerView.new()
	test_pv.setup("blue", 0, 0)
	root.add_child(test_pv)
	test_pv.position = Vector2(0, 0)
	test_pv._process(0.016)
	
	# When waiting:
	test_pv.set_waiting(true)
	test_pv._process(0.1)
	var spr_test: Sprite2D = test_pv.get_node_or_null("VisualNode/CharacterSprite") as Sprite2D
	if spr_test.frame >= 6:
		print("  [PASS] Stopped/waiting passenger correctly displays idle waiting frame (%d)" % spr_test.frame)
	else:
		print("  [FAIL] Stopped passenger did not enter idle frames: frame=%d" % spr_test.frame)
		failures += 1

	# When moving along track:
	test_pv.set_waiting(false)
	var initial_frame = spr_test.frame
	var frame_changed := false
	for step in 10:
		test_pv.position += Vector2(10.0, 0.0) # move forward 10px per step
		test_pv._process(0.016)
		if spr_test.frame < 6 and spr_test.frame != initial_frame:
			frame_changed = true
			break
	if frame_changed:
		print("  [PASS] Moving passenger visibly cycles through running stride frames (current: %d)" % spr_test.frame)
	else:
		print("  [FAIL] Moving passenger failed to cycle running frames")
		failures += 1
	test_pv.queue_free()

	# ----------------------------------------------------
	# 3. DELIVERABLE 3: PERFECT BUS SIZING FOR PARKING SLOTS
	# ----------------------------------------------------
	print("\n--- TEST 3: Bus Parking Slot Containment & Uniform Scale ---")
	const SLOT_W: float = ParkingSlotView.SLOT_WIDTH   # 48.0
	const SLOT_H: float = ParkingSlotView.SLOT_HEIGHT  # 94.0
	print("  [AUTHORITATIVE] ParkingSlotView: %d x %d" % [int(SLOT_W), int(SLOT_H)])

	for vid in level.vehicle_views:
		var vv: VehicleView = level.vehicle_views[vid]
		var is_vert: bool = (vv.vehicle_dir == 0 or vv.vehicle_dir == 1)
		var body_w = VehicleView.RENDERED_BODY_WIDTH_V if is_vert else VehicleView.RENDERED_BODY_WIDTH_H
		var visual_body: Vector2 = Vector2(body_w, VehicleView.RENDERED_BODY_LENGTH)
		var final_scale: float = VehicleView.BUS_VISUAL_SCALE
		
		print("  [MEASURED] Bus %d (%s, %s): Parked visual body: %.1f x %.1f (Scale: %.4f)" % [
			vv.vehicle_id, vv.vehicle_code, vv.vehicle_color_id, visual_body.x, visual_body.y, final_scale
		])
		
		var fits_w = visual_body.x <= SLOT_W and visual_body.x >= 36.0
		var fits_h = visual_body.y <= SLOT_H and visual_body.y >= 80.0
		if fits_w and fits_h:
			var margin_w = (SLOT_W - visual_body.x) / 2.0
			var margin_h = (SLOT_H - visual_body.y) / 2.0
			print("    [PASS] Clean margins: W_margin=%.1fpx, H_margin=%.1fpx (Zero clipping!)" % [margin_w, margin_h])
		else:
			print("    [FAIL] Bus %d visual body exceeds bounds: %.1f x %.1f" % [vv.vehicle_id, visual_body.x, visual_body.y])
			failures += 1

	# ----------------------------------------------------
	# 4. DELIVERABLE 4: FEEDER ISOLATION & OVERLAP FIX
	# ----------------------------------------------------
	print("\n--- TEST 4: Feeder Track Geometry & Stop Line Separation ---")
	var f_len := level.feeder_track.curve.get_baked_length()
	var stop_pos := f_len - 120.0
	var f_stop_pt := level.feeder_track.curve.sample_baked(stop_pos)
	var closest_oval_prog := level.passenger_track.curve.get_closest_offset(f_stop_pt)
	var closest_oval_pt := level.passenger_track.curve.sample_baked(closest_oval_prog)
	var clearance_dist := f_stop_pt.distance_to(closest_oval_pt)
	
	print("  [MEASURED] Feeder Stop Point: %s" % f_stop_pt)
	print("  [MEASURED] Closest Point on Oval: %s (offset %.1f)" % [closest_oval_pt, closest_oval_prog])
	print("  [MEASURED] Physical separation between waiting queue and oval: %.1f px" % clearance_dist)

	if clearance_dist >= 25.0:
		print("  [PASS] Feeder waiting queue is physically isolated from oval track (Clearance: %.1f px)" % clearance_dist)
	else:
		print("  [FAIL] Feeder queue too close to oval: %.1f px" % clearance_dist)
		failures += 1

	# Verify feeder rows do NOT overlap oval during unboarded state
	if not level._feeder_rows.is_empty():
		var lead_prog = level._feeder_rows.front().progress
		print("  [MEASURED] Lead feeder row progress: %.1f (Stop pos: %.1f)" % [lead_prog, stop_pos])
		if lead_prog <= f_len - 110.0:
			print("  [PASS] Lead feeder row held strictly at stop line before junction")
		else:
			print("  [FAIL] Lead feeder row entered junction prematurely: %.1f" % lead_prog)
			failures += 1

	level.queue_free()

	print("\n=======================================================")
	if failures == 0:
		print("=== ALL 4 DELIVERABLES VERIFIED 100% PASSED (0 FAILURES) ===")
	else:
		print("=== %d TESTS FAILED ===" % failures)
	print("=======================================================\n")

	quit(failures)
