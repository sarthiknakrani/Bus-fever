extends Node
class_name CarJamController

## Authoritative gameplay coordinator for the Car Jam puzzle level.
## Owns puzzle state, enforces turn-based determinism, coordinates
## the board, parking manager, passenger queue, and boarding scheduler.

signal vehicle_selected(vehicle_id: int)
signal vehicle_dispatch_started(vehicle_id: int, slot_id: int, swept_corridor: Array[Vector2i])
signal vehicle_parked(vehicle_id: int, slot_id: int)
signal boarding_started(vehicle_id: int, color_id: String, count: int, slot_id: int)
signal vehicle_filled(vehicle_id: int, slot_id: int)
signal vehicle_departed(vehicle_id: int, slot_id: int)
signal vehicle_blocked(vehicle_id: int, blocker_id: int)
signal level_completed()
signal puzzle_failed()
signal board_updated()
signal parking_updated()
signal parking_full_warning()
signal queue_updated()

enum GameState {
	PLAYING,
	PAUSED,
	WIN,
	FAIL
}

var level_data: CarJamLevelData
var board: CarJamBoardModel
var parking: CarJamParkingManager
var queue: CarJamPassengerQueue
var boarding_scheduler: CarJamBoardingController
var vehicles: Dictionary = {} # int id -> VehicleModel

class BoardingReservation extends RefCounted:
	var passenger_id: int = -1
	var color_id: String = ""
	var group_id: int = -1
	var vehicle_id: int = -1
	var reservation_status: String = "ACTIVE" # "ACTIVE", "COMMITTED", "CANCELLED"
	var session_token: int = 0

var state: int = GameState.PLAYING
var session_token: int = 0

var authoritative_passengers: Dictionary = {} # pid (int) -> Dictionary
var boarding_reservations: Dictionary = {} # pid (int) -> BoardingReservation
var pending_boarders: Dictionary = {} # vehicle_id -> int

func load_level(lvl: CarJamLevelData) -> void:
	session_token += 1
	level_data = lvl
	pending_boarders.clear()
	authoritative_passengers.clear()
	boarding_reservations.clear()

	# Populate initial authoritative passenger registry from lvl.passenger_groups
	var p_id := 0
	if lvl != null and lvl.passenger_groups != null:
		for g_idx in lvl.passenger_groups.size():
			var g = lvl.passenger_groups[g_idx]
			for j in g.initial_count:
				authoritative_passengers[p_id] = {
					"id": p_id,
					"color_id": String(g.color_id),
					"group_id": g_idx,
					"state": "PENDING"
				}
				p_id += 1

	board = CarJamBoardModel.new()
	board.setup(lvl.board_size)

	parking = CarJamParkingManager.new()
	parking.setup(lvl.parking_slots_count)

	queue = CarJamPassengerQueue.new()
	queue.setup(lvl.passenger_groups)

	boarding_scheduler = CarJamBoardingController.new()

	# 0. Pre-validate level data
	var val_res := CarJamLevelValidator.validate(lvl)
	if not val_res["ok"]:
		var val_err = "[CarJamController] FATAL: Level validation failed for '%s': %s" % [lvl.title, val_res["errors"]]
		push_error(val_err)

	vehicles.clear()
	for vd in lvl.vehicles:
		var vm := VehicleModel.new()
		vm.setup_from_data(vd)
		vehicles[vm.id] = vm
		var placed := board.place_vehicle(vm)
		if not placed:
			var conflicting_id: int = -1
			var conflicting_cells: Array[Vector2i] = []
			for c in vm.get_occupied_cells():
				var occ := board.get_vehicle_at(c)
				if occ != -1 and occ != vm.id:
					conflicting_id = occ
					conflicting_cells.append(c)
			var diag := "[CarJamController] CRITICAL ERROR: Failed to place vehicle %d ('%s') on board! Overlaps vehicle ID %d at cell(s) %s" % [
				vm.id, vm.code, conflicting_id, str(conflicting_cells)
			]
			push_error(diag)
			assert(placed, diag)

	state = GameState.PLAYING

	board_updated.emit()
	parking_updated.emit()
	queue_updated.emit()

func restart_level() -> void:
	if level_data != null:
		load_level(level_data)

