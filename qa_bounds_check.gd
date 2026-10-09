extends SceneTree

var lvl
var controller

func _init():
	lvl = load("res://scenes/level1.tscn").instantiate()
	root.add_child(lvl)
	call_deferred("_do_qa")

func _do_qa():
	for i in 5:
		await root.get_tree().process_frame
		
	controller = lvl.controller
	if controller == null:
		print("No controller found")
		quit()
		return
		
	print("\n--- QA BOUNDS CHECK ---")
	
	var sequence = [3, 6, 1, 2, 4, 5]
	for vid in sequence:
		var vv = lvl.vehicle_views.get(vid)
		if not vv: continue
		
		print("\nTesting Vehicle ID: ", vid)
		
		# Original logical direction
		var dir_str = CarJamVehicleData.dir_to_string(vv.vehicle_dir)
		print("Original logical direction: ", dir_str)
		
		
		
		var initial_pos = vv.global_position
		
		# Tap the bus
		lvl._on_vehicle_tapped(vid)
		await root.get_tree().create_timer(0.3).timeout
		if not is_instance_valid(vv): continue
		
		var moving_pos = vv.global_position
		var move_vec = (moving_pos - initial_pos).normalized()
		print("First actual screen movement vector: (", snapped(move_vec.x, 0.01), ", ", snapped(move_vec.y, 0.01), ")")
		
		# Wait to clear board
		await root.get_tree().create_timer(0.65).timeout
		if is_instance_valid(vv):
			print("Board-clear position: ", vv.global_position)
		
		# Wait to arrive
		await root.get_tree().create_timer(1.2).timeout
		if is_instance_valid(vv):
			var slot_id = -1
			for i in range(lvl.slot_views.size()):
				if controller.parking.get_slot(i).vehicle_id == vid:
					slot_id = i
					break
			print("Parking slot: ", slot_id)
			print("Parked visual orientation: ", vv.rotation)
			
			var vp_size = Vector2(720, 1880)
			var screen_rect = Rect2(-vp_size / 2.0, vp_size)
			var bounds = Rect2(vv.global_position - Vector2(50,50), Vector2(100,100))
			if screen_rect.encloses(bounds):
				print("Rendered bounds leave screen: false")
			else:
				print("Rendered bounds leave screen: true")
		
		await root.get_tree().create_timer(0.5).timeout

	print("\nQA complete")
	quit()
