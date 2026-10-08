extends Resource
class_name PassengerGroupData

## Authoritative data representing an ordered group of passengers in the queue.
## Each group has an explicit color and count that must be served before
## subsequent groups in the queue can access parking vehicles.

@export var group_id: int = 0
@export var color_id: String = "blue"
@export var initial_count: int = 4
@export var remaining_count: int = 4

func _init(p_id: int = 0, p_color: String = "blue", p_count: int = 4) -> void:
	group_id = p_id
	color_id = p_color
	initial_count = p_count
	remaining_count = p_count

func board(count: int) -> int:
	var to_board: int = mini(count, remaining_count)
	remaining_count -= to_board
	return to_board

func is_empty() -> bool:
	return remaining_count <= 0

func clone() -> PassengerGroupData:
	var copy := PassengerGroupData.new(group_id, color_id, initial_count)
	copy.remaining_count = remaining_count
	return copy

func to_dict() -> Dictionary:
	return {
		"group_id": group_id,
		"color_id": color_id,
		"initial_count": initial_count,
		"remaining_count": remaining_count
	}

func from_dict(d: Dictionary) -> void:
	group_id = int(d.get("group_id", 0))
	color_id = String(d.get("color_id", "blue"))
	initial_count = int(d.get("initial_count", 4))
	remaining_count = int(d.get("remaining_count", initial_count))
