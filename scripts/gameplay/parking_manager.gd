extends RefCounted
class_name CarJamParkingManager

## Manages the parking bays where dispatched vehicles wait to board passengers.
## Exactly 4 slots for Level 1, supporting atomic reservations, double-reservation
## prevention, and clean arrival/release lifecycles.

enum SlotState {
	FREE = 0,
	EMPTY = 0,
	RESERVED = 1,
	OCCUPIED = 2,
	DEPARTING = 3,
	RELEASING = 3
}

# Compatibility aliases on class level
const EMPTY: int = SlotState.FREE
const RELEASING: int = SlotState.DEPARTING

class ParkingSlot:
	var slot_id: int = 0
	var state: int = SlotState.FREE
	var vehicle_id: int = -1
	var is_unlocked: bool = false

	func _init(id: int) -> void:
		slot_id = id
		state = SlotState.FREE
		vehicle_id = -1
		# Default unlock rule: Slot 0 is VIP (locked), Slots 1-3 are normal (unlocked), Slots 4+ are locked
		if id >= 1 and id <= 3:
			is_unlocked = true
		else:
			is_unlocked = false

	func is_available() -> bool:
		return state == SlotState.FREE and is_unlocked


	func snapshot() -> Dictionary:
		return {
			"slot_id": slot_id,
			"state": state,
			"vehicle_id": vehicle_id
		}

	func restore(d: Dictionary) -> void:
		slot_id = int(d["slot_id"])
		state = int(d["state"])
		vehicle_id = int(d["vehicle_id"])

var _slots: Array[ParkingSlot] = []

func setup(slot_count: int = 4) -> void:
	_slots.clear()
	for i in slot_count:
		_slots.append(ParkingSlot.new(i))

func get_slot_count() -> int:
	return _slots.size()

func get_slot(slot_id: int) -> ParkingSlot:
	if slot_id < 0 or slot_id >= _slots.size():
		return null
	return _slots[slot_id]

func is_full() -> bool:
	return find_available_slot() == -1

func get_unlocked_slot_count() -> int:
	var count := 0
	for s in _slots:
		if s.is_unlocked:
			count += 1
	return count

func get_unlocked_slot_ids() -> Array[int]:
	var ids: Array[int] = []
	for s in _slots:
		if s.is_unlocked:
			ids.append(s.slot_id)
	return ids

func is_slot_unlocked(slot_id: int) -> bool:
	if slot_id >= 0 and slot_id < _slots.size():
		return _slots[slot_id].is_unlocked
	return false

func get_available_slot_count() -> int:
	var count := 0
	for s in _slots:
		if s.is_available():
			count += 1
	return count

func find_available_slot() -> int:
	for s in _slots:
		if s.is_available():
			return s.slot_id
	return -1

## Atomically reserves the lowest-indexed available slot for vehicle_id.
## Prevents double-reservation. Returns slot_id or -1 if full.
func reserve_slot(vehicle_id: int) -> int:
	# Check if this vehicle already has a slot reserved
	for s in _slots:
		if s.vehicle_id == vehicle_id:
			return -1 # Already reserved!

	var available_id := find_available_slot()
	if available_id == -1:
		return -1

	var slot: ParkingSlot = _slots[available_id]
	slot.state = SlotState.RESERVED
	slot.vehicle_id = vehicle_id
	return available_id

## Called when vehicle movement reaches the parking slot.
## Strictly validates ownership.
func confirm_arrival(slot_id: int, vehicle_id: int) -> bool:
	if slot_id < 0 or slot_id >= _slots.size():
		return false
	var slot: ParkingSlot = _slots[slot_id]
	if slot.vehicle_id != vehicle_id or slot.state != SlotState.RESERVED:
		return false
	slot.state = SlotState.OCCUPIED
	return true

## Marks a slot as DEPARTING when vehicle starts departing.
## The slot remains occupied/unavailable until departure is 100% complete.
func mark_departing(slot_id: int, vehicle_id: int = -1) -> void:
	if slot_id >= 0 and slot_id < _slots.size():
		var slot: ParkingSlot = _slots[slot_id]
		if vehicle_id == -1 or slot.vehicle_id == vehicle_id:
			slot.state = SlotState.DEPARTING

func mark_releasing(slot_id: int) -> void:
	mark_departing(slot_id)

## Releases the slot back to FREE once bus has fully completed departure offscreen.
func release_slot(slot_id: int, vehicle_id: int = -1) -> bool:
	if slot_id >= 0 and slot_id < _slots.size():
		var slot: ParkingSlot = _slots[slot_id]
		if vehicle_id != -1 and slot.vehicle_id != vehicle_id:
			return false # Ownership mismatch, prevent stale release
		slot.state = SlotState.FREE
		slot.vehicle_id = -1
		return true
	return false

func get_slot_for_vehicle(vehicle_id: int) -> int:
	for s in _slots:
		if s.vehicle_id == vehicle_id:
			return s.slot_id
	return -1

func snapshot() -> Array:
	var snap: Array = []
	for s in _slots:
		snap.append(s.snapshot())
	return snap

func restore(snap: Array) -> void:
	for i in mini(_slots.size(), snap.size()):
		_slots[i].restore(snap[i])
