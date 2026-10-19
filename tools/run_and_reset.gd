extends SceneTree

# Run the game: load the main scene headlessly, capture a fresh-level-1 screenshot,
# confirm the scene tree is healthy, then exit. Acts as both a smoke test and a
# "reset and snapshot" helper for manual verification.

const CarJamLevelScene = preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[Run] Launching project headlessly...")

	# RESET: force the GameController autoload back to Level 1. (Otherwise it
	# carries whatever level the user was last on, which can be 2+ in tests.)
	if root != null and root.has_node("GameController"):
		var gc_node = root.get_node("GameController")
		gc_node.set("current_level_number", 1)
		print("[Run] Reset GameController.current_level_number=1")

	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# Load the gameplay scene fresh (this is our "reset").
	var lvl: CarJamLevel = CarJamLevelScene.instantiate() as CarJamLevel
	if lvl == null:
		print("[Run] FAIL — could not instantiate CarJamLevel")
		quit(1)
		return
	vp.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()
	lvl._update_layout(Vector2(720, 1280))

	# Wait a few frames for the spline + buses to lay out.
	for _i in 5:
		await process_frame

	# Verify essentials.
	var ctrl: CarJamController = lvl.controller
	print("[Run] Level loaded: id=%d vehicles=%d slots=%d state=%s" % [
		ctrl.level_data.level_id if ctrl.level_data else -1,
		ctrl.vehicles.size(),
		ctrl.parking.get_slot_count() if ctrl.parking else 0,
		str(ctrl.state)
	])
	if ctrl.level_data == null:
		print("[Run] FAIL — level_data is null")
		quit(1)
		return
	if ctrl.vehicles.size() != 6:
		print("[Run] FAIL — expected 6 vehicles, got %d" % ctrl.vehicles.size())
		quit(1)
		return

	# Confirm row cycling is initialized: queue should have 60 rows.
	if lvl._circulating_rows.size() != 60:
		print("[Run] FAIL — _circulating_rows expected 60, got %d" % lvl._circulating_rows.size())
		quit(1)
		return
	if lvl._refill_pool.size() == 0:
		print("[Run] FAIL — _refill_pool is empty (visual cycle broken)")
		quit(1)
		return

	# Confirm star metadata.
	print("[Run] ideal_moves=%d, initial move_count=%d" % [ctrl.level_data.ideal_moves, ctrl.move_count])

	# Capture fresh-level-1 screenshot.
	var img := vp.get_texture().get_image()
	if img != null:
		var path := "/tmp/run_level1_fresh.png"
		img.save_png(path)
		print("[Run] Screenshot saved: %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	else:
		print("[Run] Screenshot skipped (no render target)")

	print("[Run] PASS — Level 1 loaded cleanly with all systems initialized.")
	quit(0)
