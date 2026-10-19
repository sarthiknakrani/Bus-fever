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
signal level_failed()
signal board_updated()
signal parking_updated()
signal parking_full_warning()
signal queue_updated()
## Feature B: emitted when the player taps a "?" mystery bus. The state stays
## ON_BOARD (no dispatch); the listening view animates the reveal from "?" to color.
signal mystery_revealed(vehicle_id: int)
## Feature C: VIP Slot booster. vip_available_changed(true) marks the booster
## as ready to consume; vip_available_changed(false) means it's been used this level.
## vip_extracted fires when the player activates it on a stuck bus.
signal vip_available_changed(available: bool)
signal vip_extracted(vehicle_id: int, slot_id: int)

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
var track_snapshot_provider: Callable = Callable()

# Plus-bay unlock progress tracking. PLUS bays are gated rewards that open as the
# player sustains dispatch progress. Each successful tap increments the counter;
# every PLUS_BAY_UNLOCK_INTERVAL successful dispatches unlocks one more PLUS bay.
const PLUS_BAY_UNLOCK_INTERVAL: int = 2
var _plus_bays_unlocked_this_level: int = 0
var _dispatch_count_this_level: int = 0

# Feature C: VIP Slot Booster state. Single-use per level; resets on load_level / restart_level.
var _vip_used_this_level: bool = false

func load_level(lvl: CarJamLevelData) -> void:
	# Feature C: reset VIP booster availability BEFORE the rest of load_level runs so any
	# early listeners see the right state when board/parking signals emit.
	_vip_used_this_level = false
	vip_available_changed.emit(true)

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
	var custom_unlocked: Array[int] = []
	if "unlocked_slot_ids" in lvl and not lvl.unlocked_slot_ids.is_empty():
		custom_unlocked = lvl.unlocked_slot_ids
	var plus_slot_ids: Array[int] = []
	if "plus_slot_ids" in lvl and not lvl.plus_slot_ids.is_empty():
		plus_slot_ids = lvl.plus_slot_ids
	parking.setup(lvl.parking_slots_count, custom_unlocked, plus_slot_ids)

	# Reset plus-bay unlock progress for the new level
	var plus_locked_total := parking.get_plus_locked_count()
	_plus_bays_unlocked_this_level = 0
	_dispatch_count_this_level = 0
	# unlock in waves: every PLUS_BAY_UNLOCK_INTERVAL successful dispatches
	# sets one more plus bay free. If the level has zero plus bays, no-op.

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

## Feature C: VIP booster API. The booster is single-use per level and resets on
## load_level / restart_level. UI hooks vip_available_changed(true|false) to show
## or hide the VIP button; try_extract_vip consumes the booster on a chosen bus.
func is_vip_available() -> bool:
	return not _vip_used_this_level

## Consume the VIP booster to bypass a stuck bus out of its parked bay.
## Returns true if the bus was extracted (slot released as DEPARTING, bus state set
## to DEPARTING, booster marked consumed). Returns false if VIP already used or bus
## is not currently PARKED in a known slot.
func try_extract_vip(vehicle_id: int) -> bool:
	if _vip_used_this_level:
		return false
	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null:
		return false
	if v.state != VehicleModel.VehicleState.PARKED:
		return false
	var slot_id: int = parking.get_slot_for_vehicle(vehicle_id)
	if slot_id == -1:
		return false
	# Force-bypass: directly transition to DEPARTING and mark slot DEPARTING.
	v.state = VehicleModel.VehicleState.DEPARTING
	parking.mark_departing(slot_id, vehicle_id)
	_vip_used_this_level = true
	parking_updated.emit()
	vip_extracted.emit(vehicle_id, slot_id)
	vip_available_changed.emit(false)
	print("[CarJamController] VIP booster used: bus %d extracted from slot %d" % [vehicle_id, slot_id])
	# Release the slot immediately so it counts as free for further parking.
	parking.release_slot(slot_id, vehicle_id)
	# Mark vehicle as fully departed since this is a "free" exit.
	v.state = VehicleModel.VehicleState.COMPLETED
	v.reserved_slot = -1
	vehicle_departed.emit(vehicle_id, slot_id)
	_check_terminal_states()
	return true

