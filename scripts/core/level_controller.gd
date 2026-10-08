extends Node
class_name LevelController

## The single authoritative owner of gameplay state for a level. Everything
## else (UI, animations, audio) reacts to signals but never mutates state
## directly. State transitions and pairings all live here.

signal vehicle_state_changed(vehicle_index: int)
signal board_occupancy_changed()
signal bay_state_changed()
signal passenger_state_changed()
signal game_state_changed(new_state: int)
signal request_move_animation(vehicle_index: int, from_cell: Vector2i, to_cell: Vector2i, bay_index: int, bus_color: String, bus_id: String)
signal request_board_animation(vehicle_index: int, count: int)
signal request_depart_animation(vehicle_index: int, bay_index: int)
signal request_hint_pulse(vehicle_index: int)
signal request_blocked_shake(vehicle_index: int)

enum GameState { BOOT, PLAYING, PAUSED, WIN, FAIL }

var level_resource

var _board: Board
var _bay_manager: BayManager
var _passenger_manager: PassengerManager
var _solver: HintSolver
var _undo: UndoManager

var _vehicles: Array[Vehicle] = []  # index = vehicle index, NOT alphabetical

var game_state: int = GameState.BOOT
var extra_bay_active: bool = false
var _interaction_locked: bool = false

func _ready() -> void:
	pass

func load_level(level: LevelData) -> void:
	level_resource = level
	var r: Dictionary = level.validate()
	if not r.ok:
		push_error("Level validation failed: " + ", ".join(r.errors))
		return
	# Build board + bays + passenger manager from data.
	_board = Board.new()
	_board.setup(level.board_size)
	_bay_manager = BayManager.new()
	_bay_manager.setup(level.standard_bay_count)
	_passenger_manager = PassengerManager.new()
	_passenger_manager.setup(level.passenger_order)
	_solver = HintSolver.new()
	_undo = UndoManager.new()
	# Build runtime vehicles.
	_vehicles.clear()
	var data_list: Array[VehicleData] = level.build_vehicle_data()
	for i in data_list.size():
		var v := Vehicle.new()
		v.setup(i, data_list[i])
		_vehicles.append(v)
		_board.place(v.id, v.position)
	extra_bay_active = false
	game_state = GameState.PLAYING
	_interaction_locked = false
	emit_signal("vehicle_state_changed", -1)
	emit_signal("board_occupancy_changed")
	emit_signal("bay_state_changed")
	emit_signal("passenger_state_changed")
	emit_signal("game_state_changed", game_state)
	_recompute_blocked()

func restart() -> void:
	if level_resource == null:
		return
	load_level(level_resource)

func get_board() -> Board:
	return _board

func get_bay_manager() -> BayManager:
	return _bay_manager

func get_passenger_manager() -> PassengerManager:
	return _passenger_manager

func get_solver() -> HintSolver:
	return _solver

func get_undo() -> UndoManager:
	return _undo

func vehicle_count() -> int:
	return _vehicles.size()

func get_vehicle(i: int) -> Vehicle:
	if i < 0 or i >= _vehicles.size():
		return null
	return _vehicles[i]

func get_vehicle_by_id(id: String) -> Vehicle:
	for v in _vehicles:
		if v.id == id:
			return v
	return null

func get_vehicle_index_by_id(id: String) -> int:
	for i in _vehicles.size():
		if _vehicles[i].id == id:
			return i
	return -1

## Recompute AVAILABLE / BLOCKED state for every vehicle on the board.
func _recompute_blocked() -> void:
	for v in _vehicles:
		if not v.is_on_board():
			continue
		if _can_escape(v):
			v.state = Vehicle.State.AVAILABLE
		else:
			v.state = Vehicle.State.BLOCKED
		emit_signal("vehicle_state_changed", v.index)

func _can_escape(v: Vehicle) -> bool:
	if not v.is_on_board():
		return false
	var path: Array[Vector2i] = _escape_path(v)
	return _board.escape_path_clear(v.id, path)

