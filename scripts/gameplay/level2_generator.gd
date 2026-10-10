extends SceneTree

func _init():
	print("Generating Level 2...")
	var lvl = CarJamLevelData.new()
	lvl.level_id = 2
	lvl.title = "Level 2"
	lvl.board_size = Vector2i(7, 7)
	lvl.parking_slots_count = 7
	
	var configs = [
		{"id": 1, "code": "v1", "color": "red", "pos": Vector2i(0, 1), "dir": CarJamVehicleData.Direction.UP, "fp": [Vector2i(0, 0), Vector2i(0, 1)]},
		{"id": 2, "code": "v2", "color": "blue", "pos": Vector2i(0, 4), "dir": CarJamVehicleData.Direction.DOWN, "fp": [Vector2i(0, 0), Vector2i(0, -1)]},
		{"id": 3, "code": "v3", "color": "yellow", "pos": Vector2i(1, 2), "dir": CarJamVehicleData.Direction.UP, "fp": [Vector2i(0, 0), Vector2i(0, 1)]},
		{"id": 4, "code": "v4", "color": "red", "pos": Vector2i(2, 3), "dir": CarJamVehicleData.Direction.DOWN, "fp": [Vector2i(0, 0), Vector2i(0, -1)]},
		{"id": 5, "code": "v5", "color": "blue", "pos": Vector2i(3, 1), "dir": CarJamVehicleData.Direction.RIGHT, "fp": [Vector2i(0, 0), Vector2i(-1, 0)]},
		{"id": 6, "code": "v6", "color": "yellow", "pos": Vector2i(5, 1), "dir": CarJamVehicleData.Direction.RIGHT, "fp": [Vector2i(0, 0), Vector2i(-1, 0)]},
		{"id": 7, "code": "v7", "color": "red", "pos": Vector2i(1, 4), "dir": CarJamVehicleData.Direction.LEFT, "fp": [Vector2i(0, 0), Vector2i(1, 0)]},
		{"id": 8, "code": "v8", "color": "blue", "pos": Vector2i(4, 4), "dir": CarJamVehicleData.Direction.RIGHT, "fp": [Vector2i(0, 0), Vector2i(-1, 0)]},
		{"id": 9, "code": "v9", "color": "yellow", "pos": Vector2i(2, 5), "dir": CarJamVehicleData.Direction.LEFT, "fp": [Vector2i(0, 0), Vector2i(1, 0)]},
		{"id": 10, "code": "v10", "color": "red", "pos": Vector2i(5, 2), "dir": CarJamVehicleData.Direction.UP, "fp": [Vector2i(0, 0), Vector2i(0, 1)]},
		{"id": 11, "code": "v11", "color": "blue", "pos": Vector2i(5, 5), "dir": CarJamVehicleData.Direction.DOWN, "fp": [Vector2i(0, 0), Vector2i(0, -1)]},
		{"id": 12, "code": "v12", "color": "yellow", "pos": Vector2i(6, 3), "dir": CarJamVehicleData.Direction.DOWN, "fp": [Vector2i(0, 0), Vector2i(0, -1)]}
	]
	
	for cfg in configs:
		var v = CarJamVehicleData.new()
		v.id = cfg["id"]
		v.code = cfg["code"]
		v.color_id = cfg["color"]
		v.capacity = 4
		v.anchor = cfg["pos"]
		v.initial_anchor = cfg["pos"]
		v.direction = cfg["dir"]
		
		var fp: Array[Vector2i] = []
		for p in cfg["fp"]:
			fp.append(p)
		v.footprint = fp
		
		lvl.vehicles.append(v)
		
	var queue = ["red", "yellow", "red", "blue", "yellow", "blue", "blue", "yellow", "blue", "red", "yellow", "red"]
	
	for i in range(queue.size()):
		var g = PassengerGroupData.new(i, queue[i], 4)
		lvl.passenger_groups.append(g)
		
	var err = ResourceSaver.save(lvl, "res://levels/level_002.tres")
	if err == OK:
		print("Successfully saved level_002.tres")
	else:
		print("Error saving level: ", err)
		
	quit()
