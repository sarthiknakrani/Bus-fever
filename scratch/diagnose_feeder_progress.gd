
extends SceneTree
func _init():
	var scene = load("res://scenes/gameplay/car_jam_level.tscn")
	var node = scene.instantiate()
	root.add_child(node)
	await process_frame
	if node.controller.vehicles.has(1):
		node._on_vehicle_tapped(1)
	for f in range(100):
		await process_frame
		if not node._feeder_rows.is_empty():
			var r0 = node._feeder_rows[0]
			if f % 10 == 0:
				print("Frame %d | r0 prog: %.2f | committed: %s | cap: %d" % [
					f, r0.progress, node._lead_feeder_committed, node._oval_freed_capacity
				])
	quit()
