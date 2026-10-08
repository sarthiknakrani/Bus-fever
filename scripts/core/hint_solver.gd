extends RefCounted
class_name HintSolver

## Authoritative simulation of the puzzle. Performs BFS over legal
## states to (a) prove solvability, (b) pick useful hints.
##
## Inputs: LevelData + a snapshot of current state.
## Outputs: list of legal moves from current state, and a winning
## sequence from the initial state.

const VehicleDataScript := preload("res://scripts/core/vehicle_data.gd")

class SimVehicle:
	var id: String
	var color: String
	var capacity: int
	var position: Vector2i
	var direction: int
	var on_board: bool          # true if still on board; false = parked/left
	var bay_index: int
	var current_passengers: int
	func snapshot() -> Dictionary:
		return {
			"id": id, "color": color, "capacity": capacity,
			"position": {"x": position.x, "y": position.y},
			"direction": direction, "on_board": on_board,
			"bay_index": bay_index, "current_passengers": current_passengers,
		}

class SimState:
	var board_size: Vector2i
	var vehicles: Dictionary   # id -> SimVehicle
	var cell_owner: Dictionary # "x,y" -> vehicle_id
	var bay_size: int
	var bay_owner: Array       # index -> vehicle_id or ""
	var bay_state: Array       # index -> int (BayManager.State)
	var passenger_order: Array[String]
	var active_index: int
	var extra_bay: bool
	func fingerprint() -> String:
		# Compact, order-independent hash for visited-state set.
		var parts: Array[String] = []
		for id in vehicles.keys():
			var v: SimVehicle = vehicles[id]
			var pos_str := "%s@%d,%d%s%d*p%d" % [id, v.position.x, v.position.y, ("b" if not v.on_board else ""), v.bay_index, v.current_passengers]
			parts.append(pos_str)
		parts.sort()
		var ps := "%d/%d" % [active_index, passenger_order.size()]
		var bs := ",".join(bay_owner)
		var st := ",".join(bay_state.map(func(s): return str(s)))
		return "%s|%s|%s|%s|%s" % [ps, ",".join(parts), bs, st, ("1" if extra_bay else "0")]

func _board_clear_for(state: SimState, vid: String, path: Array) -> bool:
	for c in path:
		var key := "%d,%d" % [c.x, c.y]
		var owner: String = String(state.cell_owner.get(key, ""))
		if owner != "" and owner != vid:
			return false
	return true

func _can_escape(state: SimState, v: SimVehicle) -> bool:
	# A vehicle can escape iff all cells from its current position in the
	# facing direction up to (but not including) the off-board exit are
	# free of other vehicles.
	var d: Vector2i = VehicleDataScript.dir_to_vector(v.direction)
	var p: Vector2i = v.position + d
	while p.x >= 0 and p.y >= 0 and p.x < state.board_size.x and p.y < state.board_size.y:
		var key := "%d,%d" % [p.x, p.y]
		var owner: String = String(state.cell_owner.get(key, ""))
		if owner != "" and owner != v.id:
			return false
		p += d
	return true

func _all_path_cells(v: VehicleData) -> Array:
	var d: Vector2i = VehicleDataScript.dir_to_vector(v.direction)
	var path: Array = []
	var p: Vector2i = v.position + d
	while p.x >= 0 and p.y >= 0:
		path.append(p)
		p += d
	return path

func build_initial_state(level: LevelData, extra_bay: bool) -> SimState:
	var st := SimState.new()
	st.board_size = level.board_size
	st.bay_size = level.standard_bay_count + (1 if extra_bay else 0)
	st.extra_bay = extra_bay
	st.bay_owner.resize(st.bay_size)
	st.bay_owner.fill("")
	st.bay_state.resize(st.bay_size)
	for i in st.bay_size:
		st.bay_state[i] = 0  # FREE
	st.passenger_order = level.passenger_order.duplicate()
	st.active_index = 0
	for v in level.vehicles:
		var vd := VehicleDataScript.new()
		vd.from_dict(v)
		var sv := SimVehicle.new()
		sv.id = vd.id
		sv.color = vd.color
		sv.capacity = vd.capacity
		sv.position = vd.position
		sv.direction = vd.direction
		sv.on_board = true
		sv.bay_index = -1
		sv.current_passengers = 0
		st.vehicles[vd.id] = sv
		var key := "%d,%d" % [vd.position.x, vd.position.y]
		st.cell_owner[key] = vd.id
	return st

