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
	
	var total_overlaps := 0
	for lvl_num in [1, 2]:
		gc_node.current_level_number = lvl_num
		var lvl = CarJamLevelScene.instantiate()
		root.add_child(lvl)
		
		await process_frame
		await process_frame
		await physics_frame
		await physics_frame
		
		var polys: Array[PackedVector2Array] = []
		var v_ids: Array[int] = []
		for vid in lvl.vehicle_views:
			var vv: VehicleView = lvl.vehicle_views[vid]
			var ta: Area2D = vv.get_node_or_null("TouchArea")
			var cs: CollisionShape2D = ta.get_child(0)
			var rs: RectangleShape2D = cs.shape
			var sz = rs.size
			var hw = sz.x / 2.0
			var hh = sz.y / 2.0
			var local_corners = [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
			var global_pts = PackedVector2Array()
			for c in local_corners:
				global_pts.append(cs.global_transform * c)
			polys.append(global_pts)
			v_ids.append(vid)
		
		var overlap_count := 0
		var min_clearance: float = 999999.0
		for i in range(polys.size()):
			for j in range(i + 1, polys.size()):
				var inter = Geometry2D.intersect_polygons(polys[i], polys[j])
				if not inter.is_empty():
					overlap_count += 1
					print("  [HITBOX OVERLAP] Level %d: Bus %d overlaps Bus %d!" % [lvl_num, v_ids[i], v_ids[j]])
				else:
					for pa in polys[i]:
						for pb in polys[j]:
							min_clearance = minf(min_clearance, pa.distance_to(pb))
		
		print("Level %d: Overlaps = %d | Min Hitbox Clearance = %.2f px" % [lvl_num, overlap_count, min_clearance])
		total_overlaps += overlap_count
		
		lvl.queue_free()
		await process_frame
		
	if total_overlaps == 0:
		print("\n=== SUCCESS: ALL LEVELS HAVE EXACTLY 0 HITBOX OVERLAPS ===")
		quit(0)
	else:
		printerr("\n=== FAILURE: Found %d hitbox overlaps ===" % total_overlaps)
		quit(1)
