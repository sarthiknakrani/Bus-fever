extends RefCounted
class_name Level4Resource

## Level 4 — "Highway Roundabout".
## 7x7 board, 12 vehicles (2 each of 6 colors: blue, red, yellow, green, purple, orange), 48 passengers, 5 bays.
## Circular ring layout with central blocker buses.

func build() -> LevelData:
	var lvl := LevelData.new()
	lvl.id = "level_4"
	lvl.display_name = "Level 4: Highway Roundabout"
	lvl.board_size = Vector2i(7, 7)
	lvl.standard_bay_count = 5
	lvl.cell_size = 96.0
	lvl.board_origin = Vector2(60, 320)
	lvl.bay_panel_origin = Vector2(60, 1080)
	lvl.vehicles = [
		# Ring Northbound
		{"id": "A", "color": "orange", "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "B", "color": "blue",   "capacity": 4, "position": Vector2i(1, 4), "initial_position": Vector2i(1, 4), "direction": VehicleData.Direction.NORTH},
		# Ring Southbound
		{"id": "C", "color": "green",  "capacity": 4, "position": Vector2i(5, 5), "initial_position": Vector2i(5, 5), "direction": VehicleData.Direction.SOUTH},
		{"id": "D", "color": "purple", "capacity": 4, "position": Vector2i(5, 2), "initial_position": Vector2i(5, 2), "direction": VehicleData.Direction.SOUTH},
		# Ring Eastbound
		{"id": "E", "color": "red",    "capacity": 4, "position": Vector2i(5, 1), "initial_position": Vector2i(5, 1), "direction": VehicleData.Direction.EAST},
		{"id": "F", "color": "yellow", "capacity": 4, "position": Vector2i(2, 1), "initial_position": Vector2i(2, 1), "direction": VehicleData.Direction.EAST},
		# Ring Westbound
		{"id": "G", "color": "blue",   "capacity": 4, "position": Vector2i(1, 5), "initial_position": Vector2i(1, 5), "direction": VehicleData.Direction.WEST},
		{"id": "H", "color": "orange", "capacity": 4, "position": Vector2i(4, 5), "initial_position": Vector2i(4, 5), "direction": VehicleData.Direction.WEST},
		# Center cross
		{"id": "I", "color": "yellow", "capacity": 4, "position": Vector2i(3, 1), "initial_position": Vector2i(3, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "J", "color": "green",  "capacity": 4, "position": Vector2i(3, 5), "initial_position": Vector2i(3, 5), "direction": VehicleData.Direction.SOUTH},
		{"id": "K", "color": "purple", "capacity": 4, "position": Vector2i(1, 3), "initial_position": Vector2i(1, 3), "direction": VehicleData.Direction.WEST},
		{"id": "L", "color": "red",    "capacity": 4, "position": Vector2i(5, 3), "initial_position": Vector2i(5, 3), "direction": VehicleData.Direction.EAST},
	]
	lvl.passenger_order = [
		"orange", "orange", "orange", "orange", # A
		"green", "green", "green", "green",     # C
		"red", "red", "red", "red",             # E
		"blue", "blue", "blue", "blue",         # G
		"yellow", "yellow", "yellow", "yellow", # I
		"green", "green", "green", "green",     # J
		"purple", "purple", "purple", "purple", # K
		"red", "red", "red", "red",             # L
		"blue", "blue", "blue", "blue",         # B
		"purple", "purple", "purple", "purple", # D
		"yellow", "yellow", "yellow", "yellow", # F
		"orange", "orange", "orange", "orange", # H
	]
	lvl.tutorial_triggers = []
	return lvl