func clone_state(state: SimState) -> SimState:
	var st := SimState.new()
	st.board_size = state.board_size
	st.bay_size = state.bay_size
	st.extra_bay = state.extra_bay
	st.bay_owner = state.bay_owner.duplicate()
	st.bay_state = state.bay_state.duplicate()
	st.passenger_order = state.passenger_order.duplicate()
	st.active_index = state.active_index
	st.cell_owner = state.cell_owner.duplicate()
	st.vehicles = {}
	for id in state.vehicles.keys():
		var v: SimVehicle = state.vehicles[id]
		var n := SimVehicle.new()
		n.id = v.id; n.color = v.color; n.capacity = v.capacity
		n.position = v.position; n.direction = v.direction
		n.on_board = v.on_board; n.bay_index = v.bay_index
		n.current_passengers = v.current_passengers
		st.vehicles[id] = n
	return st

func _find_free_bay(state: SimState) -> int:
	for i in state.bay_size:
		if state.bay_state[i] == 0:
			return i
	return -1

## Returns true if state represents a complete win.
func _is_win(state: SimState) -> bool:
	return state.active_index >= state.passenger_order.size()

## Simulate moving `v` to bay `bi` from state `state`. Returns new state or null if illegal.
func apply_move(state: SimState, v: SimVehicle, bay_index: int) -> SimState:
	if not v.on_board:
		return null
	if bay_index < 0 or bay_index >= state.bay_size:
		return null
	if state.bay_state[bay_index] != 0:
		return null
	if not _can_escape(state, v):
		return null
	var nst := clone_state(state)
	var nv: SimVehicle = nst.vehicles[v.id]
	nv.on_board = false
	nv.bay_index = bay_index
	nst.cell_owner.erase("%d,%d" % [v.position.x, v.position.y])
	nst.bay_owner[bay_index] = v.id
	# Move to OCCUPIED (or RESERVED then OCCUPIED — final state is OCCUPIED for solver)
	nst.bay_state[bay_index] = 2  # OCCUPIED
	# Now check if active passenger color matches this bus; if so, board as
	# many as fit (up to capacity) and depart.
	var active := ""
	while nst.active_index < nst.passenger_order.size():
		active = String(nst.passenger_order[nst.active_index])
		if active != nv.color:
			break
		if nv.current_passengers >= nv.capacity:
			break
		nv.current_passengers += 1
		nst.active_index += 1
	if nv.current_passengers >= nv.capacity:
		# Bus departs: bay freed, vehicle marked completed.
		nst.bay_owner[bay_index] = ""
		nst.bay_state[bay_index] = 0
		nv.bay_index = -1
		nv.current_passengers = 0
		nst.vehicles.erase(v.id)
	# If bus still has current_passengers > 0 (and isn't full), it WAITS.
	return nst

## Try boarding of any WAITING (parked, not full) bus against the active
## queue. This models re-evaluation after each successful action.
func reevaluate_waiting(state: SimState) -> SimState:
	var nst := clone_state(state)
	var progress := true
	while progress:
		progress = false
		var active := ""
		while nst.active_index < nst.passenger_order.size() and \
			  String(nst.passenger_order[nst.active_index]) == "":
			nst.active_index += 1
		if nst.active_index >= nst.passenger_order.size():
			break
		active = String(nst.passenger_order[nst.active_index])
		# Iterate bays in order; bus at first matching color boards.
		for i in nst.bay_size:
			if nst.bay_state[i] != 2:  # not occupied
				continue
			var vid: String = String(nst.bay_owner[i])
			if vid == "":
				continue
			if not nst.vehicles.has(vid):
				continue
			var bv: SimVehicle = nst.vehicles[vid]
			if bv.color != active:
				continue
			if bv.current_passengers >= bv.capacity:
				continue
			# Board as many as fit
			while bv.current_passengers < bv.capacity and \
				  nst.active_index < nst.passenger_order.size() and \
				  String(nst.passenger_order[nst.active_index]) == active:
				bv.current_passengers += 1
				nst.active_index += 1
			if bv.current_passengers >= bv.capacity:
				# depart
				nst.bay_owner[i] = ""
				nst.bay_state[i] = 0
				bv.bay_index = -1
				bv.current_passengers = 0
				nst.vehicles.erase(vid)
			progress = true
			break
	return nst

