extends SceneTree

func _init():
	DisplayServer.window_set_size(Vector2i(720, 1280))
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	change_scene_to_packed(scene)
	call_deferred("_run_flow")

func _run_flow():
	await create_timer(1.0).timeout
	var level = current_scene
	print("[FLOW] Level loaded: ", level)
	
	# Frame 1: Initial full-density screen
	_save_snap("qa_runtime_initial_density.png")
	print("[FLOW] 1. Initial screen captured")

	# Dispatch bus 2 (blue bus, can escape)
	print("[FLOW] 2. Tapping Vehicle 2 (Blue)")
	level._on_vehicle_tapped(2)
	await create_timer(0.4).timeout
	_save_snap("qa_runtime_bus_in_transit.png")
	print("[FLOW] 2. In-transit screenshot captured")

	# Wait for bus to park and boarding to start
	await create_timer(1.2).timeout
	_save_snap("qa_runtime_boarding.png")
	print("[FLOW] 3. Boarding screenshot captured")

	# Wait for boarding to finish and bus departure
	await create_timer(2.0).timeout
	_save_snap("qa_runtime_feeder_advance.png")
	print("[FLOW] 4. Feeder advance screenshot captured")

	# Dispatch bus 1 (yellow) into slot
	print("[FLOW] 5. Tapping Vehicle 1 (Yellow)")
	level._on_vehicle_tapped(1)
	await create_timer(1.5).timeout
	_save_snap("qa_runtime_multi_parked.png")
	print("[FLOW] 5. Multiple parked buses screenshot captured")

	print("[FLOW] Verification complete!")
	quit()

func _save_snap(filename: String):
	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png(filename)
		print("[FLOW] Saved ", filename)
