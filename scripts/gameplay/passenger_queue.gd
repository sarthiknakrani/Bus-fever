extends RefCounted
class_name CarJamPassengerQueue

## Authoritative ordered passenger queue model.
## Enforces that passengers are strictly boarded in queue order from the head group.
## Deeper groups cannot board until preceding groups are completely served.

var _groups: Array[PassengerGroupData] = []
var _head_index: int = 0

func setup(groups: Array[PassengerGroupData]) -> void:
	_groups.clear()
	for g in groups:
		_groups.append(g.clone())
	_head_index = 0

func get_head_group() -> PassengerGroupData:
	while _head_index < _groups.size() and _groups[_head_index].is_empty():
		_head_index += 1
	if _head_index >= _groups.size():
		return null
	return _groups[_head_index]

func get_head_color() -> String:
	var h := get_head_group()
	return h.color_id if h != null else ""

func get_head_index() -> int:
	get_head_group() # updates _head_index
	return _head_index

func consume_head(amount: int) -> int:
	var h := get_head_group()
	if h == null:
		return 0
	var actual := h.board(amount)
	# Advance if group is empty
	if h.is_empty():
		_head_index += 1
	return actual

func is_empty() -> bool:
	return get_head_group() == null

func get_remaining_total() -> int:
	var total := 0
	for i in range(_head_index, _groups.size()):
		total += _groups[i].remaining_count
	return total

func get_initial_total() -> int:
	var total := 0
	for g in _groups:
		total += g.initial_count
	return total

func get_visible_groups(limit: int = 10) -> Array[PassengerGroupData]:
	get_head_group()
	var visible: Array[PassengerGroupData] = []
	for i in range(_head_index, mini(_groups.size(), _head_index + limit)):
		visible.append(_groups[i])
	return visible

func get_all_groups() -> Array[PassengerGroupData]:
	return _groups

func snapshot() -> Dictionary:
	var group_snaps: Array = []
	for g in _groups:
		group_snaps.append(g.to_dict())
	return {
		"head_index": _head_index,
		"groups": group_snaps
	}

func restore(d: Dictionary) -> void:
	_head_index = int(d.get("head_index", 0))
	var group_snaps: Array = d.get("groups", [])
	_groups.clear()
	for snap in group_snaps:
		var g := PassengerGroupData.new()
		g.from_dict(snap)
		_groups.append(g)
