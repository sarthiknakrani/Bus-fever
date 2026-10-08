extends RefCounted
class_name CarJamLevelValidator

## Validates puzzle level integrity before running or solving.
## Ensures strict adherence to board boundaries, non-overlapping starting
## footprints, mathematical passenger demand conservation, and unique IDs.

static func validate(lvl: CarJamLevelData) -> Dictionary:
	var errors: Array[String] = []

	if lvl == null:
		return {"ok": false, "errors": ["Level data is null"]}

	if lvl.board_size.x <= 0 or lvl.board_size.y <= 0:
		errors.append("Invalid board size: %s" % lvl.board_size)

	if lvl.parking_slots_count < 1:
		errors.append("Invalid parking slot count: %d" % lvl.parking_slots_count)

	if lvl.vehicles.is_empty():
		errors.append("Level has no vehicles defined")

	if lvl.passenger_groups.is_empty():
		errors.append("Level has no passenger groups defined")

	# 1. Unique vehicle IDs and bounds check
	var seen_ids: Dictionary = {}
	var occupied_cells: Dictionary = {} # cell -> vehicle_id

	for v in lvl.vehicles:
		if v.id in seen_ids:
			errors.append("Duplicate vehicle ID: %d (code %s)" % [v.id, v.code])
		seen_ids[v.id] = true

		if v.capacity <= 0:
			errors.append("Vehicle %s has invalid capacity: %d" % [v.code, v.capacity])

		var cells := v.get_occupied_cells(v.anchor)
		if cells.is_empty():
			errors.append("Vehicle %s has empty footprint" % v.code)

		for c in cells:
			if c.x < 0 or c.y < 0 or c.x >= lvl.board_size.x or c.y >= lvl.board_size.y:
				errors.append("Vehicle %s cell %s out of board bounds %s" % [v.code, c, lvl.board_size])
			if c in occupied_cells:
				errors.append("Vehicle %s overlaps vehicle ID %s at cell %s" % [v.code, occupied_cells[c], c])
			occupied_cells[c] = v.id

	# 2. Mathematical Demand Conservation (Color capacities vs demands)
	var caps := lvl.get_total_capacity_by_color()
	var demands := lvl.get_total_demand_by_color()

	var all_colors: Dictionary = {}
	for c in caps.keys(): all_colors[c] = true
	for c in demands.keys(): all_colors[c] = true

	for col in all_colors.keys():
		var cap: int = caps.get(col, 0)
		var dem: int = demands.get(col, 0)
		if cap != dem:
			errors.append("Color mismatch for '%s': capacity=%d != demand=%d" % [col, cap, dem])

	return {
		"ok": errors.is_empty(),
		"errors": errors
	}
