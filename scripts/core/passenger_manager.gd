extends RefCounted
class_name PassengerManager

## Owns the passenger queue and per-passenger state. The queue is the
## deterministic ordered list of group demands that must be served in
## order; one element == one waiting passenger who must board a matching
## bus.

enum PassengerState { WAITING, RESERVED, SEATED, COMPLETED }

class Passenger:
	var id: int
	var color: String = ""
	var state: int = PassengerState.WAITING
	var reserved_by_bus: String = ""
	func snapshot() -> Dictionary:
		return {"id": id, "color": color, "state": state, "reserved_by_bus": reserved_by_bus}
	func restore(d: Dictionary) -> void:
		id = int(d["id"])
		color = String(d["color"])
		state = int(d["state"])
		reserved_by_bus = String(d["reserved_by_bus"])

var _passengers: Array[Passenger] = []
var _active_index: int = 0

func setup(order: Array[String]) -> void:
	_passengers.clear()
	for i in order.size():
		var p := Passenger.new()
		p.id = i
		p.color = order[i]
		p.state = PassengerState.WAITING
		p.reserved_by_bus = ""
		_passengers.append(p)
	_active_index = 0

func size() -> int:
	return _passengers.size()

func all_completed() -> bool:
	for p in _passengers:
		if p.state != PassengerState.COMPLETED:
			return false
	return true

func active_color() -> String:
	# The next unserved demand. Returns "" if queue is fully served.
	while _active_index < _passengers.size() and \
		  _passengers[_active_index].state == PassengerState.COMPLETED:
		_active_index += 1
	if _active_index >= _passengers.size():
		return ""
	return _passengers[_active_index].color

func active_index() -> int:
	return _active_index

## Reserves the next N passengers of `color` for `bus_id`. Returns the
## number reserved, or 0 if reservation failed (e.g. wrong color / not at
## front of queue). Reservation NEVER crosses the active queue index.
func reserve_next_for(bus_id: String, color: String, n: int) -> int:
	# Make sure _active_index is current.
	while _active_index < _passengers.size() and \
		  _passengers[_active_index].state == PassengerState.COMPLETED:
		_active_index += 1
	if _active_index >= _passengers.size():
		return 0
	# We may only reserve passengers that are at the front of the queue.
	# However, the rule says "Only the current eligible/front group may
	# board". In this puzzle design, each passenger is its own group of 1.
	# So we may only reserve passengers whose color matches the active
	# color AND they are the next unserved one.
	var reserved := 0
	var idx := _active_index
	while reserved < n and idx < _passengers.size():
		var p := _passengers[idx]
		if p.state != PassengerState.WAITING:
			break
		if p.color != color:
			break
		if p.reserved_by_bus != "" and p.reserved_by_bus != bus_id:
			return 0  # double reservation guard
		p.state = PassengerState.RESERVED
		p.reserved_by_bus = bus_id
		reserved += 1
		idx += 1
	if reserved == 0:
		return 0
	return reserved

## Marks N reserved passengers as seated for `bus_id`. Returns count.
func confirm_seated(bus_id: String, n: int) -> int:
	var seated := 0
	for p in _passengers:
		if seated >= n:
			break
		if p.state == PassengerState.RESERVED and p.reserved_by_bus == bus_id:
			p.state = PassengerState.SEATED
			seated += 1
	return seated

## Marks all SEATED passengers of `bus_id` as COMPLETED and advances
## active_index past them.
func complete_for(bus_id: String) -> int:
	var completed := 0
	for p in _passengers:
		if p.state == PassengerState.SEATED and p.reserved_by_bus == bus_id:
			p.state = PassengerState.COMPLETED
			p.reserved_by_bus = ""
			completed += 1
	_active_index = 0
	while _active_index < _passengers.size() and \
		  _passengers[_active_index].state == PassengerState.COMPLETED:
		_active_index += 1
	return completed

func release_reservations_for(bus_id: String) -> void:
	# In case a bus departs without ever boarding (e.g. deadlock recovery)
	for p in _passengers:
		if p.state == PassengerState.RESERVED and p.reserved_by_bus == bus_id:
			p.state = PassengerState.WAITING
			p.reserved_by_bus = ""

func passenger_at(idx: int) -> Passenger:
	if idx < 0 or idx >= _passengers.size():
		return null
	return _passengers[idx]

func snapshot() -> Array:
	var out: Array = []
	for p in _passengers:
		out.append(p.snapshot())
	return out

func restore(snap: Array, active_idx: int) -> void:
	_passengers.clear()
	for d in snap:
		var p := Passenger.new()
		p.restore(d)
		_passengers.append(p)
	_active_index = active_idx