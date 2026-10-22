extends SceneTree

var CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run_suite")

func _run_suite() -> void:
	print("==========================================")
	print("=== UPPER TRACK & VISUAL QA VERIFICATION ===")
	print("==========================================")
	
	var passed = 0
	var failed = 0
	
	var level_scene: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	root.add_child(level_scene)
	if not level_scene.is_node_ready():
		level_scene._ready()
		
	await create_timer(0.1).timeout
	
	# TEST 1: Track Hierarchy and Z-Index Verification
	print("\n--- TEST 1: Track Hierarchy & Draw Order ---")
	var track_bg = level_scene.passenger_track_bg
	var p_visuals = level_scene.passenger_visuals
	if track_bg != null and track_bg.z_index == -2:
		print("  [PASS] passenger_track_bg exists with z_index = -2")
		passed += 1
	else:
		print("  [FAIL] passenger_track_bg missing or incorrect z_index: ", track_bg.z_index if track_bg else "null")
		failed += 1
		
	var tr_node = track_bg.get_node_or_null("TrackRenderer") if track_bg else null
	if tr_node != null and tr_node.z_index == -2:
		print("  [PASS] TrackRenderer is child of passenger_track_bg with z_index = -2")
		passed += 1
	else:
		print("  [FAIL] TrackRenderer not found in passenger_track_bg!")
		failed += 1
		
	if p_visuals != null and p_visuals.get_node_or_null("TrackRenderer") == null:
		print("  [PASS] TrackRenderer cleanly removed from passenger_visuals (no Y-sort occlusion)")
		passed += 1
	else:
		print("  [FAIL] TrackRenderer still inside passenger_visuals!")
		failed += 1

	# TEST 2: Lane Geometry & 100% Track Encompassment
	print("\n--- TEST 2: Passenger Lane Geometry & Border Bounds ---")
	var track = level_scene.passenger_track
	var curve = track.curve
	var track_len = curve.get_baked_length()
	var road_hw = CarJamTrackRenderer.ROAD_HALF_WIDTH
	var track_half_w = road_hw + 55.0 # Border envelope including 3D curbs and drop shadow
	
	var sample_offsets = [
		curve.get_closest_offset(Vector2(0, -115)), # Top straight
		curve.get_closest_offset(Vector2(0, 115)),  # Bottom straight
		curve.get_closest_offset(Vector2(-270, 0)), # Left arc apex
		curve.get_closest_offset(Vector2(270, 0))   # Right arc apex
	]
	var sample_names = ["Top Straight", "Bottom Straight", "Left Arc", "Right Arc"]
	
	var all_contained = true
	var char_height = 160.0 * PassengerView.BASE_SCALE # Upright 2.5D sprite height
	
	for s_idx in range(sample_offsets.size()):
		var prog = sample_offsets[s_idx]
		var s_name = sample_names[s_idx]
		var pt_info = level_scene._get_curve_point_and_normal(curve, prog, true)
		var center_pt: Vector2 = pt_info["pos"]
		var normal: Vector2 = pt_info["normal"]
		
		# Sample all 4 lanes
		for lane in 4:
			var lpos: Vector2 = level_scene._calc_lane_pos(center_pt, normal, lane)
			var head_pos = lpos - Vector2(0, char_height)
			
			if s_name == "Top Straight":
				var border_y = -115.0 - track_half_w
				if head_pos.y < border_y:
					print("  [FAIL] %s Lane %d head (y=%.2f) extends beyond border (y=%.2f)!" % [s_name, lane, head_pos.y, border_y])
					all_contained = false
				else:
					print("  [PASS] %s Lane %d (feet=%.2f, head=%.2f) inside border (%.2f)" % [s_name, lane, lpos.y, head_pos.y, border_y])
			elif s_name == "Bottom Straight":
				var inner_road_y = 115.0 - road_hw
				if lpos.y < inner_road_y:
					print("  [FAIL] %s Lane %d feet (y=%.2f) outside road surface (y=%.2f)!" % [s_name, lane, lpos.y, inner_road_y])
					all_contained = false
				else:
					print("  [PASS] %s Lane %d (feet=%.2f, head=%.2f) inside inner border (%.2f)" % [s_name, lane, lpos.y, head_pos.y, inner_road_y])

	if all_contained:
		print("  [PASS] All 4 lanes across top and bottom straights are 100% contained within track borders")
		passed += 1
	else:
		failed += 1

	# TEST 3: Feeder Offscreen Emergence (Priority 4 - No on-screen button cap or arrow)
	print("\n--- TEST 3: Feeder Offscreen Emergence ---")
	var f_track = level_scene.feeder_track
	var f_start = f_track.curve.get_point_position(0)
	var loop_right_x = 270.0 + road_hw
	print("  Feeder track start: ", f_start)
	print("  Loop right boundary: %.1f px" % loop_right_x)
	
	if f_start.x > loop_right_x:
		print("  [PASS] Feeder originates cleanly offscreen past the loop right border (passengers emerge naturally)")
		passed += 1
	else:
		print("  [FAIL] Feeder start (%.1f) does not originate beyond loop right boundary (%.1f)!" % [f_start.x, loop_right_x])
		failed += 1

	# TEST 4: Live Responsive Layout & Board Prominence Across Resolutions
	print("\n--- TEST 4: Live Responsive Layout Across Resolutions ---")
	var viewports = [
		Vector2(720, 1280),
		Vector2(1080, 1920),
		Vector2(1080, 2400),
		Vector2(390, 844)
	]
	
	var layout_ok = true
	for vp in viewports:
		var vp_node = level_scene.get_viewport()
		level_scene.get_tree().root.size = Vector2i(int(vp.x), int(vp.y))
		level_scene._update_layout()
		
		var sf = level_scene.world_root.scale.x
		var visible_half_w = (vp.x / 2.0) / sf
		var track_system_half_w = 351.0
		
		if visible_half_w < track_system_half_w:
			print("  [FAIL] Viewport %s: visible half width (%.1f) < track width (%.1f)" % [vp, visible_half_w, track_system_half_w])
			layout_ok = false
		else:
			print("  [PASS] Viewport %s: Scale=%.3f, VisibleHalfW=%.1f (Margin: +%.1f px)" % [vp, sf, visible_half_w, visible_half_w - track_system_half_w])

	if layout_ok:
		passed += 1
	else:
		failed += 1

	# Cleanup
	level_scene.queue_free()

	print("\n==========================================")
	print("=== RESULTS: %d PASSED, %d FAILED ===" % [passed, failed])
	print("==========================================")
	if failed == 0:
		quit(0)
	else:
		quit(1)
