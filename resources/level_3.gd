extends RefCounted
class_name Level3Resource

## Level 3 — "Crossroad Jam".
## 7x7 board, 10 vehicles (5 color pairs: blue, red, yellow, green, purple), 40 passengers.
## Cross-corridor puzzle requiring timing of crossing lanes.

func build() -> LevelData:
	var lvl := LevelData.new()
	lvl.id = "level_3"
	lvl.display_name = "Level 3: Crossroad Jam"
	lvl.board_size = Vector2i(7, 7)
	lvl.standard_bay_count = 5
	lvl.cell_size = 96.0
	lvl.board_origin = Vector2(60, 320)
	lvl.bay_panel_origin = Vector2(60, 1080)
	lvl.vehicles = [
		{"id": "A", "color": "blue",   "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "B", "color": "yellow", "capacity": 4, "position": Vector2i(1, 4), "initial_position": Vector2i(1, 4), "direction": VehicleData.Direction.NORTH},
		{"id": "C", "color": "red",    "capacity": 4, "position": Vector2i(5, 1), "initial_position": Vector2i(5, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "D", "color": "green",  "capacity": 4, "position": Vector2i(5, 4), "initial_position": Vector2i(5, 4), "direction": VehicleData.Direction.NORTH},
		{"id": "E", "color": "purple", "capacity": 4, "position": Vector2i(0, 3), "initial_position": Vector2i(0, 3), "direction": VehicleData.Direction.WEST},
		{"id": "F", "color": "blue",   "capacity": 4, "position": Vector2i(2, 3), "initial_position": Vector2i(2, 3), "direction": VehicleData.Direction.WEST},
		{"id": "G", "color": "yellow", "capacity": 4, "position": Vector2i(6, 3), "initial_position": Vector2i(6, 3), "direction": VehicleData.Direction.EAST},
		{"id": "H", "color": "purple", "capacity": 4, "position": Vector2i(4, 3), "initial_position": Vector2i(4, 3), "direction": VehicleData.Direction.EAST},
		{"id": "I", "color": "red",    "capacity": 4, "position": Vector2i(3, 5), "initial_position": Vector2i(3, 5), "direction": VehicleData.Direction.SOUTH},
		{"id": "J", "color": "green",  "capacity": 4, "position": Vector2i(3, 2), "initial_position": Vector2i(3, 2), "direction": VehicleData.Direction.SOUTH},
	]
	lvl.passenger_order = [
		"blue", "blue", "blue", "blue",         # A
		"red", "red", "red", "red",             # C
		"purple", "purple", "purple", "purple", # E
		"yellow", "yellow", "yellow", "yellow", # G
		"red", "red", "red", "red",             # I
		"blue", "blue", "blue", "blue",         # F
		"yellow", "yellow", "yellow", "yellow", # B
		"purple", "purple", "purple", "purple", # H
		"green", "green", "green", "green",     # D
		"green", "green", "green", "green",     # J
	]
	lvl.tutorial_triggers = []
	return lvl
