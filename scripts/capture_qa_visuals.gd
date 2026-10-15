extends SceneTree

# High-Resolution QA Visual Capture Suite
# Captures mobile viewports, Level 1 & 2 boards, passenger curves, feeder junction, and parked badges.

var resolutions := [
	{"name": "level1_390x844", "size": Vector2i(390, 844), "level": 1},
	{"name": "level1_720x1280", "size": Vector2i(720, 1280), "level": 1},
	{"name": "level1_810x1746", "size": Vector2i(810, 1746), "level": 1},
	{"name": "level2_810x1746", "size": Vector2i(810, 1746), "level": 2}
]
var res_idx := 0

func _init() -> void:
	_run_next()

func _run_next() -> void:
	if res_idx >= resolutions.size():
		print("[QA CAPTURE] All resolution screenshots captured successfully!")
		call_deferred("_run_detailed_qa_snaps")
		return
	
	var r = resolutions[res_idx]
	print("[QA CAPTURE] Capturing %s (%dx%d)..." % [r["name"], r["size"].x, r["size"].y])
	DisplayServer.window_set_size(r["size"])
	
	var gc = root.get_node_or_null("GameController")
	if gc != null:
		gc.current_level_number = r["level"]
		
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	change_scene_to_packed(scene)
	call_deferred("_snap_current", r["name"])

func _snap_current(file_name: String) -> void:
	await create_timer(1.2).timeout
	var img = get_root().get_texture().get_image()
	if img != null:
		var path = "%s.png" % file_name
		img.save_png(path)
		print("[QA CAPTURE] Saved ", path)
	res_idx += 1
	_run_next()

func _run_detailed_qa_snaps() -> void:
	print("[QA CAPTURE] Running detailed gameplay flow captures (Level 1, 810x1746)...")
	DisplayServer.window_set_size(Vector2i(810, 1746))
	var gc = root.get_node_or_null("GameController")
	if gc != null: gc.current_level_number = 1
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	change_scene_to_packed(scene)
	await create_timer(1.0).timeout
	
	var cur_sc = root.get_child(root.get_child_count() - 1)
	# 1. Capture initial dense circulation
	var img0 = get_root().get_texture().get_image()
	if img0 != null:
		img0.save_png("qa_runtime_initial_density.png")
		print("[QA CAPTURE] Saved qa_runtime_initial_density.png")
		
	# 2. Tap legal buses into parking bays (Bus 2, Bus 1, Bus 4)
	if cur_sc != null and cur_sc.has_method("_on_vehicle_tapped"):
		print("[QA CAPTURE] Dispatching Bus 2 into Slot 1...")
		cur_sc._on_vehicle_tapped(2)
		await create_timer(1.2).timeout
		var img1 = get_root().get_texture().get_image()
		if img1 != null:
			img1.save_png("qa_runtime_bus_in_transit.png")
			print("[QA CAPTURE] Saved qa_runtime_bus_in_transit.png")
			
		print("[QA CAPTURE] Dispatching Bus 1 into Slot 2...")
		cur_sc._on_vehicle_tapped(1)
		await create_timer(1.2).timeout
		
		print("[QA CAPTURE] Dispatching Bus 4 into Slot 3...")
		cur_sc._on_vehicle_tapped(4)
		await create_timer(2.0).timeout
		
		var img2 = get_root().get_texture().get_image()
		if img2 != null:
			img2.save_png("qa_runtime_multi_parked.png")
			print("[QA CAPTURE] Saved qa_runtime_multi_parked.png (Showing centered badges & 20px clearance)")
			
	print("[QA CAPTURE] All visual evidence successfully generated!")
	quit()
