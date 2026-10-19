
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	# Let us test creating the unified spline curve
	var spline = Curve2D.new()
	var h = 63.51
	
	# Point 0: Exit Gate at bottom center
	spline.add_point(Vector2(0, 115), Vector2(-40, 0), Vector2(40, 0))
	# Bottom Right
	spline.add_point(Vector2(105, 115), Vector2(-h, 0), Vector2(0, -h))
	# Right Apex
	spline.add_point(Vector2(220, 0), Vector2(0, h), Vector2(0, -h))
	# Top Right
	spline.add_point(Vector2(105, -115), Vector2(0, h), Vector2(-h, 0))
	# Top Left
	spline.add_point(Vector2(-105, -115), Vector2(h, 0), Vector2(0, h))
	# Left Apex
	spline.add_point(Vector2(-220, 0), Vector2(0, -h), Vector2(0, h))
	# Bottom Left
	spline.add_point(Vector2(-105, 115), Vector2(0, -h), Vector2(h, 0))
	
	print("Oval portion baked length: ", spline.get_baked_length())
	quit()
