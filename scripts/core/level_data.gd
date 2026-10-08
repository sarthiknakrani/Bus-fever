extends RefCounted
class_name LevelData

## Pure-data description of a level. Engine loads this and constructs
## runtime state from it. No scene-tree references here.

@export var id: String = "level_1"
@export var display_name: String = "Level 1"
@export var board_size: Vector2i = Vector2i(7, 7)
@export var standard_bay_count: int = 5
@export var vehicles: Array[Dictionary] = []
@export var passenger_order: Array[String] = []
@export var board_origin: Vector2 = Vector2.ZERO
@export var cell_size: float = 96.0
@export var bay_panel_origin: Vector2 = Vector2.ZERO
@export var tutorial_triggers: Array[Dictionary] = []

func validate() -> Dictionary:
	# Returns {ok: bool, errors: Array[String]}
	var errors: Array[String] = []
	if board_size.x < 1 or board_size.y < 1:
		errors.append("board_size invalid")
	if standard_bay_count < 1:
		errors.append("standard_bay_count must be >=1")
	if vehicles.size() == 0:
		errors.append("no vehicles")
	var seen_ids := {}
	var seen_cells := {}
	var total_passengers := 0
	for v in vehicles:
		var vd := VehicleData.new()
		vd.from_dict(v)
		var r: Dictionary = vd.is_valid()
		if not r.ok:
			errors.append(r.error)
			continue
		if seen_ids.has(vd.id):
			errors.append("duplicate vehicle id '%s'" % vd.id)
		seen_ids[vd.id] = true
		if vd.position.x < 0 or vd.position.y < 0 or \
		   vd.position.x >= board_size.x or vd.position.y >= board_size.y:
			errors.append("vehicle %s out of board bounds" % vd.id)
		var key := "%d,%d" % [vd.position.x, vd.position.y]
		if seen_cells.has(key):
			errors.append("vehicle %s overlaps cell %s" % [vd.id, key])
		seen_cells[key] = vd.id
		total_passengers += vd.capacity
	if passenger_order.size() == 0:
		errors.append("passenger_order is empty")
	for c in passenger_order:
		if not c in VehicleData.ALL_COLORS:
			errors.append("passenger order contains unknown color '%s'" % c)
	# Total passenger capacity per color must equal the passengers demanded in order.
	var cap_by_color := {}
	for v in vehicles:
		var vd2 := VehicleData.new()
		vd2.from_dict(v)
		if cap_by_color.has(vd2.color):
			cap_by_color[vd2.color] += vd2.capacity
		else:
			cap_by_color[vd2.color] = vd2.capacity
	var demand_by_color := {}
	for c in passenger_order:
		if demand_by_color.has(c):
			demand_by_color[c] += 1
		else:
			demand_by_color[c] = 1
	# In this game 1 demand == 1 passenger, capacity is counted in passengers.
	for color in demand_by_color:
		var need := int(demand_by_color[color])
		var have := int(cap_by_color.get(color, 0))
		if have != need:
			errors.append("color %s demand %d != total capacity %d" % [color, need, have])
	return {"ok": errors.is_empty(), "errors": errors}

func build_vehicle_data() -> Array[VehicleData]:
	var out: Array[VehicleData] = []
	for v in vehicles:
		var vd := VehicleData.new()
		vd.from_dict(v)
		out.append(vd)
	return out