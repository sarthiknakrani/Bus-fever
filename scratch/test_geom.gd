extends SceneTree
func _init():
	var pts = PackedVector2Array()
	var f = FileAccess.open("scratch/debug_top_poly.txt", FileAccess.READ)
	if f != null:
		while not f.eof_reached():
			var line = f.get_line().strip_edges()
			if line.is_empty(): continue
			var parts = line.split(",")
			pts.append(Vector2(float(parts[0]), float(parts[1])))
		f.close()
	print("Original pts count:", pts.size())
	var clean = Geometry2D.merge_polygons(pts, PackedVector2Array())
	print("Clean count:", clean.size())
	for i in clean.size():
		var tris = Geometry2D.triangulate_polygon(clean[i])
		print("Poly", i, "pts:", clean[i].size(), "tris:", tris.size() / 3)
	quit()