func tap_vehicle(vehicle_id: int) -> bool:
	var t0 = Time.get_ticks_msec()
	var v_log = vehicles.get(vehicle_id, null)
	var state_str = "NULL" if v_log == null else str(v_log.state)
	var can_disp = false if v_log == null else v_log.can_dispatch()
	var slots_str = "["
	for s in parking._slots: slots_str += "U" if s.is_unlocked else "L" ; slots_str += str(s.state) + ":" + str(s.vehicle_id) + ", "
	slots_str += "]"
	
	if state != GameState.PLAYING:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: Game not playing" % [t0, vehicle_id, state_str, str(can_disp), slots_str])
		return false

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null or not v.can_dispatch():
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: Invalid state" % [t0, vehicle_id, state_str, str(can_disp), slots_str])
		return false

	# 1. Swept corridor collision check
	var escape_res := board.check_swept_escape(v)
	if not escape_res["can_escape"]:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: Physically Blocked by %d" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str, escape_res["blocker_id"]])
		vehicle_blocked.emit(vehicle_id, escape_res["blocker_id"])
		return false

	# 2. Atomic parking slot reservation
	var slot_id := parking.reserve_slot(vehicle_id)
	if slot_id == -1:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: No Spot Available (Toast Triggered)" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str])
		parking_full_warning.emit()
		return false

	vehicle_selected.emit(vehicle_id)

	# 3. Commit atomic dispatch
	print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | ACCEPTED: Reserved Slot %d" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str, slot_id])
	v.state = VehicleModel.VehicleState.EXITING
	v.reserved_slot = slot_id

	# Clear from authoritative board grid
	board.remove_vehicle(vehicle_id)

	board_updated.emit()
	parking_updated.emit()

	var corridor: Array[Vector2i] = escape_res["swept_corridor"]
	vehicle_dispatch_started.emit(vehicle_id, slot_id, corridor)
	return true

## Called by vehicle movement view when arrival at parking slot completes.
func on_vehicle_arrived_at_slot(vehicle_id: int, slot_id: int, token: int) -> void:
	if token != session_token:
		return # Obsolete callback from previous session / restart

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null:
		return

	# Strictly validate slot ownership
	if not parking.confirm_arrival(slot_id, vehicle_id):
		push_error("Parking arrival confirmation failed for Bus %d at Slot %d" % [vehicle_id, slot_id])
		return

	v.state = VehicleModel.VehicleState.PARKED
	v.reserved_slot = slot_id

	vehicle_parked.emit(vehicle_id, slot_id)
	parking_updated.emit()

	_check_terminal_states()

func on_vehicle_cleared_slot(vehicle_id: int, slot_id: int, token: int) -> void:
	if token != session_token:
		return
	
	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v != null:
		v.state = VehicleModel.VehicleState.DEPARTING
		
	# Mark slot as DEPARTING - it is NOT available to other buses yet!
	parking.mark_departing(slot_id, vehicle_id)
	parking_updated.emit()

func on_vehicle_departed_from_slot(vehicle_id: int, slot_id: int, token: int) -> void:
	print("[QA %d] Bus %d final exit completed off-screen. Slot %d now FREE." % [Time.get_ticks_msec(), vehicle_id, slot_id])
	if token != session_token:
		return

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v != null:
		v.state = VehicleModel.VehicleState.COMPLETED
		v.reserved_slot = -1
		
	# ONLY release slot back to FREE when the bus has 100% departed and disappeared offscreen!
	parking.release_slot(slot_id, vehicle_id)
	parking_updated.emit()
	vehicle_departed.emit(vehicle_id, slot_id)

	_check_terminal_states()


# -----------------------------------------------------------------

# -----------------------------------------------------------------
# AUTHORITATIVE PASSENGER & BOARDING LOGIC
# -----------------------------------------------------------------

func register_passengers(p_list: Array) -> void:
	authoritative_passengers.clear()
	boarding_reservations.clear()
	pending_boarders.clear()
	for p_info in p_list:
		var pid: int = int(p_info["id"])
		authoritative_passengers[pid] = {
			"id": pid,
			"color_id": String(p_info["color_id"]),
			"group_id": int(p_info.get("group_id", 0)),
			"state": String(p_info.get("state", "PENDING"))
		}

func set_passenger_state(passenger_id: int, new_state: String) -> bool:
	if not authoritative_passengers.has(passenger_id):
		return false
	var p = authoritative_passengers[passenger_id]
	p["state"] = new_state
	return true

func get_passenger(passenger_id: int) -> Dictionary:
	return authoritative_passengers.get(passenger_id, {})

func get_all_passengers() -> Dictionary:
	return authoritative_passengers