func _escape_path(v: Vehicle) -> Array[Vector2i]:
	var d: Vector2i = VehicleData.dir_to_vector(v.direction)
	var p: Vector2i = v.position + d
	var out: Array[Vector2i] = []
	while _board.in_bounds(p):
		out.append(p)
		p += d
	return out

func set_interaction_locked(locked: bool) -> void:
	_interaction_locked = locked

func is_interaction_locked() -> bool:
	return _interaction_locked

func request_hint() -> int:
	# Returns vehicle index of a useful hint or -1 if none.
	if _interaction_locked:
		return -1
	if game_state != GameState.PLAYING:
		return -1
	var cur := _build_solver_state()
	var h: Dictionary = _solver.find_hint(cur)
	if h.is_empty():
		return -1
	var idx := get_vehicle_index_by_id(String(h.vehicle))
	emit_signal("request_hint_pulse", idx)
	return idx

func unlock_extra_bay() -> bool:
	if extra_bay_active:
		return false
	if not _bay_manager.unlock_extra_bay():
		return false
	extra_bay_active = true
	emit_signal("bay_state_changed")
	return true

func reset_extra_bay() -> void:
	_bay_manager.reset_extra_bay()
	extra_bay_active = false
	emit_signal("bay_state_changed")

## Build a solver SimState from current level state.
func _build_solver_state() -> HintSolver.SimState:
	var st := _solver.build_initial_state(level_resource, extra_bay_active)
	# Sync each vehicle's current position / bay / passenger count.
	for v in _vehicles:
		if not st.vehicles.has(v.id):
			continue
		var sv: HintSolver.SimVehicle = st.vehicles[v.id]
		sv.position = v.position
		sv.on_board = v.is_on_board()
		sv.bay_index = v.bay_index
		sv.current_passengers = v.current_passengers
		if v.is_on_board():
			var key := "%d,%d" % [v.position.x, v.position.y]
			st.cell_owner[key] = v.id
	# Sync bay state from current bay manager.
	st.bay_owner.resize(_bay_manager.bay_count())
	st.bay_state.resize(_bay_manager.bay_count())
	for i in _bay_manager.bay_count():
		var b := _bay_manager.bay(i)
		st.bay_owner[i] = b.vehicle_id
		st.bay_state[i] = b.state
	st.active_index = _passenger_manager.active_index()
	return st

## Player tapped a vehicle. Returns true if action started.
func tap_vehicle(vehicle_index: int) -> bool:
	if _interaction_locked:
		return false
	if game_state != GameState.PLAYING:
		return false
	if vehicle_index < 0 or vehicle_index >= _vehicles.size():
		return false
	var v: Vehicle = _vehicles[vehicle_index]
	if not v.is_on_board():
		return false
	if v.state == Vehicle.State.BLOCKED or v.state == Vehicle.State.IDLE:
		# subtle feedback
		emit_signal("request_blocked_shake", vehicle_index)
		return false
	# Snapshot state before committing.
	_snapshot_for_undo()
	# Reserve a free bay (or refuse if none).
	var bay_index := _bay_manager.reserve_for(v.id)
	if bay_index == -1:
		# Can't accept the vehicle right now — but spec says wrong-color
		# buses may still wait. We DO need a bay for a legal vehicle. If
		# none is free, refuse and shake. Player may use Extra Bay or
		# Undo / Hint.
		_undo.pop()  # drop the snapshot
		emit_signal("request_blocked_shake", vehicle_index)
		return false
	var from_cell: Vector2i = v.position
	# Release board occupancy immediately for the leaving vehicle; the
	# animation will represent the logical move.
	_board.clear_vehicle(v.id)
	v.state = Vehicle.State.MOVING
	# Recompute blocking of remaining on-board vehicles BEFORE animation
	# finishes — this is when logical blocking is decided. UI updates
	# will reflect this immediately.
	_recompute_blocked()
	emit_signal("board_occupancy_changed")
	emit_signal("vehicle_state_changed", v.index)
	emit_signal("bay_state_changed")
	# Hand off animation. The animation handler is responsible for
	# calling _on_arrived_at_bay when the bus reaches the bay.
	emit_signal("request_move_animation", vehicle_index, from_cell, v.position, bay_index, v.color, v.id)
	_interaction_locked = true
	return true

