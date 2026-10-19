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
	# Slot 4 and 5 are configured as PLUS bays (start locked, unlock mid-level via dispatch threshold).
	lvl.plus_slot_ids = [4, 5]

	# Vehicles: 6 buses with capacity 40 (2 Yellow, 2 Blue, 2 Red = 240 seats)
	var configs := [
		{"id": 1, "code": "v1_yellow", "color": "yellow", "pos": Vector2i(3, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": CarJamVehicleData.Direction.UP},
		{"id": 2, "code": "v2_blue",   "color": "blue",   "pos": Vector2i(3, 1), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": CarJamVehicleData.Direction.LEFT},
		{"id": 3, "code": "v3_red",    "color": "red",    "pos": Vector2i(1, 2), "footprint": [Vector2i(0, 0), Vector2i(1, 0)], "dir": CarJamVehicleData.Direction.LEFT},
		{"id": 4, "code": "v4_yellow", "color": "yellow", "pos": Vector2i(4, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": CarJamVehicleData.Direction.UP},
		{"id": 5, "code": "v5_blue",   "color": "blue",   "pos": Vector2i(0, 2), "footprint": [Vector2i(0, 0), Vector2i(0, 1)], "dir": CarJamVehicleData.Direction.UP},
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

	# Ordered passenger groups: 6 groups of 40 passengers = 240 total
	var queue_colors: Array[String] = [
		"red",
		"blue",
		"yellow",
		"red",
		"blue",
		"yellow"
	]

	for i in queue_colors.size():
		var g := PassengerGroupData.new(i, queue_colors[i], 40)
		lvl.passenger_groups.append(g)

	return lvl

static func save_level_1_tres(path: String = "res://levels/level_001.tres") -> bool:
	var lvl := create_level_1()
	var err := ResourceSaver.save(lvl, path)
	if err != OK:
		push_error("Failed to save level to %s (error %d)" % [path, err])
		return false
	return true