func get_active_reservations_for_vehicle(vehicle_id: int) -> int:
	var count := 0
	for res in boarding_reservations.values():
		if res.vehicle_id == vehicle_id and res.reservation_status == "ACTIVE":
			count += 1
	return count

func _sync_pending_boarders() -> void:
	pending_boarders.clear()
	for res in boarding_reservations.values():
		if res.reservation_status == "ACTIVE":
			pending_boarders[res.vehicle_id] = pending_boarders.get(res.vehicle_id, 0) + 1

func try_reserve_boarding(arg1: int, arg2: Variant, arg3: Variant = "", arg4: Variant = -1) -> bool:
	if state != GameState.PLAYING:
		return false

	var passenger_id: int = -1
	var vehicle_id: int = -1
	var req_color: String = ""
	var req_group: int = -1

	if typeof(arg2) == TYPE_STRING:
		# Legacy signature: try_reserve_boarding(vehicle_id: int, color_id: String)
		vehicle_id = arg1
		req_color = String(arg2)
		for pid in authoritative_passengers.keys():
			var cand = authoritative_passengers[pid]
			if cand.get("color_id", "") == req_color and cand.get("state", "") == "CIRCULATING":
				if not boarding_reservations.has(pid) or boarding_reservations[pid].reservation_status != "ACTIVE":
					passenger_id = pid
					req_group = cand.get("group_id", -1)
					break
		if passenger_id == -1:
			return false
	else:
		# Authoritative signature: try_reserve_boarding(passenger_id: int, vehicle_id: int, color_id: String = "", group_id: int = -1)
		passenger_id = arg1
		vehicle_id = int(arg2)
		req_color = String(arg3)
		req_group = int(arg4)

	var p = authoritative_passengers.get(passenger_id, null)
	if p == null:
		return false

	# Passenger must be in CIRCULATING state
	if p.get("state", "") != "CIRCULATING":
		return false

	# Cannot double-reserve an actively reserved passenger
	if boarding_reservations.has(passenger_id):
		var existing_res: BoardingReservation = boarding_reservations[passenger_id]
		if existing_res.reservation_status == "ACTIVE":
			return false

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null or v.state != VehicleModel.VehicleState.PARKED:
		return false

	# Color eligibility check
	if v.color_id != p.get("color_id", ""):
		return false
	if req_color != "" and req_color != p.get("color_id", ""):
		return false

	# Capacity check: occupancy + active reservations must be strictly less than capacity
	var active_res := get_active_reservations_for_vehicle(vehicle_id)
	if v.passenger_occupancy + active_res >= v.capacity:
		return false

	# Register reservation
	var res := BoardingReservation.new()
	res.passenger_id = passenger_id
	res.color_id = p["color_id"]
	res.group_id = p.get("group_id", req_group)
	res.vehicle_id = vehicle_id
	res.reservation_status = "ACTIVE"
	res.session_token = session_token
	boarding_reservations[passenger_id] = res

	p["state"] = "BOARDING_RESERVED"
	_sync_pending_boarders()
	return true

func cancel_boarding_reservation(passenger_id: int) -> bool:
	if not boarding_reservations.has(passenger_id):
		return false
	var res: BoardingReservation = boarding_reservations[passenger_id]
	if res.reservation_status != "ACTIVE":
		return false
	res.reservation_status = "CANCELLED"
	boarding_reservations.erase(passenger_id)

	var p = authoritative_passengers.get(passenger_id, null)
	if p != null and p.get("state", "") == "BOARDING_RESERVED":
		p["state"] = "CIRCULATING"

	_sync_pending_boarders()
	return true

