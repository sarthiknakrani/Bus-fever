extends RefCounted
class_name Level2Resource

## Level 2 — "Downtown Rush".
## 6x6 board, 8 vehicles (2 each of blue, red, yellow, green), 32 passengers, 5 bays.
## Fast, punchy puzzle introducing interlocking cross traffic.

func build() -> LevelData:
	var lvl := LevelData.new()
	lvl.id = "level_2"
	lvl.display_name = "Level 2: Downtown Rush"
	lvl.board_size = Vector2i(6, 6)
	lvl.standard_bay_count = 5
	lvl.cell_size = 96.0
	lvl.board_origin = Vector2(60, 320)
	lvl.bay_panel_origin = Vector2(60, 1080)
	lvl.vehicles = [
		# Column 1: facing NORTH
		{"id": "A", "color": "blue",   "capacity": 4, "position": Vector2i(1, 1), "initial_position": Vector2i(1, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "B", "color": "red",    "capacity": 4, "position": Vector2i(1, 3), "initial_position": Vector2i(1, 3), "direction": VehicleData.Direction.NORTH},
		# Column 4: facing NORTH
		{"id": "C", "color": "yellow", "capacity": 4, "position": Vector2i(4, 1), "initial_position": Vector2i(4, 1), "direction": VehicleData.Direction.NORTH},
		{"id": "D", "color": "green",  "capacity": 4, "position": Vector2i(4, 3), "initial_position": Vector2i(4, 3), "direction": VehicleData.Direction.NORTH},
		# Column 2: facing SOUTH
		{"id": "E", "color": "red",    "capacity": 4, "position": Vector2i(2, 4), "initial_position": Vector2i(2, 4), "direction": VehicleData.Direction.SOUTH},
		{"id": "F", "color": "blue",   "capacity": 4, "position": Vector2i(2, 2), "initial_position": Vector2i(2, 2), "direction": VehicleData.Direction.SOUTH},
		# Column 3: facing SOUTH
		{"id": "G", "color": "green",  "capacity": 4, "position": Vector2i(3, 4), "initial_position": Vector2i(3, 4), "direction": VehicleData.Direction.SOUTH},
		{"id": "H", "color": "yellow", "capacity": 4, "position": Vector2i(3, 2), "initial_position": Vector2i(3, 2), "direction": VehicleData.Direction.SOUTH},
	]
	lvl.passenger_order = [
		"blue", "blue", "blue", "blue",         # group 1 (A blue)
		"yellow", "yellow", "yellow", "yellow", # group 2 (C yellow)
		"red", "red", "red", "red",             # group 3 (B/E red)
		"green", "green", "green", "green",     # group 4 (D/G green)
		"red", "red", "red", "red",             # group 5 (remaining red)
		"green", "green", "green", "green",     # group 6 (remaining green)
		"blue", "blue", "blue", "blue",         # group 7 (F blue)
		"yellow", "yellow", "yellow", "yellow", # group 8 (H yellow)
	]
	lvl.tutorial_triggers = []
	return lvl
