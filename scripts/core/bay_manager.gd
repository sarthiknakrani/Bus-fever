extends RefCounted
class_name BayManager

## Manages the pool of parking bays. The board normalises vehicle → bay
## allocation so we always know which bus is in which bay.

enum State { FREE, RESERVED, OCCUPIED }

class Bay:
	var index: int
	var state: int = State.FREE
	var vehicle_id: String = ""
	func snapshot() -> Dictionary:
		return {"index": index, "state": state, "vehicle_id": vehicle_id}
	func restore(d: Dictionary) -> void:
		index = int(d["index"])
		state = int(d["state"])
		vehicle_id = String(d["vehicle_id"])

var _bays: Array[Bay] = []
var _extra_bay_unlocked: bool = false

func setup(standard_bay_count: int) -> void:
	_bays.clear()
	for i in standard_bay_count:
		var b := Bay.new()
		b.index = i
		b.state = State.FREE
		b.vehicle_id = ""
		_bays.append(b)
	_extra_bay_unlocked = false

func bay_count() -> int:
	return _bays.size()

func is_extra_bay_active() -> bool:
	return _extra_bay_unlocked and _bays.size() > 5

func unlock_extra_bay() -> bool:
	if _extra_bay_unlocked:
		return false
	if _bays.size() >= 6:
		_extra_bay_unlocked = true
		return false
	var b := Bay.new()
	b.index = _bays.size()
	b.state = State.FREE
	b.vehicle_id = ""
	_bays.append(b)
	_extra_bay_unlocked = true
	return true

func reset_extra_bay() -> void:
	_extra_bay_unlocked = false
	while _bays.size() > 5:
		_bays.pop_back()

func bay(i: int) -> Bay:
	if i < 0 or i >= _bays.size():
		return null
	return _bays[i]

func find_free_bay() -> int:
	for i in _bays.size():
		if _bays[i].state == State.FREE:
			return i
	return -1

func first_free_bay_index() -> int:
	return find_free_bay()

## Returns bay index allocated (reserves immediately) or -1 if no bay free.
func reserve_for(vehicle_id: String) -> int:
	var idx := find_free_bay()
	if idx == -1:
		return -1
	_bays[idx].state = State.RESERVED
	_bays[idx].vehicle_id = vehicle_id
	return idx

func confirm_occupancy(bay_index: int) -> void:
	if bay_index < 0 or bay_index >= _bays.size():
		return
	_bays[bay_index].state = State.OCCUPIED

func release(bay_index: int) -> void:
	if bay_index < 0 or bay_index >= _bays.size():
		return
	_bays[bay_index].state = State.FREE
	_bays[bay_index].vehicle_id = ""

func get_bay_for(vehicle_id: String) -> int:
	for i in _bays.size():
		if _bays[i].vehicle_id == vehicle_id:
			return i
	return -1

func has_any_waiting_matching(color: String) -> int:
	# returns bay index of lowest-order waiting bus whose color matches
	for i in _bays.size():
		if _bays[i].state == State.OCCUPIED and _bays[i].vehicle_id != "":
			return i  # caller compares color from vehicles dict
	return -1

func snapshot() -> Array:
	var out: Array = []
	for b in _bays:
		out.append(b.snapshot())
	return out

func restore(snap: Array) -> void:
	_bays.clear()
	for d in snap:
		var b := Bay.new()
		b.restore(d)
		_bays.append(b)