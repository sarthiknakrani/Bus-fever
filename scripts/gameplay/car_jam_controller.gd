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

var state: int = GameState.PLAYING
var session_token: int = 0

func load_level(lvl: CarJamLevelData) -> void:
	session_token += 1
	level_data = lvl

	board = CarJamBoardModel.new()
	board.setup(lvl.board_size)

	parking = CarJamParkingManager.new()
	parking.setup(lvl.parking_slots_count)

	queue = CarJamPassengerQueue.new()
	queue.setup(lvl.passenger_groups)

	boarding_scheduler = CarJamBoardingController.new()

	vehicles.clear()
	for vd in lvl.vehicles:
		var vm := VehicleModel.new()
		vm.setup_from_data(vd)
		vehicles[vm.id] = vm
		board.place_vehicle(vm)

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

	if v_log == null or not v_log.can_dispatch():
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: Invalid state" % [t0, vehicle_id, state_str, str(can_disp), slots_str])
		return false
	if state != GameState.PLAYING:
		return false

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null or not v.can_dispatch():
		return false

	vehicle_selected.emit(vehicle_id)

	# 1. Swept corridor collision check
	var escape_res := board.check_swept_escape(v)
	if not escape_res["can_escape"]:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: Physically Blocked by %d" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str, escape_res["blocker_id"]])
		vehicle_blocked.emit(vehicle_id, escape_res["blocker_id"])
		return false

	# 2. Parking slot capacity check
	var slot_id := parking.find_available_slot()
	if slot_id == -1:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: No Spot Available (Toast Triggered)" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str])
		# Parking is completely full!
		parking_full_warning.emit()
		return false

	# 3. Commit atomic dispatch
	slot_id = parking.reserve_slot(vehicle_id)
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

	parking.confirm_arrival(slot_id, vehicle_id)
	v.state = VehicleModel.VehicleState.PARKED
	v.reserved_slot = slot_id

	vehicle_parked.emit(vehicle_id, slot_id)
	parking_updated.emit()

	# Run serialized boarding
	_process_boarding_cycle(token)
	_check_terminal_states()

func on_vehicle_cleared_slot(vehicle_id: int, slot_id: int, token: int) -> void:
	print("[QA %d] Bus %d cleared parking bounds. Slot %d released." % [Time.get_ticks_msec(), vehicle_id, slot_id])
	if token != session_token:
		return
	
	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v != null:
		v.state = VehicleModel.VehicleState.DEPARTING
		v.reserved_slot = -1
		
	# Release the bay atomically as soon as bus physically clears it
	parking.release_slot(slot_id)
	parking_updated.emit()
	
	# Try boarding cycle just in case
	_process_boarding_cycle(token)

func on_vehicle_departed_from_slot(vehicle_id: int, slot_id: int, token: int) -> void:
	print("[QA %d] Bus %d final exit completed off-screen." % [Time.get_ticks_msec(), vehicle_id])
	if token != session_token:
		return

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v != null:
		v.state = VehicleModel.VehicleState.COMPLETED
		
	# Parking is already released by on_vehicle_cleared_slot, do not double-release
	vehicle_departed.emit(vehicle_id, slot_id)

	# Re-evaluate boarding and check level clear
	_process_boarding_cycle(token)
	_check_terminal_states()


# -----------------------------------------------------------------

# -----------------------------------------------------------------
# NEW INDIVIDUAL BOARDING LOGIC
# -----------------------------------------------------------------
var pending_boarders: Dictionary = {} # vehicle_id -> int

func try_reserve_boarding(vehicle_id: int, color_id: String) -> bool:
	if state != GameState.PLAYING: return false
	var v = vehicles.get(vehicle_id, null)
	if v == null or v.state != VehicleModel.VehicleState.PARKED or v.color_id != color_id: return false
	var pending = pending_boarders.get(vehicle_id, 0)
	if v.passenger_occupancy + pending < v.capacity:
		pending_boarders[vehicle_id] = pending + 1
		return true
	return false

func commit_boarding(vehicle_id: int, color_id: String, token: int) -> void:
	if token != session_token: return
	if state != GameState.PLAYING: return
	
	var v = vehicles.get(vehicle_id, null)
	if v == null: return
	
	if pending_boarders.has(vehicle_id) and pending_boarders[vehicle_id] > 0:
		pending_boarders[vehicle_id] -= 1
		
	v.board(1)
	
	var all_groups = queue.get_all_groups()
	for g in all_groups:
		if g.color_id == color_id and g.remaining_count > 0:
			g.board(1)
			break
			
	var slot_id = parking.get_slot_for_vehicle(v.id)
	boarding_started.emit(vehicle_id, color_id, 1, slot_id)
	
	if v.is_full():
		v.state = VehicleModel.VehicleState.FULL
		vehicle_filled.emit(v.id, slot_id)
		
	_check_terminal_states()

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

func _debug_passenger_accounting() -> void:
	if not OS.is_debug_build():
		return
		
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
