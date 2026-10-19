extends Node2D
class_name PassengerSplineQueue

## Authoritative Clockwise 1D Spline Passenger Queue Manager
## Implements:
## 1. Single continuous 1D Curve2D clockwise (↻) spline from exit gate (dist = 0 px) to feeder ramp.
## 2. Gap-free stride target_dist(i) = i * 26.0 px with smooth move_toward.
## 3. Strict FIFO queue: only Row 0 (current_dist <= 5.0 px) can board.
## 4. Leftmost-slot priority search across standard parking slots 1..6.
## 5. Instant incoming_runners reservation accounting.
## 6. Micro-squash bounce (1.06 -> 1.0 over 0.05s) on arrival at bus door.

signal passenger_boarded(passenger_id: int, color_id: String, bus_id: int, slot_id: int)
signal queue_empty()
signal runner_dispatched(passenger_id: int, color_id: String, bus_id: int, slot_id: int)

class SplineRow extends RefCounted:
	var row_id: int = 0
	var batch_id: int = 0
	var color_id: String = ""
	var current_dist: float = 0.0
	var target_dist: float = 0.0
	var is_waiting: bool = false
	var passengers: Array[Dictionary] = [] # {"id": int, "color_id": String, "lane": int, "group_id": int, "view": PassengerView}

var curve: Curve2D
var row_stride: float = 26.0
var queue_speed: float = 220.0
var spawn_interval: float = 0.035
var lane_spacing: float = 28.0
var passenger_scale: float = 0.22

var rows: Array[SplineRow] = []
var active_runners: Array[Node2D] = []
var is_active: bool = true

# Slot provider callable: returns Array of slot dictionaries or objects:
# [{"slot_id": int, "bus_id": int, "color": String, "state": String, "remaining_seats": int, "incoming_runners": int, "door_pos": Vector2, "bus_view": Node}]
var get_parked_slots_callable: Callable = Callable()

var _spawn_timer: float = 0.0
var _gate_pos: Vector2 = Vector2.ZERO
var _reference_size: Vector2 = Vector2(1080.0, 1920.0)

func setup(
	p_curve: Curve2D,
	p_batches: Array[Dictionary],
	p_ref_size: Vector2 = Vector2(1080.0, 1920.0),
	p_stride: float = 26.0,
	p_speed: float = 220.0,
	p_interval: float = 0.035
) -> void:
	curve = p_curve
	_reference_size = p_ref_size
	row_stride = p_stride
	queue_speed = p_speed
	spawn_interval = p_interval
	_spawn_timer = 0.0
	
	if curve != null and curve.point_count > 0:
		_gate_pos = curve.get_point_position(0)
	
	_clear_visuals()
	_build_rows_from_batches(p_batches)

func _clear_visuals() -> void:
	for r in rows:
		for p in r.passengers:
			var pv: Node = p.get("view", null)
			if is_instance_valid(pv):
				pv.queue_free()
	rows.clear()
	for runner in active_runners:
		if is_instance_valid(runner):
			runner.queue_free()
	active_runners.clear()

func _build_rows_from_batches(batches: Array[Dictionary]) -> void:
	var row_idx := 0
	var p_id := 0
	for batch_idx in range(batches.size()):
		var b = batches[batch_idx]
		var c: String = b["color"]
		var num_rows: int = b["rows"]
		for r in num_rows:
			var s_row := SplineRow.new()
			s_row.row_id = row_idx
			s_row.batch_id = batch_idx
			s_row.color_id = c
			s_row.target_dist = float(row_idx) * row_stride
			s_row.current_dist = s_row.target_dist # Initialize packed along spline
			
			for lane in 4:
				var p_info := {
					"id": p_id,
					"color_id": c,
					"lane": lane,
					"group_id": batch_idx,
					"view": null
				}
				
				var pv := PassengerView.new()
				pv.setup(c, p_id, lane)
				pv.scale = Vector2(passenger_scale, passenger_scale)
				add_child(pv)
				p_info["view"] = pv
				
				s_row.passengers.append(p_info)
				p_id += 1
				
			rows.append(s_row)
			row_idx += 1
			
	_update_passenger_positions(0.0)

func _process(delta: float) -> void:
	if not is_active or curve == null:
		return
		
	# 1. Update row target distances and advance clockwise towards 0.0
	for i in range(rows.size()):
		var r := rows[i]
		r.target_dist = float(i) * row_stride
		var old_dist := r.current_dist
		r.current_dist = move_toward(r.current_dist, r.target_dist, queue_speed * delta)
		r.is_waiting = is_equal_approx(r.current_dist, r.target_dist)

	# 2. Update visual passenger positions along spline
	_update_passenger_positions(delta)

	# 3. Strict FIFO Gate Boarding Check
	_process_gate_boarding(delta)

func _update_passenger_positions(_delta: float) -> void:
	if curve == null or curve.get_baked_length() <= 0.0:
		return
	var curve_len := curve.get_baked_length()

	for r in rows:
		var s: float = clampf(r.current_dist, 0.0, curve_len)
		var p0 := curve.sample_baked(s)
		# Tangent along curve (increasing dist)
		var next_s: float = minf(s + 2.0, curve_len)
		var p1 := curve.sample_baked(next_s)
		if p1.distance_squared_to(p0) < 0.0001 and s > 2.0:
			p1 = p0
			p0 = curve.sample_baked(s - 2.0)
		var tangent := (p1 - p0).normalized()
		# Decreasing dist towards 0 moves in direction -tangent (clockwise)
		var move_dir := -tangent
		var normal := Vector2(-tangent.y, tangent.x)

		for p in r.passengers:
			var pv: PassengerView = p.get("view", null)
			if is_instance_valid(pv):
				var lane: int = p["lane"]
				var lane_offset: float = (float(lane) - 1.5) * lane_spacing
				pv.position = p0 + normal * lane_offset
				pv.set_movement_direction(move_dir)
				pv.set_waiting(r.is_waiting)

