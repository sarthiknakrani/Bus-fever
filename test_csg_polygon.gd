extends SceneTree
func _init():
	var pts = PackedVector2Array()
	# Draw a rounded rect
	var w = 1.0; var l = 2.0; var r = 0.3
	var res = 8
	# Top right
	for i in range(res+1):
		var ang = PI/2.0 * float(i)/res
		pts.append(Vector2(w - r + cos(ang)*r, -(l - r) - sin(ang)*r))
	# Top left
	for i in range(res+1):
		var ang = PI/2.0 + PI/2.0 * float(i)/res
		pts.append(Vector2(-(w - r) + cos(ang)*r, -(l - r) - sin(ang)*r))
	# Bottom left
	for i in range(res+1):
		var ang = PI + PI/2.0 * float(i)/res
		pts.append(Vector2(-(w - r) + cos(ang)*r, (l - r) - sin(ang)*r))
	# Bottom right
	for i in range(res+1):
		var ang = PI*1.5 + PI/2.0 * float(i)/res
		pts.append(Vector2(w - r + cos(ang)*r, (l - r) - sin(ang)*r))
		
	var poly = CSGPolygon3D.new()
	poly.polygon = pts
	poly.depth = 1.0
	poly.mode = CSGPolygon3D.MODE_DEPTH
	
	var root = Node3D.new()
	root.name = "BusRoot"
	root.add_child(poly)
	poly.owner = root
	
	var pack = PackedScene.new()
	pack.pack(root)
	ResourceSaver.save(pack, "res://test_poly.tscn")
	quit()