## Called by the visual handler when the bus has reached the bay.
func _on_arrived_at_bay(vehicle_index: int, bay_index: int) -> void:
	var v: Vehicle = _vehicles[vehicle_index]
	_bay_manager.confirm_occupancy(bay_index)
	v.bay_index = bay_index
	# Evaluate boarding against active queue.
	_evaluate_waiting_for_color(v)
	emit_signal("bay_state_changed")
	emit_signal("vehicle_state_changed", vehicle_index)
	emit_signal("passenger_state_changed")
	# After boarding/depart logic, re-evaluate ALL waiting buses — a
	# newly-wrong-color bus from earlier may now have something to do.
	_recheck_all_waiting()
	_check_win_fail()
	_interaction_locked = false

## Board or leave waiting: if active_color matches, board as many as
## possible; else, set state WAITING.
func _evaluate_waiting_for_color(v: Vehicle) -> void:
	if v.bay_index < 0:
		return
	var active := _passenger_manager.active_color()
	if active == "":
		v.state = Vehicle.State.WAITING
		return
	if v.color != active:
		v.state = Vehicle.State.WAITING
		return
	# Reserve & board as many as capacity allows.
	var need := v.remaining_seats()
	var reserved := _passenger_manager.reserve_next_for(v.id, v.color, need)
	if reserved <= 0:
		v.state = Vehicle.State.WAITING
		return
	# Animate walking + boarding (visual signal only).
	emit_signal("request_board_animation", v.index, reserved)
	_passenger_manager.confirm_seated(v.id, reserved)
	v.current_passengers += reserved
	if v.is_full():
		v.state = Vehicle.State.FULL
		# Logical state advances immediately so subsequent solver / queue
		# progression isn't coupled to the visual depart animation.
		_depart_bus_now(v.index, v.bay_index)
	else:
		v.state = Vehicle.State.WAITING

## Apply logical departure without animation coupling — board already seated
## passengers, release bay, mark vehicle COMPLETED. Emits the visual depart
## animation signal so any connected handler can play the tween, but logic
## is already consistent.
func _depart_bus_now(vehicle_index: int, bay_index: int) -> void:
	var v: Vehicle = _vehicles[vehicle_index]
	v.state = Vehicle.State.DEPARTING
	# Complete seated passengers of this bus.
	_passenger_manager.complete_for(v.id)
	v.current_passengers = 0
	# Release bay.
	_bay_manager.release(bay_index)
	v.bay_index = -1
	# Mark vehicle completed (no longer exists as a runtime entity).
	v.state = Vehicle.State.COMPLETED
	emit_signal("bay_state_changed")
	emit_signal("vehicle_state_changed", vehicle_index)
	emit_signal("passenger_state_changed")
	emit_signal("request_depart_animation", vehicle_index, bay_index)

## Called by animation when depart animation done. After the refactor this
## is a no-op (logic already advanced in _depart_bus_now); kept for API
## stability with the animation handler in level1.gd.
func _on_departed(vehicle_index: int, bay_index: int) -> void:
	pass

