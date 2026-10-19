
extends SceneTree

func _init():
	var args = OS.get_cmdline_user_args()
	var row_sp = 32.0
	var max_loop = 112
	var min_gap = 26.0
	for arg in args:
		if arg.begins_with("--row_spacing="):
			row_sp = float(arg.split("=")[1])
		elif arg.begins_with("--max_loop="):
			max_loop = int(arg.split("=")[1])
		elif arg.begins_with("--min_gap="):
			min_gap = float(arg.split("=")[1])
			
	var gc = root.get_node_or_null("GameController")
	if gc != null: gc.current_level_number = 1
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	
	# Override spacing on node
	node.ROW_SPACING = row_sp
	node.MIN_ROW_GAP = min_gap
	node.MAX_INITIAL_LOOP_PASSENGERS = max_loop
	
	root.add_child(node)
	await create_timer(0.3).timeout
	var img = get_root().get_texture().get_image()
	if img != null:
		img.save_png("scratch/test_spacing_%d_%d.png" % [int(row_sp), max_loop])
		print("SAVED scratch/test_spacing_%d_%d.png" % [int(row_sp), max_loop])
	quit()
