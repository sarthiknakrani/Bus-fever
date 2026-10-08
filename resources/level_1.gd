extends RefCounted
class_name Level1Resource

## Level 1 — single playable level.
## 7x7 board, 12 vehicles (2 each of 6 colors), 48 passengers, 5 bays.
##
## Coordinates are (x, y) cells. Direction is in VehicleData.Direction.
##
## Free at start:  A (blue), D (red), G (blue), J (red), L (orange)
## Blocked at start by real occupancy:  B, C, E, F, H, I, K

func build() -> LevelData:
	var lvl := LevelData.new()
	lvl.id = "level_1"
	lvl.display_name = "Level 1"
	lvl.board_size = Vector2i(7, 7)
	lvl.standard_bay_count = 5
	lvl.cell_size = 96.0
	lvl.board_origin = Vector2(60, 320)
	lvl.bay_panel_origin = Vector2(60, 1080)
	lvl.vehicles = [
		# Column 1: facing NORTH
		{"id": "A", "color": "blue",   "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "B", "color": "yellow", "capacity": 4, "position": Vector2i(1, 3), "initial_position": Vector2i(1, 3), "direction": VehicleData.Direction.NORTH},
		{"id": "C", "color": "green",  "capacity": 4, "position": Vector2i(1, 5), "initial_position": Vector2i(1, 5), "direction": VehicleData.Direction.NORTH},
		# Column 5: facing NORTH
		{"id": "D", "color": "red",    "capacity": 4, "position": Vector2i(5, 1), "initial_position": Vector2i(5, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "E", "color": "yellow", "capacity": 4, "position": Vector2i(5, 3), "initial_position": Vector2i(5, 3), "direction": VehicleData.Direction.NORTH},
		{"id": "F", "color": "purple", "capacity": 4, "position": Vector2i(5, 5), "initial_position": Vector2i(5, 5), "direction": VehicleData.Direction.NORTH},
		# Column 3 (middle): row 5 green, row 3 orange, row 1 green — facing SOUTH
		{"id": "G", "color": "blue",   "capacity": 4, "position": Vector2i(3, 5), "initial_position": Vector2i(3, 5), "direction": VehicleData.Direction.SOUTH},
		{"id": "H", "color": "orange", "capacity": 4, "position": Vector2i(3, 3), "initial_position": Vector2i(3, 3), "direction": VehicleData.Direction.SOUTH},
		{"id": "I", "color": "green",  "capacity": 4, "position": Vector2i(3, 1), "initial_position": Vector2i(3, 1), "direction": VehicleData.Direction.SOUTH},
		# Row 3 (middle): column 0 red, column 2 purple — facing WEST
		{"id": "J", "color": "red",    "capacity": 4, "position": Vector2i(0, 3), "initial_position": Vector2i(0, 3), "direction": VehicleData.Direction.WEST},
		{"id": "K", "color": "purple", "capacity": 4, "position": Vector2i(2, 3), "initial_position": Vector2i(2, 3), "direction": VehicleData.Direction.WEST},
		# Row 3: column 6 orange — facing EAST
		{"id": "L", "color": "orange", "capacity": 4, "position": Vector2i(6, 3), "initial_position": Vector2i(6, 3), "direction": VehicleData.Direction.EAST},
	]
	lvl.passenger_order = [
		# 12 groups of 4 — one bus per group, one passenger per "demand unit"
		# in this game's model: each passenger is one element of the order.
		"blue", "blue", "blue", "blue",         # group 1 (A blue, capacity 4)
		"red", "red", "red", "red",             # group 2 (D red)
		"orange", "orange", "orange", "orange", # group 3 (L orange)
		"yellow", "yellow", "yellow", "yellow", # group 4 (E yellow)
		"green", "green", "green", "green",     # group 5 (C green)
		"purple", "purple", "purple", "purple", # group 6 (F purple)
		"blue", "blue", "blue", "blue",         # group 7 (G blue)
		"yellow", "yellow", "yellow", "yellow", # group 8 (B yellow)
		"orange", "orange", "orange", "orange", # group 9 (H orange)
		"red", "red", "red", "red",             # group 10 (J red)
		"green", "green", "green", "green",     # group 11 (I green)
		"purple", "purple", "purple", "purple", # group 12 (K purple)
	]
	lvl.tutorial_triggers = [
		{"after_seconds": 0.5, "vehicle_id": "A", "text": "Tap a free bus"},
		{"after_seconds": 2.5, "vehicle_id": "D", "text": "Direction matters"},
		{"after_seconds": 4.5, "vehicle_id": "B", "text": "Move blockers"},
		{"after_seconds": 6.5, "vehicle_id": "E", "text": "Match the queue"},
	]
	return lvl