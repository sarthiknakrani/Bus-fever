extends Resource
class_name CarJamVehicleData

## Authoritative definition of a vehicle in puzzle data.
## Supports arbitrary footprints (1x1, 1x2, 2x1), 4 cardinal movement directions,
## and passenger capacities.

enum Direction {
	UP,
	DOWN,
	LEFT,
	RIGHT
}

const COLOR_BLUE := "blue"
const COLOR_RED := "red"
const COLOR_YELLOW := "yellow"
const COLOR_GREEN := "green"
const COLOR_PURPLE := "purple"
const COLOR_ORANGE := "orange"

@export var id: int = 0
@export var code: String = "A"
@export var anchor: Vector2i = Vector2i.ZERO
@export var initial_anchor: Vector2i = Vector2i.ZERO
@export var footprint: Array[Vector2i] = [Vector2i.ZERO] # Relative offsets from anchor
@export var direction: int = Direction.UP
@export var color_id: String = COLOR_BLUE
@export var capacity: int = 4
@export var vehicle_type: String = "bus"

static func dir_to_vector(dir: int) -> Vector2i:
	match dir:
		Direction.UP:
			return Vector2i(0, -1)
		Direction.DOWN:
			return Vector2i(0, 1)
		Direction.LEFT:
			return Vector2i(-1, 0)
		Direction.RIGHT:
			return Vector2i(1, 0)
		_:
			return Vector2i.ZERO

static func dir_to_string(dir: int) -> String:
	match dir:
		Direction.UP: return "UP"
		Direction.DOWN: return "DOWN"
		Direction.LEFT: return "LEFT"
		Direction.RIGHT: return "RIGHT"
		_: return "?"

static func color_to_rgb(col_id: String) -> Color:
	match col_id:
		COLOR_BLUE: return Color("3b82f6")
		COLOR_RED: return Color("ef4444")
		COLOR_YELLOW: return Color("eab308")
		COLOR_GREEN: return Color("22c55e")
		COLOR_PURPLE: return Color("a855f7")
		COLOR_ORANGE: return Color("f97316")
		_: return Color.WHITE

func get_occupied_cells(pos: Vector2i = anchor) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in footprint:
		cells.append(pos + offset)
	return cells

func clone() -> CarJamVehicleData:
	var copy := CarJamVehicleData.new()
	copy.id = id
	copy.code = code
	copy.anchor = anchor
	copy.initial_anchor = initial_anchor
	copy.footprint = footprint.duplicate()
	copy.direction = direction
	copy.color_id = color_id
	copy.capacity = capacity
	copy.vehicle_type = vehicle_type
	return copy

func to_dict() -> Dictionary:
	var fp_arr: Array = []
	for p in footprint:
		fp_arr.append([p.x, p.y])
	return {
		"id": id,
		"code": code,
		"anchor": [anchor.x, anchor.y],
		"initial_anchor": [initial_anchor.x, initial_anchor.y],
		"footprint": fp_arr,
		"direction": direction,
		"color_id": color_id,
		"capacity": capacity,
		"vehicle_type": vehicle_type
	}

func from_dict(d: Dictionary) -> void:
	id = int(d.get("id", 0))
	code = String(d.get("code", "A"))
	var a = d.get("anchor", [0, 0])
	anchor = Vector2i(int(a[0]), int(a[1]))
	var ia = d.get("initial_anchor", [anchor.x, anchor.y])
	initial_anchor = Vector2i(int(ia[0]), int(ia[1]))
	direction = int(d.get("direction", Direction.UP))
	color_id = String(d.get("color_id", COLOR_BLUE))
	capacity = int(d.get("capacity", 4))
	vehicle_type = String(d.get("vehicle_type", "bus"))
	footprint.clear()
	var raw_fp = d.get("footprint", [[0, 0]])
	for p in raw_fp:
		footprint.append(Vector2i(int(p[0]), int(p[1])))
