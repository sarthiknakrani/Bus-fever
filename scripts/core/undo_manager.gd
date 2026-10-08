extends RefCounted
class_name UndoManager

## Snapshots the stable logical state of a level before each PLAYER move
## (not automatic re-evaluations or solver steps). Restoring one undoes
## exactly one player action.

class Snapshot:
	var board_snapshot: Array
	var bay_snapshot: Array
	var passenger_snapshot: Array
	var active_index: int
	var vehicle_snapshots: Array = []   # Array of Vehicle.Snapshot dicts
	var game_state: int
	var extra_bay_active: bool
	var hint_pending: bool

var _stack: Array[Snapshot] = []

func push(snap: Snapshot) -> void:
	_stack.append(snap)

func can_undo() -> bool:
	return _stack.size() > 0

func pop() -> Snapshot:
	if _stack.is_empty():
		return null
	var s: Snapshot = _stack.pop_back()
	return s

func clear() -> void:
	_stack.clear()

func depth() -> int:
	return _stack.size()