extends SceneTree

func _init() -> void:
	var cfg = load("res://scripts/data/level1_config.gd").new()
	var ref_sz = cfg.reference_size
	var buses = cfg.buses_data
	var bus_sz = cfg.lot_bus_size # (110, 220)
	
	print("--- EXACT OBB INTERSECTION CHECK ---")
	for b in buses:
		var p_px: Vector2 = Vector2(b["pos"].x * ref_sz.x, b["pos"].y * ref_sz.y)
		var rad = deg_to_rad(b["heading"])
		var fwd = Vector2(sin(rad), -cos(rad)).normalized()
		
	var b1 = buses[0] # Bus 1
	var b2 = buses[1] # Bus 2
	var p1 = Vector2(b1["pos"].x * ref_sz.x, b1["pos"].y * ref_sz.y) # (756, 1229)
	var p2 = Vector2(b2["pos"].x * ref_sz.x, b2["pos"].y * ref_sz.y) # (734, 1382)
	var rad1 = deg_to_rad(b1["heading"]) # -60 deg
	var rad2 = deg_to_rad(b2["heading"]) # +30 deg
	var fwd1 = Vector2(sin(rad1), -cos(rad1)).normalized()
	var right1 = Vector2(-fwd1.y, fwd1.x)
	var fwd2 = Vector2(sin(rad2), -cos(rad2)).normalized()
	for d in range(50, 300, 10):
		var pt = p2 + fwd2 * float(d)
		var rel = pt - p1
		var lf = rel.dot(fwd1)
		var lr = rel.dot(right1)
		if absf(lf) <= 120.0:
			print("At d=", d, ": pt=", pt, " in B1 local: fwd=", lf, " right=", lr)

	quit()
