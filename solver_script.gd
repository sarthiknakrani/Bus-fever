extends SceneTree

func _init():
	var lvl = ResourceLoader.load("res://levels/level_001.tres") as CarJamLevelData
	
	print("--- STARTING SOLVER ---")
	
	var solution = []
	if solve(lvl, []):
		print("\n🏆 SOLVER SUCCESS! LEVEL CLEARED! 🏆")
	else:
		print("\n❌ SOLVER FAILED! NO SOLUTION EXISTS.")
	quit()

func solve(lvl: CarJamLevelData, path: Array) -> bool:
	var controller = CarJamController.new()
	var root = Node.new()
	root.add_child(controller)
	controller.load_level(lvl)
	
	# Apply path
	for step in path:
		controller.tap_vehicle(step)
		var slot_id = controller.vehicles[step].reserved_slot
		controller.on_vehicle_arrived_at_slot(step, slot_id, controller.session_token)
		
		# release full
		var to_release = []
		for v_id in controller.vehicles.keys():
			var v = controller.vehicles[v_id]
			if v.state == VehicleModel.VehicleState.FULL:
				to_release.append({"v": v, "s": controller.parking.get_slot_for_vehicle(v.id)})
		for r in to_release:
			controller.on_vehicle_departed_from_slot(r.v.id, r.s, controller.session_token)
			
	if controller.state == CarJamController.GameState.WIN:
		print("Winning Path: ", path)
		return true
		
	if controller.state == CarJamController.GameState.FAIL:
		root.queue_free()
		return false
		
	var valid_moves = []
	for v_id in controller.vehicles.keys():
		var v = controller.vehicles[v_id]
		if v.state == VehicleModel.VehicleState.ON_BOARD:
			if controller.board.check_swept_escape(v)["can_escape"]:
				valid_moves.append(v_id)
				
	root.queue_free()
	
	for v_id in valid_moves:
		var new_path = path.duplicate()
		new_path.append(v_id)
		if solve(lvl, new_path):
			return true
			
	return false
