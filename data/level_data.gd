extends Resource
class_name CarJamLevelData

## Complete authored puzzle level configuration for Car Jam.
## Contains board dimensions, exactly 4 parking slots, vehicle layout,
## and ordered passenger groups.

@export var level_id: int = 1
@export var title: String = "Level 1"
@export var board_size: Vector2i = Vector2i(7, 7)
@export var parking_slots_count: int = 4
@export var vehicles: Array[CarJamVehicleData] = []
@export var passenger_groups: Array[PassengerGroupData] = []

func clone() -> CarJamLevelData:
	var copy := CarJamLevelData.new()
	copy.level_id = level_id
	copy.title = title
	copy.board_size = board_size
	copy.parking_slots_count = parking_slots_count
	for v in vehicles:
		copy.vehicles.append(v.clone())
	for g in passenger_groups:
		copy.passenger_groups.append(g.clone())
	return copy

func get_total_capacity_by_color() -> Dictionary:
	var caps: Dictionary = {}
	for v in vehicles:
		caps[v.color_id] = caps.get(v.color_id, 0) + v.capacity
	return caps

func get_total_demand_by_color() -> Dictionary:
	var demands: Dictionary = {}
	for g in passenger_groups:
		demands[g.color_id] = demands.get(g.color_id, 0) + g.initial_count
	return demands
