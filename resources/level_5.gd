extends RefCounted
class_name Level5Resource

## Level 5 — "Grand Terminal".
## 8x8 board, 14 vehicles (3 blue, 3 red, 2 yellow, 2 green, 2 purple, 2 orange), 56 passengers, 5 bays.
## Terminal scale puzzle with multi-lane flow and high-occupancy coordination.

func build() -> LevelData:
	var lvl := LevelData.new()
	lvl.id = "level_5"
	lvl.display_name = "Level 5: Grand Terminal"
	lvl.board_size = Vector2i(8, 8)
	lvl.standard_bay_count = 5
	lvl.cell_size = 90.0
	lvl.board_origin = Vector2(40, 310)
	lvl.bay_panel_origin = Vector2(40, 1080)
	lvl.vehicles = [
		{"id": "A", "color": "blue",   "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "B", "color": "red",    "capacity": 4, "position": Vector2i(1, 3), "initial_position": Vector2i(1, 3), "direction": VehicleData.Direction.NORTH},
		{"id": "C", "color": "yellow", "capacity": 4, "position": Vector2i(1, 5), "initial_position": Vector2i(1, 5), "direction": VehicleData.Direction.NORTH},

		{"id": "D", "color": "green",  "capacity": 4, "position": Vector2i(3, 6), "initial_position": Vector2i(3, 6), "direction": VehicleData.Direction.SOUTH},
		{"id": "E", "color": "purple", "capacity": 4, "position": Vector2i(3, 4), "initial_position": Vector2i(3, 4), "direction": VehicleData.Direction.SOUTH},
		{"id": "F", "color": "orange", "capacity": 4, "position": Vector2i(3, 2), "initial_position": Vector2i(3, 2), "direction": VehicleData.Direction.SOUTH},

		{"id": "G", "color": "blue",   "capacity": 4, "position": Vector2i(4, 1), "initial_position": Vector2i(4, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "H", "color": "red",    "capacity": 4, "position": Vector2i(4, 3), "initial_position": Vector2i(4, 3), "direction": VehicleData.Direction.NORTH},
		{"id": "I", "color": "yellow", "capacity": 4, "position": Vector2i(4, 5), "initial_position": Vector2i(4, 5), "direction": VehicleData.Direction.NORTH},

		{"id": "J", "color": "green",  "capacity": 4, "position": Vector2i(6, 6), "initial_position": Vector2i(6, 6), "direction": VehicleData.Direction.SOUTH},
		{"id": "K", "color": "purple", "capacity": 4, "position": Vector2i(6, 4), "initial_position": Vector2i(6, 4), "direction": VehicleData.Direction.SOUTH},
		{"id": "L", "color": "orange", "capacity": 4, "position": Vector2i(6, 2), "initial_position": Vector2i(6, 2), "direction": VehicleData.Direction.SOUTH},

		{"id": "M", "color": "blue",   "capacity": 4, "position": Vector2i(0, 4), "initial_position": Vector2i(0, 4), "direction": VehicleData.Direction.WEST},
		{"id": "N", "color": "red",    "capacity": 4, "position": Vector2i(7, 4), "initial_position": Vector2i(7, 4), "direction": VehicleData.Direction.EAST},
	]
	lvl.passenger_order = [
		"blue", "blue", "blue", "blue",         # A
		"green", "green", "green", "green",     # D
		"blue", "blue", "blue", "blue",         # G
		"green", "green", "green", "green",     # J
		"blue", "blue", "blue", "blue",         # M
		"red", "red", "red", "red",             # N
		"red", "red", "red", "red",             # B
		"orange", "orange", "orange", "orange", # F
		"purple", "purple", "purple", "purple", # E
		"yellow", "yellow", "yellow", "yellow", # C
		"red", "red", "red", "red",             # H
		"orange", "orange", "orange", "orange", # L
		"purple", "purple", "purple", "purple", # K
		"yellow", "yellow", "yellow", "yellow", # I
	]
	lvl.tutorial_triggers = []
	return lvl
