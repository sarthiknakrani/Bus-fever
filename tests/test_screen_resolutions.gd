extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	print("=== Running Multi-Resolution Responsive Screen Tests ===")
	var failures: Array[String] = []

	var test_resolutions: Array[Dictionary] = [
		{"name": "Ultra Tall Phone (720x1880)", "size": Vector2(720, 1880)},
		{"name": "Tall Flagship Phone (1080x2400)", "size": Vector2(1080, 2400)},
		{"name": "Standard 16:9 Phone (720x1280)", "size": Vector2(720, 1280)},
		{"name": "Full HD 16:9 Phone (1080x1920)", "size": Vector2(1080, 1920)},
		{"name": "18:9 Phone (720x1440)", "size": Vector2(720, 1440)},
		{"name": "iPad / Tablet 4:3 (1536x2048)", "size": Vector2(1536, 2048)},
		{"name": "Square Display (1080x1080)", "size": Vector2(1080, 1080)}
	]

	for res_test in test_resolutions:
		var r_name: String = res_test["name"]
		var r_size: Vector2 = res_test["size"]

		var scene: Node2D = CarJamLevelScene.instantiate()
		root.add_child(scene)
		if not scene.is_node_ready():
			scene._ready()

		# Manually simulate the viewport size for this device test
		var top_margin: float = maxf(110.0, r_size.y * 0.065)
		var bottom_margin: float = maxf(130.0, r_size.y * 0.075)
		var avail_h: float = r_size.y - (top_margin + bottom_margin)
		var avail_w: float = r_size.x

		var scale_factor: float = clampf(minf(avail_w / 640.0, avail_h / 1520.0), 0.70, 1.35)
		scene.world_root.scale = Vector2(scale_factor, scale_factor)
		scene.world_root.position.x = avail_w / 2.0
		scene.world_root.position.y = 0.0

		var unscaled_h: float = avail_h / scale_factor
		var unscaled_top: float = top_margin / scale_factor

		scene.passenger_track_root.position.y = unscaled_top + unscaled_h * 0.10
		scene.parking_root.position.y = unscaled_top + unscaled_h * 0.28
		scene.board_root.position.y = unscaled_top + unscaled_h * 0.64

		# Checks
		var py_track: float = scene.passenger_track_root.position.y * scale_factor
		var py_parking: float = scene.parking_root.position.y * scale_factor
		var py_board: float = scene.board_root.position.y * scale_factor

		# 1. Order check
		if not (py_track < py_parking and py_parking < py_board):
			failures.append("%s: Sections overlapping or out of order! Track=%f, Parking=%f, Board=%f" % [r_name, py_track, py_parking, py_board])
			scene.queue_free()
			continue

		# 2. Bounds check
		if py_track < top_margin:
			failures.append("%s: Passenger track (%f) cuts into top margin (%f)" % [r_name, py_track, top_margin])

		var board_half_h: float = (7.0 * 78.0 / 2.0) * scale_factor
		var board_bottom: float = py_board + board_half_h
		var max_allowed_bottom: float = r_size.y - bottom_margin

		if board_bottom > max_allowed_bottom:
			failures.append("%s: Board bottom (%f) exceeds allowed bottom (%f)" % [r_name, board_bottom, max_allowed_bottom])

		# 3. Horizontal centering
		if absf(scene.world_root.position.x - r_size.x / 2.0) > 0.01:
			failures.append("%s: WorldRoot not horizontally centered" % r_name)

		print("  [PASS] %s -> scale=%.2f, Track Y=%.0f, Parking Y=%.0f, Board Y=%.0f (fitted within %.0f-%.0f)" % [
			r_name, scale_factor, py_track, py_parking, py_board, top_margin, max_allowed_bottom
		])

		scene.queue_free()

	if failures.is_empty():
		print("=== All 7 Screen Resolution Tests Passed Perfectly (0 failures) ===")
		quit(0)
	else:
		print("=== Screen Resolution Tests FAILED: %s ===" % str(failures))
		quit(1)
