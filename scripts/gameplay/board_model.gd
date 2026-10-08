extends RefCounted
class_name CarJamBoardModel

## Authoritative logical occupancy and swept-corridor collision engine.
## Maps grid cells (x, y) to vehicle IDs (-1 for empty).
## Enforces exact swept-footprint collision along escape directions.

var _size: Vector2i = Vector2i(7, 7)
## _grid[y][x] = vehicle_id (int) or -1 if empty
var _grid: Array = []

func setup(size: Vector2i) -> void:
	_size = size
	_grid.clear()
	_grid.resize(_size.y)
	for y in _size.y:
		var row: Array = []
		row.resize(_size.x)
		row.fill(-1)
		_grid[y] = row

func get_size() -> Vector2i:
	return _size

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < _size.x and p.y < _size.y

func is_cell_empty(p: Vector2i) -> bool:
	return in_bounds(p) and _grid[p.y][p.x] == -1

func get_vehicle_at(p: Vector2i) -> int:
	if not in_bounds(p):
		return -1
	return int(_grid[p.y][p.x])

func place_vehicle(v: VehicleModel) -> bool:
	var cells := v.get_occupied_cells()
	# Check all cells first
	for c in cells:
		if not in_bounds(c):
			return false
		var curr: int = _grid[c.y][c.x]
		if curr != -1 and curr != v.id:
			return false
	# Commit placement
	for c in cells:
		_grid[c.y][c.x] = v.id
	return true

func remove_vehicle(vehicle_id: int) -> void:
	for y in _size.y:
		for x in _size.x:
			if _grid[y][x] == vehicle_id:
				_grid[y][x] = -1

func clear_cell(p: Vector2i) -> void:
	if in_bounds(p):
		_grid[p.y][p.x] = -1

## Authoritative Swept-Footprint Escape Corridor Validation.
## Slides the full vehicle footprint step-by-step along its escape vector.
## If any swept cell hits another vehicle, returns { "can_escape": false, "blocker_id": id }.
## If all footprint cells clear the board boundaries unobstructed, returns { "can_escape": true }.
func check_swept_escape(v: VehicleModel) -> Dictionary:
	if v == null or not v.can_dispatch():
		return {"can_escape": false, "blocker_id": -1, "swept_corridor": []}

	var d: Vector2i = CarJamVehicleData.dir_to_vector(v.direction)
	if d == Vector2i.ZERO:
		return {"can_escape": false, "blocker_id": -1, "swept_corridor": []}

	var initial_cells := v.get_occupied_cells()
	var swept_corridor: Array[Vector2i] = []
	var step := 1
	var max_steps: int = maxi(_size.x, _size.y) + 4

	while step <= max_steps:
		var any_in_bounds := false
		for base_cell in initial_cells:
			var swept_cell := base_cell + (d * step)
			if in_bounds(swept_cell):
				any_in_bounds = true
				var occupant: int = _grid[swept_cell.y][swept_cell.x]
				if occupant != -1 and occupant != v.id:
					# Real collision! Swept footprint blocked by another vehicle
					return {
						"can_escape": false,
						"blocker_id": occupant,
						"collision_cell": swept_cell,
						"swept_corridor": swept_corridor
					}
				if not swept_cell in swept_corridor and not swept_cell in initial_cells:
					swept_corridor.append(swept_cell)

		if not any_in_bounds:
			# Entire footprint has crossed outside board boundaries without collision
			return {
				"can_escape": true,
				"blocker_id": -1,
				"collision_cell": Vector2i(-1, -1),
				"swept_corridor": swept_corridor
			}

		step += 1

	return {"can_escape": false, "blocker_id": -1, "swept_corridor": swept_corridor}

func snapshot() -> Array:
	var snap: Array = []
	for y in _size.y:
		var row: Array = []
		row.resize(_size.x)
		for x in _size.x:
			row[x] = _grid[y][x]
		snap.append(row)
	return snap

func restore(snap: Array) -> void:
	for y in _size.y:
		if y < snap.size():
			var r: Array = snap[y]
			for x in _size.x:
				if x < r.size():
					_grid[y][x] = r[x]