func commit_boarding(arg1: int, arg2: Variant, arg3: Variant = "", arg4: Variant = null) -> bool:
	if state != GameState.PLAYING:
		return false

	var passenger_id: int = -1
	var vehicle_id: int = -1
	var color_id: String = ""
	var token: int = 0

	if arg4 == null:
		# Legacy signature: commit_boarding(vehicle_id: int, color_id: String, token: int)
		vehicle_id = arg1
		color_id = String(arg2)
		token = int(arg3)
		for pid in boarding_reservations.keys():
			var r: BoardingReservation = boarding_reservations[pid]
			if r.reservation_status == "ACTIVE" and r.vehicle_id == vehicle_id and r.color_id == color_id and r.session_token == token:
				passenger_id = pid
				break
		if passenger_id == -1:
			return false
	else:
		# Authoritative signature: commit_boarding(passenger_id: int, vehicle_id: int, color_id: String, token: int)
		passenger_id = arg1
		vehicle_id = int(arg2)
		color_id = String(arg3)
		token = int(arg4)

	# 1. Stale token rejection
	if token != session_token:
		return false

	# 2. Passenger existence verification
	var p = authoritative_passengers.get(passenger_id, null)
	if p == null:
		return false

	# 3. Idempotency: verify passenger has not already boarded
	if p.get("state", "") == "BOARDED":
		return false

	# 4. Verify ID matches a live active reservation
	if not boarding_reservations.has(passenger_id):
		return false
	var res: BoardingReservation = boarding_reservations[passenger_id]
	if res.reservation_status != "ACTIVE":
		return false

	# 5. Verify reservation belongs to destination bus
	if res.vehicle_id != vehicle_id:
		return false

	# 6. Verify reservation session token
	if res.session_token != token:
		return false

	# 7. Destination vehicle exists and state verification
	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null:
		return false

	# 8. Color eligibility verification
	if v.color_id != p.get("color_id", "") or res.color_id != p.get("color_id", ""):
		return false
	if color_id != "" and color_id != p.get("color_id", ""):
		return false

	# 9. Verify vehicle capacity not exceeded
	if v.passenger_occupancy >= v.capacity:
		return false

	# --- COMMIT ACTIONS ---
	# Commit exactly one seat
	v.board(1)

	# Update reservation status and remove from active map
	res.reservation_status = "COMMITTED"
	boarding_reservations.erase(passenger_id)
	_sync_pending_boarders()

	# Transition passenger to BOARDED exactly once
	p["state"] = "BOARDED"

	# Update the corresponding logical group exactly once
	var group_id: int = int(p.get("group_id", res.group_id))
	var all_groups = queue.get_all_groups()
	var group_updated := false
	if group_id >= 0 and group_id < all_groups.size():
		var g: PassengerGroupData = all_groups[group_id]
		if g.color_id == p["color_id"] and g.remaining_count > 0:
			queue.board_group(group_id, 1)
			group_updated = true

	if not group_updated:
		for i in all_groups.size():
			var g: PassengerGroupData = all_groups[i]
			if g.color_id == p["color_id"] and g.remaining_count > 0:
				queue.board_group(i, 1)
				break

	# Emit signals
	var slot_id = parking.get_slot_for_vehicle(v.id)
	boarding_started.emit(vehicle_id, p["color_id"], 1, slot_id)

	if v.is_full():
		v.state = VehicleModel.VehicleState.FULL
		parking.mark_departing(slot_id, v.id)
		parking_updated.emit()
		vehicle_filled.emit(v.id, slot_id)

	_check_terminal_states()
	return true

func _process_boarding_cycle(token: int) -> void:
	if token != session_token:
		return

	var events := [] # Disabled strict boarding
	if not events.is_empty():
		queue_updated.emit()
		parking_updated.emit()
		for evt in events:
			boarding_started.emit(evt["vehicle_id"], evt["color_id"], evt["count"], evt["slot_id"])
			if evt["is_full"]:
				vehicle_filled.emit(evt["vehicle_id"], evt["slot_id"])

func _check_terminal_states() -> void:
	_debug_passenger_accounting()
	if state != GameState.PLAYING:
		return

	# Win check: All vehicles completed & passenger queue fully served
	var all_v_done := true
	for vid in vehicles:
		if vehicles[vid].state != VehicleModel.VehicleState.COMPLETED:
			all_v_done = false
			break

	if all_v_done and queue.is_empty():
		state = GameState.WIN
		level_completed.emit()
		return

	# Failure / Softlock check:
	# If parking is full (no free slots) AND no parked vehicle matches the head of queue:
	if parking.is_full():
		var has_match := false
		var has_departing_or_arriving := false
		var all_groups = queue.get_all_groups()
		for i in parking.get_slot_count():
			var slot = parking.get_slot(i)
			if slot:
				if slot.state == CarJamParkingManager.SlotState.RESERVED or slot.state == CarJamParkingManager.SlotState.RELEASING:
					has_departing_or_arriving = true
				elif slot.state == CarJamParkingManager.SlotState.OCCUPIED:
					var v = vehicles.get(slot.vehicle_id, null)
					if v != null:
						if v.state == VehicleModel.VehicleState.FULL or v.state == VehicleModel.VehicleState.COMPLETED:
							has_departing_or_arriving = true
						elif v.remaining_capacity() > 0:
							for g in all_groups:
								if g.remaining_count > 0 and g.color_id == v.color_id:
									has_match = true
									break
			if has_match or has_departing_or_arriving: break
		
		if not has_match and not has_departing_or_arriving:
			state = GameState.FAIL
			puzzle_failed.emit()
			return

