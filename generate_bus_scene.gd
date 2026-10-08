extends SceneTree

func _init():
	var root = Node3D.new()
	root.name = "VehicleModel3D"
	
	# Body
	var body = CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(1.2, 0.8, 2.0)
	body.position = Vector3(0, 0.6, 0) # elevated above ground
	# Note: In Godot 4, CSGBox3D doesn't have corner_radius natively? 
	# Wait, let me check. Godot 3 didn't. Godot 4 CSGBox3D doesn't either!
	# BoxMesh has corner_radius? No, neither.
	# Actually, to get rounded corners in 3D in Godot without custom meshes, it's tough.
	root.add_child(body)
	body.owner = root

	var pack = PackedScene.new()
	pack.pack(root)
	ResourceSaver.save(pack, "res://scenes/gameplay/vehicle_model_3d.tscn")
	quit()
