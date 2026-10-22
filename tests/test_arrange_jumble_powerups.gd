extends SceneTree

# Power-up Booster Test (Arrange + Jumble)
# Verifies the two newer single-use power-ups:
# - Arrange: intelligent one-tap auto-arrangement; can't be used twice
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

	# ---- try_arrange_swap backward-compat tests ----
	# Find two vehicles with compatible footprints so their swap is physically legal.
	var vehicle_ids: Array = ctrl.vehicles.keys()
	assert(vehicle_ids.size() >= 3, "Need at least 3 vehicles to test swap")
	var a_id: int = -1
	var b_id: int = -1
	for id_1 in vehicle_ids:
		for id_2 in vehicle_ids:
			if id_1 < id_2 and ctrl.vehicles[id_1].footprint.size() == ctrl.vehicles[id_2].footprint.size():
				var shape_match: bool = true
				for off in ctrl.vehicles[id_1].footprint:
					if not ctrl.vehicles[id_2].footprint.has(off):
						shape_match = false
						break
				if shape_match:
					a_id = id_1
					b_id = id_2
					break
		if a_id != -1:
			break
	assert(a_id != -1 and b_id != -1, "Must find two compatible-footprint vehicles for swap test")

	# Re-load so arrange is fresh (try_arrange_swap consumes it).
	ctrl.load_level(lvl)
	assert(ctrl.is_arrange_available(), "Arrange must be available after reload")

	# Same-id swap must fail.
	assert(not ctrl.try_arrange_swap(a_id, a_id), "Arrange with same id twice must fail")

	# Valid swap must succeed and rebuild board occupancy.
	var pre_a_anchor: Vector2i = ctrl.vehicles[a_id].anchor
	var pre_b_anchor: Vector2i = ctrl.vehicles[b_id].anchor
	assert(ctrl.try_arrange_swap(a_id, b_id), "Arrange swap must succeed")
	await create_timer(0.05).timeout
	var post_a_anchor: Vector2i = ctrl.vehicles[a_id].anchor
	var post_b_anchor: Vector2i = ctrl.vehicles[b_id].anchor
	assert(post_a_anchor == pre_b_anchor, "Bus a should take bus b's old anchor")
	assert(post_b_anchor == pre_a_anchor, "Bus b should take bus a's old anchor")
	# Verify board grid was rebuilt correctly.
	for offset in ctrl.vehicles[a_id].footprint:
		var cell: Vector2i = ctrl.vehicles[a_id].anchor + offset
		assert(ctrl.board.get_vehicle_at(cell) == a_id,
			"Board grid must reflect bus a's new position (cell %s)" % str(cell))
	for offset in ctrl.vehicles[b_id].footprint:
		var cell: Vector2i = ctrl.vehicles[b_id].anchor + offset
		assert(ctrl.board.get_vehicle_at(cell) == b_id,
			"Board grid must reflect bus b's new position (cell %s)" % str(cell))
	print("  [PASS] try_arrange_swap: anchors + board grid rebuilt correctly\n")

	# Second call must fail (single-use).
	assert(not ctrl.try_arrange_swap(a_id, b_id), "Second Arrange attempt must fail (single-use)")
	assert(not ctrl.is_arrange_available(), "is_arrange_available must now be false")
	print("  [PASS] try_arrange_swap is single-use per level\n")

	# ---- try_arrange_intelligent tests ----
	ctrl.load_level(lvl)
	assert(ctrl.is_arrange_available(), "Arrange must be available after second reload")

	var result: Dictionary = ctrl.try_arrange_intelligent()
	await create_timer(0.05).timeout
	# Result must be a valid dictionary.
	assert(result.has("ok"), "try_arrange_intelligent must return dict with 'ok' key")
	if result["ok"]:
		assert(result.has("moves"), "ok=true result must have 'moves' key")
		var moves: Array = result["moves"]
		assert(moves.size() >= 1, "At least one move when ok=true")
		# All moved vehicles must be at their new anchors with correct grid state.
		for m in moves:
			var vid: int = m["vehicle_id"]
			var new_anchor: Vector2i = m["new_anchor"]
			assert(ctrl.vehicles[vid].anchor == new_anchor,
				"Vehicle %d anchor must match new_anchor %s" % [vid, str(new_anchor)])
			for offset in ctrl.vehicles[vid].footprint:
				var cell: Vector2i = ctrl.vehicles[vid].anchor + offset
				assert(ctrl.board.get_vehicle_at(cell) == vid,
					"Board grid must reflect moved vehicle %d at cell %s" % [vid, str(cell)])
		assert(not ctrl.is_arrange_available(), "Arrange must be consumed after intelligent use")
		print("  [PASS] try_arrange_intelligent returned ok=true with valid moves and board state\n")
	else:
		# ok=false means no improvement found — booster should NOT be consumed.
		assert(ctrl.is_arrange_available(), "Arrange must NOT be consumed when ok=false")
		print("  [PASS] try_arrange_intelligent returned ok=false, booster not consumed\n")

	# Second call must fail (single-use, if first call consumed it).
	if result["ok"]:
		var result2: Dictionary = ctrl.try_arrange_intelligent()
		assert(not result2.get("ok", false), "Second intelligent arrange must fail (single-use)")
		print("  [PASS] try_arrange_intelligent is single-use per level\n")

	# ---- Jumble tests ----
	ctrl.load_level(lvl)
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

	# Jumble is single-use.
	assert(not ctrl.try_jumble_buses(), "Second Jumble attempt must fail (single-use)")
	assert(not ctrl.is_jumble_available(), "is_jumble_available must now be false")
	print("  [PASS] Jumble is single-use per level\n")

	# Restart level → both power-ups reset.
	ctrl.restart_level()
	assert(ctrl.is_arrange_available(), "Arrange must reset on restart")
	assert(ctrl.is_jumble_available(), "Jumble must reset on restart")
	print("  [PASS] Both power-ups reset on level restart\n")

	print("=======================================================")
	print("=== ALL ARRANGE + JUMBLE TESTS PASSED ===")
	print("=======================================================\n")
	quit(0)