## Unlock the next locked PLUS bay when the player has sustained enough dispatch progress.
## Called once per successful tap_vehicle() reservation. Idempotent and safe at level start.
func _maybe_unlock_plus_bay() -> void:
	if parking == null:
		return
	# Threshold: every PLUS_BAY_UNLOCK_INTERVAL dispatches opens one more plus bay.
	var target: int = int(floor(float(_dispatch_count_this_level) / float(PLUS_BAY_UNLOCK_INTERVAL)))
	while _plus_bays_unlocked_this_level < target:
		var unlocked_one := false
		for i in range(parking.get_slot_count()):
			if parking.is_plus_locked(i):
				if parking.unlock_plus_bay(i):
					_plus_bays_unlocked_this_level += 1
					unlocked_one = true
					parking_updated.emit()
					print("[CarJamController] Plus bay %d unlocked (after %d dispatches)" % [i, _dispatch_count_this_level])
				break
		if not unlocked_one:
			break # No more locked plus bays to grant; remaining taps no-op.

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

	# Feature B: Mystery "?" bus reveal. First tap ONLY reveals the color (no dispatch),
	# second tap dispatches normally. The bus stays ON_BOARD and no slot is reserved.
	if v.is_mystery:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | MYSTERY REVEAL (color=%s)" % [
			Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str, v.color_id
		])
		v.is_mystery = false
		mystery_revealed.emit(vehicle_id)
		return true

	# If parking is full, evaluate terminal states first
	if parking.is_full():
		_check_terminal_states()
		if state == GameState.FAIL:
			print("[QA %d] Tap Bus %d | REJECTED: Deadlock detected -> OUT OF SPACE" % [Time.get_ticks_msec(), vehicle_id])
			return false

	# 1. Swept corridor collision check
	var escape_res: Dictionary
	if level_data != null and level_data.level_id == 1:
		escape_res = _check_level1_bus_escape(vehicle_id)
	else:
		escape_res = board.check_swept_escape(v)

	if not escape_res["can_escape"]:
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: Physically Blocked by %d" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str, escape_res["blocker_id"]])
		vehicle_blocked.emit(vehicle_id, escape_res["blocker_id"])
		return false

	# 2. Atomic parking slot reservation
	var slot_id := parking.reserve_slot(vehicle_id)
	if slot_id == -1:
		_check_terminal_states()
		if state == GameState.FAIL:
			print("[QA %d] Tap Bus %d | REJECTED: Deadlock detected -> OUT OF SPACE" % [Time.get_ticks_msec(), vehicle_id])
			return false
		print("[QA %d] Tap Bus %d | State: %s | Legal: %s | Slots: %s | REJECTED: No Spot Available (Toast Triggered)" % [Time.get_ticks_msec(), vehicle_id, state_str, str(can_disp), slots_str])
		parking_full_warning.emit()
		return false

	vehicle_selected.emit(vehicle_id)

	# 2.5 Plus-bay reward progression: unlock a green "+" bay every PLUS_BAY_UNLOCK_INTERVAL
	# successful dispatches (Feature A from the public-source analysis).
	_dispatch_count_this_level += 1
	_maybe_unlock_plus_bay()

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

func _check_level1_bus_escape(vehicle_id: int) -> Dictionary:
	var blocker_id := -1
	if vehicle_id == 1 or vehicle_id == 4:
		var b2: VehicleModel = vehicles.get(2, null)
		if b2 != null and b2.state == VehicleModel.VehicleState.ON_BOARD:
			blocker_id = 2
	elif vehicle_id == 3 or vehicle_id == 6:
		var b5: VehicleModel = vehicles.get(5, null)
		if b5 != null and b5.state == VehicleModel.VehicleState.ON_BOARD:
			blocker_id = 5
	var empty_corr: Array[Vector2i] = []
	if blocker_id != -1:
		return {"can_escape": false, "blocker_id": blocker_id, "swept_corridor": empty_corr}
	var ok_corr: Array[Vector2i] = [Vector2i.ZERO]
	return {"can_escape": true, "blocker_id": -1, "swept_corridor": ok_corr}

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
	
