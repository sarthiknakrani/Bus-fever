extends SceneTree

func _init() -> void:
	var cfg = load("res://scripts/data/level1_config.gd").new()
	var ref_sz = cfg.reference_size # (1080, 1920)
	var buses = cfg.buses_data
	
	# Heading to forward unit vector:
	# 0 deg is -Y (0, -1)
	# -60 deg is ↖ (sin(-60), -cos(-60)) = (-0.866025, -0.5)
	# +30 deg is ↗ (sin(30), -cos(30)) = (0.5, -0.866025)
	print("--- BUS BLOCKING VERIFICATION ---")
	for b in buses:
		var p_px: Vector2 = Vector2(b["pos"].x * ref_sz.x, b["pos"].y * ref_sz.y)
		var rad = deg_to_rad(b["heading"])
		var fwd = Vector2(sin(rad), -cos(rad)).normalized()
		var right = Vector2(-fwd.y, fwd.x)
		
		# Check raycast forward 400px with half-width 65px
		var blocker_id := -1
		var min_dist := 9999.0
		for other in buses:
			if other["id"] == b["id"]: continue
			var other_px = Vector2(other["pos"].x * ref_sz.x, other["pos"].y * ref_sz.y)
			var to_other = other_px - p_px
			var forward_dist = to_other.dot(fwd)
			var lateral_dist = absf(to_other.dot(right))
			# A bus is ~110x220 px
			if forward_dist > 50.0 and forward_dist < 400.0 and lateral_dist < 80.0:
				if forward_dist < min_dist:
					min_dist = forward_dist
					blocker_id = other["id"]
		print("Bus %d (%s, heading %d deg) -> Blocked by: %s (Expected: %s)" % [
			b["id"], b["color"], b["heading"],
			("Bus %d at %.1f px" % [blocker_id, min_dist]) if blocker_id != -1 else "CLEAR",
			b["desc"]
		])
	quit()
