extends RefCounted
class_name CarJamParkingManager

## Manages the parking bays where dispatched vehicles wait to board passengers.
## Supports three bay kinds: REGULAR (unlocked working bay), PLUS (locked green-bordered
## bay that unlocks mid-level via dispatch threshold), and VIP (slot 0, reserved for the
## VIP booster feature). Atomic reservations and arrival/release lifecycles preserved.

enum SlotState {
	FREE = 0,
	EMPTY = 0,
	RESERVED = 1,
	OCCUPIED = 2,
	DEPARTING = 3,
	RELEASING = 3
}

## Bay kind taxonomy. Slot 0 is implicitly VIP per the default setup().
## Plus bays start locked and unlock in-level via dispatch threshold.
enum BayKind {
	REGULAR = 0,
	PLUS = 1,
	VIP = 2
}

# Compatibility aliases on class level
const EMPTY: int = SlotState.FREE
const RELEASING: int = SlotState.DEPARTING

class ParkingSlot:
	var slot_id: int = 0
	var state: int = SlotState.FREE
	var vehicle_id: int = -1
	var is_unlocked: bool = false
	var bay_kind: int = BayKind.REGULAR

	func _init(id: int, kind: int = BayKind.REGULAR) -> void:
		slot_id = id
		bay_kind = kind
		state = SlotState.FREE
		vehicle_id = -1
		# Default unlock rule:
		#  - SLOT 0        → VIP bay, stays locked (only the VIP Booster can unlock it)
		#  - PLUS bay      → starts locked; unlock in-level via unlock_plus_bay()
		#  - everything    → unlocked by default
		if slot_id == 0:
			bay_kind = BayKind.VIP
			is_unlocked = false
		elif bay_kind == BayKind.PLUS:
			is_unlocked = false
		elif slot_id >= 1:
			is_unlocked = true
		else:
			is_unlocked = false

	func is_available() -> bool:
		return state == SlotState.FREE and is_unlocked

	func is_plus_locked() -> bool:
		return bay_kind == BayKind.PLUS and not is_unlocked

	func snapshot() -> Dictionary:
		return {
			"slot_id": slot_id,
			"state": state,
			"vehicle_id": vehicle_id,
			"is_unlocked": is_unlocked,
			"bay_kind": bay_kind
		}

	func restore(d: Dictionary) -> void:
		slot_id = int(d["slot_id"])
		state = int(d["state"])
		vehicle_id = int(d["vehicle_id"])
		if d.has("is_unlocked"):
			is_unlocked = bool(d["is_unlocked"])
		if d.has("bay_kind"):
			bay_kind = int(d["bay_kind"])

var _slots: Array[ParkingSlot] = []

func setup(slot_count: int = 4, custom_unlocked_ids: Array[int] = [], plus_slot_ids: Array[int] = []) -> void:
	_slots.clear()
	for i in slot_count:
		# Default to REGULAR; upgrade specific IDs to PLUS when listed.
		var kind: int = BayKind.REGULAR
		if i in plus_slot_ids:
			kind = BayKind.PLUS
		var slot := ParkingSlot.new(i, kind)
		# Custom unlock list is the legacy way to mark specific slots as unlocked.
		# PLUS bays deliberately stay locked until unlock_plus_bay() is called via
		# in-level progression; we do NOT honor them in custom_unlocked_ids.
		if not custom_unlocked_ids.is_empty() and slot.bay_kind != BayKind.PLUS:
			slot.is_unlocked = custom_unlocked_ids.has(i)
		_slots.append(slot)

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

func unlock_slot(slot_id: int) -> void:
	if slot_id >= 0 and slot_id < _slots.size():
		_slots[slot_id].is_unlocked = true

## Unlock a PLUS bay by slot_id. Idempotent: returns false if not a PLUS bay, already
## unlocked, or out of range. Caller is responsible for emitting parking_updated.
func unlock_plus_bay(slot_id: int) -> bool:
	if slot_id < 0 or slot_id >= _slots.size():
		return false
	var slot: ParkingSlot = _slots[slot_id]
	if slot.bay_kind != BayKind.PLUS:
		return false
	if slot.is_unlocked:
		return false
	slot.is_unlocked = true
	return true

## Returns true when slot_id refers to a PLUS bay that hasn't been unlocked yet.
func is_plus_locked(slot_id: int) -> bool:
	if slot_id < 0 or slot_id >= _slots.size():
		return false
	return _slots[slot_id].is_plus_locked()

## Returns the count of PLUS bays still locked. Used by the controller to decide when
## to award the next green "+" bay as a reward for sustained progress.
func get_plus_locked_count() -> int:
	var n: int = 0
	for s in _slots:
		if s.is_plus_locked():
			n += 1
	return n

## Returns the count of PLUS bays already unlocked.
func get_plus_unlocked_count() -> int:
	var n: int = 0
	for s in _slots:
		if s.bay_kind == BayKind.PLUS and s.is_unlocked:
			n += 1
	return n

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
