extends RefCounted
class_name CarJamLevelFactory

## Factory to create and save the production-quality Level 1 configuration.
## 12 vehicles (4 Blue, 4 Red, 4 Yellow), 48 passengers, exactly 4 parking slots.

static func create_level_1() -> CarJamLevelData:
	var lvl := CarJamLevelData.new()
	lvl.level_id = 1
	lvl.title = "Level 1"
	lvl.board_size = Vector2i(5, 5)
	lvl.parking_slots_count = 7
	lvl.unlocked_slot_ids = [1, 2, 3, 4, 5, 6]

	# Vehicles: 6 buses with capacity 40 (2 Blue, 2 Yellow, 2 Red = 240 seats)
	# Matching reference video geometry, blocking relationships, colors and escape directions:
	#  - v1_blue:   anchor (3, 1), footprint [(0,0),(1,0)], dir LEFT (escapes freely to slot 1)
	#  - v2_yellow: anchor (3, 2), footprint [(0,0),(0,1)], dir UP   (blocked by v1_blue)
	#  - v3_yellow: anchor (4, 3), footprint [(0,0),(0,1)], dir UP   (blocked by v1_blue)
	#  - v4_blue:   anchor (0, 2), footprint [(0,0),(0,1)], dir UP   (escapes freely to slot 4)
	#  - v5_red:    anchor (1, 2), footprint [(0,0),(1,0)], dir LEFT (blocked by v4_blue)
	#  - v6_red:    anchor (1, 3), footprint [(0,0),(1,0)], dir LEFT (blocked by v4_blue)
	var configs := [
		{"id": 1, "code": "v1_blue",   "color": "blue",   "pos": Vector2i(3, 1), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": CarJamVehicleData.Direction.LEFT},
		{"id": 2, "code": "v2_yellow", "color": "yellow", "pos": Vector2i(3, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": CarJamVehicleData.Direction.UP},
		{"id": 3, "code": "v3_yellow", "color": "yellow", "pos": Vector2i(4, 3), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": CarJamVehicleData.Direction.UP},
		{"id": 4, "code": "v4_blue",   "color": "blue",   "pos": Vector2i(0, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": CarJamVehicleData.Direction.UP},
		{"id": 5, "code": "v5_red",    "color": "red",    "pos": Vector2i(1, 2), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": CarJamVehicleData.Direction.LEFT},
		{"id": 6, "code": "v6_red",    "color": "red",    "pos": Vector2i(1, 3), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": CarJamVehicleData.Direction.LEFT},
	]

	for cfg in configs:
		var v := CarJamVehicleData.new()
		v.id = cfg["id"]
		v.code = cfg["code"]
		v.color_id = cfg["color"]
		v.capacity = 40
		v.anchor = cfg["pos"]
		v.initial_anchor = cfg["pos"]
		v.direction = cfg["dir"]
		var fp: Array[Vector2i] = []
		for p in cfg["footprint"]:
			fp.append(p)
		v.footprint = fp
		lvl.vehicles.append(v)

	# Ordered passenger groups: 240 total (80 Blue, 80 Yellow, 80 Red)
	# Initial loop groups (152 passengers):
	#  - Group 0: Blue, count 36
	#  - Group 1: Yellow, count 40
	#  - Group 2: Red, count 40
	#  - Group 3: Blue, count 36
	# Feeder queue groups (88 passengers):
	#  - Group 4: Yellow, count 40
	#  - Group 5: Blue, count 8 (4 to complete 1st Blue bus, 4 for 2nd Blue bus)
	#  - Group 6: Red, count 40
	var p_groups := [
		{"color": "blue", "count": 36},
		{"color": "yellow", "count": 40},
		{"color": "red", "count": 40},
		{"color": "blue", "count": 36},
		{"color": "yellow", "count": 40},
		{"color": "blue", "count": 8},
		{"color": "red", "count": 40},
	]

	for i in p_groups.size():
		var g := PassengerGroupData.new(i, p_groups[i]["color"], p_groups[i]["count"])
		lvl.passenger_groups.append(g)

	return lvl

static func save_level_1_tres(path: String = "res://levels/level_001.tres") -> bool:
	var lvl := create_level_1()
	var err := ResourceSaver.save(lvl, path)
	if err != OK:
		push_error("Failed to save level to %s (error %d)" % [path, err])
		return false
	return true