func _process_gate_boarding(delta: float) -> void:
	if rows.is_empty():
		return

	var row0 := rows[0]
	# Strict FIFO Rule: Only Row 0 when current_dist <= 5.0 px can board
	if row0.current_dist > 5.0:
		return

	if row0.passengers.is_empty():
		rows.pop_front()
		if rows.is_empty():
			queue_empty.emit()
		return

	# Search standard slots (ascending order 1 to 6) for leftmost matching bus
	var target_slot: Dictionary = _find_leftmost_matching_slot(row0.color_id)
	if target_slot.is_empty():
		# No matching slot available; queue waits at gate
		return

	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_dispatch_runner_from_gate(row0, target_slot)

func _find_leftmost_matching_slot(color_id: String) -> Dictionary:
	if not get_parked_slots_callable.is_valid():
		return {}

	var slots: Array = get_parked_slots_callable.call()
	# Iterate slots 1 to 6 in ascending order (leftmost priority)
	for slot_dict in slots:
		var slot_id: int = int(slot_dict.get("slot_id", -1))
		if slot_id < 1 or slot_id > 6:
			continue # VIP (0) and locked/unused (7) ignored by standard pathing
		var state: String = String(slot_dict.get("state", ""))
		if state != "PARKED":
			continue
		var col: String = String(slot_dict.get("color", ""))
		if col != color_id:
			continue
		var remaining: int = int(slot_dict.get("remaining_seats", 0))
		var incoming: int = int(slot_dict.get("incoming_runners", 0))
		if (remaining - incoming) > 0:
			return slot_dict

	return {}

func _dispatch_runner_from_gate(row0: SplineRow, slot_dict: Dictionary) -> void:
	if row0.passengers.is_empty():
		return

	var p_data: Dictionary = row0.passengers.pop_front()
	var pv: PassengerView = p_data.get("view", null)
	if not is_instance_valid(pv):
		return

	var bus_id: int = int(slot_dict.get("bus_id", -1))
	var slot_id: int = int(slot_dict.get("slot_id", -1))
	var bus_view: Node = slot_dict.get("bus_view", null)
	var door_pos: Vector2 = slot_dict.get("door_pos", Vector2.ZERO)

	# 1. Immediate seat reservation accounting
	if slot_dict.has("increment_incoming_callable") and slot_dict["increment_incoming_callable"].is_valid():
		slot_dict["increment_incoming_callable"].call(1)
	elif bus_view != null and bus_view.has_method("reserve_incoming_runner"):
		bus_view.reserve_incoming_runner(1)

	runner_dispatched.emit(p_data["id"], p_data["color_id"], bus_id, slot_id)

	# 2. Animate runner along smooth Bezier curve from gate to bus door
	active_runners.append(pv)
	var start_pos: Vector2 = pv.position
	var end_pos: Vector2 = door_pos

	# Curve control points (arches down and left/right toward slot)
	var mid_y: float = minf(start_pos.y, end_pos.y) - 25.0
	var control: Vector2 = Vector2((start_pos.x + end_pos.x) * 0.5, mid_y)

	var run_duration: float = 0.28
	var tween := create_tween()
	var t_val := {"t": 0.0}

	tween.tween_method(func(val: float):
		if not is_instance_valid(pv):
			return
		var u := 1.0 - val
		var pt := u * u * start_pos + 2.0 * u * val * control + val * val * end_pos
		pv.position = pt
		var next_val := minf(1.0, val + 0.05)
		var next_u := 1.0 - next_val
		var next_pt := next_u * next_u * start_pos + 2.0 * next_u * next_val * control + next_val * next_val * end_pos
		pv.set_movement_direction((next_pt - pt).normalized())
	, 0.0, 1.0, run_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_callback(func():
		active_runners.erase(pv)
		if is_instance_valid(pv):
			pv.queue_free()

		# Arrival at bus door:
		# Decrement incoming, decrement remaining seats, update badge, play micro-squash
		if slot_dict.has("on_runner_arrived_callable") and slot_dict["on_runner_arrived_callable"].is_valid():
			slot_dict["on_runner_arrived_callable"].call(bus_id, slot_id)
		elif bus_view != null and bus_view.has_method("on_passenger_boarded"):
			bus_view.on_passenger_boarded()

		passenger_boarded.emit(p_data["id"], p_data["color_id"], bus_id, slot_id)
	)

	# If Row 0 is now empty, pop it immediately
	if row0.passengers.is_empty():
		rows.pop_front()
		if rows.is_empty():
			queue_empty.emit()

func get_remaining_passengers_count() -> int:
	var total := 0
	for r in rows:
		total += r.passengers.size()
	total += active_runners.size()
	return total

func get_remaining_rows_count() -> int:
	return rows.size()

func get_front_color() -> String:
	if not rows.is_empty():
		return rows[0].color_id
	return ""
