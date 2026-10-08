extends RefCounted
class_name VehicleModel

## Authoritative runtime state for a single vehicle.
## Tracks lifecycle state, board anchor, occupied footprint cells,
## passenger capacity, and assigned parking slot.

enum VehicleState {
	ON_BOARD,
	EXITING,
	PARKED,
	BOARDING,
	FULL,
	DEPARTING,
	COMPLETED
}

var id: int = 0
var code: String = "A"
var anchor: Vector2i = Vector2i.ZERO
var initial_anchor: Vector2i = Vector2i.ZERO
var footprint: Array[Vector2i] = [Vector2i.ZERO]
var direction: int = CarJamVehicleData.Direction.UP
var color_id: String = CarJamVehicleData.COLOR_BLUE
var capacity: int = 4
var passenger_occupancy: int = 0
var state: int = VehicleState.ON_BOARD
var reserved_slot: int = -1
var vehicle_type: String = "bus"

func setup_from_data(vd: CarJamVehicleData) -> void:
	id = vd.id
	code = vd.code
	anchor = vd.anchor
	initial_anchor = vd.initial_anchor
	footprint = vd.footprint.duplicate()
	direction = vd.direction
	color_id = vd.color_id
	capacity = vd.capacity
	vehicle_type = vd.vehicle_type
	passenger_occupancy = 0
	state = VehicleState.ON_BOARD
	reserved_slot = -1

func reset() -> void:
	anchor = initial_anchor
	passenger_occupancy = 0
	state = VehicleState.ON_BOARD
	reserved_slot = -1

func get_occupied_cells(pos: Vector2i = anchor) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in footprint:
		cells.append(pos + offset)
	return cells

func remaining_capacity() -> int:
	return maxi(0, capacity - passenger_occupancy)

func is_full() -> bool:
	return passenger_occupancy >= capacity

func board(count: int) -> int:
	var can_take := remaining_capacity()
	var taken := mini(count, can_take)
	passenger_occupancy += taken
	return taken

func can_dispatch() -> bool:
	return state == VehicleState.ON_BOARD

func is_active_in_parking() -> bool:
	return state == VehicleState.PARKED or state == VehicleState.BOARDING

func snapshot() -> Dictionary:
	return {
		"id": id,
		"anchor_x": anchor.x,
		"anchor_y": anchor.y,
		"state": state,
		"reserved_slot": reserved_slot,
		"passenger_occupancy": passenger_occupancy
	}

func restore(d: Dictionary) -> void:
	anchor = Vector2i(int(d["anchor_x"]), int(d["anchor_y"]))
	state = int(d["state"])
	reserved_slot = int(d["reserved_slot"])
	passenger_occupancy = int(d["passenger_occupancy"])
