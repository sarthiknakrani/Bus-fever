extends SceneTree

func _init() -> void:
	var h := 63.51 # R=115.0 * 0.552285
	var curve := Curve2D.new()

	# Point 0: Exit Gate (dist = 0 px)
	curve.add_point(Vector2(0, 115), Vector2.ZERO, Vector2(60, 0))
	# Point 1: Bottom-Right Curve entrance
	curve.add_point(Vector2(105, 115), Vector2(-40, 0), Vector2(h, 0))
	# Point 2: Right Apex
	curve.add_point(Vector2(220, 0), Vector2(0, 60), Vector2(0, -60))
	# Point 3: Top-Right Curve exit into top straight
	curve.add_point(Vector2(105, -115), Vector2(h, 0), Vector2(-60, 0))
	# Point 4: Top-Left Curve entrance
	curve.add_point(Vector2(-105, -115), Vector2(60, 0), Vector2(-h, 0))
	# Point 5: Left Apex
	curve.add_point(Vector2(-220, 0), Vector2(0, -60), Vector2(0, 60))
	# Point 6: Bottom-Left Curve exit
	curve.add_point(Vector2(-105, 115), Vector2(-h, 0), Vector2(40, 0))
	# Point 7: Bottom-Center (Left of Gate)
	curve.add_point(Vector2(-15, 115), Vector2(-30, 0), Vector2(30, 0))
	# Point 8: Bottom-Right Curve (Full loop back towards feeder merge)
	curve.add_point(Vector2(105, 115), Vector2(-40, 0), Vector2(h, 0))
	# Point 9: Feeder Merge point on right arc (180, 82)
	curve.add_point(Vector2(180, 82), Vector2(-20, 30), Vector2(25, -45))
	# Point 10: Lower feeder ramp
	curve.add_point(Vector2(295, 20), Vector2(-25, 45), Vector2(15, -45))
	# Point 11: Mid feeder ramp
	curve.add_point(Vector2(330, -110), Vector2(-10, 60), Vector2(10, -60))
	# Point 12: Feeder entrance (top-right offscreen)
	curve.add_point(Vector2(340, -520), Vector2(0, 120), Vector2.ZERO)

	var total_len := curve.get_baked_length()
	print("Baked total length: %.2f px" % total_len)

	# Verify 60 rows at 26.0 px stride (0 to 1534 px)
	var max_queue_dist := 59.0 * 26.0
	print("Max queue distance for 60 rows: %.2f px" % max_queue_dist)
	assert(total_len >= max_queue_dist, "Spline must be longer than 60 rows!")

	# Check position of Row 0 (Gate)
	var p0 = curve.sample_baked(0.0)
	print("Row 0 pos: ", p0)
	assert(p0.distance_to(Vector2(0, 115)) < 1.0, "Row 0 must be at gate")

	# Check position of Row 39 (~1014 px)
	var p39 = curve.sample_baked(39.0 * 26.0)
	print("Row 39 pos: ", p39)

	# Check position of Row 40 (~1040 px)
	var p40 = curve.sample_baked(40.0 * 26.0)
	print("Row 40 pos: ", p40)

	# Check position of Row 59 (~1534 px)
	var p59 = curve.sample_baked(59.0 * 26.0)
	print("Row 59 pos: ", p59)

	print("[PASS] Unified spline length and sample verification SUCCESSFUL!")
	quit()
