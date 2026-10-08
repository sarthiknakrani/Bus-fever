extends RefCounted
class_name VehicleData

## Data-only description of a vehicle that lives in a level resource.
## Pure data — no scene references. Engine code reads this to build runtime state.

enum Direction { NORTH, SOUTH, EAST, WEST }

## Color id used by visuals and the passenger queue. Strings keep level data
## human-readable and the resource human-editable.
const COLOR_BLUE := "blue"
const COLOR_RED := "red"
const COLOR_YELLOW := "yellow"
const COLOR_GREEN := "green"
const COLOR_PURPLE := "purple"
const COLOR_ORANGE := "orange"

const ALL_COLORS := [
	COLOR_BLUE, COLOR_RED, COLOR_YELLOW, COLOR_GREEN, COLOR_PURPLE, COLOR_ORANGE,
]

static func color_to_rgb(color_id: String) -> Color:
	match color_id:
		COLOR_BLUE: return Color("3a86ff")
		COLOR_RED: return Color("e63946")
		COLOR_YELLOW: return Color("ffd60a")
		COLOR_GREEN: return Color("06d6a0")
		COLOR_PURPLE: return Color("9d4edd")
		COLOR_ORANGE: return Color("fb8500")
		_: return Color.WHITE

static func dir_to_vector(d: int) -> Vector2i:
	match d:
		Direction.NORTH: return Vector2i(0, -1)
		Direction.SOUTH: return Vector2i(0, 1)
		Direction.EAST: return Vector2i(1, 0)
		Direction.WEST: return Vector2i(-1, 0)
		_: return Vector2i.ZERO

static func dir_to_string(d: int) -> String:
	match d:
		Direction.NORTH: return "NORTH"
		Direction.SOUTH: return "SOUTH"
		Direction.EAST: return "EAST"
		Direction.WEST: return "WEST"
		_: return "?"

## Unique id within a level (e.g. "A", "B"). Two-character short.
@export var id: String = ""
## Color string id (one of ALL_COLORS).
@export var color: String = COLOR_BLUE
## Passenger capacity.
@export var capacity: int = 4
## Logical position on the board in (x, y) cells.
@export var position: Vector2i = Vector2i.ZERO
## Initial logical position (used by Restart).
@export var initial_position: Vector2i = Vector2i.ZERO
## Facing direction. Vehicle escapes in this direction when cast.
@export var direction: int = Direction.NORTH

func to_dict() -> Dictionary:
	return {
		"id": id,
		"color": color,
		"capacity": capacity,
		"position": position,
		"initial_position": initial_position,
		"direction": direction,
	}

func from_dict(d: Dictionary) -> void:
	id = String(d.get("id", ""))
	color = String(d.get("color", COLOR_BLUE))
	capacity = int(d.get("capacity", 4))
	var p: Variant = d.get("position", Vector2i.ZERO)
	if p is Vector2i:
		position = p
	else:
		position = Vector2i(int(p.x), int(p.y))
	var ip: Variant = d.get("initial_position", position)
	if ip is Vector2i:
		initial_position = ip
	else:
		initial_position = Vector2i(int(ip.x), int(ip.y))
	direction = int(d.get("direction", Direction.NORTH))

## Compute the cells a vehicle currently occupies. The puzzle uses
## single-cell vehicles for Level 1, but this returns a list so the
## solver still works if future levels use longer vehicles.
func footprint_cells() -> Array[Vector2i]:
	return [position]

## All cells that must be empty (no other vehicle) for the vehicle to
## escape to the board edge. Does NOT include its own cell.
## `board_size` is the (width, height) of the logical grid.
func escape_path_cells(board_size: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d: Vector2i = dir_to_vector(direction)
	var p: Vector2i = position + d
	while _in_bounds(p, board_size):
		out.append(p)
		p += d
	return out

static func _in_bounds(p: Vector2i, sz: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < sz.x and p.y < sz.y

func is_valid() -> Dictionary:
	# Returns {ok: bool, error: String}
	if id == "":
		return {"ok": false, "error": "vehicle id is empty"}
	if not color in ALL_COLORS:
		return {"ok": false, "error": "vehicle %s has unknown color '%s'" % [id, color]}
	if capacity < 1:
		return {"ok": false, "error": "vehicle %s capacity must be >=1" % id}
	return {"ok": true, "error": ""}