func unlock_parking_slot(slot_id: int) -> bool:
	if parking == null or slot_id < 0 or slot_id >= parking.get_slot_count():
		return false
	if parking.is_slot_unlocked(slot_id):
		return false
	parking.unlock_slot(slot_id)
	parking_updated.emit()
	return true


# -----------------------------------------------------------------

# -----------------------------------------------------------------
# AUTHORITATIVE PASSENGER & BOARDING LOGIC
# -----------------------------------------------------------------

func register_passengers(p_list: Array) -> void:
	authoritative_passengers.clear()
	boarding_reservations.clear()
	pending_boarders.clear()
	for i in p_list.size():
		var p_info = p_list[i]
		var pid: int = int(p_info.get("id", i))
		var col: String = String(p_info.get("color_id", p_info.get("color", "")))
		authoritative_passengers[pid] = {
			"id": pid,
			"color_id": col,
			"group_id": int(p_info.get("group_id", 0)),
			"state": String(p_info.get("state", "PENDING"))
		}

func set_passenger_state(passenger_id: int, new_state: String) -> bool:
	if not authoritative_passengers.has(passenger_id):
		push_error("[CarJamController] Cannot set state for unknown passenger ID %d" % passenger_id)
		return false
	var p = authoritative_passengers[passenger_id]
	var cur_state: String = String(p.get("state", "PENDING"))
	if cur_state == new_state:
		return true

	# Terminal state protection: BOARDED cannot transition to anything during live gameplay
	if cur_state == "BOARDED":
		push_error("[CarJamController] Illegal transition: Passenger %d is already BOARDED; cannot transition to %s" % [passenger_id, new_state])
		return false

	# Public unrestricted mutation cannot mark a passenger BOARDED (only commit_boarding can)
	if new_state == "BOARDED":
		push_error("[CarJamController] Illegal transition: Cannot directly set state BOARDED for passenger %d outside commit_boarding()" % passenger_id)
		return false

	# Public unrestricted mutation cannot mark a passenger BOARDING_RESERVED (only try_reserve_boarding can)
	if new_state == "BOARDING_RESERVED":
		push_error("[CarJamController] Illegal transition: Cannot directly set state BOARDING_RESERVED for passenger %d outside try_reserve_boarding()" % passenger_id)
		return false

	# Allowed standard transitions:
	# PENDING -> FEEDER (emerging onto feeder track)
	# PENDING -> CIRCULATING (legitimate initial oval placement)
	# FEEDER -> CIRCULATING (merging from feeder into loop)
	# Controlled rollback:
	# BOARDING_RESERVED -> CIRCULATING (cancellation/rollback)
	var is_valid := false
	if cur_state == "PENDING" and (new_state == "FEEDER" or new_state == "CIRCULATING"):
		is_valid = true
	elif cur_state == "FEEDER" and new_state == "CIRCULATING":
		is_valid = true
	elif cur_state == "BOARDING_RESERVED" and new_state == "CIRCULATING":
		if boarding_reservations.has(passenger_id):
			cancel_boarding_reservation(passenger_id)
		is_valid = true

	if not is_valid:
		push_error("[CarJamController] Illegal state transition for passenger %d: %s -> %s" % [passenger_id, cur_state, new_state])
		return false

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

## Deprecated legacy compatibility helpers (isolated; strictly validate candidate passenger).
func try_reserve_boarding_legacy(vehicle_id: int, color_id: String) -> bool:
	for pid in authoritative_passengers.keys():
		var cand = authoritative_passengers[pid]
		if cand.get("color_id", "") == color_id and cand.get("state", "") == "CIRCULATING":
			if not boarding_reservations.has(pid):
				return try_reserve_boarding(pid, vehicle_id, color_id, cand.get("group_id", -1))
	return false

func commit_boarding_legacy(vehicle_id: int, color_id: String, token: int) -> bool:
	for pid in boarding_reservations.keys():
		var r: BoardingReservation = boarding_reservations[pid]
		if r.reservation_status == "ACTIVE" and r.vehicle_id == vehicle_id and r.color_id == color_id and r.session_token == token:
			return commit_boarding(pid, vehicle_id, color_id, token)
	return false

