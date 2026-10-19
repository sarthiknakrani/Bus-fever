extends SceneTree

func _init() -> void:
	call_deferred("_test")

func _test() -> void:
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	
	for lvl_id in [1, 2]:
		var lvl = load("res://levels/level_%03d.tres" % lvl_id)
		node.is_level1_mode = false # Test real engine
		node.controller.load_level(lvl)
		var univ = node._build_universal_passenger_queue()
		print("Level %d Universal queue size: %d" % [lvl_id, univ.size()])
		var gen = node._generate_mixed_passenger_sequence(node.controller.queue.get_all_groups())
		print("Level %d Generated queue size: %d" % [lvl_id, gen.size()])
		
		# Check vehicle capacity
		var total_veh_cap = 0
		for v in lvl.vehicles:
			total_veh_cap += v.capacity
		print("Level %d Total vehicle capacity: %d" % [lvl_id, total_veh_cap])
	
	quit()