## Generate all moves available from `state`.
func enumerate_moves(state: SimState) -> Array:
	# First: try re-evaluation (no movement, but might complete the game).
	var re := reevaluate_waiting(state)
	if _is_win(re):
		return [{"type": "reevaluate", "state": re}]
	# Try every on-board vehicle that can escape to a free bay.
	var matching: Array = []
	var non_matching: Array = []
	var active_color := _active_color(state)
	for id in state.vehicles.keys():
		var v: SimVehicle = state.vehicles[id]
		if not v.on_board:
			continue
		if not _can_escape(state, v):
			continue
		var bi := _find_free_bay(state)
		if bi == -1:
			continue
		var entry := {"type": "move", "vehicle": id, "bay": bi}
		if active_color != "" and v.color == active_color:
			matching.append(entry)
		else:
			non_matching.append(entry)
	# Prefer matching-color moves (they advance the queue). This dramatically
	# prunes the BFS in a puzzle where wrong-color waits clog up bays.
	return matching + non_matching

## Quick active-color lookup; skips over already-completed passengers.
func _active_color(state: SimState) -> String:
	var idx := state.active_index
	while idx < state.passenger_order.size() and state.passenger_order[idx] == "":
		idx += 1
	if idx >= state.passenger_order.size():
		return ""
	return state.passenger_order[idx]

## Check if `state` is a terminal dead-end: every bay is occupied by a bus
## whose color is NOT the active color, and no on-board bus matches.
func _is_pure_dead_end(state: SimState) -> bool:
	if _is_win(state):
		return false
	# If any on-board bus matches active and can escape to a free bay, alive.
	var active := _active_color(state)
	if active != "":
		for id in state.vehicles.keys():
			var v: SimVehicle = state.vehicles[id]
			if v.on_board and v.color == active and _can_escape(state, v):
				if _find_free_bay(state) != -1:
					return false
		# If a parked bus matches and is not full, alive.
		for i in state.bay_size:
			if state.bay_state[i] == 2:  # OCCUPIED
				var vid := String(state.bay_owner[i])
				if vid != "" and state.vehicles.has(vid):
					var bv: SimVehicle = state.vehicles[vid]
					if bv.color == active and bv.current_passengers < bv.capacity:
						return false
	# Now check: if every bus that can still escape is wrong-color, AND every
	# parked bus that matches active has no free bay to swap into, dead.
	# Simpler: if no on-board match AND no parked match, dead.
	return active == ""  # shouldn't happen since _is_win caught

## Run BFS from initial state. Returns an Array of moves leading to WIN,
## or empty if unsolvable.
func find_solution(initial: SimState, max_nodes: int = 50000) -> Array:
	var frontier: Array = [{"state": initial, "path": []}]
	var seen := {initial.fingerprint(): true}
	var nodes := 0
	while frontier.size() > 0:
		var cur: Dictionary = frontier.pop_front()
		nodes += 1
		if nodes > max_nodes:
			break
		var st: SimState = cur.state
		var moves: Array = enumerate_moves(st)
		for m in moves:
			var nst: SimState = m.state if m.type == "reevaluate" else null
			if nst == null:
				var nv: SimVehicle = st.vehicles[m.vehicle]
				nst = apply_move(st, nv, int(m.bay))
				if nst == null:
					continue
				nst = reevaluate_waiting(nst)
			if _is_win(nst):
				var win_path: Array = cur.path.duplicate()
				win_path.append(m)
				return win_path
			if _is_pure_dead_end(nst):
				continue
			var fp := nst.fingerprint()
			if seen.has(fp):
				continue
			seen[fp] = true
			var new_path: Array = cur.path.duplicate()
			new_path.append(m)
			frontier.append({"state": nst, "path": new_path})
	return []

func _count_on_board(st: SimState) -> int:
	var n := 0
	for id in st.vehicles.keys():
		if st.vehicles[id].on_board:
			n += 1
	return n

## Produce a useful Hint: any legal move from current state. Returns
## {"vehicle": id, "bay": int} or {} if none.
func find_hint(state: SimState) -> Dictionary:
	var moves := enumerate_moves(state)
	if moves.is_empty():
		return {}
	var m: Dictionary = moves[0]
	if m.type == "reevaluate":
		return {}
	return {"vehicle": m.vehicle, "bay": int(m.bay)}

## Detect dead-end state: no moves, not yet won, and from this state no
## sequence leads to WIN. We approximate by re-running BFS from this
## state with a smaller node budget.
func is_dead_end(state: SimState, max_nodes: int = 1500) -> bool:
	if _is_win(state):
		return false
	var moves := enumerate_moves(state)
	if moves.size() > 0:
		return false
	return true  # immediate dead node