## Iterate all waiting buses in deterministic order and try to advance.
func _recheck_all_waiting() -> void:
	var progress := true
	while progress:
		progress = false
		var active := _passenger_manager.active_color()
		if active == "":
			break
		# Iterate bays in index order; deterministic.
		for i in _bay_manager.bay_count():
			var b = _bay_manager.bay(i)
			if b == null:
				continue
			if b.state != BayManager.State.OCCUPIED:
				continue
			var v := get_vehicle_by_id(b.vehicle_id)
			if v == null:
				continue
			if v.color != active or v.is_full() or v.state == Vehicle.State.COMPLETED:
				continue
			var need := v.remaining_seats()
			var reserved := _passenger_manager.reserve_next_for(v.id, v.color, need)
			if reserved <= 0:
				continue
			emit_signal("request_board_animation", v.index, reserved)
			_passenger_manager.confirm_seated(v.id, reserved)
			v.current_passengers += reserved
			if v.is_full():
				v.state = Vehicle.State.FULL
				_depart_bus_now(v.index, v.bay_index)
			else:
				v.state = Vehicle.State.WAITING
			progress = true
			break  # restart from lowest bay

## Check terminal conditions.
func _check_win_fail() -> void:
	if _passenger_manager.all_completed():
		game_state = GameState.WIN
		_interaction_locked = true
		emit_signal("game_state_changed", game_state)
		return
	# Dead-end: no legal moves, no waiting matches possible.
	if _is_dead_end():
		game_state = GameState.FAIL
		_interaction_locked = true
		emit_signal("game_state_changed", game_state)

func _is_dead_end() -> bool:
	# If any bay is free, check if any on-board vehicle can escape
	if _bay_manager.find_free_bay() != -1:
		for v in _vehicles:
			if v.is_on_board() and v.state == Vehicle.State.AVAILABLE:
				return false
	# If no bays are free OR no on-board vehicles can move, check if any waiting bus matches active demand
	var active := _passenger_manager.active_color()
	if active == "":
		return false
	for i in _bay_manager.bay_count():
		var b = _bay_manager.bay(i)
		if b == null or b.state != BayManager.State.OCCUPIED:
			continue
		var v := get_vehicle_by_id(b.vehicle_id)
		if v == null:
			continue
		if v.color == active and not v.is_full():
			return false
	return true

func _snapshot_for_undo() -> void:
	var s := UndoManager.Snapshot.new()
	s.board_snapshot = _board.snapshot()
	s.bay_snapshot = _bay_manager.snapshot()
	s.passenger_snapshot = _passenger_manager.snapshot()
	s.active_index = _passenger_manager.active_index()
	s.game_state = game_state
	s.extra_bay_active = extra_bay_active
	s.hint_pending = false
	for v in _vehicles:
		s.vehicle_snapshots.append(v.make_snapshot())
	_undo.push(s)

## Undo one player move. Returns true if applied.
func undo() -> bool:
	if not _undo.can_undo():
		return false
	if _interaction_locked:
		return false
	var s: UndoManager.Snapshot = _undo.pop()
	_board.restore(s.board_snapshot)
	_bay_manager.restore(s.bay_snapshot)
	_passenger_manager.restore(s.passenger_snapshot, s.active_index)
	for i in _vehicles.size():
		if i < s.vehicle_snapshots.size():
			_vehicles[i].restore_snapshot(s.vehicle_snapshots[i])
	extra_bay_active = s.extra_bay_active
	game_state = s.game_state
	_interaction_locked = false
	emit_signal("vehicle_state_changed", -1)
	emit_signal("board_occupancy_changed")
	emit_signal("bay_state_changed")
	emit_signal("passenger_state_changed")
	emit_signal("game_state_changed", game_state)
	return true

func pause() -> void:
	if game_state == GameState.PLAYING:
		game_state = GameState.PAUSED
		emit_signal("game_state_changed", game_state)

func resume() -> void:
	if game_state == GameState.PAUSED:
		game_state = GameState.PLAYING
		emit_signal("game_state_changed", game_state)

func find_first_available_vehicle_index() -> int:
	for v in _vehicles:
		if v.is_on_board() and v.state == Vehicle.State.AVAILABLE:
			return v.index
	return -1

func get_active_passenger_color() -> String:
	if _passenger_manager == null:
		return ""
	return _passenger_manager.active_color()

func is_playing() -> bool:
	return game_state == GameState.PLAYING