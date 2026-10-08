extends RefCounted
class_name Board

## Authoritative logical occupancy of the puzzle grid. Single owner of
## "who is in cell Y" — every other system defers to this when checking
## escape paths, overlapping, etc. Physics and visuals are NOT gameplay
## authority.

var _size: Vector2i = Vector2i.ZERO
## cell_owner[y][x] = vehicle_id or "" if empty.
var _cell_owner: Array = []

func setup(size: Vector2i) -> void:
	_size = size
	_cell_owner.clear()
	_cell_owner.resize(size.y)
	for y in size.y:
		var row: Array = []
		row.resize(size.x)
		row.fill("")
		_cell_owner[y] = row

func size() -> Vector2i:
	return _size

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < _size.x and p.y < _size.y

func is_empty(p: Vector2i) -> bool:
	return in_bounds(p) and _cell_owner[p.y][p.x] == ""

func owner_at(p: Vector2i) -> String:
	if not in_bounds(p):
		return ""
	return String(_cell_owner[p.y][p.x])

func place(vehicle_id: String, p: Vector2i) -> bool:
	if not in_bounds(p):
		return false
	if _cell_owner[p.y][p.x] != "" and _cell_owner[p.y][p.x] != vehicle_id:
		return false
	_cell_owner[p.y][p.x] = vehicle_id
	return true

func clear(p: Vector2i) -> void:
	if not in_bounds(p):
		return
	_cell_owner[p.y][p.x] = ""

func clear_vehicle(vehicle_id: String) -> void:
	for y in _size.y:
		for x in _size.x:
			if _cell_owner[y][x] == vehicle_id:
				_cell_owner[y][x] = ""

## Returns true if every cell in the path is empty (no other vehicle).
## The vehicle's own current cell is not part of the path.
func escape_path_clear(vehicle_id: String, path: Array[Vector2i]) -> bool:
	for c in path:
		if not in_bounds(c):
			return false
		var o: String = String(_cell_owner[c.y][c.x])
		if o != "" and o != vehicle_id:
			return false
	return true

func snapshot() -> Array:
	var snap: Array = []
	for y in _size.y:
		var row: Array = []
		row.resize(_size.x)
		row.fill("")
		for x in _size.x:
			row[x] = _cell_owner[y][x]
		snap.append(row)
	return snap

func restore(snap: Array) -> void:
	_cell_owner.clear()
	_cell_owner.resize(_size.y)
	for y in _size.y:
		var row: Array = []
		row.resize(_size.x)
		row.fill("")
		if y < snap.size():
			var sr: Array = snap[y]
			for x in min(_size.x, sr.size()):
				row[x] = sr[x]
		_cell_owner[y] = row