func try_reserve_boarding(arg1: int, arg2: Variant, arg3: Variant = "", arg4: Variant = -1) -> bool:
	if state != GameState.PLAYING:
		return false

	if typeof(arg2) == TYPE_STRING:
		return try_reserve_boarding_legacy(arg1, String(arg2))

	var passenger_id: int = arg1
	var vehicle_id: int = int(arg2)
	var req_color: String = String(arg3)
	var req_group: int = int(arg4)

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

	# Authoritative Group Verification
	var gid: int = int(p.get("group_id", req_group))
	var all_groups = queue.get_all_groups()
	if gid < 0 or gid >= all_groups.size():
		push_error("[CarJamController] try_reserve_boarding rejected: passenger %d has invalid group_id %d" % [passenger_id, gid])
		return false

	var target_group: PassengerGroupData = all_groups[gid]
	if target_group.color_id != p.get("color_id", ""):
		push_error("[CarJamController] try_reserve_boarding rejected: group %d color '%s' != passenger %d color '%s'" % [gid, target_group.color_id, passenger_id, p.get("color_id", "")])
		return false

	var active_res_for_group := 0
	for r in boarding_reservations.values():
		if r.reservation_status == "ACTIVE" and r.group_id == gid:
			active_res_for_group += 1
	if active_res_for_group >= target_group.remaining_count:
		return false

	# Register reservation
	var res := BoardingReservation.new()
	res.passenger_id = passenger_id
	res.color_id = p["color_id"]
	res.group_id = gid
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

	if arg4 == null:
		return commit_boarding_legacy(arg1, String(arg2), int(arg3))

	var passenger_id: int = arg1
	var vehicle_id: int = int(arg2)
	var color_id: String = String(arg3)
	var token: int = int(arg4)

	# 1. Stale token rejection
	if token != session_token:
		return false

	# 2. Passenger existence verification
	var p = authoritative_passengers.get(passenger_id, null)
	if p == null:
		push_error("[CarJamController] commit_boarding rejected: passenger ID %d not found" % passenger_id)
		return false

	# 3. Idempotency: verify passenger has not already boarded
	if p.get("state", "") == "BOARDED":
		return false

	# 4. Verify ID matches a live active reservation
	if not boarding_reservations.has(passenger_id):
		push_warning("[CarJamController] commit_boarding rejected: passenger %d has no active reservation" % passenger_id)
		return false
	var res: BoardingReservation = boarding_reservations[passenger_id]
	if res.reservation_status != "ACTIVE":
		push_warning("[CarJamController] commit_boarding rejected: reservation for %d is %s" % [passenger_id, res.reservation_status])
		return false

	# 5. Verify reservation belongs to destination bus
	if res.vehicle_id != vehicle_id:
		push_error("[CarJamController] commit_boarding rejected: destination bus mismatch (res=%d, call=%d)" % [res.vehicle_id, vehicle_id])
		return false

	# 6. Verify reservation session token
	if res.session_token != token:
		push_warning("[CarJamController] commit_boarding rejected: reservation token mismatch")
		return false

	# 7. Destination vehicle exists and state verification
	var v: VehicleModel = vehicles.get(vehicle_id, null)
	if v == null or v.state != VehicleModel.VehicleState.PARKED:
		push_error("[CarJamController] commit_boarding rejected: destination bus %d invalid or not parked" % vehicle_id)
		return false

	# 8. Color eligibility verification
	if v.color_id != p.get("color_id", "") or res.color_id != p.get("color_id", ""):
		push_error("[CarJamController] commit_boarding rejected: color mismatch (bus=%s, res=%s, p=%s)" % [v.color_id, res.color_id, p.get("color_id", "")])
		return false
	if color_id != "" and color_id != p.get("color_id", ""):
		push_error("[CarJamController] commit_boarding rejected: requested color %s != passenger color %s" % [color_id, p.get("color_id", "")])
		return false

	# 9. Verify vehicle capacity not exceeded
	if v.passenger_occupancy >= v.capacity:
		push_error("[CarJamController] commit_boarding rejected: bus %d is already full (%d/%d)" % [vehicle_id, v.passenger_occupancy, v.capacity])
		return false

	# 10. STRICT AUTHORITATIVE GROUP VALIDATION (BEFORE ANY MUTATION)
	# Verify group exists, color matches, and has remaining demand.
	# Reject inconsistent reservations rather than silently decrementing another group.
	var group_id: int = int(p.get("group_id", res.group_id))
	var all_groups = queue.get_all_groups()
	if group_id < 0 or group_id >= all_groups.size():
		push_error("[CarJamController] commit_boarding rejected: invalid group_id %d (queue has %d groups) for passenger %d" % [group_id, all_groups.size(), passenger_id])
		return false

	var target_group: PassengerGroupData = all_groups[group_id]
	if target_group.color_id != p.get("color_id", ""):
		push_error("[CarJamController] commit_boarding rejected: group %d color '%s' != passenger %d color '%s'" % [group_id, target_group.color_id, passenger_id, p.get("color_id", "")])
		return false

	if target_group.remaining_count <= 0:
		push_error("[CarJamController] commit_boarding rejected: group %d color '%s' has zero remaining demand for passenger %d" % [group_id, target_group.color_id, passenger_id])
		return false

	# 11. ATOMIC COMMIT (All-or-nothing decrement)
	var dec := queue.board_group(group_id, 1)
	if dec <= 0:
		push_error("[CarJamController] commit_boarding rejected: queue.board_group(%d, 1) returned %d" % [group_id, dec])
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

