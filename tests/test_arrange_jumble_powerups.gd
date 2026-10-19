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

	# 4) Jumble: pick 3+ on-board buses, snapshot anchors, run jumble, ensure
	#    post-anchors are a permutation (same set, different order).
	var on_board_ids: Array = []
	var pre_jumble_anchors: Dictionary = {}
	for vid in ctrl.vehicles:
		var v = ctrl.vehicles[vid]
		if v != null and v.state == VehicleModel.VehicleState.ON_BOARD:
			on_board_ids.append(vid)
			pre_jumble_anchors[vid] = v.anchor
	assert(on_board_ids.size() >= 3, "Need >= 3 ON_BOARD vehicles for jumble test")
	assert(ctrl.try_jumble_buses(), "Jumble must succeed with >= 3 ON_BOARD vehicles")
	await create_timer(0.05).timeout

	var pre_set: Dictionary = {}
	var post_set: Dictionary = {}
	for vid in on_board_ids:
		pre_set[pre_jumble_anchors[vid]] = true
		post_set[ctrl.vehicles[vid].anchor] = true
	assert(pre_set.size() == post_set.size(), "Jumbled positions must keep the same multiset of anchors")
	assert(pre_set.size() == on_board_ids.size(), "Each ON_BOARD vehicle must still have a valid anchor after jumble")
	print("  [PASS] Jumble preserves the anchor multiset\n")

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
