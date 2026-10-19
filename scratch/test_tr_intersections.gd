extends SceneTree

func _init():
	var curve = Curve2D.new()
	var h := 63.51
	curve.add_point(Vector2(220, 0), Vector2(0, -h), Vector2(0, h))
	curve.add_point(Vector2(105, 115), Vector2(h, 0), Vector2.ZERO)
	curve.add_point(Vector2(-105, 115), Vector2.ZERO, Vector2(-h, 0))
	curve.add_point(Vector2(-220, 0), Vector2(0, h), Vector2(0, -h))
	curve.add_point(Vector2(-105, -115), Vector2(-h, 0), Vector2.ZERO)
	curve.add_point(Vector2(105, -115), Vector2.ZERO, Vector2(h, 0))
	curve.add_point(Vector2(220, 0), Vector2(0, -h), Vector2(0, h))

	var f_curve = Curve2D.new()
	f_curve.add_point(Vector2(340, -520), Vector2.ZERO, Vector2(0, 120))
	f_curve.add_point(Vector2(330, -110), Vector2(10, -60), Vector2(-10, 60))
	f_curve.add_point(Vector2(295, 20), Vector2(20, -40), Vector2(-25, 35))
	var merge_prog = curve.get_closest_offset(Vector2(180, 82))
	var merge_pt = curve.sample_baked(merge_prog)
	f_curve.add_point(merge_pt, Vector2(30, -28), Vector2.ZERO)

	var f_len = f_curve.get_baked_length()
	print("f_len: ", f_len)
	for d in [0, 50, 100, 150, 180, 200, 220, 240, 260]:
		var prog = f_len - float(d)
		var pt = f_curve.sample_baked(prog)
		var dist_to_center = pt.distance_to(Vector2(105, 0))
		print("dist from merge: %3d px | prog: %.1f | pt: (%.1f, %.1f) | dist to (105,0): %.1f" % [d, prog, pt.x, pt.y, dist_to_center])
	quit()