func check_terminal_states() -> void:
	_check_terminal_states()

func _check_terminal_states() -> void:
	_debug_passenger_accounting()
	if state != GameState.PLAYING:
		return

	# 1. Win Check: Emit/trigger level_completed only when all vehicles have departed and zero passengers remain on the track.
	var all_v_done := true
	for vid in vehicles:
		if vehicles[vid].state != VehicleModel.VehicleState.COMPLETED:
			all_v_done = false
			break

	var zero_passengers_remain := true
	for pid in authoritative_passengers:
		var st: String = String(authoritative_passengers[pid].get("state", ""))
		if st != "BOARDED":
			zero_passengers_remain = false
			break

	if track_snapshot_provider.is_valid():
		var snapshot: Dictionary = track_snapshot_provider.call()
		var circ_rows: Array = snapshot.get("circulating_rows", [])
		var feeder_rows: Array = snapshot.get("feeder_rows", [])
		var pending_rows: Array = snapshot.get("pending_rows", [])
		var has_circ: bool = not circ_rows.is_empty()
		var has_feeder: bool = not feeder_rows.is_empty()
		var has_pending: bool = not pending_rows.is_empty()
		var has_flight: bool = bool(snapshot.get("has_boarding_in_flight", false))
		var has_transit: bool = bool(snapshot.get("is_any_vehicle_in_transit", false))
		if has_circ or has_feeder or has_pending or has_flight:
			zero_passengers_remain = false
		if not all_v_done and has_transit:
			zero_passengers_remain = false

	if all_v_done and zero_passengers_remain and queue.is_empty():
		state = GameState.WIN
		level_completed.emit()
		return

	# 2. Accurate Lose/Jam Check: Trigger level_failed (puzzle_failed) ONLY when:
	#    - All parking slots are occupied by fully DOCKED vehicles (no vehicle is still driving to a slot), AND
	#    - Zero passengers are currently in RESERVED or BOARDING states, AND
	#    - None of the currently accessible front passengers on the oval track match the color of any docked vehicle.
	if not parking.is_full():
		return

	# Condition A: Verify every unlocked parking slot is occupied by a fully DOCKED vehicle
	var parked_color_needs: Dictionary = {} # color_id -> bool
	for i in parking.get_slot_count():
		var slot = parking.get_slot(i)
		if slot and slot.is_unlocked:
			if slot.state != CarJamParkingManager.SlotState.OCCUPIED:
				# Vehicle is still arriving (RESERVED) or departing (RELEASING)
				return
			if slot.vehicle_id == -1:
				return
			var v = vehicles.get(slot.vehicle_id, null)
			if v == null:
				return
			# Vehicle must be fully docked in slot (not exiting board or departing)
			if v.state == VehicleModel.VehicleState.EXITING:
				return
			if v.state == VehicleModel.VehicleState.FULL or v.state == VehicleModel.VehicleState.DEPARTING or v.state == VehicleModel.VehicleState.COMPLETED:
				return
			if v.remaining_capacity() > 0:
				parked_color_needs[v.color_id] = true

	# Condition B: Zero passengers are currently in RESERVED or BOARDING states
	if not boarding_reservations.is_empty():
		for r in boarding_reservations.values():
			if r.reservation_status == "ACTIVE":
				return

	for pid in authoritative_passengers:
		var st: String = String(authoritative_passengers[pid].get("state", ""))
		if st == "RESERVED" or st == "BOARDING":
			return

	if track_snapshot_provider.is_valid():
		var snapshot: Dictionary = track_snapshot_provider.call()
		if snapshot.get("is_any_vehicle_in_transit", false):
			return
		if snapshot.get("has_boarding_in_flight", false):
			return

		# Condition C: Check currently accessible front passengers on the oval track
		var has_circulating_match := false
		var circ_rows: Array = snapshot.get("circulating_rows", [])
		for row in circ_rows:
			for p in row.get("passengers", []):
				if parked_color_needs.has(p.get("color_id", "")):
					has_circulating_match = true
					break
			if has_circulating_match:
				break

		if has_circulating_match:
			return

		# Check if feeder rows can enter the oval using earned capacity credits
		var has_feeder_match := false
		var credits: int = int(snapshot.get("oval_freed_capacity", 0))
		var queue_to_check: Array = []
		queue_to_check.append_array(snapshot.get("feeder_rows", []))
		queue_to_check.append_array(snapshot.get("pending_rows", []))

		for row in queue_to_check:
			var r_pass: Array = row.get("passengers", [])
			var cost: int = r_pass.size()
			if cost == 0:
				continue
			if credits >= cost:
				credits -= cost
				for p in r_pass:
					if parked_color_needs.has(p.get("color_id", "")):
						has_feeder_match = true
						break
				if has_feeder_match:
					break
			else:
				break

		if has_feeder_match:
			return

	else:
		# Fallback for headless tests / solver without CarJamLevel
		var has_circulating_match := false
		for p in authoritative_passengers.values():
			var st: String = String(p.get("state", ""))
			var col: String = String(p.get("color_id", ""))
			if st == "CIRCULATING" and parked_color_needs.has(col):
				has_circulating_match = true
				break

		if has_circulating_match:
			return

		var circulating_count := 0
		for p in authoritative_passengers.values():
			if p.get("state", "") == "CIRCULATING":
				circulating_count += 1

		var credits: int = maxi(152 - circulating_count, 0)
		var has_feeder_match := false
		var p_keys: Array = authoritative_passengers.keys()
		p_keys.sort()
		for pid in p_keys:
			var p = authoritative_passengers[pid]
			var st: String = String(p.get("state", ""))
			var col: String = String(p.get("color_id", ""))
			if st == "FEEDER" or st == "PENDING":
				if credits >= 1:
					credits -= 1
					if parked_color_needs.has(col):
						has_feeder_match = true
						break
				else:
					break

		if has_feeder_match:
			return

	# ALL conditions met: Parking full with docked buses, zero in-flight, zero matching front passengers -> LOSE
	state = GameState.FAIL
	puzzle_failed.emit()
	level_failed.emit()
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
	var group_errors := []
	var reservation_errors := []
	var vehicle_errors := []
	var occupancy_errors := []

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

		# Invariant: No passenger may be represented as boarded in one system and circulating/reserved in another
		if st == "BOARDED" and boarding_reservations.has(pid):
			reservation_errors.append("Passenger %d is marked BOARDED but still has an active reservation!" % pid)
		elif st == "BOARDING_RESERVED" and not boarding_reservations.has(pid):
			reservation_errors.append("Passenger %d is marked BOARDING_RESERVED but has no reservation record!" % pid)
		elif (st == "CIRCULATING" or st == "FEEDER" or st == "PENDING") and boarding_reservations.has(pid):
			reservation_errors.append("Passenger %d is in state '%s' but has an active reservation record!" % [pid, st])

	for expected_id in expected_total:
		if not seen_ids.has(expected_id):
			missing_ids.append(expected_id)

	var total_accounted := 0
	for st in ["PENDING", "FEEDER", "CIRCULATING", "BOARDING_RESERVED", "BOARDED"]:
		total_accounted += state_counts.get(st, 0)

	var color_errors := []
	var group_accounting := []
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

		# Exact per-group initial, remaining and boarded counts
		var all_groups = queue.get_all_groups()
		for g_idx in all_groups.size():
			var g: PassengerGroupData = all_groups[g_idx]
			var auth_group_total := 0
			var auth_group_boarded := 0
			var auth_group_unboarded := 0
			for pid in authoritative_passengers.keys():
				var p = authoritative_passengers[pid]
				if int(p.get("group_id", -1)) == g_idx:
					auth_group_total += 1
					if p.get("color_id", "") != g.color_id:
						group_errors.append("Group %d passenger %d has color '%s' != group color '%s'" % [g_idx, pid, p.get("color_id", ""), g.color_id])
					if p.get("state", "") == "BOARDED":
						auth_group_boarded += 1
					else:
						auth_group_unboarded += 1

			var expected_boarded := g.initial_count - g.remaining_count
			if auth_group_total != g.initial_count:
				group_errors.append("Group %d total mismatch: authored initial %d != authoritative registered %d" % [g_idx, g.initial_count, auth_group_total])
			if auth_group_boarded != expected_boarded:
				group_errors.append("Group %d boarded mismatch: queue decrements %d != authoritative boarded %d" % [g_idx, expected_boarded, auth_group_boarded])
			if auth_group_unboarded != g.remaining_count:
				group_errors.append("Group %d remaining mismatch: queue remaining %d != authoritative unboarded %d" % [g_idx, g.remaining_count, auth_group_unboarded])

			group_accounting.append({
				"group_id": g_idx,
				"color_id": g.color_id,
				"initial_count": g.initial_count,
				"remaining_count": g.remaining_count,
				"queue_boarded": expected_boarded,
				"auth_boarded": auth_group_boarded,
				"auth_unboarded": auth_group_unboarded
			})

	# Active reservation ownership and vehicle pending seat counts
	for pid in boarding_reservations.keys():
		var res: BoardingReservation = boarding_reservations[pid]
		if not authoritative_passengers.has(pid):
			reservation_errors.append("Reservation references nonexistent passenger %d" % pid)
		elif authoritative_passengers[pid]["state"] != "BOARDING_RESERVED":
			reservation_errors.append("Passenger %d state is '%s', expected BOARDING_RESERVED" % [pid, authoritative_passengers[pid]["state"]])
		if not vehicles.has(res.vehicle_id):
			reservation_errors.append("Reservation references nonexistent vehicle %d" % res.vehicle_id)

	var total_bus_occupancy := 0
	for vid in vehicles.keys():
		var v: VehicleModel = vehicles[vid]
		total_bus_occupancy += v.passenger_occupancy
		var active_res_count := get_active_reservations_for_vehicle(vid)
		var sync_pending: int = int(pending_boarders.get(vid, 0))
		if active_res_count != sync_pending:
			vehicle_errors.append("Bus %d pending boarders mismatch: active_res=%d, sync_pending=%d" % [vid, active_res_count, sync_pending])
		if v.passenger_occupancy + active_res_count > v.capacity:
			vehicle_errors.append("Bus %d over capacity: occupancy %d + active %d > capacity %d" % [vid, v.passenger_occupancy, active_res_count, v.capacity])

	var total_boarded: int = int(state_counts.get("BOARDED", 0))
	if total_bus_occupancy != total_boarded:
		occupancy_errors.append("Aggregate bus occupancy (%d) != total boarded passengers (%d)" % [total_bus_occupancy, total_boarded])

	var ok := (total_accounted == expected_total) and duplicate_ids.is_empty() and missing_ids.is_empty() and color_errors.is_empty() and group_errors.is_empty() and reservation_errors.is_empty() and vehicle_errors.is_empty() and occupancy_errors.is_empty()
	return {
		"ok": ok,
		"total": total_accounted,
		"expected_total": expected_total,
		"state_counts": state_counts,
		"duplicate_ids": duplicate_ids,
		"missing_ids": missing_ids,
		"color_errors": color_errors,
		"group_errors": group_errors,
		"group_accounting": group_accounting,
		"reservation_errors": reservation_errors,
		"vehicle_errors": vehicle_errors,
		"occupancy_errors": occupancy_errors
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
