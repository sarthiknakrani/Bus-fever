
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	
	var pc = node.passenger_track.curve
	var track_len = pc.get_baked_length()
	var fc = node.feeder_track.curve
	var f_len = fc.get_baked_length()
	
	print("--- TEST PLACEMENT (44 loop rows, 16 feeder rows, ROW_SPACING = 26.0) ---")
	var loop_rows_count = 44
	var loop_progs = []
	for r in range(loop_rows_count):
		var p = fmod(node._platform_start_prog - float(r) * 26.0 + track_len * 10.0, track_len)
		loop_progs.append(p)
	loop_progs.sort()
	
	print("Checking loop adjacent gaps (should all be ~26px):")
	var min_gap = 999.0
	var max_gap = 0.0
	for i in range(loop_progs.size()):
		var p1 = loop_progs[i]
		var p2 = loop_progs[(i + 1) % loop_progs.size()]
		var gap = p2 - p1
		if gap < 0: gap += track_len
		if gap < min_gap: min_gap = gap
		if gap > max_gap: max_gap = gap
	print("Min gap: %.2f px | Max gap: %.2f px" % [min_gap, max_gap])
	
	var feeder_stop_pos = f_len - 208.0
	print("Checking feeder positions (16 rows):")
	for j in range(16):
		var p = feeder_stop_pos - float(j) * 26.0
		if j < 3 or j > 13:
			print("Feeder row %d: prog = %.2f" % [j, p])
			
	quit()
