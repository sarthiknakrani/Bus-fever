extends SceneTree

const CarJamLevelScene := preload("res://scenes/gameplay/car_jam_level.tscn")

func _init() -> void:
	var gc_node = root.get_node_or_null("GameController")
	if gc_node == null:
		var gc_script = GDScript.new()
		gc_script.source_code = "extends Node\nvar current_level_number: int = 1\nfunc has_level(n: int) -> bool: return n <= 2\n"
		gc_script.reload()
		gc_node = Node.new()
		gc_node.set_script(gc_script)
		gc_node.name = "GameController"
		root.add_child(gc_node)
	gc_node.current_level_number = 1
	
	var lvl = CarJamLevelScene.instantiate()
	root.add_child(lvl)
	
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	
	print("\n=== MULTI-POINT BUS HITBOX PICKING AUDIT ===")
	var space_state = lvl.get_world_2d().direct_space_state
	var mis_hits := 0
	
	for vid in [1, 2, 3, 4, 5, 6]:
		var vv: VehicleView = lvl.vehicle_views[vid]
		var cs: CollisionShape2D = vv.get_node("TouchArea").get_child(0)
		var rs: RectangleShape2D = cs.shape
		var sz = rs.size
		var center = cs.global_position
		
		# Sample within the valid hitbox boundaries
		var hw = (sz.x * 0.4)
		var hh = (sz.y * 0.4)
		
		var sample_local_points = [
			Vector2(0, 0),
			Vector2(0, -hh),
			Vector2(0, hh),
			Vector2(-hw, 0),
			Vector2(hw, 0)
		]
		
		print("\nBus %d (%s, %s): size=%s" % [vid, vv.vehicle_code, vv.vehicle_color_id, sz])
		for pt_local in sample_local_points:
			var pt_global = cs.global_transform * pt_local
			var query = PhysicsPointQueryParameters2D.new()
			query.position = pt_global
			query.collide_with_areas = true
			var hits = space_state.intersect_point(query)
			var hit_ids = []
			for h in hits:
				hit_ids.append(h["collider"].get_parent().vehicle_id)
			var ok = (hit_ids == [vid])
			if not ok: mis_hits += 1
			print("  Local %s -> Global %s: hits=%s [%s]" % [
				pt_local, pt_global, str(hit_ids), "OK" if ok else "FAIL"
			])
			
	if mis_hits == 0:
		print("\n=== PERFECT HITBOX PICKING: 0 MIS-HITS ACROSS ALL 30 TEST POINTS ===")
		quit(0)
	else:
		printerr("\n=== FOUND %d MIS-HITS ===" % mis_hits)
		quit(1)
