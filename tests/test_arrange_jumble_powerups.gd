extends SceneTree

# Power-up Booster Test (Arrange + Jumble)
# Verifies the two newer single-use power-ups:
# - Arrange: swaps positions of two ON_BOARD buses; can't be used twice
# - Jumble: random-permutes all ON_BOARD positions; can't be used twice

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("\n=======================================================")
	print("=== ARRANGE + JUMBLE POWER-UP TEST ===")
	print("=======================================================\n")

	var lvl: CarJamLevelData = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	assert(lvl != null, "level_001.tres must load")

	var ctrl := CarJamController.new()
	root.add_child(ctrl)
	ctrl.load_level(lvl)

	# Both power-ups start available.
	assert(ctrl.is_arrange_available(), "Arrange must be available at level start")
	assert(ctrl.is_jumble_available(), "Jumble must be available at level start")
	print("  [PASS] Both power-ups start available\n")

	# Capture all vehicles' pre-swap anchors.
	var pre_anchors: Dictionary = {}
	for vid in ctrl.vehicles:
		pre_anchors[vid] = ctrl.vehicles[vid].anchor
	var vehicle_ids: Array = ctrl.vehicles.keys()
	assert(vehicle_ids.size() >= 3, "Need at least 3 vehicles to test swap")
	var a_id: int = int(vehicle_ids[0])
	var b_id: int = int(vehicle_ids[1])

	# 1) Try arranging two identical ids — should fail (no-op).
	assert(not ctrl.try_arrange_swap(a_id, a_id), "Arrange with same id twice must fail")

	# 2) Arrange the two buses. Expect anchors swapped.
	assert(ctrl.try_arrange_swap(a_id, b_id), "Arrange swap must succeed")
	await create_timer(0.05).timeout
	var post_a_anchor: Vector2i = ctrl.vehicles[a_id].anchor
	var post_b_anchor: Vector2i = ctrl.vehicles[b_id].anchor
	var pre_a_anchor: Vector2i = pre_anchors[a_id]
	var pre_b_anchor: Vector2i = pre_anchors[b_id]
	assert(post_a_anchor == pre_b_anchor, "Bus a should take bus b's old anchor")
	assert(post_b_anchor == pre_a_anchor, "Bus b should take bus a's old anchor")
	print("  [PASS] Arrange swapped anchors correctly\n")

	# 3) Arrange is now used — second call must fail.
	assert(not ctrl.try_arrange_swap(a_id, b_id), "Second Arrange attempt must fail (single-use)")
	assert(not ctrl.is_arrange_available(), "is_arrange_available must now be false")
	print("  [PASS] Arrange is single-use per level\n")

	# 4) Jumble: pick on-board buses, snapshot colors, run jumble, ensure
	#    every bus changes to an alternative color, multiset of colors is conserved,
	#    and NO new colors are added.
	var on_board_ids: Array = []
	var pre_jumble_colors: Dictionary = {}
	var pre_color_counts: Dictionary = {}
	for vid in ctrl.vehicles:
		var v = ctrl.vehicles[vid]
		if v != null and v.state == VehicleModel.VehicleState.ON_BOARD:
			on_board_ids.append(vid)
			pre_jumble_colors[vid] = v.color_id
			pre_color_counts[v.color_id] = pre_color_counts.get(v.color_id, 0) + 1
	assert(on_board_ids.size() >= 3, "Need >= 3 ON_BOARD vehicles for jumble test")
	assert(ctrl.try_jumble_buses(), "Jumble must succeed with >= 3 ON_BOARD vehicles")
	await create_timer(0.05).timeout

	var post_color_counts: Dictionary = {}
	var changed_count: int = 0
	for vid in on_board_ids:
		var pre_col: String = pre_jumble_colors[vid]
		var post_col: String = ctrl.vehicles[vid].color_id
		assert(pre_color_counts.has(post_col), "Jumbled color '%s' must be an existing level color (no new color added)" % post_col)
		post_color_counts[post_col] = post_color_counts.get(post_col, 0) + 1
		if post_col != pre_col:
			changed_count += 1
		assert(post_col != pre_col, "Bus %d must change to an alternative color (was %s, got %s)" % [vid, pre_col, post_col])

	assert(changed_count == on_board_ids.size(), "ALL buses must change to an alternative color")
	assert(pre_color_counts == post_color_counts, "Color multiset must be strictly conserved (no orphan passenger demand)")
	print("  [PASS] Jumble changed ALL bus colors to alternatives with zero new colors added\n")

	# 5) Jumble is single-use.
	assert(not ctrl.try_jumble_buses(), "Second Jumble attempt must fail (single-use)")
	assert(not ctrl.is_jumble_available(), "is_jumble_available must now be false")
	print("  [PASS] Jumble is single-use per level\n")

	# 6) Restart level → both power-ups reset.
	ctrl.restart_level()
	assert(ctrl.is_arrange_available(), "Arrange must reset on restart")
	assert(ctrl.is_jumble_available(), "Jumble must reset on restart")
	print("  [PASS] Both power-ups reset on level restart\n")

	print("=======================================================")
	print("=== ALL ARRANGE + JUMBLE TESTS PASSED ===")
	print("=======================================================\n")
	quit(0)