func verify_passenger_conservation() -> Dictionary:
	var state_counts := {
		"PENDING": 0,
		"FEEDER": 0,
		"CIRCULATING": 0,
		"BOARDING_RESERVED": 0,
		"BOARDED": 0
	}
	var by_color_state := {}
	var seen_ids := {}
	var duplicate_ids := []
	var missing_ids := []

	var expected_total := 0
	if queue != null:
		for g in queue.get_all_groups():
			expected_total += g.initial_count

	for pid in authoritative_passengers.keys():
		var p = authoritative_passengers[pid]
		if seen_ids.has(pid):
			duplicate_ids.append(pid)
		seen_ids[pid] = true

		var st: String = String(p.get("state", "UNKNOWN"))
		if state_counts.has(st):
			state_counts[st] += 1
		else:
			state_counts[st] = 1

		var c: String = String(p.get("color_id", ""))
		if not by_color_state.has(c):
			by_color_state[c] = {"PENDING": 0, "FEEDER": 0, "CIRCULATING": 0, "BOARDING_RESERVED": 0, "BOARDED": 0}
		if by_color_state[c].has(st):
			by_color_state[c][st] += 1

	for expected_id in expected_total:
		if not seen_ids.has(expected_id):
			missing_ids.append(expected_id)

	var total_accounted := 0
	for st in ["PENDING", "FEEDER", "CIRCULATING", "BOARDING_RESERVED", "BOARDED"]:
		total_accounted += state_counts.get(st, 0)

	var color_errors := []
	if queue != null:
		var initial_by_color := {}
		for g in queue.get_all_groups():
			initial_by_color[g.color_id] = initial_by_color.get(g.color_id, 0) + g.initial_count

		for c in initial_by_color.keys():
			var exp_c = initial_by_color[c]
			var act_c = 0
			if by_color_state.has(c):
				for st in by_color_state[c]:
					act_c += by_color_state[c][st]
			if exp_c != act_c:
				color_errors.append("Color '%s' demand mismatch: expected %d, got %d" % [c, exp_c, act_c])

	var ok := (total_accounted == expected_total) and duplicate_ids.is_empty() and missing_ids.is_empty() and color_errors.is_empty()
	return {
		"ok": ok,
		"total": total_accounted,
		"expected_total": expected_total,
		"state_counts": state_counts,
		"duplicate_ids": duplicate_ids,
		"missing_ids": missing_ids,
		"color_errors": color_errors
	}

func _debug_passenger_accounting() -> void:
	if not OS.is_debug_build():
		return

	var cons := verify_passenger_conservation()
	assert(cons["ok"], "QA FAIL: Strict passenger conservation violated! " + str(cons))
		
	var initial_by_color := {}
	var remaining_by_color := {}
	var boarded_by_color := {}
	var capacity_by_color := {}
	
	for g in queue.get_all_groups():
		initial_by_color[g.color_id] = initial_by_color.get(g.color_id, 0) + g.initial_count
		remaining_by_color[g.color_id] = remaining_by_color.get(g.color_id, 0) + g.remaining_count
		
	for vid in vehicles:
		var v = vehicles[vid]
		capacity_by_color[v.color_id] = capacity_by_color.get(v.color_id, 0) + v.capacity
		boarded_by_color[v.color_id] = boarded_by_color.get(v.color_id, 0) + v.passenger_occupancy
		# Assertion: Vehicle never exceeds capacity
		assert(v.passenger_occupancy <= v.capacity, "QA FAIL: Vehicle %d exceeded capacity!" % v.id)
		
	print("\n[QA] --- PASSENGER ACCOUNTING REPORT ---")
	for c in initial_by_color.keys():
		var init = initial_by_color[c]
		var rem = remaining_by_color[c]
		var board = boarded_by_color.get(c, 0)
		var cap = capacity_by_color.get(c, 0)
		print("[QA] %s: Initial=%d | Boarded=%d | Remaining=%d | BusCapacity=%d" % [c, init, board, rem, cap])
		# Assertion: Conservation of passengers
		assert(init == board + rem, "QA FAIL: Passenger conservation violated for %s! Init(%d) != Boarded(%d) + Rem(%d)" % [c, init, board, rem])
	print("[QA] -----------------------------------\n")
