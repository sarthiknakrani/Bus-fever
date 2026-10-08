extends RefCounted
class_name CarJamLevelFactory

## Factory to create and save the production-quality Level 1 configuration.
## 12 vehicles (4 Blue, 4 Red, 4 Yellow), 48 passengers, exactly 4 parking slots.

static func create_level_1() -> CarJamLevelData:
	var lvl := CarJamLevelData.new()
	lvl.level_id = 1
	lvl.title = "Level 1"
	lvl.board_size = Vector2i(7, 7)
	lvl.parking_slots_count = 4

	# Vehicles
	var configs := [
		# Col 1: UP
		{"id": 0, "code": "A", "color": "blue",   "pos": Vector2i(1, 1), "dir": CarJamVehicleData.Direction.UP},
		{"id": 1, "code": "B", "color": "red",    "pos": Vector2i(1, 3), "dir": CarJamVehicleData.Direction.UP},
		{"id": 2, "code": "C", "color": "yellow", "pos": Vector2i(1, 5), "dir": CarJamVehicleData.Direction.UP},
		# Col 5: UP
		{"id": 3, "code": "D", "color": "red",    "pos": Vector2i(5, 1), "dir": CarJamVehicleData.Direction.UP},
		{"id": 4, "code": "E", "color": "yellow", "pos": Vector2i(5, 3), "dir": CarJamVehicleData.Direction.UP},
		{"id": 5, "code": "F", "color": "blue",   "pos": Vector2i(5, 5), "dir": CarJamVehicleData.Direction.UP},
		# Col 3: DOWN
		{"id": 6, "code": "G", "color": "blue",   "pos": Vector2i(3, 5), "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 7, "code": "H", "color": "yellow", "pos": Vector2i(3, 3), "dir": CarJamVehicleData.Direction.DOWN},
		{"id": 8, "code": "I", "color": "red",    "pos": Vector2i(3, 1), "dir": CarJamVehicleData.Direction.DOWN},
		# Row 3: HORIZONTAL
		{"id": 9, "code": "J", "color": "yellow", "pos": Vector2i(0, 3), "dir": CarJamVehicleData.Direction.LEFT},
		{"id": 10, "code": "K", "color": "blue",  "pos": Vector2i(2, 3), "dir": CarJamVehicleData.Direction.LEFT},
		{"id": 11, "code": "L", "color": "red",   "pos": Vector2i(6, 3), "dir": CarJamVehicleData.Direction.RIGHT},
	]

	for cfg in configs:
		var v := CarJamVehicleData.new()
		v.id = cfg["id"]
		v.code = cfg["code"]
		v.color_id = cfg["color"]
		v.capacity = 4
		v.anchor = cfg["pos"]
		v.initial_anchor = cfg["pos"]
		v.direction = cfg["dir"]
		v.footprint = [Vector2i.ZERO]
		lvl.vehicles.append(v)

	# Ordered passenger groups: 12 groups of 4 passengers = 48 total
	var queue_colors: Array[String] = [
		"blue",   # Group 0: matches A
		"red",    # Group 1: matches D
		"yellow", # Group 2: matches J
		"blue",   # Group 3: matches G
		"red",    # Group 4: matches L
		"yellow", # Group 5: matches H
		"blue",   # Group 6: matches K
		"red",    # Group 7: matches B
		"yellow", # Group 8: matches E
		"blue",   # Group 9: matches F
		"red",    # Group 10: matches I
		"yellow"  # Group 11: matches C
	]

	for i in queue_colors.size():
		var g := PassengerGroupData.new(i, queue_colors[i], 4)
		lvl.passenger_groups.append(g)

	return lvl

static func save_level_1_tres(path: String = "res://levels/level_001.tres") -> bool:
	var lvl := create_level_1()
	var err := ResourceSaver.save(lvl, path)
	if err != OK:
		push_error("Failed to save level to %s (error %d)" % [path, err])
		return false
	return true
