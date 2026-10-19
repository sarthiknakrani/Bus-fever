extends SceneTree

func _init() -> void:
	var lvl: CarJamLevel = load("res://scenes/gameplay/car_jam_level.tscn").instantiate()
	root.add_child(lvl)
	if not lvl.is_node_ready():
		lvl._ready()

	var p_curve = lvl.passenger_track.curve
	var f_curve = lvl.feeder_track.curve

	print("p_curve length: ", p_curve.get_baked_length())
	print("f_curve length: ", f_curve.get_baked_length())

	# Sample feeder curve points and find distance to closest point on passenger track
	print("Checking distances between Feeder curve and Oval curve:")
	var f_len = f_curve.get_baked_length()
	for s in range(0, int(f_len), 30):
		var fp = f_curve.sample_baked(float(s))
		var closest_offset = p_curve.get_closest_offset(fp)
		var pp = p_curve.sample_baked(closest_offset)
		var dist = fp.distance_to(pp)
		print("Feeder s=%d pos=%s | closest oval pt=%s | dist=%.1f" % [s, fp, pp, dist])

	quit()
