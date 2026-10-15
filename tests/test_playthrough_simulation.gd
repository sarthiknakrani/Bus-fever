extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	_run()

func _run() -> void:
	for lvl_num in [1, 2]:
		print("\n==================================================")
		print("=== RUNNING FULL LEVEL %d PLAYTHROUGH SIMULATION ===" % lvl_num)
		print("==================================================")
		
		var lvl = CarJamLevelScene.instantiate()
		root.add_child(lvl)
		lvl._ready()
		var res_path = "res://levels/level_%03d.tres" % lvl_num
		var ld = ResourceLoader.load(res_path) as CarJamLevelData
		lvl.controller.load_level(ld)
		lvl._setup_visuals(ld)
		
		var solver = CarJamPuzzleSolver.new()
		var solve_res = solver.solve(ld)
		print("Solver result: solvable=", solve_res["solvable"], " moves count=", solve_res["moves"].size())
		if not solve_res["solvable"]:
			printerr("Level %d is not solvable!" % lvl_num)
			quit(1)
			return
			
		var moves: Array = solve_res["moves"]
		print("Solving Level %d with moves: %s" % [lvl_num, str(moves)])
		
		var move_idx := 0
		var sim_frames := 0
		var max_frames := 6000 if lvl_num == 1 else 14000
		
		while sim_frames < max_frames:
			await process_frame
			sim_frames += 1
			
			if move_idx < moves.size() and lvl.controller.parking.find_available_slot() != -1:
				var next_vid = moves[move_idx]
				var v = lvl.controller.vehicles.get(next_vid)
				if v != null and v.state == VehicleModel.VehicleState.ON_BOARD:
					var ok = lvl.controller.tap_vehicle(next_vid)
					if ok:
						print("Frame %d: Dispatched vehicle %d (color=%s)" % [sim_frames, next_vid, v.color_id])
						move_idx += 1
							
			if lvl.controller.state == CarJamController.GameState.WIN:
				print(">>> SUCCESS! Level %d reached WIN in frame %d <<<" % [lvl_num, sim_frames])
				break
			elif lvl.controller.state == CarJamController.GameState.FAIL:
				printerr(">>> Level %d failed prematurely at frame %d <<<" % [lvl_num, sim_frames])
				quit(1)
				return
				
		if lvl.controller.state == CarJamController.GameState.WIN:
			print("Level %d Playthrough Test: PASSED! (State: WIN reached in frame %d)" % [lvl_num, sim_frames])
		else:
			printerr("Level %d Timed out after %d frames. State = %d" % [lvl_num, sim_frames, lvl.controller.state])
			quit(1)
			return
			
		lvl.queue_free()
		await process_frame
		
	print("\n==================================================")
	print("=== BOTH LEVEL 1 & LEVEL 2 FULLY PASSED TO WIN ===")
	print("==================================================")
	quit(0)
