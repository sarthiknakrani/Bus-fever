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
var is_dispatching: bool = false
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
	is_dispatching = false

	board_updated.emit()
	parking_updated.emit()
	queue_updated.emit()

func restart_level() -> void:
	if level_data != null:
		load_level(level_data)

func tap_vehicle(vehicle_id: int) -> bool:
	if state != GameState.PLAYING or is_dispatching:
		return false

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null or not v.can_dispatch():
		return false

	vehicle_selected.emit(vehicle_id)

	# 1. Swept corridor collision check
	var escape_res := board.check_swept_escape(v)
	if not escape_res["can_escape"]:
		vehicle_blocked.emit(vehicle_id, escape_res["blocker_id"])
		return false

	# 2. Parking slot capacity check
	var slot_id := parking.find_available_slot()
	if slot_id == -1:
		# Parking is completely full!
		vehicle_blocked.emit(vehicle_id, -1)
		return false

	# 3. Commit atomic dispatch
	slot_id = parking.reserve_slot(vehicle_id)
	v.state = VehicleModel.VehicleState.EXITING
	v.reserved_slot = slot_id

	# Clear from authoritative board grid
	board.remove_vehicle(vehicle_id)
	is_dispatching = true

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
		is_dispatching = false
		return

	parking.confirm_arrival(slot_id, vehicle_id)
	v.state = VehicleModel.VehicleState.PARKED
	v.reserved_slot = slot_id
	is_dispatching = false

	vehicle_parked.emit(vehicle_id, slot_id)
	parking_updated.emit()

	# Run serialized boarding
	_process_boarding_cycle(token)
	_check_terminal_states()

func on_vehicle_departed_from_slot(vehicle_id: int, slot_id: int, token: int) -> void:
	if token != session_token:
		return

	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v != null:
		v.state = VehicleModel.VehicleState.COMPLETED
		v.reserved_slot = -1

	parking.release_slot(slot_id)
	vehicle_departed.emit(vehicle_id, slot_id)
	parking_updated.emit()

	# Re-evaluate boarding in case subsequent passenger groups can now board
	_process_boarding_cycle(token)
	_check_terminal_states()

func _process_boarding_cycle(token: int) -> void:
	if token != session_token:
		return

	var events := boarding_scheduler.evaluate_boarding(queue, parking, vehicles)
	if not events.is_empty():
		queue_updated.emit()
		parking_updated.emit()
		for evt in events:
			boarding_started.emit(evt["vehicle_id"], evt["color_id"], evt["count"], evt["slot_id"])
			if evt["is_full"]:
				vehicle_filled.emit(evt["vehicle_id"], evt["slot_id"])

func _check_terminal_states() -> void:
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
		var head_color := queue.get_head_color()
		var matching_parked := false
		for i in parking.get_slot_count():
			var slot := parking.get_slot(i)
			if slot != null and slot.vehicle_id != -1:
				var v: VehicleModel = vehicles.get(slot.vehicle_id, null)
				if v != null:
					# If a vehicle is FULL, it is about to depart and free a slot. Not a softlock!
					if v.state == VehicleModel.VehicleState.FULL:
						matching_parked = true
						break
					if v.color_id == head_color and v.remaining_capacity() > 0:
						matching_parked = true
						break
		if not matching_parked and not is_dispatching:
			# True deadlock: all slots occupied, queue head blocked!
			state = GameState.FAIL
			puzzle_failed.emit()
			return

	# Also check if no vehicles remain in parking, but all remaining on-board vehicles are blocked:
	if not is_dispatching and parking.get_available_slot_count() > 0:
		var has_any_on_board := false
		var has_any_escape := false
		for vid in vehicles:
			var v: VehicleModel = vehicles[vid]
			if v.can_dispatch():
				has_any_on_board = true
				if board.check_swept_escape(v)["can_escape"]:
					has_any_escape = true
					break
		if has_any_on_board and not has_any_escape:
			# Complete gridlock on board with no parked vehicles to free space!
			state = GameState.FAIL
			puzzle_failed.emit()

func pause() -> void:
	if state == GameState.PLAYING:
		state = GameState.PAUSED

func resume() -> void:
	if state == GameState.PAUSED:
		state = GameState.PLAYING
