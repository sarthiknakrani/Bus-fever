extends RefCounted
class_name Vehicle

## Runtime state for a single vehicle. Owned by LevelController; UI
## vehicle nodes bind to one of these.

enum State {
	IDLE,
	BLOCKED,
	AVAILABLE,
	SELECTED,
	MOVING,
	WAITING,
	BOARDING,
	FULL,
	DEPARTING,
	COMPLETED,
}

class Snapshot:
	var index: int
	var state: int
	var position: Vector2i
	var bay_index: int
	var current_passengers: int
	func from_vehicle(v: Vehicle) -> void:
		index = v.index
		state = v.state
		position = v.position
		bay_index = v.bay_index
		current_passengers = v.current_passengers
	func to_vehicle(v: Vehicle) -> void:
		v.state = state
		v.position = position
		v.bay_index = bay_index
		v.current_passengers = current_passengers

@export var index: int = -1
var data
var state: int = State.IDLE
var position: Vector2i = Vector2i.ZERO
var initial_position: Vector2i = Vector2i.ZERO
var direction: int = VehicleData.Direction.NORTH
var capacity: int = 4
var current_passengers: int = 0
var color: String = "blue"
var id: String = ""
var bay_index: int = -1
var length: int = 1

func setup(idx: int, vd: VehicleData) -> void:
	index = idx
	data = vd
	id = vd.id
	capacity = vd.capacity
	color = vd.color
	direction = vd.direction
	position = vd.position
	initial_position = vd.initial_position
	length = vd.length if ("length" in vd) else 1
	state = State.IDLE
	current_passengers = 0
	bay_index = -1

func reset() -> void:
	position = initial_position
	state = State.IDLE
	current_passengers = 0
	bay_index = -1

func remaining_seats() -> int:
	return maxi(0, capacity - current_passengers)

func remaining_count() -> int:
	return maxi(0, capacity - current_passengers)

func boarded_count() -> int:
	return current_passengers

func is_full() -> bool:
	return current_passengers >= capacity

func is_on_board() -> bool:
	return state == State.IDLE or state == State.BLOCKED or state == State.AVAILABLE or state == State.SELECTED

func is_in_bay() -> bool:
	return state == State.WAITING or state == State.BOARDING or state == State.FULL or state == State.DEPARTING

func is_transitioning() -> bool:
	return state == State.MOVING or state == State.BOARDING or state == State.DEPARTING or state == State.SELECTED

func make_snapshot() -> Snapshot:
	var s := Snapshot.new()
	s.from_vehicle(self)
	return s

func restore_snapshot(s: Snapshot) -> void:
	s.to_vehicle(self)

func state_name() -> String:
	return [
		"IDLE", "BLOCKED", "AVAILABLE", "SELECTED",
		"MOVING", "WAITING", "BOARDING", "FULL", "DEPARTING", "COMPLETED",
	][state]